import Foundation
import CryptoKit
import Supabase

/// Capa de acceso a Supabase. Gateada por `BackendConfig`: si no hay credenciales,
/// `client == nil` y `isConfigured == false`, así que la app sigue funcionando en local.
///
/// Auth (Apple/Google/email), perfil del club, Your Circle, presencia, conexiones,
/// mensajes y moderación. Todo lo de entrenos/feed/ranking se quitó de la app.
@MainActor
final class Backend {
    static let shared = Backend()

    let client: SupabaseClient?
    var isConfigured: Bool { client != nil }

    private init() {
        if BackendConfig.isConfigured, let url = URL(string: BackendConfig.supabaseURL) {
            client = SupabaseClient(supabaseURL: url, supabaseKey: BackendConfig.supabaseAnonKey)
        } else {
            client = nil
        }
    }

    /// ID del usuario autenticado en Supabase (nil si no hay sesión o no está configurado).
    var currentUserId: UUID? { client?.auth.currentSession?.user.id }

    /// Igual, pero espera a que el SDK restaure la sesión persistida (útil en el arranque en frío).
    func currentUserIdAsync() async -> UUID? {
        if let s = client?.auth.currentSession { return s.user.id }
        return try? await client?.auth.session.user.id
    }

    // MARK: - Auth (ID token nativo → sesión Supabase)

    /// Inicia sesión en Supabase con el ID token de Apple (requiere el `nonce` en crudo).
    @discardableResult
    func signInWithApple(idToken: String, nonce: String) async throws -> UUID {
        guard let client else { throw BackendError.notConfigured }
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
        return session.user.id
    }

