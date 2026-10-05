import SwiftUI
import PhotosUI

// MARK: - Momentos: historias de lo que estás haciendo en Bali (0034 + 0036)
//
// Las fotos del perfil dicen QUIÉN eres; un Momento dice QUÉ estás haciendo ahora.
//   · Se ven como círculos (no como otra foto): anillo de color si es de las últimas
//     24 h y no lo has visto; neutro si ya lo viste o es antiguo (fijado).
//   · Al tocarlo, visor a pantalla completa tipo historia.
//   · Duran 24 h salvo que su autor lo deje en el perfil («Keep on profile»).

struct Moment: Codable, Identifiable, Hashable {
    let id: String
    let user_id: String
    var media: MediaItem
    var title: String?
    var activity: String
    var area: String?
    var happened_at: String
    var note: String?
    var pinned: Bool
    var viewed: Bool?

    var date: Date { BackendDate.parse(happened_at) ?? Date() }
    var areaLabel: String? { area.flatMap(Neighborhood.init(rawValue:))?.label }
    var activityInfo: MomentActivity { MomentActivity(raw: activity) }
    var isRecent: Bool { Date().timeIntervalSince(date) < 24 * 3600 }

    /// «2h ago», «Today», «Yesterday», «Sep 28».
    var whenLabel: String {
        let s = Date().timeIntervalSince(date)
        if s < 60 * 60 { return String(format: L10n.t("%lldm ago"), max(1, Int(s / 60))) }
        if s < 12 * 3600 { return String(format: L10n.t("%lldh ago"), Int(s / 3600)) }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return L10n.t("Today") }
        if cal.isDateInYesterday(date) { return L10n.t("Yesterday") }
        let f = DateFormatter(); f.locale = L10n.locale; f.setLocalizedDateFormatFromTemplate("MMMd")
        return f.string(from: date)
    }
}

/// Tipo de actividad de un Momento.
struct MomentActivity: Hashable, Identifiable {
    let raw: String
    var id: String { raw }

    /// Las de la pantalla de crear (decisión 2026-10-05).
    static let choices: [MomentActivity] = ["surf", "gym", "running", "coffee", "padel", "yoga", "other"].map(MomentActivity.init(raw:))
    private static let extras: [String: (String, String)] = [
        "coffee": ("☕️", "Coffee"), "sunset": ("🌅", "Sunset"), "beach": ("🏖️", "Beach"),
        "explore": ("🧭", "Explore"), "other": ("✨", "Other"),
    ]

    var emoji: String {
        if let s = Sport.from(raw) { return s.emoji }
        return Self.extras[raw]?.0 ?? "✨"
    }
    var label: String {
        if raw == "running" { return L10n.t("Run") }
        if let s = Sport.from(raw) { return s.label }
        return L10n.t(Self.extras[raw]?.1 ?? raw.capitalized)
    }
    /// «SURF TODAY», «TRAINING TODAY» (la etiqueta del Circle).
    var todayBadge: String {
        switch raw {
        case "gym", "crossfit": return L10n.t("TRAINING TODAY")
        case "running": return L10n.t("RAN TODAY")
        case "other": return L10n.t("ACTIVE TODAY")
        default: return String(format: L10n.t("%@ TODAY"), label.uppercased())
        }
    }
}

struct MomentInsert: Encodable {
    let user_id: String
    let media: MediaItem
    let activity: String
    let area: String?
    let happened_at: String
    let note: String?
    let pinned: Bool
}

extension Backend {
    /// Momentos visibles de una persona (últimas 24 h + fijados), con «visto» para mí.
    func moments(of userId: String) async -> [Moment] {
        guard let client, client.auth.currentSession != nil else { return [] }
        struct P: Encodable { let target: String }
        return (try? await client.rpc("moments_of", params: P(target: userId.lowercased())).execute().value) ?? []
    }

