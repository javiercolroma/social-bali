import SwiftUI

struct PlanView: View {
    @EnvironmentObject var store: AppStore
    @State private var preview: WorkoutTemplate?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PanelCard {
                    Text("BIBLIOTECA").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    Text(store.lastAction).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.ink)
                    Text("Toca un entreno para ver sus ejercicios y cargarlo.").font(.footnote).foregroundColor(Brand.muted)
                }
                ForEach(store.allWorkouts) { workout in
                    Button { preview = workout } label: { workoutRow(workout) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Brand.bg)
        .sheet(item: $preview) { workout in
            WorkoutPreview(workout: workout).environmentObject(store)
        }
    }

    private func workoutRow(_ workout: WorkoutTemplate) -> some View {
        PanelCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.name).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                    Text(workout.description).font(.footnote).foregroundColor(Brand.muted)
                }
                Spacer()
                Text("\(workout.exercises.count)").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
                Text("ej.").font(.caption2).foregroundColor(Brand.muted)
            }
        }
    }
}

struct WorkoutPreview: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let workout: WorkoutTemplate

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { idx, ex in
                        HStack(spacing: 12) {
                            Text("\(idx + 1)").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.muted)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.ink)
                                Text("\(ex.sets)×\(ex.reps) · \(weightText(ex.weight)) kg").font(.footnote).foregroundColor(Brand.muted)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Brand.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line))
                    }
                    Button {
                        store.loadWorkout(workout)
                        dismiss()
                    } label: { Label("Cargar entreno", systemImage: "dumbbell.fill") }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 8)
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle(workout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
        }
    }

    private func weightText(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }
}
