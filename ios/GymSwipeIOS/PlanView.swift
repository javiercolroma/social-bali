import SwiftUI

struct PlanView: View {
    @EnvironmentObject var store: AppStore
    @State private var preview: WorkoutTemplate?
    @State private var creating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Button { creating = true } label: {
                    Label("Crear entrenamiento", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())

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
        .sheet(isPresented: $creating) {
            CreateWorkoutView().environmentObject(store)
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

    private var isMine: Bool { workout.block == "Mis entrenos" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { idx, ex in
                        HStack(spacing: 12) {
                            Text("\(idx + 1)").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.muted).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.ink)
                                Text("\(ex.sets)×\(ex.reps) · \(weightText(ex.weight)) kg").font(.footnote).foregroundColor(Brand.muted)
                            }
                            Spacer()
                        }
                        .padding(12).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line))
                    }
                    Button { store.loadWorkout(workout); dismiss() } label: {
                        Label("Cargar entreno", systemImage: "dumbbell.fill")
                    }.buttonStyle(PrimaryButtonStyle()).padding(.top, 8)

                    if isMine {
                        Button(role: .destructive) { store.deleteWorkout(workout.id); dismiss() } label: {
                            Label("Eliminar entreno", systemImage: "trash").frame(maxWidth: .infinity)
                        }.padding(.top, 2)
                    }
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle(workout.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
        }
    }

    private func weightText(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }
}

private struct DraftExercise: Identifiable {
    let id = UUID()
    var name = ""
    var sets = 4
    var reps = 8
    var weight = 20.0
}

struct CreateWorkoutView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var drafts: [DraftExercise] = [DraftExercise()]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        drafts.contains { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("NOMBRE").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        TextField("Mi entreno", text: $name)
                            .padding(.horizontal, 12).frame(height: 46).background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line))
                    }

                    ForEach($drafts) { $draft in
                        VStack(spacing: 8) {
                            HStack {
                                TextField("Ejercicio", text: $draft.name)
                                    .padding(.horizontal, 10).frame(height: 40).background(Brand.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                if drafts.count > 1 {
                                    Button { drafts.removeAll { $0.id == draft.id } } label: {
                                        Image(systemName: "trash").foregroundColor(Brand.red)
                                    }
                                }
                            }
                            HStack(spacing: 8) {
                                stepperBox("Series", value: $draft.sets, range: 1...10)
                                stepperBox("Reps", value: $draft.reps, range: 1...50)
                                weightBox("Kg", value: $draft.weight)
                            }
                        }
                        .padding(12).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
                    }

                    Button { drafts.append(DraftExercise()) } label: {
                        Label("Añadir ejercicio", systemImage: "plus.circle")
                    }
                    .font(.system(size: 14, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))

                    Button { save() } label: { Label("Guardar entreno", systemImage: "checkmark") }
                        .buttonStyle(PrimaryButtonStyle(enabled: canSave)).disabled(!canSave)
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Crear entreno").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
        }
    }

    private func save() {
        let exercises = drafts
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { d in AppStore.makeExercise(name.isEmpty ? "Mi entreno" : name, d.name, d.sets, d.reps, d.weight) }
        store.addWorkout(name: name, exercises: exercises)
        dismiss()
    }

    private func stepperBox(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            HStack(spacing: 6) {
                Button { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 } } label: { Image(systemName: "minus") }
                Text("\(value.wrappedValue)").font(.system(size: 15, weight: .heavy)).frame(minWidth: 24)
                Button { if value.wrappedValue < range.upperBound { value.wrappedValue += 1 } } label: { Image(systemName: "plus") }
            }.foregroundColor(Brand.ink)
        }.frame(maxWidth: .infinity).padding(.vertical, 6).background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func weightBox(_ label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            HStack(spacing: 6) {
                Button { if value.wrappedValue >= 2.5 { value.wrappedValue -= 2.5 } } label: { Image(systemName: "minus") }
                Text(value.wrappedValue == value.wrappedValue.rounded() ? "\(Int(value.wrappedValue))" : String(format: "%.1f", value.wrappedValue))
                    .font(.system(size: 15, weight: .heavy)).frame(minWidth: 30)
                Button { value.wrappedValue += 2.5 } label: { Image(systemName: "plus") }
            }.foregroundColor(Brand.ink)
        }.frame(maxWidth: .infinity).padding(.vertical, 6).background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
