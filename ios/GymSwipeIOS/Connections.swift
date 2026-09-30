import SwiftUI

// MARK: - Conectar con contexto (PRODUCT.md, Fase 3 · migración 0026)
//
// Se conecta CON UN MOTIVO y quien lo recibe ve quién es y por qué. Si acepta, se abre
// el chat. «Me interesa» (citas) solo se revela si es mutuo. Sin conexión aceptada no se
// puede escribir: lo impone el servidor (`messages_insert`), no solo la interfaz.

enum ConnectReason: String, CaseIterable, Identifiable {
    case train, surf, coffee, interested

    var id: String { rawValue }

    /// Lo que eliges al conectar.
    var label: String {
        switch self {
        case .train:      return L10n.t("Train together")
        case .surf:       return L10n.t("Surf sometime")
        case .coffee:     return L10n.t("Grab a coffee")
        case .interested: return L10n.t("I'm interested")
        }
    }

    /// Lo que ve quien lo recibe: «wants to surf sometime».
    var receivedLine: String {
        switch self {
        case .train:      return L10n.t("wants to train together")
        case .surf:       return L10n.t("wants to surf sometime")
        case .coffee:     return L10n.t("wants to grab a coffee")
        case .interested: return L10n.t("is interested in you")
        }
    }

    var emoji: String {
        switch self {
        case .train: return "🏋️"
        case .surf: return "🏄"
        case .coffee: return "☕️"
        case .interested: return "✨"
        }
    }

    /// Los motivos sociales, siempre disponibles. «interested» va aparte (solo si ambos
    /// buscan citas y tienen 18+).
    static let social: [ConnectReason] = [.train, .surf, .coffee]
}

/// Fila de `public.connection_requests` (la RLS ya filtra lo que puedo ver).
struct ConnectionRow: Codable, Identifiable, Hashable {
    let id: String
    let from_id: String
    let to_id: String
    let reason: String
    let status: String
    let created_at: String

    var connectReason: ConnectReason? { ConnectReason(rawValue: reason) }
}

/// Estado de la relación con una persona, visto desde mí.
enum ConnState: Equatable {
    case none
    case sent(ConnectReason)                    // enviada (un rechazo también se ve así: es silencioso)
    case incoming(ConnectReason, requestId: String)
    case connected(ConnectReason)
}

extension Backend {
    func fetchConnections() async throws -> [ConnectionRow] {
        guard let client else { return [] }
        _ = try await client.auth.session   // token renovado (ver todaysPeople)
        return try await client.from("connection_requests")
            .select("id,from_id,to_id,reason,status,created_at")
            .order("created_at", ascending: false)
            .execute().value
    }

    /// 'connected' o 'pending'.
    func sendConnection(to personId: String, reason: ConnectReason) async throws -> String {
        guard let client else { throw BackendError.notConfigured }
        struct P: Encodable { let target: String; let reason: String }
        return try await client.rpc("send_connection", params: P(target: personId.lowercased(), reason: reason.rawValue))
            .execute().value
    }

    func respondConnection(_ requestId: String, accept: Bool) async throws -> String {
        guard let client else { throw BackendError.notConfigured }
        struct P: Encodable { let request: String; let accept: Bool }
        return try await client.rpc("respond_connection", params: P(request: requestId, accept: accept))
            .execute().value
    }
}

extension AppStore {
    /// Carga las solicitudes y los perfiles de quienes me escriben (best-effort).
    func loadConnections() {
        guard BackendConfig.isConfigured else { return }
        Task {
            guard let me = await Backend.shared.currentUserIdAsync() else { return }
            myUserId = me.uuidString.lowercased()
            guard let rows = try? await Backend.shared.fetchConnections() else { return }
            connections = rows
            let others = Set(rows.map { $0.from_id.lowercased() == myUserId ? $0.to_id : $0.from_id })
            let ids = others.compactMap { UUID(uuidString: $0) }
            if let profs = try? await Backend.shared.fetchProfiles(ids: ids) {
                connectionPeople = Self.asPeople(profs)
            }
        }
    }

    func connectionState(_ personId: String) -> ConnState {
        guard let me = myUserId else { return .none }
        let other = personId.lowercased()
        let mine = connections.first { $0.from_id.lowercased() == me && $0.to_id.lowercased() == other }
        let theirs = connections.first { $0.from_id.lowercased() == other && $0.to_id.lowercased() == me }
        if let a = [mine, theirs].compactMap({ $0 }).first(where: { $0.status == "accepted" }) {
            return .connected(a.connectReason ?? .coffee)
        }
        if let t = theirs, t.status == "pending", let r = t.connectReason { return .incoming(r, requestId: t.id) }
        if let m = mine, let r = m.connectReason { return .sent(r) }
        return .none
    }

    func isConnected(_ personId: String) -> Bool {
        if case .connected = connectionState(personId) { return true }
        return false
    }

    /// Solicitudes recibidas pendientes (las «interested» nunca llegan aquí: son ocultas).
    var incomingRequests: [ConnectionRow] {
        guard let me = myUserId else { return [] }
        return connections.filter { $0.to_id.lowercased() == me && $0.status == "pending" }
    }

