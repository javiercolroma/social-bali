import SwiftUI
import PhotosUI
import Supabase

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
        Text(LocalizedStringKey(label)).font(.caption2).foregroundColor(Brand.muted)
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
    private var incoming: [SocialPerson] { store.incomingRequestPeople + store.people.filter { store.relationship($0.id) == .incoming } }
    /// Nº de CHATS con mensajes nuevos (no mensajes totales) — para el circulito verde.
    private var unreadChats: Int { store.conversations.filter { $0.unread > 0 }.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // Selector propio (el Picker segmentado no admite badges): "Mensajes" lleva
                // un circulito verde con el nº de chats con mensajes nuevos, estilo WhatsApp.
                HStack(spacing: 6) {
                    switchTab(0, incoming.isEmpty ? "Amigos" : "Amigos (\(incoming.count))")
                    switchTab(1, "Mensajes", badge: unreadChats)
                }.padding(.horizontal, 16)

                SlidingPages(index: tab) {
                    ScrollView {
                        FriendsContent(onOpenChat: { chatTarget = IdString(id: $0) },
                                       onOpenProfile: { profileTarget = IdString(id: $0) },
                                       onEditAccount: onEditAccount)
                    }
                } second: {
                    ScrollView { chats }
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

    /// Pestaña del selector Amigos/Mensajes, con circulito verde de chats sin leer.
    private func switchTab(_ idx: Int, _ label: String, badge: Int = 0) -> some View {
        let active = tab == idx
        return Button { FX.selection(); tab = idx } label: {
            HStack(spacing: 6) {
                Text(label).font(.system(size: 14, weight: .heavy))
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                        .padding(.horizontal, 5).frame(minWidth: 18).frame(height: 18)
                        .background(Brand.green).clipShape(Capsule())
                        .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                }
            }
            .foregroundColor(active ? Color(hex: "10150a") : Brand.soft)
            .frame(maxWidth: .infinity).frame(height: 40)
            .background(active ? Brand.green : Brand.chip)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
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
        return (m.fromMe ? "Tú: " : "") + m.preview
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

    @State private var realResults: [SocialPerson] = []
    @State private var searchTask: Task<Void, Never>?

    private func rel(_ id: String) -> RelationshipStatus { store.relationship(id) }
    // Solicitudes recibidas: reales (cuentas privadas, del servidor) + demo.
    private var incoming: [SocialPerson] { store.incomingRequestPeople + store.people.filter { rel($0.id) == .incoming } }
    // Con backend real, "tus amigos" = a quién sigues DE VERDAD; sin backend, demo.
    private var friends: [SocialPerson] { store.following }
    private var discover: [SocialPerson] { store.people.filter { rel($0.id) == .none || rel($0.id) == .outgoing } }
    private var results: [SocialPerson] {
        // Con backend: resultados REALES del servidor (antes solo buscaba en la lista demo,
        // vacía en producción → "no aparece nadie" aunque sí saliera en sugerencias).
        if BackendConfig.isConfigured { return realResults }
        let q = query.folding(options: .diacriticInsensitive, locale: .current).lowercased().replacingOccurrences(of: "@", with: "")
        guard !q.isEmpty else { return [] }
        return store.people.filter {
            $0.name.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q) || $0.handle.contains(q)
        }
    }

    /// Búsqueda real con debounce (300 ms), cancelando la anterior.
    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
        guard BackendConfig.isConfigured, !q.isEmpty else { realResults = []; return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            let rows = (try? await Backend.shared.searchProfiles(q)) ?? []
            if Task.isCancelled { return }
            let me = await Backend.shared.currentUserIdAsync()
            realResults = AppStore.asPeople(rows.filter { $0.id != me })
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(Brand.soft)
                TextField("Buscar por nombre o @usuario", text: $query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onChange(of: query) { _ in scheduleSearch() }
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
                inviteCard   // cold start: trae a tu gente al gimnasio
            }
        }.padding(.horizontal, 14).padding(.bottom, 16)
    }

    /// Invita a tus amigos (share sheet). El mensaje lleva tu @usuario y un enlace a la
    /// página de invitación: si tu amigo YA tiene la app, el botón «Abrir» salta directo a
    /// tu perfil (deep link forgeloop://user/...); si no, le guía a descargarla.
    private var inviteCard: some View {
        let handle = store.account?.handle ?? ""
        let url = "https://javiercolroma.github.io/gym-swipe-ios/invite.html" + (handle.isEmpty ? "" : "?u=\(handle)")
        return ShareLink(item: "Entreno con Forge Loop 💪 Sígueme, soy @\(handle.isEmpty ? "forgeloop" : handle). Únete aquí: \(url)") {
            HStack(spacing: 11) {
                ZStack {
                    Circle().fill(Brand.greenSoft).frame(width: 40, height: 40)
                    Image(systemName: "person.badge.plus").font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "10150a"))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Invita a tus amigos").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("Entrenar acompañado engancha el doble.").font(.caption).foregroundColor(Brand.muted)
                }
                Spacer()
                Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.soft)
            }
            .padding(10).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
        }
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
                    ScoredAvatar(emoji: person.avatar, avatarURL: person.avatarURL, score: store.personScore(person.id))
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
    @State private var channel: RealtimeChannelV2?
    @State private var showWorkoutPicker = false
    @State private var pendingWorkout: WorkoutTemplate?   // entreno adjunto pendiente de enviar

    /// Suscripción Realtime: los mensajes del otro llegan al instante (sin esperar al sondeo).
    private func subscribeRealtime() async {
        guard BackendConfig.isConfigured, let client = Backend.shared.client,
              let me = await Backend.shared.currentUserIdAsync() else { return }
        let ch = client.channel("chat:\(personId)")
        let inserts = ch.postgresChange(InsertAction.self, schema: "public", table: "messages",
                                        filter: "recipient_id=eq.\(me.uuidString)")
        await ch.subscribe()
        channel = ch
        for await change in inserts {
            guard let row = try? change.decodeRecord(as: MessageRow.self, decoder: JSONDecoder()),
                  row.sender_id.lowercased() == personId.lowercased() else { continue }
            let msg = ChatMessage(id: row.id, fromMe: false, text: row.text,
                                  at: BackendDate.parse(row.created_at) ?? Date())
            if !realMessages.contains(where: { $0.id == msg.id }) {
                realMessages.append(msg)
                store.appendLocalMessage(personId, msg)   // último mensaje recibido en la lista
            }
        }
    }

    private func unsubscribe() async {
        if let ch = channel, let client = Backend.shared.client { await client.removeChannel(ch) }
        channel = nil
    }

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

            VStack(spacing: 8) {
                // Adjunto pendiente: el entreno elegido se coloca aquí (no se envía hasta pulsar enviar).
                if let w = pendingWorkout {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.fill").font(.system(size: 14)).foregroundColor(Color(hex: "4b6211"))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Entreno adjunto").font(.system(size: 10, weight: .heavy)).foregroundColor(Brand.soft)
                            Text(L10n.x(w.name)).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                        }
                        Spacer()
                        Button { withAnimation { pendingWorkout = nil } } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundColor(Brand.soft)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Brand.greenSoft.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                HStack(spacing: 8) {
                    Button { FX.tap(); showWorkoutPicker = true } label: {
                        Image(systemName: "plus").font(.system(size: 20, weight: .semibold)).foregroundColor(Brand.ink)
                            .frame(width: 46, height: 46).background(Brand.chip).clipShape(Circle())
                    }
                    TextField("Escribe un mensaje", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                        .padding(.horizontal, 16).frame(height: 46).background(Color.white).clipShape(Capsule())
                        .overlay(Capsule().stroke(Brand.line))
                    Button { send() } label: {
                        Image(systemName: "paperplane.fill").foregroundColor(Color(hex: "10150a"))
                            .frame(width: 46, height: 46).background(Brand.green).clipShape(Circle())
                    }.disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty && pendingWorkout == nil)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Brand.bg).overlay(Divider(), alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.bg.ignoresSafeArea())
        .onAppear { store.openConversation(personId) }
        .task {
            await loadReal()
            Task { await subscribeRealtime() }   // mensajes del otro AL INSTANTE
            // Fallback: sondeo lento por si el Realtime no conecta.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                await loadReal()
            }
        }
        .onDisappear { Task { await unsubscribe() } }
        .sheet(item: $profileTarget) { item in
            if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
        }
        .sheet(isPresented: $showWorkoutPicker) {
            // Elegir un entreno lo ADJUNTA al mensaje (no lo envía); se manda al pulsar enviar.
            ShareWorkoutPicker { w in showWorkoutPicker = false; withAnimation { pendingWorkout = w } }.environmentObject(store)
        }
    }

    /// Envía cualquier texto por el camino correcto (real o local) y lo refleja al instante.
    private func deliver(_ text: String) {
        if realMode, let uid = UUID(uuidString: personId) {
            let msg = ChatMessage(id: UUID().uuidString, fromMe: true, text: text, at: Date())
            realMessages.append(msg)
            store.appendLocalMessage(personId, msg)   // refleja el último mensaje en la lista
            Task { try? await Backend.shared.sendMessage(to: uid, text: text) }
        } else {
            store.sendMessage(personId, text, activeConversation: conversationId(personId))
        }
    }

    private func send() {
        let t = draft.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty || pendingWorkout != nil else { return }
        FX.tap()
        if let w = pendingWorkout { deliver(WorkoutShare.encode(w)); pendingWorkout = nil }
        if !t.isEmpty { deliver(t); draft = "" }
    }

    @ViewBuilder
    private func bubble(_ m: ChatMessage) -> some View {
        if let w = m.sharedWorkout {
            HStack {
                if m.fromMe { Spacer(minLength: 40) }
                SharedWorkoutCard(workout: w, fromMe: m.fromMe, at: m.at)
                if !m.fromMe { Spacer(minLength: 40) }
            }
        } else {
            HStack {
                if m.fromMe { Spacer(minLength: 50) }
                VStack(alignment: m.fromMe ? .trailing : .leading, spacing: 2) {
                    Text(m.text).font(.system(size: 15)).foregroundColor(m.fromMe ? Color(hex: "10150a") : Color(hex: "2c3127"))
                    HStack(spacing: 3) {
                        Text(shortTime(m.at)).font(.system(size: 10, weight: .semibold)).opacity(0.5)
                        if m.fromMe {
                            // Doble check estilo WhatsApp (enviado; sin confirmación de lectura).
                            ZStack {
                                Image(systemName: "checkmark").offset(x: -2.5)
                                Image(systemName: "checkmark").offset(x: 1.5)
                            }.font(.system(size: 8, weight: .bold)).opacity(0.55)
                        }
                    }
                }
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(m.fromMe ? Brand.greenSoft : Brand.chip)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                if !m.fromMe { Spacer(minLength: 50) }
            }
        }
    }
}

