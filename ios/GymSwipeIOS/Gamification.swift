import SwiftUI

// MARK: - Logros (achievements)

enum AchTier {
    case bronze, silver, gold, diamond
    var color: Color {
        switch self {
        case .bronze:  return Color(hex: "b0824a")
        case .silver:  return Color(hex: "9aa3ad")
        case .gold:    return Color(hex: "e2a915")
        case .diamond: return Color(hex: "2fb8c6")
        }
    }
    var fill: LinearGradient {
        let c = color
        return LinearGradient(colors: [c.opacity(0.92), c.opacity(0.62)], startPoint: .top, endPoint: .bottom)
    }
    var glow: CGFloat {
        switch self { case .bronze: return 0; case .silver: return 2; case .gold: return 6; case .diamond: return 9 }
    }
}

struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let icon: String       // SF Symbol
    let tier: AchTier
    let coins: Int
    let goal: Int
    let value: @MainActor (AppStore) -> Int   // progreso actual (0…goal)
    static func == (a: Achievement, b: Achievement) -> Bool { a.id == b.id }
}

enum Achievements {
    static let all: [Achievement] = [
        Achievement(id: "first", title: "Primer paso", detail: "Guarda tu primer entreno",
                    icon: "figure.strengthtraining.traditional", tier: .bronze, coins: 30, goal: 1,
                    value: { min(1, $0.sessions.count) }),
        Achievement(id: "w10", title: "Constante", detail: "Guarda 10 entrenos",
                    icon: "checkmark.seal.fill", tier: .bronze, coins: 40, goal: 10, value: { $0.sessions.count }),
        Achievement(id: "w50", title: "Veterano", detail: "Guarda 50 entrenos",
                    icon: "shield.lefthalf.filled", tier: .silver, coins: 90, goal: 50, value: { $0.sessions.count }),
        Achievement(id: "w100", title: "Centurión", detail: "Guarda 100 entrenos",
                    icon: "medal.fill", tier: .gold, coins: 160, goal: 100, value: { $0.sessions.count }),
        Achievement(id: "streak7", title: "Semana de fuego", detail: "Consigue una racha de 7",
                    icon: "flame.fill", tier: .silver, coins: 60, goal: 7, value: { $0.player.streak }),
        Achievement(id: "streak30", title: "Imparable", detail: "Consigue una racha de 30",
                    icon: "bolt.fill", tier: .gold, coins: 220, goal: 30, value: { $0.player.streak }),
        Achievement(id: "oro", title: "Liga de Oro", detail: "Llega a la división Oro",
                    icon: "rosette", tier: .gold, coins: 110, goal: 45, value: { $0.gymScore.total }),
        Achievement(id: "diamante", title: "Diamante", detail: "Llega a la división Diamante",
                    icon: "diamond.fill", tier: .diamond, coins: 200, goal: 75, value: { $0.gymScore.total }),
        Achievement(id: "maestro", title: "Maestro", detail: "Llega a la división Maestro",
                    icon: "crown.fill", tier: .diamond, coins: 320, goal: 90, value: { $0.gymScore.total }),
        Achievement(id: "vol10k", title: "Tonelaje", detail: "Levanta 10.000 kg en total",
                    icon: "scalemass.fill", tier: .silver, coins: 70, goal: 10_000,
                    value: { Int($0.sessions.reduce(0.0) { $0 + $1.volume }) }),
        Achievement(id: "vol100k", title: "Grúa", detail: "Levanta 100.000 kg en total",
                    icon: "scalemass.fill", tier: .gold, coins: 190, goal: 100_000,
                    value: { Int($0.sessions.reduce(0.0) { $0 + $1.volume }) }),
        Achievement(id: "photo", title: "Postureo", detail: "Comparte una foto de entreno",
                    icon: "camera.fill", tier: .bronze, coins: 30, goal: 1,
                    value: { $0.sessions.contains { $0.photoData != nil } ? 1 : 0 }),
        Achievement(id: "early", title: "Madrugador", detail: "Entrena antes de las 7:00",
                    icon: "sunrise.fill", tier: .silver, coins: 50, goal: 1,
                    value: { $0.sessions.contains { Calendar.current.component(.hour, from: $0.date) < 7 } ? 1 : 0 }),
        Achievement(id: "night", title: "Búho", detail: "Entrena después de las 22:00",
                    icon: "moon.stars.fill", tier: .silver, coins: 50, goal: 1,
                    value: { $0.sessions.contains { Calendar.current.component(.hour, from: $0.date) >= 22 } ? 1 : 0 }),
        Achievement(id: "social", title: "Sociable", detail: "Sigue a alguien",
                    icon: "person.2.fill", tier: .bronze, coins: 30, goal: 1, value: { min(1, $0.following.count) }),
    ]
    static func by(_ id: String) -> Achievement? { all.first { $0.id == id } }
}

extension AppStore {
    var totalAchievements: Int { Achievements.all.count }
    var unlockedCount: Int { Achievements.all.filter { unlockedAchievements.contains($0.id) }.count }
    func isUnlocked(_ id: String) -> Bool { unlockedAchievements.contains(id) }
    func achievementValue(_ a: Achievement) -> Int { min(a.goal, a.value(self)) }

    /// Desbloquea los logros cuyo objetivo ya se cumple, suma sus monedas y (si procede) los encola para celebrar.
    func refreshAchievements(celebrate: Bool) {
        var newly: [Achievement] = []
        for a in Achievements.all where !unlockedAchievements.contains(a.id) {
            if a.value(self) >= a.goal {
                unlockedAchievements.insert(a.id)
                coins += a.coins
                newly.append(a)
            }
        }
        guard !newly.isEmpty else { return }
        if celebrate { celebrations.append(contentsOf: newly) }
        persist()
    }
}

