import SwiftUI

/// **Chats**: bandeja de entrada. Buscador arriba (tus chats y miembros por nombre),
/// conversaciones con punto verde si la persona está activa, y vista previa con icono
/// según el tipo de mensaje. Chat directo: cualquier miembro puede escribir a otro.
struct ChatsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    /// Como pestaña no lleva «Done» (solo cuando se presenta como hoja).
    var asTab = false
    var onOpenChat: (String) -> Void
    @State private var openProfile: ProfileRow?
    @State private var query = ""
    @State private var results: [ProfileRow] = []
    @State private var searching = false
    @State private var online: Set<String> = []

    @State private var confirmClear: Conversation?

    /// Fijados arriba (como en WhatsApp) y después por fecha.
    private var conversations: [Conversation] {
        store.conversations.sorted { a, b in
            let pa = store.isPinned(a.personId), pb = store.isPinned(b.personId)
            return pa != pb ? pa : a.lastAt > b.lastAt
        }
    }

    private var term: String { query.trimmingCharacters(in: .whitespaces) }

    private var filtered: [Conversation] {
        guard !term.isEmpty else { return conversations }
        return conversations.filter { (store.person($0.personId)?.name ?? "").localizedCaseInsensitiveContains(term) }
    }

    /// Miembros que encajan con la búsqueda y con los que aún no hay chat.
    private var people: [ProfileRow] {
        let chatting = Set(conversations.map { $0.personId.lowercased() })
        return results.filter { !chatting.contains($0.id.uuidString.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            List {
                searchField
                    .listRowSeparator(.hidden).listRowBackground(Brand.bg)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))

                if conversations.isEmpty && term.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 30, weight: .light)).foregroundColor(Brand.soft)
                        Text("No chats yet").font(.display(22)).foregroundColor(Brand.ink)
                        Text("Open someone's profile in your circle and say hi — or search for a member above.")
                            .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60).padding(.horizontal, 24)
                    .listRowSeparator(.hidden).listRowBackground(Brand.bg)
                }

                if !term.isEmpty && !filtered.isEmpty { sectionTitle("CHATS").listRowSeparator(.hidden).listRowBackground(Brand.bg) }
                ForEach(filtered) { c in
                    row(c)
                        .listRowBackground(Brand.bg)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 66 }
                        // Deslizar, como en WhatsApp.
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { store.toggleUnread(c.personId) } label: {
                                Label(c.unread > 0 ? "Read" : "Unread", systemImage: c.unread > 0 ? "envelope.open" : "envelope.badge")
                            }
                            .tint(Brand.bronze)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { confirmClear = c } label: { Label("Delete", systemImage: "trash") }
                            Button { store.setPinned(c.personId, !store.isPinned(c.personId)) } label: {
                                Label(store.isPinned(c.personId) ? "Unpin" : "Pin", systemImage: store.isPinned(c.personId) ? "pin.slash" : "pin")
                            }
                            .tint(Brand.ink)
                        }
                }

                if !term.isEmpty {
                    if !people.isEmpty { sectionTitle("MEMBERS").padding(.top, 8).listRowSeparator(.hidden).listRowBackground(Brand.bg) }
                    ForEach(people) { p in
                        memberRow(p).listRowBackground(Brand.bg)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                    if searching { ProgressView().tint(Brand.ink).frame(maxWidth: .infinity).padding(20).listRowBackground(Brand.bg) }
                    if !searching && filtered.isEmpty && people.isEmpty && term.count >= 2 {
                        Text(String(format: L10n.t("No one called “%@”"), term))
                            .font(.footnote).foregroundColor(Brand.muted).frame(maxWidth: .infinity).padding(.top, 30)
                            .listRowSeparator(.hidden).listRowBackground(Brand.bg)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .background(Brand.bg)
            .navigationTitle("Chats").navigationBarTitleDisplayMode(.large)
            .confirmationDialog("Delete this chat?", isPresented: Binding(get: { confirmClear != nil }, set: { if !$0 { confirmClear = nil } }),
                                titleVisibility: .visible) {
                Button("Delete chat", role: .destructive) { if let c = confirmClear { store.clearChat(c.personId) }; confirmClear = nil }
            } message: { Text("It's removed for you only. They keep their copy.") }
            .toolbar { if !asTab { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } } }
            .task { store.loadConversations(); await refreshOnline() }
            .refreshable { store.loadConversations(); await refreshOnline() }
            .task(id: term) { await search() }
            .onChange(of: store.conversations.count) { _ in Task { await refreshOnline() } }
            .sheet(item: $openProfile) { ClubProfileView(personId: $0.id.uuidString.lowercased(), initial: $0).environmentObject(store) }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(Brand.soft)
            TextField("Search chats and members", text: $query)
                .font(.system(size: 16)).autocorrectionDisabled().textInputAutocapitalization(.words)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Brand.soft) }
            }
        }
        .padding(.horizontal, 12).frame(height: 42)
        .background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sectionTitle(_ t: LocalizedStringKey) -> some View {
        Text(t).font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundColor(Brand.muted).padding(.vertical, 6)
    }

    private func avatar(_ person: SocialPerson?, online isOnline: Bool) -> some View {
        PersonAvatar(person: person, size: 54)
            .overlay(alignment: .bottomTrailing) {
                if isOnline {
                    Circle().fill(Brand.online).frame(width: 13, height: 13)
                        .overlay(Circle().stroke(Brand.bg, lineWidth: 2.5))
                }
            }
    }

    private func row(_ c: Conversation) -> some View {
        let person = store.person(c.personId)
        let bold = c.unread > 0
        return Button { FX.tap(); onOpenChat(c.personId) } label: {
            HStack(spacing: 12) {
                avatar(person, online: online.contains(c.personId.lowercased()))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(person?.name ?? "…").font(.system(size: 16, weight: bold ? .bold : .semibold)).foregroundColor(Brand.ink)
                        if let co = person?.club?.homeCountry, !co.isEmpty { Text(countryFlag(co)).font(.system(size: 14)) }
                        Spacer()
                        if store.isPinned(c.personId) {
                            Image(systemName: "pin.fill").font(.system(size: 11)).foregroundColor(Brand.soft).rotationEffect(.degrees(45))
                        }
                        if let m = c.lastMessage {
                            Text(shortTime(m.at)).font(.system(size: 12, weight: bold ? .semibold : .regular))
                                .foregroundColor(bold ? Brand.ink : Brand.soft)
                        }
                    }
                    HStack(spacing: 4) {
                        if let m = c.lastMessage, m.fromMe {
                            ZStack {
                                Image(systemName: "checkmark").offset(x: -2.5)
                                Image(systemName: "checkmark").offset(x: 1.5)
                            }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(m.read == true ? Color(hex: "3b9ae8") : Brand.soft)
                        }
                        Text(c.lastMessage?.preview ?? L10n.t("Say hi")).font(.system(size: 14, weight: bold ? .medium : .regular))
                            .foregroundColor(bold ? Brand.ink : Brand.muted).lineLimit(1)
                        Spacer()
                        if c.unread > 0 {
                            Text("\(c.unread)").font(.system(size: 11, weight: .bold)).foregroundColor(Brand.onAccent)
                                .padding(.horizontal, 6).frame(minWidth: 20, minHeight: 20).background(Brand.accent).clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func memberRow(_ p: ProfileRow) -> some View {
        Button { openProfile = p } label: {
            HStack(spacing: 12) {
                avatar(AppStore.asPeople([p]).first, online: p.online == true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(p.age.map { "\(p.name ?? ""), \($0)" } ?? (p.name ?? "")).font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.ink)
                        if let co = p.club.homeCountry, !co.isEmpty { Text(countryFlag(co)).font(.system(size: 14)) }
                    }
                    Text([p.club.area?.label, p.distance_m.map(CircleDistance.label)].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 13)).foregroundColor(Brand.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.soft)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    // MARK: Datos

    /// Busca miembros en el servidor (con una pequeña espera para no lanzar una
    /// consulta por cada letra).
    private func search() async {
        guard term.count >= 2 else { results = []; return }
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        searching = true
        let r = await Backend.shared.searchMembers(term)
        if !Task.isCancelled { results = r }
        searching = false
    }

    private func refreshOnline() async {
        online = await Backend.shared.onlineAmong(conversations.map(\.personId))
    }
}