/// Tarjeta de entreno compartido dentro del chat. Quien la recibe puede añadirlo a su plan.
struct SharedWorkoutCard: View {
    @EnvironmentObject var store: AppStore
    let workout: WorkoutTemplate
    let fromMe: Bool
    let at: Date
    @State private var added = false
    @State private var showPreview = false
    @State private var showSave = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Brand.greenSoft).frame(width: 40, height: 40)
                    Image(systemName: "dumbbell.fill").font(.system(size: 17, weight: .bold)).foregroundColor(Color(hex: "10150a"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("ENTRENO COMPARTIDO").font(.system(size: 9, weight: .heavy)).foregroundColor(Brand.soft).tracking(0.5)
                    Text(L10n.x(workout.name)).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
            }
            Text("\(workout.exercises.count) ejercicios · \(workout.block)")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.muted)
            // Vista rápida de los primeros ejercicios.
            VStack(alignment: .leading, spacing: 3) {
                ForEach(workout.exercises.prefix(4)) { e in
                    HStack(spacing: 6) {
                        Circle().fill(Brand.line).frame(width: 4, height: 4)
                        Text(L10n.x(e.name)).font(.system(size: 12)).foregroundColor(Brand.muted).lineLimit(1)
                        Spacer()
                        Text("\(e.sets)×\(e.reps)").font(.system(size: 11, weight: .semibold)).foregroundColor(Brand.soft)
                    }
                }
                if workout.exercises.count > 4 {
                    Text("+\(workout.exercises.count - 4) más").font(.system(size: 11, weight: .semibold)).foregroundColor(Brand.soft)
                }
            }
            Text("Toca para previsualizar").font(.system(size: 10, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
            if !fromMe {
                Button {
                    FX.tap(); showSave = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: added ? "checkmark.circle.fill" : "plus.circle.fill")
                        Text(added ? "Añadido a tu plan" : "Añadir a mi plan")
                    }
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(added ? Brand.ink : Color(hex: "10150a"))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(added ? Brand.chip : Brand.green).clipShape(RoundedRectangle(cornerRadius: 11))
                }.disabled(added)
            }
            // Pie tipo mensaje: hora + doble check (enviado) cuando es tuyo.
            HStack(spacing: 3) {
                Spacer(minLength: 0)
                Text(shortTime(at)).font(.system(size: 10, weight: .semibold)).foregroundColor(Brand.soft).opacity(0.6)
                if fromMe {
                    ZStack {
                        Image(systemName: "checkmark").offset(x: -2.5)
                        Image(systemName: "checkmark").offset(x: 1.5)
                    }.font(.system(size: 8, weight: .bold)).foregroundColor(Brand.soft).opacity(0.6)
                }
            }
        }
        .padding(12)
        .frame(width: 250, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.line))
        // TODA la tarjeta abre la previsualización (el botón «Añadir» gana su propio toque).
        .contentShape(Rectangle())
        .onTapGesture { FX.tap(); showPreview = true }
        .sheet(isPresented: $showPreview) {
            SharedWorkoutPreview(template: workout, alreadyAdded: added, showAdd: !fromMe,
                                 onSaved: { added = true; showPreview = false })
                .environmentObject(store)
        }
        .sheet(isPresented: $showSave) {
            SaveSharedWorkoutSheet(workout: workout) { added = true }
                .environmentObject(store)
        }
    }
}

