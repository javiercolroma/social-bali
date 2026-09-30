import SwiftUI

// MARK: - Récords personales (PRs)

struct PersonalBest: Codable, Equatable, Identifiable {
    var exercise: String
    var weight: Double
    var reps: Int
    var e1rm: Double
    var date: Date
    var id: String { exercise }
}

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
        Achievement(id: "first", title: "First step", detail: "Save your first workout",
                    icon: "figure.strengthtraining.traditional", tier: .bronze, coins: 30, goal: 1,
                    value: { min(1, $0.sessions.count) }),
        Achievement(id: "w10", title: "Consistent", detail: "Save 10 workouts",
                    icon: "checkmark.seal.fill", tier: .bronze, coins: 40, goal: 10, value: { $0.sessions.count }),
        Achievement(id: "w50", title: "Veteran", detail: "Save 50 workouts",
                    icon: "shield.lefthalf.filled", tier: .silver, coins: 90, goal: 50, value: { $0.sessions.count }),
        Achievement(id: "w100", title: "Centurion", detail: "Save 100 workouts",
                    icon: "medal.fill", tier: .gold, coins: 160, goal: 100, value: { $0.sessions.count }),
        Achievement(id: "streak7", title: "Week on fire", detail: "Hit a 7-day streak",
                    icon: "flame.fill", tier: .silver, coins: 60, goal: 7, value: { $0.player.streak }),
        Achievement(id: "streak30", title: "Unstoppable", detail: "Hit a 30-day streak",
                    icon: "bolt.fill", tier: .gold, coins: 220, goal: 30, value: { $0.player.streak }),
        Achievement(id: "oro", title: "Gold League", detail: "Reach the Gold division",
                    icon: "rosette", tier: .gold, coins: 110, goal: 45, value: { $0.gymScore.total }),
        Achievement(id: "diamante", title: "Diamond", detail: "Reach the Diamond division",
                    icon: "diamond.fill", tier: .diamond, coins: 200, goal: 75, value: { $0.gymScore.total }),
        Achievement(id: "maestro", title: "Master", detail: "Reach the Master division",
                    icon: "crown.fill", tier: .diamond, coins: 320, goal: 90, value: { $0.gymScore.total }),
        Achievement(id: "vol10k", title: "Tonnage", detail: "Lift 10,000 kg in total",
                    icon: "scalemass.fill", tier: .silver, coins: 70, goal: 10_000,
                    value: { Int($0.sessions.reduce(0.0) { $0 + $1.volume }) }),
        Achievement(id: "vol100k", title: "Crane", detail: "Lift 100,000 kg in total",
                    icon: "scalemass.fill", tier: .gold, coins: 190, goal: 100_000,
                    value: { Int($0.sessions.reduce(0.0) { $0 + $1.volume }) }),
        Achievement(id: "photo", title: "Show-off", detail: "Share a workout photo",
                    icon: "camera.fill", tier: .bronze, coins: 30, goal: 1,
                    value: { $0.sessions.contains { $0.photoData != nil || $0.photoURL != nil } ? 1 : 0 }),
        Achievement(id: "early", title: "Early bird", detail: "Train before 7:00",
                    icon: "sunrise.fill", tier: .silver, coins: 50, goal: 1,
                    value: { $0.sessions.contains { Calendar.current.component(.hour, from: $0.date) < 7 } ? 1 : 0 }),
        Achievement(id: "night", title: "Night owl", detail: "Train after 22:00",
                    icon: "moon.stars.fill", tier: .silver, coins: 50, goal: 1,
                    value: { $0.sessions.contains { Calendar.current.component(.hour, from: $0.date) >= 22 } ? 1 : 0 }),
        Achievement(id: "social", title: "Social", detail: "Follow someone",
                    icon: "person.2.fill", tier: .bronze, coins: 30, goal: 1, value: { min(1, $0.following.count) }),
        Achievement(id: "pr1", title: "Record breaker", detail: "Set your first record",
                    icon: "trophy.fill", tier: .silver, coins: 60, goal: 1, value: { max($0.prCount, $0.personalBests.count) }),
        Achievement(id: "pr10", title: "Record machine", detail: "Set 10 records",
                    icon: "trophy.fill", tier: .gold, coins: 170, goal: 10, value: { max($0.prCount, $0.personalBests.count) }),
    ]
    static func by(_ id: String) -> Achievement? { all.first { $0.id == id } }
}

