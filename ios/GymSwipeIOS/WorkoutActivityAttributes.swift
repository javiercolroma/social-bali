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
        var bpm: Int?
        var resting: Bool
        var restEndsAt: Date?
    }

    var title: String
}
