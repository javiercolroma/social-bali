import SwiftUI
import Photos
import PhotosUI
import MapKit
import CoreLocation
import AVFoundation

// MARK: - Adjuntar, como en WhatsApp (con la estética de Bali Circle)
//
// · Panel con la tira de tus últimas fotos (tocar = elegir, varias a la vez), cámara,
//   galería completa y ubicación.
// · Antes de enviar fotos: vista previa a pantalla completa con pie de foto.
// · Ubicación: mapa con tu posición actual y «Send your current location».

/// Lo que se va a enviar desde el panel.
enum PendingMedia: Identifiable {
    case asset(PHAsset)
    case image(UIImage)
    case video(URL)

    var id: String {
        switch self {
        case .asset(let a): return a.localIdentifier
        case .image(let i): return "img-\(ObjectIdentifier(i).hashValue)"
        case .video(let u): return u.absoluteString
        }
    }
}

struct AttachPanel: View {
    enum Action { case camera, library, location }
    var onAction: (Action) -> Void
    var onSend: ([PendingMedia]) -> Void

    @State private var assets: [PHAsset] = []
    @State private var selected: [String] = []
    @State private var auth: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Brand.line).frame(width: 40, height: 5).padding(.top, 8)

            // Tira de fotos recientes (la cámara primero), como en WhatsApp.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button { onAction(.camera) } label: {
                        ZStack {
                            Brand.ink
                            Image(systemName: "camera.fill").font(.system(size: 26)).foregroundColor(Brand.onAccent)
                        }
                        .frame(width: 104, height: 128).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }.buttonStyle(.plain)
                    if auth == .authorized || auth == .limited {
                        ForEach(assets, id: \.localIdentifier) { a in
                            Button { toggle(a) } label: { tile(a) }.buttonStyle(.plain)
                        }
                    } else {
                        Button { requestAccess() } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "photo.on.rectangle").font(.system(size: 22))
                                Text("Show recent photos").font(.system(size: 12, weight: .medium)).multilineTextAlignment(.center)
                            }
                            .foregroundColor(Brand.ink)
                            .frame(width: 104, height: 128).background(Brand.sand)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            if selected.isEmpty {
                HStack(spacing: 0) {
                    item(.library, "Gallery", "photo.on.rectangle.angled")
                    item(.camera, "Camera", "camera")
                    item(.location, "Location", "mappin.and.ellipse")
                }
                .padding(.horizontal, 12)
            } else {
                Button { onSend(selected.compactMap { id in assets.first { $0.localIdentifier == id }.map(PendingMedia.asset) }) } label: {
                    HStack(spacing: 8) {
                        Text(selected.count == 1 ? L10n.t("Send 1 photo") : String(format: L10n.t("Send %lld photos"), selected.count))
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .animation(.easeOut(duration: 0.18), value: selected.isEmpty)
        .background(Brand.bg)
        .presentationDetents([.height(300)])
        .task { if auth == .authorized || auth == .limited { load() } }
    }

    private func tile(_ a: PHAsset) -> some View {
        let n = selected.firstIndex(of: a.localIdentifier).map { $0 + 1 }
        return AssetThumb(asset: a)
            .frame(width: 104, height: 128)
            .overlay(alignment: .bottomLeading) {
                if a.mediaType == .video {
                    Text(String(format: "%d:%02d", Int(a.duration) / 60, Int(a.duration) % 60))
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 5).background(.black.opacity(0.4)).clipShape(Capsule()).padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(n != nil ? Brand.accent : Color.black.opacity(0.2)).frame(width: 24, height: 24)
                    Circle().stroke(Color.white, lineWidth: 1.5).frame(width: 24, height: 24)
                    if let n { Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.onAccent) }
                }
                .padding(7)
            }
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(n != nil ? Brand.ink : .clear, lineWidth: 3))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(n != nil ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: n)
    }

    private func item(_ a: Action, _ title: LocalizedStringKey, _ icon: String) -> some View {
        Button { FX.tap(); onAction(a) } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 21, weight: .medium)).foregroundColor(Brand.ink)
                    .frame(width: 58, height: 58)
                    .background(Brand.sand).clipShape(Circle())
                    .overlay(Circle().stroke(Brand.sandDeep, lineWidth: 1))
                Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(Brand.ink)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func toggle(_ a: PHAsset) {
        FX.selection()
        if let i = selected.firstIndex(of: a.localIdentifier) { selected.remove(at: i) }
        else if selected.count < 10 { selected.append(a.localIdentifier) }
    }

    private func requestAccess() {
        if auth == .denied || auth == .restricted {
            if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
            Task { @MainActor in auth = s; if s == .authorized || s == .limited { load() } }
        }
    }

    private func load() {
        let o = PHFetchOptions()
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        o.fetchLimit = 40
        o.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        let r = PHAsset.fetchAssets(with: o)
        var out: [PHAsset] = []
        r.enumerateObjects { a, _, _ in out.append(a) }
        assets = out
    }
}

