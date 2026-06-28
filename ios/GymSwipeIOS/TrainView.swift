import SwiftUI

struct TrainView: View {
    @EnvironmentObject var store: AppStore
    @State private var sessionStart: Date?
    @State private var restUntil: Date?

    private var totalSets: Int { store.exercises.reduce(0) { $0 + $1.sets } }
    private var closedSets: Int { store.exercises.reduce(0) { $0 + $1.completedSets + $1.skippedSets } }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if store.exercises.isEmpty {
                    emptyState
                } else if let ex = store.activeExercise {
                    sessionHeader
                    activeCard(ex)
                } else {
                    finishedState
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Brand.bg)
    }

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
                        Text(elapsed(start)).font(.system(size: 18, weight: .heavy)).monospacedDigit().foregroundColor(Brand.ink)
                    }
                }
            }
            ProgressView(value: Double(closedSets), total: Double(max(1, totalSets))).tint(Brand.green)
            if let until = restUntil {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let remaining = max(0, Int(until.timeIntervalSinceNow))
                    if remaining > 0 {
                        HStack {
                            Image(systemName: "timer")
                            Text("Descanso \(remaining)s").fontWeight(.bold)
                            Spacer()
                            Button("Saltar") { restUntil = nil }.font(.system(size: 13, weight: .heavy))
                        }
                        .font(.system(size: 14)).foregroundColor(Color(hex: "4b6211"))
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
                ForEach(0..<ex.sets, id: \.self) { i in
                    Circle()
                        .fill(dotColor(ex, i))
                        .frame(width: 12, height: 12)
                }
            }
            HStack(spacing: 16) {
                stat("\(ex.reps)", "reps")
                stat(weightText(ex.weight), "kg")
                stat("\(ex.rest)s", "descanso")
            }
            .padding(.vertical, 4)
            HStack(spacing: 10) {
                Button {
                    store.registerSet(ex.id, done: false)
                } label: {
                    Label("Saltar", systemImage: "xmark").font(.system(size: 15, weight: .heavy))
                        .foregroundColor(Color(hex: "a73232")).frame(maxWidth: .infinity).frame(minHeight: 50)
                        .background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    store.registerSet(ex.id, done: true)
                    if sessionStart == nil { sessionStart = Date() }
                    restUntil = Date().addingTimeInterval(Double(ex.rest))
                } label: {
                    Label("Hecho", systemImage: "checkmark").font(.system(size: 15, weight: .heavy))
                        .foregroundColor(Color(hex: "10150a")).frame(maxWidth: .infinity).frame(minHeight: 50)
                        .background(Brand.green).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var finishedState: some View {
        PanelCard {
            HStack { Spacer(); Text("💪").font(.system(size: 44)); Spacer() }
            Text("¡Entreno completado!").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("\(closedSets) series registradas").foregroundColor(Brand.muted)
                .frame(maxWidth: .infinity, alignment: .center)
            Button("Reiniciar entreno") { store.resetSession(); sessionStart = nil; restUntil = nil }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var emptyState: some View {
        PanelCard {
            HStack { Spacer(); Text("🏋️").font(.system(size: 44)); Spacer() }
            Text("Aún no has cargado un entreno").font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Carga uno desde la pestaña Plan o empieza con uno rápido.").foregroundColor(Brand.muted)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            ForEach(store.templates.prefix(3)) { t in
                Button { store.loadWorkout(t); sessionStart = nil; restUntil = nil } label: {
                    HStack { Image(systemName: "bolt.fill"); Text("Cargar \(t.name)") }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

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

    private func elapsed(_ start: Date) -> String {
        let s = max(0, Int(-start.timeIntervalSinceNow))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