    func markMomentViewed(_ id: String) async {
        guard let client else { return }
        struct P: Encodable { let moment: String }
        _ = try? await client.rpc("mark_moment_viewed", params: P(moment: id)).execute()
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

// MARK: - Anillo

/// El anillo de historias de Bali Circle: dorado-bronce cálido, nada chillón.
struct MomentRing: View {
    var active: Bool
    var lineWidth: CGFloat = 2.5
    static let gradient = AngularGradient(colors: [Color(hex: "e2c38f"), Color(hex: "b9864f"), Color(hex: "d9a46b"),
                                                   Color(hex: "f0d9ae"), Color(hex: "e2c38f")], center: .center)
    var body: some View {
        if active { Circle().stroke(Self.gradient, lineWidth: lineWidth) }
        else { Circle().stroke(Color.black.opacity(0.14), lineWidth: 1.2) }
    }
}

// MARK: - Fila de Momentos en el perfil

struct MomentsRow: View {
    @EnvironmentObject var store: AppStore
    let userId: String
    var userName: String
    var avatarURL: String?
    var isMe = false

    @State private var moments: [Moment] = []
    @State private var viewerStart: ViewerStart?
    @State private var composing = false

    struct ViewerStart: Identifiable { let id = UUID(); let index: Int }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MOMENTS").font(.system(size: 11, weight: .bold)).tracking(1.4).foregroundColor(Brand.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    if isMe {
                        Button { FX.tap(); composing = true } label: {
                            circleItem(label: L10n.t("New")) {
                                ZStack {
                                    Circle().fill(Brand.sand)
                                    Image(systemName: "plus").font(.system(size: 22, weight: .medium)).foregroundColor(Brand.ink)
                                }
                            } ring: { Circle().strokeBorder(Brand.sandDeep, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])) }
                        }.buttonStyle(.plain)
                    }
                    ForEach(Array(moments.enumerated()), id: \.element.id) { i, m in
                        Button { viewerStart = ViewerStart(index: i) } label: {
                            circleItem(label: m.isRecent ? m.activityInfo.label : m.whenLabel) {
                                RemoteFill(url: m.media.url).clipShape(Circle())
                            } ring: { MomentRing(active: m.isRecent && m.viewed != true && !isMe) }
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4).padding(.horizontal, 2)
            }
            if moments.isEmpty && !isMe {
                Text("No moments right now.").font(.footnote).foregroundColor(Brand.soft)
            } else if moments.isEmpty && isMe {
                Text("Share what you're up to — a surf, a session, a sunset. It disappears after 24 h.")
                    .font(.footnote).foregroundColor(Brand.muted)
            }
        }
        .task(id: userId) { await load() }
        .fullScreenCover(item: $viewerStart) { start in
            MomentViewer(moments: moments, startIndex: start.index, userName: userName, avatarURL: avatarURL,
                         isMe: isMe, onChange: { Task { await load() } })
        }
        .fullScreenCover(isPresented: $composing) {
            CreateMomentView(onPosted: { Task { await load() } }).environmentObject(store)
        }
    }

    private func load() async { moments = await Backend.shared.moments(of: userId) }

    private func circleItem<C: View, R: View>(label: String, @ViewBuilder content: () -> C, @ViewBuilder ring: () -> R) -> some View {
        VStack(spacing: 6) {
            content()
                .frame(width: 62, height: 62)
                .padding(4)
                .overlay(ring())
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(Brand.ink).lineLimit(1)
        }
        .frame(width: 74)
    }
}

// MARK: - Visor tipo historia

struct MomentViewer: View {
    @Environment(\.dismiss) private var dismiss
    let moments: [Moment]
    var startIndex: Int
    var userName: String
    var avatarURL: String?
    var isMe = false
    var onChange: () -> Void = {}

    @State private var index = 0
    @State private var progress: CGFloat = 0
    @State private var paused = false
    @State private var dragY: CGFloat = 0
    @State private var confirmDelete = false

