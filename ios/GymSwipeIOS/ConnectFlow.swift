import SwiftUI

// MARK: - Connect: una nota propia, no un mensaje predefinido
//
// Al conectar puedes escribir una nota (opcional) que la otra persona ve con la
// solicitud. Si los dos buscáis citas, aparece además «I'm interested», que es PRIVADO:
// la otra persona solo lo sabe si también lo marca.

struct ConnectSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let personId: String
    let name: String
    let photoURL: String?
    /// ¿Ofrecer «I'm interested»? Solo si ambos buscan citas.
    let offerInterested: Bool
    @State private var note = ""
    @State private var interested = false
    @State private var busy = false
    @FocusState private var focused: Bool

    private static let maxNote = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule().fill(Brand.line).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.top, 8)
            HStack(spacing: 14) {
                Group {
                    if let u = photoURL { RemoteFill(url: u) } else { Brand.sand }
                }
                .frame(width: 56, height: 56).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: L10n.t("Connect with %@"), name)).font(.display(24)).foregroundColor(Brand.ink)
                    Text("They'll see your note with the request.").font(.subheadline).foregroundColor(Brand.muted)
                }
            }

            VStack(alignment: .trailing, spacing: 6) {
                TextField(String(format: L10n.t("Say hi to %@… (optional)"), name), text: $note, axis: .vertical)
                    .font(.system(size: 16)).foregroundColor(Brand.ink).tint(Brand.ink)
                    .lineLimit(3...5)
                    .focused($focused)
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(focused ? Brand.ink : Brand.line))
                    .onChange(of: note) { v in if v.count > Self.maxNote { note = String(v.prefix(Self.maxNote)) } }
                Text("\(note.count)/\(Self.maxNote)").font(.caption2).foregroundColor(Brand.soft)
            }

            if offerInterested {
                Button { FX.selection(); interested.toggle() } label: {
                    HStack(spacing: 12) {
                        Text("✨").font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("I'm interested").font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.ink)
                            Text("Private — they'll only know if they're interested too.")
                                .font(.caption).foregroundColor(Brand.muted)
                        }
                        Spacer()
                        Image(systemName: interested ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22)).foregroundColor(interested ? Brand.ink : Brand.line)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 60)
                    .background(interested ? Brand.sand : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(interested ? Brand.ink : Brand.line, lineWidth: interested ? 1.5 : 1))
                }
                .buttonStyle(.plain)
            }

            Button { send() } label: {
                if busy { ProgressView().tint(Brand.onAccent) } else { Text("Send request") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(busy)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Brand.bg)
        .presentationDetents([.large])
    }

    private func send() {
        busy = true
        let reason: ConnectReason = interested ? .interested : .connect
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let result = await store.connect(personId, reason: reason, note: text.isEmpty ? nil : text)
            busy = false
            dismiss()
            // Los dos dijeron «interested»: se celebra como un match.
            if result == "connected" && reason == .interested {
                try? await Task.sleep(nanoseconds: 350_000_000)
                MatchCenter.shared.match = MatchInfo(personId: personId, name: name, photoURL: photoURL)
            }
        }
    }
}

// MARK: - It's a match

struct MatchInfo: Identifiable, Equatable {
    let personId: String
    let name: String
    let photoURL: String?
    var id: String { personId }
}

/// Quién acaba de hacer match (lo presenta `RootView` a pantalla completa).
@MainActor
final class MatchCenter: ObservableObject {
    static let shared = MatchCenter()
    @Published var match: MatchInfo?
}

struct MatchView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let info: MatchInfo

    var body: some View {
        ZStack {
            LinearGradient(colors: [Brand.ink, Color(hex: "2b2722")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                Group {
                    if let url = info.photoURL { RemoteFill(url: url) }
                    else { Brand.sand.overlay(Text("✨").font(.system(size: 60))) }
                }
                .frame(width: 160, height: 160).clipShape(Circle())
                .overlay(Circle().stroke(Brand.sand, lineWidth: 3))
                Text("It's a match.").font(.display(40)).foregroundColor(.white)
                Text(String(format: L10n.t("You and %@ are both interested."), info.name))
                    .font(.system(size: 17, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                Spacer()
                Button {
                    FX.tap()
                    let id = info.personId
                    dismiss()
                    store.openChatWith = id
                } label: {
                    Text("Say hi").font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Brand.sand).clipShape(RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
                Button { dismiss() } label: {
                    Text("Keep exploring").font(.system(size: 15, weight: .heavy)).foregroundColor(.white.opacity(0.75))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 28).padding(.bottom, 24)
        }
        .onAppear { FX.success() }
    }
}
