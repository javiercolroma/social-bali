import Foundation

/// Un avance concreto detectado al comparar un ejercicio con la ÚLTIMA vez que apareció
/// en el historial del usuario (o con su mejor marca de siempre). No es una cifra bruta:
/// se traduce a una frase legible en la tarjeta ("En remo sentado subiste el peso un 5%").
/// Estructurado (no texto): así se localiza al RENDER (cambio de idioma en vivo) y el
/// nombre del ejercicio se traduce vía L10n.x. Se guarda EN la sesión (Codable).
struct ProgressInsight: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case newPR            // récord de 1RM estimado de SIEMPRE en ese ejercicio
        case weightUp         // más peso máximo que la última vez
        case repsUp           // mismo peso, más repeticiones que la última vez
        case e1rmUp           // más fuerza estimada (1RM Epley) que la última vez
        case avgWeightUp      // más peso medio por repetición
        case volumeUp         // más volumen (reps×peso) en ese ejercicio
        case prMatchFewerSets // igualaste tu marca con menos series (menor esfuerzo)
        case groupVolumeUp    // más volumen agregado en un grupo (espalda, pierna…)
    }

    var kind: Kind
    /// Nombre del ejercicio (o grupo) en español canónico; se traduce al mostrar con L10n.x.
    var subject: String
    /// Significado según kind: % (weight/e1rm/avg/volume/group), nº de reps (repsUp),
    /// peso máximo en kg (newPR), 0 (prMatchFewerSets).
    var amount: Double
    /// Valores crudos ANTES/AHORA para la tarjeta premium «Antes → Ahora» (0 si no aplica).
    var before: Double = 0
    var after: Double = 0

    init(kind: Kind, subject: String, amount: Double, before: Double = 0, after: Double = 0) {
        self.kind = kind; self.subject = subject; self.amount = amount
        self.before = before; self.after = after
    }

    /// Decodificación TOLERANTE: los registros antiguos (locales y del servidor) no traen
    /// `before`/`after` (campos nuevos). Sin este init, el decoder sintetizado lanza
    /// keyNotFound y tumba TODO el histórico (borraría los datos locales y vaciaría el feed).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(Kind.self, forKey: .kind)
        subject = try c.decode(String.self, forKey: .subject)
        amount = try c.decode(Double.self, forKey: .amount)
        before = try c.decodeIfPresent(Double.self, forKey: .before) ?? 0
        after = try c.decodeIfPresent(Double.self, forKey: .after) ?? 0
    }

    var id: String { "\(kind.rawValue)|\(subject)" }

    private func fmtW(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }

    // MARK: - Presentación «Antes → Ahora» (mockup premium de la tarjeta sin foto)

    /// Nombre del ejercicio ya traducido.
    var displaySubject: String { L10n.x(subject) }

    /// ¿Es un avance de EJERCICIO (con Antes→Ahora)? false = grupo/otros.
    var isExercise: Bool { kind != .groupVolumeUp }

    /// ¿Cuenta como MEJORA real (para «N mejoraron»)? «Igualaste con menos series» y el
    /// volumen de grupo no son mejoras estrictas → no suman al conteo.
    var isImprovement: Bool {
        switch kind {
        case .weightUp, .repsUp, .avgWeightUp, .e1rmUp, .volumeUp, .newPR: return true
        default: return false
        }
    }

    /// ¿Hay una comparación Antes→Ahora numérica que mostrar como tarjeta?
    var hasBeforeAfter: Bool {
        switch kind {
        case .weightUp, .repsUp, .avgWeightUp, .e1rmUp, .volumeUp, .newPR: return before > 0 || after > 0
        default: return false
        }
    }

    /// Unidad de los valores Antes/Ahora.
    var unit: String {
        switch kind {
        case .weightUp, .newPR: return "kg"
        case .repsUp: return "reps"
        case .avgWeightUp: return "kg/rep"
        case .e1rmUp: return "kg 1RM"
        case .volumeUp: return "kg vol"
        default: return ""
        }
    }

    var beforeText: String { fmtW(before) }
    var afterText: String { fmtW(after) }

    /// Insignia del delta (a la derecha de la tarjeta): «+5%», «+3 reps», «PR».
    var deltaBadge: String {
        let n = Int(amount.rounded())
        switch kind {
        case .repsUp: return String(format: NSLocalizedString("+%lld reps", comment: ""), n)
        case .newPR: return NSLocalizedString("PR", comment: "")
        case .prMatchFewerSets: return NSLocalizedString("Igualado", comment: "")
        default: return "+\(n)%"
        }
    }

    /// Icono del ejercicio (aproximado por su grupo muscular).
    var exerciseIcon: String {
        switch GymScoreEngine.pattern(for: subject).group {
        case "pierna": return "figure.strengthtraining.functional"
        case "bisagra": return "figure.strengthtraining.traditional"
        case "empuje": return "figure.strengthtraining.traditional"
        case "tiron": return "figure.rower"
        case "condicion": return "figure.core.training"
        default: return "dumbbell.fill"
        }
    }

    /// Frase ya localizada y con el nombre del ejercicio traducido. Se recalcula al
    /// reconstruirse la vista tras un cambio de idioma (root .id(languageToken)).
    var localizedText: String {
        let name = L10n.x(subject)
        let n = Int(amount.rounded())
        func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }
        switch kind {
        case .newPR:
            return String(format: L("Nuevo récord en %1$@: %2$@ kg"), name, fmtW(amount))
        case .weightUp:
            return String(format: L("En %1$@ subiste el peso máximo un %2$lld%%"), name, n)
        case .repsUp:
            return String(format: L("Con el mismo peso en %1$@, %2$lld reps más que la última vez"), name, n)
        case .e1rmUp:
            return String(format: L("Tu fuerza estimada en %1$@ subió un %2$lld%%"), name, n)
        case .avgWeightUp:
            return String(format: L("En %1$@ levantaste un %2$lld%% más de peso medio por rep"), name, n)
        case .volumeUp:
            return String(format: L("En %1$@ tu volumen subió un %2$lld%%"), name, n)
        case .prMatchFewerSets:
            return String(format: L("Igualaste tu marca en %1$@ con menos esfuerzo"), name)
        case .groupVolumeUp:
            return String(format: L("Tu volumen de %1$@ subió un %2$lld%%"), name, n)
        }
    }

    var icon: String {
        switch kind {
        case .newPR: return "trophy.fill"
        case .weightUp: return "scalemass.fill"
        case .repsUp: return "arrow.up.circle.fill"
        case .e1rmUp: return "bolt.fill"
        case .avgWeightUp: return "chart.line.uptrend.xyaxis"
        case .volumeUp: return "chart.bar.fill"
        case .prMatchFewerSets: return "checkmark.seal.fill"
        case .groupVolumeUp: return "flame.fill"
        }
    }
}

