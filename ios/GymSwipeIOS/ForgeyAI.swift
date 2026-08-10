import Foundation
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Forgey IA: coach conversacional 100 % EN EL DISPOSITIVO (Apple Foundation Models,
/// iOS 26+ con Apple Intelligence). Sin peticiones a servidores externos: los datos de
/// tus entrenos no salen del iPhone. Un único servicio central al que se pregunta desde
/// cualquier pantalla a través de la mascota (no funciones fragmentadas por pantalla).
@MainActor
final class ForgeyAI: ObservableObject {
    static let shared = ForgeyAI()

    /// ¿Este dispositivo PODRÁ usar la IA alguna vez? false = ocultar los accesos por
    /// completo (iOS < 26 o hardware sin Apple Intelligence: no tiene sentido enseñarlos).
    /// Estados transitorios (IA desactivada, modelo descargándose) SÍ cuentan como soportado.
    static var isSupported: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .unavailable(.deviceNotEligible) = SystemLanguageModel.default.availability { return false }
            return true
        }
        #endif
        return false
    }

    /// ¿Este dispositivo puede usar la IA? (nil = sí; si no, el motivo en humano)
    static func unavailableReason() -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.deviceNotEligible):
                return "Este dispositivo no soporta Apple Intelligence (hace falta un iPhone 15 Pro o posterior)."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Activa Apple Intelligence en Ajustes → Apple Intelligence y Siri para hablar con Forgey."
            case .unavailable(.modelNotReady):
                return "El modelo de Apple Intelligence se está descargando. Inténtalo en unos minutos."
            case .unavailable:
                return "Apple Intelligence no está disponible ahora mismo en este dispositivo."
            }
        }
        #endif
        return "Forgey IA necesita iOS 26 o posterior con Apple Intelligence."
    }

    // MARK: - Contexto: resumen COMPACTO de tus entrenos (el modelo on-device tiene contexto corto)

    /// Resumen del historial del usuario para que Forgey responda con TUS datos.
    /// ESTRUCTURADO y con los datos clave PRE-CALCULADOS (mejor ejercicio, progresión
    /// mejor/peor…): el modelo on-device es pequeño y responde bien cuando el dato exacto
    /// ya está servido; con prosa larga tiende a "resumir el perfil" en vez de contestar.
    static func context(from store: AppStore) -> String {
        let score = store.gymScore
        // SOLO entrenos fiables: los implausibles no alimentan a la IA ni a las estadísticas.
        let reliable = store.sessions.filter { $0.verified }
        var out: [String] = []
        out.append("PERFIL: \(store.account?.name ?? "atleta") · racha \(store.player.streak) días · Gym Score \(score.total)/100 (fuerza \(score.strength), constancia \(score.consistency), volumen \(score.volume)).")

        // Por ejercicio: mejor 1RM estimado, nº de sesiones y progresión primera→última.
        struct Stat { var bestE: Double = 0; var bestW: Double = 0; var bestR: Int = 0; var first: Double = 0; var last: Double = 0; var n = 0 }
        var stats: [String: Stat] = [:]
        for s in reliable.sorted(by: { $0.date < $1.date }) {
            for it in (s.items ?? []) {
                let sets = it.logs ?? [SetLog(reps: it.reps, weight: it.weight)]
                guard let best = sets.max(by: { e1($0) < e1($1) }), e1(best) > 0 else { continue }
                var st = stats[it.name] ?? Stat()
                if e1(best) > st.bestE { st.bestE = e1(best); st.bestW = best.weight; st.bestR = best.reps }
                if st.n == 0 { st.first = e1(best) }
                st.last = e1(best); st.n += 1
                stats[it.name] = st
            }
        }

        if stats.isEmpty {
            out.append("SIN ENTRENOS GUARDADOS todavía.")
        } else {
            // Mejores marcas, de mayor a menor → responde directo a "¿en qué soy mejor?".
            let ranked = stats.sorted { $0.value.bestE > $1.value.bestE }
            out.append("MEJORES MARCAS (1RM estimado, de mejor a peor): " + ranked.prefix(8).map {
                "\($0.key) \(Int($0.value.bestE.rounded())) kg (mejor serie \(fmtW($0.value.bestW))×\($0.value.bestR), \($0.value.n) sesiones)"
            }.joined(separator: "; ") + ".")
            out.append("TU MEJOR EJERCICIO (marca más alta): \(ranked.first!.key).")
            out.append("EL QUE MÁS ENTRENAS: \(stats.max { $0.value.n < $1.value.n }!.key).")

            let withTrend = stats.filter { $0.value.n >= 2 && $0.value.first > 0 }
            if !withTrend.isEmpty {
                let pct: (Stat) -> Int = { Int((($0.last - $0.first) / $0.first * 100).rounded()) }
                let sortedTrend = withTrend.sorted { pct($0.value) > pct($1.value) }
                out.append("PROGRESIÓN desde el primer registro: " + sortedTrend.map { "\($0.key) \(pct($0.value) >= 0 ? "+" : "")\(pct($0.value))%" }.joined(separator: "; ") + ".")
                out.append("MAYOR PROGRESO: \(sortedTrend.first!.key). MENOR PROGRESO: \(sortedTrend.last!.key).")
            }

            let f = DateFormatter(); f.dateFormat = "d MMM"; f.locale = Locale(identifier: "es_ES")
            let recent = reliable.sorted { $0.date > $1.date }.prefix(6)
            out.append("ÚLTIMOS ENTRENOS: " + recent.map { s in
                "\(f.string(from: s.date)) «\(s.name)» (\(s.sets) series)"
            }.joined(separator: "; ") + ".")
        }
        return out.joined(separator: "\n")
    }

    private static func e1(_ s: SetLog) -> Double { s.weight * (1 + Double(min(20, s.reps)) / 30) }
    private static func fmtW(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }

    // MARK: - Conversación

    /// Pregunta libre a Forgey con el contexto del usuario. Lanza si el modelo no está disponible.
    func ask(_ question: String, store: AppStore) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: ForgeyPrompts.chatInstructions(context: ForgeyAI.context(from: store)))
            return try await session.respond(to: question).content
        }
        #endif
        throw NSError(domain: "ForgeyAI", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: ForgeyAI.unavailableReason() ?? "No disponible"])
    }

    // MARK: - Reparto de entreno (contexto para el análisis del físico por foto)

    /// Reparto REAL del volumen de entreno por patrón (solo sesiones fiables): la señal más
    /// honesta de qué zonas están descuidadas. Acompaña a la foto en el análisis del físico
    /// (que es SOLO-nube: Claude ve la imagen; esto le dice además qué grupos entrenas poco).
    static func trainingSplit(from store: AppStore) -> String {
        var vol: [String: Double] = [:]
        for s in store.sessions where s.verified {
            for it in (s.items ?? []) {
                let sets = it.logs ?? [SetLog(reps: it.reps, weight: it.weight)]
                let v = sets.reduce(0.0) { $0 + Double($1.reps) * max(1, $1.weight) }
                vol[GymScoreEngine.pattern(for: it.name).group, default: 0] += v
            }
        }
        let total = vol.values.reduce(0, +)
        guard total > 0 else { return "Aún no hay entrenos fiables registrados." }
        let names = ["empuje": "empuje (pecho/hombro/tríceps)", "tiron": "tirón (espalda/bíceps)",
                     "pierna": "pierna", "bisagra": "cadena posterior (femoral/glúteo)",
                     "condicion": "core/condición", "accesorio": "accesorios"]
        let parts = vol.sorted { $0.value > $1.value }.map { "\(names[$0.key] ?? $0.key) \(Int(($0.value / total * 100).rounded()))%" }
        return "Reparto de su volumen de entreno: " + parts.joined(separator: ", ") + "."
    }

    // MARK: - Generar un entreno desde una descripción (Plan)

    /// Genera un entreno estructurado a partir de una descripción en lenguaje natural.
    /// Confiamos en el prompt (catálogo por grupo + regla crítica en `generateInstructions`)
    /// y en la salida estructurada `@Generable`, sin post-validación de grupos musculares.
    func generateWorkout(from description: String, store: AppStore) async throws -> WorkoutTemplate {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: ForgeyPrompts.generateInstructions(
                context: ForgeyAI.context(from: store),
                referenceLoads: ForgeyPrompts.referenceLoads(from: store),
                catalog: ForgeyPrompts.catalog(for: description)))
            let res = try await session.respond(
                to: "Crea un entreno para: \(description). Recuerda: TODOS los ejercicios deben corresponder a esa descripción.",
                generating: AIWorkout.self).content

            let exercises = res.exercises.map {
                AppStore.makeExercise(res.name, $0.name, min(6, max(1, $0.sets)), min(30, max(1, $0.reps)),
                                      min(300, max(0, $0.weightKg)))
            }
            return WorkoutTemplate(id: "ai-\(Int(Date().timeIntervalSince1970))", name: res.name,
                                   description: AppStore.summary(of: exercises),
                                   block: res.block.isEmpty ? "Otros" : res.block, exercises: exercises)
        }
        #endif
        throw NSError(domain: "ForgeyAI", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: ForgeyAI.unavailableReason() ?? "No disponible"])
    }
}

#if canImport(FoundationModels)
/// Salida ESTRUCTURADA del generador de entrenos (guided generation: el modelo
/// rellena este esquema, sin parseos frágiles de texto).
@available(iOS 26.0, *)
@Generable
struct AIWorkout {
    @Guide(description: "Nombre corto y motivador del entreno, en español")
    var name: String
    @Guide(description: "Grupo principal: Pecho, Espalda, Pierna, Hombro, Brazo, Empuje, Pull, Full body…")
    var block: String
    @Guide(description: "Entre 3 y 8 ejercicios")
    var exercises: [AIExercise]
}

@available(iOS 26.0, *)
@Generable
struct AIExercise {
    @Guide(description: "Nombre del ejercicio en español")
    var name: String
    @Guide(description: "Número de series, de 2 a 5")
    var sets: Int
    @Guide(description: "Repeticiones por serie, de 5 a 20")
    var reps: Int
    @Guide(description: "Peso inicial en kg (0 si es con peso corporal)")
    var weightKg: Double
}
#endif
