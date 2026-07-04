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
            let session = LanguageModelSession(instructions: """
            Eres Forgey, la mascota y coach de gimnasio de la app Forge Loop. Responde SIEMPRE en español, \
            con tono cercano y motivador (algún emoji está bien).

            PRECISIÓN (lo más importante): responde EXACTAMENTE a lo que se pregunta, con el dato \
            concreto de los DATOS DEL USUARIO, en 2-4 frases. VE AL GRANO: la PRIMERA frase ya es \
            la respuesta, sin preámbulos ni relleno (nada de «¡Estoy emocionado de decirte…!», \
            «¡Gran pregunta!» ni similares). NO resumas el perfil completo, NO enumeres datos \
            que no se han pedido. Ejemplos: si preguntan «¿en qué ejercicio soy \
            mejor?» responde con TU MEJOR EJERCICIO y su marca; si preguntan «¿dónde progreso \
            menos?» responde con MENOR PROGRESO y su %.

            FORMATO (estricto): máximo 50 palabras. NADA de párrafos largos. Estructura: \
            primera línea = la respuesta con su dato; si hay más datos o consejos, líneas \
            sueltas cortas empezando por «- » (máximo 3). Texto plano, sin Markdown (nada de \
            asteriscos ni almohadillas).

            Si no hay datos suficientes, dilo con honestidad y da un consejo general seguro. No \
            inventes marcas ni fechas. No des consejos médicos; ante dolor, recomienda descansar \
            y consultar a un profesional.

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
    ///
    /// El modelo on-device es PEQUEÑO y a veces mezcla grupos musculares (pedías pierna y
    /// colaba un press). Defensa en 3 capas: (1) catálogo de ejemplos POR GRUPO en las
    /// instrucciones (los modelos pequeños copian los ejemplos que ven: si son de torso,
    /// generan torso); (2) regla crítica explícita; (3) VERIFICACIÓN local de cada ejercicio
    /// contra el grupo pedido + un reintento correctivo, y filtrado final si aún cuela algo.
    func generateWorkout(from description: String, store: AppStore) async throws -> WorkoutTemplate {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: """
            Eres un entrenador personal. Diseña entrenos de gimnasio sensatos y seguros en español.

            REGLA CRÍTICA: TODOS los ejercicios deben trabajar EXACTAMENTE lo que pide la \
            descripción del usuario. Si pide pierna, SOLO ejercicios de pierna (nada de press \
            banca, remo ni curl de bíceps). Si pide pecho, SOLO pecho y tríceps auxiliar si encaja.

            Catálogo por grupo — elige SOLO del grupo que corresponda:
            - Pierna/Glúteo: Sentadilla, Prensa de piernas, Zancadas, Hip thrust, Peso muerto rumano, Extensión de cuádriceps, Curl femoral, Elevación de gemelos, Sentadilla búlgara
            - Pecho: Press banca, Press inclinado con mancuernas, Aperturas, Fondos, Flexiones
            - Espalda: Remo con barra, Dominadas, Jalón al pecho, Remo en polea, Face pull
            - Hombro: Press militar, Elevaciones laterales, Elevaciones frontales, Pájaros
            - Bíceps: Curl con barra, Curl martillo, Curl inclinado
            - Tríceps: Press francés, Extensión de tríceps en polea, Fondos en banco
            - Core: Plancha, Crunch, Giro ruso, Elevación de piernas

            Pesos iniciales conservadores acordes al nivel del usuario (0 kg si es con el peso corporal).

            NIVEL DEL USUARIO:
            \(ForgeyAI.context(from: store))
            """)
            func generate(_ prompt: String) async throws -> AIWorkout {
                try await session.respond(to: prompt, generating: AIWorkout.self).content
            }
            var res = try await generate("Crea un entreno para: \(description). Recuerda: TODOS los ejercicios deben corresponder a esa descripción.")

            // Verificación local contra el grupo muscular pedido + reintento correctivo.
            if let targets = Self.targetGroups(in: description) {
                let bad = res.exercises.filter { Self.clearlyOffTarget($0.name, targets: targets) }
                if !bad.isEmpty {
                    let feedback = "Estos ejercicios NO encajan con «\(description)»: \(bad.map(\.name).joined(separator: ", ")). Genera el entreno COMPLETO de nuevo usando ÚNICAMENTE ejercicios adecuados para: \(description)."
                    if let r2 = try? await generate(feedback) {
                        let bad2 = r2.exercises.filter { Self.clearlyOffTarget($0.name, targets: targets) }
                        if bad2.count < bad.count { res = r2 }
                    }
                    // Última red: descarta lo claramente fuera de grupo si quedan ≥3 ejercicios.
                    let cleaned = res.exercises.filter { !Self.clearlyOffTarget($0.name, targets: targets) }
                    if cleaned.count >= 3 { res.exercises = cleaned }
                }
            }

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

    // MARK: - Validación de grupo muscular (local, sin IA)

    private static func norm(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
    private static func has(_ s: String, _ pattern: String) -> Bool {
        s.range(of: pattern, options: .regularExpression) != nil
    }

    /// Grupos musculares que PIDE la descripción del usuario. nil = no restringe (full body
    /// o no se menciona ningún grupo) → no validamos.
    static func targetGroups(in description: String) -> Set<String>? {
        let d = norm(description)
        if has(d, "full ?body|cuerpo completo|todo el cuerpo|general") { return nil }
        var t = Set<String>()
        if has(d, "pierna|cuadricep|femoral|gluteo|gemelo|tren inferior") { t.insert("pierna") }
        if has(d, "pecho|pectoral") { t.insert("pecho") }
        if has(d, "espalda|dorsal") { t.insert("espalda") }
        if has(d, "hombro|deltoide") { t.insert("hombro") }
        if has(d, "bicep") { t.insert("biceps") }
        if has(d, "tricep") { t.insert("triceps") }
        if has(d, "brazo") { t.formUnion(["biceps", "triceps"]) }
        if has(d, "core|abdominal|abdomen") { t.insert("core") }
        if has(d, "empuje|push") { t.formUnion(["pecho", "hombro", "triceps"]) }
        if has(d, "tiron|pull|jalon") { t.formUnion(["espalda", "biceps"]) }
        return t.isEmpty ? nil : t
    }

    /// Grupo(s) de un ejercicio por su nombre. nil = desconocido (no podemos afirmar que esté mal).
    static func exerciseGroups(_ name: String) -> Set<String>? {
        let n = norm(name)
        // El orden importa: "curl femoral" es pierna (no bíceps); "elevación de piernas" es core.
        if has(n, "elevacion(es)? de pierna") { return ["core"] }
        if has(n, "sentadilla|prensa|zancada|gemelo|cuadricep|femoral|gluteo|hip ?thrust|peso muerto|rumano|bulgara|abductor|aductor|step ?up") { return ["pierna"] }
        if has(n, "plancha|crunch|abdominal|ruso|core|rueda") { return ["core"] }
        if has(n, "press (de )?banca|press inclinado|press declinado|apertura|pec ?deck|flexion|pullover") { return ["pecho"] }
        if has(n, "fondos") { return ["pecho", "triceps"] }
        if has(n, "remo|dominada|jalon|pull|hiperextension|buenos dias") { return ["espalda"] }
        if has(n, "press militar|press de hombro|elevacion(es)? lateral|elevacion(es)? frontal|pajaro|arnold|deltoide") { return ["hombro"] }
        if has(n, "tricep|frances|patada|press cerrado") { return ["triceps"] }
        if has(n, "curl|martillo|bicep") { return ["biceps"] }
        return nil
    }

    /// ¿El ejercicio está CLARAMENTE fuera de los grupos pedidos?
    static func clearlyOffTarget(_ name: String, targets: Set<String>) -> Bool {
        guard let g = exerciseGroups(name) else { return false }
        return g.isDisjoint(with: targets)
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
