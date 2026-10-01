import SwiftUI

/// **Chats**: solicitudes de conexión arriba (quién y POR QUÉ) y debajo las personas con
/// las que ya has conectado. Sustituye a Amigos/Mensajes, que se basaba en seguidores:
/// en el club solo se habla con quien ha aceptado (`can_message_to`, 0026).
struct ChatsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    /// Como pestaña no lleva «Done» (solo cuando se presenta como hoja).
    var asTab = false
    var onOpenChat: (String) -> Void
    @State private var openProfile: IdString?

    /// Conectados, con conversación o sin ella: los más recientes primero y los que
    /// aún no se han escrito al final («say hi»).
    private var rows: [(personId: String, conv: Conversation?, reason: ConnectReason?)] {
        guard let me = store.myUserId else { return [] }
        let accepted = store.connections.filter { $0.status == "accepted" }
        var seen = Set<String>()
        var out: [(String, Conversation?, ConnectReason?)] = []
        for c in accepted {
            let other = (c.from_id.lowercased() == me ? c.to_id : c.from_id).lowercased()
            guard seen.insert(other).inserted else { continue }
            let conv = store.conversations.first { $0.personId.lowercased() == other }
            out.append((other, conv, c.connectReason))
        }
        return out.sorted { a, b in
            switch (a.1, b.1) {
            case let (x?, y?): return x.lastAt > y.lastAt
            case (_?, nil): return true
            default: return false
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !store.incomingRequests.isEmpty { requests }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONNECTIONS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        if rows.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "hand.wave").font(.system(size: 26)).foregroundColor(Brand.soft)
                                Text("No connections yet").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                                Text("Connect with someone from your circle. When they accept, you can chat here.")
                                    .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding(.top, 40).padding(.horizontal, 24)
                        }
                        ForEach(rows, id: \.personId) { r in chatRow(r.personId, r.conv, r.reason) }
                    }
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Chats").navigationBarTitleDisplayMode(.inline)
            .toolbar { if !asTab { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.heavy) } } }
            .task { store.loadConnections(); store.loadConversations() }
            .sheet(item: $openProfile) { ClubProfileView(personId: $0.id).environmentObject(store) }
        }
    }

    private var requests: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REQUESTS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            ForEach(store.incomingRequests) { req in
                let person = store.person(req.from_id)
                VStack(alignment: .leading, spacing: 10) {
                    Button { openProfile = IdString(id: req.from_id) } label: {
                        HStack(spacing: 12) {
                            avatar(person, size: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person?.name ?? "…").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                                Text("\(req.connectReason?.emoji ?? "") \(req.connectReason?.receivedLine ?? "")")
                                    .font(.subheadline).foregroundColor(Brand.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                        }
                    }.buttonStyle(.plain)
                    ConnectControl(personId: req.from_id, theyAreOpenToDating: false)
                }
                .padding(12).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
            }
        }
    }

    private func chatRow(_ personId: String, _ conv: Conversation?, _ reason: ConnectReason?) -> some View {
        let person = store.person(personId)
        return Button { FX.tap(); onOpenChat(personId) } label: {
            HStack(spacing: 12) {
                avatar(person, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(person?.name ?? "…").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                        Spacer()
                        if let m = conv?.lastMessage { Text(shortTime(m.at)).font(.caption2).foregroundColor(Brand.soft) }
                    }
                    HStack {
                        Text(preview(conv, reason)).font(.system(size: 13))
                            .foregroundColor((conv?.unread ?? 0) > 0 ? Brand.ink : Brand.muted).lineLimit(1)
                        Spacer()
                        if let u = conv?.unread, u > 0 {
                            Text("\(u)").font(.system(size: 11, weight: .heavy)).foregroundColor(Brand.onAccent)
                                .padding(.horizontal, 6).frame(minWidth: 20, minHeight: 20).background(Brand.accent).clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(12).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
        }.buttonStyle(.plain)
    }

    /// Sin mensajes todavía: se recuerda el motivo para romper el hielo.
    private func preview(_ conv: Conversation?, _ reason: ConnectReason?) -> String {
        if let m = conv?.lastMessage { return (m.fromMe ? L10n.t("You: ") : "") + m.preview }
        if reason == .interested { return "✨ " + L10n.t("It's a match — say hi") }
        if let r = reason { return "\(r.emoji) " + String(format: L10n.t("Connected to %@ — say hi"), r.label.lowercased()) }
        return L10n.t("Say hi")
    }

    private func avatar(_ p: SocialPerson?, size: CGFloat) -> some View {
        Group {
            if let url = p?.avatarURL { RemoteFill(url: url) }
            else { Brand.sand.overlay(Text(p?.club?.sportList.first?.emoji ?? "🙂").font(.system(size: size * 0.45))) }
        }
        .frame(width: size, height: size).clipShape(Circle())
    }
}