extension AppStore {
    var totalAchievements: Int { Achievements.all.count }
    var unlockedCount: Int { Achievements.all.filter { unlockedAchievements.contains($0.id) }.count }
    func isUnlocked(_ id: String) -> Bool { unlockedAchievements.contains(id) }
    func achievementValue(_ a: Achievement) -> Int { min(a.goal, a.value(self)) }

    /// Desbloquea los logros cuyo objetivo ya se cumple y (si procede) los encola para celebrar.
    /// `coins` se sigue acumulando en el modelo por compatibilidad de datos, pero NO se muestra:
    /// no había tienda donde gastarlas, así que la moneda no significaba nada para el usuario.
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

// MARK: - Misiones semanales

struct WeeklyQuest: Identifiable {
    let id: String
    let title: String
    let icon: String
    let goal: Int
    let unit: String              // "días", "series", "min"…
    let reward: Int               // monedas (histórico: ya no se muestra, ver arriba)
    let xpReward: Int             // XP (alimenta nivel + liga)
    let progress: @MainActor (AppStore) -> Int
}

enum Quests {
    static let weekly: [WeeklyQuest] = [
        WeeklyQuest(id: "days3", title: "Train 3 days", icon: "calendar", goal: 3, unit: "days", reward: 50, xpReward: 30,
                    progress: { $0.weekTrainingDays() }),
        WeeklyQuest(id: "sets40", title: "Complete 40 sets", icon: "square.stack.3d.up.fill", goal: 40, unit: "sets", reward: 80, xpReward: 50,
                    progress: { $0.weekSessions().reduce(0) { $0 + $1.sets } }),
        WeeklyQuest(id: "min90", title: "Log 90 minutes", icon: "clock.fill", goal: 90, unit: "min", reward: 100, xpReward: 60,
                    progress: { Int($0.weekSessions().reduce(0) { $0 + $1.elapsed } / 60) }),
    ]
}

extension AppStore {
    /// Identificador de la semana ISO actual (para reiniciar misiones cada lunes).
    var weekId: String {
        let c = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return "\(c.yearForWeekOfYear ?? 0)-W\(c.weekOfYear ?? 0)"
    }
    func weekSessions() -> [WorkoutSession] {
        sessions.filter { weekIdFor($0.date) == weekId }   // año-seguro (semana ISO + año)
    }
    func weekTrainingDays() -> Int {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return Set(weekSessions().map { f.string(from: $0.date) }).count
    }
    func questProgress(_ q: WeeklyQuest) -> Int { min(q.goal, q.progress(self)) }
    func questDone(_ q: WeeklyQuest) -> Bool { q.progress(self) >= q.goal }
    func questClaimed(_ q: WeeklyQuest) -> Bool { claimedQuests.contains("\(weekId):\(q.id)") }
    func claimQuest(_ q: WeeklyQuest) {
        guard questDone(q), !questClaimed(q) else { return }
        coins += q.reward
        player.xp += q.xpReward
        claimedQuests.insert("\(weekId):\(q.id)")
        // Si la misión estaba en la cola de "recién completada", la quitamos.
        questCompleted.removeAll { $0.id == q.id }
        FX.success(sound: true)
        persist()
    }
}

struct WeeklyQuestsCard: View {
    @EnvironmentObject var store: AppStore
    @State private var flash: String? = nil   // id de la misión con destello "+XP"

