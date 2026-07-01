import SwiftUI
import PhotosUI

func normalizeHandle(_ value: String) -> String {
    let lower = value.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    let filtered = lower.unicodeScalars.filter { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_").contains($0) }
    return String(String.UnicodeScalarView(filtered)).prefix(20).description
}

/// Número determinista (para seguidores/seguidos demo) a partir de un id.
func deterministicCount(_ seed: String, salt: UInt64, lo: Int, hi: Int) -> Int {
    var s = salt
    for ch in seed.unicodeScalars { s = s &* 131 &+ UInt64(ch.value) }
    return lo + Int(s % UInt64(max(1, hi - lo + 1)))
}

func formatCount(_ n: Int) -> String {
    if n >= 1000 { return String(format: "%.1f", Double(n) / 1000).replacingOccurrences(of: ".", with: ",") + "k" }
    return "\(n)"
}

/// Fila estilo Instagram: entrenos · seguidores · siguiendo (seguidores/siguiendo abren lista).
func profileCountsRow(entrenos: Int, seguidores: Int, siguiendo: Int, locked: Bool = false,
                      onSeguidores: @escaping () -> Void, onSiguiendo: @escaping () -> Void) -> some View {
    HStack(spacing: 0) {
        profileCountTile(formatCount(entrenos), "Entrenos")
        // Cuenta privada que no sigues: los contadores no son tocables (no se ve la lista).
        if locked {
            profileCountTile(formatCount(seguidores), "Seguidores")
            profileCountTile(formatCount(siguiendo), "Siguiendo")
        } else {
            Button { onSeguidores() } label: { profileCountTile(formatCount(seguidores), "Seguidores") }.buttonStyle(.plain)
            Button { onSiguiendo() } label: { profileCountTile(formatCount(siguiendo), "Siguiendo") }.buttonStyle(.plain)
        }
    }
    .padding(.vertical, 12)
    .background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
}

private func profileCountTile(_ value: String, _ label: String) -> some View {
    VStack(spacing: 2) {
        Text(value).font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink)
        Text(label).font(.caption2).foregroundColor(Brand.muted)
    }.frame(maxWidth: .infinity)
}

/// Lista determinista de personas (seguidores/seguidos demo) rotando el pool.
func demoFollowList(_ store: AppStore, seed: String, salt: UInt64, exclude: String?) -> [SocialPerson] {
    let pool = store.people.filter { $0.id != exclude }
    guard !pool.isEmpty else { return [] }
    var s = salt
    for ch in seed.unicodeScalars { s = s &* 131 &+ UInt64(ch.value) }
    let start = Int(s % UInt64(pool.count))
    return Array(pool[start...] + pool[..<start])
}

struct FollowListData: Identifiable { let id = UUID(); let title: String; let people: [SocialPerson] }

/// Lista de seguidores/seguidos con buscador.
struct FollowListSheet: View {
    @EnvironmentObject var store: AppStore
    let title: String
    let people: [SocialPerson]
    @State private var query = ""
    @State private var profileTarget: IdString?

    private var results: [SocialPerson] {
        let q = query.folding(options: .diacriticInsensitive, locale: .current).lowercased().replacingOccurrences(of: "@", with: "")
        guard !q.isEmpty else { return people }
        return people.filter {
            $0.name.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q) || $0.handle.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(Brand.soft)
                    TextField("Buscar por nombre o @usuario", text: $query)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Brand.soft) } }
                }
                .padding(.horizontal, 12).frame(height: 44).background(Color.white).clipShape(Capsule())
                .overlay(Capsule().stroke(Brand.line)).padding(.horizontal, 14)

                ScrollView {
                    VStack(spacing: 8) {
                        if results.isEmpty {
                            Text(people.isEmpty ? "Nadie por aquí todavía." : "Sin resultados.").font(.footnote).foregroundColor(Brand.muted).padding(.top, 30)
                        } else {
                            ForEach(results) { p in row(p) }
                        }
                    }.padding(.horizontal, 14).padding(.bottom, 16)
                }
            }
            .padding(.top, 8).background(Brand.bg)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .sheet(item: $profileTarget) { item in
                if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
            }
        }
    }

    private func row(_ p: SocialPerson) -> some View {
        let rel = store.relationship(p.id)
        let label = rel == .friends ? "Siguiendo" : (rel == .outgoing ? "Pendiente" : "Seguir")
        return HStack(spacing: 11) {
            Button { profileTarget = IdString(id: p.id) } label: {
                HStack(spacing: 11) {
                    ScoredAvatar(emoji: p.avatar, score: store.personScore(p.id))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                        Text("@\(p.handle)").font(.caption).foregroundColor(Brand.muted)
                    }
                }
            }.buttonStyle(.plain)
            Spacer()
            Button { FX.tap(); store.followOrRequest(p.id) } label: {
                Text(label).font(.system(size: 12, weight: .heavy)).foregroundColor(rel == .none ? Color(hex: "10150a") : Brand.ink)
                    .padding(.horizontal, 14).frame(height: 32).background(rel == .none ? Brand.green : Brand.chip).clipShape(Capsule())
            }.buttonStyle(.plain)
        }
        .padding(10).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
    }
}

