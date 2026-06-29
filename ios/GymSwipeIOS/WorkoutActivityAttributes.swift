import Foundation
import ActivityKit

/// Atributos de la Live Activity del entrenamiento en marcha.
/// Compartido entre la app (que la crea/actualiza) y la extensión de widget (que la dibuja).
@available(iOS 16.1, *)
struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var workoutName: String
        var startedAt: Date
        var closedSets: Int
        var totalSets: Int
        var currentExercise: String
        var reps: Int
        var weight: Double
        var setIndex: Int      // serie actual del ejercicio (1-based)
        var exerciseSets: Int  // nº de series del ejercicio actual
        var bpm: Int?
        var resting: Bool
        var restStartedAt: Date?
        var restEndsAt: Date?
    }

    var title: String
}