    var body: some View {
        PanelCard {
            HStack(spacing: 7) {
                Image(systemName: "target").font(.system(size: 13)).foregroundColor(Brand.green)
                Text("WEEKLY QUESTS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                Spacer()
                Text("New on Monday · \(store.leagueDaysLeft)d").font(.system(size: 11, weight: .heavy)).foregroundColor(Brand.soft)
            }
            ForEach(Quests.weekly) { q in
                questRow(q)
                if q.id != Quests.weekly.last?.id { Divider() }
            }
        }
    }

    private func questRow(_ q: WeeklyQuest) -> some View {
        let value = store.questProgress(q)
        let done = store.questDone(q)
        let claimed = store.questClaimed(q)
        return HStack(spacing: 11) {
            ZStack {
                Circle().fill(done ? Brand.green : Brand.chip).frame(width: 34, height: 34)
                Image(systemName: q.icon).font(.system(size: 14, weight: .heavy)).foregroundColor(done ? Color(hex: "10150a") : Brand.soft)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(q.title).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Brand.chip)
                        Capsule().fill(done ? Brand.green : Brand.green.opacity(0.7))
                            .frame(width: max(6, geo.size.width * min(1, Double(value) / Double(q.goal))))
                    }
                }.frame(height: 6)
                .accessibilityValue("\(value) of \(q.goal) \(q.unit)")
                Text("\(value)/\(q.goal) \(q.unit)").font(.system(size: 11, weight: .bold)).foregroundColor(Brand.soft)
            }
            if claimed {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundColor(Brand.green)
            } else if done {
                Button {
                    FX.tap()
                    flash = q.id
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { store.claimQuest(q) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { if flash == q.id { flash = nil } }
                } label: {
                    Text("+\(q.xpReward) XP").font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                        .padding(.horizontal, 11).frame(height: 34).background(Brand.green).clipShape(Capsule())
                }.buttonStyle(.plain)
                .accessibilityLabel("Claim \(q.xpReward) XP")
                .overlay(alignment: .top) {
                    if flash == q.id {
                        Text("+\(q.xpReward) XP").font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "6ea300"))
                            .offset(y: -22).transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            } else {
                Text("+\(q.xpReward) XP").font(.system(size: 12, weight: .heavy)).foregroundColor(Brand.soft)
            }
        }
    }
}

// MARK: - Aviso de misión completada (reclamar sin abrir Actividad)

struct QuestCompleteCelebration: View {
    let quest: WeeklyQuest
    var onClaim: () -> Void
    var onDismiss: () -> Void
    @State private var pop: CGFloat = 0.4

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { onDismiss() }
            ConfettiView().frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
            VStack(spacing: 14) {
                Text("QUEST COMPLETE!").font(.system(size: 13, weight: .heavy)).kerning(1).foregroundColor(Color(hex: "6ea300"))
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: "b4ec51"), Color(hex: "8ed11d")], startPoint: .top, endPoint: .bottom))
                        .frame(width: 112, height: 112).overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 3))
                        .shadow(color: Brand.green.opacity(0.7), radius: 16)
                    Image(systemName: quest.icon).font(.system(size: 46, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                }.scaleEffect(pop)
                Text(quest.title).font(.system(size: 21, weight: .heavy)).foregroundColor(Brand.ink).multilineTextAlignment(.center)
                Text("+\(quest.xpReward) XP").font(.system(size: 14, weight: .heavy)).foregroundColor(Color(hex: "6ea300"))
                .padding(.horizontal, 14).padding(.vertical, 8).background(Brand.chip).clipShape(Capsule())
                Button { onClaim() } label: { Text("Claim reward").frame(maxWidth: .infinity) }
                    .buttonStyle(PrimaryButtonStyle()).padding(.top, 4)
                Button { onDismiss() } label: { Text("Not now").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.soft) }
            }
            .padding(24).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12).padding(.horizontal, 34)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = 1 }; FX.success(sound: true) }
    }
}

// MARK: - Liga semanal (ascenso / descenso)

struct LeagueMember: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let xp: Int
    let isMe: Bool
}

