import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import MapKit
import CoreLocation
import Supabase

// MARK: - Chat 1:1 tipo WhatsApp (0033)
//
// Texto, fotos y vídeos (galería o cámara), ubicación y notas de voz. Doble check
// gris/azul según la otra persona lo haya leído. Separadores por día.

struct ChatView: View {
    @EnvironmentObject var store: AppStore
    let personId: String
    var onOpenProfile: (String) -> Void
    var onClose: () -> Void = {}

    @State private var draft = ""
    @State private var messages: [ChatMessage] = []
    @State private var channel: RealtimeChannelV2?
    @State private var showProfile = false
    @State private var attachMenu = false
    @State private var showLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var sending = 0
    @State private var sendError: String?
    @State private var viewer: ChatMessage?
    @StateObject private var recorder = VoiceRecorder()
    @FocusState private var typing: Bool

    private var person: SocialPerson? { store.person(personId) }
    private var me: String? { Backend.shared.currentUserId?.uuidString.lowercased() }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if messages.isEmpty {
                            emptyState(icon: "hand.wave", title: "Say hi", body: "Be friendly — this is a small community.")
                        }
                        ForEach(Array(messages.enumerated()), id: \.element.id) { i, m in
                            if i == 0 || !Calendar.current.isDate(messages[i - 1].at, inSameDayAs: m.at) {
                                daySeparator(m.at)
                            }
                            ChatBubble(message: m, onOpen: { viewer = m }).id(m.id)
                        }
                        if sending > 0 {
                            HStack { Spacer(); ProgressView().tint(Brand.ink).padding(10) }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    store.markConversationRead(personId)
                }
                .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            if let sendError {
                Text(sendError).font(.caption).foregroundColor(Brand.redText).padding(.vertical, 4)
            }
            composer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.bg.ignoresSafeArea())
        .onAppear { _ = store.openConversation(personId) }
        .task {
            messages = store.conversations.first { $0.personId.lowercased() == personId.lowercased() }?.messages ?? []
            await load()
            Task { await subscribeRealtime() }
            // Respaldo: refresco lento (también trae el doble check azul).
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                await load()
            }
        }
        .onDisappear { Task { await unsubscribe() } }
        .sheet(isPresented: $showProfile) { ClubProfileView(personId: personId).environmentObject(store) }
        .confirmationDialog("", isPresented: $attachMenu) {
            Button("Photo or video") { showLibrary = true }
            if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("Camera") { showCamera = true } }
            Button("Share my location") { Task { await sendLocation() } }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showLibrary, selection: $libraryItem, matching: .any(of: [.images, .videos, .livePhotos]),
                      photoLibrary: .shared())
        .onChange(of: libraryItem) { item in
            guard let item else { return }
            libraryItem = nil
            Task { await sendPicked(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { result in
                showCamera = false
                Task { await sendCamera(result) }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $viewer) { MediaViewer(message: $0) }
    }

    // MARK: Cabecera

    private var header: some View {
        HStack(spacing: 11) {
            Button { onClose() } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundColor(Brand.ink)
                    .frame(width: 36, height: 36)
            }
            Button { showProfile = true } label: {
                HStack(spacing: 11) {
                    PersonAvatar(person: person, size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text(person?.name ?? "…").font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.ink)
                            if let c = person?.club?.homeCountry, !c.isEmpty { Text(countryFlag(c)) }
                        }
                        if let a = person?.club?.area {
                            Text(a.label).font(.caption).foregroundColor(Brand.muted)
                        }
                    }
                }
            }.buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Brand.bg).overlay(Divider(), alignment: .bottom)
    }

    private func daySeparator(_ d: Date) -> some View {
        let f = DateFormatter()
        f.locale = L10n.locale
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        return Text(f.string(from: d))
            .font(.system(size: 11, weight: .semibold)).foregroundColor(Brand.muted)
            .padding(.horizontal, 10).frame(height: 22).background(Brand.chip).clipShape(Capsule())
            .padding(.vertical, 8)
    }

    // MARK: Escribir

    private var composer: some View {
        Group {
            if recorder.isRecording {
                HStack(spacing: 12) {
                    Button { recorder.cancel() } label: {
                        Image(systemName: "trash").font(.system(size: 18)).foregroundColor(Brand.redText).frame(width: 44, height: 44)
                    }
                    Circle().fill(Brand.red).frame(width: 9, height: 9)
                    Text(timeString(recorder.elapsed)).font(.system(size: 15, weight: .medium).monospacedDigit()).foregroundColor(Brand.ink)
                    Spacer()
                    Button { Task { await sendVoice() } } label: {
                        Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold)).foregroundColor(Brand.onAccent)
                            .frame(width: 44, height: 44).background(Brand.accent).clipShape(Circle())
                    }
                }
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    Button { typing = false; attachMenu = true } label: {
                        Image(systemName: "plus").font(.system(size: 20, weight: .medium)).foregroundColor(Brand.ink)
                            .frame(width: 44, height: 44)
                    }
                    TextField("Message", text: $draft, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($typing)
                        .font(.system(size: 16))
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Brand.line))
                    if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button { recorder.start() } label: {
                            Image(systemName: "mic.fill").font(.system(size: 18)).foregroundColor(Brand.ink)
                                .frame(width: 44, height: 44)
                        }
                    } else {
                        Button { sendText() } label: {
                            Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold)).foregroundColor(Brand.onAccent)
                                .frame(width: 44, height: 44).background(Brand.accent).clipShape(Circle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Brand.bg).overlay(Divider(), alignment: .top)
    }

    private func timeString(_ t: TimeInterval) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }

    // MARK: Enviar

    private func sendText() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        draft = ""
        FX.tap()
        deliver(MessageInsert(sender_id: "", recipient_id: "", text: t))
    }

    /// Lo refleja al instante y lo manda al servidor.
    private func deliver(_ m: MessageInsert) {
        guard let uid = UUID(uuidString: personId) else { return }
        let local = ChatMessage(id: UUID().uuidString, fromMe: true, text: m.text, at: Date(), kind: m.kind,
                                mediaURL: m.media_url, posterURL: m.poster_url, w: m.media_w, h: m.media_h,
                                duration: m.duration, lat: m.lat, lon: m.lon, read: false)
        messages.append(local)
        store.appendLocalMessage(personId, local)
        sendError = nil
        Task {
            do { try await Backend.shared.sendMessage(to: uid, m) }
            catch {
                print("[Chat] envío falló:", error)
                messages.removeAll { $0.id == local.id }
                sendError = L10n.t("Couldn't send. Try again.")
            }
        }
    }

    private func sendPicked(_ item: PhotosPickerItem) async {
        sending += 1; defer { sending -= 1 }
        do {
            let m = try await MediaUploader.upload(item)
            deliver(insert(for: m))
        } catch {
            sendError = (error as? LocalizedError)?.errorDescription ?? L10n.t("Couldn't send. Try again.")
        }
    }

    private func sendCamera(_ result: CameraPicker.Result?) async {
        guard let result else { return }
        sending += 1; defer { sending -= 1 }
        do {
            switch result {
            case .image(let img):
                guard let d = img.jpegData(compressionQuality: 0.85) else { return }
                let jpeg = compressedImageData(d)
                let url = try await Backend.shared.uploadMedia(jpeg, ext: "jpg", contentType: "image/jpeg")
                deliver(insert(for: MediaItem(kind: "photo", url: url, video_url: nil, w: Int(img.size.width), h: Int(img.size.height))))
            case .video(let url):
                let still = try await MediaUploader.poster(of: url)
                deliver(insert(for: try await MediaUploader.uploadMoving(kind: "video", stillData: still, videoURL: url)))
            }
        } catch {
            sendError = (error as? LocalizedError)?.errorDescription ?? L10n.t("Couldn't send. Try again.")
        }
    }

    private func insert(for m: MediaItem) -> MessageInsert {
        if let v = m.video_url {
            return MessageInsert(sender_id: "", recipient_id: "", text: "", kind: "video", media_url: v,
                                 poster_url: m.url, media_w: m.w, media_h: m.h)
        }
        return MessageInsert(sender_id: "", recipient_id: "", text: "", kind: "image", media_url: m.url,
                             media_w: m.w, media_h: m.h)
    }

    /// Ubicación de AHORA, compartida a propósito con esta persona.
    private func sendLocation() async {
        sending += 1; defer { sending -= 1 }
        guard let c = await OneShotLocation().fetch() else {
            sendError = L10n.t("Couldn't get your location.")
            return
        }
        deliver(MessageInsert(sender_id: "", recipient_id: "", text: "", kind: "location", lat: c.latitude, lon: c.longitude))
    }

    private func sendVoice() async {
        guard let (file, seconds) = recorder.stop(), seconds >= 1 else { return }
        sending += 1; defer { sending -= 1 }
        do {
            let data = try Data(contentsOf: file)
            let url = try await Backend.shared.uploadMedia(data, ext: "m4a", contentType: "audio/mp4")
            deliver(MessageInsert(sender_id: "", recipient_id: "", text: "", kind: "audio", media_url: url, duration: seconds))
        } catch {
            sendError = L10n.t("Couldn't send. Try again.")
        }
        try? FileManager.default.removeItem(at: file)
    }

    // MARK: Recibir

    private func load() async {
        guard let uid = UUID(uuidString: personId) else { return }
        guard let rows = try? await Backend.shared.fetchMessages(with: uid) else { return }
        let fresh = rows.map { $0.message(me: me) }
        // Conserva los mensajes propios aún en camino.
        let pending = messages.filter { m in m.fromMe && !fresh.contains { $0.id == m.id } && Date().timeIntervalSince(m.at) < 20 }
        messages = fresh + pending.filter { p in !fresh.contains { $0.fromMe && $0.at.timeIntervalSince(p.at) > -2 && $0.type == p.type && $0.text == p.text } }
    }

    private func subscribeRealtime() async {
        guard BackendConfig.isConfigured, let client = Backend.shared.client,
              let me = await Backend.shared.currentUserIdAsync() else { return }
        let ch = client.channel("chat:\(personId)")
        let inserts = ch.postgresChange(InsertAction.self, schema: "public", table: "messages",
                                        filter: "recipient_id=eq.\(me.uuidString)")
        await ch.subscribe()
        channel = ch
        for await change in inserts {
            guard let row = try? change.decodeRecord(as: MessageRow.self, decoder: JSONDecoder()),
                  row.sender_id.lowercased() == personId.lowercased() else { continue }
            let msg = row.message(me: me.uuidString)
            if !messages.contains(where: { $0.id == msg.id }) {
                messages.append(msg)
                store.appendLocalMessage(personId, msg)
            }
        }
    }

    private func unsubscribe() async {
        if let ch = channel, let client = Backend.shared.client { await client.removeChannel(ch) }
        channel = nil
    }
}

