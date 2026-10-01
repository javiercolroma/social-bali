import SwiftUI
import PhotosUI

// MARK: - Momentos: el perfil como identidad viva (migración 0034)
//
// Cada actividad compartida es un post LIGERO que extiende el perfil — no un feed:
// siempre 4:5, poco texto, los mismos chips y la misma tipografía que el perfil.
// El perfil tiene 3 capas: identidad fija · Highlights (fijados) · Recent.

struct Moment: Codable, Identifiable, Hashable {
    let id: String
    let user_id: String
    var media: MediaItem
    var title: String
    var activity: String
    var area: String?
    var happened_at: String
    var note: String?
    var pinned: Bool

    var date: Date { BackendDate.parse(happened_at) ?? Date() }
    var areaLabel: String? { area.flatMap(Neighborhood.init(rawValue:))?.label }
    var activityInfo: MomentActivity { MomentActivity(raw: activity) }

    /// «Today», «Yesterday», «Sep 28».
    var whenLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return L10n.t("Today") }
        if cal.isDateInYesterday(date) { return L10n.t("Yesterday") }
        let f = DateFormatter(); f.locale = L10n.locale; f.setLocalizedDateFormatFromTemplate("MMMd")
        return f.string(from: date)
    }
}

/// Tipo de actividad: los deportes del club + planes de Bali que no son deporte.
struct MomentActivity: Hashable, Identifiable {
    let raw: String
    var id: String { raw }

    static let extras: [(String, String, String)] = [
        ("coffee", "☕️", "Coffee"), ("sunset", "🌅", "Sunset"), ("beach", "🏖️", "Beach"), ("explore", "🧭", "Explore"),
    ]

    var emoji: String {
        if let s = Sport.from(raw) { return s.emoji }
        return Self.extras.first { $0.0 == raw }?.1 ?? "✨"
    }
    var label: String {
        if let s = Sport.from(raw) { return s.label }
        return L10n.t(Self.extras.first { $0.0 == raw }?.2 ?? raw.capitalized)
    }
    /// «SURF TODAY», «TRAINING TODAY» (la etiqueta del Circle).
    var todayBadge: String {
        switch raw {
        case "gym", "crossfit": return L10n.t("TRAINING TODAY")
        case "running": return L10n.t("RAN TODAY")
        default: return String(format: L10n.t("%@ TODAY"), label.uppercased())
        }
    }

    /// Para elegir al publicar: primero mis deportes, después el resto y los planes.
    static func choices(mine: [Sport]) -> [MomentActivity] {
        let firsts = mine.map(\.rawValue)
        let rest = [Sport.surf, .gym, .running, .yoga, .padel, .muayThai, .freediving, .hiking].map(\.rawValue).filter { !firsts.contains($0) }
        return (firsts + rest + extras.map(\.0)).map(MomentActivity.init(raw:))
    }
}

struct MomentInsert: Encodable {
    let user_id: String
    let media: MediaItem
    let title: String
    let activity: String
    let area: String?
    let happened_at: String
    let note: String?
    let pinned: Bool
}

extension Backend {
    func fetchMoments(of userId: String) async -> [Moment] {
        guard let client else { return [] }
        return (try? await client.from("moments").select()
            .eq("user_id", value: userId.lowercased())
            .order("happened_at", ascending: false).limit(30)
            .execute().value) ?? []
    }

    func createMoment(_ m: MomentInsert) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.from("moments").insert(m).execute()
    }

    func setMomentPinned(_ id: String, _ pinned: Bool) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.from("moments").update(["pinned": pinned]).eq("id", value: id).execute()
    }

    func deleteMoment(_ id: String) async {
        guard let client else { return }
        _ = try? await client.from("moments").delete().eq("id", value: id).execute()
    }
}

// MARK: - Sección del perfil: Highlights + Recent

struct MomentsSection: View {
    @EnvironmentObject var store: AppStore
    let userId: String
    var isMe = false
    @State private var moments: [Moment] = []
    @State private var open: Moment?
    @State private var composing = false
    @State private var loaded = false

    private var highlights: [Moment] { moments.filter(\.pinned) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if isMe {
                Button { FX.tap(); composing = true } label: {
                    Label("Share a moment", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            if !highlights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("HIGHLIGHTS")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(highlights) { m in
                                Button { open = m } label: { highlight(m) }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            if !moments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("RECENT")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(moments.prefix(8)) { m in
                            Button { open = m } label: { MomentCard(moment: m) }.buttonStyle(.plain)
                        }
                    }
                }
            } else if isMe && loaded {
                Text("Share what you're up to — a surf, a session, a sunset. It brings your profile to life.")
                    .font(.footnote).foregroundColor(Brand.muted)
            }
        }
        .task(id: userId) { await load() }
        .sheet(item: $open) { m in
            MomentDetail(moment: m, isMe: isMe, onChange: { Task { await load() } })
        }
        .sheet(isPresented: $composing) {
            NewMomentSheet(onPosted: { Task { await load() } }).environmentObject(store)
        }
    }