/// Motor de comparación POR EJERCICIO contra el historial propio. La comparación no es
/// entreno-completo vs. entreno-completo (dos sesiones nunca son iguales), sino ejercicio
/// a ejercicio: cada movimiento de hoy contra la última vez que lo hiciste.
enum ProgressInsights {

    // MARK: - Métricas por ejercicio (a partir de sus series reales)

    struct Metrics {
        let maxW: Double
        /// Reps del MEJOR set a la carga máxima (máximo, no suma → robusto al nº de series:
        /// hacer una serie más al mismo peso NO cuenta como "más reps").
        let topReps: Int
        let totalReps: Int
        let totalVol: Double
        /// Volumen y reps SOLO de las series de trabajo (≥85% del máximo): descarta
        /// calentamientos/aproximaciones para que la media por rep no dependa de si se
        /// registró o no un set ligero.
        let workingVol: Double
        let workingReps: Int
        let bestE1: Double
        let sets: Int
        var workingAvgWeight: Double { workingReps > 0 ? workingVol / Double(workingReps) : 0 }
    }

    /// 1RM estimado (Epley) con las reps capadas a 20 (evita valores absurdos en series muy largas).
    static func e1(_ w: Double, _ reps: Int) -> Double { w * (1 + Double(min(20, reps)) / 30) }

    static func norm(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            .trimmingCharacters(in: .whitespaces)
    }

    /// Series reales de un ejercicio: usa los logs (solo series HECHAS); si no hay, sintetiza.
    static func setsOf(_ item: SessionExercise) -> [SetLog] {
        if let l = item.logs, !l.isEmpty { return l }
        return Array(repeating: SetLog(reps: item.reps, weight: item.weight), count: max(1, item.sets))
    }