/// Miniatura de una foto de la galería.
struct AssetThumb: View {
    let asset: PHAsset
    @State private var image: UIImage?
    var body: some View {
        Color.clear.overlay {
            if let image { Image(uiImage: image).resizable().scaledToFill() } else { Brand.chip }
        }
        .clipped()
        .task(id: asset.localIdentifier) {
            let o = PHImageRequestOptions(); o.deliveryMode = .opportunistic; o.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 320, height: 400),
                                                  contentMode: .aspectFill, options: o) { img, _ in
                if let img { Task { @MainActor in image = img } }
            }
        }
    }
}

// MARK: - Vista previa antes de enviar (con pie de foto)

struct MediaSendPreview: View {
    let items: [PendingMedia]
    let recipientName: String
    var onSend: (String) -> Void
    var onCancel: () -> Void
    @State private var caption = ""
    @State private var page = 0
    @FocusState private var typing: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $page) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, m in
                    preview(m).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .always : .never))
            .ignoresSafeArea(edges: .top)
            .onTapGesture { typing = false }

            VStack {
                HStack {
                    Button { onCancel() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            .frame(width: 40, height: 40).background(.white.opacity(0.15)).clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(16)
                Spacer()
                VStack(spacing: 10) {
                    HStack(alignment: .bottom, spacing: 10) {
                        TextField("", text: $caption, prompt: Text("Add a caption…").foregroundColor(.white.opacity(0.6)), axis: .vertical)
                            .lineLimit(1...4)
                            .focused($typing)
                            .foregroundColor(.white).tint(.white)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(.white.opacity(0.14)).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        Button { onSend(caption.trimmingCharacters(in: .whitespacesAndNewlines)) } label: {
                            Image(systemName: "paperplane.fill").font(.system(size: 18)).foregroundColor(Brand.ink)
                                .frame(width: 50, height: 50).background(Brand.sand).clipShape(Circle())
                        }
                    }
                    Text(String(format: L10n.t("To %@"), recipientName)).font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7)).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 6)
                }
                .padding(.horizontal, 14).padding(.bottom, 10)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            }
        }
    }

    @ViewBuilder
    private func preview(_ m: PendingMedia) -> some View {
        switch m {
        case .image(let img):
            Image(uiImage: img).resizable().scaledToFit()
        case .video(let u):
            LoopingVideo(url: u).aspectRatio(contentMode: .fit)
        case .asset(let a):
            AssetLarge(asset: a)
        }
    }
}

struct AssetLarge: View {
    let asset: PHAsset
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            if let image { Image(uiImage: image).resizable().scaledToFit() } else { ProgressView().tint(.white) }
            if asset.mediaType == .video {
                Image(systemName: "play.fill").font(.system(size: 22)).foregroundColor(.white)
                    .frame(width: 56, height: 56).background(.black.opacity(0.4)).clipShape(Circle())
            }
        }
        .task(id: asset.localIdentifier) {
            let o = PHImageRequestOptions(); o.deliveryMode = .highQualityFormat; o.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1400, height: 1400),
                                                  contentMode: .aspectFit, options: o) { img, _ in
                if let img { Task { @MainActor in image = img } }
            }
        }
    }
}

// MARK: - Subir lo elegido