    private func load() async {
        moments = await Backend.shared.fetchMoments(of: userId)
        loaded = true
    }

    private func sectionTitle(_ t: LocalizedStringKey) -> some View {
        Text(t).font(.system(size: 11, weight: .bold)).tracking(1.4).foregroundColor(Brand.muted)
    }

    /// Highlight: círculo con la imagen y la actividad debajo (como historias destacadas).
    private func highlight(_ m: Moment) -> some View {
        VStack(spacing: 6) {
            RemoteFill(url: m.media.url)
                .frame(width: 66, height: 66).clipShape(Circle())
                .overlay(Circle().stroke(Brand.sandDeep, lineWidth: 2).padding(-4))
                .padding(4)
            Text("\(m.activityInfo.emoji) \(m.activityInfo.label)").font(.system(size: 11, weight: .medium))
                .foregroundColor(Brand.ink).lineLimit(1)
        }
        .frame(width: 82)
    }
}

/// Tarjeta de un momento: siempre 4:5, chip de actividad, título y «zona · cuándo».
struct MomentCard: View {
    let moment: Moment

    var body: some View {
        Color.clear
            .aspectRatio(4 / 5, contentMode: .fit)
            .overlay(MediaView(item: moment.media))
            .overlay(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom))
            .overlay(alignment: .topLeading) {
                Text("\(moment.activityInfo.emoji) \(moment.activityInfo.label)")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(Brand.ink)
                    .padding(.horizontal, 8).frame(height: 22).background(Color.white.opacity(0.88)).clipShape(Capsule())
                    .padding(8)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(moment.title).font(.display(16)).lineLimit(1)
                    Text([moment.areaLabel, moment.whenLabel].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11, weight: .medium)).opacity(0.85)
                }
                .foregroundColor(.white).shadow(color: .black.opacity(0.3), radius: 3)
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Un momento en grande. Si es tuyo: fijar como Highlight o borrar.
struct MomentDetail: View {
    @Environment(\.dismiss) private var dismiss
    let moment: Moment
    var isMe = false
    var onChange: () -> Void = {}
    @State private var confirmDelete = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Color.clear.aspectRatio(4 / 5, contentMode: .fit)
                    .overlay(MediaView(item: moment.media))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                HStack(spacing: 8) {
                    Text("\(moment.activityInfo.emoji) \(moment.activityInfo.label)")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.ink)
                        .padding(.horizontal, 10).frame(height: 28).background(Brand.sand).clipShape(Capsule())
                    Text([moment.areaLabel, moment.whenLabel].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 14)).foregroundColor(Brand.muted)
                }
                Text(moment.title).font(.display(28)).foregroundColor(Brand.ink)
                if let n = moment.note, !n.isEmpty {
                    Text(n).font(.system(size: 17)).foregroundColor(Brand.ink).fixedSize(horizontal: false, vertical: true)
                }
                if let error { Text(error).font(.caption).foregroundColor(Brand.redText) }
                if isMe {
                    HStack(spacing: 10) {
                        Button { Task { await togglePin() } } label: {
                            Label(moment.pinned ? "Remove from highlights" : "Add to highlights",
                                  systemImage: moment.pinned ? "star.slash" : "star")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button { confirmDelete = true } label: {
                            Image(systemName: "trash").font(.system(size: 17)).foregroundColor(Brand.redText)
                                .frame(width: 54, height: 54).background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(18)
        }
        .background(Brand.bg)
        .confirmationDialog("Delete this moment?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await Backend.shared.deleteMoment(moment.id); onChange(); dismiss() }
            }
        }
    }

    private func togglePin() async {
        do {
            try await Backend.shared.setMomentPinned(moment.id, !moment.pinned)
            onChange(); dismiss()
        } catch {
            self.error = L10n.t("You can pin up to 6 highlights.")
        }
    }
}

// MARK: - Publicar un momento

