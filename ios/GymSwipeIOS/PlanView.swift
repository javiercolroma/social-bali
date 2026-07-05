import SwiftUI

struct PlanView: View {
    @EnvironmentObject var store: AppStore
    var onLoaded: () -> Void = {}
    @State private var preview: WorkoutTemplate?
    @State private var creating = false
    @State private var aiCreating = false   // generar entreno con Forgey (IA on-device)
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

    /// Primer entreno de la lista (para anclar el tutorial de "cargar entreno").
    private var firstWorkoutId: String? { grouped.first?.workouts.first?.id }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button { creating = true } label: { Label("Crear entrenamiento", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle())
                    .tourAnchor("plan.create")

                // Crear con IA on-device: solo en dispositivos que la soportan.
                if ForgeyEngine.isAvailable { aiCreateButton }

                ForEach(grouped, id: \.group) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.x(section.group).uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                            Spacer()
                            Text("\(section.workouts.count)").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.soft)
                        }
                        ForEach(section.workouts) { workout in
                            Button { preview = workout } label: { workoutRow(workout) }
                                .buttonStyle(.plain)
                                .tourAnchor("plan.item", if: workout.id == firstWorkoutId)
                                .contextMenu {
                                    Button { preview = workout } label: { Label("Ver / Editar", systemImage: "pencil") }
                                    Button(role: .destructive) { pendingDelete = workout } label: { Label("Eliminar", systemImage: "trash") }
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
        .sheet(isPresented: $aiCreating) { AIWorkoutSheet(onLoaded: onLoaded).environmentObject(store) }
        .alert("¿Eliminar entreno?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), presenting: pendingDelete) { w in
            Button("Eliminar", role: .destructive) { FX.warning(); store.deleteWorkout(w.id); pendingDelete = nil }
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
        } message: { w in
            Text("Se quitará “\(w.name)” de tu lista de entrenos.")
        }
    }

    private var aiCreateButton: some View {
        Button { FX.tap(); aiCreating = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("Crear con Forgey (IA)")
            }
            .font(.system(size: 15, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
            .frame(maxWidth: .infinity).frame(minHeight: 48)
            .background(Brand.greenSoft.opacity(0.28)).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(hex: "9ec85a"), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
        }
    }

    private func workoutRow(_ workout: WorkoutTemplate) -> some View {
        PanelCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(Brand.greenSoft).frame(width: 42, height: 42)
                    Image(systemName: "dumbbell.fill").font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "10150a"))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.x(workout.name)).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
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

    var body: some View {
        NavigationStack {
            Group {
                if let workout {
                    ScrollView {
                        VStack(spacing: 8) {
                            WorkoutExerciseList(exercises: workout.exercises)
                            Button { FX.start(); store.loadWorkout(workout); dismiss(); onLoaded() } label: { Label("Cargar entreno", systemImage: "dumbbell.fill") }
                                .buttonStyle(PrimaryButtonStyle()).padding(.top, 8)
                            Button { showEditor = true } label: {
                                Label("Editar", systemImage: "pencil").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                                    .frame(maxWidth: .infinity).frame(minHeight: 48).background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Label("Eliminar entreno", systemImage: "trash").frame(maxWidth: .infinity)
                            }.padding(.top, 2)
                        }.padding(16)
                    }
                    .navigationTitle(workout.name)
                } else {
                    Color.clear.onAppear { dismiss() }
                }
            }
            .background(Brand.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { SheetBackButton { dismiss() } } }
            .sheet(isPresented: $showEditor) {
                if let workout { CreateWorkoutView(editing: workout).environmentObject(store) }
            }
            .alert("¿Eliminar entreno?", isPresented: $confirmDelete) {
                Button("Eliminar", role: .destructive) { FX.warning(); store.deleteWorkout(workoutId); dismiss() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se quitará “\(workout?.name ?? "")” de tu lista de entrenos.")
            }
        }
    }

    private func weightText(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }
}

/// Lista de ejercicios de un entreno que **muestra las superseries**: los ejercicios
/// consecutivos con el mismo grupo van con una etiqueta «🔗 SUPERSERIE», una franja verde
/// a la izquierda que los une y una letra (A/B/C) por ejercicio del grupo.
struct WorkoutExerciseList: View {
    let exercises: [Exercise]

