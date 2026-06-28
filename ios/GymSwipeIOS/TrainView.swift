import SwiftUI

struct TrainView: View {
    @EnvironmentObject var store: AppStore
    var onGoToPlan: () -> Void = {}
    @State private var sessionStart: Date?
    @State private var restUntil: Date?
    @State private var showSummary = false
    @State private var previewWorkout: WorkoutTemplate?

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
                    activeCard(ex)
                    Button {
                        showSummary = true
                    } label: {
                        Label("Finalizar entrenamiento", systemImage: "flag.checkered")
                            .font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                            .frame(maxWidth: .infinity).frame(minHeight: 48)
                            .background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Brand.bg)
        .sheet(item: $previewWorkout) { w in
            WorkoutPreview(workoutId: w.id).environmentObject(store)
        }
        .onChange(of: store.exercises.isEmpty) { empty in
            if !empty { resetLocal() }
        }
    }

    // MARK: - Session

    private var sessionHeader: some View {
        PanelCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PROGRESO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    Text("\(closedSets) / \(totalSets) series").font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink)
                }
                Spacer()
                if let start = sessionStart {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(timeString(max(0, Int(-start.timeIntervalSinceNow)))).font(.system(size: 18, weight: .heavy)).monospacedDigit().foregroundColor(Brand.ink)
                    }
                }
            }
            ProgressView(value: Double(closedSets), total: Double(max(1, totalSets))).tint(Brand.green)
            if let until = restUntil {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let remaining = max(0, Int(until.timeIntervalSinceNow))
                    if remaining > 0 {
                        HStack {
                            Image(systemName: "timer"); Text("Descanso \(remaining)s").fontWeight(.bold)
                            Spacer(); Button("Saltar") { restUntil = nil }.font(.system(size: 13, weight: .heavy))
                        }.font(.system(size: 14)).foregroundColor(Color(hex: "4b6211"))
                    } else { Color.clear.frame(height: 0).onAppear { restUntil = nil } }
                }
            }
        }
    }

    private func activeCard(_ ex: Exercise) -> some View {
        PanelCard {
            Text(ex.day.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            Text(ex.name).font(.system(size: 26, weight: .heavy)).foregroundColor(Brand.ink)
            HStack(spacing: 6) {
                ForEach(0..<ex.sets, id: \.self) { i in Circle().fill(dotColor(ex, i)).frame(width: 12, height: 12) }
            }
            HStack(spacing: 16) {
                stat("\(ex.reps)", "reps"); stat(weightText(ex.weight), "kg"); stat("\(ex.rest)s", "descanso")
            }.padding(.vertical, 4)
            HStack(spacing: 10) {
                Button { register(ex, done: false) } label: {
                    Label("Saltar", systemImage: "xmark").font(.system(size: 15, weight: .heavy))
                        .foregroundColor(Color(hex: "a73232")).frame(maxWidth: .infinity).frame(minHeight: 50)
                        .background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    register(ex, done: true)
                    restUntil = Date().addingTimeInterval(Double(ex.rest))
                } label: {
                    Label("Hecho", systemImage: "checkmark").font(.system(size: 15, weight: .heavy))
                        .foregroundColor(Color(hex: "10150a")).frame(maxWidth: .infinity).frame(minHeight: 50)
                        .background(Brand.green).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func register(_ ex: Exercise, done: Bool) {
        if sessionStart == nil { sessionStart = Date() }
        store.registerSet(ex.id, done: done)
    }

    // MARK: - Summary (Strava-style)

    private var summary: some View {
        PanelCard {
            HStack { Spacer(); Text("🏁").font(.system(size: 44)); Spacer() }
            Text("Resumen del entreno").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(workoutName).font(.footnote).foregroundColor(Brand.muted)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 10) {
                summaryStat(timeString(elapsedSeconds), "Duración", "clock")
                summaryStat("\(completedSets)", "Series", "checkmark.circle")
            }
            HStack(spacing: 10) {
                summaryStat("\(Int(sessionVolume)) kg", "Volumen", "scalemass")
                summaryStat("+\(sessionXP)", "XP", "bolt.fill")
            }
            if skippedSets > 0 {
                Text("\(skippedSets) series saltadas · \(exercisesDone) ejercicios").font(.caption).foregroundColor(Brand.soft)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Button { store.saveSession(); resetLocal() } label: { Label("Guardar entrenamiento", systemImage: "checkmark") }
                .buttonStyle(PrimaryButtonStyle())
            Button(role: .destructive) { store.discardSession(); resetLocal() } label: {
                Label("Descartar", systemImage: "trash").frame(maxWidth: .infinity)
            }.padding(.top, 2)
        }
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

    private func resetLocal() { sessionStart = nil; restUntil = nil; showSummary = false }

    // MARK: - Empty

    private var emptyState: some View {
        PanelCard {
            HStack { Spacer(); Text("🏋️").font(.system(size: 44)); Spacer() }
            Text("¿Qué entrenamos hoy?").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("TUS MÁS FRECUENTES").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                .padding(.top, 4)
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
                    }
                    .padding(.horizontal, 4)
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

    // MARK: - Helpers

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
        }
    }

    private func dotColor(_ ex: Exercise, _ i: Int) -> Color {
        if i < ex.completedSets { return Brand.green }
        if i < ex.completedSets + ex.skippedSets { return Brand.red.opacity(0.6) }
        return Brand.chip
    }

    private func weightText(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }
    private func timeString(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}
