import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import UniformTypeIdentifiers

// MARK: - Fotos y vídeos del perfil (migración 0029, `profiles.media`)
//
// El perfil es una GALERÍA densa: hasta 9 fotos, vídeos cortos o Live Photos. Cada
// elemento guarda siempre una imagen (`url`) — la foto, o el primer fotograma del vídeo —
// y, si se mueve, el vídeo (`video_url`). `w`/`h` permiten la rejilla tipo Pinterest
// (alturas distintas) sin descargar nada antes de pintarla.

struct MediaItem: Codable, Hashable, Identifiable {
    var kind: String          // "photo" | "video" | "live"
    var url: String           // imagen (foto o portada del vídeo)
    var video_url: String?    // vídeo para "video" y "live"
    var w: Int?
    var h: Int?

    var id: String { url }
    var moves: Bool { video_url != nil }
    /// Ancho / alto, limitado para que ninguna celda quede ridícula en la rejilla.
    var aspect: CGFloat {
        guard let w, let h, w > 0, h > 0 else { return 4 / 5 }
        return min(max(CGFloat(w) / CGFloat(h), 0.6), 1.25)
    }
}

enum MediaRules {
    static let max = 9
    static let minToJoin = 3
    static let maxVideoSeconds: Double = 30
}

// MARK: - Pintar

/// Una foto, o un vídeo/Live Photo en bucle y SIN sonido sobre su portada.
struct MediaView: View {
    let item: MediaItem
    var autoplay = true

    var body: some View {
        ZStack {
            RemoteFill(url: item.url)
            if autoplay, let v = item.video_url, let u = URL(string: v) {
                LoopingVideo(url: u).allowsHitTesting(false)
            }
        }
        .clipped()
    }
}

/// Vídeo en bucle, silenciado y sin controles (el «dinamismo» de la galería).
struct LoopingVideo: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.play(url)
        return v
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        if uiView.current != url { uiView.play(url) }
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: ()) { uiView.stop() }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private(set) var current: URL?

        func play(_ url: URL) {
            current = url
            let item = AVPlayerItem(url: url)
            let p = AVQueuePlayer()
            p.isMuted = true
            p.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: p, templateItem: item)
            player = p
            (layer as? AVPlayerLayer)?.player = p
            (layer as? AVPlayerLayer)?.videoGravity = .resizeAspectFill
            p.play()
        }

        func stop() { player?.pause(); player = nil; looper = nil }
    }
}

/// Rejilla tipo Pinterest: dos columnas y cada pieza va a la más corta, con su altura.
struct Masonry: Layout {
    var columns = 2
    var spacing: CGFloat = 8
    /// Ancho/alto de cada subvista, en el mismo orden.
    var aspects: [CGFloat]
    /// Alto fijo extra por pieza (p. ej. el nombre bajo la foto en el Circle).
    var extraHeight: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let frames = layout(width: width, count: subviews.count)
        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = layout(width: bounds.width, count: subviews.count)
        for (i, s) in subviews.enumerated() {
            let f = frames[i]
            s.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), proposal: ProposedViewSize(f.size))
        }
    }

    private func layout(width: CGFloat, count: Int) -> [CGRect] {
        let colW = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        var heights = Array(repeating: CGFloat(0), count: columns)
        var out: [CGRect] = []
        for i in 0..<count {
            let a = i < aspects.count ? aspects[i] : 4 / 5
            let h = colW / max(a, 0.1) + extraHeight
            let c = heights.firstIndex(of: heights.min() ?? 0) ?? 0
            out.append(CGRect(x: CGFloat(c) * (colW + spacing), y: heights[c], width: colW, height: h))
            heights[c] += h + spacing
        }
        return out
    }
}