enum PendingUploader {
    /// Sube una foto/vídeo elegido y devuelve el MediaItem para el mensaje.
    static func upload(_ m: PendingMedia) async throws -> MediaItem {
        switch m {
        case .image(let img):
            guard let d = img.jpegData(compressionQuality: 0.85) else { throw MediaUploader.Failure.unreadable }
            let jpeg = compressedImageData(d)
            let size = UIImage(data: jpeg)?.size ?? img.size
            let url = try await Backend.shared.uploadMedia(jpeg, ext: "jpg", contentType: "image/jpeg")
            return MediaItem(kind: "photo", url: url, video_url: nil, w: Int(size.width), h: Int(size.height))
        case .video(let u):
            let still = try await MediaUploader.poster(of: u)
            return try await MediaUploader.uploadMoving(kind: "video", stillData: still, videoURL: u)
        case .asset(let a):
            if a.mediaType == .video {
                let url = try await videoURL(a)
                let still = try await MediaUploader.poster(of: url)
                return try await MediaUploader.uploadMoving(kind: "video", stillData: still, videoURL: url)
            }
            let data = try await imageData(a)
            let jpeg = compressedImageData(data)
            let size = UIImage(data: jpeg)?.size ?? .zero
            let url = try await Backend.shared.uploadMedia(jpeg, ext: "jpg", contentType: "image/jpeg")
            return MediaItem(kind: "photo", url: url, video_url: nil, w: Int(size.width), h: Int(size.height))
        }
    }

    private static func imageData(_ a: PHAsset) async throws -> Data {
        try await withCheckedThrowingContinuation { c in
            let o = PHImageRequestOptions(); o.isNetworkAccessAllowed = true; o.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImageDataAndOrientation(for: a, options: o) { d, _, _, _ in
                if let d { c.resume(returning: d) } else { c.resume(throwing: MediaUploader.Failure.unreadable) }
            }
        }
    }

    private static func videoURL(_ a: PHAsset) async throws -> URL {
        try await withCheckedThrowingContinuation { c in
            let o = PHVideoRequestOptions(); o.isNetworkAccessAllowed = true; o.deliveryMode = .mediumQualityFormat
            PHImageManager.default().requestAVAsset(forVideo: a, options: o) { av, _, _ in
                if let u = (av as? AVURLAsset)?.url { c.resume(returning: u) } else { c.resume(throwing: MediaUploader.Failure.unreadable) }
            }
        }
    }
}

// MARK: - Enviar ubicación (mapa de vista previa)

struct LocationSendSheet: View {
    var onSend: (CLLocationCoordinate2D) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -8.65, longitude: 115.13),
                                                   span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    @State private var failed = false

    private struct Pin: Identifiable { let id = 0; let c: CLLocationCoordinate2D }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Map(coordinateRegion: $region, annotationItems: coordinate.map { [Pin(c: $0)] } ?? []) { p in
                        MapAnnotation(coordinate: p.c) {
                            ZStack {
                                Circle().fill(Brand.ink.opacity(0.15)).frame(width: 46, height: 46)
                                Circle().fill(Brand.ink).frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            }
                        }
                    }
                    if coordinate == nil && !failed { ProgressView().tint(Brand.ink).padding(14).background(Color.white).clipShape(Circle()) }
                }
                .frame(maxHeight: .infinity)

                VStack(spacing: 12) {
                    if failed {
                        Text("Couldn't get your location.").font(.footnote).foregroundColor(Brand.redText)
                    }
                    Button { if let c = coordinate { onSend(c); dismiss() } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill").font(.system(size: 16)).foregroundColor(Brand.onAccent)
                                .frame(width: 40, height: 40).background(Brand.accent).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Send your current location").font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.ink)
                                Text("Opens in Google Maps for them").font(.system(size: 12)).foregroundColor(Brand.muted)
                            }
                            Spacer()
                        }
                        .padding(12).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.line))
                    }
                    .buttonStyle(.plain)
                    .disabled(coordinate == nil)
                    .opacity(coordinate == nil ? 0.5 : 1)
                }
                .padding(16)
                .background(Brand.bg)
            }
            .navigationTitle("Location").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task {
                if let c = await OneShotLocation().fetch() {
                    coordinate = c
                    withAnimation { region.center = c }
                } else { failed = true }
            }
        }
    }
}
