import SwiftUI

/// Fusión natural de Ranking + Partner en una sola pestaña "Comunidad".
/// Un selector segmentado conmuta entre la clasificación/mapa (Ranking) y la
/// búsqueda de compañeros (Partner). Ambas vistas viven en un ZStack para
/// conservar su estado (scroll, mapa, ubicación) al cambiar de sección.
struct CommunityView: View {
    @EnvironmentObject var store: AppStore
    var onOpenChat: (String) -> Void
    // La sección activa vive en el store para que el tutorial guiado (CoachTour)
    // pueda llevar al usuario hasta Partner mientras se lo explica.
    private var section: Int { store.communitySection }

    private let items: [(title: String, icon: String)] = [
        ("Ranking", "trophy.fill"),
        ("Partner", "person.2.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            switcher
            ZStack {
                RankingView()
                    .opacity(section == 0 ? 1 : 0)
                    .allowsHitTesting(section == 0)
                PartnerView(onOpenChat: onOpenChat)
                    .opacity(section == 1 ? 1 : 0)
                    .allowsHitTesting(section == 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.28), value: section)
        }
        .background(Brand.bg)
    }

    private var switcher: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                let active = section == idx
                Button {
                    FX.selection()
                    withAnimation(.easeInOut(duration: 0.28)) { store.communitySection = idx }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon).font(.system(size: 13, weight: .heavy))
                        Text(item.title).font(.system(size: 14, weight: .heavy))
                    }
                    .foregroundColor(active ? Color(hex: "10150a") : Brand.soft)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(active ? Brand.green : Brand.chip)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
}