/// Previsualización de un entreno compartido (desde el chat): lista completa con superseries
/// y CTA para añadirlo a tu plan. Así decides si te interesa antes de guardarlo.
struct SharedWorkoutPreview: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutTemplate
    var alreadyAdded: Bool = false
    var showAdd: Bool = true
    var onSaved: () -> Void = {}
    @State private var added = false
    @State private var showSave = false

    private var isAdded: Bool { added || alreadyAdded }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(Brand.greenSoft).frame(width: 48, height: 48)
                            Image(systemName: "dumbbell.fill").font(.system(size: 20, weight: .bold)).foregroundColor(Color(hex: "10150a"))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ENTRENO COMPARTIDO").font(.system(size: 10, weight: .heavy)).foregroundColor(Brand.soft).tracking(0.5)
                            Text("\(template.exercises.count) ejercicios · \(template.block)").font(.footnote).foregroundColor(Brand.muted)
                        }
                        Spacer()
                    }
                    WorkoutExerciseList(exercises: template.exercises)
                    if showAdd {
                        Button { FX.tap(); showSave = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text(isAdded ? "Añadido a tu plan" : "Añadir a mi plan")
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(PrimaryButtonStyle(enabled: !isAdded)).disabled(isAdded).padding(.top, 4)
                    }
                }.padding(16)
            }
            .background(Brand.bg)
            .navigationTitle(L10n.x(template.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { SheetBackButton { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSave) {
            SaveSharedWorkoutSheet(workout: template) { added = true; onSaved() }
                .environmentObject(store)
        }
    }
}

/// Paso de guardado, sencillo y elegante: nombre a tu gusto + grupo (existente o nuevo).
struct SaveSharedWorkoutSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let workout: WorkoutTemplate
    var onSaved: () -> Void = {}
    @State private var name = ""
    @State private var group = ""
    @FocusState private var nameFocused: Bool

    /// Tus apartados del plan + sugerencias típicas (sin duplicados).
    private var groupOptions: [String] {
        var seen = Set<String>(); var out: [String] = []
        for g in store.customGroups + ["Compartidos", "Pierna", "Pecho", "Espalda", "Push", "Pull", "Otros"]
        where seen.insert(g).inserted { out.append(g) }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Brand.greenSoft).frame(width: 40, height: 40)
                    Image(systemName: "square.and.arrow.down.fill").font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "10150a"))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Guardar en tu plan").font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("\(workout.exercises.count) ejercicios").font(.caption).foregroundColor(Brand.muted)
                }
                Spacer()
            }
            .padding(.top, 22)

            VStack(alignment: .leading, spacing: 5) {
                Text("NOMBRE").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                TextField("Nombre del entreno", text: $name)
                    .font(.system(size: 15, weight: .heavy)).focused($nameFocused)
                    .padding(.horizontal, 12).frame(height: 48).background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(nameFocused ? Brand.green : Brand.line, lineWidth: nameFocused ? 1.5 : 1))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("GRUPO (apartado del plan)").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                TextField("Escribe uno nuevo o elige abajo", text: $group)
                    .padding(.horizontal, 12).frame(height: 48).background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(groupOptions, id: \.self) { g in
                            Button { FX.tap(); group = g } label: {
                                Text(g).font(.system(size: 12, weight: .heavy))
                                    .foregroundColor(group == g ? Color(hex: "10150a") : Brand.muted)
                                    .padding(.horizontal, 11).padding(.vertical, 7)
                                    .background(group == g ? Brand.green : Brand.chip)
                                    .clipShape(Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }

            Button {
                FX.success()
                store.addSharedWorkout(workout, name: name, group: group)
                onSaved()
                dismiss()
            } label: { Label("Guardar", systemImage: "checkmark").frame(maxWidth: .infinity) }
                .buttonStyle(PrimaryButtonStyle())

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Brand.bg)
        .overlay(alignment: .topLeading) { SheetBackButton { dismiss() }.padding(.leading, 14).padding(.top, 14) }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { name = workout.name; group = workout.block.isEmpty ? "Compartidos" : workout.block }
    }
}

