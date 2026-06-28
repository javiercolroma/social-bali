import SwiftUI

struct PlanView: View {
    @EnvironmentObject var store: AppStore
    var onLoaded: () -> Void = {}
    @State private var preview: WorkoutTemplate?
    @State private var creating = false
    @State private var pendingDelete: WorkoutTemplate?

    private var grouped: [(group: String, workouts: [WorkoutTemplate])] {
        let dict = Dictionary(grouping: store.allWorkouts, by: { $0.block })
        let order = AppStore.groupOrder
        func rank(_ g: String) -> Int { order.firstIndex(of: g) ?? order.count }
        return dict.map { (group: $0.key, workouts: $0.value) }
            .sorted { a, b in
                let ra = rank(a.group), rb = rank(b.group)
                if ra != rb { return ra < rb }
                return a.group.localizedCaseInsensitiveCompare(b.group) == .orderedAscending
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button { creating = true } label: { Label("Crear entrenamiento", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle())

                ForEach(grouped, id: \.group) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(section.group.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                            Spacer()
                            Text("\(section.workouts.count)").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.soft)
                        }
                        ForEach(section.workouts) { workout in
                            Button { preview = workout } label: { workoutRow(workout) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { preview = workout } label: { Label("Ver / Editar", systemImage: "pencil") }
                                    if store.isSaved(workout.id) {
                                        Button(role: .destructive) { pendingDelete = workout } label: { Label("Eliminar", systemImage: "trash") }
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Brand.bg)
        .sheet(item: $preview) { WorkoutPreview(workoutId: $0.id, onLoaded: onLoaded).environmentObject(store) }
        .sheet(isPresented: $creating) { CreateWorkoutView().environmentObject(store) }
        .confirmationDialog("¿Eliminar “\(pendingDelete?.name ?? "")”?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { FX.warning(); if let w = pendingDelete { store.deleteWorkout(w.id) }; pendingDelete = nil }
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
        }
    }

    private func workoutRow(_ workout: WorkoutTemplate) -> some View {
        PanelCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.name).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                    Text(workout.description).font(.footnote).foregroundColor(Brand.muted).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.soft)
            }
        }
    }
}

