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
                    VStack(alignment: .leading, spacing: 2) {
                        Label {
                            Text(s.currentExercise.isEmpty ? "In progress" : s.currentExercise)
                                .font(.caption).fontWeight(.heavy).lineLimit(1)
                        } icon: {
                            Image(systemName: "dumbbell.fill").foregroundColor(lime)
                        }
                        if let partner = s.supersetPartner, !partner.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "link").font(.system(size: 8, weight: .heavy))
                                Text(partner).font(.system(size: 9, weight: .heavy)).lineLimit(1)
                            }.foregroundColor(lime)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if s.resting, let ends = s.restEndsAt {
                        Text(timerInterval: (s.restStartedAt ?? ends)...ends, countsDown: true)
                            .monospacedDigit().font(.title3.weight(.heavy))
                            .foregroundColor(lime).frame(maxWidth: 72, alignment: .trailing)
                    } else if s.exerciseSets > 0 {
                        Text("Set \(s.setIndex)/\(s.exerciseSets)")
                            .font(.caption.weight(.heavy)).foregroundColor(.white)
                            .frame(maxWidth: 90, alignment: .trailing)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if let bpm = s.bpm {
                        Label("\(bpm)", systemImage: "heart.fill")
                            .font(.caption2.weight(.bold)).foregroundColor(.red)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ControlsView(state: s).padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundColor(lime)
            } compactTrailing: {
                if s.resting, let ends = s.restEndsAt {
                    Text(timerInterval: (s.restStartedAt ?? ends)...ends, countsDown: true)
                        .monospacedDigit().frame(maxWidth: 44).foregroundColor(lime)
                } else if s.exerciseSets > 0 {
                    Text("\(s.setIndex)/\(s.exerciseSets)")
                        .font(.caption2.weight(.heavy)).monospacedDigit().foregroundColor(.white)
                } else {
                    Image(systemName: "dumbbell.fill").foregroundColor(lime)
                }
            } minimal: {
                if s.resting, let ends = s.restEndsAt {
                    Text(timerInterval: (s.restStartedAt ?? ends)...ends, countsDown: true)
                        .monospacedDigit().frame(maxWidth: 36).foregroundColor(lime)
                } else {
                    Image(systemName: "dumbbell.fill").foregroundColor(lime)
                }
            }
            .keylineTint(lime)
        }
    }
}

@available(iOS 16.2, *)
/// Vibración en los botones del widget: los intents no pueden disparar haptics directamente
/// (proceso en segundo plano), pero `sensoryFeedback` vibra al CAMBIAR el estado que el
/// botón modifica — el efecto para el usuario es "toco → vibra".
private extension View {
    @ViewBuilder func hapticOnChange<T: Equatable>(_ value: T) -> some View {
        if #available(iOS 17.0, *) { self.sensoryFeedback(.impact(weight: .medium), trigger: value) } else { self }
    }
    @ViewBuilder func hapticSuccessOnChange<T: Equatable>(_ value: T) -> some View {
        if #available(iOS 17.0, *) { self.sensoryFeedback(.success, trigger: value) } else { self }
    }
}

private struct LockScreenView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        content
            // Vibraciones del widget: ajustar reps/peso (toque), cerrar serie (éxito),
            // empezar/terminar descanso (toque).
            .hapticOnChange(state.reps)
            .hapticOnChange(state.weight)
            .hapticSuccessOnChange(state.closedSets)
            .hapticOnChange(state.resting)
    }

    private var content: some View {
        VStack(spacing: 10) {
            // Una sola fila de cabecera. El cronómetro de entrenamiento se ha
            // eliminado; el chip "Serie X/Y" ocupa el hueco que dejó arriba a la derecha.
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill").foregroundColor(lime)
                Text(state.currentExercise.isEmpty ? "Workout in progress" : state.currentExercise)
                    .font(.headline).foregroundColor(.white).lineLimit(1)
                Spacer(minLength: 8)
                if let bpm = state.bpm {
                    Label("\(bpm)", systemImage: "heart.fill")
                        .font(.caption2.weight(.bold)).foregroundColor(.red)
                        .labelStyle(.titleAndIcon)
                }
                if state.exerciseSets > 0 {
                    Text("Set \(state.setIndex)/\(state.exerciseSets)")
                        .font(.caption2.weight(.heavy)).foregroundColor(ink)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(lime).clipShape(Capsule())
                }
            }
            if let partner = state.supersetPartner, !partner.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "link").font(.system(size: 9, weight: .heavy))
                    Text("SUPERSET").font(.system(size: 9, weight: .heavy))
                    Image(systemName: "arrow.right").font(.system(size: 8, weight: .heavy))
                    Text(partner).font(.system(size: 10, weight: .heavy)).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundColor(lime)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ControlsView(state: state)   // controles O el bloque de descanso
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16))
        .activityBackgroundTint(Color.black.opacity(0.65))
    }
}

/// Fila(s) de control: pasos de reps/peso + Hecho/Saltar; o el bloque de descanso.
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
                    action("Skip", "xmark", .skip, bg: Color(red: 0.55, green: 0.16, blue: 0.16).opacity(0.85), fg: .white)
                    action("Done", "checkmark", .done, bg: lime, fg: ink)
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

    /// Descanso: fila compacta HORIZONTAL (aro a la izquierda, texto en medio, "Saltar" a la
    /// derecha). El layout vertical anterior era demasiado alto y se recortaba en el lock screen.
    /// El contador va DENTRO del aro como `currentValueLabel` (el sistema lo centra solo, nítido,
    /// sin solapamientos). Tamaño con `.frame` (funciona en el contexto de Live Activity).
    @ViewBuilder
    private func restRow(start: Date, end: Date) -> some View {
        HStack(spacing: 14) {
            ProgressView(timerInterval: start...end, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                Text(timerInterval: start...end, countsDown: true)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .foregroundColor(.white)
            }
            .progressViewStyle(.circular)
            .tint(lime)
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 2) {
                Text("REST").font(.system(size: 14, weight: .heavy)).foregroundColor(lime)
                Text("Catch your breath").font(.caption2).foregroundColor(.white.opacity(0.6)).lineLimit(1)
            }

            Spacer(minLength: 8)

            if #available(iOS 17.0, *) {
                Button(intent: WorkoutControlIntent(.restSkip)) {
                    Text("Skip")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(ink)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(lime)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
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
