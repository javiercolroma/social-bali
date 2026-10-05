import SwiftUI
import AVFoundation
import Photos

// MARK: - Cámara del chat, como la de WhatsApp
//
// Pantalla completa: tocar el disparador = foto, mantenerlo = vídeo (anillo que avanza),
// flash, girar cámara, galería y la tira de fotos recientes encima del disparador.
// Lo capturado (o lo elegido de la tira) va a la vista previa con pie de foto.

struct ChatCameraView: View {
    var onCaptured: ([PendingMedia]) -> Void
    var onOpenLibrary: () -> Void
    var onClose: () -> Void

    @StateObject private var cam = CameraController()
    @State private var recent: [PHAsset] = []
    @State private var pressing = false
    @State private var pressStart = Date()
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: cam.session).ignoresSafeArea()
                .onTapGesture(count: 2) { cam.flip() }

            VStack {
                // Arriba: cerrar y flash.
                HStack {
                    Button { onClose() } label: { roundIcon("xmark") }
                    Spacer()
                    if cam.isRecording {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                            Text(String(format: "%d:%02d", Int(cam.recordedSeconds) / 60, Int(cam.recordedSeconds) % 60))
                                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).frame(height: 30).background(.black.opacity(0.35)).clipShape(Capsule())
                    }
                    Spacer()
                    Button { cam.flashOn.toggle() } label: { roundIcon(cam.flashOn ? "bolt.fill" : "bolt.slash.fill") }
                }
                .padding(.horizontal, 16).padding(.top, 8)

                Spacer()

                // Tira de fotos recientes (como en WhatsApp).
                if !recent.isEmpty && !cam.isRecording {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(recent, id: \.localIdentifier) { a in
                                Button { onCaptured([.asset(a)]) } label: {
                                    AssetThumb(asset: a).frame(width: 66, height: 66)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.bottom, 14)
                }

                // Galería · disparador · girar
                HStack {
                    Button { onOpenLibrary() } label: { roundIcon("photo.on.rectangle", size: 46) }
                    Spacer()
                    shutter
                    Spacer()
                    Button { cam.flip() } label: { roundIcon("arrow.triangle.2.circlepath.camera", size: 46) }
                }
                .padding(.horizontal, 34)

                Text(cam.isRecording ? L10n.t("Release to stop") : L10n.t("Hold for video, tap for photo"))
                    .font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                    .padding(.top, 10).padding(.bottom, 8)
            }
        }
        .statusBarHidden()
        .task {
            await cam.start()
            loadRecent()
        }
        .onDisappear { cam.stop() }
        .onChange(of: cam.captured) { m in
            if let m { cam.captured = nil; onCaptured([m]) }
        }
    }

    /// Tocar = foto. Mantener (más de 0,35 s) = vídeo hasta soltar.
    private var shutter: some View {
        ZStack {
            Circle().stroke(Color.white, lineWidth: 5).frame(width: 78, height: 78)
            if cam.isRecording {
                Circle().trim(from: 0, to: min(1, cam.recordedSeconds / MediaRules.maxVideoSeconds))
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 78, height: 78)
                RoundedRectangle(cornerRadius: 8).fill(Color.red).frame(width: 30, height: 30)
            } else {
                Circle().fill(Color.white.opacity(pressing ? 0.6 : 0.95)).frame(width: 64, height: 64)
            }
        }
        .scaleEffect(cam.isRecording ? 1.15 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cam.isRecording)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressing else { return }
                    pressing = true; pressStart = Date()
                    holdTask = Task {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        if !Task.isCancelled && pressing { cam.startRecording() }
                    }
                }
                .onEnded { _ in
                    pressing = false
                    holdTask?.cancel()
                    if cam.isRecording { cam.stopRecording() }
                    else if Date().timeIntervalSince(pressStart) < 0.35 { FX.tap(); cam.takePhoto() }
                }
        )
    }

    private func roundIcon(_ name: String, size: CGFloat = 40) -> some View {
        Image(systemName: name).font(.system(size: size * 0.42, weight: .semibold)).foregroundColor(.white)
            .frame(width: size, height: size).background(.black.opacity(0.35)).clipShape(Circle())
    }

    private func loadRecent() {
        let st = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard st == .authorized || st == .limited else { return }
        let o = PHFetchOptions()
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        o.fetchLimit = 30
        o.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        var out: [PHAsset] = []
        PHAsset.fetchAssets(with: o).enumerateObjects { a, _, _ in out.append(a) }
        recent = out
    }
}

