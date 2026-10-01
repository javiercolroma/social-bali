import Foundation
import Combine
import Supabase

func conversationId(_ personId: String) -> String { "conv-\(personId)" }

/// Estado de la app de **Bali Circle**: sesión, cuenta, identidad del club, conexiones,
/// conversaciones y la caché de personas. Todo lo de entrenamiento, gamificación, feed y
/// planes se quitó (2026-09-30): la app es un club social, no una app de fitness.
@MainActor
final class AppStore: ObservableObject {
    @Published var profile = Profile(sex: "", age: "", country: "", city: "", gym: "")

    @Published var auth: Auth?
    @Published var account: Account?
    @Published var conversations: [Conversation] = []

    @Published var flashMessage: String? = nil             // aviso breve tipo toast (efímero)

    /// True mientras comprobamos en el servidor si el usuario ya tiene perfil (para no
    /// enseñar el onboarding a alguien que ya se registró). Efímero (no se persiste).
    @Published var checkingProfile = false

    /// Personas con las que tienes conversación real (para resolver nombre/avatar en Chats).
    @Published var messagedPeople: [SocialPerson] = []
    /// Conectar con motivo (ver Connections.swift): solicitudes visibles para mí
    /// (enviadas, recibidas y aceptadas) y los perfiles de quienes aparecen en ellas.
    @Published var connections: [ConnectionRow] = []
    @Published var connectionPeople: [SocialPerson] = []
    /// Abre el chat con esta persona desde cualquier pantalla (RootView lo observa).
    @Published var openChatWith: String? = nil
    var myUserId: String? = nil
    /// Perfil a abrir por deep link de invitación (balicircle://user/<usuario>). Efímero.
    @Published var deepLinkPersonId: String? = nil

    /// DEBUG: salta el login (AuthView) y el onboarding mientras se depura.
    /// Pon en `false` para volver al flujo real (login → onboarding → app).
    /// Si ya se guardó una cuenta debug, reinstala/borra datos para ver de nuevo el flujo.
    static let debugSkipAuthOnboarding = false