    static func metricsFromSets(_ s: [SetLog]) -> Metrics {
        let maxW = s.map(\.weight).max() ?? 0
        let topReps = s.filter { abs($0.weight - maxW) < 0.01 }.map(\.reps).max() ?? 0
        let totalReps = s.reduce(0) { $0 + $1.reps }
        let totalVol = s.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
        let heavy = s.filter { $0.weight > 0 && $0.weight >= maxW * 0.85 }   // series de trabajo
        let workingReps = heavy.reduce(0) { $0 + $1.reps }
        let workingVol = heavy.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
        let bestE1 = s.map { e1($0.weight, $0.reps) }.max() ?? 0
        return Metrics(maxW: maxW, topReps: topReps, totalReps: totalReps, totalVol: totalVol,
                       workingVol: workingVol, workingReps: workingReps, bestE1: bestE1, sets: s.count)
    }

    static func metrics(_ item: SessionExercise) -> Metrics { metricsFromSets(setsOf(item)) }

    /// Métricas del ejercicio `key` (nombre normalizado) en una sesión, CONSOLIDANDO todas
    /// sus apariciones: un mismo movimiento puede constar dos veces en un entreno y debe
    /// tratarse como uno solo (si no, se duplican ids y se dobla el volumen de grupo).
    static func metricsFor(_ key: String, in session: WorkoutSession) -> Metrics? {
        let matching = (session.items ?? []).filter { norm($0.name) == key }
        guard !matching.isEmpty else { return nil }
        return metricsFromSets(matching.flatMap { setsOf($0) })
    }

    /// Nombre de grupo (en español, traducible con L10n.x) para agregar volumen macro.
    /// nil = grupo demasiado vago para un insight ("accesorio").
    static func friendlyGroup(_ patternGroup: String) -> String? {
        switch patternGroup {
        case "pierna", "bisagra": return "pierna"
        case "empuje": return "empuje"
        case "tiron": return "espalda"
        case "condicion": return "core"
        default: return nil
        }
    }

    // MARK: - Cálculo