enum League {
    static let names = ["Bronze", "Silver", "Gold", "Platinum", "Diamond", "Master", "Legend"]
    static let colors = ["b0824a", "9aa3ad", "e2a915", "8fb7c9", "2fb8c6", "9b6cf2", "f2760c"]
    static let maxTier = names.count - 1
    static let promoteTop = 3       // los 3 primeros ascienden
    static let relegateBottom = 3   // los 3 últimos descienden
    static let botNames = ["Aria", "Bruno", "Chloe", "Diego", "Emma", "Fran", "Gala", "Hugo",
                           "Iris", "Jon", "Kira", "Luca", "Mara", "Nil", "Ona", "Pol", "Rita", "Saúl"]
    static let botEmojis = ["🦊", "🐻", "🦅", "🐺", "🦁", "🐯", "🐳", "🦈", "🐴", "🦉", "🐷", "🐸", "🐰", "🐨"]

    static func bots(weekId: String, tier: Int) -> [LeagueMember] {
        var seed: UInt64 = 1469598103934665603
        for ch in (weekId + "#\(tier)").unicodeScalars { seed = (seed ^ UInt64(ch.value)) &* 1099511628211 }
        return (0..<14).map { i in
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let base = 180 + tier * 130
            let xp = base + Int((seed >> 33) % UInt64(base * 3 + 250))
            return LeagueMember(id: "bot\(i)", name: botNames[i % botNames.count],
                                emoji: botEmojis[i % botEmojis.count], xp: xp, isMe: false)
        }
    }
}

extension AppStore {
    var leagueName: String { League.names[min(League.maxTier, max(0, leagueTier))] }

    private func weekIdFor(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(c.yearForWeekOfYear ?? 0)-W\(c.weekOfYear ?? 0)"
    }
    /// XP ganada en la semana ISO de `date` (suma del XP de las sesiones de esa semana).
    func weekXP(for date: Date = Date()) -> Int {
        // Solo cuentan para la liga las sesiones plausibles (anti-fake).
        sessions.filter { weekIdFor($0.date) == weekIdFor(date) && $0.verified }
            .reduce(0) { $0 + $1.xp }
    }
    /// Días que faltan para el reinicio de la liga (próximo lunes).
    var leagueDaysLeft: Int {
        let cal = Calendar.current
        guard let next = cal.nextDate(after: Date(), matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) else { return 0 }
        return max(0, cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: next)).day ?? 0)
    }
    /// Clasificación de la liga de esta semana. Con backend: usuarios REALES por XP
    /// semanal (RPC `weekly_xp_leaderboard`). Sin backend: bots deterministas + tú.
    func leagueStandings() -> [LeagueMember] {
        if Backend.shared.isConfigured {
            let meId = Backend.shared.currentUserId
            return realLeaderboard.map { r in
                LeagueMember(id: r.user_id.uuidString, name: r.name ?? r.handle ?? "Athlete",
                             emoji: "🙂", xp: r.weekly_xp, isMe: r.user_id == meId)
            }
        }
        var m = League.bots(weekId: weekId, tier: leagueTier)
        m.append(LeagueMember(id: "me", name: account?.name ?? "You", emoji: "🙂", xp: weekXP(), isMe: true))
        return m.sorted { $0.xp > $1.xp }
    }

    /// Carga la clasificación real del servidor (best-effort).
    func loadLeaderboard() {
        guard Backend.shared.isConfigured else { return }
        Task {
            let rows = (try? await Backend.shared.fetchWeeklyLeaderboard()) ?? []
            realLeaderboard = rows
        }
    }
    var myLeagueRank: Int {
        (leagueStandings().firstIndex { $0.isMe }.map { $0 + 1 }) ?? 0
    }

    /// Al cambiar de semana, resuelve la liza anterior (ascenso/descenso por posición).
    func resolveLeagueIfNeeded() {
        let now = weekId
        if leagueWeekId.isEmpty { leagueWeekId = now; persist(); return }
        guard leagueWeekId != now else { return }
        // Clasificación de la semana pasada con la tier que tenías entonces.
        let prevDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let prevWeek = weekIdFor(prevDate)
        var members = League.bots(weekId: prevWeek, tier: leagueTier)
        members.append(LeagueMember(id: "me", name: account?.name ?? "You", emoji: "🙂", xp: weekXP(for: prevDate), isMe: true))
        members.sort { $0.xp > $1.xp }
        let rank = (members.firstIndex { $0.isMe } ?? members.count - 1) + 1
        if rank <= League.promoteTop, leagueTier < League.maxTier {
            leagueTier += 1
            leaguePromoted = leagueTier
        } else if rank > members.count - League.relegateBottom, leagueTier > 0 {
            leagueTier -= 1
        }
        leagueWeekId = now
        persist()
    }
}