/// Vista previa en vivo de la cámara.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoLayer.session = session
        v.videoLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// Sesión de cámara: foto, vídeo (con micro), flash y girar.
@MainActor
final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var isRecording = false
    @Published var recordedSeconds: Double = 0
    @Published var flashOn = false
    @Published var captured: PendingMedia?

    private let photoOut = AVCapturePhotoOutput()
    private let movieOut = AVCaptureMovieFileOutput()
    private var position: AVCaptureDevice.Position = .back
    private var input: AVCaptureDeviceInput?
    private var timer: Timer?
    private let queue = DispatchQueue(label: "bali.camera")

    func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return }
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        session.beginConfiguration()
        session.sessionPreset = .high
        attachCamera(.back)
        if let mic = AVCaptureDevice.default(for: .audio), let mi = try? AVCaptureDeviceInput(device: mic), session.canAddInput(mi) {
            session.addInput(mi)
        }
        if session.canAddOutput(photoOut) { session.addOutput(photoOut) }
        if session.canAddOutput(movieOut) {
            session.addOutput(movieOut)
            movieOut.maxRecordedDuration = CMTime(seconds: MediaRules.maxVideoSeconds, preferredTimescale: 600)
        }
        session.commitConfiguration()
        let s = session
        queue.async { s.startRunning() }
    }

    func stop() {
        let s = session
        queue.async { s.stopRunning() }
    }

    private func attachCamera(_ pos: AVCaptureDevice.Position) {
        if let input { session.removeInput(input) }
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: pos),
              let inp = try? AVCaptureDeviceInput(device: dev), session.canAddInput(inp) else { return }
        session.addInput(inp)
        input = inp
        position = pos
    }

    func flip() {
        session.beginConfiguration()
        attachCamera(position == .back ? .front : .back)
        session.commitConfiguration()
        FX.tap()
    }

    func takePhoto() {
        let settings = AVCapturePhotoSettings()
        if photoOut.supportedFlashModes.contains(.on) { settings.flashMode = flashOn ? .on : .off }
        photoOut.capturePhoto(with: settings, delegate: self)
    }

    func startRecording() {
        guard !movieOut.isRecording else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        if flashOn, let dev = input?.device, dev.hasTorch { try? dev.lockForConfiguration(); dev.torchMode = .on; dev.unlockForConfiguration() }
        movieOut.startRecording(to: url, recordingDelegate: self)
        isRecording = true; recordedSeconds = 0
        FX.tap()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.recordedSeconds += 0.1 }
        }
    }

    func stopRecording() {
        guard movieOut.isRecording else { return }
        movieOut.stopRecording()
    }

    private func endRecording() {
        timer?.invalidate(); timer = nil
        isRecording = false
        if let dev = input?.device, dev.hasTorch { try? dev.lockForConfiguration(); dev.torchMode = .off; dev.unlockForConfiguration() }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let img = UIImage(data: data) else { return }
        Task { @MainActor in self.captured = .image(img) }
    }

    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            self.endRecording()
            // Un toque muy corto no deja vídeo útil.
            if self.recordedSeconds >= 0.8 { self.captured = .video(outputFileURL) }
        }
    }
}

extension PendingMedia: Equatable {
    static func == (a: PendingMedia, b: PendingMedia) -> Bool { a.id == b.id }
}
