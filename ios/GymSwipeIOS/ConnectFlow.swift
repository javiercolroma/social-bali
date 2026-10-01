import SwiftUI

// MARK: - Connect: elegir el motivo (PRODUCT.md · Connect)
//
// No hay ❤️ mudo: al conectar se dice POR QUÉ. Quien lo recibe ve «Javier wants to go
// surfing with you» y decide. «I'm interested» solo aparece si los dos buscan citas (y
// tienen 18+), y solo se revela si es mutuo.

struct ConnectSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let personId: String
    let name: String
    let photoURL: String?
    /// ¿Ofrecer «I'm interested»? Solo si ambos buscan citas.
    let offerInterested: Bool
    @State private var busy = false

    private var reasons: [ConnectReason] { ConnectReason.social + (offerInterested ? [.interested] : []) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule().fill(Brand.line).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.top, 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: L10n.t("Connect with %@"), name))
                    .font(.system(size: 24, weight: .heavy)).foregroundColor(Brand.ink)
                Text("Say why. They'll see it with your request.")
                    .font(.subheadline).foregroundColor(Brand.muted)
            }
            VStack(spacing: 10) {
                ForEach(reasons) { r in
                    Button { send(r) } label: {
                        HStack(spacing: 14) {
                            Text(r.emoji).font(.system(size: 26))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.label).font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink)
                                if r == .interested {
                                    Text("Private — they'll only know if they're interested too.")
                                        .font(.caption).foregroundColor(Brand.muted)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold)).foregroundColor(Brand.soft)
                        }
                        .padding(.horizontal, 16).frame(minHeight: 60)
                        .background(r == .interested ? Brand.sand.opacity(0.45) : Brand.chip.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Brand.bg)
        .presentationDetents([.height(offerInterested ? 470 : 390)])
    }

    private func send(_ r: ConnectReason) {
        busy = true
        Task {
            let result = await store.connect(personId, reason: r)
            busy = false
            dismiss()
            // Los dos dijeron «interested»: se celebra como un match.
            if result == "connected" && r == .interested {
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
