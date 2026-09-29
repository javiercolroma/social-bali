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

    // Con backend real NO hay bots/personas demo: la app usa usuarios reales.
    let people: [SocialPerson] = BackendConfig.isConfigured ? [] : AppStore.demoPeople
    let templates = AppStore.builtinTemplates

    /// Clasificación real de la semana (XP), cargada del servidor. Vacía sin backend.
    @Published var realLeaderboard: [LeaderRow] = []

    /// True mientras comprobamos en el servidor si el usuario ya tiene perfil (para no
    /// enseñar el onboarding a alguien que ya se registró). Efímero (no se persiste).
    @Published var checkingProfile = false

    /// A quién sigues / quién te sigue DE VERDAD (usuarios reales). Vacío sin backend.
    @Published var followingPeople: [SocialPerson] = []
    @Published var followerPeople: [SocialPerson] = []
    /// Solicitudes de seguimiento pendientes (a cuentas privadas), ids en minúscula.
    @Published var pendingFollowingIds: Set<String> = []
    /// Personas con las que tienes conversación real (para resolver nombre/avatar en Mensajes).
    @Published var messagedPeople: [SocialPerson] = []
    /// Conectar con motivo (Fase 3, ver Connections.swift): solicitudes visibles para mí
    /// (enviadas, recibidas y aceptadas) y los perfiles de quienes me las enviaron.
    @Published var connections: [ConnectionRow] = []
    @Published var connectionPeople: [SocialPerson] = []
    /// Abre el chat con esta persona desde cualquier pantalla (RootView lo observa).
    @Published var openChatWith: String? = nil
    var myUserId: String? = nil
    /// Perfil a abrir por deep link de invitación (forgeloop://user/<usuario>). Efímero.
    @Published var deepLinkPersonId: String? = nil
    /// Mi celda (~5 km) del servidor, para distancias aproximadas en Partner.
    @Published var myCell: (Double, Double)? = nil
    /// Cambia al cambiar el idioma en Ajustes → reconstruye toda la UI al instante.
    @Published var languageToken = UUID()
    /// Solicitudes de seguimiento RECIBIDAS (tu cuenta es privada) pendientes de aceptar.
    @Published var incomingRequestPeople: [SocialPerson] = []

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
        backfillInsights()        // rellena los avances de progreso de sesiones que aún no los tengan
    }

    /// Calcula los avances por-ejercicio (ProgressInsight) de las sesiones propias que aún
    /// no los tienen (campo nuevo → antiguas en nil; también las sincronizadas del servidor).
    /// Solo escribe donde falta, así que es barato y estable entre arranques.
    func backfillInsights() {
        let cap = 120   // solo las más recientes (evita cargar el arranque con historiales enormes)
        let all = sessions
        var changed = false
        // V2: los insights antiguos no traen los valores Antes/Ahora → recálculo ÚNICO (una vez).
        let needsV2 = !UserDefaults.standard.bool(forKey: "forgeInsightsV2")
        for i in sessions.indices where i < cap && sessions[i].verified {
            if sessions[i].insights == nil || needsV2 {
                sessions[i].insights = ProgressInsights.compute(for: sessions[i], history: all); changed = true
            }
            if sessions[i].medals == nil || needsV2 {
                sessions[i].medals = SessionMedals.compute(for: sessions[i], history: all); changed = true
            }
        }
        // Marca V2 solo cuando ya hay sesiones (en frío el arranque puede correr con la lista vacía
        // y las sesiones llegar luego por sync).
        if needsV2 && !sessions.isEmpty { UserDefaults.standard.set(true, forKey: "forgeInsightsV2") }
        if changed && loaded { persistSoon() }
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
        profile.enforceDatingAge()
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
    /// Ejercicio activo. En una superserie NO se hace un ejercicio entero y luego el otro:
    /// se rota (una serie de cada). El activo dentro del grupo es el pendiente con MENOS series
    /// cerradas (y, a igualdad, el primero en orden) → A·serie1, B·serie1, A·serie2, B·serie2…
    var activeExercise: Exercise? {
        guard let first = exercises.first(where: { $0.resolvedStatus == .pending }) else { return nil }
        guard let g = first.supersetGroup else { return first }
        let members = exercises.filter { $0.supersetGroup == g && $0.resolvedStatus == .pending }
        let minClosed = members.map { $0.closedSets }.min() ?? 0
        return members.first { $0.closedSets == minClosed } ?? first
    }
    /// Tus entrenos: los guardados PISAN a la plantilla predefinida con el mismo id
    /// (así, editar una predefinida conserva el id y la previsualización ve los cambios).
    var allWorkouts: [WorkoutTemplate] {
        let savedIds = Set(savedWorkouts.map { $0.id })
        return (templates.filter { !savedIds.contains($0.id) } + savedWorkouts)
            .filter { !hiddenWorkoutIds.contains($0.id) }
    }

    /// Miembros de la superserie de `ex` (en orden). Vacío si no es una superserie.
    func supersetPeers(of ex: Exercise) -> [Exercise] {
        guard let g = ex.supersetGroup else { return [] }
        return exercises.filter { $0.supersetGroup == g }
    }
    /// ¿El descanso va DESPUÉS de esta serie? En superserie solo se descansa al cerrar la ronda
    /// (cuando el siguiente activo NO es un compañero con menos series cerradas que este).
    func restsAfterSet(_ ex: Exercise) -> Bool {
        guard ex.supersetGroup != nil else { return true }
        guard let next = activeExercise, next.supersetGroup == ex.supersetGroup else { return true }
        let mine = exercises.first { $0.id == ex.id }?.closedSets ?? ex.closedSets
        return next.closedSets >= mine   // compañero "por detrás" → seguimos sin descanso
    }

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

    func relationship(_ personId: String) -> RelationshipStatus {
        // Usuarios REALES (UUID) con backend: el estado viene SOLO del servidor. El diccionario
        // `relationships` es del modo demo y PERSISTE en el dispositivo — si se consultara aquí,
        // los follows de una cuenta anterior "contaminarían" a la siguiente (bug de follow fantasma).
        if BackendConfig.isConfigured, UUID(uuidString: personId) != nil {
            let key = personId.lowercased()
            if followingPeople.contains(where: { $0.id.lowercased() == key }) { return .friends }
            if pendingFollowingIds.contains(key) { return .outgoing }
            if incomingRequestPeople.contains(where: { $0.id.lowercased() == key }) { return .incoming }
            return .none
        }
        return relationships[personId] ?? .none
    }
    func person(_ id: String) -> SocialPerson? {
        // Insensible a mayúsculas (Postgres da el UUID en minúscula; Swift en mayúscula).
        let key = id.lowercased()
        let all = people + followingPeople + followerPeople + messagedPeople + connectionPeople
        if let p = all.first(where: { $0.id.lowercased() == key }) { return p }
        // Usuario real no cacheado: placeholder para que SIEMPRE se abra el perfil;
        // FriendProfileView carga sus datos reales (nombre, sesiones, contadores).
        if BackendConfig.isConfigured, UUID(uuidString: id) != nil {
            return SocialPerson(id: id, name: "Atleta", handle: "", avatar: "🙂", gym: "")
        }
        return nil
    }

    /// Refleja un mensaje (enviado o recibido) en la lista de conversaciones al instante.
    func appendLocalMessage(_ personId: String, _ msg: ChatMessage) {
        if let i = conversations.firstIndex(where: { $0.personId == personId }) {
            if !conversations[i].messages.contains(where: { $0.id == msg.id }) {
                conversations[i].messages.append(msg)
                conversations[i].lastAt = msg.at
            }
        } else {
            conversations.insert(Conversation(id: conversationId(personId), personId: personId,
                                              messages: [msg], unread: 0, lastAt: msg.at), at: 0)
        }
        conversations.sort { $0.lastAt > $1.lastAt }
    }

    /// Construye la lista de conversaciones REALES a partir de tus mensajes del servidor.
    func loadConversations() {
        guard BackendConfig.isConfigured else { return }
        Task {
            guard let me = await Backend.shared.currentUserIdAsync() else { return }
            let meStr = me.uuidString.lowercased()
            let msgs = (try? await Backend.shared.fetchRecentMessages()) ?? []
            var byPartner: [String: [MessageRow]] = [:]
            for m in msgs {
                let partner = m.sender_id.lowercased() == meStr ? m.recipient_id : m.sender_id
                byPartner[partner, default: []].append(m)
            }
            let ids = byPartner.keys.compactMap { UUID(uuidString: $0) }
            let mp = (try? await Backend.shared.fetchProfiles(ids: ids)) ?? []
            seedScores(mp); messagedPeople = Self.asPeople(mp)
            conversations = byPartner.map { (partner, rows) in
                let msgs = rows.sorted { $0.created_at < $1.created_at }.map { r in
                    ChatMessage(id: r.id, fromMe: r.sender_id.lowercased() == meStr,
                                text: r.text, at: BackendDate.parse(r.created_at) ?? Date())
                }
                // No leídos = mensajes que ME ha mandado el otro y aún no marcados como leídos.
                let unread = rows.filter { $0.sender_id.lowercased() == partner.lowercased() && $0.read != true }.count
                return Conversation(id: conversationId(partner), personId: partner,
                                    messages: msgs, unread: unread, lastAt: msgs.last?.at ?? Date())
            }.sorted { $0.lastAt > $1.lastAt }
        }
    }

    // @Published: al refrescar un score (perfil abierto, feed cargado) TODAS las insignias
    // visibles se repintan a la vez — antes convivían valores viejos y nuevos (14 vs 16).
    @Published private var scoreCache: [String: Int] = [:]
    /// Gym Score de cualquier perfil para el badge del avatar. El mío es el real;
    /// el de los demás es determinista (su historial demo no cambia) y se cachea.
    func personScore(_ id: String) -> Int {
        if id == "me" { return gymScore.total }
        if let c = scoreCache[id.lowercased()] { return c }
        // Usuario real: NO inventamos su score. Se calcula de sus sesiones reales al abrir
        // su perfil (y se cachea con setPersonScore). Hasta entonces, 0.
        if BackendConfig.isConfigured, UUID(uuidString: id) != nil { return 0 }
        guard let p = person(id) else { return 0 }
        let s = GymScoreEngine.calculate(buildFriendHistory(p)).total
        scoreCache[id.lowercased()] = s
        return s
    }

    /// Cachea el Gym Score REAL de un usuario (calculado de sus sesiones) para pintarlo en avatares.
    func setPersonScore(_ id: String, _ score: Int) { scoreCache[id.lowercased()] = score }

    /// Siembra la caché desde perfiles del servidor (gym_score canónico que sube cada usuario).
    func seedScores(_ rows: [ProfileRow]) {
        for r in rows { if let sc = r.gym_score, sc > 0 { scoreCache[r.id.uuidString.lowercased()] = sc } }
    }

    /// Sube MI score al perfil: así todos me ven el mismo número en feed, búsquedas y perfil.
    func pushMyScore() {
        guard BackendConfig.isConfigured else { return }
        let total = gymScore.total
        Task { await Backend.shared.pushGymScore(total) }
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

    /// ¿Hay un entreno en marcha? (para no interrumpir con pop-ups de logro mientras entrenas).
    var isTraining: Bool { !exercises.isEmpty }

    /// Última marca de un ejercicio (por nombre, en cualquier entreno): la MEJOR serie
    /// (por 1RM estimado) de la sesión más reciente que lo incluyó. Para pintar
    /// "Última vez: 60 kg × 8" en la tarjeta del entreno — la razón nº1 de usar una app de gym.
    func lastPerformance(of name: String) -> (weight: Double, reps: Int, date: Date)? {
        let key = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        // Solo entrenos FIABLES: los falseados no valen como referencia.
        for s in sessions.filter({ $0.verified }).sorted(by: { $0.date > $1.date }) {
            for it in (s.items ?? []) where it.name.folding(options: .diacriticInsensitive, locale: .current).lowercased() == key {
                let sets: [(w: Double, r: Int)] = it.logs?.map { ($0.weight, $0.reps) } ?? [(it.weight, it.reps)]
                guard let best = sets.max(by: {
                    $0.w * (1 + Double(min(20, $0.r)) / 30) < $1.w * (1 + Double(min(20, $1.r)) / 30)
                }), best.w > 0 || best.r > 0 else { continue }
                return (best.w, best.r, s.date)
            }
        }
        return nil
    }

    /// Reconstruye `history` a partir de las SESIONES sincronizadas del servidor. `history` es
    /// local (no se sube), así que tras reinstalar/entrar en otro dispositivo estaría vacío y el
    /// Gym Score / racha / récords / logros saldrían a 0 pese a tener entrenos. Sintetiza una
    /// entrada por ejercicio de cada sesión que aún no esté representada (por `sessionId`).
    @discardableResult
    func rebuildHistoryFromSessions() -> Bool {
        let known = Set(history.compactMap { $0.sessionId?.lowercased() })
        var added: [HistoryEntry] = []
        for s in sessions where !known.contains(s.id.lowercased()) {
            for (i, ex) in (s.items ?? []).enumerated() {
                let logs = ex.logs ?? []
                let vol = logs.isEmpty ? Double(ex.sets) * Double(ex.reps) * ex.weight
                                       : logs.reduce(0) { $0 + Double($1.reps) * $1.weight }
                added.append(HistoryEntry(id: "\(s.id)-\(i)-\(ex.name)", exerciseName: ex.name, day: "",
                    status: .done, sets: ex.sets, reps: ex.reps, weight: ex.weight, volume: vol,
                    xp: 0, completedAt: s.date, sessionId: s.id, verified: s.verified))
            }
        }
        guard !added.isEmpty else { return false }
        history.insert(contentsOf: added, at: 0)
        return true
    }

    // Commit the session: write history + XP + a session record, then clear the workout.
    func saveSession(name: String, note: String, photoData: Data?, visibility: WorkoutVisibility, elapsed: Int,
                     avgHeartRate: Int? = nil, maxHeartRate: Int? = nil, location: String? = nil) {
        let sid = UUID().uuidString.lowercased()   // minúsculas: mismo id local y en Postgres (evita duplicados en la sync)
        // Estado de las misiones ANTES de esta sesión (para avisar de las que se completen).
        let questsBefore = Dictionary(uniqueKeysWithValues: Quests.weekly.map { ($0.id, questDone($0)) })
        var gained = 0
        var doneExercises = 0
        var totalSets = 0
        var totalVolume = 0.0
        var sessionItems: [SessionExercise] = []
        var newEntries: [HistoryEntry] = []
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
            newEntries.append(HistoryEntry(
                id: "h-\(ex.id)-\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 0..<9999))",
                exerciseName: ex.name, day: ex.day, status: status,
                sets: ex.completedSets > 0 ? ex.completedSets : ex.sets, reps: ex.reps, weight: ex.weight,
                volume: Double(ex.completedSets) * Double(ex.reps) * ex.weight,
                xp: xp, completedAt: Date(), sessionId: sid))
        }
        // Plausibilidad (anti-fake): ÚNICO criterio = duración (media ≥ 20 s por serie).
        // Sin topes de series/XP (decisión de producto). El guardado de sesiones implausibles
        // se bloquea en la UI (TrainView); esto queda como cinturón para datos sincronizados.
        let verified = FeatureFlags.allowShortWorkouts || (totalSets >= 1 && elapsed >= max(60, totalSets * 20))
        // El histórico se escribe con la marca: el Gym Score ignora las entradas no verificadas.
        for var e in newEntries.reversed() { e.verified = verified; history.insert(e, at: 0) }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let newSession = WorkoutSession(
            id: sid, name: trimmed.isEmpty ? (exercises.first?.day ?? "Entreno") : trimmed,
            note: note.trimmingCharacters(in: .whitespaces), date: Date(), elapsed: elapsed,
            exercises: doneExercises, sets: totalSets, volume: totalVolume, xp: gained,
            photoData: photoData, visibility: visibility, items: sessionItems,
            avgHeartRate: avgHeartRate, maxHeartRate: maxHeartRate,
            location: location?.trimmingCharacters(in: .whitespaces), verified: verified)
        sessions.insert(newSession, at: 0)
        // Avances por-ejercicio + logros/medallas vs. el historial propio (solo si cuenta).
        if verified {
            sessions[0].insights = ProgressInsights.compute(for: sessions[0], history: sessions)
            sessions[0].medals = SessionMedals.compute(for: sessions[0], history: sessions)
        }
        player.xp += gained
        applyStreakFreeze()                    // protege la racha con congeladores si hubo un hueco
        player.streak = currentStreak()
        checkStreakMilestones()                // hitos de racha (celebra + monedas + congelador)
        if verified { detectPRs(sessionItems, celebrate: true) }   // sesión fake → ni registra ni celebra récords
        exercises = []
        lastAction = "Entreno guardado"
        // Misiones recién completadas por esta sesión → aviso para reclamar.
        for q in Quests.weekly where questDone(q) && !(questsBefore[q.id] ?? false) && !questClaimed(q) {
            questCompleted.append(q)
        }
        if !verified { flashMessage = "Entreno guardado. Por ser muy rápido, no cuenta para la liga, los récords ni el Gym Score." }
        persist()
        pushSessionToBackend(sessions[0])      // sesiones[0] = la nueva YA con sus insights (best-effort, gateado)
        refreshAchievements(celebrate: true)   // desbloquea + celebra logros nuevos
        NotificationManager.shared.afterWorkoutSaved(streak: player.streak)   // aviso de racha en 3 días
    }

    /// Sube un entreno creado al servidor (best-effort) para que no se pierda al cerrar sesión.
    func pushWorkoutToBackend(_ w: WorkoutTemplate) {
        guard Backend.shared.isConfigured else { return }
        Task {
            guard let uid = await Backend.shared.currentUserIdAsync() else { return }
            do { try await Backend.shared.upsertWorkout(WorkoutRow(w, userId: uid)); print("[Backend] entreno subido: \(w.id)") }
            catch { print("[Backend] subir entreno falló:", error) }
        }
    }

    /// Sincroniza los entrenos creados con el servidor (fuente de verdad + sube los locales que
    /// aún no estén). Restaura tus entrenos tras cerrar sesión / reinstalar / cambiar de móvil.
    func syncWorkoutsFromBackend() {
        guard Backend.shared.isConfigured else { return }
        Task {
            guard await Backend.shared.currentUserIdAsync() != nil else { return }
            guard let rows = try? await Backend.shared.fetchMyWorkouts() else { return }
            let server = rows.map { $0.asTemplate }
            let serverIds = Set(server.map { $0.id })
            let localOnly = savedWorkouts.filter { !serverIds.contains($0.id) }
            for w in localOnly { pushWorkoutToBackend(w) }   // sube los que faltaban en el servidor
            savedWorkouts = localOnly + server               // locales sin subir primero, luego servidor
            print("[Backend] entrenos sincronizados: \(server.count) servidor + \(localOnly.count) locales")
            persist()
        }
    }

    /// Sube una sesión recién guardada al servidor (best-effort; requiere backend + sesión Supabase).
    func pushSessionToBackend(_ s: WorkoutSession) {
        guard Backend.shared.isConfigured else { return }
        Task {
            guard let uid = await Backend.shared.currentUserIdAsync() else { return }
            // Sube la foto del entreno a Storage (si hay) y guarda su URL en la fila.
            var photoURL: String? = nil
            if let photo = s.photoData {
                do { photoURL = try await Backend.shared.uploadSessionPhoto(photo, sessionId: s.id) }
                catch { print("[Backend] subir FOTO falló:", error) }   // visible, no silenciado
            }
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
                // Comparación insensible a mayúsculas (Postgres guarda el UUID en minúscula).
                let serverIds = Set(server.map { $0.id.lowercased() })
                // Sube las locales que faltan en el servidor (con su foto si la hay).
                for s in sessions where !serverIds.contains(s.id.lowercased()) && UUID(uuidString: s.id) != nil {
                    var url = s.photoURL
                    if url == nil, let photo = s.photoData {
                        url = try? await Backend.shared.uploadSessionPhoto(photo, sessionId: s.id)
                    }
                    try? await Backend.shared.upsertSession(SessionRow(s, userId: uid, photoURL: url))
                }
                // Merge SIN duplicados: server (fuente de verdad) + las locales que aún no están.
                let localOnly = sessions.filter { !serverIds.contains($0.id.lowercased()) }
                // CURACIÓN de fotos: si el servidor tiene la sesión SIN photo_url pero aquí
                // conservamos photoData (p. ej. la subida falló en su momento), re-súbela.
                let localById = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id.lowercased(), $0) })
                var merged = server.map { srv -> WorkoutSession in
                    var m = srv
                    if let loc = localById[srv.id.lowercased()] {
                        if m.photoURL == nil, loc.photoData != nil { m.photoData = loc.photoData }
                        // Insights/medallas de MIS sesiones = derivación LOCAL (fresca, con TODO
                        // mi historial y en formato V2 con Antes→Ahora): prefiere SIEMPRE el valor
                        // local sobre el del servidor (que puede ser de un formato viejo).
                        // backfill recalcula las que no tengan copia local.
                        if loc.insights != nil { m.insights = loc.insights }
                        if loc.medals != nil { m.medals = loc.medals }
                    }
                    return m
                }
                for s in merged where s.photoURL == nil && s.photoData != nil {
                    Task { [s] in
                        if let url = try? await Backend.shared.uploadSessionPhoto(s.photoData!, sessionId: s.id) {
                            try? await Backend.shared.upsertSession(SessionRow(s, userId: uid, photoURL: url))
                            print("[Backend] foto curada para sesión \(s.id)")
                        }
                    }
                }
                sessions = (merged + localOnly).sorted { $0.date > $1.date }
                // Reconstruye el histórico desde las sesiones para que el Gym Score / racha /
                // récords / logros funcionen tras reinstalar o entrar en otro dispositivo.
                rebuildHistoryFromSessions()
                detectPRsFromHistory()               // récords a partir del histórico reconstruido
                player.streak = currentStreak()
                refreshAchievements(celebrate: false) // backfill silencioso (ya conseguidos antes)
                backfillInsights()                    // las sesiones del servidor llegan sin insights: recalcúlalos
                // Cura al servidor los insights/medallas para que tus seguidores los vean:
                // (a) sesiones subidas SIN ellos (columnas nuevas) y (b) UNA vez, todas las
                // recientes → sube el formato V2 (Antes→Ahora). Best-effort.
                let v2Heal = !UserDefaults.standard.bool(forKey: "forgeSessionsV2Healed")
                let serverMissing = Set(server.filter { $0.insights == nil || $0.medals == nil }.map { $0.id.lowercased() })
                for s in sessions.prefix(120)
                    where (s.insights?.isEmpty == false || s.medals?.isEmpty == false)
                        && (v2Heal || serverMissing.contains(s.id.lowercased())) {
                    Task { [s] in try? await Backend.shared.upsertSession(SessionRow(s, userId: uid, photoURL: s.photoURL)) }
                }
                if v2Heal && !sessions.isEmpty { UserDefaults.standard.set(true, forKey: "forgeSessionsV2Healed") }
                persist()
                print("[Backend] sesiones sincronizadas: \(server.count) servidor + \(localOnly.count) locales")
            } catch { print("[Backend] sync sesiones falló:", error) }
        }
    }

    /// Reconstruye los récords (`personalBests`) a partir de TODAS las sesiones, sin celebrar.
    /// Para que "Tus récords" y los logros de récord sobrevivan a reinstalar/entrar en otro móvil.
    func detectPRsFromHistory() {
        for s in sessions where s.verified {
            detectPRs(s.items ?? [], celebrate: false)   // registra sin celebrar (backfill tras re-login)
        }
    }

    /// Detecta récords personales (mejor 1RM estimado por ejercicio). Registra el mejor
    /// de cada ejercicio y celebra solo cuando SUPERA un récord previo (no la primera vez).
    private func detectPRs(_ items: [SessionExercise], celebrate: Bool) {
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
                // Solo se celebra/cuenta si NO es un backfill silencioso.
                if prev != nil && celebrate {
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
        // Cuenta también las SESIONES (sincronizadas del servidor): así la racha sobrevive
        // a reinstalar/entrar en otro dispositivo aunque `history` sea solo local.
        let sessionDays = sessions.map { cal.startOfDay(for: $0.date) }
        let trainedDays = Set(history.filter { $0.status == .done }
            .map { cal.startOfDay(for: $0.completedAt) } + shielded + sessionDays).sorted(by: >)
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
            // La fecha va PRIMERO: el servidor rechaza «dating» si aún no la tiene.
            if let b = profile.birthdate {
                do { try await Backend.shared.upsertMyBirthdate(b) }
                catch { print("[Backend] fecha de nacimiento falló:", error) }
            }
            let row = ProfileRow(
                id: uid,
                handle: acc.handle,
                name: acc.name,
                avatar_url: avatarURL,
                country: profile.country.isEmpty ? nil : profile.country,
                city: profile.city.isEmpty ? nil : profile.city,
                gym: profile.gym.isEmpty ? nil : profile.gym,
                is_private: profile.isPrivate,
                // Club social: identidad de la PERSONA (ver PRODUCT.md · Fase 1).
                bio: profile.bio?.isEmpty == false ? profile.bio : nil,
                sports: (profile.sports?.isEmpty == false) ? profile.sports : nil,
                neighborhood: profile.neighborhood,
                home_city: profile.homeCity?.isEmpty == false ? profile.homeCity : nil,
                home_country: profile.homeCountry?.isEmpty == false ? profile.homeCountry : nil,
                stay_kind: profile.stayKind,
                stay_until: profile.stayUntil.map(StayDate.string(from:)),
                intents: (profile.intents?.isEmpty == false) ? profile.intents : nil)
            // (Los intents ya pasan por `enforceDatingAge` en cada `persist`.)
            do { try await Backend.shared.upsertProfile(row); print("[Backend] perfil sincronizado: @\(row.handle ?? "")") }
            catch { print("[Backend] upsert perfil falló:", error) }
        }
    }

    /// Inicia sesión con un proveedor (Apple / email / Google). Sin backend: se guarda local.
    func signIn(provider: String, userId: String, email: String?, name: String?) {
        auth = Auth(provider: provider, userId: userId, email: email, name: name)
        // Si hay backend y aún no hay cuenta local, marcamos "comprobando" para NO enseñar
        // el onboarding mientras miramos si ya tienes perfil en el servidor.
        if BackendConfig.isConfigured && account == nil { checkingProfile = true }
        persist()
    }

    /// Si el usuario YA tiene perfil en Supabase, reconstruye la cuenta local → se salta el
    /// onboarding. Si no (usuario nuevo), deja `account == nil` para que haga el onboarding.
    func hydrateAccountFromBackend() {
        guard BackendConfig.isConfigured, account == nil else { checkingProfile = false; return }
        checkingProfile = true
        Task {
            let found = (try? await Backend.shared.fetchMyProfile()) ?? nil
            if let p = found, let handle = p.handle, !handle.isEmpty {
                account = Account(name: p.name ?? handle, handle: handle)
                if let c = p.country { profile.country = c }
                if let c = p.city { profile.city = c }
                if let g = p.gym { profile.gym = g }
                if let pv = p.is_private { profile.isPrivate = pv }
                // Club social: sin esto, quien reinstala o cambia de móvil perdería su
                // identidad (bio, deportes, barrio, estancia) y Discover lo vería vacío.
                profile.bio = p.bio
                profile.sports = p.sports
                profile.neighborhood = p.neighborhood
                profile.homeCity = p.home_city
                profile.homeCountry = p.home_country
                profile.stayKind = p.stay_kind
                profile.stayUntil = p.stay_until.flatMap(StayDate.date(from:))
                profile.intents = p.intents
                // La fecha vive aparte (privada). Sin ella, «Dating» quedaría bloqueado
                // para alguien que ya demostró su edad antes de reinstalar.
                if let b = (try? await Backend.shared.fetchMyBirthdate()) ?? nil { profile.birthdate = b }
                // Usuario que YA existía: no le repitas el tutorial guiado del menú.
                seenTours.formUnion((0..<5).map { "tour-\($0)" })
                persist()
            }
            checkingProfile = false
        }
    }

    /// Cerrar sesión: borra TODO el estado local del usuario (como cualquier app social) para
    /// que NADA se filtre a la siguiente cuenta (follows, chats, monedas, logros, racha…).
    /// El próximo login rehidrata del servidor (perfil + entrenos) o hace onboarding si es nuevo.
    func logout() {
        Task { await Backend.shared.signOut() }
        NotificationManager.shared.cancelAll()   // sin sesión no hay recordatorios
        auth = nil
        account = nil
        exercises = []
        player = Player(xp: 0, streak: 0, focus: 80, hearts: 3)
        history = []
        profile = Profile(sex: "", age: "", country: "España", city: "Madrid", gym: "Mi gimnasio")
        savedWorkouts = []
        sessions = []
        lastAction = "Listo para empezar"
        relationships = [:]
        conversations = []
        notifications = []
        trainingPlans = []
        appliedKudos = []
        hiddenWorkoutIds = []
        coins = 0
        unlockedAchievements = []
        celebrations = []
        personalBests = [:]
        prCount = 0
        pendingPRs = []
        claimedQuests = []
        questCompleted = []
        streakFreezes = 0
        shieldedDays = []
        streakMilestones = []
        streakCelebration = nil
        leagueTier = 0
        leagueWeekId = ""
        leaguePromoted = nil
        ownedCosmetics = []
        equippedFrame = nil
        equippedForgey = nil
        equippedTitle = nil
        realLeaderboard = []
        connections = []; connectionPeople = []; myUserId = nil
        followingPeople = []
        followerPeople = []
        messagedPeople = []
        incomingRequestPeople = []
        pendingFollowingIds = []
        scoreCache = [:]
        checkingProfile = false
        persist()
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
        // Usuarios REALES: el follow/unfollow se escribe en el servidor (con estado optimista
        // para que el botón responda al instante); nada de simulaciones demo.
        if BackendConfig.isConfigured, let uid = UUID(uuidString: personId) {
            let key = personId.lowercased()
            switch relationship(personId) {
            case .friends, .outgoing:
                followingPeople.removeAll { $0.id.lowercased() == key }
                pendingFollowingIds.remove(key)
                Task { try? await Backend.shared.unfollow(uid); loadFollowing() }
            default:
                let isPrivate = person(personId)?.isPrivate == true
                if isPrivate { pendingFollowingIds.insert(key) }
                else if let p = person(personId) { followingPeople.append(p) }
                // Seguir puede desbloquear el logro "Sociable": celébralo (no estás entrenando).
                refreshAchievements(celebrate: !isTraining)
                Task {
                    do { try await Backend.shared.setFollow(uid, status: isPrivate ? "pending" : "accepted") }
                    catch { print("[Backend] FOLLOW falló:", error) }
                    loadFollowing()
                }
            }
            return
        }
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
        // Usuario REAL: acepta la solicitud en el servidor (pending → accepted).
        if BackendConfig.isConfigured, let uid = UUID(uuidString: personId) {
            let key = personId.lowercased()
            if let p = incomingRequestPeople.first(where: { $0.id.lowercased() == key }) {
                followerPeople.append(p)   // ya te sigue
            }
            incomingRequestPeople.removeAll { $0.id.lowercased() == key }
            Task { try? await Backend.shared.acceptFollowRequest(from: uid) }
            return
        }
        relationships[personId] = .friends
        let name = person(personId)?.name ?? "Esa persona"
        updateFollowRequestNotif(personId, body: "Has aceptado la solicitud de \(name).")
        persist()
    }

    /// Rechazar una solicitud de seguimiento.
    func rejectFriendRequest(_ personId: String) {
        // Usuario REAL: borra la solicitud en el servidor.
        if BackendConfig.isConfigured, let uid = UUID(uuidString: personId) {
            incomingRequestPeople.removeAll { $0.id.lowercased() == personId.lowercased() }
            Task { try? await Backend.shared.rejectFollowRequest(from: uid) }
            return
        }
        relationships[personId] = .none
        let name = person(personId)?.name ?? "Esa persona"
        updateFollowRequestNotif(personId, body: "Has rechazado la solicitud de \(name).")
        persist()
    }

    /// Deep link de invitación: busca el @usuario y abre su perfil (para seguirle).
    func openProfileByHandle(_ handle: String) {
        guard BackendConfig.isConfigured else { return }
        let h = handle.trimmingCharacters(in: .whitespaces).lowercased()
        guard !h.isEmpty else { return }
        Task {
            let results = (try? await Backend.shared.searchProfiles(h)) ?? []
            if let match = results.first(where: { ($0.handle ?? "").lowercased() == h }) ?? results.first {
                deepLinkPersonId = match.id.uuidString.lowercased()
            }
        }
    }

    /// Carga las solicitudes de seguimiento RECIBIDAS (pendientes) desde el servidor.
    func loadFollowRequests() {
        guard BackendConfig.isConfigured else { return }
        Task {
            let rows = (try? await Backend.shared.fetchFollowRequests()) ?? []
            let ids = rows.compactMap { UUID(uuidString: $0.follower_id) }
            guard !ids.isEmpty else { incomingRequestPeople = []; return }
            let ip = (try? await Backend.shared.fetchProfiles(ids: ids)) ?? []
            seedScores(ip); incomingRequestPeople = Self.asPeople(ip)
        }
    }

    /// Elimina la cuenta COMPLETA (servidor + estado local). Devuelve false si falló el servidor.
    func deleteAccount() async -> Bool {
        if BackendConfig.isConfigured {
            do { try await Backend.shared.deleteAccount() }
            catch { print("[Backend] eliminar cuenta falló:", error); return false }
        }
        logout()   // borra todo el estado local (igual que cerrar sesión)
        return true
    }

    private func updateFollowRequestNotif(_ personId: String, body: String) {
        notifications = notifications.map { n in
            guard n.personId == personId, n.type == .friendRequest else { return n }
            var c = n; c.body = body; c.read = true; return c
        }
    }

    func follow(_ personId: String) { relationships[personId] = .friends; persist() }
    func unfollow(_ personId: String) { relationships[personId] = .none; persist() }

    /// Personas que sigues (tu red). Con backend: usuarios REALES; sin backend: demo.
    var following: [SocialPerson] {
        BackendConfig.isConfigured ? followingPeople : people.filter { relationship($0.id) == .friends }
    }

    /// Carga de verdad a quién sigues Y quién te sigue (aceptados → perfiles), best-effort.
    func loadFollowing() {
        guard BackendConfig.isConfigured else { return }
        Task {
            let follows = (try? await Backend.shared.fetchFollowing()) ?? []
            let ids = follows.filter { $0.status == "accepted" }.compactMap { UUID(uuidString: $0.following_id) }
            let fp = (try? await Backend.shared.fetchProfiles(ids: ids)) ?? []
            seedScores(fp); followingPeople = Self.asPeople(fp)
            pendingFollowingIds = Set(follows.filter { $0.status == "pending" }.map { $0.following_id.lowercased() })

            let followers = (try? await Backend.shared.fetchFollowers()) ?? []
            let fids = followers.filter { $0.status == "accepted" }.compactMap { UUID(uuidString: $0.follower_id) }
            followerPeople = Self.asPeople((try? await Backend.shared.fetchProfiles(ids: fids)) ?? [])
            // Ya con la red real cargada, DESBLOQUEA (sin celebrar) los logros sociales que ya
            // cumplas — esto corre en CADA apertura, así que celebrar aquí repetiría el pop-up de
            // "Sociable" en cada arranque. La celebración va solo en el acto de seguir
            // (`followOrRequest`), que es cuando de verdad lo consigues.
            refreshAchievements(celebrate: false)
        }
        loadFollowRequests()   // solicitudes recibidas (cuentas privadas)
    }

    static func asPeople(_ profiles: [ProfileRow]) -> [SocialPerson] {
        profiles.map { p in
            SocialPerson(id: p.id.uuidString.lowercased(), name: p.name ?? p.handle ?? "Atleta",
                         handle: p.handle ?? "", avatar: "🙂", gym: p.gym ?? "",
                         city: p.city ?? "", country: p.country ?? "",
                         isPrivate: p.is_private ?? false, avatarURL: p.avatar_url, club: p.club)
        }
    }

    func toggleKudo(_ id: String) {
        let nowLiked: Bool
        if appliedKudos.contains(id) { appliedKudos.remove(id); nowLiked = false }
        else { appliedKudos.insert(id); nowLiked = true }
        persist()
        // Persiste el like REAL en el servidor (best-effort).
        if BackendConfig.isConfigured {
            Task {
                if nowLiked { try? await Backend.shared.likeSession(id) }
                else { try? await Backend.shared.unlikeSession(id) }
            }
        }
    }

    /// Carga qué sesiones he "likeado" de verdad (para el corazón relleno).
    func loadMyLikes() {
        guard BackendConfig.isConfigured else { return }
        Task { if let ids = try? await Backend.shared.likedSessionIds() { appliedKudos = Set(ids) } }
    }

    // MARK: - Conversations

    @discardableResult
    func openConversation(_ personId: String) -> String {
        // Con backend NO creamos conversaciones vacías (saldrían como "Sin mensajes todavía"):
        // la conversación aparece en la lista al enviar/recibir el primer mensaje real.
        if !BackendConfig.isConfigured && !conversations.contains(where: { $0.personId == personId }) {
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
        // Marca leídos en el servidor (para que no vuelva a contar en otro dispositivo).
        if BackendConfig.isConfigured, let uid = UUID(uuidString: personId) {
            Task { await Backend.shared.markMessagesRead(from: uid) }
        }
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
        // Usuario REAL: el mensaje viaja por el chat real (Supabase), sin bots.
        if BackendConfig.isConfigured, let uid = UUID(uuidString: personId) {
            let id = conversationId(personId.lowercased())
            appendLocalMessage(personId.lowercased(), ChatMessage(id: newId("m"), fromMe: true, text: text, at: Date()))
            Task { try? await Backend.shared.sendMessage(to: uid, text: text) }
            return id
        }
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
        if BackendConfig.isConfigured {
            // Plan REAL: se publica en el servidor y se recarga la lista.
            Task {
                try? await Backend.shared.createTrainingPlan(title: title, when: when, place: place, spots: spots, note: note)
                loadTrainingPlans()
            }
            return
        }
        let plan = TrainingPlan(id: newId("plan"), title: title, when: when, place: place, spots: spots, ownerId: "me", score: score, note: note)
        trainingPlans.insert(plan, at: 0)
        trainingPlans = Array(trainingPlans.prefix(8))
        persist()
    }

    /// Elimina un entreno del histórico: local + servidor (fila y foto). El Gym Score,
    /// la racha y las estadísticas se recalculan solos al cambiar `sessions`.
    func deleteSession(_ id: String) {
        sessions.removeAll { $0.id == id }
        rebuildHistoryFromSessions()
        persist()
        if BackendConfig.isConfigured {
            Task { await Backend.shared.deleteSession(id: id) }
            pushMyScore()
        }
    }

    /// Edita nombre/descripción/foto de una sesión propia y la re-sincroniza al servidor.
    /// `photo == nil` deja la foto como estaba; una foto nueva regenera su URL de Storage.
    /// Devuelve false si la sesión no está en el store (la UI no debe fingir que guardó).
    @discardableResult
    func updateSession(id: String, name: String, note: String, photo: Data?) -> Bool {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { sessions[idx].name = trimmed }
        sessions[idx].note = note.trimmingCharacters(in: .whitespaces)
        if let photo {
            sessions[idx].photoData = photo
            sessions[idx].photoURL = nil   // foto nueva → se vuelve a subir y se regenera la URL
        }
        persist()
        pushSessionToBackend(sessions[idx])   // re-upsert (nombre/nota) + re-sube la foto si cambió
        lastAction = "Actividad actualizada"
        return true
    }

    func deletePlan(_ id: String) {
        trainingPlans.removeAll { $0.id == id }
        if BackendConfig.isConfigured, UUID(uuidString: id) != nil {
            Task { try? await Backend.shared.deleteTrainingPlan(id: id) }
        }
        persist()
    }

    /// ¿Este plan es mío? (demo: ownerId == "me"; real: mi UUID)
    func isMyPlan(_ plan: TrainingPlan) -> Bool {
        if plan.ownerId == "me" { return true }
        if let me = Backend.shared.currentUserId?.uuidString.lowercased() { return plan.ownerId.lowercased() == me }
        return false
    }

    /// Planes REALES del servidor (últimos 14 días) → sustituyen a los demo con backend.
    func loadTrainingPlans() {
        guard BackendConfig.isConfigured else { return }
        Task {
            let rows = (try? await Backend.shared.fetchTrainingPlans()) ?? []
            trainingPlans = rows.map { r in
                TrainingPlan(id: r.id.uuidString.lowercased(), title: r.title, when: r.when_text,
                             place: r.place, spots: r.spots, ownerId: r.user_id.uuidString.lowercased(),
                             score: 0, note: r.note,
                             authorName: r.author?.name ?? r.author?.handle,
                             authorHandle: r.author?.handle,
                             authorAvatarURL: r.author?.avatar_url,
                             cellLat: r.cell_lat, cellLon: r.cell_lon)
            }
            myCell = await Backend.shared.fetchMyCell()
            persist()
        }
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
        pushWorkoutToBackend(workout)   // que sobreviva a cerrar sesión / reinstalar
    }

    /// ¿Ya tienes en el plan un entreno con este nombre? (para el estado del botón "Añadir").
    func hasSavedWorkoutNamed(_ name: String) -> Bool {
        savedWorkouts.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Añade a TU plan un entreno recibido por el chat, como entreno EDITABLE. Re-genera ids
    /// (para no colisionar con los del emisor). Puedes darle TU nombre y grupo al guardarlo;
    /// si el nombre ya existe, se añade un sufijo « (2)» para poder editar ambos por separado.
    @discardableResult
    func addSharedWorkout(_ t: WorkoutTemplate, name: String? = nil, group: String? = nil) -> WorkoutTemplate {
        let base = (name?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 } ?? t.name
        let blockOverride = (group?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 }
        var finalName = base
        if hasSavedWorkoutNamed(finalName) {
            var n = 2
            while hasSavedWorkoutNamed("\(base) (\(n))") { n += 1 }
            finalName = "\(base) (\(n))"
        }
        let reid = t.exercises.map { e -> Exercise in
            var c = e
            c.id = newId("ex"); c.completedSets = 0; c.skippedSets = 0; c.status = .pending; c.setLog = nil
            return c
        }
        let w = WorkoutTemplate(id: newId("w"), name: finalName,
                                description: AppStore.summary(of: reid),
                                block: blockOverride ?? (t.block.isEmpty ? "Compartidos" : t.block), exercises: reid)
        savedWorkouts.insert(w, at: 0)
        FX.success()
        persist()
        pushWorkoutToBackend(w)   // que sobreviva a cerrar sesión / reinstalar
        return w
    }

    /// Custom groups created by the user (from saved workouts).
    var customGroups: [String] {
        var seen = Set<String>()
        return savedWorkouts.map { $0.block }.filter { seen.insert($0).inserted }
    }

    func deleteWorkout(_ id: String) {
        if savedWorkouts.contains(where: { $0.id == id }) {
            savedWorkouts.removeAll { $0.id == id }   // entreno propio: se borra
            if Backend.shared.isConfigured {          // bórralo también en el servidor
                Task { try? await Backend.shared.deleteWorkout(id: id) }
            }
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
            pushWorkoutToBackend(w)   // sube el cambio al servidor
        } else {
            // Plantilla predefinida: la copia editable CONSERVA el id → la lista y la
            // previsualización muestran los cambios al instante (antes se creaba con id
            // nuevo y parecía que "no se guardaba").
            let g = group.trimmingCharacters(in: .whitespaces)
            let copy = WorkoutTemplate(id: id, name: name.isEmpty ? "Mi entreno" : name,
                                       description: AppStore.summary(of: exercises),
                                       block: g.isEmpty ? "Otros" : g, exercises: exercises)
            savedWorkouts.insert(copy, at: 0)
            persist()
            pushWorkoutToBackend(copy)
        }
    }

    private func newId(_ prefix: String) -> String { "\(prefix)-\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 0..<100000))" }

    // MARK: - Demo seed

    private func seedDemo() {
        // Con backend real: nada de bots ni conversaciones/planes/notificaciones demo.
        // El estado social arranca vacío y se llena con usuarios reales.
        guard !Backend.shared.isConfigured else { return }
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

    static func makeExercise(_ day: String, _ name: String, _ sets: Int, _ reps: Int, _ weight: Double, _ rest: Int = 120,
                             supersetGroup: String? = nil) -> Exercise {
        Exercise(id: "\(name)-\(Int.random(in: 0..<1_000_000))", day: day, name: name, targetSets: sets, sets: sets,
                 completedSets: 0, skippedSets: 0, reps: reps, weight: weight, rest: rest, note: "", status: .pending,
                 supersetGroup: supersetGroup)
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
