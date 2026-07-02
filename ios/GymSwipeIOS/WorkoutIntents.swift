import AppIntents

/// Botón del widget de entreno. Al ser `LiveActivityIntent`, el sistema ejecuta
/// `perform()` DENTRO del proceso de la app (no en la extensión), así que puede
/// comunicarse con la sesión en marcha vía `WorkoutRemote.shared`.
@available(iOS 17.0, *)
struct WorkoutControlIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Controlar entreno"
    static var isDiscoverable = false

    @Parameter(title: "Acción")
    var action: String

    init() {}
    init(_ command: WorkoutCommand) { self.action = command.rawValue }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let command = WorkoutCommand(rawValue: action) {
            // Reps/peso: actualiza la Live Activity aquí mismo y ESPERA a que se aplique.
            // El sistema recarga la UI del widget al terminar perform(): si la actualización
            // ya está confirmada, el valor nuevo aparece al instante (antes se disparaba en un
            // Task sin esperar y la recarga llegaba ANTES que el cambio → sensación de lentitud).
            switch command {
            case .repsUp:     await LiveActivityManager.shared.bumpReps(1)
            case .repsDown:   await LiveActivityManager.shared.bumpReps(-1)
            case .weightUp:   await LiveActivityManager.shared.bumpWeight(2.5)
            case .weightDown: await LiveActivityManager.shared.bumpWeight(-2.5)
            default: break
            }
            WorkoutRemote.shared.send(command)
        }
        return .result()
    }
}