/// Galería de un perfil (sin la primera pieza, que va arriba en grande).
struct MediaGallery: View {
    let items: [MediaItem]
    var body: some View {
        if !items.isEmpty {
            Masonry(aspects: items.map(\.aspect)) {
                ForEach(items) { m in
                    MediaView(item: m)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Subir

/// Prepara un elemento elegido en la galería del móvil y lo sube a `media/<uid>/…`.
enum MediaUploader {
    enum Failure: LocalizedError {
        case unreadable, tooLong
        var errorDescription: String? {
            switch self {
            case .unreadable: return "That file couldn't be read."
            case .tooLong: return "Videos can be up to 30 seconds."
            }
        }
    }

    static func upload(_ item: PhotosPickerItem) async throws -> MediaItem {
        let types = item.supportedContentTypes
        if types.contains(where: { $0.conforms(to: .livePhoto) }),
           let live = try? await item.loadTransferable(type: PHLivePhoto.self),
           let pair = try? await livePhotoFiles(live) {
            return try await uploadMoving(kind: "live", stillData: pair.still, videoURL: pair.video)
        }
        if types.contains(where: { $0.conforms(to: .movie) }) {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else { throw Failure.unreadable }
            let still = try await poster(of: movie.url)
            return try await uploadMoving(kind: "video", stillData: still, videoURL: movie.url)
        }
        guard let data = try await item.loadTransferable(type: Data.self) else { throw Failure.unreadable }
        let jpeg = compressedImageData(data)
        let size = UIImage(data: jpeg)?.size ?? .zero
        let url = try await Backend.shared.uploadMedia(jpeg, ext: "jpg", contentType: "image/jpeg")
        return MediaItem(kind: "photo", url: url, video_url: nil, w: Int(size.width), h: Int(size.height))
    }

    /// Vídeo/Live: se recomprime a ~720p (mp4) y se sube junto a su portada.
    static func uploadMoving(kind: String, stillData: Data, videoURL: URL) async throws -> MediaItem {
        let asset = AVURLAsset(url: videoURL)
        let seconds = try await asset.load(.duration).seconds
        if seconds > MediaRules.maxVideoSeconds + 0.5 { throw Failure.tooLong }
        let mp4 = try await export(asset)
        defer { try? FileManager.default.removeItem(at: mp4) }
        let still = compressedImageData(stillData)
        let size = UIImage(data: still)?.size ?? .zero
        async let stillURL = Backend.shared.uploadMedia(still, ext: "jpg", contentType: "image/jpeg")
        async let movieURL = Backend.shared.uploadMedia(try Data(contentsOf: mp4), ext: "mp4", contentType: "video/mp4")
        return MediaItem(kind: kind, url: try await stillURL, video_url: try await movieURL,
                         w: Int(size.width), h: Int(size.height))
    }

    private static func export(_ asset: AVAsset) async throws -> URL {
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        guard let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else { throw Failure.unreadable }
        s.outputURL = out
        s.outputFileType = .mp4
        s.shouldOptimizeForNetworkUse = true
        await s.export()
        guard s.status == .completed else { throw s.error ?? Failure.unreadable }
        return out
    }

    static func poster(of url: URL) async throws -> Data {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        let cg = try gen.copyCGImage(at: .zero, actualTime: nil)
        guard let d = UIImage(cgImage: cg).jpegData(compressionQuality: 0.85) else { throw Failure.unreadable }
        return d
    }

    /// Saca la foto y el vídeo de una Live Photo (sin pedir acceso a toda la galería).
    private static func livePhotoFiles(_ live: PHLivePhoto) async throws -> (still: Data, video: URL) {
        let resources = PHAssetResource.assetResources(for: live)
        guard let photo = resources.first(where: { $0.type == .photo }),
              let video = resources.first(where: { $0.type == .pairedVideo }) else { throw Failure.unreadable }
        let dir = FileManager.default.temporaryDirectory
        let photoURL = dir.appendingPathComponent(UUID().uuidString + ".heic")
        let videoURL = dir.appendingPathComponent(UUID().uuidString + ".mov")
        try await write(photo, to: photoURL)
        try await write(video, to: videoURL)
        defer { try? FileManager.default.removeItem(at: photoURL) }
        return (try Data(contentsOf: photoURL), videoURL)
    }

    private static func write(_ r: PHAssetResource, to url: URL) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: r, toFile: url, options: nil) { err in
                if let err { c.resume(throwing: err) } else { c.resume() }
            }
        }
    }
}

/// Vídeo elegido en la galería, copiado a un fichero temporal propio.
struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "." + received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// MARK: - Editar la galería (registro y Editar perfil)

/// Rejilla de 3×3: la primera pieza es la principal. Tocar un hueco abre la galería del
/// móvil (fotos, vídeos y Live Photos); tocar una pieza deja ponerla primera o quitarla.
struct MediaGalleryEditor: View {
    @Binding var items: [MediaItem]
    @State private var picks: [PhotosPickerItem] = []
    @State private var uploading = 0
    @State private var error: String?
    @State private var selected: MediaItem?

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(0..<MediaRules.max, id: \.self) { i in
                    if i < items.count {
                        Button { selected = items[i] } label: { tile(items[i], main: i == 0) }.buttonStyle(.plain)
                    } else if i < items.count + uploading {
                        slot.overlay(ProgressView().tint(Brand.ink))
                    } else {
                        PhotosPicker(selection: $picks, maxSelectionCount: max(1, MediaRules.max - items.count - uploading),
                                     matching: .any(of: [.images, .videos, .livePhotos]), photoLibrary: .shared()) {
                            slot.overlay(Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundColor(Brand.soft))
                        }
                        .disabled(!BackendConfig.isConfigured || items.count + uploading >= MediaRules.max)
                    }
                }
            }
            if let error { Text(error).font(.caption).foregroundColor(Brand.redText) }
        }
        .onChange(of: picks) { new in
            guard !new.isEmpty else { return }
            let batch = Array(new.prefix(MediaRules.max - items.count - uploading))
            picks = []
            Task { await add(batch) }
        }
        .confirmationDialog("", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            if let s = selected, items.first != s {
                Button("Make main photo") { move(s) }
            }
            Button("Remove", role: .destructive) { if let s = selected { items.removeAll { $0 == s } } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func tile(_ m: MediaItem, main: Bool) -> some View {
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay(MediaView(item: m, autoplay: false))
            .overlay(alignment: .topTrailing) {
                if m.moves {
                    Image(systemName: m.kind == "live" ? "livephoto" : "play.fill")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                        .padding(6).background(.black.opacity(0.35)).clipShape(Circle()).padding(6)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if main {
                    Text("MAIN").font(.system(size: 9, weight: .heavy)).tracking(0.6).foregroundColor(Brand.ink)
                        .padding(.horizontal, 7).frame(height: 18).background(Brand.sand).clipShape(Capsule()).padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var slot: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Brand.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .aspectRatio(3 / 4, contentMode: .fit)
    }

    private func move(_ m: MediaItem) {
        items.removeAll { $0 == m }
        items.insert(m, at: 0)
    }

    private func add(_ batch: [PhotosPickerItem]) async {
        error = nil
        uploading += batch.count
        for p in batch {
            do {
                let m = try await MediaUploader.upload(p)
                if items.count < MediaRules.max { items.append(m) }
            } catch {
                print("[Media] subida falló:", error)
                self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn't upload. Try again."
            }
            uploading -= 1
        }
        FX.success()
    }
}
