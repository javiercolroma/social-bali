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
            // Reps/peso: actualiza la Live Activity AL INSTANTE aquí mismo (sin esperar a la
            // vista ni al store) — es lo que se sentía lento. El store se sincroniza aparte.
            switch command {
            case .repsUp:     LiveActivityManager.shared.bumpReps(1)
            case .repsDown:   LiveActivityManager.shared.bumpReps(-1)
            case .weightUp:   LiveActivityManager.shared.bumpWeight(2.5)
            case .weightDown: LiveActivityManager.shared.bumpWeight(-2.5)
            default: break
            }
            WorkoutRemote.shared.send(command)
        }
        return .result()
    }
}
