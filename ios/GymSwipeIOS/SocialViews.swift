import SwiftUI
import PhotosUI
import Supabase

func normalizeHandle(_ value: String) -> String {
    let lower = value.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    let filtered = lower.unicodeScalars.filter { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_").contains($0) }
    return String(String.UnicodeScalarView(filtered)).prefix(20).description
}

func emptyState(icon: String, title: String, body: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon).font(.system(size: 26)).foregroundColor(Brand.soft)
        Text(title).font(.system(size: 16, weight: .heavy)).foregroundColor(Color(hex: "41463c"))
        Text(body).font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
    }.padding(.top, 60).padding(.horizontal, 30).frame(maxWidth: .infinity)
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
    /// Usuario real sin conexión aceptada: el servidor rechazaría el mensaje (0026).
    private var mustConnectFirst: Bool {
        BackendConfig.isConfigured && UUID(uuidString: personId) != nil && !store.isConnected(personId)
    }
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
                        PersonAvatar(person: person, size: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(person?.name ?? "…").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                            if let a = person?.club?.area { Text(a.label).font(.caption).foregroundColor(Brand.muted) }
                        }
                    }
                }.buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Brand.bg).overlay(Divider(), alignment: .bottom)

            // La conversación nace con un motivo (PRODUCT.md, principio 4).
            if case .connected(let r) = store.connectionState(personId) {
                Text("\(r.emoji) \(String(format: L10n.t("You connected to %@"), r.label.lowercased()))")
                    .font(.caption).fontWeight(.semibold).foregroundColor(Color(hex: "4b6211"))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Brand.greenSoft.opacity(0.6)).clipShape(Capsule())
                    .padding(.top, 8)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        if !messages.isEmpty {
                            ForEach(messages) { m in bubble(m).id(m.id) }
                        } else {
                            emptyState(icon: "message", title: "No messages", body: "Write the first message.")
                        }
                    }.padding(16)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    store.markConversationRead(personId)
                }
            }

            if mustConnectFirst {
                VStack(spacing: 6) {
                    Text("Connect first to send a message").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("Messages open once you've both agreed to connect.")
                        .font(.caption).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.horizontal, 14).padding(.vertical, 14)
                .background(Brand.bg).overlay(Divider(), alignment: .top)
            } else {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                        .padding(.horizontal, 16).frame(height: 46).background(Color.white).clipShape(Capsule())
                        .overlay(Capsule().stroke(Brand.line))
                    Button { send() } label: {
                        Image(systemName: "paperplane.fill").foregroundColor(Color(hex: "10150a"))
                            .frame(width: 46, height: 46).background(Brand.green).clipShape(Circle())
                    }.disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Brand.bg).overlay(Divider(), alignment: .top)
            }
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
        .sheet(item: $profileTarget) { ClubProfileView(personId: $0.id).environmentObject(store) }
    }

    /// Envía cualquier texto por el camino correcto (real o local) y lo refleja al instante.
    private func deliver(_ text: String) {
        if realMode, let uid = UUID(uuidString: personId) {
            let msg = ChatMessage(id: UUID().uuidString, fromMe: true, text: text, at: Date())
            realMessages.append(msg)
            store.appendLocalMessage(personId, msg)   // refleja el último mensaje en la lista
            Task { try? await Backend.shared.sendMessage(to: uid, text: text) }
        } else {
            store.sendMessage(personId, text)
        }
    }

    private func send() {
        let t = draft.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        FX.tap()
        deliver(t); draft = ""
    }

    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.fromMe { Spacer(minLength: 50) }
            VStack(alignment: m.fromMe ? .trailing : .leading, spacing: 2) {
                Text(m.text).font(.system(size: 15)).foregroundColor(m.fromMe ? Color(hex: "10150a") : Color(hex: "2c3127"))
                Text(shortTime(m.at)).font(.system(size: 10, weight: .semibold)).opacity(0.5)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(m.fromMe ? Brand.greenSoft : Brand.chip)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            if !m.fromMe { Spacer(minLength: 50) }
        }
    }
}

// MARK: - Avatar

/// Foto de perfil redonda; sin foto, el emoji de su primer deporte.
struct PersonAvatar: View {
    let person: SocialPerson?
    var size: CGFloat = 44
    var body: some View {
        Group {
            if let url = person?.avatarURL { RemoteFill(url: url) }
            else { Brand.greenSoft.overlay(Text(person?.club?.sportList.first?.emoji ?? "🙂").font(.system(size: size * 0.45))) }
        }
        .frame(width: size, height: size).clipShape(Circle())
    }
}

// MARK: - Mi perfil (pestaña Profile)