    private func decor(_ i: Int) -> (inSS: Bool, first: Bool, last: Bool, letter: String) {
        let g = exercises[i].supersetGroup
        let prevSame = i > 0 && g != nil && exercises[i - 1].supersetGroup == g
        let nextSame = i < exercises.count - 1 && g != nil && exercises[i + 1].supersetGroup == g
        let inSS = prevSame || nextSame
        var letter = ""
        if inSS {
            var start = i; while start > 0 && exercises[start - 1].supersetGroup == g { start -= 1 }
            letter = String(UnicodeScalar(65 + min(25, i - start))!)
        }
        return (inSS, inSS && !prevSame, inSS && !nextSame, letter)
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, ex in
                let d = decor(idx)
                VStack(spacing: 0) {
                    if d.first {
                        HStack(spacing: 5) {
                            Image(systemName: "link").font(.system(size: 10, weight: .heavy))
                            Text("SUPERSERIE").font(.system(size: 10, weight: .heavy)).tracking(0.6)
                            Text("· sin descanso entre ellos").font(.system(size: 10, weight: .semibold)).foregroundColor(Brand.soft)
                        }
                        .foregroundColor(Color(hex: "4b6211"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                    }
                    HStack(spacing: 12) {
                        // Visualización SOBRIA (el color vive solo en el editor de crear/editar);
                        // la superserie mantiene su letra verde porque es información, no adorno.
                        if d.inSS {
                            Text(d.letter).font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                                .frame(width: 24, height: 24).background(Brand.green).clipShape(Circle())
                        } else {
                            Text("\(idx + 1)").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.muted).frame(width: 24)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.x(ex.name)).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.ink)
                            Text("\(ex.sets)×\(ex.reps) · \(weightText(ex.weight)) kg").font(.footnote).foregroundColor(Brand.muted)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(d.inSS ? Brand.greenSoft.opacity(0.35) : Brand.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(d.inSS ? Brand.green.opacity(0.4) : Brand.line))
                }
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
    var linkNext = false   // superserie con el ejercicio siguiente
}

struct CreateWorkoutView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var editing: WorkoutTemplate? = nil
    @State private var name = ""
    @State private var group = ""
    @State private var drafts: [DraftExercise] = [DraftExercise()]
    @State private var didLoad = false
    @FocusState private var nameFocused: Bool
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
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    labeled("NOMBRE") {
                        TextField("Mi entreno", text: $name)
                            .focused($nameFocused)
                            .submitLabel(.next)
                            .padding(.horizontal, 12).frame(height: 46).background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(nameFocused ? Brand.greenSoft : Brand.line, lineWidth: nameFocused ? 1.5 : 1))
                    }

                    labeled("GRUPO") { groupField }

                    labeled("EJERCICIOS") {
                        VStack(spacing: 10) {
                            ForEach(Array(drafts.enumerated()), id: \.element.id) { idx, _ in
                                exerciseCard($drafts[idx], index: idx).id(drafts[idx].id)
                                if idx < drafts.count - 1 { supersetLink(idx) }
                            }
                            addButton
                        }
                    }

