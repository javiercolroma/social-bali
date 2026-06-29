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
            WorkoutRemote.shared.send(command)
        }
        return .result()
    }
}