    private var current: Moment? { moments.indices.contains(index) ? moments[index] : nil }
    private var duration: Double { current?.media.video_url != nil ? 10 : 5 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let m = current {
                MediaView(item: m.media)
                    .id(m.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .ignoresSafeArea(edges: .bottom)

                // Toques: izquierda = anterior, derecha = siguiente; mantener = pausa.
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle()).onTapGesture { go(-1) }
                        .frame(maxWidth: .infinity)
                    Color.clear.contentShape(Rectangle()).onTapGesture { go(1) }
                        .frame(maxWidth: .infinity)
                }
                .onLongPressGesture(minimumDuration: 0.2, pressing: { paused = $0 }, perform: {})

                VStack(spacing: 0) {
                    topBar(m)
                    Spacer()
                    infoOverlay(m)
                }
            }
        }
        .offset(y: max(0, dragY))
        .opacity(1 - Double(max(0, dragY)) / 600)
        .gesture(
            DragGesture()
                .onChanged { v in if v.translation.height > 0 { dragY = v.translation.height; paused = true } }
                .onEnded { v in
                    if v.translation.height > 120 { dismiss() }
                    else { withAnimation(.spring()) { dragY = 0 }; paused = false }
                }
        )
        .statusBarHidden()
        .onAppear { index = min(max(0, startIndex), max(0, moments.count - 1)); markViewed() }
        .task(id: index) {
            progress = 0
            let step = 0.05
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
                if paused { continue }
                progress += CGFloat(step / duration)
                if progress >= 1 { go(1); break }
            }
        }
        .confirmationDialog("Delete this moment?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let m = current { Task { await Backend.shared.deleteMoment(m.id); onChange(); dismiss() } }
            }
        }
    }

    private func topBar(_ m: Moment) -> some View {
        VStack(spacing: 10) {
            // Barras de progreso, una por Momento.
            HStack(spacing: 4) {
                ForEach(moments.indices, id: \.self) { i in
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.35))
                            Capsule().fill(Color.white)
                                .frame(width: g.size.width * (i < index ? 1 : i == index ? progress : 0))
                        }
                    }
                    .frame(height: 2.5)
                }
            }
            HStack(spacing: 10) {
                Group {
                    if let a = avatarURL { RemoteFill(url: a) } else { Brand.sand }
                }
                .frame(width: 34, height: 34).clipShape(Circle())
                Text(userName).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Text(m.whenLabel).font(.system(size: 14)).foregroundColor(.white.opacity(0.75))
                Spacer()
                if isMe {
                    Menu {
                        Button { Task { try? await Backend.shared.setMomentPinned(m.id, !m.pinned); onChange() } } label: {
                            Label(m.pinned ? "Remove from profile" : "Keep on profile", systemImage: m.pinned ? "pin.slash" : "pin")
                        }
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 36, height: 36)
                    }
                }
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 12).padding(.top, 8)
        .shadow(color: .black.opacity(0.35), radius: 4)
    }

    /// Qué hizo, dónde y cuándo — discreto, sin tapar la imagen.
    private func infoOverlay(_ m: Moment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(m.activityInfo.emoji) \(m.activityInfo.label)")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.ink)
                    .padding(.horizontal, 11).frame(height: 30).background(Color.white.opacity(0.92)).clipShape(Capsule())
                if let a = m.areaLabel {
                    Label(a, systemImage: "mappin").font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                }
            }
            if let n = m.note, !n.isEmpty {
                Text(n).font(.system(size: 18, weight: .medium)).foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18).padding(.top, 40).padding(.bottom, 26)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .bottom))
    }

    private func go(_ d: Int) {
        let n = index + d
        if n < 0 { progress = 0; return }
        if n >= moments.count { dismiss(); return }
        index = n
        markViewed()
    }

    private func markViewed() {
        guard let m = current, !isMe else { return }
        Task { await Backend.shared.markMomentViewed(m.id) }
    }
}

// MARK: - Crear un Momento

