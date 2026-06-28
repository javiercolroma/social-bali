import Foundation
import Combine

func conversationId(_ personId: String) -> String { "conv-\(personId)" }

@MainActor
final class AppStore: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var player = Player(xp: 0, streak: 0, focus: 80, hearts: 3)
    @Published var history: [HistoryEntry] = []
    @Published var profile = Profile(sex: "", age: "", country: "España", city: "Madrid", gym: "Mi gimnasio")
    @Published var savedWorkouts: [WorkoutTemplate] = []
    @Published var lastAction = "Listo para empezar"

    @Published var account: Account?
    @Published var relationships: [String: RelationshipStatus] = [:]
    @Published var conversations: [Conversation] = []
    @Published var notifications: [AppNotification] = []
    @Published var trainingPlans: [TrainingPlan] = []

    let people = AppStore.demoPeople
    let templates = AppStore.builtinTemplates

    private var loaded = false
    private let storeKey = "forge-native-v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let snap = try? JSONDecoder().decode(Persisted.self, from: data) {
            exercises = snap.exercises
            player = snap.player
            history = snap.history
            profile = snap.profile
            savedWorkouts = snap.savedWorkouts
            account = snap.account
            relationships = snap.relationships
            conversations = snap.conversations
            notifications = snap.notifications
            trainingPlans = snap.trainingPlans
        } else {
            seedDemo()
        }
        loaded = true
    }

    // MARK: - Persistence

    private struct Persisted: Codable {
        var exercises: [Exercise]
        var player: Player
        var history: [HistoryEntry]
        var profile: Profile
        var savedWorkouts: [WorkoutTemplate]
        var account: Account?
        var relationships: [String: RelationshipStatus]
        var conversations: [Conversation]
        var notifications: [AppNotification]
        var trainingPlans: [TrainingPlan]
    }

    func persist() {
        guard loaded else { return }
        let snap = Persisted(
            exercises: exercises, player: player, history: history, profile: profile,
            savedWorkouts: savedWorkouts, account: account, relationships: relationships,
            conversations: conversations, notifications: notifications, trainingPlans: trainingPlans
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    // MARK: - Computed

    var gymScore: GymScore { GymScoreEngine.calculate(history) }
    var activeExercise: Exercise? { exercises.first { $0.status == .pending } }
    var allWorkouts: [WorkoutTemplate] { templates + savedWorkouts }

    /// Workouts the user trains most often (by past sessions), else the first templates.
    var frequentWorkouts: [WorkoutTemplate] {
        let sessions = Dictionary(grouping: history) { $0.sessionId ?? $0.id }
        var counts: [String: Int] = [:]
        for (_, entries) in sessions {
            if let day = entries.first?.day { counts[day, default: 0] += 1 }
        }
        var result: [WorkoutTemplate] = []
        for day in counts.sorted(by: { $0.value > $1.value }).map(\.key) {
            if let w = allWorkouts.first(where: { $0.name == day || $0.exercises.first?.day == day }),
               !result.contains(where: { $0.id == w.id }) {
                result.append(w)
            }
            if result.count >= 3 { break }
        }
        return result.isEmpty ? Array(templates.prefix(3)) : result
    }
    var unreadMessages: Int { conversations.reduce(0) { $0 + $1.unread } }
    var unreadNotifications: Int { notifications.filter { !$0.read }.count }

    func relationship(_ personId: String) -> RelationshipStatus { relationships[personId] ?? .none }
    func person(_ id: String) -> SocialPerson? { people.first { $0.id == id } }

    // MARK: - Training

    func loadWorkout(_ template: WorkoutTemplate) {
        exercises = template.exercises.map { e in
            var copy = e
            copy.completedSets = 0
            copy.skippedSets = 0
            copy.status = .pending
            return copy
        }
        lastAction = "\(template.name) cargada"
        persist()
    }

    func adjustReps(_ id: String, _ delta: Int) {
        guard let i = exercises.firstIndex(where: { $0.id == id }) else { return }
        exercises[i].reps = max(1, exercises[i].reps + delta)
        persist()
    }

    func adjustWeight(_ id: String, _ delta: Double) {
        guard let i = exercises.firstIndex(where: { $0.id == id }) else { return }
        let next = max(0, exercises[i].weight + delta)
        exercises[i].weight = (next * 2).rounded() / 2   // keep .5 steps clean
        persist()
    }

    func registerSet(_ exerciseId: String, done: Bool) {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        var ex = exercises[idx]
        if ex.closedSets >= ex.sets { return }
        if done { ex.completedSets += 1 } else { ex.skippedSets += 1 }
        ex.status = ex.resolvedStatus
        exercises[idx] = ex
        lastAction = done ? "Serie completada" : "Serie saltada"
        persist()
    }

    // Commit the session: write history + XP, then clear the loaded workout.
    func saveSession() {
        let sid = "session-\(Int(Date().timeIntervalSince1970))"
        var gained = 0
        for ex in exercises where (ex.completedSets + ex.skippedSets) > 0 {
            let status: ExerciseStatus = ex.completedSets > 0 ? .done : .skipped
            let xp = ex.completedSets * 12 + (status == .done ? 18 : 0)
            gained += xp
            history.insert(HistoryEntry(
                id: "h-\(ex.id)-\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 0..<9999))",
                exerciseName: ex.name, day: ex.day, status: status,
                sets: ex.completedSets > 0 ? ex.completedSets : ex.sets, reps: ex.reps, weight: ex.weight,
                volume: Double(ex.completedSets) * Double(ex.reps) * ex.weight,
                xp: xp, completedAt: Date(), sessionId: sid), at: 0)
        }
        player.xp += gained
        player.streak = currentStreak()
        exercises = []
        lastAction = "Entreno guardado"
        persist()
    }

    func discardSession() {
        exercises = []
        lastAction = "Entreno descartado"
        persist()
    }

    private func currentStreak() -> Int {
        let doneDays = Set(history.filter { $0.status == .done }.map { dayKey($0.completedAt) })
        var streak = 0
        var cursor = Date()
        while doneDays.contains(dayKey(cursor)) {
            streak += 1
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    // MARK: - Account

    func saveAccount(_ acc: Account) { account = acc; persist() }

    // MARK: - Friends

    func sendFriendRequest(_ personId: String) {
        relationships[personId] = .outgoing
        persist()
        let name = person(personId)?.name ?? "Tu compañero"
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) { [weak self] in
            guard let self else { return }
            if self.relationships[personId] == .outgoing {
                self.relationships[personId] = .friends
                self.notifications.insert(AppNotification(
                    id: self.newId("n"), type: .friendAccepted, title: "Solicitud aceptada",
                    body: "\(name) ha aceptado tu solicitud de amistad.", at: Date(), read: false, personId: personId), at: 0)
                self.persist()
            }
        }
    }

    func acceptFriendRequest(_ personId: String) {
        relationships[personId] = .friends
        let name = person(personId)?.name ?? "Tu compañero"
        notifications.insert(AppNotification(
            id: newId("n"), type: .friendAccepted, title: "Nuevo amigo",
            body: "Ahora tú y \(name) sois amigos.", at: Date(), read: false, personId: personId), at: 0)
        markFriendRequestNotifsRead(personId)
        persist()
    }

    func rejectFriendRequest(_ personId: String) {
        relationships[personId] = RelationshipStatus.none
        markFriendRequestNotifsRead(personId)
        persist()
    }

    private func markFriendRequestNotifsRead(_ personId: String) {
        notifications = notifications.map {
            ($0.personId == personId && $0.type == .friendRequest) ? withRead($0) : $0
        }
    }

    // MARK: - Conversations

    @discardableResult
    func openConversation(_ personId: String) -> String {
        if !conversations.contains(where: { $0.personId == personId }) {
            conversations.insert(Conversation(id: conversationId(personId), personId: personId, messages: [], unread: 0, lastAt: Date()), at: 0)
        }
        markConversationRead(personId)
        return conversationId(personId)
    }

    func markConversationRead(_ personId: String) {
        conversations = conversations.map { c in
            guard c.personId == personId else { return c }
            var copy = c; copy.unread = 0; return copy
        }
        persist()
    }

    func sendMessage(_ personId: String, _ text: String, activeConversation: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        append(message: ChatMessage(id: newId("m"), fromMe: true, text: trimmed, at: Date()), to: personId, markRead: true)
        persist()
        scheduleReply(personId, activeConversation: activeConversation)
    }

    private func append(message: ChatMessage, to personId: String, markRead: Bool) {
        if let idx = conversations.firstIndex(where: { $0.personId == personId }) {
            var c = conversations[idx]
            c.messages.append(message)
            c.lastAt = message.at
            c.unread = (markRead || message.fromMe) ? 0 : c.unread + 1
            conversations[idx] = c
        } else {
            conversations.insert(Conversation(
                id: conversationId(personId), personId: personId, messages: [message],
                unread: (markRead || message.fromMe) ? 0 : 1, lastAt: message.at), at: 0)
        }
    }

    private func scheduleReply(_ personId: String, activeConversation: String?) {
        guard person(personId) != nil else { return }
        let replies = [
            "¡Genial! Me viene bien mañana por la tarde.",
            "Perfecto, ¿a qué hora te pasa mejor?",
            "Hecho. Nos vemos en el gym 💪",
            "Vale, te confirmo el sitio luego.",
        ]
        let text = replies.randomElement() ?? "¡Vamos!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            guard let self else { return }
            let isOpen = activeConversation == conversationId(personId)
            self.append(message: ChatMessage(id: self.newId("m"), fromMe: false, text: text, at: Date()), to: personId, markRead: isOpen)
            self.persist()
        }
    }

    // MARK: - Notifications

    func markNotificationRead(_ id: String) {
        notifications = notifications.map { $0.id == id ? withRead($0) : $0 }
        persist()
    }

    func markAllNotificationsRead() {
        notifications = notifications.map { withRead($0) }
        persist()
    }

    private func withRead(_ n: AppNotification) -> AppNotification { var c = n; c.read = true; return c }

    // MARK: - Partner

    @discardableResult
    func acceptTrainingPlan(_ personId: String, _ text: String) -> String {
        let id = conversationId(personId)
        append(message: ChatMessage(id: newId("m"), fromMe: true, text: text, at: Date()), to: personId, markRead: true)
        let name = person(personId)?.name ?? "tu compañero"
        notifications.insert(AppNotification(
            id: newId("n"), type: .trainingAccepted, title: "Entrenamiento aceptado",
            body: "Has aceptado el entreno de \(name).", at: Date(), read: false, personId: personId, conversationId: id), at: 0)
        persist()
        scheduleReply(personId, activeConversation: id)
        return id
    }

    func addPlan(title: String, when: String, place: String, spots: String, score: Int) {
        let plan = TrainingPlan(id: newId("plan"), title: title, when: when, place: place, spots: spots, ownerId: "me", score: score)
        trainingPlans.insert(plan, at: 0)
        trainingPlans = Array(trainingPlans.prefix(8))
        persist()
    }

    func deletePlan(_ id: String) {
        trainingPlans.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Workouts (create / delete)

    static func summary(of exercises: [Exercise]) -> String {
        if exercises.isEmpty { return "Sin ejercicios" }
        let names = exercises.prefix(3).map { $0.name }.joined(separator: " · ")
        return exercises.count > 3 ? "\(names)…" : names
    }

    func addWorkout(name: String, group: String, exercises: [Exercise]) {
        let g = group.trimmingCharacters(in: .whitespaces)
        let workout = WorkoutTemplate(
            id: newId("w"), name: name.isEmpty ? "Mi entreno" : name,
            description: AppStore.summary(of: exercises), block: g.isEmpty ? "Mis entrenos" : g, exercises: exercises)
        savedWorkouts.insert(workout, at: 0)
        persist()
    }

    /// Custom groups created by the user (from saved workouts).
    var customGroups: [String] {
        var seen = Set<String>()
        return savedWorkouts.map { $0.block }.filter { seen.insert($0).inserted }
    }

    func deleteWorkout(_ id: String) {
        savedWorkouts.removeAll { $0.id == id }
        persist()
    }

    func isSaved(_ id: String) -> Bool { savedWorkouts.contains { $0.id == id } }

    /// Save edits. If it's a saved workout, update in place; if it's a built-in
    /// template, create an editable copy in "Mis entrenos".
    func updateWorkout(id: String, name: String, group: String, exercises: [Exercise]) {
        let g = group.trimmingCharacters(in: .whitespaces)
        let block = g.isEmpty ? "Mis entrenos" : g
        if let idx = savedWorkouts.firstIndex(where: { $0.id == id }) {
            var w = savedWorkouts[idx]
            w.name = name.isEmpty ? "Mi entreno" : name
            w.block = block
            w.exercises = exercises
            w.description = AppStore.summary(of: exercises)
            savedWorkouts[idx] = w
            persist()
        } else {
            addWorkout(name: name, group: group, exercises: exercises)
        }
    }

    private func newId(_ prefix: String) -> String { "\(prefix)-\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 0..<100000))" }

    // MARK: - Demo seed

    private func seedDemo() {
        let now = Date()
        relationships = ["p-mika": .friends, "p-leo": .incoming]
        conversations = [Conversation(
            id: conversationId("p-mika"), personId: "p-mika",
            messages: [
                ChatMessage(id: "s1", fromMe: false, text: "¡Buen entreno el otro día!", at: now.addingTimeInterval(-3600)),
                ChatMessage(id: "s2", fromMe: true, text: "Gracias! ¿Repetimos esta semana?", at: now.addingTimeInterval(-3500)),
                ChatMessage(id: "s3", fromMe: false, text: "¿Entrenamos mañana pecho?", at: now.addingTimeInterval(-8 * 60)),
            ],
            unread: 1, lastAt: now.addingTimeInterval(-8 * 60))]
        notifications = [AppNotification(
            id: "sn1", type: .friendRequest, title: "Nueva solicitud de amistad",
            body: "Leo quiere ser tu compañero de entreno.", at: now.addingTimeInterval(-40 * 60), read: false, personId: "p-leo")]
        trainingPlans = [
            TrainingPlan(id: "plan-mika", title: "Pecho + tríceps", when: "Mañana", place: "Basic-Fit Gran Vía", spots: "1 persona", ownerId: "p-mika", score: 71),
            TrainingPlan(id: "plan-sofia", title: "Pierna", when: "Esta semana", place: "Zona cercana", spots: "2 personas", ownerId: "p-sofia", score: 64),
        ]
        player = Player(xp: 260, streak: 4, focus: 82, hearts: 3)
    }

    static let demoPeople: [SocialPerson] = [
        SocialPerson(id: "p-mika", name: "Mika", handle: "mika", avatar: "🦊", gym: "Basic-Fit Gran Vía", flag: "🇪🇸"),
        SocialPerson(id: "p-leo", name: "Leo", handle: "leo_lifts", avatar: "🐻", gym: "McFit Chamberí", flag: "🇪🇸"),
        SocialPerson(id: "p-sofia", name: "Sofía", handle: "sofia_fit", avatar: "🦅", gym: "Altafit Retiro", flag: "🇲🇽"),
        SocialPerson(id: "p-dani", name: "Dani", handle: "dani", avatar: "🐺", gym: "Basic-Fit Sol", flag: "🇦🇷"),
        SocialPerson(id: "p-vera", name: "Vera", handle: "vera_strong", avatar: "🦌", gym: "VivaGym Malasaña", flag: "🇫🇷"),
        SocialPerson(id: "p-iker", name: "Iker", handle: "iker", avatar: "🦁", gym: "Synergym Salamanca", flag: "🇪🇸"),
        SocialPerson(id: "p-noa", name: "Noa", handle: "noa_gym", avatar: "🐯", gym: "Basic-Fit Atocha", flag: "🇨🇴"),
    ]

    static func makeExercise(_ day: String, _ name: String, _ sets: Int, _ reps: Int, _ weight: Double, _ rest: Int = 120) -> Exercise {
        Exercise(id: "\(name)-\(Int.random(in: 0..<1_000_000))", day: day, name: name, targetSets: sets, sets: sets,
                 completedSets: 0, skippedSets: 0, reps: reps, weight: weight, rest: rest, note: "", status: .pending)
    }

    static let builtinTemplates: [WorkoutTemplate] = [
        WorkoutTemplate(id: "t-torso", name: "Torso A", description: "Empuje, tirón y hombro", block: "Por defecto", exercises: [
            makeExercise("Torso A", "Press banca", 4, 6, 70),
            makeExercise("Torso A", "Remo con barra", 4, 8, 65),
            makeExercise("Torso A", "Press militar", 3, 8, 42.5),
            makeExercise("Torso A", "Dominadas", 4, 6, 0),
            makeExercise("Torso A", "Elevación lateral", 3, 14, 10),
        ]),
        WorkoutTemplate(id: "t-pierna", name: "Pierna A", description: "Sentadilla, bisagra y glúteo", block: "Por defecto", exercises: [
            makeExercise("Pierna A", "Sentadilla trasera", 5, 5, 90),
            makeExercise("Pierna A", "Peso muerto rumano", 4, 8, 80),
            makeExercise("Pierna A", "Prensa de piernas", 3, 10, 140),
            makeExercise("Pierna A", "Hip thrust", 4, 8, 110),
            makeExercise("Pierna A", "Elevación de gemelos", 4, 14, 60),
        ]),
        WorkoutTemplate(id: "t-full", name: "Full body", description: "Sesión completa rápida", block: "Por defecto", exercises: [
            makeExercise("Full body", "Sentadilla goblet", 3, 10, 32),
            makeExercise("Full body", "Press banca", 3, 8, 65),
            makeExercise("Full body", "Remo mancuerna", 3, 10, 30),
            makeExercise("Full body", "Press militar", 3, 8, 40),
            makeExercise("Full body", "Plancha", 3, 40, 0),
        ]),
    ]
}

// Deterministic demo training history for a friend profile.
func buildFriendHistory(_ person: SocialPerson) -> [HistoryEntry] {
    var seed: UInt64 = 0
    for ch in person.id.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
    func rng() -> Double {
        seed = seed &+ 0x6d2b79f5
        var t = (seed ^ (seed >> 15)) &* (1 | seed)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double((t ^ (t >> 14)) & 0xffffffff) / 4294967296
    }
    let pool: [(String, Int, Int, Double)] = [
        ("Press banca", 4, 6, 80), ("Sentadilla trasera", 5, 5, 110), ("Peso muerto", 3, 5, 140),
        ("Remo con barra", 4, 8, 70), ("Press militar", 4, 6, 45), ("Dominadas lastradas", 4, 6, 15),
        ("Hip thrust", 4, 8, 120), ("Press inclinado", 4, 8, 55), ("Jalón dorsal", 3, 10, 60),
    ]
    let strength = 0.6 + rng() * 0.85
    let sessions = 10 + Int(rng() * 4)
    var entries: [HistoryEntry] = []
    let base = Date()
    for s in 0..<sessions {
        let offset = Int((Double(sessions - 1 - s) / Double(max(1, sessions - 1))) * 24)
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: base) ?? base
        let count = 3 + Int(rng() * 2)
        for e in 0..<count {
            let item = pool[Int(rng() * Double(pool.count)) % pool.count]
            let weight = max(0, (item.3 * strength / 2.5).rounded() * 2.5)
            entries.append(HistoryEntry(
                id: "f-\(person.id)-\(s)-\(e)", exerciseName: item.0, day: "Entreno", status: .done,
                sets: item.1, reps: item.2, weight: weight,
                volume: Double(item.1) * Double(item.2) * weight, xp: item.1 * 12,
                completedAt: date, sessionId: "f-\(person.id)-\(s)"))
        }
    }
    return entries
}
