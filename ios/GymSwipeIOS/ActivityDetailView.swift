import SwiftUI
import PhotosUI

struct ActivityData {
    let authorName: String
    let avatarPhoto: Data?
    let avatarEmoji: String
    let flag: String
    let location: String
    let date: Date
    var title: String
    var note: String
    var photo: Data?
    var photoURL: String? = nil
    let elapsed: Int
    let exercises: Int
    let sets: Int
    let volume: Double
    let items: [SessionExercise]
    var avgHeartRate: Int? = nil
    var maxHeartRate: Int? = nil
    var score: Int = 0   // Gym Score del autor, para el badge del avatar
    var xp: Int = 0      // XP ganado en la sesión (0 = no mostrar, p. ej. posts de otros)
    var insights: [ProgressInsight] = []   // avances vs. historial (solo en sesiones propias)
    /// id de la sesión SI es mía (editable/eliminable). nil = ajena → sin menú de edición.
    var sessionId: String? = nil
}

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let item: ActivityData

    // Copia mutable para reflejar las ediciones al instante (sin cerrar el detalle).
    @State private var data: ActivityData
    @State private var showEdit = false
    @State private var showDelete = false
    @State private var showFullPhoto = false
    @State private var showAddMedia = false
    @State private var addMediaItem: PhotosPickerItem?

    init(item: ActivityData) {
        self.item = item
        _data = State(initialValue: item)
    }

    private var hasMedia: Bool { data.photo != nil || (data.photoURL?.isEmpty == false) }
    private var isMine: Bool { data.sessionId != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Con foto → protagonista arriba (elástica + tocar para verla completa).
                    // Sin foto → directo a la info, sin hueco reservado.
                    if hasMedia {
                        StretchyWorkoutPhoto(data: data.photo, url: data.photoURL, baseHeight: 440) {
                            FX.tap(); showFullPhoto = true
                        }
                    }
                    VStack(spacing: 14) {
                        author
                        Text(data.title).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !data.note.isEmpty {
                            Text(data.note).font(.system(size: 15)).foregroundColor(Color(hex: "2c3127"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        WorkoutInsightsStrip(insights: data.insights)
                        HStack(spacing: 10) {
                            metric(durationText(data.elapsed), "Tiempo", "clock")
                            metric("\(data.sets)", "Series", "checkmark.circle")
                            metric("\(data.exercises)", "Ejercicios", "list.bullet")
                            if data.xp > 0 { metric("+\(data.xp)", "XP", "star.fill") }
                        }
                        if let avg = data.avgHeartRate {
                            HStack(spacing: 10) {
                                metric("\(avg) ppm", "FC media", "heart.fill")
                                metric("\(data.maxHeartRate ?? avg) ppm", "FC máx", "heart.fill")
                            }
                        }
                        if !data.items.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("EJERCICIOS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                                ForEach(Array(data.items.enumerated()), id: \.offset) { _, ex in
                                    exerciseCard(ex)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .coordinateSpace(name: "activityScroll")   // línea base de la foto elástica (reposo = 0)
            .background(Brand.bg)
            .navigationTitle("Actividad").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetBackButton { dismiss() } }
                if isMine {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button { FX.tap(); showEdit = true } label: { Label("Editar actividad", systemImage: "pencil") }
                            Button { FX.tap(); showAddMedia = true } label: { Label("Añadir multimedia", systemImage: "photo.badge.plus") }
                            Button(role: .destructive) { FX.tap(); showDelete = true } label: { Label("Eliminar actividad", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundColor(Brand.ink)
                                .frame(width: 34, height: 34).background(Brand.chip).clipShape(Circle())
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showFullPhoto) {
            FullScreenPhotoView(data: data.photo, url: data.photoURL) { showFullPhoto = false }
        }
        .sheet(isPresented: $showEdit) {
            EditActivitySheet(data: data) { name, note, photo in
                applyEdit(name: name, note: note, photo: photo)
            }
        }
        // Añadir multimedia: acción rápida (picker directo, sin abrir la edición completa).
        .photosPicker(isPresented: $showAddMedia, selection: $addMediaItem, matching: .images)
        .onChange(of: addMediaItem) { newItem in
            guard let newItem else { return }
            Task {
                if let d = try? await newItem.loadTransferable(type: Data.self) {
                    applyEdit(name: data.title, note: data.note, photo: d)
                }
                addMediaItem = nil
            }
        }
        .confirmationDialog("¿Eliminar esta actividad?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let id = data.sessionId { store.deleteSession(id) }
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var author: some View {
        HStack(spacing: 11) {
            ZStack(alignment: .bottomTrailing) {
                if let d = data.avatarPhoto, let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFill().frame(width: 46, height: 46).clipShape(Circle())
                } else {
                    Avatar(emoji: data.avatarEmoji, size: 46)
                }
                ScoreBadge(score: data.score, avatarSize: 46)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(data.authorName).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                HStack(spacing: 5) {
                    Text(relativeTime(data.date))
                    if !data.location.isEmpty {
                        Text("·"); Image(systemName: "mappin.and.ellipse").font(.system(size: 9)); Text(data.location)
                    }
                }.font(.caption).foregroundColor(Brand.soft)
            }
            Spacer()
        }
    }

    /// Aplica una edición: persiste en el store y refleja el cambio en la vista al instante.
    /// Solo actualiza la vista si el store guardó de verdad (si no, no finge un guardado).
    private func applyEdit(name: String, note: String, photo: Data?) {
        guard let id = data.sessionId else { return }
        guard store.updateSession(id: id, name: name, note: note, photo: photo) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { data.title = trimmed }
        data.note = note.trimmingCharacters(in: .whitespaces)
        if let photo { data.photo = photo; data.photoURL = nil }
    }

    private func metric(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(Color(hex: "6ea300"))
            Text(value).font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
            Text(LocalizedStringKey(label)).font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Per-set list for an exercise: SOLO las series hechas. Usa los logs (que solo
    /// contienen las series completadas); si no hay logs, usa el conteo de hechas.
    private func expandedSets(_ ex: SessionExercise) -> [SetLog] {
        if let logs = ex.logs, !logs.isEmpty { return logs }
        return Array(repeating: SetLog(reps: ex.reps, weight: ex.weight), count: max(0, ex.sets))
    }

    private func exerciseCard(_ ex: SessionExercise) -> some View {
        let sets = expandedSets(ex)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.x(ex.name)).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                Spacer()
                Text("\(sets.count) \(sets.count == 1 ? "serie" : "series")")
                    .font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                    .padding(.horizontal, 9).padding(.vertical, 4).background(Brand.greenSoft).clipShape(Capsule())
            }
            VStack(spacing: 0) {
                ForEach(Array(sets.enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Brand.green).frame(width: 24, height: 24)
                            Text("\(i + 1)").font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                        }
                        Text("\(s.reps) reps").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "2c3127"))
                        Spacer()
                        Text("\(fmt(s.weight)) kg").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    }
                    .padding(.vertical, 8)
                    if i < sets.count - 1 { Divider() }
                }
            }
        }
        .padding(14).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
    }

    private func fmt(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }

    private func durationText(_ s: Int) -> String {
        let m = s / 60
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(max(1, m)) min"
    }
}

/// Editar una actividad propia: nombre, descripción y foto (cambiar/añadir).
private struct EditActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let data: ActivityData
    var onSave: (String, String, Data?) -> Void

    @State private var name: String
    @State private var note: String
    @State private var pickedItem: PhotosPickerItem?
    @State private var newPhoto: Data?

    init(data: ActivityData, onSave: @escaping (String, String, Data?) -> Void) {
        self.data = data
        self.onSave = onSave
        _name = State(initialValue: data.title)
        _note = State(initialValue: data.note)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("FOTO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    photoPreview
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label(hasAnyPhoto ? "Cambiar foto" : "Añadir foto", systemImage: "photo.badge.plus")
                            .font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Text("NOMBRE").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    TextField("Nombre de la actividad", text: $name)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 14).frame(height: 48).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
                        .onChange(of: name) { v in if v.count > 60 { name = String(v.prefix(60)) } }

                    Text("DESCRIPCIÓN").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    TextField("Añade una descripción…", text: $note, axis: .vertical)
                        .font(.system(size: 15)).lineLimit(2...5)
                        .padding(14).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
                        .onChange(of: note) { v in if v.count > 300 { note = String(v.prefix(300)) } }
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Editar actividad").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { FX.tap(); onSave(name, note, newPhoto); dismiss() }
                        .font(.system(size: 16, weight: .heavy))
                }
            }
            .onChange(of: pickedItem) { it in
                guard let it else { return }
                Task { newPhoto = try? await it.loadTransferable(type: Data.self) }
            }
        }
    }

    private var hasAnyPhoto: Bool { newPhoto != nil || data.photo != nil || (data.photoURL?.isEmpty == false) }

    @ViewBuilder private var photoPreview: some View {
        let h: CGFloat = 240
        if let d = newPhoto ?? data.photo, let ui = UIImage(data: d) {
            ZStack { Color.white; Image(uiImage: ui).resizable().scaledToFit() }
                .frame(maxWidth: .infinity).frame(height: h)
                .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
        } else if let u = data.photoURL, let link = URL(string: u) {
            ZStack { Color.white; AsyncImage(url: link) { img in img.resizable().scaledToFit() } placeholder: { ProgressView() } }
                .frame(maxWidth: .infinity).frame(height: h)
                .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
        } else {
            RoundedRectangle(cornerRadius: 12).fill(Brand.chip).frame(height: h)
                .overlay(VStack(spacing: 6) {
                    Image(systemName: "photo").font(.system(size: 30)).foregroundColor(Brand.soft)
                    Text("Sin foto").font(.footnote).foregroundColor(Brand.muted)
                })
        }
    }
}