// MARK: - Messages

struct MessagesSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var initialTab: Int = 0
    @State private var tab = 0
    @State private var profileTarget: IdString?
    @State private var chatTarget: IdString?
    var onOpenChat: (String) -> Void
    var onOpenProfile: (String) -> Void
    var onEditAccount: () -> Void

    private var conversations: [Conversation] { store.conversations.sorted { $0.lastAt > $1.lastAt } }
    private var incoming: [SocialPerson] { store.people.filter { store.relationship($0.id) == .incoming } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Picker("", selection: $tab) {
                    Text(incoming.isEmpty ? "Amigos" : "Amigos (\(incoming.count))").tag(0)
                    Text("Mensajes").tag(1)
                }.pickerStyle(.segmented).padding(.horizontal, 16)

                ScrollView {
                    if tab == 1 { chats } else {
                        FriendsContent(onOpenChat: { chatTarget = IdString(id: $0) },
                                       onOpenProfile: { profileTarget = IdString(id: $0) },
                                       onEditAccount: onEditAccount)
                    }
                }
            }
            .padding(.top, 8)
            .background(Brand.bg)
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .onAppear { tab = initialTab }
            .task { store.loadFollowing(); store.loadConversations() }
            .sheet(item: $profileTarget) { item in
                if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
            }
        }
        // Chat dentro de Mensajes: al volver, regresas a Amigos/Mensajes (no a Social).
        .overlay {
            if let c = chatTarget {
                ChatView(personId: c.id, onOpenProfile: { _ in }, onClose: { chatTarget = nil })
                    .environmentObject(store)
                    .transition(.move(edge: .trailing))
                    .zIndex(5)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: chatTarget?.id)
    }

    private var chats: some View {
        VStack(spacing: 8) {
            if conversations.isEmpty {
                emptyState(icon: "tray", title: "Sin conversaciones", body: "Acepta un entrenamiento o escribe a un amigo.")
            } else {
                ForEach(conversations) { conv in
                    let person = store.person(conv.personId)
                    Button { chatTarget = IdString(id: conv.personId) } label: {
                        HStack(spacing: 11) {
                            Avatar(emoji: person?.avatar ?? "👤")
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(person?.name ?? "Compañero").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                                    Spacer()
                                    if let m = conv.lastMessage { Text(shortTime(m.at)).font(.caption2).foregroundColor(Brand.soft) }
                                }
                                HStack {
                                    Text(previewText(conv)).font(.system(size: 13)).foregroundColor(conv.unread > 0 ? Brand.ink : Brand.muted)
                                        .lineLimit(1)
                                    Spacer()
                                    if conv.unread > 0 {
                                        Text("\(conv.unread)").font(.system(size: 11, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                                            .padding(.horizontal, 6).frame(minWidth: 20, minHeight: 20).background(Brand.green).clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(12).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(.horizontal, 14).padding(.bottom, 16)
    }

    private func previewText(_ conv: Conversation) -> String {
        guard let m = conv.lastMessage else { return "Sin mensajes todavía" }
        return (m.fromMe ? "Tú: " : "") + m.text
    }
}

func emptyState(icon: String, title: String, body: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon).font(.system(size: 26)).foregroundColor(Brand.soft)
        Text(title).font(.system(size: 16, weight: .heavy)).foregroundColor(Color(hex: "41463c"))
        Text(body).font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
    }.padding(.top, 60).padding(.horizontal, 30).frame(maxWidth: .infinity)
}

// MARK: - Friends

struct FriendsContent: View {
    @EnvironmentObject var store: AppStore
    @State private var query = ""
    var onOpenChat: (String) -> Void
    var onOpenProfile: (String) -> Void
    var onEditAccount: () -> Void

    private func rel(_ id: String) -> RelationshipStatus { store.relationship(id) }
    private var incoming: [SocialPerson] { store.people.filter { rel($0.id) == .incoming } }
    // Con backend real, "tus amigos" = a quién sigues DE VERDAD; sin backend, demo.
    private var friends: [SocialPerson] { store.following }
    private var discover: [SocialPerson] { store.people.filter { rel($0.id) == .none || rel($0.id) == .outgoing } }
    private var results: [SocialPerson] {
        let q = query.folding(options: .diacriticInsensitive, locale: .current).lowercased().replacingOccurrences(of: "@", with: "")
        guard !q.isEmpty else { return [] }
        return store.people.filter {
            $0.name.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q) || $0.handle.contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(Brand.soft)
                TextField("Buscar por nombre o @usuario", text: $query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Brand.soft) } }
            }
            .padding(.horizontal, 12).frame(height: 44).background(Color.white).clipShape(Capsule())
            .overlay(Capsule().stroke(Brand.line))

            if !query.isEmpty {
                section("Resultados", people: results, empty: "Nadie coincide con “\(query)”.")
            } else {
                if !incoming.isEmpty { section("Solicitudes recibidas", people: incoming, empty: "") }
                if !friends.isEmpty { section("Tus amigos", people: friends, empty: "") }
                if !discover.isEmpty { section("Descubre compañeros", people: discover, empty: "") }
            }
        }.padding(.horizontal, 14).padding(.bottom, 16)
    }

    private func section(_ title: String, people: [SocialPerson], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            if people.isEmpty {
                Text(empty).font(.footnote).foregroundColor(Brand.muted)
            } else {
                ForEach(people) { person in personRow(person) }
            }
        }
    }

    private func personRow(_ person: SocialPerson) -> some View {
        let status = rel(person.id)
        return HStack(spacing: 11) {
            Button { onOpenProfile(person.id) } label: {
                HStack(spacing: 11) {
                    ScoredAvatar(emoji: person.avatar, score: store.personScore(person.id))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(person.name).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                        Text("@\(person.handle)").font(.caption).foregroundColor(Brand.muted)
                    }
                }
            }.buttonStyle(.plain)
            Spacer()
            switch status {
            case .incoming:
                Button { FX.success(sound: true); store.acceptFriendRequest(person.id) } label: { Image(systemName: "checkmark").foregroundColor(Color(hex: "10150a")) }
                    .frame(width: 36, height: 36).background(Brand.green).clipShape(RoundedRectangle(cornerRadius: 10))
                Button { FX.warning(); store.rejectFriendRequest(person.id) } label: { Image(systemName: "xmark").foregroundColor(Color(hex: "a73232")) }
                    .frame(width: 36, height: 36).background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 10))
            case .friends:
                Button { FX.tap(); onOpenChat(person.id) } label: { Label("Mensaje", systemImage: "message.fill").font(.system(size: 12, weight: .heavy)) }
            case .outgoing:
                Button { FX.tap(); store.followOrRequest(person.id) } label: {
                    Label("Pendiente", systemImage: "clock").font(.system(size: 12, weight: .heavy)).foregroundColor(Brand.ink)
                }
            case .none:
                Button { FX.tap(); store.followOrRequest(person.id) } label: { Label("Seguir", systemImage: "person.badge.plus").font(.system(size: 12, weight: .heavy)) }
            }
        }
        .padding(10).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
    }
}