/// Tu perfil tal y como lo ven los demás, con el botón de editar y los ajustes.
struct MeProfileView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing = false
    @State private var settings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    if let d = store.account?.photoData, let img = UIImage(data: d) {
                        Color.clear.overlay(Image(uiImage: img).resizable().scaledToFill())
                    } else {
                        PhotoPager(urls: store.profile.photos ?? []) {
                            ZStack {
                                LinearGradient(colors: [Brand.greenSoft, Color(hex: "e7f0d6")], startPoint: .topLeading, endPoint: .bottomTrailing)
                                Text(store.profile.club.sportList.first?.emoji ?? "🙂").font(.system(size: 90))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity).aspectRatio(4 / 5, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text(store.account?.name ?? "").font(.system(size: 30, weight: .heavy)).foregroundColor(Brand.ink)
                ClubIdentityCard(club: store.profile.club, onEdit: { editing = true })

                HStack(spacing: 10) {
                    Button { FX.tap(); editing = true } label: {
                        Label("Edit profile", systemImage: "pencil").frame(maxWidth: .infinity)
                    }.buttonStyle(PrimaryButtonStyle())
                    Button { FX.tap(); settings = true } label: {
                        Image(systemName: "gearshape.fill").font(.system(size: 17, weight: .semibold)).foregroundColor(Brand.ink)
                            .frame(width: 54, height: 54).background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Brand.bg)
        .sheet(isPresented: $editing) { NavigationStack { EditProfileView() }.environmentObject(store) }
        .sheet(isPresented: $settings) { SettingsView().environmentObject(store) }
    }
}

// MARK: - Identidad del club en el perfil

/// Tarjeta «quién es esta persona»: bio, estancia en Bali, barrio, de dónde es,
/// deportes y qué busca. La MISMA para el perfil propio y el ajeno (fuente única).
/// Con `onEdit` es el perfil propio: lápiz para editar y, si está vacía, invitación a
/// rellenarla en vez de desaparecer (sin identidad no hay nada que enseñar en Discover).
struct ClubIdentityCard: View {
    let club: ClubIdentity
    var onEdit: (() -> Void)? = nil

    var body: some View {
        if club.isEmpty {
            if let onEdit { emptyInvite(onEdit) }
        } else {
            PanelCard {
                HStack(alignment: .top) {
                    if let bio = club.trimmedBio {
                        Text(bio).font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if let onEdit {
                        Button { FX.tap(); onEdit() } label: {
                            Image(systemName: "pencil").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.soft)
                                .frame(width: 30, height: 30).background(Brand.chip).clipShape(Circle())
                        }.buttonStyle(.plain)
                    }
                }
                facts
                if !club.sportList.isEmpty {
                    WrapLayout(spacing: 6) {
                        ForEach(club.sportList) { s in chip("\(s.emoji) \(s.label)") }
                    }
                }
                if !club.intentList.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OPEN TO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        WrapLayout(spacing: 6) {
                            ForEach(club.intentList) { i in
                                Label(i.label, systemImage: i.icon)
                                    .font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                                    .padding(.horizontal, 11).frame(height: 30)
                                    .background(Brand.greenSoft).clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    /// Estancia primero: es lo que más cambia la utilidad de conectar con alguien.
    @ViewBuilder
    private var facts: some View {
        let stay = club.stay
        let home = club.homeLine
        if stay != nil || club.area != nil || home != nil {
            VStack(alignment: .leading, spacing: 7) {
                if let stay {
                    HStack(spacing: 8) {
                        fact(stayIcon(stay.kind), stay.headline)
                        if let u = stay.urgency {
                            Text(u).font(.system(size: 11, weight: .heavy)).foregroundColor(Color(hex: "a73232"))
                                .padding(.horizontal, 8).frame(height: 22).background(Brand.redSoft).clipShape(Capsule())
                        }
                    }
                }
                if let a = club.area { fact("mappin.and.ellipse", a.label) }
                if let home { fact("globe.europe.africa.fill", String(format: L10n.t("From %@"), home)) }
            }
        }
    }

    private func stayIcon(_ k: StayKind) -> String {
        switch k {
        case .livingHere: return "house.fill"
        case .longTerm:   return "calendar"
        case .until:      return "airplane.departure"
        }
    }

    private func fact(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "6ea300")).frame(width: 18)
            Text(text).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.ink)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
            .padding(.horizontal, 11).frame(height: 30).background(Brand.chip).clipShape(Capsule())
    }

    private func emptyInvite(_ onEdit: @escaping () -> Void) -> some View {
        PanelCard {
            Text("Tell the club who you are").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
            Text("Add a bio, your sports, where you're based and how long you're around. It's what people see before they connect.")
                .font(.footnote).foregroundColor(Brand.muted).fixedSize(horizontal: false, vertical: true)
            Button { FX.tap(); onEdit() } label: {
                Text("Complete your profile")
            }.buttonStyle(PrimaryButtonStyle())
        }
    }
}

/// Fila que salta de línea cuando no cabe (chips de longitud variable). `LazyVGrid`
/// obliga a columnas de ancho fijo y deja «Beach volleyball» cortado junto a «BJJ».
struct WrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var cur = Row()
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let needed = cur.indices.isEmpty ? size.width : cur.width + spacing + size.width
            if needed > width, !cur.indices.isEmpty {
                rows.append(cur); cur = Row()
            }
            cur.width = cur.indices.isEmpty ? size.width : cur.width + spacing + size.width
            cur.height = max(cur.height, size.height)
            cur.indices.append(i)
        }
        if !cur.indices.isEmpty { rows.append(cur) }
        return rows
    }
}
