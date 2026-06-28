import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let level = getLevelProgress(store.player.xp)
        ScrollView {
            VStack(spacing: 14) {
                PanelCard {
                    HStack(spacing: 14) {
                        Avatar(emoji: "🙂", size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.account?.name ?? "Tu perfil").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
                            if let h = store.account?.handle { Text("@\(h)").font(.subheadline).foregroundColor(Brand.muted) }
                        }
                        Spacer()
                    }
                }

                PanelCard {
                    HStack {
                        Text("Nivel \(level.level)").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                        Spacer()
                        Text("\(store.player.xp) XP").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.muted)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Brand.chip)
                            Capsule().fill(Brand.green).frame(width: max(6, geo.size.width * level.progress))
                        }
                    }.frame(height: 10)
                    HStack(spacing: 18) {
                        metric("\(store.player.streak)", "Racha 🔥")
                        metric("\(store.gymScore.total)", "Gym Score")
                        metric("\(store.history.count)", "Registros")
                    }
                }

                PanelCard {
                    Text("DATOS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    field("Sexo", binding: Binding(get: { store.profile.sex }, set: { store.profile.sex = $0; store.persist() }))
                    field("Edad", binding: Binding(get: { store.profile.age }, set: { store.profile.age = $0; store.persist() }), keyboard: .numberPad)
                    field("País", binding: Binding(get: { store.profile.country }, set: { store.profile.country = $0; store.persist() }))
                    field("Ciudad", binding: Binding(get: { store.profile.city }, set: { store.profile.city = $0; store.persist() }))
                    field("Gimnasio", binding: Binding(get: { store.profile.gym }, set: { store.profile.gym = $0; store.persist() }))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Brand.bg)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
        }.frame(maxWidth: .infinity)
    }

    private func field(_ label: String, binding: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            TextField(label, text: binding)
                .keyboardType(keyboard)
                .padding(.horizontal, 12).frame(height: 44)
                .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