struct LeaguePromotionCelebration: View {
    let tier: Int
    var onDismiss: () -> Void
    @State private var pop: CGFloat = 0.4
    var body: some View {
        let idx = min(League.maxTier, max(0, tier))
        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { onDismiss() }
            ConfettiView().frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
            VStack(spacing: 14) {
                Text("PROMOTED!").font(.system(size: 13, weight: .heavy)).kerning(1).foregroundColor(Color(hex: League.colors[idx]))
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: League.colors[idx]).opacity(0.95), Color(hex: League.colors[idx]).opacity(0.6)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 118, height: 118).overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 3))
                        .shadow(color: Color(hex: League.colors[idx]).opacity(0.75), radius: 18)
                    Image(systemName: "shield.fill").font(.system(size: 48, weight: .heavy)).foregroundColor(.white)
                }.scaleEffect(pop)
                Text("\(League.names[idx]) League").font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                Text("You finished near the top and moved up a league. On to the next one!").font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                Button { onDismiss() } label: { Text("Let's go!").frame(maxWidth: .infinity) }
                    .buttonStyle(PrimaryButtonStyle()).padding(.top, 4)
            }
            .padding(24).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12).padding(.horizontal, 34)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = 1 }; FX.success(sound: true) }
    }
}

struct LeagueCard: View {
    @EnvironmentObject var store: AppStore
    var onOpen: () -> Void
    var body: some View {
        let idx = min(League.maxTier, max(0, store.leagueTier))
        Button { FX.tap(); onOpen() } label: {
            PanelCard {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(LinearGradient(colors: [Color(hex: League.colors[idx]).opacity(0.9), Color(hex: League.colors[idx]).opacity(0.6)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 46, height: 46).overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.5))
                        Image(systemName: "shield.fill").font(.system(size: 20, weight: .heavy)).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(store.leagueName) League").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                        Text("You're #\(store.myLeagueRank) · \(store.leagueDaysLeft) days left").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.soft)
                }
            }
        }.buttonStyle(.plain)
    }
}