// MARK: - Tarjeta de perfil: nivel + monedas + logros

struct GamificationCard: View {
    @EnvironmentObject var store: AppStore
    var onOpenLogros: () -> Void

    var body: some View {
        let lv = getLevelProgress(store.player.xp)
        PanelCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: "b4ec51"), Color(hex: "8ed11d")], startPoint: .top, endPoint: .bottom))
                        .frame(width: 46, height: 46)
                        .shadow(color: Brand.green.opacity(0.4), radius: 6, y: 3)
                    Text("\(lv.level)").font(.system(size: 20, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Nivel \(lv.level)").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Brand.chip)
                            Capsule().fill(Brand.green).frame(width: max(6, geo.size.width * lv.progress))
                        }
                    }.frame(height: 7)
                    Text("\(store.player.xp - lv.current) / \(lv.next - lv.current) XP").font(.system(size: 11, weight: .bold)).foregroundColor(Brand.soft)
                }
                Spacer(minLength: 8)
                VStack(spacing: 2) {
                    Text("🪙").font(.system(size: 20))
                    Text("\(store.coins)").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink).monospacedDigit()
                }
            }
            Divider()
            Button { FX.tap(); onOpenLogros() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill").font(.system(size: 14)).foregroundColor(Color(hex: "e2a915"))
                    Text("Logros").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    Spacer()
                    Text("\(store.unlockedCount)/\(store.totalAchievements)").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.soft)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
    }
}

// MARK: - Pantalla de Logros

struct LogrosView: View {
    @EnvironmentObject var store: AppStore
    private let cols = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(store.unlockedCount) de \(store.totalAchievements)").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
                            Text("logros conseguidos").font(.footnote).foregroundColor(Brand.muted)
                        }
                        Spacer()
                        HStack(spacing: 5) { Text("🪙").font(.system(size: 18)); Text("\(store.coins)").font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink) }
                            .padding(.horizontal, 12).frame(height: 40).background(Brand.chip).clipShape(Capsule())
                    }
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(Achievements.all) { a in AchievementTile(a: a) }
                    }
                }.padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Logros").navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AchievementTile: View {
    @EnvironmentObject var store: AppStore
    let a: Achievement

    var body: some View {
        let unlocked = store.isUnlocked(a.id)
        let value = store.achievementValue(a)
        return VStack(spacing: 8) {
            ZStack {
                Circle().fill(unlocked ? AnyShapeStyle(a.tier.fill) : AnyShapeStyle(Brand.chip))
                    .frame(width: 58, height: 58)
                    .overlay(Circle().stroke(.white.opacity(unlocked ? 0.6 : 0), lineWidth: 1.5))
                    .shadow(color: unlocked ? a.tier.color.opacity(0.7) : .clear, radius: a.tier.glow)
                Image(systemName: unlocked ? a.icon : "lock.fill")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(unlocked ? .white : Brand.soft)
            }
            Text(a.title).font(.system(size: 12, weight: .heavy)).foregroundColor(unlocked ? Brand.ink : Brand.muted)
                .multilineTextAlignment(.center).lineLimit(2).frame(height: 30)
            if unlocked {
                Text("🪙 \(a.coins)").font(.system(size: 11, weight: .heavy)).foregroundColor(Color(hex: "b0824a"))
            } else if a.goal > 1 {
                // Barra de progreso para logros de conteo
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Brand.chip)
                        Capsule().fill(Brand.green.opacity(0.7)).frame(width: geo.size.width * min(1, Double(value) / Double(a.goal)))
                    }
                }.frame(height: 5)
                Text("\(value)/\(a.goal)").font(.system(size: 10, weight: .bold)).foregroundColor(Brand.soft)
            } else {
                Text(a.detail).font(.system(size: 10, weight: .semibold)).foregroundColor(Brand.soft)
                    .multilineTextAlignment(.center).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14).padding(.horizontal, 8)
        .background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.line))
        .opacity(unlocked ? 1 : 0.9)
    }
}

// MARK: - Celebración al desbloquear un logro

struct AchievementCelebration: View {
    let achievement: Achievement
    var onDismiss: () -> Void
    @State private var pop: CGFloat = 0.4
    @State private var shine = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { onDismiss() }
            ConfettiView().frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
            VStack(spacing: 16) {
                Text("¡LOGRO DESBLOQUEADO!").font(.system(size: 13, weight: .heavy)).kerning(1).foregroundColor(Color(hex: "e2a915"))
                ZStack {
                    Circle().fill(achievement.tier.fill).frame(width: 118, height: 118)
                        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 3))
                        .shadow(color: achievement.tier.color.opacity(0.8), radius: 18)
                    Image(systemName: achievement.icon).font(.system(size: 50, weight: .heavy)).foregroundColor(.white)
                }
                .scaleEffect(pop)
                .rotationEffect(.degrees(shine ? 0 : -8))
                VStack(spacing: 4) {
                    Text(achievement.title).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                    Text(achievement.detail).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                }
                HStack(spacing: 6) {
                    Text("🪙").font(.system(size: 18))
                    Text("+\(achievement.coins) monedas").font(.system(size: 15, weight: .heavy)).foregroundColor(Color(hex: "b0824a"))
                }
                .padding(.horizontal, 14).padding(.vertical, 8).background(Brand.chip).clipShape(Capsule())
                Button { onDismiss() } label: { Text("¡Genial!").frame(maxWidth: .infinity) }
                    .buttonStyle(PrimaryButtonStyle()).padding(.top, 4)
            }
            .padding(24)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            .padding(.horizontal, 34)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = 1 }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.05)) { shine = true }
            FX.success(sound: true)
        }
    }
}
