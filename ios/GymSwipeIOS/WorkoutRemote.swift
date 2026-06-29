import Foundation
import Combine

/// Acciones que el widget de la pantalla de bloqueo / Isla Dinámica puede mandar
/// a la sesión en marcha. Las ejecuta `TrainView` con su lógica habitual.
enum WorkoutCommand: String {
    case done        // serie hecha → siguiente serie/ejercicio
    case skip        // saltar serie
    case repsUp, repsDown
    case weightUp, weightDown
    case restPlus    // +15s de descanso
    case restSkip    // saltar descanso
}

/// Canal compartido (un solo proceso, el de la app) entre los App Intents del widget
/// y la vista de entreno. El intent (LiveActivityIntent) corre dentro de la app y
/// publica el comando; `TrainView` lo observa y lo aplica.
@MainActor
final class WorkoutRemote: ObservableObject {
    static let shared = WorkoutRemote()

    /// Token que cambia con cada comando para que `onReceive` siempre dispare,
    /// aunque se repita la misma acción (p. ej. pulsar "+" dos veces).
    @Published var pending: (id: Int, command: WorkoutCommand)?
    private var counter = 0

    func send(_ command: WorkoutCommand) {
        counter += 1
        pending = (counter, command)
    }
}
