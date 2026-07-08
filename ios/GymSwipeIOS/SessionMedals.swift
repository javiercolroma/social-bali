import SwiftUI

/// Logro de un entreno estilo Strava: reconoce avances (grandes o pequeños) con una medalla
/// de oro/plata/bronce (emoji en la tarjeta; el detalle explica cuál fue). La app es GENEROSA:
/// casi cualquier mejora se convierte en medalla. Se guarda EN la sesión (Codable) y se
/// comparte al feed, igual que los insights.
struct SessionMedal: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case firstWorkout      // primer entreno de siempre
        case newExercise       // estrenaste un ejercicio
        case longestWorkout    // entreno más largo hasta ahora
        case mostVolume        // más volumen movido que nunca
        case mostSets          // más series que nunca
        case exercisePR        // récord de peso en un ejercicio
        case weeklyStreak      // varios entrenos esta semana
        case bestOfMonth       // mejor entreno del mes
    }
    enum Tier: String, Codable { case gold, silver, bronze }

    var kind: Kind
    var tier: Tier
    /// Nombre de ejercicio (exercisePR/newExercise) o vacío. Se traduce con L10n.x al mostrar.
    var subject: String
    /// Valor según kind: kg (volumen/PR), nº (series/semana), segundos (duración), 0.
    var value: Double

    var id: String { "\(kind.rawValue)|\(subject)" }
    var emoji: String { switch tier { case .gold: return "🥇"; case .silver: return "🥈"; case .bronze: return "🥉" } }
    var rank: Int { switch tier { case .gold: return 3; case .silver: return 2; case .bronze: return 1 } }
    var achTier: AchTier { switch tier { case .gold: return .gold; case .silver: return .silver; case .bronze: return .bronze } }
    var icon: String {
        switch kind {
        case .firstWorkout: return "figure.strengthtraining.traditional"
        case .newExercise: return "sparkles"
        case .longestWorkout: return "clock.badge.checkmark"
        case .mostVolume: return "scalemass.fill"
        case .mostSets: return "square.stack.3d.up.fill"
        case .exercisePR: return "trophy.fill"
        case .weeklyStreak: return "calendar.badge.checkmark"
        case .bestOfMonth: return "crown.fill"
        }
    }

    private func L(_ k: String) -> String { NSLocalizedString(k, comment: "") }

    var localizedTitle: String {
        switch kind {
        case .firstWorkout: return L("Primer entreno")
        case .newExercise: return L("Ejercicio nuevo")
        case .longestWorkout: return L("Entreno más largo")
        case .mostVolume: return L("Más volumen")
        case .mostSets: return L("Más series")
        case .exercisePR: return L("Récord personal")
        case .weeklyStreak: return L("Semana activa")
        case .bestOfMonth: return L("Mejor del mes")
        }
    }

    var localizedDetail: String {
        let v = Int(value.rounded())
        switch kind {
        case .firstWorkout: return L("¡Tu primer entrenamiento!")
        case .newExercise: return String(format: L("Estrenaste %@"), L10n.x(subject))
        case .longestWorkout: return String(format: L("Tu entreno más largo: %lld min"), max(1, v / 60))
        case .mostVolume: return String(format: L("Más peso movido que nunca: %lld kg"), v)
        case .mostSets: return String(format: L("Tu récord de series: %lld"), v)
        case .exercisePR: return String(format: L("Récord de %1$@: %2$lld kg"), L10n.x(subject), v)
        case .weeklyStreak: return String(format: L("%lld entrenos esta semana"), v)
        case .bestOfMonth: return L("Tu mejor entreno del mes")
        }
    }
}

/// Motor de medallas: mira la sesión contra el historial propio y reconoce logros con mano
/// generosa. Reutiliza la matemática por-ejercicio de `ProgressInsights`.
enum SessionMedals {
    static func compute(for session: WorkoutSession, history: [WorkoutSession]) -> [SessionMedal] {
        let prior = history.filter { $0.id != session.id && $0.verified && $0.date < session.date }

        // Primer entreno de siempre → medalla de oro (y nada más: no hay con qué comparar).
        guard !prior.isEmpty else { return [.init(kind: .firstWorkout, tier: .gold, subject: "", value: 0)] }

        var medals: [SessionMedal] = []

        // Récords de sesión frente a TODO el historial previo.
        if session.elapsed >= 300, session.elapsed > (prior.map { $0.elapsed }.max() ?? 0) {
            medals.append(.init(kind: .longestWorkout, tier: .gold, subject: "", value: Double(session.elapsed)))
        }
        if session.volume > 0, session.volume > (prior.map { $0.volume }.max() ?? 0) {
            medals.append(.init(kind: .mostVolume, tier: .gold, subject: "", value: session.volume))
        }
        if session.sets >= 3, session.sets > (prior.map { $0.sets }.max() ?? 0) {
            medals.append(.init(kind: .mostSets, tier: .silver, subject: "", value: Double(session.sets)))
        }

        // PR de peso en un ejercicio (nunca antes levantado tanto) → una medalla, el más alto.
        var bestPR: (String, Double)? = nil
        for item in (session.items ?? []) {
            let key = ProgressInsights.norm(item.name)
            let cur = ProgressInsights.metricsFor(key, in: session)?.maxW ?? 0
            let allPrior = prior.compactMap { ProgressInsights.metricsFor(key, in: $0)?.maxW }.max() ?? 0
            if allPrior > 0, cur > allPrior, bestPR == nil || cur > bestPR!.1 { bestPR = (item.name, cur) }
        }
        if let pr = bestPR { medals.append(.init(kind: .exercisePR, tier: .gold, subject: pr.0, value: pr.1)) }

        // Ejercicio estrenado (no aparece en ningún entreno previo).
        let priorNames = Set(prior.flatMap { ($0.items ?? []).map { ProgressInsights.norm($0.name) } })
        if let newEx = (session.items ?? []).first(where: { !priorNames.contains(ProgressInsights.norm($0.name)) }) {
            medals.append(.init(kind: .newExercise, tier: .bronze, subject: newEx.name, value: 0))
        }

        // Frecuencia: nº de entrenos en los 7 días que terminan en esta sesión.
        let weekAgo = session.date.addingTimeInterval(-7 * 86400)
        let thisWeek = 1 + prior.filter { $0.date > weekAgo && $0.date <= session.date }.count
        if thisWeek >= 3 { medals.append(.init(kind: .weeklyStreak, tier: .silver, subject: "", value: Double(thisWeek))) }

        // Mejor del mes por volumen (empatar o superar el máximo del mes en curso).
        let cal = Calendar.current
        let sameMonth = prior.filter { cal.isDate($0.date, equalTo: session.date, toGranularity: .month) }
        if session.volume > 0, !sameMonth.isEmpty, session.volume >= (sameMonth.map { $0.volume }.max() ?? 0) {
            medals.append(.init(kind: .bestOfMonth, tier: .silver, subject: "", value: session.volume))
        }

        // Más relevantes primero (oro → plata → bronce).
        return medals.sorted { $0.rank > $1.rank }
    }
}