                    Button { save() } label: { Label("Guardar entreno", systemImage: "checkmark") }
                        .buttonStyle(PrimaryButtonStyle(enabled: canSave)).disabled(!canSave)
                }
                .padding(16)
                .padding(.bottom, 260)   // aire para que el teclado nunca tape la tarjeta activa
            }
            // Con el teclado abierto, desplaza SIEMPRE hasta la tarjeta que estás editando.
            .onChange(of: focusedExercise) { id in
                guard let id else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            }
            .background(Brand.bg)
            .navigationTitle(editing == nil ? "Crear entreno" : "Editar entreno").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { SheetBackButton { dismiss() } } }
            .onAppear {
                prefill()
                // Entreno nuevo: el cursor empieza en el Nombre para escribir directamente.
                if editing == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { nameFocused = true }
                }
            }
        }
    }

    private func prefill() {
        guard !didLoad, let e = editing else { didLoad = true; return }
        name = e.name
        group = (e.block == "Por defecto" || e.block == "Mis entrenos") ? "" : e.block
        drafts = e.exercises.map { DraftExercise(name: $0.name, sets: $0.sets, reps: $0.reps, weight: $0.weight) }
        // Reconstruye los enlaces de superserie: dos ejercicios consecutivos con el mismo grupo.
        for i in 0..<max(0, e.exercises.count - 1) where e.exercises[i].supersetGroup != nil
            && e.exercises[i].supersetGroup == e.exercises[i + 1].supersetGroup {
            drafts[i].linkNext = true
        }
        if drafts.isEmpty { drafts = [DraftExercise()] }
        didLoad = true
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(LocalizedStringKey(title)).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exerciseCard(_ draft: Binding<DraftExercise>, index: Int = 0) -> some View {
        let id = draft.wrappedValue.id
        let suggestions = focusedExercise == id ? searchExercises(draft.wrappedValue.name) : []
        let trimmed = draft.wrappedValue.name.trimmingCharacters(in: .whitespaces)
        // Si escribes un ejercicio que no está en el catálogo, ofrecemos usarlo como personalizado.
        let isCustom = focusedExercise == id && !trimmed.isEmpty
            && !exerciseCatalog.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                // Número del ejercicio: burbuja verde (color y orden de un vistazo).
                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                    .frame(width: 28, height: 28).background(Brand.green).clipShape(Circle())
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
            if isCustom || !suggestions.isEmpty {
                VStack(spacing: 0) {
                    if isCustom {
                        Button { focusedExercise = nil } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 14)).foregroundColor(Color(hex: "4b6211")).frame(width: 18)
                                Text("Usar “\(trimmed)”").font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.ink)
                                Spacer()
                                Text("nuevo").font(.system(size: 10, weight: .heavy)).foregroundColor(Brand.soft)
                                    .padding(.horizontal, 7).padding(.vertical, 3).background(Brand.chip).clipShape(Capsule())
                            }.padding(.horizontal, 12).frame(height: 44)
                        }
                        if !suggestions.isEmpty { Divider() }
                    }
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
                stepperBox("SERIES", icon: "square.stack.3d.up.fill", tint: Color(hex: "4b6211"), bg: Brand.greenSoft.opacity(0.35),
                           text: "\(draft.wrappedValue.sets)",
                           dec: { if draft.wrappedValue.sets > 1 { draft.wrappedValue.sets -= 1 } },
                           inc: { if draft.wrappedValue.sets < 10 { draft.wrappedValue.sets += 1 } })
                stepperBox("REPS", icon: "repeat", tint: Color(hex: "b8860b"), bg: Color(hex: "fff3d6"),
                           text: "\(draft.wrappedValue.reps)",
                           dec: { if draft.wrappedValue.reps > 1 { draft.wrappedValue.reps -= 1 } },
                           inc: { if draft.wrappedValue.reps < 50 { draft.wrappedValue.reps += 1 } })
                stepperBox("KG", icon: "scalemass.fill", tint: Color(hex: "3d7dbb"), bg: Color(hex: "e5f0fb"),
                           text: weightText(draft.wrappedValue.weight),
                           dec: { if draft.wrappedValue.weight >= 2.5 { draft.wrappedValue.weight -= 2.5 } },
                           inc: { draft.wrappedValue.weight += 2.5 })
            }
        }
        .padding(12).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
    }

    private func stepperBox(_ label: String, icon: String, tint: Color, bg: Color,
                            text: String, dec: @escaping () -> Void, inc: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9, weight: .heavy))
                Text(label).font(.system(size: 10, weight: .heavy))
            }.foregroundColor(tint)
            HStack(spacing: 8) {
                roundBtn("minus", action: dec)
                Text(text).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink).frame(minWidth: 30)
                roundBtn("plus", action: inc)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(bg).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func roundBtn(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { FX.selection(); action() }) {
            Image(systemName: icon).font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(width: 30, height: 30).background(Color.white).clipShape(Circle())
                .overlay(Circle().stroke(Brand.line))
        }
    }

    /// Conector entre dos ejercicios: enlázalos en superserie (se alternan sin descanso).
    private func supersetLink(_ idx: Int) -> some View {
        let linked = drafts[idx].linkNext
        return Button {
            FX.tap(); withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drafts[idx].linkNext.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: linked ? "link" : "link.badge.plus").font(.system(size: 11, weight: .heavy))
                Text(linked ? "Superserie" : "Enlazar en superserie").font(.system(size: 11, weight: .heavy))
            }
            .foregroundColor(linked ? Color(hex: "10150a") : Brand.soft)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(linked ? Brand.green : Brand.chip)
            .clipShape(Capsule())
            .overlay(alignment: .top) { Rectangle().fill(linked ? Brand.green : Brand.line).frame(width: 2, height: 8).offset(y: -8) }
            .overlay(alignment: .bottom) { Rectangle().fill(linked ? Brand.green : Brand.line).frame(width: 2, height: 8).offset(y: 8) }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private var addButton: some View {
        Button {
            let d = DraftExercise()
            drafts.append(d)
            // Deja el cursor listo en el nuevo ejercicio para escribir sin tener que tocar.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusedExercise = d.id }
        } label: {
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
        let day = name.isEmpty ? "Mi entreno" : name
        // Asigna un id de grupo de superserie a cada tramo de ejercicios unidos por `linkNext`.
        var groupOf: [UUID: String] = [:]
        var i = 0
        while i < drafts.count {
            if i < drafts.count - 1 && drafts[i].linkNext {
                let gid = "ss-\(Int.random(in: 0..<1_000_000))"
                groupOf[drafts[i].id] = gid
                var j = i
                while j < drafts.count - 1 && drafts[j].linkNext { groupOf[drafts[j + 1].id] = gid; j += 1 }
                i = j + 1
            } else { i += 1 }
        }
        let exercises = drafts
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { d in AppStore.makeExercise(day, d.name, d.sets, d.reps, d.weight, supersetGroup: groupOf[d.id]) }
        if let e = editing {
            store.updateWorkout(id: e.id, name: name, group: group, exercises: exercises)
        } else {
            store.addWorkout(name: name, group: group, exercises: exercises)
        }
        dismiss()
    }

    private func weightText(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }
}
