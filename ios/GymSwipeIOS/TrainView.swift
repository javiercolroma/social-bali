import SwiftUI
import PhotosUI

struct TrainView: View {
    @EnvironmentObject var store: AppStore
    var onGoToPlan: () -> Void = {}
    @State private var sessionStart: Date?
    @State private var showSummary = false
    @State private var previewWorkout: WorkoutTemplate?
    @State private var sessionName = ""
    @State private var sessionNote = ""
    @State private var sessionPhoto: Data?
    @State private var sessionPickerItem: PhotosPickerItem?
    @State private var visibility: WorkoutVisibility = .all
    @State private var restActive = false
    @State private var restElapsed = 0
    @State private var restTotal = 0
    @AppStorage("fxSound") private var soundOn = true
    @AppStorage("fxHaptics") private var hapticsOn = true

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    // TODO: pruebas — descanso fijo a 10s. Volver a `ex.rest` para producción.
    private let testRestSeconds = 10

    private var totalSets: Int { store.exercises.reduce(0) { $0 + $1.sets } }
    private var closedSets: Int { store.exercises.reduce(0) { $0 + $1.completedSets + $1.skippedSets } }
    private var completedSets: Int { store.exercises.reduce(0) { $0 + $1.completedSets } }
    private var skippedSets: Int { store.exercises.reduce(0) { $0 + $1.skippedSets } }
    private var sessionVolume: Double { store.exercises.reduce(0) { $0 + Double($1.completedSets) * Double($1.reps) * $1.weight } }
    private var sessionXP: Int { store.exercises.reduce(0) { $0 + $1.completedSets * 12 + ($1.completedSets > 0 ? 18 : 0) } }
    private var exercisesDone: Int { store.exercises.filter { $0.completedSets > 0 }.count }
    private var elapsedSeconds: Int { sessionStart.map { max(0, Int(-$0.timeIntervalSinceNow)) } ?? 0 }
    private var finished: Bool { store.activeExercise == nil && !store.exercises.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if store.exercises.isEmpty {
                    emptyState
                } else if showSummary || finished {
                    summary
                } else if let ex = store.activeExercise {
                    sessionHeader
                    if restActive { restBanner }
                    activeCard(ex)
                        .id(ex.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)))
                    finishButton
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: store.activeExercise?.id)
        }
        .background(Brand.bg)
        .sheet(item: $previewWorkout) { WorkoutPreview(workoutId: $0.id).environmentObject(store) }
        .onAppear { if !store.exercises.isEmpty && sessionStart == nil { sessionStart = Date() } }
        .onChange(of: store.exercises.isEmpty) { empty in
            if empty { resetLocal() }
            else { sessionStart = Date(); restActive = false; restElapsed = 0; showSummary = false }
        }
        .onReceive(ticker) { _ in
            if restActive && restElapsed < restTotal {
                restElapsed += 1
                if restElapsed >= restTotal { fxRest() }
            }
        }
    }

    // MARK: - Session

    private var sessionHeader: some View {
        PanelCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workoutName.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    Text("\(closedSets) / \(totalSets) series").font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink)
                }
                Spacer()
                if let start = sessionStart {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        HStack(spacing: 5) {
                            Image(systemName: "clock.fill").font(.system(size: 13)).foregroundColor(Color(hex: "6ea300"))
                            Text(timeString(max(0, Int(-start.timeIntervalSinceNow))))
                                .font(.system(size: 21, weight: .heavy)).monospacedDigit().foregroundColor(Brand.ink)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Brand.surface).clipShape(Capsule())
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Brand.chip)
                    Capsule().fill(Brand.green)
                        .frame(width: max(6, geo.size.width * CGFloat(closedSets) / CGFloat(max(1, totalSets))))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: closedSets)
                }
            }.frame(height: 10)
        }
    }

    private var restOver: Bool { restElapsed >= restTotal }
    private var restRemaining: Int { max(0, restTotal - restElapsed) }

    private var restBanner: some View {
        PanelCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Brand.chip, lineWidth: 7)
                    Circle().trim(from: 0, to: restOver ? 1 : CGFloat(restRemaining) / CGFloat(max(1, restTotal)))
                        .stroke(Brand.green, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: restElapsed)
                    if restOver {
                        Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 26)).foregroundColor(Color(hex: "4b6211"))
                    } else {
                        Text(timeString(restRemaining)).font(.system(size: 17, weight: .heavy)).monospacedDigit().foregroundColor(Brand.ink)
                    }
                }.frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 2) {
                    Text(restOver ? "¡Haz tu serie!" : "Descanso")
                        .font(.system(size: 17, weight: .heavy)).foregroundColor(restOver ? Color(hex: "4b6211") : Brand.ink)
                    Text(restOver ? "Descanso completado" : "Recupera para la próxima serie")
                        .font(.caption).foregroundColor(Brand.muted)
                }
                Spacer()
                if !restOver {
                    Button { restTotal += 15; Haptics.soft() } label: {
                        Text("+15s").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                            .padding(.horizontal, 14).frame(height: 38).background(Brand.chip).clipShape(Capsule())
                    }
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func activeCard(_ ex: Exercise) -> some View {
        let current = min(ex.sets, ex.completedSets + ex.skippedSets + 1)
        return PanelCard {
            HStack {
                Text(ex.day.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                Spacer()
                Text("SERIE \(current) DE \(ex.sets)").font(.caption2).fontWeight(.heavy).foregroundColor(Color(hex: "4b6211"))
            }
            Text(ex.name).font(.system(size: 28, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(2)
            HStack(spacing: 7) {
                ForEach(0..<ex.sets, id: \.self) { i in
                    Circle().fill(dotColor(ex, i))
                        .frame(width: 13, height: 13)
                        .scaleEffect(i == ex.completedSets + ex.skippedSets - 1 ? 1.25 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: ex.completedSets + ex.skippedSets)
                }
            }
            HStack(spacing: 12) {
                editStat("repeat", "\(ex.reps)", "reps",
                         minus: { store.adjustReps(ex.id, -1); Haptics.soft() },
                         plus: { store.adjustReps(ex.id, 1); Haptics.soft() })
                editStat("dumbbell.fill", weightText(ex.weight), "kg",
                         minus: { store.adjustWeight(ex.id, -2.5); Haptics.soft() },
                         plus: { store.adjustWeight(ex.id, 2.5); Haptics.soft() })
            }.padding(.vertical, 6)
            HStack(spacing: 10) {
                Button { register(ex, done: false) } label: {
                    Label("Saltar", systemImage: "xmark").font(.system(size: 16, weight: .heavy))
                        .foregroundColor(Color(hex: "a73232")).frame(maxWidth: .infinity).frame(minHeight: 56)
                        .background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(PressableButtonStyle())
                Button { register(ex, done: true) } label: {
                    Label("Hecho", systemImage: "checkmark").font(.system(size: 17, weight: .heavy))
                        .foregroundColor(Color(hex: "10150a")).frame(maxWidth: .infinity).frame(minHeight: 56)
                        .background(Brand.green).clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Brand.green.opacity(0.45), radius: 12, y: 6)
                }.buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var finishButton: some View {
        Button { withAnimation { showSummary = true } } label: {
            Label("Finalizar entrenamiento", systemImage: "flag.checkered")
                .font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(maxWidth: .infinity).frame(minHeight: 48)
                .background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func register(_ ex: Exercise, done: Bool) {
        if sessionStart == nil { sessionStart = Date() }
        let willClose = (ex.completedSets + ex.skippedSets + 1) >= ex.sets
        if done { restActive = true; restTotal = testRestSeconds; restElapsed = 0 } else { restActive = false }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { store.registerSet(ex.id, done: done) }

        if willClose && store.activeExercise != nil {
            fxExercise()   // moved to the next exercise: special sound
        } else if done {
            fxDone()
        } else {
            fxSkip()
        }
    }

    // MARK: - Summary

    private var summary: some View {
        ZStack(alignment: .top) {
            PanelCard {
                HStack { Spacer(); Text("🏁").font(.system(size: 46)); Spacer() }
                Text("¡Buen trabajo!").font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                    .frame(maxWidth: .infinity, alignment: .center)
                HStack(spacing: 10) {
                    summaryStat(timeString(elapsedSeconds), "Duración", "clock")
                    summaryStat("\(completedSets)", "Series", "checkmark.circle")
                }
                HStack(spacing: 10) {
                    summaryStat("\(Int(sessionVolume)) kg", "Volumen", "dumbbell.fill")
                    summaryStat("+\(sessionXP)", "XP", "bolt.fill")
                }
                if skippedSets > 0 {
                    Text("\(skippedSets) series saltadas · \(exercisesDone) ejercicios").font(.caption).foregroundColor(Brand.soft)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Divider().padding(.vertical, 2)

                summaryLabel("NOMBRE DEL ENTRENO")
                TextField(defaultSessionName, text: $sessionName)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 12).frame(height: 44).background(Brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                summaryLabel("¿QUÉ TAL TE HA IDO?")
                TextField("Cómo te has sentido, sensaciones…", text: $sessionNote, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(2...4)
                    .padding(.horizontal, 12).padding(.vertical, 10).background(Brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                summaryLabel("FOTO DEL ENTRENO (OPCIONAL)")
                PhotoPickerLabel(item: $sessionPickerItem, onPicked: { sessionPhoto = $0 }) {
                    if let data = sessionPhoto, let ui = UIImage(data: data) {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(height: 120).frame(maxWidth: .infinity).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "pencil.circle.fill").font(.system(size: 24)).foregroundColor(.white).padding(6)
                            }
                    } else {
                        HStack(spacing: 8) { Image(systemName: "camera.fill"); Text("Añadir foto") }
                            .font(.system(size: 15, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                            .frame(maxWidth: .infinity).frame(minHeight: 52)
                            .background(Brand.greenSoft.opacity(0.22)).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: "9ec85a"), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
                    }
                }

                summaryLabel("¿QUIÉN PUEDE VERLO?")
                HStack(spacing: 8) {
                    ForEach(WorkoutVisibility.allCases, id: \.self) { v in
                        Button { FX.tap(); visibility = v } label: {
                            HStack(spacing: 5) {
                                Image(systemName: v.icon).font(.system(size: 11, weight: .bold))
                                Text(v.label).font(.system(size: 12, weight: .heavy))
                            }
                            .frame(maxWidth: .infinity).frame(height: 38)
                            .background(visibility == v ? Brand.greenSoft : Brand.chip)
                            .foregroundColor(Brand.ink).clipShape(Capsule())
                        }
                    }
                }

                Button {
                    fxFinish()
                    store.saveSession(name: sessionName, note: sessionNote, photoData: sessionPhoto, visibility: visibility, elapsed: elapsedSeconds)
                    resetLocal()
                } label: { Label("Guardar entrenamiento", systemImage: "checkmark") }
                    .buttonStyle(PrimaryButtonStyle()).padding(.top, 4)
                Button(role: .destructive) { store.discardSession(); resetLocal() } label: {
                    Label("Descartar", systemImage: "trash").frame(maxWidth: .infinity)
                }.padding(.top, 2)
            }
            ConfettiView().frame(height: 320).allowsHitTesting(false)
        }
        .onAppear { fxFinish(); if sessionName.isEmpty { sessionName = defaultSessionName } }
    }

    private func summaryLabel(_ text: String) -> some View {
        Text(text).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 2)
    }

    private func summaryStat(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(Color(hex: "6ea300"))
            Text(value).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var workoutName: String { store.exercises.first?.day ?? "Entreno" }

    /// Strava-style default with a gym twist: "<grupo> de <franja>" (e.g. "Pierna de tarde").
    private var defaultSessionName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let time = hour < 12 ? "de mañana" : (hour < 21 ? "de tarde" : "de noche")
        var counts: [String: Int] = [:]
        for e in store.exercises { counts[GymScoreEngine.pattern(for: e.exerciseName).group, default: 0] += 1 }
        let top = counts.max { $0.value < $1.value }?.key ?? ""
        let labels = ["pierna": "Pierna", "bisagra": "Posterior", "empuje": "Empuje",
                      "tiron": "Tirón", "condicion": "Cardio", "accesorio": "Full body"]
        return "\(labels[top] ?? "Entreno") \(time)"
    }
    private func resetLocal() {
        sessionStart = nil; restActive = false; restElapsed = 0; restTotal = 0; showSummary = false
        sessionName = ""; sessionNote = ""; sessionPhoto = nil; sessionPickerItem = nil; visibility = .all
    }

    // MARK: - Empty

    private var emptyState: some View {
        PanelCard {
            HStack { Spacer(); Text("🏋️").font(.system(size: 44)); Spacer() }
            Text("¿Qué entrenamos hoy?").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("TUS MÁS FRECUENTES").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted).padding(.top, 4)
            ForEach(store.frequentWorkouts) { t in
                Button { previewWorkout = t } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.name).font(.system(size: 15, weight: .heavy))
                            Text("\(t.exercises.count) ejercicios").font(.caption2).fontWeight(.bold).opacity(0.7)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).opacity(0.6)
                    }.padding(.horizontal, 4)
                }.buttonStyle(PrimaryButtonStyle())
            }
            Button { onGoToPlan() } label: {
                HStack { Image(systemName: "square.grid.2x2"); Text("Otros entrenos"); Spacer(); Image(systemName: "chevron.right") }
                    .font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    .padding(.horizontal, 14).frame(maxWidth: .infinity).frame(minHeight: 50)
                    .background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - FX

    private func fxDone() { if hapticsOn { Haptics.success() }; if soundOn { Synth.shared.done() } }
    private func fxSkip() { if hapticsOn { Haptics.soft() }; if soundOn { Synth.shared.skip() } }
    private func fxExercise() { if hapticsOn { Haptics.success() }; if soundOn { Synth.shared.exercise() } }
    private func fxRest() { if hapticsOn { Haptics.rigid() }; if soundOn { Synth.shared.rest() } }
    private func fxFinish() { if hapticsOn { Haptics.success() }; if soundOn { Synth.shared.finish() } }

    // MARK: - Helpers

    private func editStat(_ icon: String, _ value: String, _ label: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Color(hex: "6ea300"))
            HStack(spacing: 12) {
                stepButton("minus", action: minus)
                Text(value).font(.system(size: 24, weight: .heavy)).foregroundColor(Brand.ink)
                    .frame(minWidth: 44).contentTransition(.numericText())
                stepButton("plus", action: plus)
            }
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(width: 32, height: 32).background(Color.white).clipShape(Circle())
                .overlay(Circle().stroke(Brand.line))
        }.buttonStyle(PressableButtonStyle())
    }

    private func dotColor(_ ex: Exercise, _ i: Int) -> Color {
        if i < ex.completedSets { return Brand.green }
        if i < ex.completedSets + ex.skippedSets { return Brand.red.opacity(0.6) }
        return Brand.chip
    }

    private func weightText(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }
    private func timeString(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}