/// Selector para compartir uno de TUS entrenos por el chat.
struct ShareWorkoutPicker: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let onPick: (WorkoutTemplate) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if store.allWorkouts.isEmpty {
                        Text("No tienes entrenos en tu plan todavía.").font(.subheadline).foregroundColor(Brand.muted).padding(.top, 40)
                    }
                    ForEach(store.allWorkouts) { w in
                        Button { onPick(w) } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10).fill(Brand.greenSoft).frame(width: 42, height: 42)
                                    Image(systemName: "dumbbell.fill").font(.system(size: 17, weight: .bold)).foregroundColor(Color(hex: "10150a"))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.x(w.name)).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                                    Text("\(w.exercises.count) ejercicios · \(w.block)").font(.caption).foregroundColor(Brand.muted)
                                }
                                Spacer()
                                Image(systemName: "paperplane.fill").foregroundColor(Brand.green)
                            }
                            .padding(12).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
                        }.buttonStyle(.plain)
                    }
                }.padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Compartir entreno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { SheetBackButton { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
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
    @State private var realName: String?
    @State private var realHandle: String?

    /// Carga los datos REALES del usuario (perfil + sesiones + contadores + score) cuando hay backend.
    private func loadReal() async {
        guard BackendConfig.isConfigured, let uid = UUID(uuidString: person.id) else { return }
        if let profs = try? await Backend.shared.fetchProfiles(ids: [uid]), let p = profs.first {
            realName = p.name ?? p.handle
            realHandle = p.handle
        }
        let s = (try? await Backend.shared.fetchUserSessions(person.id)) ?? []
        realSessions = s.map { $0.asWorkoutSession }
        // Cachea su Gym Score REAL (de sus sesiones) para que los avatares dejen de inventarlo.
        store.setPersonScore(person.id, GymScoreEngine.calculate(historyFromSessions(realSessions ?? [])).total)
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
                WorkoutMedia(photoData: s.photoData, photoURL: s.photoURL,
                             elapsed: s.elapsed, sets: s.sets, volume: s.volume,
                             exercises: s.exercises,
                             seed: "\(s.name)-\(Int(s.date.timeIntervalSince1970))", height: 160)
                WorkoutInsightsStrip(insights: s.insights ?? [])
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
                    Text(realName ?? person.name).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                    if person.isPrivate { Image(systemName: "lock.fill").font(.system(size: 13)).foregroundColor(Brand.soft) }
                }
                Text("@\(realHandle ?? person.handle)").font(.subheadline).foregroundColor(Brand.muted)
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
            Text(LocalizedStringKey(label)).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
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
                    GamificationCard(onOpenLogros: { showLogros = true })
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
            VStack(spacing: 6) {
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
                WorkoutMedia(photoData: s.photoData, photoURL: s.photoURL,
                             elapsed: s.elapsed, sets: s.sets, volume: s.volume,
                             exercises: s.exercises,
                             seed: "\(s.name)-\(Int(s.date.timeIntervalSince1970))", height: 160)
                WorkoutInsightsStrip(insights: s.insights ?? [])
                WorkoutStatStrip(stats: WorkoutStatStrip.metrics(time: durationText(s.elapsed), sets: s.sets,
                                                 exercises: s.exercises, ppm: s.avgHeartRate), style: .compact)
            }
        }.buttonStyle(.plain)
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(LocalizedStringKey(label)).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
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
    @State private var handleAvailability: Bool? = nil   // nil = sin comprobar/da igual
    @State private var handleCheckTask: Task<Void, Never>?

    /// Comprobación REAL contra el servidor (antes el «disponible» era solo formato local).
    private func checkHandleAvailability(_ h: String) {
        handleCheckTask?.cancel()
        handleAvailability = nil
        guard BackendConfig.isConfigured, !h.isEmpty else { return }
        handleCheckTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            if Task.isCancelled { return }
            let ok = await Backend.shared.isHandleAvailable(h)
            if !Task.isCancelled { handleAvailability = ok }
        }
    }
    private var taken: [String] { store.people.map { $0.handle } }
    private var handleError: String? {
        if normalized.count < 3 { return "Mínimo 3 caracteres" }
        if taken.contains(normalized) { return "Ese usuario ya existe" }
        return nil
    }
    private var canSubmit: Bool {
        name.trimmingCharacters(in: .whitespaces).count >= 2 && handleError == nil
            && handleAvailability != false   // con @ ocupado no se puede guardar
    }

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
                            .onChange(of: handle) { _ in checkHandleAvailability(normalized) }
                    }
                    .padding(.horizontal, 12).frame(height: 46).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line))
                    if !normalized.isEmpty, let err = handleError {
                        Text(err).font(.caption).foregroundColor(Color(hex: "c14b46"))
                    } else if !normalized.isEmpty {
                        // Estado REAL del servidor (con debounce), no solo formato.
                        if handleAvailability == false {
                            Text("Ese @usuario ya está cogido").font(.caption).foregroundColor(Color(hex: "c14b46"))
                        } else if handleAvailability == true {
                            Text("@\(normalized) disponible").font(.caption).foregroundColor(Color(hex: "4b8a1f"))
                        } else if BackendConfig.isConfigured {
                            Text("Comprobando disponibilidad…").font(.caption).foregroundColor(Brand.soft)
                        }
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
