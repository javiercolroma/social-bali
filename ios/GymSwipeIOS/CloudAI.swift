import Foundation

/// Motor de IA en la NUBE: llama a la Edge Function `forgey-ai` de Supabase, que hace de
/// proxy seguro a la API de Claude (modelo económico). La clave de Anthropic vive SOLO en
/// los secretos del servidor; el cliente se autentica con su sesión de Supabase (JWT).
/// El servidor además capa longitudes, aplica el tope diario y registra el uso (ai_usage).
@MainActor
enum CloudAI {

    enum CloudError: LocalizedError {
        case notConfigured, dailyLimit, noSession, server(String)
        var errorDescription: String? {
            switch self {
            case .notConfigured: return "La IA en la nube aún no está activada. ¡Muy pronto!"
            case .dailyLimit: return "Has llegado al límite diario de IA. Vuelve mañana 💪"
            case .noSession: return "Inicia sesión para hablar con Forgey."
            case .server(let m): return "Forgey no responde ahora mismo (\(m)). Inténtalo de nuevo."
            }
        }
    }

    /// Petición básica: instrucciones (system) + mensaje del usuario → texto.
    static func complete(system: String, prompt: String, maxTokens: Int = 600) async throws -> String {
        guard let client = Backend.shared.client else { throw CloudError.notConfigured }
        guard let token = try? await client.auth.session.accessToken else { throw CloudError.noSession }

        var req = URLRequest(url: URL(string: "\(BackendConfig.supabaseURL)/functions/v1/forgey-ai")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 45
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(BackendConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // El cliente también capa (el server re-capa): nada de Quijotes hacia la nube.
        let body: [String: Any] = ["system": String(system.prefix(8000)),
                                   "prompt": String(prompt.prefix(1200)),
                                   "maxTokens": maxTokens]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200:
            struct R: Decodable { let text: String }
            return try JSONDecoder().decode(R.self, from: data).text
        case 401: throw CloudError.noSession
        case 429: throw CloudError.dailyLimit
        case 503: throw CloudError.notConfigured
        default: throw CloudError.server("código \(status)")
        }
    }

    // MARK: - Generador de entrenos (JSON estricto + misma validación local que on-device)

    private struct CloudWorkout: Decodable {
        let name: String
        let block: String
        let exercises: [CloudExercise]
    }
    private struct CloudExercise: Decodable {
        let name: String
        let sets: Int
        let reps: Int
        let weightKg: Double
    }

    static func generateWorkout(from description: String, store: AppStore) async throws -> WorkoutTemplate {
        let system = ForgeyPrompts.generateInstructions(
            context: ForgeyAI.context(from: store),
            referenceLoads: ForgeyPrompts.referenceLoads(from: store))
            + "\n\nSALIDA (estricto): SOLO un objeto JSON válido, sin markdown ni texto extra: "
            + #"{"name":"…","block":"…","exercises":[{"name":"…","sets":4,"reps":10,"weightKg":40}]}"#
            + " Entre 3 y 8 ejercicios."

        func request(_ prompt: String) async throws -> CloudWorkout {
            let raw = try await complete(system: system, prompt: prompt, maxTokens: 800)
            return try parse(raw)
        }

        var res = try await request("Crea un entreno para: \(description). Recuerda: TODOS los ejercicios deben corresponder a esa descripción.")

        // Misma defensa que on-device: validación de grupo + un reintento correctivo.
        if let targets = ForgeyAI.targetGroups(in: description) {
            let bad = res.exercises.filter { ForgeyAI.clearlyOffTarget($0.name, targets: targets) }
            if !bad.isEmpty {
                if let r2 = try? await request("Estos ejercicios NO encajan con «\(description)»: \(bad.map(\.name).joined(separator: ", ")). Genera el entreno COMPLETO de nuevo usando ÚNICAMENTE ejercicios adecuados para: \(description)."),
                   r2.exercises.filter({ ForgeyAI.clearlyOffTarget($0.name, targets: targets) }).count < bad.count {
                    res = r2
                }
                let cleaned = res.exercises.filter { !ForgeyAI.clearlyOffTarget($0.name, targets: targets) }
                if cleaned.count >= 3 { res = CloudWorkout(name: res.name, block: res.block, exercises: cleaned) }
            }
        }

        let exercises = res.exercises.map {
            AppStore.makeExercise(res.name, $0.name, min(6, max(1, $0.sets)), min(30, max(1, $0.reps)),
                                  min(300, max(0, $0.weightKg)))
        }
        guard !exercises.isEmpty else { throw CloudError.server("entreno vacío") }
        return WorkoutTemplate(id: "ai-\(Int(Date().timeIntervalSince1970))", name: res.name,
                               description: AppStore.summary(of: exercises),
                               block: res.block.isEmpty ? "Otros" : res.block, exercises: exercises)
    }

    /// El modelo a veces envuelve el JSON en ```json …``` o añade una frase: lo extraemos.
    private static func parse(_ raw: String) throws -> CloudWorkout {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let a = t.firstIndex(of: "{"), let b = t.lastIndex(of: "}") { t = String(t[a...b]) }
        guard let d = t.data(using: .utf8) else { throw CloudError.server("respuesta ilegible") }
        return try JSONDecoder().decode(CloudWorkout.self, from: d)
    }
}