struct LeagueView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        let idx = min(League.maxTier, max(0, store.leagueTier))
        let standings = store.leagueStandings()
        return NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Cabecera de la liga
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(LinearGradient(colors: [Color(hex: League.colors[idx]).opacity(0.95), Color(hex: League.colors[idx]).opacity(0.6)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 72, height: 72).overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 2))
                                .shadow(color: Color(hex: League.colors[idx]).opacity(0.6), radius: 10)
                            Image(systemName: "shield.fill").font(.system(size: 30, weight: .heavy)).foregroundColor(.white)
                        }
                        Text("\(store.leagueName) League").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
                        Text("Top \(League.promoteTop) move up · \(store.leagueDaysLeft) days left").font(.footnote).foregroundColor(Brand.muted)
                    }.padding(.vertical, 6)

                    PanelCard {
                        ForEach(Array(standings.enumerated()), id: \.element.id) { i, m in
                            leagueRow(i + 1, m, total: standings.count)
                            if m.id != standings.last?.id { Divider() }
                        }
                    }
                    Text("The league resets every Monday. Earn XP by training to move up.")
                        .font(.caption).foregroundColor(Brand.muted).multilineTextAlignment(.center).padding(.top, 2)
                }.padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Weekly league").navigationBarTitleDisplayMode(.inline)
        }
        .task { store.loadLeaderboard() }
    }

    private func leagueRow(_ rank: Int, _ m: LeagueMember, total: Int) -> some View {
        let promote = rank <= League.promoteTop
        let relegate = rank > total - League.relegateBottom
        return HStack(spacing: 11) {
            Text("\(rank)").font(.system(size: 14, weight: .heavy)).foregroundColor(promote ? Brand.green : (relegate ? Color(hex: "d9534f") : Brand.muted)).frame(width: 22)
            Avatar(emoji: m.isMe ? "🙂" : m.emoji, size: 32)
            Text(m.isMe ? "You" : m.name).font(.system(size: 14, weight: m.isMe ? .heavy : .semibold)).foregroundColor(Brand.ink)
            Spacer()
            Text("\(m.xp) XP").font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.soft).monospacedDigit()
            if promote { Image(systemName: "arrow.up").font(.system(size: 11, weight: .heavy)).foregroundColor(Brand.green) }
            else if relegate { Image(systemName: "arrow.down").font(.system(size: 11, weight: .heavy)).foregroundColor(Color(hex: "d9534f")) }
        }
        .padding(.vertical, 5).padding(.horizontal, 6)
        .background(m.isMe ? Brand.greenSoft.opacity(0.4) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Tarjeta de perfil: nivel + logros

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
                    Text("Level \(lv.level)").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Brand.chip)
                            Capsule().fill(Brand.green).frame(width: max(6, geo.size.width * lv.progress))
                        }
                    }.frame(height: 7)
                    Text("\(store.player.xp - lv.current) / \(lv.next - lv.current) XP").font(.system(size: 11, weight: .bold)).foregroundColor(Brand.soft)
                }
                Spacer(minLength: 8)
            }
            Divider()
            gamRow("Achievements", "trophy.fill", Color(hex: "e2a915"), trailing: "\(store.unlockedCount)/\(store.totalAchievements)", action: onOpenLogros)
        }
    }

    private func gamRow(_ title: String, _ icon: String, _ tint: Color, trailing: String, action: @escaping () -> Void) -> some View {
        Button { FX.tap(); action() } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(tint).frame(width: 18)
                Text(title).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                Spacer()
                Text(trailing).font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.soft).lineLimit(1)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
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
                            Text("\(store.unlockedCount) of \(store.totalAchievements)").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
                            Text("achievements unlocked").font(.footnote).foregroundColor(Brand.muted)
                        }
                        Spacer()
                    }
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(Achievements.all) { a in AchievementTile(a: a) }
                    }
                }.padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Achievements").navigationBarTitleDisplayMode(.inline)
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
                Text(a.detail).font(.system(size: 10, weight: .semibold)).foregroundColor(Brand.soft)
                    .multilineTextAlignment(.center).lineLimit(2)
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
                Text("ACHIEVEMENT UNLOCKED!").font(.system(size: 13, weight: .heavy)).kerning(1).foregroundColor(Color(hex: "e2a915"))
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
                Button { onDismiss() } label: { Text("Awesome!").frame(maxWidth: .infinity) }
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

// MARK: - Celebración de récord personal

struct PRCelebration: View {
    let pr: PersonalBest
    var onDismiss: () -> Void
    @State private var pop: CGFloat = 0.4

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { onDismiss() }
            ConfettiView().frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
            VStack(spacing: 14) {
                Text("NEW RECORD!").font(.system(size: 13, weight: .heavy)).kerning(1).foregroundColor(Color(hex: "6ea300"))
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: "b4ec51"), Color(hex: "8ed11d")], startPoint: .top, endPoint: .bottom))
                        .frame(width: 112, height: 112)
                        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 3))
                        .shadow(color: Brand.green.opacity(0.7), radius: 16)
                    Image(systemName: "trophy.fill").font(.system(size: 46, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                }.scaleEffect(pop)
                Text(L10n.x(pr.exercise)).font(.system(size: 21, weight: .heavy)).foregroundColor(Brand.ink).multilineTextAlignment(.center)
                Text("\(fmt(pr.weight)) kg × \(pr.reps)").font(.system(size: 26, weight: .heavy)).foregroundColor(Brand.ink)
                Text("Estimated 1RM ~\(Int(pr.e1rm.rounded())) kg").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.soft)
                Button { onDismiss() } label: { Text("Let's go!").frame(maxWidth: .infinity) }
                    .buttonStyle(PrimaryButtonStyle()).padding(.top, 4)
            }
            .padding(24)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            .padding(.horizontal, 34)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = 1 }
            FX.success(sound: true)
        }
    }
    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
}

