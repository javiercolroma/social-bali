import ActivityKit
import WidgetKit
import SwiftUI

private let lime = Color(red: 0.655, green: 0.949, blue: 0.176)   // ~#a7f22d
private let ink = Color(red: 0.063, green: 0.082, blue: 0.039)    // ~#10150a

@available(iOS 16.2, *)
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(s.workoutName).font(.caption).fontWeight(.heavy).lineLimit(1)
                    } icon: {
                        Image(systemName: "dumbbell.fill").foregroundColor(lime)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(s.startedAt, style: .timer).monospacedDigit().font(.title3.weight(.heavy))
                        .foregroundColor(.white).frame(maxWidth: 70, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(s.resting ? "Descanso" : (s.currentExercise.isEmpty ? "En marcha" : s.currentExercise))
                        .font(.caption2).foregroundColor(.white.opacity(0.7)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 14) {
                        Label("\(s.closedSets)/\(s.totalSets) series", systemImage: "checkmark.circle").foregroundColor(lime)
                        if let bpm = s.bpm { Label("\(bpm) ppm", systemImage: "heart.fill").foregroundColor(.red) }
                        Spacer()
                        if s.resting, let ends = s.restEndsAt {
                            Label { Text(timerInterval: Date()...ends, countsDown: true).monospacedDigit() } icon: { Image(systemName: "timer") }
                                .foregroundColor(.orange)
                        }
                    }.font(.caption.weight(.bold))
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundColor(lime)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer).monospacedDigit().frame(maxWidth: 52).foregroundColor(.white)
            } minimal: {
                Image(systemName: "dumbbell.fill").foregroundColor(lime)
            }
            .keylineTint(lime)
        }
    }
}

@available(iOS 16.2, *)
private struct LockScreenView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill").foregroundColor(lime)
                    Text(state.workoutName).font(.headline).foregroundColor(.white).lineLimit(1)
                }
                if state.resting, let ends = state.restEndsAt {
                    HStack(spacing: 5) {
                        Image(systemName: "timer").font(.caption2)
                        Text("Descanso")
                        Text(timerInterval: Date()...ends, countsDown: true).monospacedDigit()
                    }.font(.subheadline.weight(.semibold)).foregroundColor(.orange)
                } else {
                    Text(state.currentExercise.isEmpty ? "Entreno en marcha" : state.currentExercise)
                        .font(.subheadline).foregroundColor(.white.opacity(0.7)).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(state.startedAt, style: .timer).monospacedDigit()
                    .font(.title2.weight(.heavy)).foregroundColor(.white).frame(maxWidth: 96, alignment: .trailing)
                HStack(spacing: 10) {
                    Label("\(state.closedSets)/\(state.totalSets)", systemImage: "checkmark.circle").foregroundColor(lime)
                    if let bpm = state.bpm { Label("\(bpm)", systemImage: "heart.fill").foregroundColor(.red) }
                }.font(.caption.weight(.bold))
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.black.opacity(0.6))
    }
}