// MARK: - Chat

struct ChatView: View {
    @EnvironmentObject var store: AppStore
    let personId: String
    var onOpenProfile: (String) -> Void
    var onClose: () -> Void = {}
    @State private var draft = ""
    @State private var profileTarget: IdString?
    @State private var realMessages: [ChatMessage] = []
    @State private var realMode = false

    private var person: SocialPerson? { store.person(personId) }
    private var conversation: Conversation? { store.conversations.first { $0.personId == personId } }
    private var messages: [ChatMessage] { realMode ? realMessages : (conversation?.messages ?? []) }

    /// Carga los mensajes REALES con este usuario desde el servidor.
    private func loadReal() async {
        guard BackendConfig.isConfigured, let uid = UUID(uuidString: personId) else { return }
        realMode = true
        let rows = (try? await Backend.shared.fetchMessages(with: uid)) ?? []
        let me = Backend.shared.currentUserId?.uuidString.lowercased()
        realMessages = rows.map { r in
            ChatMessage(id: r.id, fromMe: r.sender_id.lowercased() == me,
                        text: r.text, at: BackendDate.parse(r.created_at) ?? Date())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Button { onClose() } label: { Image(systemName: "arrow.left").font(.system(size: 18, weight: .semibold)).foregroundColor(Brand.ink) }
                Button { profileTarget = IdString(id: personId) } label: {
                    HStack(spacing: 11) {
                        Avatar(emoji: person?.avatar ?? "👤")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(person?.name ?? "Compañero").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                            Text(person?.gym ?? "").font(.caption).foregroundColor(Brand.muted)
                        }
                    }
                }.buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Brand.bg).overlay(Divider(), alignment: .bottom)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        if !messages.isEmpty {
                            ForEach(messages) { m in bubble(m).id(m.id) }
                        } else {
                            emptyState(icon: "message", title: "Sin mensajes", body: "Escribe el primer mensaje.")
                        }
                    }.padding(16)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    store.markConversationRead(personId)
                }
            }

            HStack(spacing: 8) {
                TextField("Escribe un mensaje", text: $draft)
                    .padding(.horizontal, 16).frame(height: 46).background(Color.white).clipShape(Capsule())
                    .overlay(Capsule().stroke(Brand.line))
                Button { send() } label: {
                    Image(systemName: "paperplane.fill").foregroundColor(Color(hex: "10150a"))
                        .frame(width: 46, height: 46).background(Brand.green).clipShape(Circle())
                }.disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Brand.bg).overlay(Divider(), alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.bg.ignoresSafeArea())
        .onAppear { store.openConversation(personId) }
        .task {
            await loadReal()
            // Sondeo ligero para ver los mensajes nuevos del otro (sin websockets).
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                await loadReal()
            }
        }
        .sheet(item: $profileTarget) { item in
            if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
        }
    }

    private func send() {
        let t = draft.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        FX.tap()
        if realMode, let uid = UUID(uuidString: personId) {
            realMessages.append(ChatMessage(id: UUID().uuidString, fromMe: true, text: t, at: Date()))
            Task { try? await Backend.shared.sendMessage(to: uid, text: t) }
        } else {
            store.sendMessage(personId, draft, activeConversation: conversationId(personId))
        }
        draft = ""
    }

    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.fromMe { Spacer(minLength: 50) }
            VStack(alignment: m.fromMe ? .trailing : .leading, spacing: 2) {
                Text(m.text).font(.system(size: 15)).foregroundColor(m.fromMe ? Color(hex: "10150a") : Color(hex: "2c3127"))
                Text(shortTime(m.at)).font(.system(size: 10, weight: .semibold)).opacity(0.5)
            }
            .padding(.horizontal, 11).padding(.vertical, 8)
            .background(m.fromMe ? Brand.greenSoft : Brand.chip)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            if !m.fromMe { Spacer(minLength: 50) }
        }
    }
}