    private var loaded = false
    /// Misma clave que la versión con entrenos: el decodificado es tolerante (solo lee los
    /// campos que siguen existiendo e ignora el resto), así nadie pierde su sesión al actualizar.
    private let storeKey = "forge-native-v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let snap = try? JSONDecoder().decode(Persisted.self, from: data) {
            if let p = snap.profile { profile = p }
            auth = snap.auth
            account = snap.account
            conversations = snap.conversations ?? []
        }
        // DEBUG: arranca directo en la app, sin login ni onboarding.
        if Self.debugSkipAuthOnboarding {
            if auth == nil { auth = Auth(provider: "debug", userId: "debug", email: nil, name: "Debug") }
            if account == nil { account = Account(name: "Debug", handle: "debug") }
        }
        loaded = true
    }

    // MARK: - Persistence

    /// Todo opcional: los datos guardados por versiones anteriores traen además campos de
    /// entrenos, liga, logros… que simplemente se ignoran al decodificar.
    private struct Persisted: Codable {
        var profile: Profile?
        var auth: Auth?
        var account: Account?
        var conversations: [Conversation]?
    }

    func persist() {
        guard loaded else { return }
        profile.enforceDatingAge()
        let snap = Persisted(profile: profile, auth: auth, account: account, conversations: conversations)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    // MARK: - Computed

    var unreadMessages: Int { conversations.reduce(0) { $0 + $1.unread } }

    func person(_ id: String) -> SocialPerson? {
        // Insensible a mayúsculas (Postgres da el UUID en minúscula; Swift en mayúscula).
        let key = id.lowercased()
        let all = messagedPeople + connectionPeople
        if let p = all.first(where: { $0.id.lowercased() == key }) { return p }
        // Usuario real no cacheado: placeholder para que SIEMPRE se abra el perfil;
        // ClubProfileView carga sus datos reales.
        if BackendConfig.isConfigured, UUID(uuidString: id) != nil {
            return SocialPerson(id: id, name: "Member", handle: "", avatar: "🙂", gym: "")
        }
        return nil
    }

    /// Refleja un mensaje (enviado o recibido) en la lista de conversaciones al instante.
    func appendLocalMessage(_ personId: String, _ msg: ChatMessage) {
        if let i = conversations.firstIndex(where: { $0.personId == personId }) {
            if !conversations[i].messages.contains(where: { $0.id == msg.id }) {
                conversations[i].messages.append(msg)
                conversations[i].lastAt = msg.at
            }
        } else {
            conversations.insert(Conversation(id: conversationId(personId), personId: personId,
                                              messages: [msg], unread: 0, lastAt: msg.at), at: 0)
        }
        conversations.sort { $0.lastAt > $1.lastAt }
    }

    /// Construye la lista de conversaciones REALES a partir de tus mensajes del servidor.
    func loadConversations() {
        guard BackendConfig.isConfigured else { return }
        Task {
            guard let me = await Backend.shared.currentUserIdAsync() else { return }
            let meStr = me.uuidString.lowercased()
            let msgs = (try? await Backend.shared.fetchRecentMessages()) ?? []
            var byPartner: [String: [MessageRow]] = [:]
            for m in msgs {
                let partner = m.sender_id.lowercased() == meStr ? m.recipient_id : m.sender_id
                byPartner[partner, default: []].append(m)
            }
            let ids = byPartner.keys.compactMap { UUID(uuidString: $0) }
            let mp = (try? await Backend.shared.fetchProfiles(ids: ids)) ?? []
            messagedPeople = Self.asPeople(mp)
            conversations = byPartner.map { (partner, rows) in
                let msgs = rows.sorted { $0.created_at < $1.created_at }.map { r in
                    ChatMessage(id: r.id, fromMe: r.sender_id.lowercased() == meStr,
                                text: r.text, at: BackendDate.parse(r.created_at) ?? Date())
                }
                // No leídos = mensajes que ME ha mandado el otro y aún no marcados como leídos.
                let unread = rows.filter { $0.sender_id.lowercased() == partner.lowercased() && $0.read != true }.count
                return Conversation(id: conversationId(partner), personId: partner,
                                    messages: msgs, unread: unread, lastAt: msgs.last?.at ?? Date())
            }.sorted { $0.lastAt > $1.lastAt }
        }
    }

    // MARK: - Account

    /// @usuario interno que exige `profiles.handle` (único). NUNCA se enseña ni se pide:
    /// nombre en minúsculas y sin tildes + «-» + 6 caracteres aleatorios en base 36.
    static func generateHandle(from name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789")
        var base = String(folded.filter { allowed.contains($0) }.prefix(12))
        if base.isEmpty { base = "member" }
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        let suffix = String((0..<6).map { _ in alphabet.randomElement()! })
        return "\(base)-\(suffix)"
    }

    func saveAccount(_ acc: Account) {
        account = acc; persist()
        syncProfileToBackend()
    }

    /// Best-effort: sube el perfil a Supabase si hay backend configurado y sesión abierta.
    func syncProfileToBackend() {
        guard Backend.shared.isConfigured, account != nil else { return }
        Task {
            guard let uid = await Backend.shared.currentUserIdAsync() else { return }
            // Sube el avatar a Storage (si hay) y usa su URL pública en el perfil.
            // La foto principal de la galería es la foto de perfil.
            var avatarURL: String? = profile.media?.first?.url
            if avatarURL == nil, let photo = account?.photoData { avatarURL = try? await Backend.shared.uploadAvatar(photo) }
            // La fecha va PRIMERO: el servidor rechaza «dating» si aún no la tiene.
            if let b = profile.birthdate {
                do { try await Backend.shared.upsertMyBirthdate(b) }
                catch { print("[Backend] fecha de nacimiento falló:", error) }
            }
            // Un reintento si el @usuario generado choca con otro (único en el servidor).
            for attempt in 0..<2 {
                guard let acc = account else { return }
                let row = profileRow(uid: uid, acc: acc, avatarURL: avatarURL)
                do {
                    try await Backend.shared.upsertProfile(row)
                    print("[Backend] perfil sincronizado")
                    return
                } catch {
                    print("[Backend] upsert perfil falló:", error)
                    let msg = String(describing: error).lowercased()
                    guard attempt == 0, msg.contains("handle") || msg.contains("23505") || msg.contains("duplicate") else { return }
                    var fixed = acc
                    fixed.handle = Self.generateHandle(from: acc.name)
                    account = fixed; persist()
                }
            }
        }
    }

    private func profileRow(uid: UUID, acc: Account, avatarURL: String?) -> ProfileRow {
        ProfileRow(
            id: uid,
            handle: acc.handle,
            name: acc.name,
            avatar_url: avatarURL,
            country: profile.country.isEmpty ? nil : profile.country,
            city: profile.city.isEmpty ? nil : profile.city,
            // Club social: identidad de la PERSONA (ver PRODUCT.md · Fase 1).
            bio: profile.bio?.isEmpty == false ? profile.bio : nil,
            sports: (profile.sports?.isEmpty == false) ? profile.sports : nil,
            neighborhood: profile.neighborhood,
            home_city: profile.homeCity?.isEmpty == false ? profile.homeCity : nil,
            home_country: profile.homeCountry?.isEmpty == false ? profile.homeCountry : nil,
            stay_kind: profile.stayKind,
            stay_until: profile.stayUntil.map(StayDate.string(from:)),
            intents: (profile.intents?.isEmpty == false) ? profile.intents : nil,
            photos: (profile.photos?.isEmpty == false) ? profile.photos : nil,
            media: (profile.media?.isEmpty == false) ? profile.media : nil,
            arrival_date: profile.arrivalDate.map(StayDate.string(from:)))
        // (Los intents ya pasan por `enforceDatingAge` en cada `persist`.)
    }

    /// Entra en la app con la identidad del proveedor. Con backend, SOLO se llama cuando
    /// la sesión de Supabase ya está abierta (ver AuthView): así nunca se entra «a medias».
    func signIn(provider: String, userId: String, email: String?, name: String?) {
        auth = Auth(provider: provider, userId: userId, email: email, name: name)
        // Si hay backend y aún no hay cuenta local, marcamos "comprobando" para NO enseñar
        // el onboarding mientras miramos si ya tienes perfil en el servidor.
        if BackendConfig.isConfigured && account == nil { checkingProfile = true }
        persist()
    }

    /// Arranque: si hay sesión local pero Supabase no tiene sesión válida, se cierra la
    /// sesión local para volver a la pantalla de acceso (antes se quedaba dentro con todas
    /// las pantallas fallando con «check your connection»). Un fallo de RED no cierra nada.
    func validateBackendSession() async {
        guard BackendConfig.isConfigured, auth != nil, !Self.debugSkipAuthOnboarding,
              let client = Backend.shared.client else { return }
        do {
            _ = try await client.auth.session
        } catch let e as URLError {
            print("[Auth] sin red al validar la sesión; se mantiene:", e.code)
        } catch {
            print("[Auth] sesión de Supabase no válida → cierre local:", error)
            logout()
        }
    }

    /// Si el usuario YA tiene perfil en Supabase, reconstruye la cuenta local → se salta el
    /// onboarding. Si no (usuario nuevo), deja `account == nil` para que haga el onboarding.
    func hydrateAccountFromBackend() {
        guard BackendConfig.isConfigured, account == nil else { checkingProfile = false; return }
        checkingProfile = true
        Task {
            let found = (try? await Backend.shared.fetchMyProfile()) ?? nil
            if let p = found, let handle = p.handle, !handle.isEmpty {
                account = Account(name: p.name ?? "", handle: handle)
                if let c = p.country { profile.country = c }
                if let c = p.city { profile.city = c }
                // Club social: sin esto, quien reinstala o cambia de móvil perdería su
                // identidad (bio, deportes, barrio, estancia) y Your Circle lo vería vacío.
                profile.bio = p.bio
                profile.sports = p.sports
                profile.neighborhood = p.neighborhood
                profile.homeCity = p.home_city
                profile.homeCountry = p.home_country
                profile.stayKind = p.stay_kind
                profile.stayUntil = p.stay_until.flatMap(StayDate.date(from:))
                profile.intents = p.intents
                profile.photos = p.photos
                profile.media = p.media
                profile.arrivalDate = p.arrival_date.flatMap(StayDate.date(from:))
                // La fecha vive aparte (privada). Sin ella, «Dating» quedaría bloqueado
                // para alguien que ya demostró su edad antes de reinstalar.
                if let b = (try? await Backend.shared.fetchMyBirthdate()) ?? nil { profile.birthdate = b }
                persist()
            }
            checkingProfile = false
        }
    }

    /// Cerrar sesión: borra TODO el estado local del usuario para que NADA se filtre a la
    /// siguiente cuenta. El próximo login rehidrata del servidor o hace onboarding si es nuevo.
    func logout() {
        Task { await Backend.shared.signOut() }
        NotificationManager.shared.cancelAll()
        PresenceService.shared.stop()
        auth = nil
        account = nil
        profile = Profile(sex: "", age: "", country: "", city: "", gym: "")
        conversations = []
        connections = []; connectionPeople = []; myUserId = nil
        messagedPeople = []
        openChatWith = nil
        deepLinkPersonId = nil
        checkingProfile = false
        persist()
    }

    /// Deep link de invitación: busca el @usuario y abre su perfil.
    func openProfileByHandle(_ handle: String) {
        guard BackendConfig.isConfigured else { return }
        let h = handle.trimmingCharacters(in: .whitespaces).lowercased()
        guard !h.isEmpty else { return }
        Task {
            let results = (try? await Backend.shared.searchProfiles(h)) ?? []
            if let match = results.first(where: { ($0.handle ?? "").lowercased() == h }) ?? results.first {
                deepLinkPersonId = match.id.uuidString.lowercased()
            }
        }
    }

    /// Elimina la cuenta COMPLETA (servidor + estado local). Devuelve false si falló el servidor.
    func deleteAccount() async -> Bool {
        if BackendConfig.isConfigured {
            do { try await Backend.shared.deleteAccount() }
            catch { print("[Backend] eliminar cuenta falló:", error); return false }
        }
        logout()   // borra todo el estado local (igual que cerrar sesión)
        return true
    }

    static func asPeople(_ profiles: [ProfileRow]) -> [SocialPerson] {
        profiles.map { p in
            SocialPerson(id: p.id.uuidString.lowercased(), name: p.name ?? "Member",
                         handle: p.handle ?? "", avatar: "🙂", gym: "",
                         city: p.city ?? "", country: p.country ?? "",
                         isPrivate: p.is_private ?? false, avatarURL: p.avatar_url, club: p.club,
                         photos: (p.photos ?? []) + (p.moments ?? []))
        }
    }

    // MARK: - Conversations

    @discardableResult
    func openConversation(_ personId: String) -> String {
        // Con backend NO creamos conversaciones vacías: la conversación aparece en la
        // lista al enviar/recibir el primer mensaje real.
        if !BackendConfig.isConfigured && !conversations.contains(where: { $0.personId == personId }) {
            conversations.insert(Conversation(id: conversationId(personId), personId: personId, messages: [], unread: 0, lastAt: Date()), at: 0)
        }
        markConversationRead(personId)
        return conversationId(personId)
    }

    func markConversationRead(_ personId: String) {
        conversations = conversations.map { c in
            guard c.personId == personId else { return c }
            var copy = c; copy.unread = 0; return copy
        }
        persist()
        // Marca leídos en el servidor (para que no vuelva a contar en otro dispositivo).
        if BackendConfig.isConfigured, let uid = UUID(uuidString: personId) {
            Task { await Backend.shared.markMessagesRead(from: uid) }
        }
    }

    /// Envío LOCAL (solo sin backend, para desarrollo): el real va por `Backend.sendMessage`.
    func sendMessage(_ personId: String, _ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appendLocalMessage(personId, ChatMessage(id: newId("m"), fromMe: true, text: trimmed, at: Date()))
        persist()
    }

    private func newId(_ prefix: String) -> String { "\(prefix)-\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 0..<100000))" }
}