struct CreateMomentView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var onPosted: () -> Void = {}

    @State private var pick: PhotosPickerItem?
    @State private var media: MediaItem?
    @State private var uploading = false
    @State private var activity: String?
    @State private var area: String?
    @State private var note = ""
    @State private var posting = false
    @State private var error: String?

    private var canPost: Bool { media != nil && activity != nil && !posting && !uploading }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        mediaPicker

                        field("WHAT ARE YOU UP TO?") {
                            WrapLayout(spacing: 6) {
                                ForEach(MomentActivity.choices) { a in
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

                        field("SAY SOMETHING (OPTIONAL)") {
                            TextField("Perfect waves this morning", text: $note, axis: .vertical)
                                .lineLimit(1...3).font(.system(size: 16))
                                .padding(12).background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Brand.line))
                                .onChange(of: note) { v in if v.count > 120 { note = String(v.prefix(120)) } }
                            Text("\(note.count)/120").font(.caption2).foregroundColor(Brand.soft).frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        Label("Disappears after 24 h. You can keep it on your profile.", systemImage: "clock")
                            .font(.footnote).foregroundColor(Brand.muted)
                        if let error { Text(error).font(.caption).foregroundColor(Brand.redText) }
                        Color.clear.frame(height: 80)
                    }
                    .padding(18)
                }
                // CTA fijo abajo.
                Button { Task { await post() } } label: {
                    if posting { ProgressView().tint(Brand.onAccent) } else { Text("Share moment") }
                }
                .buttonStyle(PrimaryButtonStyle(enabled: canPost))
                .disabled(!canPost)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(Brand.bg.opacity(0.97).ignoresSafeArea(edges: .bottom))
            }
            .background(Brand.bg)
            .navigationTitle("New moment").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark").foregroundColor(Brand.ink) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") { Task { await post() } }.fontWeight(.semibold).disabled(!canPost)
                }
            }
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

    /// Vista previa vertical (formato historia), para cambiar o quitar el archivo.
    private var mediaPicker: some View {
        PhotosPicker(selection: $pick, matching: .any(of: [.images, .videos, .livePhotos]), photoLibrary: .shared()) {
            Color.clear
                .frame(maxWidth: .infinity).frame(height: 380)
                .overlay {
                    if let media { MediaView(item: media) }
                    else {
                        ZStack {
                            Brand.surface
                            VStack(spacing: 10) {
                                if uploading { ProgressView().tint(Brand.ink) }
                                else {
                                    Image(systemName: "camera.on.rectangle").font(.system(size: 36, weight: .light))
                                    Text("Add a photo or video").font(.system(size: 15, weight: .medium))
                                }
                            }.foregroundColor(Brand.muted)
                        }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if media != nil {
                        Button { media = nil; pick = nil } label: {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                .frame(width: 32, height: 32).background(.black.opacity(0.45)).clipShape(Circle())
                        }.padding(10)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Brand.line, style: StrokeStyle(lineWidth: 1, dash: media == nil ? [6, 5] : [])))
        }
        .disabled(uploading)
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
                .padding(.horizontal, 12).frame(height: 36)
                .background(on ? Brand.sand : Color.white).clipShape(Capsule())
                .overlay(Capsule().stroke(on ? Brand.ink : Brand.line, lineWidth: on ? 1.5 : 1))
        }.buttonStyle(.plain)
    }

    private func post() async {
        guard let media, let activity, let uid = await Backend.shared.currentUserIdAsync() else { return }
        posting = true; error = nil
        let t = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await Backend.shared.createMoment(MomentInsert(
                user_id: uid.uuidString.lowercased(), media: media, activity: activity, area: area,
                happened_at: BackendDate.iso.string(from: Date()), note: t.isEmpty ? nil : t, pinned: false))
            FX.success()
            onPosted(); dismiss()
        } catch {
            print("[Moments] publicar falló:", error)
            self.error = L10n.t("Couldn't share. Try again.")
        }
        posting = false
    }
}
