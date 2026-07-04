import Foundation
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
    static func context(from store: AppStore) -> String {
        var out: [String] = []
        let score = store.gymScore
        out.append("Usuario: \(store.account?.name ?? "atleta"). Racha: \(store.player.streak) días. Gym Score: \(score.total)/100 (fuerza \(score.strength), constancia \(score.consistency), volumen \(score.volume)).")

        // Últimas sesiones (máx 10): fecha, nombre y mejor serie por ejercicio.
        let f = DateFormatter(); f.dateFormat = "d MMM"; f.locale = Locale(identifier: "es_ES")
        let recent = store.sessions.sorted { $0.date > $1.date }.prefix(10)
        if recent.isEmpty {
            out.append("Aún no tiene entrenos guardados.")
        } else {
            out.append("Últimos entrenos:")
            for s in recent {
                let exs = (s.items ?? []).map { it -> String in
                    let sets = it.logs ?? []
                    let best = sets.max { $0.weight * (1 + Double($0.reps) / 30) < $1.weight * (1 + Double($1.reps) / 30) }
                    let w = best?.weight ?? it.weight, r = best?.reps ?? it.reps
                    return "\(it.name) \(w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w))kg×\(r)"
                }.joined(separator: ", ")
                out.append("- \(f.string(from: s.date)) «\(s.name)»: \(exs)")
            }
        }

        // Progresión por ejercicio (primera vs última marca): para "¿dónde progreso menos?".
        var firstBest: [String: Double] = [:], lastBest: [String: Double] = [:], count: [String: Int] = [:]
        for s in store.sessions.sorted(by: { $0.date < $1.date }) {
            for it in (s.items ?? []) {
                let sets = it.logs ?? [SetLog(reps: it.reps, weight: it.weight)]
                guard let e = sets.map({ $0.weight * (1 + Double(min(20, $0.reps)) / 30) }).max(), e > 0 else { continue }
                if firstBest[it.name] == nil { firstBest[it.name] = e }
                lastBest[it.name] = e
                count[it.name, default: 0] += 1
            }
        }
        let prog = firstBest.keys.compactMap { name -> String? in
            guard let a = firstBest[name], let b = lastBest[name], count[name, default: 0] >= 2, a > 0 else { return nil }
            return "\(name): \(Int(((b - a) / a * 100).rounded()))% (\(count[name]!) sesiones)"
        }
        if !prog.isEmpty { out.append("Progresión de 1RM estimado por ejercicio: " + prog.joined(separator: "; ") + ".") }
        return out.joined(separator: "\n")
    }

    // MARK: - Conversación

    /// Pregunta libre a Forgey con el contexto del usuario. Lanza si el modelo no está disponible.
    func ask(_ question: String, store: AppStore) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: """
            Eres Forgey, la mascota y coach de gimnasio de la app Forge Loop. Responde SIEMPRE en español, \
            en 120 palabras o menos, con tono cercano y motivador (puedes usar algún emoji). \
            Escribe en TEXTO PLANO, sin Markdown (nada de asteriscos ni almohadillas); usa guiones para listas. \
            Basa tus respuestas en los datos REALES del usuario que tienes debajo; si no hay datos \
            suficientes, dilo con honestidad y da un consejo general seguro. No inventes marcas ni fechas. \
            No des consejos médicos; ante dolor, recomienda descansar y consultar a un profesional.

            DATOS DEL USUARIO:
            \(ForgeyAI.context(from: store))
            """)
            return try await session.respond(to: question).content
        }
        #endif
        throw NSError(domain: "ForgeyAI", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: ForgeyAI.unavailableReason() ?? "No disponible"])
    }

    // MARK: - Generar un entreno desde una descripción (Plan)

    /// Genera un entreno estructurado a partir de una descripción en lenguaje natural.
    func generateWorkout(from description: String, store: AppStore) async throws -> WorkoutTemplate {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: """
            Eres un entrenador personal. Diseña entrenos de gimnasio sensatos y seguros en español. \
            Usa nombres de ejercicios comunes (Press banca, Sentadilla, Remo con barra, Peso muerto, \
            Press militar, Dominadas, Fondos, Curl de bíceps, Elevaciones laterales, Zancadas, Hip thrust…). \
            Elige pesos iniciales conservadores acordes al nivel del usuario (0 kg si es con el peso corporal).

            NIVEL DEL USUARIO:
            \(ForgeyAI.context(from: store))
            """)
            let res = try await session.respond(
                to: "Crea un entreno a partir de esta descripción: \(description)",
                generating: AIWorkout.self
            ).content
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