// MARK: - Notifications

struct NotificationsSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var profileTarget: IdString?
    var onOpenChat: (String) -> Void
    var onOpenFriends: () -> Void

    private var sorted: [AppNotification] { store.notifications.sorted { $0.at > $1.at } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if sorted.isEmpty {
                        emptyState(icon: "bell", title: "Sin notificaciones", body: "Aquí verás solicitudes y entrenos aceptados.")
                    } else {
                        ForEach(sorted) { n in row(n) }
                    }
                }.padding(14)
            }
            .background(Brand.bg)
            .navigationTitle("Notificaciones").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $profileTarget) { item in
                if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
            }
        }
        // Al abrir, dejan de ser "nuevas" (ya las has visto), como en Instagram.
        .onAppear { store.markAllNotificationsRead() }
    }

    private func row(_ n: AppNotification) -> some View {
        let isPendingRequest = n.type == .friendRequest && n.personId.map { store.relationship($0) == .incoming } ?? false
        return VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 11) {
                leadingIcon(n)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(n.title).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                        Spacer()
                        Text(relativeTime(n.at)).font(.caption2).foregroundColor(Brand.soft)
                    }
                    Text(n.body).font(.footnote).foregroundColor(Brand.muted)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                store.markNotificationRead(n.id)
                if let pid = n.personId {
                    if n.conversationId != nil { dismiss(); onOpenChat(pid) }
                    else { profileTarget = IdString(id: pid) }
                }
            }
            if isPendingRequest, let pid = n.personId {
                HStack(spacing: 8) {
                    Button { FX.success(); store.acceptFriendRequest(pid) } label: {
                        Text("Aceptar").font(.system(size: 14, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                            .frame(maxWidth: .infinity).frame(height: 38).background(Brand.green).clipShape(Capsule())
                    }.buttonStyle(.plain)
                    Button { FX.warning(); store.rejectFriendRequest(pid) } label: {
                        Text("Rechazar").font(.system(size: 14, weight: .heavy)).foregroundColor(Color(hex: "a73232"))
                            .frame(maxWidth: .infinity).frame(height: 38).background(Brand.redSoft).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Brand.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
    }

    /// Foto de perfil de la persona (con badge del tipo) si la notificación es de alguien; si no, icono genérico.
    @ViewBuilder
    private func leadingIcon(_ n: AppNotification) -> some View {
        if let pid = n.personId, let p = store.person(pid) {
            ZStack(alignment: .bottomTrailing) {
                Avatar(emoji: p.avatar, size: 42)
                Image(systemName: icon(n.type)).font(.system(size: 9, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                    .frame(width: 18, height: 18).background(Brand.green).clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 1.5)).offset(x: 3, y: 3)
            }
        } else {
            Image(systemName: icon(n.type)).font(.system(size: 15))
                .frame(width: 42, height: 42).background(Brand.greenSoft).foregroundColor(Color(hex: "10150a")).clipShape(Circle())
        }
    }

    private func icon(_ t: NotificationType) -> String {
        switch t {
        case .friendRequest: return "person.badge.plus"
        case .friendAccepted: return "checkmark"
        case .trainingAccepted: return "dumbbell.fill"
        case .newFollower: return "person.fill.badge.plus"
        }
    }
}

// MARK: - Friend profile

struct FriendProfileView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let person: SocialPerson
    @State private var daySheet: DayPayload?
    @State private var detailSession: WorkoutSession?
    @State private var followList: FollowListData?
    @State private var realSessions: [WorkoutSession]?
    @State private var realFollowers: Int?
    @State private var realFollowing: Int?

    /// Carga los datos REALES del usuario (sus sesiones + contadores) cuando hay backend.
    private func loadReal() async {
        guard BackendConfig.isConfigured, UUID(uuidString: person.id) != nil else { return }
        let s = (try? await Backend.shared.fetchUserSessions(person.id)) ?? []
        realSessions = s.map { $0.asWorkoutSession }
        if let c = try? await Backend.shared.followCounts(person.id) {
            realFollowers = c.followers; realFollowing = c.following
        }
    }

    /// Historial (para el Gym Score) a partir de sus sesiones reales.
    private func historyFromSessions(_ sessions: [WorkoutSession]) -> [HistoryEntry] {
        var out: [HistoryEntry] = []
        for s in sessions {
            for ex in s.items ?? [] {
                let logs = ex.logs ?? []
                let vol = logs.isEmpty ? Double(ex.sets) * Double(ex.reps) * ex.weight
                                       : logs.reduce(0) { $0 + Double($1.reps) * $1.weight }
                out.append(HistoryEntry(id: "\(s.id)-\(ex.name)", exerciseName: ex.name, day: "",
                    status: .done, sets: ex.sets, reps: ex.reps, weight: ex.weight, volume: vol,
                    xp: 0, completedAt: s.date, sessionId: s.id))
            }
        }
        return out
    }

    var body: some View {
        // Usuario real: sus datos del servidor. Sin backend: demo determinista.
        let history: [HistoryEntry] = realSessions.map { historyFromSessions($0) } ?? buildFriendHistory(person)
        let score = GymScoreEngine.calculate(history)
        let sessionsList: [WorkoutSession] = realSessions ?? friendSessions(history)
        // Cuenta privada y aún no la sigues → contenido oculto (estilo Instagram).
        let locked = person.isPrivate && store.relationship(person.id) != .friends

        return NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header(entrenos: sessionsList.count, locked: locked)
                    if locked {
                        privateNotice
                    } else {
                        HStack(spacing: 10) {
                            statTile("GYM SCORE", "\(score.total)")
                            statTile("RACHA", "\(score.trainingDays) 🔥")
                        }
                        PanelCard {
                            Text(score.tier).font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                                .padding(.horizontal, 10).padding(.vertical, 3).background(Brand.greenSoft).clipShape(Capsule())
                            ScoreBarView(label: "Fuerza", value: score.strength)
                            ScoreBarView(label: "Constancia", value: score.consistency)
                            ScoreBarView(label: "Progreso", value: score.progression)
                            ScoreBarView(label: "Volumen", value: score.volume)
                            ScoreBarView(label: "Variedad", value: score.variety)
                        }
                        TrainingCalendarView(sessions: sessionsList) { date, day in
                            daySheet = DayPayload(id: date, date: date, sessions: day)
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ENTRENOS · \(sessionsList.count)").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(sessionsList) { s in sessionPostCard(s) }
                        }
                    }
                }.padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if BackendConfig.isConfigured, UUID(uuidString: person.id) != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) { reportUser() } label: { Label("Reportar usuario", systemImage: "flag") }
                            Button(role: .destructive) { blockUser() } label: { Label("Bloquear a \(person.name)", systemImage: "hand.raised") }
                        } label: { Image(systemName: "ellipsis").foregroundColor(Brand.ink) }
                    }
                }
            }
            .sheet(item: $daySheet) { DaySessionsSheet(date: $0.date, sessions: $0.sessions, author: person).environmentObject(store) }
            .sheet(item: $detailSession) { s in
                ActivityDetailView(item: personActivityData(s, person)).environmentObject(store)
            }
            .sheet(item: $followList) { FollowListSheet(title: $0.title, people: $0.people).environmentObject(store) }
        }
        .task { await loadReal() }
    }

    private func reportUser() {
        FX.tap()
        Task { try? await Backend.shared.report(targetType: "user", targetId: person.id, reportedUserId: person.id, reason: "reported from profile") }
    }
    private func blockUser() {
        FX.tap()
        Task {
            if let uid = UUID(uuidString: person.id) { try? await Backend.shared.unfollow(uid) }
            try? await Backend.shared.blockUser(person.id)
            store.loadFollowing()
        }
        dismiss()
    }

    private func sessionPostCard(_ s: WorkoutSession) -> some View {
        Button { FX.tap(); detailSession = s } label: {
            PanelCard {
                HStack(spacing: 10) {
                    WorkoutTypeBadge(size: .compact)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                        Text(relativeTime(s.date)).font(.system(size: 13)).foregroundColor(Brand.soft)
                    }
                    Spacer()
                    if !s.verified {
                        Image(systemName: "shield.slash").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.soft)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                }
                WorkoutStatStrip(stats: WorkoutStatStrip.metrics(time: durationText(s.elapsed), sets: s.sets,
                                                 exercises: s.exercises, ppm: s.avgHeartRate), style: .compact)
            }
        }.buttonStyle(.plain)
    }

    private func durationText(_ s: Int) -> String {
        let m = s / 60
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(max(1, m)) min"
    }

    private var privateNotice: some View {
        PanelCard {
            HStack { Spacer(); Image(systemName: "lock.fill").font(.system(size: 30)).foregroundColor(Brand.soft); Spacer() }
                .padding(.top, 6)
            Text("Esta cuenta es privada").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Envía una solicitud y, cuando \(person.name) la acepte, podrás ver su Gym Score y sus entrenos.")
                .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
    }

    private func header(entrenos: Int, locked: Bool) -> some View {
        VStack(spacing: 12) {
            ScoredAvatar(emoji: person.avatar, score: store.personScore(person.id), size: 84)
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Text(person.name).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                    if person.isPrivate { Image(systemName: "lock.fill").font(.system(size: 13)).foregroundColor(Brand.soft) }
                }
                Text("@\(person.handle)").font(.subheadline).foregroundColor(Brand.muted)
            }
            profileCountsRow(entrenos: entrenos,
                             seguidores: realFollowers ?? (deterministicCount(person.id, salt: 7, lo: 40, hi: 1500) + (store.relationship(person.id) == .friends ? 1 : 0)),
                             siguiendo: realFollowing ?? deterministicCount(person.id, salt: 13, lo: 30, hi: 700),
                             locked: locked,
                             // Con backend real, las listas de seguidores/seguidos ajenas no son públicas: solo el número.
                             onSeguidores: { if !BackendConfig.isConfigured { followList = FollowListData(title: "Seguidores", people: demoFollowList(store, seed: person.id, salt: 7, exclude: person.id)) } },
                             onSiguiendo: { if !BackendConfig.isConfigured { followList = FollowListData(title: "Siguiendo", people: demoFollowList(store, seed: person.id, salt: 13, exclude: person.id)) } })
            followButton
        }
    }

    @ViewBuilder
    private var followButton: some View {
        let rel = store.relationship(person.id)
        let label = rel == .friends ? "Siguiendo" : (rel == .outgoing ? "Pendiente" : "Seguir")
        Button { FX.tap(); store.followOrRequest(person.id) } label: {
            HStack(spacing: 6) {
                if rel == .friends { Image(systemName: "checkmark") }
                else if rel == .outgoing { Image(systemName: "clock") }
                Text(label).font(.system(size: 15, weight: .heavy))
            }
            .foregroundColor(rel == .none ? Color(hex: "10150a") : Brand.ink)
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(rel == .none ? Brand.green : Brand.chip)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            Text(value).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
        }.frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
    }

    private func friendSessions(_ history: [HistoryEntry]) -> [WorkoutSession] {
        let groups = Dictionary(grouping: history) { $0.sessionId ?? $0.id }
        return groups.map { (sid, entries) -> WorkoutSession in
            let date = entries.map { $0.completedAt }.max() ?? Date()
            let sets = entries.reduce(0) { $0 + $1.sets }
            var seed: UInt64 = 0
            for ch in sid.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
            let avgHR = 118 + Int(seed % 42)
            let maxHR = avgHR + 12 + Int((seed >> 5) % 22)
            let items = entries.map { e -> SessionExercise in
                let logs = (0..<max(1, e.sets)).map { i in
                    SetLog(reps: e.reps, weight: max(0, e.weight + Double(i) * 2.5 - Double(max(0, e.sets - 1)) * 1.25))
                }
                return SessionExercise(name: e.exerciseName, sets: e.sets, reps: e.reps, weight: e.weight, logs: logs)
            }
            return WorkoutSession(id: sid, name: Self.sessionTitle(entries), note: "", date: date,
                                  elapsed: entries.count * 240 + sets * 40, exercises: entries.count, sets: sets,
                                  volume: entries.reduce(0) { $0 + $1.volume }, xp: 0, photoData: nil,
                                  visibility: .all, items: items, avgHeartRate: avgHR, maxHeartRate: maxHR)
        }.sorted { $0.date > $1.date }
    }

    private static func sessionTitle(_ entries: [HistoryEntry]) -> String {
        var counts: [String: Int] = [:]
        for e in entries { counts[GymScoreEngine.pattern(for: e.exerciseName).group, default: 0] += 1 }
        let top = counts.max { $0.value < $1.value }?.key ?? "accesorio"
        let names = ["pierna": "Pierna", "bisagra": "Cadena posterior", "empuje": "Empuje",
                     "tiron": "Tirón", "condicion": "Cardio & core", "accesorio": "Full body"]
        return names[top] ?? "Entreno"
    }
}