    /// Insights de `session` comparando cada ejercicio con su aparición previa en `history`
    /// (todas las sesiones propias). Devuelve como mucho 3, los más relevantes, solo positivos.
    static func compute(for session: WorkoutSession, history: [WorkoutSession]) -> [ProgressInsight] {
        guard let items = session.items, !items.isEmpty else { return [] }
        // Sesiones fiables ANTERIORES a esta, de más reciente a más antigua.
        let prior = history
            .filter { $0.id != session.id && $0.verified && $0.date < session.date }
            .sorted { $0.date > $1.date }
        guard !prior.isEmpty else { return [] }

        var candidates: [(insight: ProgressInsight, rank: Double)] = []
        var groupCur: [String: Double] = [:]
        var groupPrev: [String: Double] = [:]
        var seen = Set<String>()   // cada ejercicio (nombre normalizado) se procesa UNA vez

        for item in items {
            let key = norm(item.name)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            guard let cur = metricsFor(key, in: session), cur.totalReps > 0 else { continue }
            let name = item.name

            // Sesiones anteriores que contienen este ejercicio (más reciente primero) + su
            // peso máximo de SIEMPRE. metricsFor consolida apariciones repetidas por sesión.
            let priorWith = prior.filter { s in (s.items ?? []).contains { norm($0.name) == key } }
            let allTimeMaxW = priorWith.compactMap { metricsFor(key, in: $0)?.maxW }.max() ?? 0

            // Volumen macro por grupo (una vez por ejercicio, vs. su aparición previa).
            if let g = friendlyGroup(GymScoreEngine.pattern(for: name).group),
               let pSession = priorWith.first, let pm = metricsFor(key, in: pSession) {
                groupCur[g, default: 0] += cur.totalVol
                groupPrev[g, default: 0] += pm.totalVol
            }

            guard let prevSession = priorWith.first, let prev = metricsFor(key, in: prevSession) else { continue }

            // Se elige UN insight por ejercicio, por prioridad (el titular más fuerte).
            // Se guardan los valores Antes→Ahora para la tarjeta premium.
            // 1) RÉCORD: peso máximo nunca antes levantado en este ejercicio (esporádico).
            if allTimeMaxW > 0, cur.maxW > allTimeMaxW {
                candidates.append((.init(kind: .newPR, subject: name, amount: cur.maxW, before: allTimeMaxW, after: cur.maxW), 1000)); continue
            }
            // 2) Más peso que la última vez (sin ser récord absoluto).
            if prev.maxW > 0, cur.maxW > prev.maxW, let p = pctChange(cur.maxW, prev.maxW) {
                candidates.append((.init(kind: .weightUp, subject: name, amount: Double(p), before: prev.maxW, after: cur.maxW), 300 + Double(p))); continue
            }
            // 3) Mismo peso (incluido peso corporal = 0) y más reps en la MEJOR serie a esa carga.
            if abs(cur.maxW - prev.maxW) < 0.01, cur.topReps - prev.topReps >= 2 {
                let d = cur.topReps - prev.topReps
                candidates.append((.init(kind: .repsUp, subject: name, amount: Double(d), before: Double(prev.topReps), after: Double(cur.topReps)), 250 + Double(d) * 15)); continue
            }
            // 4) Más peso medio por rep en las series de TRABAJO (sin calentamientos).
            if prev.workingAvgWeight > 0, cur.workingAvgWeight > prev.workingAvgWeight, let p = pctChange(cur.workingAvgWeight, prev.workingAvgWeight) {
                candidates.append((.init(kind: .avgWeightUp, subject: name, amount: Double(p), before: prev.workingAvgWeight, after: cur.workingAvgWeight), 180 + Double(p))); continue
            }
            // 5) Más fuerza estimada (1RM).
            if prev.bestE1 > 0, cur.bestE1 > prev.bestE1, let p = pctChange(cur.bestE1, prev.bestE1) {
                candidates.append((.init(kind: .e1rmUp, subject: name, amount: Double(p), before: prev.bestE1, after: cur.bestE1), 150 + Double(p))); continue
            }
            // 6) Más volumen total (tope 60%: por encima suele ser diferencia de nº de series, no progreso).
            if prev.totalVol > 0, cur.totalVol > prev.totalVol, let p = pctChange(cur.totalVol, prev.totalVol, min: 5, max: 60) {
                candidates.append((.init(kind: .volumeUp, subject: name, amount: Double(p), before: prev.totalVol, after: cur.totalVol), 120 + Double(p))); continue
            }
            // 7) Igualaste tu marca con menos series (menor esfuerzo).
            if prev.bestE1 > 0, abs(cur.bestE1 - prev.bestE1) / prev.bestE1 < 0.01, cur.sets < prev.sets {
                candidates.append((.init(kind: .prMatchFewerSets, subject: name, amount: 0), 100)); continue
            }
        }

        // Mejor insight de grupo (uno solo, para no saturar).
        var groupBest: (ProgressInsight, Double)? = nil
        for (g, curV) in groupCur {
            guard let prevV = groupPrev[g], prevV > 0, curV > prevV, let pct = pctChange(curV, prevV, min: 5, max: 60) else { continue }
            if groupBest == nil || Double(pct) > groupBest!.1 {
                groupBest = (.init(kind: .groupVolumeUp, subject: g, amount: Double(pct)), Double(pct))
            }
        }

        // Guarda TODOS los avances de ejercicio (ordenados por relevancia) + el mejor de grupo
        // al final. El conteo "N/M mejoraron" los necesita todos; la UI capa lo que muestra.
        var out = candidates.sorted { $0.rank > $1.rank }.map { $0.insight }
        if let g = groupBest?.0 { out.append(g) }
        var seenIds = Set<String>()
        return out.filter { seenIds.insert($0.id).inserted }
    }

    /// % de subida redondeado; nil si por debajo del umbral o por encima del tope (marca previa
    /// trivial o diferencia estructural de series → ruido, no progreso real).
    private static func pctChange(_ cur: Double, _ prev: Double, min lo: Int = 3, max hi: Int = 120) -> Int? {
        guard prev > 0 else { return nil }
        let pct = Int(((cur / prev) - 1) * 100 + 0.5)
        return (pct >= lo && pct <= hi) ? pct : nil
    }
}
