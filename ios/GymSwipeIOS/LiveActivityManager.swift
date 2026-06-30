import Foundation
import ActivityKit

/// Gestiona la Live Activity de la pantalla de bloqueo / Isla Dinámica para la sesión en marcha.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    // Se guarda como Any para no exponer un tipo limitado a iOS 16.x en una clase del target iOS 16.0.
    private var current: Any?

    // Coalescencia de updates: ActivityKit limita la frecuencia, así que ráfagas de toques
    // (reps/peso) se agrupan — se aplica el primero al instante y el último tras una ventana corta.
    private var pendingState: Any?
    private var lastFlush = Date.distantPast
    private var flushScheduled = false
    private let minInterval: TimeInterval = 0.16

    func start(name: String, startedAt: Date, closedSets: Int, totalSets: Int,
               currentExercise: String, reps: Int, weight: Double, setIndex: Int, exerciseSets: Int) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled, current == nil else { return }
        let attrs = WorkoutActivityAttributes(title: "Forge Loop")
        let state = WorkoutActivityAttributes.ContentState(
            workoutName: name, startedAt: startedAt, closedSets: closedSets, totalSets: totalSets,
            currentExercise: currentExercise, reps: reps, weight: weight, setIndex: setIndex,
            exerciseSets: exerciseSets, bpm: nil, resting: false, restStartedAt: nil, restEndsAt: nil)
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
                bpm: Int?, resting: Bool, restStartedAt: Date?, restEndsAt: Date?) {
        guard #available(iOS 16.2, *), current is Activity<WorkoutActivityAttributes> else { return }
        pendingState = WorkoutActivityAttributes.ContentState(
            workoutName: name, startedAt: startedAt, closedSets: closedSets, totalSets: totalSets,
            currentExercise: currentExercise, reps: reps, weight: weight, setIndex: setIndex,
            exerciseSets: exerciseSets, bpm: bpm, resting: resting, restStartedAt: restStartedAt, restEndsAt: restEndsAt)
        scheduleFlush()
    }

    /// Aplica el primer cambio al instante; los siguientes en una ráfaga se agrupan
    /// y se manda solo el último tras `minInterval` (evita la cola/lag de ActivityKit).
    private func scheduleFlush() {
        let since = Date().timeIntervalSince(lastFlush)
        if since >= minInterval {
            flushNow()
        } else if !flushScheduled {
            flushScheduled = true
            let delay = minInterval - since
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                self.flushScheduled = false
                self.flushNow()
            }
        }
    }

    private func flushNow() {
        guard #available(iOS 16.2, *), let act = current as? Activity<WorkoutActivityAttributes>,
              let state = pendingState as? WorkoutActivityAttributes.ContentState else { return }
        pendingState = nil
        lastFlush = Date()
        Task { await act.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end() {
        pendingState = nil
        guard #available(iOS 16.2, *), let act = current as? Activity<WorkoutActivityAttributes> else { current = nil; return }
        current = nil
        Task { await act.end(nil, dismissalPolicy: .immediate) }
    }
}