struct NewMomentSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var onPosted: () -> Void = {}

    @State private var pick: PhotosPickerItem?
    @State private var media: MediaItem?
    @State private var uploading = false
    @State private var title = ""
    @State private var activity: String?
    @State private var area: String?
    @State private var when = 0          // 0 hoy · 1 ayer · 2 otro día
    @State private var otherDay = Date()
    @State private var note = ""
    @State private var pinned = false
    @State private var posting = false
    @State private var error: String?

    private var canPost: Bool {
        media != nil && activity != nil && !title.trimmingCharacters(in: .whitespaces).isEmpty && !posting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PhotosPicker(selection: $pick, matching: .any(of: [.images, .videos, .livePhotos]), photoLibrary: .shared()) {
                        Color.clear.aspectRatio(4 / 5, contentMode: .fit)
                            .overlay {
                                if let media { MediaView(item: media) }
                                else {
                                    ZStack {
                                        Brand.surface
                                        VStack(spacing: 8) {
                                            if uploading { ProgressView().tint(Brand.ink) }
                                            else {
                                                Image(systemName: "photo.badge.plus").font(.system(size: 34, weight: .light))
                                                Text("Add a photo or video").font(.system(size: 15, weight: .medium))
                                            }
                                        }.foregroundColor(Brand.muted)
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Brand.line, style: StrokeStyle(lineWidth: 1, dash: media == nil ? [6, 5] : [])))
                    }
                    .disabled(uploading)

                    field("TITLE") {
                        TextField("Dawn patrol at Uluwatu", text: $title)
                            .font(.display(20)).foregroundColor(Brand.ink)
                            .onChange(of: title) { v in if v.count > 60 { title = String(v.prefix(60)) } }
                    }

                    field("WHAT") {
                        WrapLayout(spacing: 6) {
                            ForEach(MomentActivity.choices(mine: store.profile.sportList)) { a in
                                chip("\(a.emoji) \(a.label)", on: activity == a.raw) { activity = a.raw }
                            }
                        }
                    }

                    field("WHERE") {
                        WrapLayout(spacing: 6) {
                            ForEach(Neighborhood.picker) { n in
                                chip(n.label, on: area == n.rawValue) { area = (area == n.rawValue) ? nil : n.rawValue }
                            }
                        }
                    }

                    field("WHEN") {
                        HStack(spacing: 6) {
                            chip(L10n.t("Today"), on: when == 0) { when = 0 }
                            chip(L10n.t("Yesterday"), on: when == 1) { when = 1 }
                            chip(L10n.t("Another day"), on: when == 2) { when = 2 }
                        }
                        if when == 2 {
                            DatePicker("", selection: $otherDay, in: ...Date(), displayedComponents: .date).labelsHidden()
                        }
                    }

                    field("NOTE") {
                        TextField("Optional — a line about it", text: $note, axis: .vertical)
                            .lineLimit(1...3).font(.system(size: 16))
                            .onChange(of: note) { v in if v.count > 140 { note = String(v.prefix(140)) } }
                    }

                    Toggle(isOn: $pinned) { Label("Add to highlights", systemImage: "star") }
                        .tint(Brand.accent).font(.system(size: 15, weight: .medium))

                    if let error { Text(error).font(.caption).foregroundColor(Brand.redText) }

                    Button { Task { await post() } } label: {
                        if posting { ProgressView().tint(Brand.onAccent) } else { Text("Share") }
                    }
                    .buttonStyle(PrimaryButtonStyle(enabled: canPost))
                    .disabled(!canPost)
                }
                .padding(18)
            }
            .background(Brand.bg)
            .navigationTitle("New moment").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { if area == nil { area = store.profile.neighborhood } }
            .onChange(of: pick) { item in
                guard let item else { return }
                Task {
                    uploading = true; error = nil
                    do { media = try await MediaUploader.upload(item) }
                    catch { self.error = (error as? LocalizedError)?.errorDescription ?? L10n.t("Couldn't upload. Try again.") }
                    uploading = false
                }
            }
        }
    }

    private func field<C: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .bold)).tracking(1.4).foregroundColor(Brand.muted)
            content()
        }
    }

    private func chip(_ text: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button { FX.selection(); action() } label: {
            Text(text).font(.system(size: 14, weight: .medium)).foregroundColor(Brand.ink)
                .padding(.horizontal, 12).frame(height: 34)
                .background(on ? Brand.sand : Color.white).clipShape(Capsule())
                .overlay(Capsule().stroke(on ? Brand.ink : Brand.line, lineWidth: on ? 1.5 : 1))
        }.buttonStyle(.plain)
    }

    private func post() async {
        guard let media, let activity, let uid = await Backend.shared.currentUserIdAsync() else { return }
        posting = true; error = nil
        let cal = Calendar.current
        let date = when == 0 ? Date() : when == 1 ? (cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()) : otherDay
        let t = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await Backend.shared.createMoment(MomentInsert(
                user_id: uid.uuidString.lowercased(), media: media, title: title.trimmingCharacters(in: .whitespaces),
                activity: activity, area: area, happened_at: BackendDate.iso.string(from: date),
                note: t.isEmpty ? nil : t, pinned: pinned))
            FX.success()
            onPosted(); dismiss()
        } catch {
            print("[Moments] publicar falló:", error)
            self.error = pinned ? L10n.t("You can pin up to 6 highlights.") : L10n.t("Couldn't share. Try again.")
        }
        posting = false
    }
}
