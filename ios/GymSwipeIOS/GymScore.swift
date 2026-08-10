import Foundation

enum GymScoreEngine {
    static let windowDays = 21
    static let reliableDays = 7          // el score pasa a "definitivo" tras 7 días entrenando
    static let reliableTrainingDays = 4

    struct Pattern { let group: String; let benchmark: Double; let compound: Double }

    static func pattern(for name: String) -> Pattern {
        let n = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        // OJO al orden: la cadena posterior va ANTES que cuádriceps, porque «peso muerto
        // rumano» o «sentadilla búlgara» contienen palabras de ambos y manda el isquio.
        // Antes «curl femoral», «buenos días» o «hip thrust a una pierna» caían en el
        // cajón de sastre «accesorio» (benchmark 70 en vez de 220): el trabajo de isquios
        // contaba de menos en el Gym Score y salía distorsionado en el reparto que ve la IA.
        if n.range(of: "peso muerto|rumano|hip thrust|femoral|isquio|gluteo|buenos dias|good morning|nordic|glute-ham|hiperextension|puente de gluteo|bulgara", options: .regularExpression) != nil {
            return Pattern(group: "bisagra", benchmark: 220, compound: 1.12)
        }
        if n.range(of: "sentadilla|prensa|zancada|pierna|gemelo|cuadriceps|hack squat|step up|pistol|sissy|aductor|abductor", options: .regularExpression) != nil {
            return Pattern(group: "pierna", benchmark: 185, compound: 1.08)
        }
        if n.range(of: "press banca|fondos|press inclinado|aperturas", options: .regularExpression) != nil {
            return Pattern(group: "empuje", benchmark: 140, compound: 1.05)
        }
        if n.range(of: "remo|dominada|jalon|pull", options: .regularExpression) != nil {
            return Pattern(group: "tiron", benchmark: 120, compound: 1.04)
        }
        if n.range(of: "core|plancha|abdominal|ruso|antirotacion|movilidad|spinning|sprint|sled", options: .regularExpression) != nil {
            return Pattern(group: "condicion", benchmark: 60, compound: 0.72)
        }
        return Pattern(group: "accesorio", benchmark: 70, compound: 0.82)
    }

    static let tiers: [(min: Int, label: String)] = [
        (85, "Legendario"), (70, "Élite"), (55, "Avanzado"),
        (40, "Competente"), (20, "Constante"), (0, "Iniciado"),
    ]

    static func tier(_ total: Int) -> String {
        tiers.first(where: { total >= $0.min })?.label ?? "Iniciado"
    }

    private static func clampScore(_ v: Double) -> Int { max(0, min(100, Int(v.rounded()))) }
    private static func clamp01(_ v: Double) -> Double { max(0, min(1, v)) }
    private static func e1rm(weight: Double, reps: Int) -> Double { weight * (1 + Double(min(20, reps)) / 30) }

