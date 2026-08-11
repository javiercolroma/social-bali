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

    /// ¿Se enseñan los accesos de IA de CHAT/GENERACIÓN (peek, botón del Plan)? Estos
    /// funcionan on-device o en la nube.
    static var isAvailable: Bool { mode != .none }

    /// ¿Está disponible el ANÁLISIS DEL FÍSICO por foto? Es SOLO-nube (el modelo de Apple no
    /// ve imágenes): requiere la visión-nube activa y backend configurado. Gobierna la cámara
    /// del chat, aparte de `isAvailable`. Apagado hasta poner la ANTHROPIC_API_KEY.
    static var cloudVisionAvailable: Bool { FeatureFlags.cloudVisionEnabled && BackendConfig.isConfigured }

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
        // Si el modelo se saltó el marcador pero la pregunta pedía ejercicios de un grupo,
        // lo ponemos nosotros: el botón de crear entreno debe salir igual.
        return Reply(text: text, suggestion: suggestion ?? ForgeyPrompts.fallbackSuggestion(for: question))
    }

    // MARK: - Análisis del físico por foto (SOLO-nube: Claude ve la imagen)

    static func analyzeBody(photo: Data, store: AppStore) async throws -> Reply {
        // Seguridad de adjuntos: solo imágenes de verdad (los pickers ya filtran, esto
        // es el cinturón: un archivo no-imagen no pasa de aquí).
        guard UIImage(data: photo) != nil else {
            return Reply(text: "Solo puedo analizar imágenes 📷. Prueba con una foto de cuerpo entero.", suggestion: nil)
        }
        guard cloudVisionAvailable else {
            throw err("El análisis del físico con IA no está disponible todavía.")
        }
        let raw = try await CloudAI.analyzeBody(photo: photo, store: store)
        let (text, suggestion) = ForgeyPrompts.extractSuggestion(raw)
        return Reply(text: text, suggestion: suggestion)
    }

    // MARK: - Generador de entrenos

    static func generateWorkout(from description: String, store: AppStore) async throws -> WorkoutTemplate {
        switch mode {
        case .onDevice:
            let template = try await ForgeyAI.shared.generateWorkout(from: description, store: store)
            bumpDeviceUsage()
            return template
        case .cloud:
            return try await CloudAI.generateWorkout(from: description, store: store)
        case .none:
            throw err(ForgeyAI.unavailableReason() ?? "IA no disponible")
        }
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
