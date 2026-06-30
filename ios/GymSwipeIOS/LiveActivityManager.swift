import Foundation
import ActivityKit

/// Gestiona la Live Activity de la pantalla de bloqueo / Isla Dinámica para la sesión en marcha.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    // Se guardan como Any para no exponer tipos limitados a iOS 16.x en una clase del target iOS 16.0.
    private var current: Any?        // Activity<WorkoutActivityAttributes>
    private var currentState: Any?   // ContentState — fuente de verdad de lo que muestra el widget

    func start(name: String, startedAt: Date, closedSets: Int, totalSets: Int,
               currentExercise: String, reps: Int, weight: Double, setIndex: Int, exerciseSets: Int) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled, current == nil else { return }
        let attrs = WorkoutActivityAttributes(title: "Forge Loop")
        let state = WorkoutActivityAttributes.ContentState(
            workoutName: name, startedAt: startedAt, closedSets: closedSets, totalSets: totalSets,
            currentExercise: currentExercise, reps: reps, weight: weight, setIndex: setIndex,
            exerciseSets: exerciseSets, bpm: nil, resting: false, restStartedAt: nil, restEndsAt: nil)
        currentState = state
        do {
            current = try Activity.request(attributes: attrs,
                                           content: ActivityContent(state: state, staleDate: nil),
                                           pushType: nil)
        } catch {
            current = nil; currentState = nil
        }
    }

    func update(name: String, startedAt: Date, closedSets: Int, totalSets: Int,
                currentExercise: String, reps: Int, weight: Double, setIndex: Int, exerciseSets: Int,
                bpm: Int?, resting: Bool, restStartedAt: Date?, restEndsAt: Date?) {
        guard #available(iOS 16.2, *) else { return }
        currentState = WorkoutActivityAttributes.ContentState(
            workoutName: name, startedAt: startedAt, closedSets: closedSets, totalSets: totalSets,
            currentExercise: currentExercise, reps: reps, weight: weight, setIndex: setIndex,
            exerciseSets: exerciseSets, bpm: bpm, resting: resting, restStartedAt: restStartedAt, restEndsAt: restEndsAt)
        push()
    }

    /// Cambios DIRECTOS desde el App Intent del widget. Actualizan la Live Activity al instante,
    /// sin pasar por la vista ni el store, que es lo que daba la sensación de lentitud.
    /// Re-adquiere la actividad y su estado por si iOS relanzó la app para ejecutar el intent
    /// (en ese caso `currentState` estaría vacío y el cambio se perdía).
    func bumpReps(_ delta: Int) {
        guard #available(iOS 16.2, *), let act = liveActivity() else { return }
        var s = liveState(act)
        s.reps = max(1, s.reps + delta)
        currentState = s
        Task { await act.update(ActivityContent(state: s, staleDate: nil)) }
    }
    func bumpWeight(_ delta: Double) {
        guard #available(iOS 16.2, *), let act = liveActivity() else { return }
        var s = liveState(act)
        let next = max(0, s.weight + delta)
        s.weight = (next * 2).rounded() / 2
        currentState = s
        Task { await act.update(ActivityContent(state: s, staleDate: nil)) }
    }

    @available(iOS 16.2, *)
    private func liveActivity() -> Activity<WorkoutActivityAttributes>? {
        if let a = current as? Activity<WorkoutActivityAttributes> { return a }
        let a = Activity<WorkoutActivityAttributes>.activities.first
        current = a
        return a
    }
    @available(iOS 16.2, *)
    private func liveState(_ act: Activity<WorkoutActivityAttributes>) -> WorkoutActivityAttributes.ContentState {
        (currentState as? WorkoutActivityAttributes.ContentState) ?? act.content.state
    }

    private func push() {
        guard #available(iOS 16.2, *), let act = current as? Activity<WorkoutActivityAttributes>,
              let s = currentState as? WorkoutActivityAttributes.ContentState else { return }
        Task { await act.update(ActivityContent(state: s, staleDate: nil)) }
    }

    func end() {
        currentState = nil
        guard #available(iOS 16.2, *), let act = current as? Activity<WorkoutActivityAttributes> else { current = nil; return }
        current = nil
        Task { await act.end(nil, dismissalPolicy: .immediate) }
    }
}