    /// Inicia sesión en Supabase con el ID token de Google.
    @discardableResult
    func signInWithGoogle(idToken: String) async throws -> UUID {
        guard let client else { throw BackendError.notConfigured }
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken))
        return session.user.id
    }

    /// Inicia sesión con email/contraseña (falla si las credenciales no son válidas).
    @discardableResult
    // Email SIN contraseña (estilo Strava): se envía un código de 6 dígitos al correo
    // (SMTP Resend + plantillas con {{ .Token }}) y `verifyEmailCode` abre la sesión.

    /// Envía el código. `createIfNeeded`: en REGISTRO crea la cuenta si no existe; en
    /// INICIO DE SESIÓN va a false → un correo no registrado da error (y no una cuenta nueva).
    func sendEmailCode(_ email: String, createIfNeeded: Bool) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.auth.signInWithOTP(email: email, shouldCreateUser: createIfNeeded)
    }

    /// Verifica el código de 6 dígitos y devuelve el usuario ya autenticado.
    func verifyEmailCode(_ email: String, code: String) async throws -> UUID {
        guard let client else { throw BackendError.notConfigured }
        let res = try await client.auth.verifyOTP(email: email, token: code, type: .email)
        return res.user.id
    }

    func signOut() async {
        try? await client?.auth.signOut()
    }

    /// Envía un correo para restablecer la contraseña.
    func resetPassword(email: String) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.auth.resetPasswordForEmail(email)
    }

    // MARK: - Perfil

    /// Crea/actualiza la fila de perfil del usuario actual. Solo los campos no nulos.
    func upsertProfile(_ profile: ProfileRow) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.from("profiles").upsert(profile).execute()
    }

    /// Fecha de nacimiento: va en `profile_private` (solo la lee su dueño), NO en
    /// `profiles`, que es pública dentro del club. Ver migración 0024.
    func upsertMyBirthdate(_ date: Date) async throws {
        guard let client, let uid = await currentUserIdAsync() else { throw BackendError.notConfigured }
        struct Row: Encodable { let id: String; let birthdate: String }
        try await client.from("profile_private")
            .upsert(Row(id: uid.uuidString.lowercased(), birthdate: StayDate.string(from: date)), returning: .minimal)
            .execute()
    }

    func fetchMyBirthdate() async throws -> Date? {
        guard let client, let uid = await currentUserIdAsync() else { return nil }
        struct Row: Decodable { let birthdate: String? }
        let rows: [Row] = try await client.from("profile_private").select("birthdate")
            .eq("id", value: uid.uuidString.lowercased()).limit(1).execute().value
        return rows.first?.birthdate.flatMap(StayDate.date(from:))
    }

    // MARK: - Discover («Today's People», migración 0025)

    /// El mazo de hoy (día de Bali). Lo calcula y guarda el servidor: siempre el mismo.
    func todaysPeople() async throws -> DiscoverDeck {
        guard let client else { throw BackendError.notConfigured }
        // En frío, `currentSession` puede traer un token CADUCADO: la RPC salía con él, el
        // servidor la rechazaba y Descubrir enseñaba «sin conexión» hasta refrescar a mano.
        // `auth.session` espera a la sesión restaurada y renueva el token si hace falta.
        _ = try await client.auth.session
        return try await client.rpc("todays_people").execute().value
    }

    /// Your Circle (0028): el mazo de hoy + distancia, online e indicador de cada persona.
    func yourCircle() async throws -> CircleDeck {
        guard let client else { throw BackendError.notConfigured }
        _ = try await client.auth.session   // token renovado (ver todaysPeople)
        return try await client.rpc("your_circle").execute().value
    }

    /// El perfil social de una persona: celda del Circle + señales de actividad.
    /// nil si no existe o hay un bloqueo entre las dos.
    func clubProfile(_ id: String) async throws -> ProfileRow? {
        guard let client else { throw BackendError.notConfigured }
        _ = try await client.auth.session
        struct P: Encodable { let target: String }
        return try await client.rpc("club_profile", params: P(target: id.lowercased())).execute().value
    }

    // MARK: - Presencia de Your Circle (0028)

    /// El servidor ajusta la posición a ~110 m antes de guardarla y nadie la puede leer.
    func updatePresenceExact(lat: Double, lon: Double) async {
        guard let client else { return }
        struct P: Encodable { let lat: Double; let lon: Double }
        do { try await client.rpc("update_presence", params: P(lat: lat, lon: lon)).execute() }
        catch { print("[Backend] presencia falló:", error) }
    }

    func heartbeat() async {
        guard let client, client.auth.currentSession != nil else { return }
        _ = try? await client.rpc("heartbeat").execute()
    }

    func goOffline() async {
        guard let client, client.auth.currentSession != nil else { return }
        _ = try? await client.rpc("go_offline").execute()
    }

    /// Mostrar mi distancia / mi online a los demás.
    func setPresenceVisibility(showDistance: Bool, showOnline: Bool) async {
        guard let client, let me = await currentUserIdAsync() else { return }
        struct V: Encodable { let show_distance: Bool; let show_online: Bool }
        do {
            try await client.from("profiles").update(V(show_distance: showDistance, show_online: showOnline))
                .eq("id", value: me.uuidString).execute()
        } catch { print("[Backend] privacidad de presencia falló:", error) }
    }

    func fetchPresenceVisibility() async -> (showDistance: Bool, showOnline: Bool)? {
        guard let client, let me = await currentUserIdAsync() else { return nil }
        struct V: Decodable { let show_distance: Bool?; let show_online: Bool? }
        guard let v: V = try? await client.from("profiles").select("show_distance,show_online")
            .eq("id", value: me.uuidString).single().execute().value else { return nil }
        return (v.show_distance ?? true, v.show_online ?? true)
    }

    /// Cuántos perfiles del mazo de hoy has visto (el servidor solo lo deja avanzar).
    func setDiscoverPosition(_ pos: Int) async {
        guard let client else { return }
        struct P: Encodable { let pos: Int }
        do { try await client.rpc("discover_set_position", params: P(pos: pos)).execute() }
        catch { print("[Backend] posición de Discover falló:", error) }
    }

    // MARK: - Fotos de actividad (0027)

    /// Sube una foto «haciendo lo que te gusta» y devuelve su URL pública.
    func uploadActivityPhoto(_ data: Data) async throws -> String {
        guard let client, let uid = await currentUserIdAsync() else { throw BackendError.notConfigured }
        let path = "\(uid.uuidString.lowercased())/activity-\(UUID().uuidString.lowercased()).jpg"
        _ = try await client.storage.from("avatars")
            .upload(path, data: compressedImageData(data), options: FileOptions(contentType: "image/jpeg", upsert: false))
        return try client.storage.from("avatars").getPublicURL(path: path).absoluteString
    }

    /// Borra el fichero de una foto de actividad (best-effort).
    func deleteActivityPhoto(_ url: String) async {
        guard let client, let r = url.range(of: "/avatars/") else { return }
        _ = try? await client.storage.from("avatars").remove(paths: [String(url[r.upperBound...])])
    }

    // MARK: - Eliminar cuenta (App Store 5.1.1: obligatorio con registro)

    /// Borra la cuenta COMPLETA del usuario actual: archivos de Storage (best-effort) y la
    /// fila de auth.users vía RPC `delete_my_account` (las cascadas arrastran perfil, sesiones,
    /// follows, mensajes, kudos, comentarios, entrenos…). Después cierra la sesión Supabase.
    func deleteAccount() async throws {
        guard let client else { throw BackendError.notConfigured }
        if let uid = await currentUserIdAsync() {
            let dir = uid.uuidString.lowercased()
            if let files = try? await client.storage.from("session-photos").list(path: dir) {
                let paths = files.map { "\(dir)/\($0.name)" }
                if !paths.isEmpty { _ = try? await client.storage.from("session-photos").remove(paths: paths) }
            }
            _ = try? await client.storage.from("avatars").remove(paths: ["\(dir)/avatar.jpg"])
        }
        try await client.rpc("delete_my_account").execute()
        try? await client.auth.signOut()
    }

    // MARK: - Presencia (privacidad: celda de ~5 km, nunca exacta)

    /// Redondea a la celda de 0,05° (~5 km) y actualiza tu presencia. NUNCA se sube
    /// la ubicación exacta — solo la celda y la marca de actividad.
    func updatePresence(lat: Double, lon: Double) async {
        guard let client, let me = await currentUserIdAsync() else { return }
        struct P: Encodable { let geo_cell_lat: Double; let geo_cell_lon: Double; let active_at: String }
        let cell = P(geo_cell_lat: (lat / 0.05).rounded() * 0.05,
                     geo_cell_lon: (lon / 0.05).rounded() * 0.05,
                     active_at: BackendDate.iso.string(from: Date()))
        _ = try? await client.from("profiles").update(cell).eq("id", value: me.uuidString).execute()
    }

    /// Marca actividad SIN ubicación (al abrir la app): cuenta para "activos", no para el mapa.
    func touchPresence() async {
        guard let client, let me = await currentUserIdAsync() else { return }
        struct T: Encodable { let active_at: String }
        _ = try? await client.from("profiles").update(T(active_at: BackendDate.iso.string(from: Date())))
            .eq("id", value: me.uuidString).execute()
    }

    /// ¿Está libre este @usuario? (excluyendo al propio usuario). nil = no se pudo comprobar.
    func isHandleAvailable(_ handle: String) async -> Bool? {
        guard let client else { return nil }
        let h = handle.trimmingCharacters(in: .whitespaces).lowercased()
        guard !h.isEmpty else { return nil }
        struct Row: Decodable { let id: UUID }
        guard let rows: [Row] = try? await client.from("profiles").select("id")
            .ilike("handle", pattern: h).limit(1).execute().value else { return nil }
        if rows.isEmpty { return true }
        let me = await currentUserIdAsync()
        return rows.first?.id == me   // tu propio handle actual cuenta como disponible
    }

    // MARK: - Push (token del dispositivo)

    /// Registra/actualiza el token APNs del dispositivo para poder recibir pushes.
    func upsertDeviceToken(_ token: String) async throws {
        guard let client, let uid = await currentUserIdAsync() else { return }
        struct Row: Codable { let token: String; let user_id: String; let platform: String }
        try await client.from("device_tokens")
            .upsert(Row(token: token, user_id: uid.uuidString.lowercased(), platform: "ios")).execute()
    }

    /// Busca usuarios reales por @handle o por nombre.
    func searchProfiles(_ query: String, limit: Int = 20) async throws -> [ProfileRow] {
        guard let client else { return [] }
        // Quita comas/paréntesis que romperían el filtro `or` de PostgREST.
        let q = query.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        guard !q.isEmpty else { return [] }
        return try await client.from("profiles")
            .select(ProfileRow.columns)
            .or("handle.ilike.%\(q)%,name.ilike.%\(q)%")
            .limit(limit)
            .execute().value
    }

    /// El perfil del usuario autenticado (para saber si ya se onboardeó).
    func fetchMyProfile() async throws -> ProfileRow? {
        guard let client, let uid = await currentUserIdAsync() else { return nil }
        let rows: [ProfileRow] = try await client.from("profiles")
            .select(ProfileRow.columns)
            .eq("id", value: uid.uuidString).limit(1).execute().value
        return rows.first
    }

    func fetchProfiles(ids: [UUID]) async throws -> [ProfileRow] {
        guard let client, !ids.isEmpty else { return [] }
        return try await client.from("profiles")
            .select(ProfileRow.columns)
            .in("id", values: ids.map { $0.uuidString })
            .execute().value
    }

    // MARK: - Mensajería 1:1

    /// Historial de la conversación con otro usuario (ambos sentidos), cronológico.
    func fetchMessages(with otherUserId: UUID) async throws -> [MessageRow] {
        guard let client, let me = await currentUserIdAsync() else { return [] }
        let a = me.uuidString, b = otherUserId.uuidString
        return try await client.from("messages").select()
            .or("and(sender_id.eq.\(a),recipient_id.eq.\(b)),and(sender_id.eq.\(b),recipient_id.eq.\(a))")
            .order("created_at", ascending: true)
            .execute().value
    }

    /// Todos mis mensajes recientes (para construir la lista de conversaciones).
    func fetchRecentMessages(limit: Int = 300) async throws -> [MessageRow] {
        guard let client, let me = await currentUserIdAsync() else { return [] }
        let m = me.uuidString
        return try await client.from("messages").select()
            .or("sender_id.eq.\(m),recipient_id.eq.\(m)")
            .order("created_at", ascending: false).limit(limit).execute().value
    }

    /// Marca como leídos los mensajes que te ha enviado ese usuario.
    func markMessagesRead(from otherUserId: UUID) async {
        guard let client, let me = await currentUserIdAsync() else { return }
        _ = try? await client.from("messages").update(["read": true])
            .eq("recipient_id", value: me.uuidString)
            .eq("sender_id", value: otherUserId.uuidString)
            .eq("read", value: false)
            .execute()
    }

    /// Envía un mensaje a otro usuario.
    func sendMessage(to otherUserId: UUID, text: String) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("messages")
            .insert(MessageInsert(sender_id: me.uuidString, recipient_id: otherUserId.uuidString, text: text))
            .execute()
    }

    // MARK: - Moderación (reportar / bloquear)

    /// Reporta contenido ('session' | 'comment' | 'user'). Idempotente por reporter+target.
    func report(targetType: String, targetId: String, reportedUserId: String?, reason: String) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("reports")
            .upsert(ReportInsert(reporter_id: me.uuidString, target_type: targetType, target_id: targetId,
                                 reported_user_id: reportedUserId, reason: reason),
                    onConflict: "reporter_id,target_type,target_id")
            .execute()
    }

    func blockUser(_ userId: String) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("blocks").upsert(BlockRow(blocker_id: me.uuidString, blocked_id: userId)).execute()
    }
    func unblockUser(_ userId: String) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("blocks").delete()
            .eq("blocker_id", value: me.uuidString).eq("blocked_id", value: userId).execute()
    }
    func blockedIds() async throws -> [String] {
        guard let client, let me = await currentUserIdAsync() else { return [] }
        let rows: [BlockRow] = try await client.from("blocks").select().eq("blocker_id", value: me.uuidString).execute().value
        return rows.map { $0.blocked_id }
    }

    // MARK: - Storage (fotos). Cada archivo va bajo `<uid>/…` (lo exige la RLS de Storage).

    /// Sube el avatar del usuario y devuelve su URL pública.
    @discardableResult
    func uploadAvatar(_ data: Data) async throws -> String {
        guard let client, let uid = await currentUserIdAsync() else { throw BackendError.notConfigured }
        let path = "\(uid.uuidString.lowercased())/avatar.jpg"
        _ = try await client.storage.from("avatars")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return try client.storage.from("avatars").getPublicURL(path: path).absoluteString
    }

}