// MARK: - Burbujas

struct ChatBubble: View {
    let message: ChatMessage
    var onOpen: () -> Void

    var body: some View {
        HStack {
            if message.fromMe { Spacer(minLength: 54) }
            content
            if !message.fromMe { Spacer(minLength: 54) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch message.type {
        case "image", "video":
            Button(action: onOpen) {
                ZStack {
                    RemoteFill(url: message.posterURL ?? message.mediaURL ?? "")
                    if message.type == "video" {
                        Image(systemName: "play.fill").font(.system(size: 20)).foregroundColor(.white)
                            .frame(width: 48, height: 48).background(.black.opacity(0.4)).clipShape(Circle())
                    }
                }
                .frame(width: 220, height: 220 / mediaAspect)
                .overlay(alignment: .bottomTrailing) { meta.foregroundColor(.white).shadow(radius: 2).padding(8) }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }.buttonStyle(.plain)
        case "location":
            Button { openInMaps() } label: {
                VStack(alignment: .leading, spacing: 0) {
                    MapSnapshot(lat: message.lat ?? 0, lon: message.lon ?? 0).frame(width: 230, height: 140)
                    HStack {
                        Label("Location", systemImage: "mappin.circle.fill").font(.system(size: 14, weight: .semibold))
                        Spacer()
                        meta
                    }
                    .foregroundColor(Brand.ink).padding(10)
                }
                .frame(width: 230)
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }.buttonStyle(.plain)
        case "audio":
            AudioBubble(url: message.mediaURL ?? "", duration: message.duration ?? 0) { meta }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        default:
            VStack(alignment: .trailing, spacing: 2) {
                Text(message.preview).font(.system(size: 16)).foregroundColor(Brand.ink)
                    .fixedSize(horizontal: false, vertical: true)
                meta.foregroundColor(Brand.muted)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(bubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var bubbleColor: Color { message.fromMe ? Brand.sand : Color.white }

    private var mediaAspect: CGFloat {
        guard let w = message.w, let h = message.h, w > 0, h > 0 else { return 1 }
        return min(max(CGFloat(w) / CGFloat(h), 0.6), 1.6)
    }

    /// Hora + doble check (azul si la otra persona ya lo ha leído).
    private var meta: some View {
        HStack(spacing: 3) {
            Text(message.at, style: .time).font(.system(size: 10, weight: .medium))
            if message.fromMe {
                ZStack {
                    Image(systemName: "checkmark").offset(x: -2.5)
                    Image(systemName: "checkmark").offset(x: 1.5)
                }
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(message.read == true ? Color(hex: "3b9ae8") : Brand.soft)
            }
        }
        .opacity(0.85)
    }

    private func openInMaps() {
        guard let lat = message.lat, let lon = message.lon else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
        item.name = message.fromMe ? L10n.t("My location") : L10n.t("Shared location")
        item.openInMaps()
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

    var body: some View {
        HStack(spacing: 10) {
            Button { player.toggle(url) } label: {
                Image(systemName: player.playing ? "pause.fill" : "play.fill").font(.system(size: 16)).foregroundColor(Brand.ink)
                    .frame(width: 34, height: 34).background(Color.white.opacity(0.7)).clipShape(Circle())
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Brand.ink.opacity(0.15))
                        Capsule().fill(Brand.ink).frame(width: g.size.width * player.progress)
                    }
                }
                .frame(width: 130, height: 4)
                HStack {
                    Text(String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60))
                        .font(.system(size: 11, weight: .medium).monospacedDigit()).foregroundColor(Brand.muted)
                    Spacer()
                    meta().foregroundColor(Brand.muted)
                }
                .frame(width: 130)
            }
        }
    }
}

@MainActor
final class AudioPlayer: ObservableObject {
    @Published var playing = false
    @Published var progress: CGFloat = 0
    private var player: AVPlayer?
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
        player?.play(); playing = true
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
