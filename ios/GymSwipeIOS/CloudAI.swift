import Foundation
import UIKit

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
            case .notConfigured: return "Cloud AI isn't switched on yet. Coming soon!"
            case .dailyLimit: return "You've hit today's AI limit. Come back tomorrow 💪"
            case .noSession: return "Sign in to chat with Forgey."
            case .server(let m): return "Forgey isn't responding right now (\(m)). Please try again."
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
        default: throw CloudError.server("code \(status)")
        }
    }

    // MARK: - Generador de entrenos (JSON estricto)

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
            referenceLoads: ForgeyPrompts.referenceLoads(from: store),
            catalog: ForgeyPrompts.catalog(for: description))
            + "\n\nSALIDA (estricto): SOLO un objeto JSON válido, sin markdown ni texto extra: "
            + #"{"name":"…","block":"…","exercises":[{"name":"…","sets":4,"reps":10,"weightKg":40}]}"#
            + " Entre 3 y 8 ejercicios. \"name\", \"block\" y los nombres de ejercicio, en inglés (English)."

        func request(_ prompt: String) async throws -> CloudWorkout {
            let raw = try await complete(system: system, prompt: prompt, maxTokens: 800)
            return try parse(raw)
        }

        let res = try await request("Crea un entreno para: \(description). Recuerda: TODOS los ejercicios deben corresponder a esa descripción.")

        let exercises = res.exercises.map {
            AppStore.makeExercise(res.name, catalogName(forDisplay: $0.name), min(6, max(1, $0.sets)), min(30, max(1, $0.reps)),
                                  min(300, max(0, $0.weightKg)))
        }
        guard !exercises.isEmpty else { throw CloudError.server("empty workout") }
        return WorkoutTemplate(id: "ai-\(Int(Date().timeIntervalSince1970))", name: res.name,
                               description: AppStore.summary(of: exercises),
                               block: res.block.isEmpty ? "Others" : res.block, exercises: exercises)
    }

    /// El modelo a veces envuelve el JSON en ```json …``` o añade una frase: lo extraemos.
    private static func parse(_ raw: String) throws -> CloudWorkout {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let a = t.firstIndex(of: "{"), let b = t.lastIndex(of: "}") { t = String(t[a...b]) }
        guard let d = t.data(using: .utf8) else { throw CloudError.server("unreadable response") }
        return try JSONDecoder().decode(CloudWorkout.self, from: d)
    }

    // MARK: - Análisis del físico por FOTO (Claude ve la imagen)

    /// La foto viaja a la nube (con consentimiento previo). Se redimensiona y comprime ANTES
    /// de salir: nunca se manda en crudo. Devuelve el texto del análisis.
    static func analyzeBody(photo: Data, store: AppStore) async throws -> String {
        guard let client = Backend.shared.client else { throw CloudError.notConfigured }
        guard let token = try? await client.auth.session.accessToken else { throw CloudError.noSession }
        guard let (b64, media) = downscaledJPEGBase64(photo) else { throw CloudError.server("unreadable image") }

        var req = URLRequest(url: URL(string: "\(BackendConfig.supabaseURL)/functions/v1/forgey-ai")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(BackendConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let system = ForgeyPrompts.analyzeInstructions(split: ForgeyAI.trainingSplit(from: store))
        let body: [String: Any] = ["system": String(system.prefix(8000)),
                                   "prompt": "Which areas should I improve? Analyse my physique. Answer in English.",
                                   "maxTokens": 500,
                                   "image": ["media_type": media, "data": b64]]
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
        default: throw CloudError.server("code \(status)")
        }
    }

    /// Redimensiona (borde largo ≤ maxEdge) + comprime a JPEG + base64. Abarata la petición
    /// (~1500 tokens de imagen) y respeta los límites de Anthropic; la original no sale nunca.
    private static func downscaledJPEGBase64(_ data: Data, maxEdge: CGFloat = 1568) -> (String, String)? {
        guard let img = UIImage(data: data) else { return nil }
        let longest = max(img.size.width, img.size.height)
        let scale = longest > maxEdge ? maxEdge / longest : 1
        let target = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            img.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.7) else { return nil }
        return (jpeg.base64EncodedString(), "image/jpeg")
    }
}
