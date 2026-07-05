import Foundation
import UIKit

/// Selector de motor de Forgey: IA on-device (Apple) si el dispositivo puede; si no,
/// la nube (Claude vía Edge Function `forgey-ai`, gateada por `FeatureFlags.cloudAIEnabled`
/// y por la clave ANTHROPIC_API_KEY en los secretos de Supabase). La lógica de prompts es
/// COMPARTIDA (ForgeyPrompts); aquí solo se decide quién ejecuta y se registra el uso.
@MainActor
enum ForgeyEngine {

    enum Mode { case onDevice, cloud, none }

    static var mode: Mode {
        if ForgeyAI.isSupported { return .onDevice }
        if FeatureFlags.cloudAIEnabled && BackendConfig.isConfigured { return .cloud }
        return .none
    }

    /// ¿Se enseñan los accesos de IA (peek, botón del Plan, cámara del chat)?
    static var isAvailable: Bool { mode != .none }

    /// nil = listo para hablar. Con nube activa nunca hay estados transitorios locales.
    static func unavailableReason() -> String? {
        switch mode {
        case .onDevice, .none: return ForgeyAI.unavailableReason()
        case .cloud: return nil
        }
    }

    struct Reply {
        let text: String
        /// Descripción de entreno YA escrita por el modelo (protocolo ENTRENO_SUGERIDO).
        /// nil = la respuesta no justifica ofrecer la creación de un entreno.
        let suggestion: String?
    }

    // MARK: - Chat

    static func ask(_ question: String, store: AppStore) async throws -> Reply {
        let raw: String
        switch mode {
        case .onDevice:
            raw = try await ForgeyAI.shared.ask(question, store: store)
            bumpDeviceUsage()
        case .cloud:
            raw = try await CloudAI.complete(
                system: ForgeyPrompts.chatInstructions(context: ForgeyAI.context(from: store)),
                prompt: question)
        case .none:
            throw err(ForgeyAI.unavailableReason() ?? "IA no disponible")
        }
        let (text, suggestion) = ForgeyPrompts.extractSuggestion(raw)
        return Reply(text: text, suggestion: suggestion)
    }

    // MARK: - Análisis del físico (la foto NUNCA sale del dispositivo: Vision es local
    // en ambos modos; a la nube solo viajan las MEDICIONES en texto)

    static func analyzeBody(photo: Data, store: AppStore) async throws -> Reply {
        // Seguridad de adjuntos: solo imágenes de verdad (los pickers ya filtran, esto
        // es el cinturón: un archivo no-imagen no pasa de aquí).
        guard UIImage(data: photo) != nil else {
            return Reply(text: "Solo puedo analizar imágenes 📷. Prueba con una foto de cuerpo entero.", suggestion: nil)
        }
        let metrics: String
        switch ForgeyAI.detectBody(from: photo) {
        case .noPerson:
            return Reply(text: "No consigo ver un cuerpo completo en la foto 📷. Prueba con una foto de cuerpo entero, de frente y con buena luz. ¿La intentamos de nuevo?", suggestion: nil)
        case .unavailable:
            metrics = "No disponibles en este dispositivo (analiza solo con el reparto de entreno; dilo en una frase)."
        case .metrics(let m):
            metrics = m
        }
        let raw: String
        switch mode {
        case .onDevice:
            raw = try await ForgeyAI.shared.analyzeBody(metrics: metrics, store: store)
            bumpDeviceUsage()
        case .cloud:
            raw = try await CloudAI.complete(
                system: ForgeyPrompts.analyzeInstructions(metrics: metrics, split: ForgeyAI.trainingSplit(from: store)),
                prompt: "¿Qué partes debería mejorar?")
        case .none:
            throw err(ForgeyAI.unavailableReason() ?? "IA no disponible")
        }
        let (text, suggestion) = ForgeyPrompts.extractSuggestion(raw)
        return Reply(text: text, suggestion: suggestion)
    }

    // MARK: - Generador de entrenos

    static func generateWorkout(from description: String, store: AppStore) async throws -> WorkoutTemplate {
        var template: WorkoutTemplate
        switch mode {
        case .onDevice:
            template = try await ForgeyAI.shared.generateWorkout(from: description, store: store)
            bumpDeviceUsage()
        case .cloud:
            template = try await CloudAI.generateWorkout(from: description, store: store)
        case .none:
            throw err(ForgeyAI.unavailableReason() ?? "IA no disponible")
        }
        // Cinturón final compartido: cargas coherentes con el nivel real del usuario.
        template.exercises = ForgeyPrompts.clampWeights(template.exercises, store: store)
        return template
    }

    // MARK: - Registro de uso (persistente, por usuario y día; base del futuro plan de pago)

    private static func bumpDeviceUsage() {
        guard BackendConfig.isConfigured else { return }
        Task { await Backend.shared.bumpAIUsage(kind: "device") }
    }

    private static func err(_ msg: String) -> NSError {
        NSError(domain: "ForgeyEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
