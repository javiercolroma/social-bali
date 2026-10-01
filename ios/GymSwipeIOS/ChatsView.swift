import SwiftUI

/// **Chats**: tus conversaciones, la más reciente primero. Chat directo (tipo Grindr):
/// cualquier miembro puede escribir a otro; el servidor solo lo impide si hay bloqueo
/// (0032).
struct ChatsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    /// Como pestaña no lleva «Done» (solo cuando se presenta como hoja).
    var asTab = false
    var onOpenChat: (String) -> Void
    @State private var openProfile: IdString?

    private var conversations: [Conversation] { store.conversations.sorted { $0.lastAt > $1.lastAt } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if conversations.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 30, weight: .light)).foregroundColor(Brand.soft)
                            Text("No chats yet").font(.display(22)).foregroundColor(Brand.ink)
                            Text("Open someone's profile in your circle and say hi.")
                                .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 80).padding(.horizontal, 24)
                    }
                    ForEach(conversations) { c in row(c) }
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Chats").navigationBarTitleDisplayMode(.inline)
            .toolbar { if !asTab { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } } }
            .task { store.loadConversations() }
            .refreshable { store.loadConversations() }
            .sheet(item: $openProfile) { ClubProfileView(personId: $0.id).environmentObject(store) }
        }
    }

    private func row(_ c: Conversation) -> some View {
        let person = store.person(c.personId)
        return Button { FX.tap(); onOpenChat(c.personId) } label: {
            HStack(spacing: 12) {
                Button { openProfile = IdString(id: c.personId) } label: { PersonAvatar(person: person, size: 52) }
                    .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(person?.name ?? "…").font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.ink)
                        Spacer()
                        if let m = c.lastMessage { Text(shortTime(m.at)).font(.caption2).foregroundColor(Brand.soft) }
                    }
                    HStack {
                        Text(preview(c)).font(.system(size: 14))
                            .foregroundColor(c.unread > 0 ? Brand.ink : Brand.muted).lineLimit(1)
                        Spacer()
                        if c.unread > 0 {
                            Text("\(c.unread)").font(.system(size: 11, weight: .bold)).foregroundColor(Brand.onAccent)
                                .padding(.horizontal, 6).frame(minWidth: 20, minHeight: 20).background(Brand.accent).clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(12).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.line))
        }.buttonStyle(.plain)
    }

    private func preview(_ c: Conversation) -> String {
        guard let m = c.lastMessage else { return L10n.t("Say hi") }
        return (m.fromMe ? L10n.t("You: ") : "") + m.preview
    }
}
