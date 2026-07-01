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
    @Published var sessions: [WorkoutSession] = []
    @Published var lastAction = "Listo para empezar"

    @Published var auth: Auth?
    @Published var account: Account?
    @Published var relationships: [String: RelationshipStatus] = [:]
    @Published var conversations: [Conversation] = []
    @Published var notifications: [AppNotification] = []
    @Published var trainingPlans: [TrainingPlan] = []
    @Published var appliedKudos: Set<String> = []   // posts del muro a los que has dado aplausos
    @Published var hiddenWorkoutIds: Set<String> = []   // entrenos por defecto que el usuario ha eliminado
    @Published var seenTours: Set<String> = []   // secciones cuyo tutorial guiado ya se vio
    @Published var communitySection = 0   // 0 = Ranking, 1 = Partner (efímero; el tour lo dirige)

    // MARK: - Gamificación
    @Published var coins: Int = 0                          // moneda para la tienda de cosméticos
    @Published var unlockedAchievements: Set<String> = []  // logros conseguidos
    @Published var celebrations: [Achievement] = []        // cola de logros a celebrar (efímero)
    @Published var personalBests: [String: PersonalBest] = [:]  // récord por ejercicio (clave normalizada)
    @Published var prCount: Int = 0                        // nº de récords batidos (para logros)
    @Published var pendingPRs: [PersonalBest] = []         // cola de récords a celebrar (efímero)
    @Published var claimedQuests: Set<String> = []         // misiones reclamadas ("semana:idMision")
    @Published var questCompleted: [WeeklyQuest] = []       // misiones recién completadas a avisar (efímero)
    @Published var flashMessage: String? = nil             // aviso breve tipo toast (efímero)
    @Published var streakFreezes: Int = 0                   // congeladores para proteger la racha
    @Published var shieldedDays: Set<String> = []          // días cubiertos por un congelador (yyyy-MM-dd)
    @Published var streakMilestones: Set<Int> = []          // hitos de racha ya celebrados
    @Published var streakCelebration: Int? = nil           // hito de racha a celebrar (efímero)
    @Published var leagueTier: Int = 0                      // liga actual (0 = Bronce … 6 = Leyenda)
    @Published var leagueWeekId: String = ""               // semana a la que pertenece la liga actual
    @Published var leaguePromoted: Int? = nil              // nueva liga al ascender (efímero, para celebrar)
    @Published var ownedCosmetics: Set<String> = []        // cosméticos comprados
    @Published var equippedFrame: String? = nil            // marco de avatar equipado
    @Published var equippedForgey: String? = nil           // accesorio de Forgey equipado
    @Published var equippedTitle: String? = nil            // título mostrado en el perfil

    let people = AppStore.demoPeople
    let templates = AppStore.builtinTemplates

    /// DEBUG: salta el login (AuthView) y el onboarding mientras se depura.
    /// Pon en `false` para volver al flujo real (login → onboarding → app).
    /// Si ya se guardó una cuenta debug, reinstala/borra datos para ver de nuevo el flujo.
    static let debugSkipAuthOnboarding = false

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
            auth = snap.auth
            account = snap.account
            relationships = snap.relationships
            conversations = snap.conversations
            notifications = snap.notifications
            trainingPlans = snap.trainingPlans
            sessions = snap.sessions ?? []
            appliedKudos = Set(snap.appliedKudos ?? [])
            hiddenWorkoutIds = Set(snap.hiddenWorkoutIds ?? [])
            seenTours = Set(snap.seenTours ?? [])
            coins = snap.coins ?? 0
            unlockedAchievements = Set(snap.unlockedAchievements ?? [])
            personalBests = snap.personalBests ?? [:]
            prCount = snap.prCount ?? 0
            claimedQuests = Set(snap.claimedQuests ?? [])
            streakFreezes = snap.streakFreezes ?? 0
            shieldedDays = Set(snap.shieldedDays ?? [])
            streakMilestones = Set(snap.streakMilestones ?? [])
            leagueTier = snap.leagueTier ?? 0
            leagueWeekId = snap.leagueWeekId ?? ""
            ownedCosmetics = Set(snap.ownedCosmetics ?? [])
            equippedFrame = snap.equippedFrame
            equippedForgey = snap.equippedForgey
            equippedTitle = snap.equippedTitle
            // Migrate old "Mis entrenos" group to "Otros"
            savedWorkouts = savedWorkouts.map { w in
                guard w.block == "Mis entrenos" else { return w }
                var c = w; c.block = "Otros"; return c
            }
        } else {
            seedDemo()
        }
        // DEBUG: arranca directo en la app, sin login ni onboarding.
        if Self.debugSkipAuthOnboarding {
            if auth == nil { auth = Auth(provider: "debug", userId: "debug", email: nil, name: "Debug") }
            if account == nil { account = Account(name: "Debug", handle: "debug") }
        }
        loaded = true
        // Da por conseguidos (sin celebrar) los logros que ya cumplas al abrir.
        refreshAchievements(celebrate: false)
        resolveLeagueIfNeeded()   // ascenso/descenso si ha cambiado de semana
        claimedQuests = claimedQuests.filter { $0.hasPrefix("\(weekId):") }   // poda misiones de semanas pasadas
    }

    // MARK: - Persistence

    private struct Persisted: Codable {
        var exercises: [Exercise]
        var player: Player
        var history: [HistoryEntry]
        var profile: Profile
        var savedWorkouts: [WorkoutTemplate]
        var auth: Auth?
        var account: Account?
        var relationships: [String: RelationshipStatus]
        var conversations: [Conversation]
        var notifications: [AppNotification]
        var trainingPlans: [TrainingPlan]
        var sessions: [WorkoutSession]?
        var appliedKudos: [String]?
        var hiddenWorkoutIds: [String]?
        var seenTours: [String]?
        var coins: Int?
        var unlockedAchievements: [String]?
        var personalBests: [String: PersonalBest]?
        var prCount: Int?
        var claimedQuests: [String]?
        var streakFreezes: Int?
        var shieldedDays: [String]?
        var streakMilestones: [Int]?
        var leagueTier: Int?
        var leagueWeekId: String?
        var ownedCosmetics: [String]?
        var equippedFrame: String?
        var equippedForgey: String?
        var equippedTitle: String?
    }

    func persist() {
        guard loaded else { return }
        let snap = Persisted(
            exercises: exercises, player: player, history: history, profile: profile,
            savedWorkouts: savedWorkouts, auth: auth, account: account, relationships: relationships,
            conversations: conversations, notifications: notifications, trainingPlans: trainingPlans,
            sessions: sessions, appliedKudos: Array(appliedKudos), hiddenWorkoutIds: Array(hiddenWorkoutIds),
            seenTours: Array(seenTours), coins: coins, unlockedAchievements: Array(unlockedAchievements),
            personalBests: personalBests, prCount: prCount, claimedQuests: Array(claimedQuests),
            streakFreezes: streakFreezes, shieldedDays: Array(shieldedDays), streakMilestones: Array(streakMilestones),
            leagueTier: leagueTier, leagueWeekId: leagueWeekId,
            ownedCosmetics: Array(ownedCosmetics), equippedFrame: equippedFrame,
            equippedForgey: equippedForgey, equippedTitle: equippedTitle
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    /// Persistencia diferida (coalescente) para ráfagas de cambios como los steppers de
    /// reps/peso (incluidos los del widget): evita codificar TODO el estado en cada toque.
    private var persistGen = 0
    func persistSoon() {
        persistGen += 1
        let gen = persistGen
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            if self.persistGen == gen { self.persist() }
        }
    }

    // MARK: - Computed

    var gymScore: GymScore { GymScoreEngine.calculate(history) }
    var activeExercise: Exercise? { exercises.first { $0.status == .pending } }
    var allWorkouts: [WorkoutTemplate] { (templates + savedWorkouts).filter { !hiddenWorkoutIds.contains($0.id) } }

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

    private var scoreCache: [String: Int] = [:]
    /// Gym Score de cualquier perfil para el badge del avatar. El mío es el real;
    /// el de los demás es determinista (su historial demo no cambia) y se cachea.
    func personScore(_ id: String) -> Int {
        if id == "me" { return gymScore.total }
        if let c = scoreCache[id] { return c }
        guard let p = person(id) else { return 0 }
        let s = GymScoreEngine.calculate(buildFriendHistory(p)).total
        scoreCache[id] = s
        return s
    }

    // MARK: - Training

    func loadWorkout(_ template: WorkoutTemplate) {
        exercises = template.exercises.map { e in
            var copy = e
            copy.completedSets = 0
            copy.skippedSets = 0
            copy.status = .pending
            copy.setLog = nil
            return copy
        }
        lastAction = "\(template.name) cargada"
        persist()
    }

    func adjustReps(_ id: String, _ delta: Int) {
        guard let i = exercises.firstIndex(where: { $0.id == id }) else { return }
        exercises[i].reps = min(50, max(1, exercises[i].reps + delta))   // tope realista (anti-fake)
        persistSoon()   // ráfagas de toques: no recodificar todo el estado en cada uno
    }

    func adjustWeight(_ id: String, _ delta: Double) {
        guard let i = exercises.firstIndex(where: { $0.id == id }) else { return }
        let next = min(500, max(0, exercises[i].weight + delta))         // tope realista (anti-fake)
        exercises[i].weight = (next * 2).rounded() / 2   // keep .5 steps clean
        persistSoon()
    }

    func registerSet(_ exerciseId: String, done: Bool) {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        var ex = exercises[idx]
        if ex.closedSets >= ex.sets { return }
        if done {
            ex.completedSets += 1
            var logs = ex.setLog ?? []
            logs.append(SetLog(reps: ex.reps, weight: ex.weight))
            ex.setLog = logs
        } else { ex.skippedSets += 1 }
        ex.status = ex.resolvedStatus
        exercises[idx] = ex
        lastAction = done ? "Serie completada" : "Serie saltada"
        persist()
    }

    // Commit the session: write history + XP + a session record, then clear the workout.
    func saveSession(name: String, note: String, photoData: Data?, visibility: WorkoutVisibility, elapsed: Int,
                     avgHeartRate: Int? = nil, maxHeartRate: Int? = nil, location: String? = nil) {
        let sid = UUID().uuidString   // UUID: mismo id local y en el servidor (Supabase)
        // Estado de las misiones ANTES de esta sesión (para avisar de las que se completen).
        let questsBefore = Dictionary(uniqueKeysWithValues: Quests.weekly.map { ($0.id, questDone($0)) })
        var gained = 0
        var doneExercises = 0
        var totalSets = 0
        var totalVolume = 0.0
        var sessionItems: [SessionExercise] = []
        for ex in exercises where (ex.completedSets + ex.skippedSets) > 0 {
            let status: ExerciseStatus = ex.completedSets > 0 ? .done : .skipped
            let xp = ex.completedSets * 12 + (status == .done ? 18 : 0)
            gained += xp
            if ex.completedSets > 0 { doneExercises += 1 }
            totalSets += ex.completedSets
            let logs = ex.setLog ?? []   // setLog solo guarda las series HECHAS
            totalVolume += logs.isEmpty
                ? Double(ex.completedSets) * Double(ex.reps) * ex.weight
                : logs.reduce(0) { $0 + Double($1.reps) * $1.weight }
            // El detalle del entreno solo muestra las series HECHAS: no añadimos ejercicios
            // saltados por completo, y el conteo es el de series completadas (no las planeadas).
            if ex.completedSets > 0 {
                sessionItems.append(SessionExercise(name: ex.name, sets: ex.completedSets, reps: ex.reps, weight: ex.weight, logs: logs.isEmpty ? nil : logs))
            }
            history.insert(HistoryEntry(
                id: "h-\(ex.id)-\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 0..<9999))",
                exerciseName: ex.name, day: ex.day, status: status,
                sets: ex.completedSets > 0 ? ex.completedSets : ex.sets, reps: ex.reps, weight: ex.weight,
                volume: Double(ex.completedSets) * Double(ex.reps) * ex.weight,
                xp: xp, completedAt: Date(), sessionId: sid), at: 0)
        }
        // Plausibilidad (anti-fake): una sesión demasiado rápida no cuenta para liga/récords públicos.
        // ~20 s por serie (incluye descanso, permite EMOM/superseries) + topes por sesión.
        let verified = elapsed >= totalSets * 20 && totalSets <= 60 && gained <= 600
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let newSession = WorkoutSession(
            id: sid, name: trimmed.isEmpty ? (exercises.first?.day ?? "Entreno") : trimmed,
            note: note.trimmingCharacters(in: .whitespaces), date: Date(), elapsed: elapsed,
            exercises: doneExercises, sets: totalSets, volume: totalVolume, xp: gained,
            photoData: photoData, visibility: visibility, items: sessionItems,
            avgHeartRate: avgHeartRate, maxHeartRate: maxHeartRate,
            location: location?.trimmingCharacters(in: .whitespaces), verified: verified)
        sessions.insert(newSession, at: 0)
        player.xp += gained
        applyStreakFreeze()                    // protege la racha con congeladores si hubo un hueco
        player.streak = currentStreak()
        checkStreakMilestones()                // hitos de racha (celebra + monedas + congelador)
        detectPRs(sessionItems, verified: verified)   // récords personales (solo se celebran si es plausible)
        exercises = []
        lastAction = "Entreno guardado"
        // Misiones recién completadas por esta sesión → aviso para reclamar.
        for q in Quests.weekly where questDone(q) && !(questsBefore[q.id] ?? false) && !questClaimed(q) {
            questCompleted.append(q)
        }
        if !verified { flashMessage = "Entreno guardado. Por ser muy rápido, no cuenta para la liga ni para récords." }
        persist()
        pushSessionToBackend(newSession)       // sube la sesión a Supabase (best-effort, gateado)
        refreshAchievements(celebrate: true)   // desbloquea + celebra logros nuevos
    }

    /// Sube una sesión recién guardada al servidor (best-effort; requiere backend + sesión Supabase).
    func pushSessionToBackend(_ s: WorkoutSession) {
        guard Backend.shared.isConfigured else { return }
        Task {
            guard let uid = await Backend.shared.currentUserIdAsync() else { return }
            // Sube la foto del entreno a Storage (si hay) y guarda su URL en la fila.
            var photoURL: String? = nil
            if let photo = s.photoData { photoURL = try? await Backend.shared.uploadSessionPhoto(photo, sessionId: s.id) }
            do { try await Backend.shared.upsertSession(SessionRow(s, userId: uid, photoURL: photoURL)); print("[Backend] sesión subida: \(s.id)") }
            catch { print("[Backend] subir sesión falló:", error) }
        }
    }

    /// Fusiona el histórico local con el del servidor (server como fuente de verdad; sube las locales
    /// que aún no estén). Se llama tras iniciar sesión y en el arranque si ya hay sesión Supabase.
    func syncSessionsFromBackend() {
        guard Backend.shared.isConfigured else { return }
        Task {
            guard let uid = await Backend.shared.currentUserIdAsync() else { return }
            do {
                let server = try await Backend.shared.fetchMySessions().map { $0.asWorkoutSession }
                let serverIds = Set(server.map { $0.id })
                // Sube las locales que faltan, subiendo también su foto (si no está ya en Storage).
                for s in sessions where !serverIds.contains(s.id) && UUID(uuidString: s.id) != nil {
                    var url = s.photoURL
                    if url == nil, let photo = s.photoData {
                        url = try? await Backend.shared.uploadSessionPhoto(photo, sessionId: s.id)
                    }
                    try? await Backend.shared.upsertSession(SessionRow(s, userId: uid, photoURL: url))
                }
                // Recalcula "solo locales" desde el estado ACTUAL (puede haberse guardado una sesión
                // durante los await de arriba), para no perderla al reasignar.
                let localOnly = sessions.filter { !serverIds.contains($0.id) }
                sessions = (server + localOnly).sorted { $0.date > $1.date }
                persist()
                print("[Backend] sesiones sincronizadas: \(server.count) servidor + \(localOnly.count) locales")
            } catch { print("[Backend] sync sesiones falló:", error) }
        }
    }

    /// Detecta récords personales (mejor 1RM estimado por ejercicio). Registra el mejor
    /// de cada ejercicio y celebra solo cuando SUPERA un récord previo (no la primera vez).
    private func detectPRs(_ items: [SessionExercise], verified: Bool) {
        for item in items {
            let key = item.name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            let sets: [(w: Double, r: Int)] = (item.logs?.map { ($0.weight, $0.reps) }) ?? [(item.weight, item.reps)]
            var best: (w: Double, r: Int, e: Double)?
            for s in sets where s.w > 0 {
                let e = s.w * (1 + Double(min(20, s.r)) / 30)
                if best == nil || e > best!.e { best = (s.w, s.r, e) }
            }
            guard let b = best else { continue }
            let prev = personalBests[key]
            if prev == nil || b.e > prev!.e1rm + 0.01 {
                let pb = PersonalBest(exercise: item.name, weight: b.w, reps: b.r, e1rm: b.e, date: Date())
                personalBests[key] = pb
                // Solo se celebra/cuenta como récord público si la sesión es plausible.
                if prev != nil && verified {
                    pendingPRs.append(pb)
                    prCount += 1
                }
            }
        }
    }

    func discardSession() {
        exercises = []
        lastAction = "Entreno descartado"
        persist()
    }

    /// Si el hueco desde el último día entrenado rompería la racha, consume congeladores
    /// (cada uno cubre una ventana de 3 días) marcando días "protegidos" que puentean el hueco.
    private func applyStreakFreeze() {
        guard streakFreezes > 0 else { return }
        let cal = Calendar.current
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let realDays = Set(history.filter { $0.status == .done }.map { cal.startOfDay(for: $0.completedAt) }).sorted(by: >)
        guard realDays.count >= 2 else { return }
        let today = realDays[0]
        var prev = realDays[1]
        var gap = cal.dateComponents([.day], from: prev, to: today).day ?? 0
        while gap > 3 && streakFreezes > 0 {
            guard let shieldDate = cal.date(byAdding: .day, value: 3, to: prev) else { break }
            if shieldDate >= today { break }
            shieldedDays.insert(f.string(from: shieldDate))
            streakFreezes -= 1
            prev = shieldDate
            gap = cal.dateComponents([.day], from: prev, to: today).day ?? 0
        }
    }

    private func checkStreakMilestones() {
        for m in [7, 14, 30, 60, 100] where player.streak >= m && !streakMilestones.contains(m) {
            streakMilestones.insert(m)
            coins += m * 3
            if m == 7 || m == 30 { streakFreezes += 1 }   // regala congeladores en hitos clave
            streakCelebration = m
        }
    }

    // Racha "de gimnasio": no exige entrenar a diario. Se mantiene mientras no
    // pasen más de 3 días entre entrenos (y el último sea de los últimos 3 días).
    // Cada día entrenado dentro de esa ventana suma +1.
    private func currentStreak() -> Int {
        let cal = Calendar.current
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        // Los días protegidos por un congelador cuentan como entrenados (puentean el hueco).
        let shielded = shieldedDays.compactMap { f.date(from: $0).map { cal.startOfDay(for: $0) } }
        let trainedDays = Set(history.filter { $0.status == .done }
            .map { cal.startOfDay(for: $0.completedAt) } + shielded).sorted(by: >)
        guard let mostRecent = trainedDays.first else { return 0 }
        let today = cal.startOfDay(for: Date())
        let sinceLast = cal.dateComponents([.day], from: mostRecent, to: today).day ?? 0
        if sinceLast > 3 { return 0 } // han pasado más de 3 días sin entrenar
        var streak = 1
        var prev = mostRecent
        for day in trainedDays.dropFirst() {
            let gap = cal.dateComponents([.day], from: day, to: prev).day ?? 0
            if gap <= 3 { streak += 1; prev = day } else { break }
        }
        return streak
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    // MARK: - Account

    func saveAccount(_ acc: Account) {
        account = acc; persist()
        syncProfileToBackend()
    }

    /// Best-effort: sube el perfil a Supabase si hay backend configurado y sesión abierta.
    /// (La foto/avatar_url llegará en la fase de Storage; aquí van los campos de texto.)
    func syncProfileToBackend() {
        guard Backend.shared.isConfigured, let acc = account else { return }
        Task {
            guard let uid = await Backend.shared.currentUserIdAsync() else { return }
            // Sube el avatar a Storage (si hay) y usa su URL pública en el perfil.
            var avatarURL: String? = nil
            if let photo = acc.photoData { avatarURL = try? await Backend.shared.uploadAvatar(photo) }
            let row = ProfileRow(
                id: uid,
                handle: acc.handle,
                name: acc.name,
                avatar_url: avatarURL,
                country: profile.country.isEmpty ? nil : profile.country,
                city: profile.city.isEmpty ? nil : profile.city,
                gym: profile.gym.isEmpty ? nil : profile.gym,
                is_private: profile.isPrivate)
            do { try await Backend.shared.upsertProfile(row); print("[Backend] perfil sincronizado: @\(row.handle ?? "")") }
            catch { print("[Backend] upsert perfil falló:", error) }
        }
    }

    /// Inicia sesión con un proveedor (Apple / email / Google). Sin backend: se guarda local.
    func signIn(provider: String, userId: String, email: String?, name: String?) {
        auth = Auth(provider: provider, userId: userId, email: email, name: name)
        persist()
    }

    /// Cerrar sesión: vuelve a la pantalla de login (se conserva el perfil para reentrar).
    func logout() {
        auth = nil; persist()
        Task { await Backend.shared.signOut() }
    }

    // MARK: - Tutorial guiado por sección
    func tourSeen(_ key: String) -> Bool { seenTours.contains(key) }
    func markTourSeen(_ key: String) { seenTours.insert(key); persist() }
    /// Reinicia todos los tutoriales (para volver a verlos desde Ajustes).
    func resetTours() { seenTours = []; persist() }

    // MARK: - Seguir / solicitudes (estilo Instagram)

    /// Pulsar "Seguir / Siguiendo / Pendiente" sobre alguien.
    /// - Público: empiezas a seguir directamente (→ .friends).
    /// - Privado: se envía una solicitud (→ .outgoing, "Pendiente").
    /// Si ya lo sigues o la solicitud está pendiente, la acción la deshace.
    func followOrRequest(_ personId: String) {
        switch relationship(personId) {
        case .friends:
            relationships[personId] = .none          // dejar de seguir
        case .outgoing:
            relationships[personId] = .none          // cancelar solicitud pendiente
        default:
            if person(personId)?.isPrivate == true {
                relationships[personId] = .outgoing  // solicitud pendiente de aprobación
                scheduleFollowResponse(personId)
            } else {
                relationships[personId] = .friends    // perfil público: sigues al momento
            }
        }
        persist()
    }

    /// Compatibilidad: enviar solicitud == followOrRequest (respeta privacidad).
    func sendFriendRequest(_ personId: String) { followOrRequest(personId) }

    /// Respuesta (simulada) del usuario privado a TU solicitud de seguimiento.
    private func scheduleFollowResponse(_ personId: String) {
        let name = person(personId)?.name ?? "Esa persona"
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { [weak self] in
            guard let self, self.relationships[personId] == .outgoing else { return }
            self.relationships[personId] = .friends
            self.notifications.insert(AppNotification(
                id: self.newId("n"), type: .friendAccepted, title: "Solicitud aceptada",
                body: "\(name) ha aceptado tu solicitud de seguimiento.", at: Date(), read: false, personId: personId), at: 0)
            self.persist()
        }
    }

    /// Aceptar una solicitud de seguimiento que TE han enviado (cuenta privada).
    func acceptFriendRequest(_ personId: String) {
        relationships[personId] = .friends
        let name = person(personId)?.name ?? "Esa persona"
        updateFollowRequestNotif(personId, body: "Has aceptado la solicitud de \(name).")
        persist()
    }

    /// Rechazar una solicitud de seguimiento.
    func rejectFriendRequest(_ personId: String) {
        relationships[personId] = .none
        let name = person(personId)?.name ?? "Esa persona"
        updateFollowRequestNotif(personId, body: "Has rechazado la solicitud de \(name).")
        persist()
    }

    private func updateFollowRequestNotif(_ personId: String, body: String) {
        notifications = notifications.map { n in
            guard n.personId == personId, n.type == .friendRequest else { return n }
            var c = n; c.body = body; c.read = true; return c
        }
    }

    func follow(_ personId: String) { relationships[personId] = .friends; persist() }
    func unfollow(_ personId: String) { relationships[personId] = .none; persist() }

    /// Personas que sigues (tu red).
    var following: [SocialPerson] { people.filter { relationship($0.id) == .friends } }

    func toggleKudo(_ id: String) {
        if appliedKudos.contains(id) { appliedKudos.remove(id) } else { appliedKudos.insert(id) }
        persist()
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

    func addPlan(title: String, when: String, place: String, spots: String, score: Int, note: String? = nil) {
        let plan = TrainingPlan(id: newId("plan"), title: title, when: when, place: place, spots: spots, ownerId: "me", score: score, note: note)
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
            description: AppStore.summary(of: exercises), block: g.isEmpty ? "Otros" : g, exercises: exercises)
        savedWorkouts.insert(workout, at: 0)
        persist()
    }

    /// Custom groups created by the user (from saved workouts).
    var customGroups: [String] {
        var seen = Set<String>()
        return savedWorkouts.map { $0.block }.filter { seen.insert($0).inserted }
    }

    func deleteWorkout(_ id: String) {
        if savedWorkouts.contains(where: { $0.id == id }) {
            savedWorkouts.removeAll { $0.id == id }   // entreno propio: se borra
        } else {
            hiddenWorkoutIds.insert(id)               // entreno por defecto: se oculta
        }
        persist()
    }

    func isSaved(_ id: String) -> Bool { savedWorkouts.contains { $0.id == id } }

    /// Save edits. If it's a saved workout, update in place; if it's a built-in
    /// template, create an editable copy.
    func updateWorkout(id: String, name: String, group: String, exercises: [Exercise]) {
        let g = group.trimmingCharacters(in: .whitespaces)
        let block = g.isEmpty ? "Otros" : g
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
        // Empieza SIN seguidos para mostrar el onboarding de usuario nuevo en Social.
        // Mika aparece como recomendación; Leo, como solicitud entrante ("te quiere seguir").
        relationships = ["p-leo": .incoming]
        conversations = [Conversation(
            id: conversationId("p-mika"), personId: "p-mika",
            messages: [
                ChatMessage(id: "s1", fromMe: false, text: "¡Buen entreno el otro día!", at: now.addingTimeInterval(-3600)),
                ChatMessage(id: "s2", fromMe: true, text: "Gracias! ¿Repetimos esta semana?", at: now.addingTimeInterval(-3500)),
                ChatMessage(id: "s3", fromMe: false, text: "¿Entrenamos mañana pecho?", at: now.addingTimeInterval(-8 * 60)),
            ],
            unread: 1, lastAt: now.addingTimeInterval(-8 * 60))]
        notifications = [
            AppNotification(
                id: "sn1", type: .friendRequest, title: "Nueva solicitud de seguimiento",
                body: "Leo quiere seguirte.", at: now.addingTimeInterval(-40 * 60), read: false, personId: "p-leo"),
            AppNotification(
                id: "sn2", type: .newFollower, title: "Nuevo seguidor",
                body: "Noa ha empezado a seguirte.", at: now.addingTimeInterval(-3 * 3600), read: false, personId: "p-noa"),
        ]
        trainingPlans = [
            TrainingPlan(id: "plan-mika", title: "Pecho + tríceps", when: "Mañana", place: "Basic-Fit Gran Vía", spots: "1 persona", ownerId: "p-mika", score: 71, note: "Busco alguien para hacer fuerza por la mañana, ritmo alto."),
            TrainingPlan(id: "plan-sofia", title: "Pierna", when: "Esta semana", place: "Zona cercana", spots: "2 personas", ownerId: "p-sofia", score: 64, note: "Día de pierna durillo, se agradece motivación 💪"),
        ]
        player = Player(xp: 260, streak: 4, focus: 82, hearts: 3)
    }

    static let demoPeople: [SocialPerson] = [
        SocialPerson(id: "p-mika", name: "Mika", handle: "mika", avatar: "🦊", gym: "Basic-Fit Gran Vía", flag: "🇪🇸", city: "Madrid", country: "España"),
        SocialPerson(id: "p-leo", name: "Leo", handle: "leo_lifts", avatar: "🐻", gym: "McFit Chamberí", flag: "🇪🇸", city: "Zaragoza", country: "España"),
        SocialPerson(id: "p-sofia", name: "Sofía", handle: "sofia_fit", avatar: "🦅", gym: "Altafit Retiro", flag: "🇲🇽", city: "Ciudad de México", country: "México", isPrivate: true),
        SocialPerson(id: "p-dani", name: "Dani", handle: "dani", avatar: "🐺", gym: "Basic-Fit Sol", flag: "🇦🇷", city: "Buenos Aires", country: "Argentina"),
        SocialPerson(id: "p-vera", name: "Vera", handle: "vera_strong", avatar: "🦌", gym: "VivaGym Malasaña", flag: "🇫🇷", city: "París", country: "Francia"),
        SocialPerson(id: "p-iker", name: "Iker", handle: "iker", avatar: "🦁", gym: "Synergym Salamanca", flag: "🇪🇸", city: "Bilbao", country: "España", isPrivate: true),
        SocialPerson(id: "p-noa", name: "Noa", handle: "noa_gym", avatar: "🐯", gym: "Basic-Fit Atocha", flag: "🇨🇴", city: "Bogotá", country: "Colombia"),
    ]

    static func makeExercise(_ day: String, _ name: String, _ sets: Int, _ reps: Int, _ weight: Double, _ rest: Int = 120) -> Exercise {
        Exercise(id: "\(name)-\(Int.random(in: 0..<1_000_000))", day: day, name: name, targetSets: sets, sets: sets,
                 completedSets: 0, skippedSets: 0, reps: reps, weight: weight, rest: rest, note: "", status: .pending)
    }

    static let builtinTemplates: [WorkoutTemplate] = [
        template("t-pecho", "Pecho", [
            ("Press banca", 4, 8, 60),
            ("Press inclinado con mancuernas", 4, 10, 24),
            ("Aperturas en polea", 3, 12, 12.5),
            ("Fondos en paralelas", 3, 10, 0),
            ("Press de pecho en máquina", 3, 12, 45),
        ]),
        template("t-espalda", "Espalda", [
            ("Dominadas", 4, 8, 0),
            ("Remo con barra", 4, 10, 50),
            ("Jalón al pecho", 3, 12, 50),
            ("Remo con mancuerna", 3, 12, 24),
            ("Face pull", 3, 15, 20),
        ]),
        template("t-pierna", "Pierna", [
            ("Sentadilla trasera", 4, 8, 70),
            ("Prensa de piernas", 4, 12, 120),
            ("Peso muerto rumano", 3, 10, 60),
            ("Curl femoral tumbado", 3, 12, 35),
            ("Extensión de cuádriceps", 3, 15, 40),
            ("Elevación de gemelos", 4, 15, 50),
        ]),
        template("t-hombro", "Hombro", [
            ("Press militar", 4, 8, 35),
            ("Elevaciones laterales", 4, 15, 8),
            ("Press Arnold", 3, 10, 16),
            ("Pájaros (deltoide posterior)", 3, 15, 8),
            ("Elevaciones frontales", 3, 12, 8),
        ]),
        template("t-brazo", "Brazo", [
            ("Curl de bíceps con barra", 4, 10, 25),
            ("Curl martillo", 3, 12, 12),
            ("Press francés", 4, 10, 25),
            ("Extensión de tríceps en polea", 3, 12, 20),
            ("Curl predicador", 3, 12, 20),
            ("Fondos de tríceps en banco", 3, 12, 0),
        ]),
    ]

    private static func template(_ id: String, _ name: String, _ exercises: [(String, Int, Int, Double)]) -> WorkoutTemplate {
        let exs = exercises.map { makeExercise(name, $0.0, $0.1, $0.2, $0.3) }
        return WorkoutTemplate(id: id, name: name, description: summary(of: exs), block: name, exercises: exs)
    }

    /// Preferred order for workout groups in Plan (others go after, alphabetical).
    static let groupOrder = ["Pecho", "Espalda", "Pierna", "Hombro", "Brazo", "Abdomen", "Full body"]
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
