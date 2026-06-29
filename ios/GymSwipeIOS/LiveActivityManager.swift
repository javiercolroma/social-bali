import Foundation
import ActivityKit

/// Gestiona la Live Activity de la pantalla de bloqueo / Isla Dinámica para la sesión en marcha.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    // Se guarda como Any para no exponer un tipo limitado a iOS 16.x en una clase del target iOS 16.0.
    private var current: Any?

    func start(name: String, startedAt: Date, closedSets: Int, totalSets: Int,
               currentExercise: String, reps: Int, weight: Double, setIndex: Int, exerciseSets: Int) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled, current == nil else { return }
        let attrs = WorkoutActivityAttributes(title: "Forge Loop")
        let state = WorkoutActivityAttributes.ContentState(
            workoutName: name, startedAt: startedAt, closedSets: closedSets, totalSets: totalSets,
            currentExercise: currentExercise, reps: reps, weight: weight, setIndex: setIndex,
            exerciseSets: exerciseSets, bpm: nil, resting: false, restEndsAt: nil)
        do {
            current = try Activity.request(attributes: attrs,
                                           content: ActivityContent(state: state, staleDate: nil),
                                           pushType: nil)
        } catch {
            current = nil
        }
    }

    func update(name: String, startedAt: Date, closedSets: Int, totalSets: Int,
                currentExercise: String, reps: Int, weight: Double, setIndex: Int, exerciseSets: Int,
                bpm: Int?, resting: Bool, restEndsAt: Date?) {
        guard #available(iOS 16.2, *), let act = current as? Activity<WorkoutActivityAttributes> else { return }
        let state = WorkoutActivityAttributes.ContentState(
            workoutName: name, startedAt: startedAt, closedSets: closedSets, totalSets: totalSets,
            currentExercise: currentExercise, reps: reps, weight: weight, setIndex: setIndex,
            exerciseSets: exerciseSets, bpm: bpm, resting: resting, restEndsAt: restEndsAt)
        Task { await act.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end() {
        guard #available(iOS 16.2, *), let act = current as? Activity<WorkoutActivityAttributes> else { current = nil; return }
        current = nil
        Task { await act.end(nil, dismissalPolicy: .immediate) }
    }
}