    /// ¿Busco citas (y puedo)? Condición para ofrecer «I'm interested».
    var iAmOpenToDating: Bool { profile.canDate && profile.intentList.contains(.dating) }

    /// 'connected', 'pending' o nil si falló.
    @discardableResult
    func connect(_ personId: String, reason: ConnectReason) async -> String? {
        do {
            let result = try await Backend.shared.sendConnection(to: personId, reason: reason)
            FX.success()
            loadConnections()
            // El match de «interested» lo celebra `ConnectSheet`; el resto, un aviso.
            if result == "connected" && reason != .interested { flashMessage = L10n.t("You're connected!") }
            return result
        } catch {
            print("[Connect] envío falló:", error)
            FX.warning()
            return nil
        }
    }

    func respond(_ requestId: String, accept: Bool, personId: String) async {
        do {
            _ = try await Backend.shared.respondConnection(requestId, accept: accept)
            accept ? FX.success() : FX.tap()
            loadConnections()
            if accept { openChatWith = personId }
        } catch {
            print("[Connect] respuesta falló:", error)
            FX.warning()
        }
    }
}

// MARK: - Botón de conectar (tarjeta de Descubrir y perfil)

/// Un único control para todos los estados: conectar (con motivo) → enviada →
/// conectados (mensaje). Si la otra persona te lo pidió, aceptar aquí mismo.
struct ConnectControl: View {
    @EnvironmentObject var store: AppStore
    let personId: String
    /// ¿Ofrecer «I'm interested»? Solo si ambos buscan citas (ver `ClubIdentity.visible`).
    let theyAreOpenToDating: Bool
    /// Para la hoja de motivos; si faltan, se buscan en las personas ya cargadas.
    var name: String? = nil
    var photoURL: String? = nil
    @State private var busy = false
    @State private var choosing = false

    var body: some View {
        switch store.connectionState(personId) {
        case .none:
            Button { FX.tap(); choosing = true } label: {
                pill(icon: "hand.wave.fill", text: L10n.t("Connect"), filled: true)
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .sheet(isPresented: $choosing) {
                ConnectSheet(personId: personId,
                             name: name ?? store.person(personId)?.name ?? "",
                             photoURL: photoURL ?? store.person(personId)?.avatarURL,
                             offerInterested: store.iAmOpenToDating && theyAreOpenToDating)
                    .environmentObject(store)
            }
        case .sent(let r):
            VStack(alignment: .leading, spacing: 4) {
                pill(icon: r == .interested ? "lock.fill" : "clock", text: r == .interested ? L10n.t("Interested · private") : "\(r.emoji) \(L10n.t("Request sent"))", filled: false)
                if r == .interested {
                    Text("They'll only know if they're interested too.").font(.caption2).foregroundColor(Brand.soft)
                }
            }
        case .incoming(let r, let requestId):
            HStack(spacing: 8) {
                Button { Task { busy = true; await store.respond(requestId, accept: true, personId: personId); busy = false } } label: {
                    pill(icon: "checkmark", text: "\(r.emoji) \(L10n.t("Accept"))", filled: true)
                }.buttonStyle(.plain)
                Button { Task { busy = true; await store.respond(requestId, accept: false, personId: personId); busy = false } } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.soft)
                        .frame(width: 44, height: 44).background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            .disabled(busy)
        case .connected:
            Button { FX.tap(); store.openChatWith = personId } label: {
                pill(icon: "message.fill", text: L10n.t("Message"), filled: true)
            }.buttonStyle(.plain)
        }
    }

    private func pill(icon: String, text: String, filled: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(.system(size: 15, weight: .heavy))
        .foregroundColor(filled ? Color(hex: "10150a") : Brand.ink)
        .frame(maxWidth: .infinity).frame(height: 44)
        .background(filled ? Brand.green : Brand.chip)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Solicitudes recibidas

/// «2 people want to connect»: quién, y POR QUÉ. Aceptar abre el chat.
struct ConnectionRequestsSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var openProfile: SocialPerson?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if store.incomingRequests.isEmpty {
                        Text("No pending requests").font(.footnote).foregroundColor(Brand.muted).padding(.top, 40)
                    }
                    ForEach(store.incomingRequests) { req in
                        let person = store.person(req.from_id)
                        PanelCard {
                            Button { if let person { openProfile = person } } label: {
                                HStack(spacing: 12) {
                                    ScoredAvatar(emoji: person?.club?.sportList.first?.emoji ?? "🙂",
                                                 avatarURL: person?.avatarURL, score: store.personScore(req.from_id), size: 52)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(person?.name ?? "…").font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink)
                                        Text("\(req.connectReason?.emoji ?? "") \(req.connectReason?.receivedLine ?? "")")
                                            .font(.subheadline).foregroundColor(Brand.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                                }
                            }.buttonStyle(.plain)
                            ConnectControl(personId: req.from_id, theyAreOpenToDating: false)
                        }
                    }
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle(L10n.t("Connection requests")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.t("Done")) { dismiss() }.fontWeight(.heavy) } }
            .sheet(item: $openProfile) { ClubProfileView(personId: $0.id).environmentObject(store) }
            // Al aceptar se abre el chat: esta hoja se cierra para que se vea.
            .onChange(of: store.openChatWith) { v in if v != nil { dismiss() } }
        }
    }
}
