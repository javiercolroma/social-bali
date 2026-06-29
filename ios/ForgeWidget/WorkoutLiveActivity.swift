import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

private let lime = Color(red: 0.655, green: 0.949, blue: 0.176)   // ~#a7f22d
private let ink = Color(red: 0.063, green: 0.082, blue: 0.039)    // ~#10150a

private func wText(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }

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
                        Text(s.currentExercise.isEmpty ? "En marcha" : s.currentExercise)
                            .font(.caption).fontWeight(.heavy).lineLimit(1)
                    } icon: {
                        Image(systemName: "dumbbell.fill").foregroundColor(lime)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(s.startedAt, style: .timer).monospacedDigit().font(.title3.weight(.heavy))
                        .foregroundColor(.white).frame(maxWidth: 70, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    if s.exerciseSets > 0 && !s.resting {
                        Text("Serie \(s.setIndex)/\(s.exerciseSets)")
                            .font(.caption2).foregroundColor(.white.opacity(0.7)).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ControlsView(state: s).padding(.top, 2)
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
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill").foregroundColor(lime)
                Text(state.currentExercise.isEmpty ? "Entreno en marcha" : state.currentExercise)
                    .font(.headline).foregroundColor(.white).lineLimit(1)
                Spacer()
                Text(state.startedAt, style: .timer).monospacedDigit()
                    .font(.title3.weight(.heavy)).foregroundColor(.white)
                    .frame(maxWidth: 80, alignment: .trailing)
            }
            HStack(spacing: 8) {
                if state.exerciseSets > 0 {
                    Text("Serie \(state.setIndex)/\(state.exerciseSets)")
                        .font(.caption2.weight(.heavy)).foregroundColor(ink)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(lime).clipShape(Capsule())
                }
                Spacer()
                if let bpm = state.bpm {
                    Label("\(bpm)", systemImage: "heart.fill").font(.caption.weight(.bold)).foregroundColor(.red)
                }
            }
            ControlsView(state: state)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 18, trailing: 16))
        .activityBackgroundTint(Color.black.opacity(0.65))
    }
}

/// Fila(s) de control: pasos de reps/peso + Hecho/Saltar; o controles de descanso.
/// Los botones son interactivos en iOS 17+ (App Intents); en 16.2–16.x se muestran como info.
@available(iOS 16.2, *)
private struct ControlsView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if state.resting, let ends = state.restEndsAt {
            restRow(start: state.restStartedAt ?? ends, end: ends)
        } else if #available(iOS 17.0, *) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    stepper("repeat", "\(state.reps)", "reps", down: .repsDown, up: .repsUp)
                    stepper("dumbbell.fill", wText(state.weight), "kg", down: .weightDown, up: .weightUp)
                }
                HStack(spacing: 8) {
                    action("Saltar", "xmark", .skip, bg: Color(red: 0.55, green: 0.16, blue: 0.16).opacity(0.85), fg: .white)
                    action("Hecho", "checkmark", .done, bg: lime, fg: ink)
                }
            }
        } else {
            HStack(spacing: 14) {
                Label("\(state.reps) reps", systemImage: "repeat")
                Label("\(wText(state.weight)) kg", systemImage: "dumbbell.fill")
                Spacer()
                Label("\(state.closedSets)/\(state.totalSets)", systemImage: "checkmark.circle").foregroundColor(lime)
            }
            .font(.caption.weight(.bold)).foregroundColor(.white.opacity(0.85))
        }
    }

    @ViewBuilder
    private func restRow(start: Date, end: Date) -> some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressView(timerInterval: start...end, countsDown: true)
                    .progressViewStyle(.circular)
                    .tint(lime)
                Text(timerInterval: start...end, countsDown: true)
                    .font(.system(size: 15, weight: .heavy)).monospacedDigit()
                    .foregroundColor(.white).frame(maxWidth: 54)
            }
            .frame(width: 62, height: 62)
            VStack(alignment: .leading, spacing: 2) {
                Text("Descanso").font(.system(size: 16, weight: .heavy)).foregroundColor(.white)
                Text("Recupera para la próxima serie").font(.caption2).foregroundColor(.white.opacity(0.65))
            }
            Spacer()
            if #available(iOS 17.0, *) {
                Button(intent: WorkoutControlIntent(.restSkip)) {
                    Text("Saltar").font(.system(size: 14, weight: .heavy)).foregroundColor(ink)
                        .padding(.horizontal, 16).frame(height: 40)
                        .background(lime).clipShape(Capsule())
                }.buttonStyle(.plain)
            }
        }
    }

    @available(iOS 17.0, *)
    private func stepper(_ icon: String, _ value: String, _ unit: String, down: WorkoutCommand, up: WorkoutCommand) -> some View {
        HStack(spacing: 6) {
            Button(intent: WorkoutControlIntent(down)) {
                Image(systemName: "minus").font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
                    .frame(width: 34, height: 34).background(Color.white.opacity(0.16)).clipShape(Circle())
            }.buttonStyle(.plain)
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text(value).font(.system(size: 18, weight: .heavy)).monospacedDigit().foregroundColor(.white)
                Text(unit).font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Button(intent: WorkoutControlIntent(up)) {
                Image(systemName: "plus").font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
                    .frame(width: 34, height: 34).background(Color.white.opacity(0.16)).clipShape(Circle())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 5).padding(.vertical, 4)
        .background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @available(iOS 17.0, *)
    private func action(_ title: String, _ icon: String, _ command: WorkoutCommand, bg: Color, fg: Color) -> some View {
        Button(intent: WorkoutControlIntent(command)) {
            Label(title, systemImage: icon).font(.system(size: 15, weight: .heavy)).foregroundColor(fg)
                .frame(maxWidth: .infinity).frame(height: 42)
                .background(bg).clipShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}