// MARK: - Celebración de hito de racha

struct StreakCelebration: View {
    let days: Int
    let gotFreeze: Bool
    var onDismiss: () -> Void
    @State private var pop: CGFloat = 0.4

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { onDismiss() }
            ConfettiView().frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
            VStack(spacing: 14) {
                Text("STREAK ON FIRE!").font(.system(size: 13, weight: .heavy)).kerning(1).foregroundColor(Color(hex: "f2760c"))
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: "ffb03a"), Color(hex: "f2600c")], startPoint: .top, endPoint: .bottom))
                        .frame(width: 118, height: 118)
                        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 3))
                        .shadow(color: Color(hex: "f2600c").opacity(0.7), radius: 18)
                    Image(systemName: "flame.fill").font(.system(size: 52, weight: .heavy)).foregroundColor(.white)
                }.scaleEffect(pop)
                Text("\(days)-day streak").font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                Text("Keep it up, don't lose it!").font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.muted)
                if gotFreeze {
                    Text("🧊 +1 streak freeze").font(.system(size: 14, weight: .heavy)).foregroundColor(Color(hex: "2b8fd6"))
                        .padding(.horizontal, 14).padding(.vertical, 8).background(Brand.chip).clipShape(Capsule())
                }
                Button { onDismiss() } label: { Text("Bring on more!").frame(maxWidth: .infinity) }
                    .buttonStyle(PrimaryButtonStyle()).padding(.top, 4)
            }
            .padding(24)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            .padding(.horizontal, 34)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = 1 }; FX.success(sound: true) }
    }
}

// MARK: - Tarjeta de récords (para Actividad ▸ Progreso)

struct RecordsCard: View {
    @EnvironmentObject var store: AppStore
    var compact = false                 // top 3 + «Ver todos» (el detalle vive en su hoja)
    var onSeeAll: () -> Void = {}
    var body: some View {
        let records = store.personalBests.values.sorted { $0.e1rm > $1.e1rm }
        let shown = compact ? 3 : 6
        PanelCard {
            HStack(spacing: 7) {
                Image(systemName: "trophy.fill").font(.system(size: 13)).foregroundColor(Color(hex: "e2a915"))
                Text("YOUR RECORDS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                Spacer()
            }
            if records.isEmpty {
                Text("Log workouts to set your first records 💪")
                    .font(.footnote).foregroundColor(Brand.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
            } else {
                ForEach(Array(records.prefix(shown))) { r in
                    HStack {
                        Text(L10n.x(r.exercise)).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                        Spacer()
                        Text("\(fmt(r.weight)) kg × \(r.reps)").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink).monospacedDigit()
                        Text("· 1RM \(Int(r.e1rm.rounded()))").font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.soft).monospacedDigit()
                    }
                    if r.id != records.prefix(shown).last?.id { Divider() }
                }
                if compact && records.count > shown {
                    Button { FX.tap(); onSeeAll() } label: {
                        Text("See all \(records.count) records")
                            .font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(Brand.greenSoft.opacity(0.28)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
}


/// Todos los récords personales, en su propia hoja (la tarjeta de Progreso muestra el top 3).
struct AllRecordsSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    private func dismissRecords() { dismiss() }
    var body: some View {
        let records = store.personalBests.values.sorted { $0.e1rm > $1.e1rm }
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.element.id) { i, r in
                        HStack {
                            Text(L10n.x(r.exercise)).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                            Spacer()
                            Text("\(r.weight == r.weight.rounded() ? String(Int(r.weight)) : String(format: "%.1f", r.weight)) kg × \(r.reps)")
                                .font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink).monospacedDigit()
                            Text("· 1RM \(Int(r.e1rm.rounded()))").font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.soft).monospacedDigit()
                        }
                        .padding(.vertical, 10)
                        if i < records.count - 1 { Divider() }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.line))
                .padding(14)
            }
            .background(Brand.bg)
            .navigationTitle("Your records").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { SheetBackButton { dismissRecords() } } }
        }
        .presentationDetents([.large]).presentationDragIndicator(.visible)
    }
}