    static func calculate(_ history: [HistoryEntry]) -> GymScore {
        // Anti-fake: las sesiones implausibles (verified == false) NO alimentan el score.
        // nil = datos antiguos sin marca → cuentan (compatibilidad).
        let history = history.filter { $0.verified ?? true }
        let dayMs = 24.0 * 60 * 60
        let now = Date().timeIntervalSince1970

        struct Weighted { let entry: HistoryEntry; let ageDays: Double; let weight: Double }
        func weighted(_ days: Double) -> [Weighted] {
            history.filter { $0.status == .done }.compactMap { entry in
                let age = max(0, (now - entry.completedAt.timeIntervalSince1970) / dayMs)
                guard age <= days else { return nil }
                return Weighted(entry: entry, ageDays: age, weight: max(0, 1 - age / days))
            }
        }

        let recent = weighted(Double(windowDays))
        let previous = weighted(Double(windowDays * 2)).filter { $0.ageDays > Double(windowDays) }
        let recentEntries = recent.map { $0.entry }
        let sessions = Set(recentEntries.map { $0.sessionId ?? String($0.completedAt.timeIntervalSince1970) }).count
        let trainingDays = Set(recentEntries.map { dayKey($0.completedAt) }).count
        let groups = Set(recentEntries.map { pattern(for: $0.exerciseName).group })
        let skipped = history.filter {
            let age = max(0, (now - $0.completedAt.timeIntervalSince1970) / dayMs)
            return age <= Double(windowDays) && $0.status == .skipped
        }
        let weightedVolume = recent.reduce(0.0) { $0 + $1.entry.volume * pattern(for: $1.entry.exerciseName).compound * $1.weight }
        let previousVolume = previous.reduce(0.0) { $0 + $1.entry.volume * $1.weight }

        var bestByGroup: [String: Double] = [:]
        for w in recent where w.entry.weight > 0 {
            let p = pattern(for: w.entry.exerciseName)
            let s = (e1rm(weight: w.entry.weight, reps: w.entry.reps) / p.benchmark) * 100
            bestByGroup[p.group] = max(bestByGroup[p.group] ?? 0, s)
        }

        let coverage = clamp01(Double(bestByGroup.count) / 4)
        let strengthBase = bestByGroup.isEmpty ? 0 : bestByGroup.values.map { min(105, $0) }.reduce(0, +) / Double(bestByGroup.count)
        let strength = clampScore(pow(clamp01((strengthBase * coverage) / 100), 1.3) * 100)
        let consistency = clampScore(pow(clamp01(Double(sessions) / 18), 1.35) * 100)
        let volume = clampScore(pow(clamp01((log10(weightedVolume + 1) - 3.6) / 2.4), 1.25) * 100)

        let progression: Int
        if previousVolume > 0 {
            let ratio = (weightedVolume - previousVolume) / previousVolume
            progression = clampScore(48 + (ratio >= 0 ? ratio * 90 : ratio * 240))
        } else {
            progression = recentEntries.isEmpty ? 0 : 35
        }

        let variety = clampScore(pow(clamp01(Double(groups.count) / 5), 1.7) * 100)
        let completion = Double(recentEntries.count) / Double(max(1, recentEntries.count + skipped.count))
        let quality = clampScore(pow(completion, 2.4) * 100)

        let rawWeighted = Double(strength) * 0.3 + Double(consistency) * 0.22 + Double(progression) * 0.17
            + Double(volume) * 0.13 + Double(quality) * 0.1 + Double(variety) * 0.08
        let potential = clampScore(100 * pow(clamp01(rawWeighted / 100), 1.35))

        let firstAt = history.map { $0.completedAt.timeIntervalSince1970 }.min()
        let daysTracked = firstAt == nil ? 0 : Int((now - firstAt!) / dayMs)
        let spanFactor = clamp01(Double(daysTracked) / Double(reliableDays))
        let evidence = clamp01(min(Double(trainingDays) / 5, Double(sessions) / 5))
        let reliability = spanFactor * evidence
        let reliable = daysTracked >= reliableDays && trainingDays >= reliableTrainingDays
        let total = clampScore(Double(potential) * (0.5 + 0.5 * reliability))

        return GymScore(
            total: total, potential: potential, reliability: Int((reliability * 100).rounded()),
            reliable: reliable, daysUntilReliable: max(0, reliableDays - daysTracked), tier: tier(total),
            strength: strength, consistency: consistency, volume: volume, progression: progression,
            variety: variety, quality: quality, sessions: sessions, trainingDays: trainingDays
        )
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

func getLevelProgress(_ xp: Int) -> (level: Int, progress: Double, current: Int, next: Int) {
    func xpForLevel(_ level: Int) -> Int {
        if level <= 1 { return 0 }
        return Int((120 * (pow(Double(level - 1), 1.42) + Double(level - 2) * 0.38)).rounded())
    }
    var level = 1
    while xp >= xpForLevel(level + 1) { level += 1 }
    let current = xpForLevel(level)
    let next = xpForLevel(level + 1)
    let earned = xp - current
    let needed = max(1, next - current)
    return (level, min(1, Double(earned) / Double(needed)), current, next)
}