struct WorkoutPreview: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let workoutId: String
    var onLoaded: () -> Void = {}
    @State private var showEditor = false
    @State private var confirmDelete = false

    private var workout: WorkoutTemplate? { store.allWorkouts.first { $0.id == workoutId } }
    private var isMine: Bool { store.isSaved(workoutId) }

    var body: some View {
        NavigationStack {
            Group {
                if let workout {
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
                            Button { FX.start(); store.loadWorkout(workout); dismiss(); onLoaded() } label: { Label("Cargar entreno", systemImage: "dumbbell.fill") }
                                .buttonStyle(PrimaryButtonStyle()).padding(.top, 8)
                            Button { showEditor = true } label: {
                                Label("Editar", systemImage: "pencil").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                                    .frame(maxWidth: .infinity).frame(minHeight: 48).background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            if isMine {
                                Button(role: .destructive) { confirmDelete = true } label: {
                                    Label("Eliminar entreno", systemImage: "trash").frame(maxWidth: .infinity)
                                }.padding(.top, 2)
                            }
                        }.padding(16)
                    }
                    .navigationTitle(workout.name)
                } else {
                    Color.clear.onAppear { dismiss() }
                }
            }
            .background(Brand.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
            .sheet(isPresented: $showEditor) {
                if let workout { CreateWorkoutView(editing: workout).environmentObject(store) }
            }
            .confirmationDialog("¿Eliminar este entreno?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { FX.warning(); store.deleteWorkout(workoutId); dismiss() }
                Button("Cancelar", role: .cancel) {}
            }
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
    var editing: WorkoutTemplate? = nil
    @State private var name = ""
    @State private var group = ""
    @State private var drafts: [DraftExercise] = [DraftExercise()]
    @State private var didLoad = false
    @FocusState private var groupFocused: Bool
    @FocusState private var focusedExercise: UUID?

    private let suggestedGroups = ["Pecho", "Espalda", "Pierna", "Hombro", "Brazo", "Abdomen", "Full body", "Push", "Pull"]
    private var groupOptions: [String] {
        var seen = Set<String>(); var out: [String] = []
        for g in store.customGroups + suggestedGroups where seen.insert(g).inserted { out.append(g) }
        return out
    }
    private var groupSuggestions: [String] {
        let q = group.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return groupOptions }
        return groupOptions.filter { $0.localizedCaseInsensitiveContains(q) && $0.caseInsensitiveCompare(q) != .orderedSame }
    }
    private var groupQuery: String { group.trimmingCharacters(in: .whitespaces) }
    private var canCreateGroup: Bool {
        !groupQuery.isEmpty && !groupOptions.contains { $0.caseInsensitiveCompare(groupQuery) == .orderedSame }
    }

    private var groupField: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill").font(.system(size: 13)).foregroundColor(Brand.soft)
                TextField("Pierna, Pecho, Pull…", text: $group).focused($groupFocused)
                if !group.isEmpty {
                    Button { group = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Brand.soft) }
                }
            }
            .padding(.horizontal, 12).frame(height: 46).background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(groupFocused ? Brand.greenSoft : Brand.line, lineWidth: groupFocused ? 1.5 : 1))

            if groupFocused {
                VStack(spacing: 0) {
                    if canCreateGroup {
                        groupRow(icon: "plus.circle.fill", color: Color(hex: "4b6211"), title: "Crear “\(groupQuery)”", badge: "nuevo") { commitGroup(groupQuery) }
                        if !groupSuggestions.isEmpty { Divider() }
                    }
                    ForEach(Array(groupSuggestions.prefix(6).enumerated()), id: \.element) { idx, opt in
                        groupRow(icon: "tag.fill", color: Brand.soft, title: opt, badge: nil) { commitGroup(opt) }
                        if idx < min(6, groupSuggestions.count) - 1 { Divider() }
                    }
                }
                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                .padding(.top, 6)
            }
        }
    }

    private func groupRow(icon: String, color: Color, title: String, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(color).frame(width: 18)
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.ink)
                Spacer()
                if let badge {
                    Text(badge).font(.system(size: 10, weight: .heavy)).foregroundColor(Brand.soft)
                        .padding(.horizontal, 7).padding(.vertical, 3).background(Brand.chip).clipShape(Capsule())
                }
            }.padding(.horizontal, 12).frame(height: 46)
        }
    }

    private func commitGroup(_ value: String) { group = value; groupFocused = false }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        drafts.contains { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    labeled("NOMBRE") {
                        TextField("Mi entreno", text: $name)
                            .padding(.horizontal, 12).frame(height: 46).background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line))
                    }

                    labeled("GRUPO") { groupField }

                    labeled("EJERCICIOS") {
                        VStack(spacing: 10) {
                            ForEach($drafts) { $draft in exerciseCard($draft) }
                            addButton
                        }
                    }

                    Button { save() } label: { Label("Guardar entreno", systemImage: "checkmark") }
                        .buttonStyle(PrimaryButtonStyle(enabled: canSave)).disabled(!canSave)
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle(editing == nil ? "Crear entreno" : "Editar entreno").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        guard !didLoad, let e = editing else { didLoad = true; return }
        name = e.name
        group = (e.block == "Por defecto" || e.block == "Mis entrenos") ? "" : e.block
        drafts = e.exercises.map { DraftExercise(name: $0.name, sets: $0.sets, reps: $0.reps, weight: $0.weight) }
        if drafts.isEmpty { drafts = [DraftExercise()] }
        didLoad = true
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exerciseCard(_ draft: Binding<DraftExercise>) -> some View {
        let id = draft.wrappedValue.id
        let suggestions = focusedExercise == id ? searchExercises(draft.wrappedValue.name) : []
        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Nombre del ejercicio", text: draft.name)
                    .font(.system(size: 15, weight: .semibold))
                    .focused($focusedExercise, equals: id)
                    .padding(.horizontal, 12).frame(height: 44).background(Brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                if drafts.count > 1 {
                    Button { drafts.removeAll { $0.id == id } } label: {
                        Image(systemName: "trash").font(.system(size: 15)).foregroundColor(Brand.red)
                            .frame(width: 44, height: 44).background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(suggestions.prefix(6).enumerated()), id: \.element) { idx, name in
                        Button { draft.wrappedValue.name = name; focusedExercise = nil } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "dumbbell.fill").font(.system(size: 12)).foregroundColor(Brand.soft).frame(width: 18)
                                Text(name).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.ink)
                                Spacer()
                            }.padding(.horizontal, 12).frame(height: 44)
                        }
                        if idx < min(6, suggestions.count) - 1 { Divider() }
                    }
                }
                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            }
            HStack(spacing: 8) {
                stepperBox("SERIES", text: "\(draft.wrappedValue.sets)",
                           dec: { if draft.wrappedValue.sets > 1 { draft.wrappedValue.sets -= 1 } },
                           inc: { if draft.wrappedValue.sets < 10 { draft.wrappedValue.sets += 1 } })
                stepperBox("REPS", text: "\(draft.wrappedValue.reps)",
                           dec: { if draft.wrappedValue.reps > 1 { draft.wrappedValue.reps -= 1 } },
                           inc: { if draft.wrappedValue.reps < 50 { draft.wrappedValue.reps += 1 } })
                stepperBox("KG", text: weightText(draft.wrappedValue.weight),
                           dec: { if draft.wrappedValue.weight >= 2.5 { draft.wrappedValue.weight -= 2.5 } },
                           inc: { draft.wrappedValue.weight += 2.5 })
            }
        }
        .padding(12).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
    }

    private func stepperBox(_ label: String, text: String, dec: @escaping () -> Void, inc: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Text(label).font(.system(size: 10, weight: .heavy)).foregroundColor(Brand.muted)
            HStack(spacing: 8) {
                roundBtn("minus", action: dec)
                Text(text).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink).frame(minWidth: 30)
                roundBtn("plus", action: inc)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func roundBtn(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(width: 30, height: 30).background(Color.white).clipShape(Circle())
                .overlay(Circle().stroke(Brand.line))
        }
    }

    private var addButton: some View {
        Button { drafts.append(DraftExercise()) } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Añadir ejercicio")
            }
            .font(.system(size: 15, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
            .frame(maxWidth: .infinity).frame(minHeight: 52)
            .background(Brand.greenSoft.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(hex: "9ec85a"), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
        }
    }

    private func save() {
        FX.success()
        let exercises = drafts
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { d in AppStore.makeExercise(name.isEmpty ? "Mi entreno" : name, d.name, d.sets, d.reps, d.weight) }
        if let e = editing {
            store.updateWorkout(id: e.id, name: name, group: group, exercises: exercises)
        } else {
            store.addWorkout(name: name, group: group, exercises: exercises)
        }
        dismiss()
    }

    private func weightText(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }
}