enum BackendError: Error { case notConfigured, noSession, emailTaken }

/// Nonce para Sign in with Apple → Supabase: se envía el SHA256 a Apple y el crudo a Supabase.
enum AuthNonce {
    static func random(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Fila de `public.profiles`. `id` debe ser el `auth.uid()` del usuario.
struct ProfileRow: Codable {
    /// Columnas que se LEEN. Incluye las del club: si falta una, `hydrateAccountFromBackend`
    /// la leería como nil y borraría la identidad local al reinstalar.
    static let columns = "id,handle,name,avatar_url,country,city,gym,is_private,"
        + "bio,sports,neighborhood,home_city,home_country,stay_kind,stay_until,intents,photos"

    let id: UUID
    var handle: String?
    var name: String?
    var avatar_url: String?
    var country: String?
    var city: String?
    var gym: String?
    var is_private: Bool?
    var gym_score: Int?

    // ─── Club social (migración 0023) ────────────────────────────────────────
    // Opcionales: hay perfiles en producción sin nada de esto.
    var bio: String?
    var sports: [String]?
    var neighborhood: String?
    var home_city: String?
    var home_country: String?
    var stay_kind: String?
    /// `date` en Postgres → se manda como "yyyy-MM-dd" en texto, no como Date: el
    /// codificador por defecto emite un timestamp ISO completo y la columna es `date`.
    var stay_until: String?
    var intents: [String]?
    /// Hasta 4 fotos «haciendo lo que te gusta» (0027).
    var photos: [String]?
    /// Fotos de sus últimos entrenos públicos. Solo llega en Descubrir; NO es columna.
    var moments: [String]?

    // ─── Solo en Your Circle (0028); NO son columnas y no se envían ───────────
    var age: Int?
    /// Metros ya redondeados por el servidor; nil si esa persona la oculta o no hay ubicación.
    var distance_m: Int?
    var online: Bool?
    /// new · new_in_area · leaving · nearby
    var badge: String?
    var days_left: Int?
    /// Primera vez que aparece en MI Circle (para «4 new»).
    var first_time: Bool?
    /// Solo en el perfil social (`club_profile`); nil si la cuenta es privada.
    var activity: ActivitySignals?

    /// Los campos del club y las fotos se mandan SIEMPRE, también como `null`: el
    /// `Encodable` sintetizado omite los nil, y entonces borrar tu bio (o tu última foto)
    /// no llegaba nunca al servidor, que conservaba el valor viejo. El resto se omite si
    /// es nil, a propósito: `avatar_url` nil significa «sin cambios», no «borra la foto».
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(handle, forKey: .handle)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(avatar_url, forKey: .avatar_url)
        try c.encodeIfPresent(country, forKey: .country)
        try c.encodeIfPresent(city, forKey: .city)
        try c.encodeIfPresent(gym, forKey: .gym)
        try c.encodeIfPresent(is_private, forKey: .is_private)
        try c.encodeIfPresent(gym_score, forKey: .gym_score)
        try c.encode(bio, forKey: .bio)
        try c.encode(sports, forKey: .sports)
        try c.encode(neighborhood, forKey: .neighborhood)
        try c.encode(home_city, forKey: .home_city)
        try c.encode(home_country, forKey: .home_country)
        try c.encode(stay_kind, forKey: .stay_kind)
        try c.encode(stay_until, forKey: .stay_until)
        try c.encode(intents, forKey: .intents)
        try c.encode(photos, forKey: .photos)
        // `moments` no se envía: no es una columna.
    }

    var club: ClubIdentity {
        ClubIdentity(bio: bio, sports: sports, neighborhood: neighborhood, homeCity: home_city,
                     homeCountry: home_country, stayKind: stay_kind,
                     stayUntil: stay_until.flatMap(StayDate.date(from:)), intents: intents)
    }
}

/// Respuesta de `todays_people()`: tarjetas en el orden del mazo + por dónde vas.
struct DiscoverDeck: Decodable {
    let day: String
    let position: Int
    let profiles: [ProfileRow]
}

/// «Trains 4× / week», «Active this week», «7 week streak» (0028, `activity_signals`).
struct ActivitySignals: Codable, Hashable {
    let per_week: Int?
    let active_this_week: Bool?
    let week_streak: Int?
}

struct CircleDeck: Decodable {
    let day: String
    let position: Int
    /// Mi barrio declarado (cabecera «YOUR CIRCLE · Canggu»).
    let area: String?
    let profiles: [ProfileRow]
}

/// Formato de `profiles.stay_until` (columna `date` de Postgres).
enum StayDate {
    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func string(from date: Date) -> String { fmt.string(from: date) }
    static func date(from string: String) -> Date? { fmt.date(from: String(string.prefix(10))) }
}

/// Alta de reporte de contenido.
struct ReportInsert: Encodable {
    let reporter_id: String
    let target_type: String
    let target_id: String
    let reported_user_id: String?
    let reason: String?
}

/// Bloqueo de usuario.
struct BlockRow: Codable {
    let blocker_id: String
    let blocked_id: String
}

/// Alta de mensaje (sin id/fecha).
struct MessageInsert: Encodable {
    let sender_id: String
    let recipient_id: String
    let text: String
}

/// Mensaje leído de `public.messages`.
struct MessageRow: Codable {
    let id: String
    let sender_id: String
    let recipient_id: String
    let text: String
    let created_at: String
    var read: Bool? = nil
}

/// Fecha ↔ `timestamptz`. Escribimos ISO8601 con milisegundos; al leer somos tolerantes
/// porque Postgres devuelve microsegundos (6 dígitos), que el parser estricto rechaza.
enum BackendDate {
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func parse(_ s: String) -> Date? {
        if let d = iso.date(from: s) { return d }
        // Quita la parte fraccionaria de cualquier longitud y reintenta sin ella.
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        let stripped = s.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return plain.date(from: stripped)
    }
}