// MARK: - My profile (vista pública de tu propio perfil)

struct MeProfileView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var daySheet: DayPayload?
    @State private var detailSession: WorkoutSession?
    @State private var showSettings = false
    @State private var followList: FollowListData?
    @State private var showLogros = false
    @State private var showShop = false
    @State private var showTitles = false

    var body: some View {
        let score = store.gymScore
        let sessionsList = store.sessions.sorted { $0.date > $1.date }
        return NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header(entrenos: sessionsList.count)
                    HStack(spacing: 10) {
                        statTile("GYM SCORE", "\(score.total)")
                        statTile("RACHA", "\(store.player.streak) 🔥")
                    }
                    GamificationCard(onOpenLogros: { showLogros = true },
                                     onOpenShop: { showShop = true },
                                     onOpenTitles: { showTitles = true })
                    PanelCard {
                        Text(score.tier).font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                            .padding(.horizontal, 10).padding(.vertical, 3).background(Brand.greenSoft).clipShape(Capsule())
                        ScoreBarView(label: "Fuerza", value: score.strength)
                        ScoreBarView(label: "Constancia", value: score.consistency)
                        ScoreBarView(label: "Progreso", value: score.progression)
                        ScoreBarView(label: "Volumen", value: score.volume)
                        ScoreBarView(label: "Variedad", value: score.variety)
                    }
                    TrainingCalendarView(sessions: sessionsList) { date, day in
                        daySheet = DayPayload(id: date, date: date, sessions: day)
                    }
                    if sessionsList.isEmpty {
                        Text("Aún no has guardado entrenos. ¡Registra tu primera sesión!")
                            .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity).padding(.top, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ENTRENOS · \(sessionsList.count)").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(sessionsList) { s in sessionPostCard(s) }
                        }
                    }
                }.padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { FX.tap(); showSettings = true } label: { Image(systemName: "gearshape").foregroundColor(Brand.ink) } } }
            .sheet(item: $daySheet) { DaySessionsSheet(date: $0.date, sessions: $0.sessions).environmentObject(store) }
            .sheet(item: $detailSession) { s in ActivityDetailView(item: meActivityData(s, store)).environmentObject(store) }
            .sheet(item: $followList) { FollowListSheet(title: $0.title, people: $0.people).environmentObject(store) }
            .sheet(isPresented: $showSettings) { SettingsView().environmentObject(store) }
            .sheet(isPresented: $showLogros) { LogrosView().environmentObject(store) }
            .sheet(isPresented: $showShop) { ShopView().environmentObject(store) }
            .sheet(isPresented: $showTitles) { TitlesView().environmentObject(store) }
            .onChange(of: store.account?.handle) { _ in if store.account == nil { dismiss() } }
        }
    }

    @ViewBuilder
    private var socialPills: some View {
        let links = socialLinks
        if !links.isEmpty {
            HStack(spacing: 8) {
                ForEach(links, id: \.url) { l in
                    Link(destination: l.url) {
                        HStack(spacing: 5) {
                            Text(l.title).font(.system(size: 11, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                            Text("@\(l.handle)").font(.system(size: 11, weight: .semibold)).foregroundColor(Brand.soft).lineLimit(1)
                        }
                        .padding(.horizontal, 11).frame(height: 30)
                        .background(Brand.chip).clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var socialLinks: [(title: String, handle: String, url: URL)] {
        var out: [(title: String, handle: String, url: URL)] = []
        if let ig = store.profile.instagram, !ig.isEmpty, let u = URL(string: "https://instagram.com/\(ig)") {
            out.append(("Instagram", ig, u))
        }
        if let tk = store.profile.tiktok, !tk.isEmpty, let u = URL(string: "https://www.tiktok.com/@\(tk)") {
            out.append(("TikTok", tk, u))
        }
        if let tw = store.profile.twitter, !tw.isEmpty, let u = URL(string: "https://x.com/\(tw)") {
            out.append(("X", tw, u))
        }
        return out
    }

    private func header(entrenos: Int) -> some View {
        VStack(spacing: 12) {
            ScoredAvatar(account: store.account, score: store.gymScore.total, size: 84)
                .overlay(AvatarFrame(frameId: store.equippedFrame, size: 84))
            VStack(spacing: 6) {
                if let title = store.equippedTitle {
                    Text(title).font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "9b6cf2"))
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Color(hex: "9b6cf2").opacity(0.12)).clipShape(Capsule())
                }
                HStack(spacing: 6) {
                    Text(store.account?.name ?? "Tú").font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                    if store.profile.isPrivate { Image(systemName: "lock.fill").font(.system(size: 13)).foregroundColor(Brand.soft) }
                }
                Text("@\(store.account?.handle ?? "tu_usuario")").font(.subheadline).foregroundColor(Brand.muted)
                socialPills
            }
            profileCountsRow(entrenos: entrenos,
                             seguidores: BackendConfig.isConfigured ? store.followerPeople.count : deterministicCount(store.account?.handle ?? "me", salt: 7, lo: 40, hi: 1500),
                             siguiendo: store.following.count,
                             onSeguidores: {
                                 let list = BackendConfig.isConfigured ? store.followerPeople : demoFollowList(store, seed: store.account?.handle ?? "me", salt: 7, exclude: nil)
                                 followList = FollowListData(title: "Seguidores", people: list)
                             },
                             onSiguiendo: { followList = FollowListData(title: "Siguiendo", people: store.following) })
        }
    }

    private func sessionPostCard(_ s: WorkoutSession) -> some View {
        Button { FX.tap(); detailSession = s } label: {
            PanelCard {
                HStack(spacing: 10) {
                    WorkoutTypeBadge(size: .compact)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                        Text(relativeTime(s.date)).font(.system(size: 13)).foregroundColor(Brand.soft)
                    }
                    Spacer()
                    if !s.verified {
                        Image(systemName: "shield.slash").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.soft)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                }
                WorkoutStatStrip(stats: WorkoutStatStrip.metrics(time: durationText(s.elapsed), sets: s.sets,
                                                 exercises: s.exercises, ppm: s.avgHeartRate), style: .compact)
            }
        }.buttonStyle(.plain)
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            Text(value).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
        }.frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
    }

    private func durationText(_ s: Int) -> String {
        let m = s / 60
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(max(1, m)) min"
    }
}

// MARK: - Account setup

struct AccountSetupView: View {
    @EnvironmentObject var store: AppStore
    var allowCancel: Bool
    var onCancel: () -> Void
    @State private var name = ""
    @State private var handle = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoData: Data?
    @ObservedObject private var health = HealthManager.shared

    private var normalized: String { normalizeHandle(handle) }
    private var taken: [String] { store.people.map { $0.handle } }
    private var handleError: String? {
        if normalized.count < 3 { return "Mínimo 3 caracteres" }
        if taken.contains(normalized) { return "Ese usuario ya existe" }
        return nil
    }
    private var canSubmit: Bool { name.trimmingCharacters(in: .whitespaces).count >= 2 && handleError == nil }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("FORGE LOOP").font(.caption2).fontWeight(.heavy).foregroundColor(Color(hex: "4b6211"))
                    Text(store.account == nil ? "Crea tu cuenta" : "Editar cuenta").font(.system(size: 26, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("Elige tu nombre y un @usuario único para que tus amigos te encuentren.").font(.footnote).foregroundColor(Brand.muted)
                }
                HStack {
                    Spacer()
                    PhotoPickerLabel(item: $pickerItem, onPicked: { photoData = $0 }) {
                        ZStack(alignment: .bottomTrailing) {
                            if let d = photoData, let ui = UIImage(data: d) {
                                Image(uiImage: ui).resizable().scaledToFill().frame(width: 84, height: 84).clipShape(Circle())
                            } else {
                                Avatar(emoji: "📷", size: 84)
                            }
                            Image(systemName: "camera.fill").font(.system(size: 12, weight: .bold))
                                .foregroundColor(Brand.ink).padding(7).background(Brand.green).clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                field("Nombre", text: $name, placeholder: "Tu nombre")
                VStack(alignment: .leading, spacing: 5) {
                    Text("USUARIO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    HStack(spacing: 2) {
                        Text("@").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.soft)
                        TextField("tu_usuario", text: $handle).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12).frame(height: 46).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line))
                    if !normalized.isEmpty, let err = handleError {
                        Text(err).font(.caption).foregroundColor(Color(hex: "c14b46"))
                    } else if !normalized.isEmpty {
                        Text("@\(normalized) disponible").font(.caption).foregroundColor(Color(hex: "4b8a1f"))
                    }
                }
                Button {
                    let isNew = store.account == nil
                    var acc = store.account ?? Account(name: "", handle: "")
                    acc.name = name.trimmingCharacters(in: .whitespaces)
                    acc.handle = normalized
                    if let photoData { acc.photoData = photoData }
                    FX.success(sound: true)
                    store.saveAccount(acc)
                    if isNew && health.isAvailable && !health.connected { Task { await health.connect() } }
                    onCancel()
                } label: { Text(store.account == nil ? "Empezar" : "Guardar") }
                    .buttonStyle(PrimaryButtonStyle(enabled: canSubmit)).disabled(!canSubmit)
                if allowCancel { Button("Cancelar") { onCancel() }.frame(maxWidth: .infinity) }
            }
            .padding(20).background(Brand.bg).clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            .padding(22)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.55).ignoresSafeArea())
        .onAppear {
            name = store.account?.name ?? ""
            handle = store.account?.handle ?? ""
            photoData = store.account?.photoData
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            TextField(placeholder, text: text)
                .padding(.horizontal, 12).frame(height: 46).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line))
        }
    }
}
