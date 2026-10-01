import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import MapKit
import CoreLocation

// Piezas del chat: adjuntar, mapa, notas de voz, cámara y visor.

// MARK: - Adjuntar (panel propio, estilo de la app)

struct AttachSheet: View {
    enum Choice { case camera, photos, location }
    var onPick: (Choice) -> Void

    var body: some View {
        VStack(spacing: 22) {
            Capsule().fill(Brand.line).frame(width: 40, height: 5).padding(.top, 8)
            HStack(spacing: 0) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    item(.camera, "Camera", "camera.fill")
                }
                item(.photos, "Photos", "photo.on.rectangle.angled")
                item(.location, "Location", "mappin.and.ellipse")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Brand.bg)
        .presentationDetents([.height(190)])
        .presentationDragIndicator(.hidden)
    }

    private func item(_ c: Choice, _ title: LocalizedStringKey, _ icon: String) -> some View {
        Button { FX.tap(); onPick(c) } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 22, weight: .medium)).foregroundColor(Brand.ink)
                    .frame(width: 62, height: 62)
                    .background(Brand.sand).clipShape(Circle())
                    .overlay(Circle().stroke(Brand.sandDeep, lineWidth: 1))
                Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(Brand.ink)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Mapa estático de una ubicación compartida.
struct MapSnapshot: View {
    let lat: Double
    let lon: Double
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image { Image(uiImage: image).resizable().scaledToFill() } else { Brand.chip }
            Image(systemName: "mappin.circle.fill").font(.system(size: 30)).foregroundColor(Brand.red)
                .background(Circle().fill(.white).padding(4))
        }
        .clipped()
        .task {
            let o = MKMapSnapshotter.Options()
            o.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                          latitudinalMeters: 600, longitudinalMeters: 600)
            o.size = CGSize(width: 460, height: 280)
            image = try? await MKMapSnapshotter(options: o).start().image
        }
    }
}

/// Nota de voz: reproducir / pausar con progreso.
struct AudioBubble<Meta: View>: View {
    let url: String
    let duration: Double
    @ViewBuilder var meta: () -> Meta
    @StateObject private var player = AudioPlayer()

    private func bar(_ i: Int) -> CGFloat {
        var h: UInt64 = 1469598103934665603
        for c in (url + String(i)).utf8 { h = (h ^ UInt64(c)) &* 1099511628211 }
        return 5 + CGFloat(h % 17)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button { player.toggle(url) } label: {
                Image(systemName: player.playing ? "pause.fill" : "play.fill").font(.system(size: 16)).foregroundColor(Brand.ink)
                    .frame(width: 34, height: 34).background(Color.white.opacity(0.7)).clipShape(Circle())
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                // Onda de la nota (estable por URL), rellenada según avanza.
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<26, id: \.self) { i in
                        Capsule()
                            .fill(Double(i) / 26 < Double(player.progress) ? Brand.ink : Brand.ink.opacity(0.22))
                            .frame(width: 3, height: bar(i))
                    }
                }
                .frame(width: 130, height: 22, alignment: .leading)
                HStack {
                    Text(String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60))
                        .font(.system(size: 11, weight: .medium).monospacedDigit()).foregroundColor(Brand.muted)
                    Spacer()
                    meta().foregroundColor(Brand.muted)
                }
                .frame(width: 130)
            }
            if player.playing || player.progress > 0 {
                Button { player.cycleSpeed() } label: {
                    Text(player.speedLabel).font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.ink)
                        .frame(width: 38, height: 24).background(Color.white.opacity(0.8)).clipShape(Capsule())
                }.buttonStyle(.plain)
            }
        }
    }
}

@MainActor
final class AudioPlayer: ObservableObject {
    @Published var playing = false
    @Published var progress: CGFloat = 0
    @Published var speed: Float = 1
    private var player: AVPlayer?

    var speedLabel: String { speed == 1 ? "1×" : speed == 1.5 ? "1.5×" : "2×" }

    func cycleSpeed() {
        speed = speed == 1 ? 1.5 : speed == 1.5 ? 2 : 1
        if playing { player?.rate = speed }
    }
    private var observer: Any?

    func toggle(_ url: String) {
        if playing { player?.pause(); playing = false; return }
        if player == nil, let u = URL(string: url) {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            let p = AVPlayer(url: u)
            observer = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] t in
                guard let self, let d = p.currentItem?.duration.seconds, d > 0 else { return }
                Task { @MainActor in
                    self.progress = CGFloat(t.seconds / d)
                    if t.seconds >= d - 0.05 { self.playing = false; self.progress = 0; p.seek(to: .zero) }
                }
            }
            player = p
        }
        player?.play(); player?.rate = speed; playing = true
    }
}

/// Graba notas de voz (AAC, .m4a).
@MainActor
final class VoiceRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var file: URL?

    func start() {
        AVAudioSession.sharedInstance().requestRecordPermission { ok in
            Task { @MainActor in if ok { self.begin() } }
        }
    }

    private func begin() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100,
                                       AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue]
        guard let r = try? AVAudioRecorder(url: url, settings: settings), r.record() else { return }
        recorder = r; file = url; elapsed = 0; isRecording = true
        FX.tap()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let r = self.recorder else { return }
                self.elapsed = r.currentTime
                if r.currentTime >= 120 { _ = self.stop() }   // 2 minutos como mucho
            }
        }
    }

    func stop() -> (URL, Double)? {
        guard let r = recorder, let f = file else { return nil }
        let seconds = r.currentTime
        r.stop(); timer?.invalidate()
        recorder = nil; timer = nil; isRecording = false
        return (f, seconds)
    }

    func cancel() {
        if let (f, _) = stop() { try? FileManager.default.removeItem(at: f) }
    }
}

/// Una sola lectura de la ubicación actual (para compartirla en un chat).
@MainActor
final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    func fetch() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { c in
            continuation = c
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let c = locations.last?.coordinate
        Task { @MainActor in self.continuation?.resume(returning: c); self.continuation = nil }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.continuation?.resume(returning: nil); self.continuation = nil }
    }
}

/// Cámara del sistema (foto o vídeo corto).
struct CameraPicker: UIViewControllerRepresentable {
    enum Result { case image(UIImage), video(URL) }
    var onDone: (Result?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.mediaTypes = ["public.image", "public.movie"]
        p.videoMaximumDuration = MediaRules.maxVideoSeconds
        p.videoQuality = .typeMedium
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onDone: (Result?) -> Void
        init(onDone: @escaping (Result?) -> Void) { self.onDone = onDone }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL { onDone(.video(url)) }
            else if let img = info[.originalImage] as? UIImage { onDone(.image(img)) }
            else { onDone(nil) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onDone(nil) }
    }
}

/// Foto o vídeo de un mensaje a pantalla completa.
struct MediaViewer: View {
    let message: ChatMessage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if message.type == "video", let u = message.mediaURL.flatMap(URL.init(string:)) {
                VideoPlayer(player: AVPlayer(url: u)).ignoresSafeArea()
            } else if let u = message.mediaURL.flatMap(URL.init(string:)) {
                AsyncImage(url: u) { phase in
                    if let img = phase.image { img.resizable().scaledToFit() } else { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    .frame(width: 40, height: 40).background(.white.opacity(0.15)).clipShape(Circle())
            }
            .padding(16)
        }
    }
}
