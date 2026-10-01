import SwiftUI
import PhotosUI
import Supabase

// MARK: - Chat 1:1 tipo WhatsApp (0033 + 0035)
//
// Mismas interacciones que WhatsApp, con la estética de Bali Circle:
//   · burbujas con «colita» agrupadas, hora y doble check dentro;
//   · mantener pulsado → reacciones + Responder / Copiar / Borrar para todos;
//   · deslizar a la derecha → responder citando;
//   · cabecera con «online» / «last seen…» / «typing…»;
//   · botón para bajar al final; separadores por día; fondo con motivo suave.

struct ChatView: View {
    @EnvironmentObject var store: AppStore
    let personId: String
    var onOpenProfile: (String) -> Void
    var onClose: () -> Void = {}

    @State private var draft = ""
    @State private var messages: [ChatMessage] = []
    @State private var channel: RealtimeChannelV2?
    @State private var typingChannel: RealtimeChannelV2?
    @State private var theyAreTyping = false
    @State private var typingResetTask: Task<Void, Never>?
    @State private var lastTypingSent = Date.distantPast
    @State private var lastSeen: Date?
    @State private var showProfile = false
    @State private var attachMenu = false
    @State private var showLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var sending = 0
    @State private var sendError: String?
    @State private var viewer: ChatMessage?
    @State private var replyingTo: ChatMessage?
    @State private var focusedMessage: ChatMessage?
    @State private var atBottom = true
    @StateObject private var recorder = VoiceRecorder()
    @State private var holdDragX: CGFloat = 0
    @State private var holdCancelled = false
    @State private var holding = false
    @State private var holdDragY: CGFloat = 0
    /// Grabación bloqueada (deslizar hacia arriba): se puede soltar y seguir grabando.
    @State private var recordLocked = false
    @FocusState private var typing: Bool

    private var person: SocialPerson? { store.person(personId) }
    private var me: String? { Backend.shared.currentUserId?.uuidString.lowercased() }
    private var isOnline: Bool { lastSeen.map { Date().timeIntervalSince($0) < 300 } ?? false }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if messages.isEmpty {
                                emptyState(icon: "hand.wave", title: "Say hi", body: "Be friendly — this is a small community.")
                            }
                            ForEach(Array(messages.enumerated()), id: \.element.id) { i, m in
                                if i == 0 || !Calendar.current.isDate(messages[i - 1].at, inSameDayAs: m.at) {
                                    daySeparator(m.at)
                                }
                                let lastOfGroup = i == messages.count - 1 || messages[i + 1].fromMe != m.fromMe
                                    || !Calendar.current.isDate(messages[i + 1].at, inSameDayAs: m.at)
                                ChatBubble(message: m, quoted: quoted(m), tail: lastOfGroup,
                                           onOpen: { viewer = m },
                                           onReply: { reply(to: m) },
                                           onLongPress: { FX.tap(); focusedMessage = m })
                                    .padding(.bottom, lastOfGroup ? 8 : 2)
                                    .id(m.id)
                            }
                            if theyAreTyping { TypingBubble().padding(.bottom, 8) }
                            if sending > 0 {
                                HStack { Spacer(); ProgressView().tint(Brand.ink).padding(10) }
                            }
                            Color.clear.frame(height: 1).id("bottom")
                                .onAppear { atBottom = true }
                                .onDisappear { atBottom = false }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 10)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .background(ChatWallpaper())
                    .onChange(of: messages.count) { _ in
                        if atBottom || messages.last?.fromMe == true {
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                        store.markConversationRead(personId)
                    }
                    .onChange(of: theyAreTyping) { t in if t && atBottom { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } } }
                    .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
                    .overlay(alignment: .bottomTrailing) {
                        // Bajar al final, como en WhatsApp.
                        if !atBottom {
                            Button { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } } label: {
                                Image(systemName: "chevron.down").font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink)
                                    .frame(width: 40, height: 40).background(Color.white).clipShape(Circle())
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            }
                            .padding(14)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            if let sendError {
                Text(sendError).font(.caption).foregroundColor(Brand.redText).padding(.vertical, 4)
            }
            if let r = replyingTo { replyBar(r) }
            composer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.bg.ignoresSafeArea())
        .overlay { if let m = focusedMessage { focusOverlay(m) } }
        .animation(.easeOut(duration: 0.18), value: focusedMessage?.id)
        .animation(.easeOut(duration: 0.18), value: atBottom)
        .onAppear { _ = store.openConversation(personId) }
        .task {
            messages = store.conversations.first { $0.personId.lowercased() == personId.lowercased() }?.messages ?? []
            await load()
            Task { await subscribeRealtime() }
            Task { await subscribeTyping() }
            while !Task.isCancelled {
                lastSeen = await Backend.shared.lastSeen(personId)
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await load()   // también trae reacciones, borrados y el doble check azul
            }
        }
        .onDisappear { Task { await unsubscribe() } }
        .onChange(of: draft) { v in if !v.isEmpty { sendTyping() } }
        .sheet(isPresented: $showProfile) { ClubProfileView(personId: personId).environmentObject(store) }
        .sheet(isPresented: $attachMenu) {
            AttachSheet { choice in
                attachMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    switch choice {
                    case .camera: showCamera = true
                    case .photos: showLibrary = true
                    case .location: Task { await sendLocation() }
                    }
                }
            }
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

    private var statusLine: String? {
        if theyAreTyping { return L10n.t("typing…") }
        if isOnline { return L10n.t("online") }
        guard let d = lastSeen else { return nil }
        let t = DateFormatter(); t.locale = L10n.locale; t.timeStyle = .short
        if Calendar.current.isDateInToday(d) { return String(format: L10n.t("last seen today at %@"), t.string(from: d)) }
        if Calendar.current.isDateInYesterday(d) { return String(format: L10n.t("last seen yesterday at %@"), t.string(from: d)) }
        let f = DateFormatter(); f.locale = L10n.locale; f.setLocalizedDateFormatFromTemplate("MMMd")
        return String(format: L10n.t("last seen %@"), f.string(from: d))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { onClose() } label: {
                Image(systemName: "chevron.left").font(.system(size: 19, weight: .semibold)).foregroundColor(Brand.ink)
                    .frame(width: 34, height: 40)
            }
            Button { showProfile = true } label: {
                HStack(spacing: 10) {
                    PersonAvatar(person: person, size: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text(person?.name ?? "…").font(.system(size: 17, weight: .semibold)).foregroundColor(Brand.ink)
                            if let c = person?.club?.homeCountry, !c.isEmpty { Text(countryFlag(c)).font(.system(size: 14)) }
                        }
                        if let s = statusLine {
                            Text(s).font(.system(size: 12)).foregroundColor(theyAreTyping || isOnline ? Brand.online : Brand.muted)
                                .transition(.opacity)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        .animation(.easeInOut(duration: 0.2), value: statusLine)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Brand.bg).overlay(Divider(), alignment: .bottom)
    }

    private func daySeparator(_ d: Date) -> some View {
        let f = DateFormatter()
        f.locale = L10n.locale
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        return Text(f.string(from: d))
            .font(.system(size: 12, weight: .medium)).foregroundColor(Brand.ink.opacity(0.75))
            .padding(.horizontal, 10).frame(height: 24).background(Color.white.opacity(0.92)).clipShape(Capsule())
            .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            .padding(.vertical, 10)
    }

    private func quoted(_ m: ChatMessage) -> ChatMessage? {
        guard let r = m.replyTo else { return nil }
        return messages.first { $0.id == r }
    }

    // MARK: Mantener pulsado: reacciones y acciones

    private static let reactions = ["❤️", "👍", "😂", "😮", "😢", "🙏"]

    private func focusOverlay(_ m: ChatMessage) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.6))
                .onTapGesture { focusedMessage = nil }
            VStack(alignment: m.fromMe ? .trailing : .leading, spacing: 10) {
                if m.deleted != true {
                    HStack(spacing: 4) {
                        ForEach(Self.reactions, id: \.self) { e in
                            Button { react(m, e) } label: {
                                Text(e).font(.system(size: 28))
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(m.myReaction == e ? Brand.sand : Color.clear))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white).clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                }
                ChatBubble(message: m, quoted: quoted(m), tail: true, onOpen: {}, onReply: {}, onLongPress: {})
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    if m.deleted != true {
                        action("Reply", "arrowshape.turn.up.left") { reply(to: m) }
                        if m.type == "text" {
                            Divider()
                            action("Copy", "doc.on.doc") { UIPasteboard.general.string = m.text; focusedMessage = nil }
                        }
                    }
                    if m.fromMe && m.deleted != true {
                        Divider()
                        action("Delete for everyone", "trash", destructive: true) { delete(m) }
                    }
                }
                .frame(width: 240)
                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: m.fromMe ? .trailing : .leading)
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }

    private func action(_ title: LocalizedStringKey, _ icon: String, destructive: Bool = false, _ run: @escaping () -> Void) -> some View {
        Button { FX.tap(); run() } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: icon)
            }
            .font(.system(size: 16))
            .foregroundColor(destructive ? Brand.redText : Brand.ink)
            .padding(.horizontal, 16).frame(height: 46)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func reply(to m: ChatMessage) {
        guard m.deleted != true else { return }
        focusedMessage = nil
        replyingTo = m
        typing = true
    }

    private func react(_ m: ChatMessage, _ e: String) {
        let new = m.myReaction == e ? nil : e
        if let i = messages.firstIndex(where: { $0.id == m.id }) { messages[i].myReaction = new }
        focusedMessage = nil
        FX.success()
        Task { await Backend.shared.reactMessage(m.id, new) }
    }

    private func delete(_ m: ChatMessage) {
        if let i = messages.firstIndex(where: { $0.id == m.id }) {
            messages[i].deleted = true; messages[i].text = ""; messages[i].kind = "text"; messages[i].mediaURL = nil
        }
        focusedMessage = nil
        Task { await Backend.shared.deleteMessageForEveryone(m.id) }
    }

    private func replyBar(_ r: ChatMessage) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Brand.bronze).frame(width: 3).clipShape(Capsule())
            VStack(alignment: .leading, spacing: 2) {
                Text(r.fromMe ? L10n.t("You") : (person?.name ?? "")).font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.bronze)
                Text(r.preview).font(.system(size: 14)).foregroundColor(Brand.muted).lineLimit(1)
            }
            Spacer()
            Button { replyingTo = nil } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.muted).frame(width: 30, height: 30)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(height: 54)
        .background(Brand.chip)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Escribir

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if recorder.isRecording && recordLocked {
                HStack(spacing: 12) {
                    Button { recorder.cancel(); recordLocked = false; FX.warning() } label: {
                        Image(systemName: "trash").font(.system(size: 19)).foregroundColor(Brand.redText).frame(width: 40, height: 44)
                    }
                    Circle().fill(Brand.red).frame(width: 9, height: 9)
                        .opacity(Int(recorder.elapsed * 2) % 2 == 0 ? 1 : 0.35)
                    Text(timeString(recorder.elapsed)).font(.system(size: 16, weight: .medium).monospacedDigit()).foregroundColor(Brand.ink)
                    Spacer()
                    Text("Recording").font(.system(size: 14)).foregroundColor(Brand.muted)
                    Spacer()
                }
                .padding(.horizontal, 6).frame(height: 44)
                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .transition(.opacity)
            } else if recorder.isRecording {
                HStack(spacing: 10) {
                    Circle().fill(Brand.red).frame(width: 9, height: 9)
                        .opacity(Int(recorder.elapsed * 2) % 2 == 0 ? 1 : 0.35)
                    Text(timeString(recorder.elapsed)).font(.system(size: 16, weight: .medium).monospacedDigit()).foregroundColor(Brand.ink)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text("Slide to cancel").font(.system(size: 14))
                    }
                    .foregroundColor(Brand.muted)
                    .offset(x: max(-80, min(0, holdDragX)))
                    .opacity(1 + Double(max(-90, min(0, holdDragX))) / 120)
                    Spacer()
                }
                .padding(.horizontal, 14).frame(height: 44)
                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .transition(.opacity)
            } else {
                Button { typing = false; attachMenu = true } label: {
                    Image(systemName: "plus").font(.system(size: 22, weight: .regular)).foregroundColor(Brand.ink)
                        .frame(width: 36, height: 44)
                }
                HStack(alignment: .bottom, spacing: 6) {
                    TextField("Message", text: $draft, axis: .vertical)
                        .lineLimit(1...6)
                        .focused($typing)
                        .font(.system(size: 17))
                        .padding(.leading, 14).padding(.vertical, 10)
                    if draft.isEmpty {
                        // Cámara dentro del campo, como en WhatsApp.
                        Button { showCamera = true } label: {
                            Image(systemName: "camera").font(.system(size: 18)).foregroundColor(Brand.muted)
                                .frame(width: 36, height: 40)
                        }
                        .padding(.trailing, 4)
                    }
                }
                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Brand.line))
            }
            if recorder.isRecording && recordLocked {
                Button { recordLocked = false; Task { await sendVoice() } } label: {
                    Image(systemName: "paperplane.fill").font(.system(size: 17)).foregroundColor(Brand.onAccent)
                        .frame(width: 44, height: 44).background(Brand.accent).clipShape(Circle())
                }
            } else if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                micButton
            } else {
                Button { sendText() } label: {
                    Image(systemName: "paperplane.fill").font(.system(size: 17)).foregroundColor(Brand.onAccent)
                        .frame(width: 44, height: 44).background(Brand.accent).clipShape(Circle())
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: recorder.isRecording)
        .animation(.easeOut(duration: 0.15), value: draft.isEmpty)
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(Brand.bg).overlay(Divider(), alignment: .top)
    }

    /// Mantener para grabar, como en WhatsApp: soltar envía, deslizar a la izquierda cancela.
    private var micButton: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: recorder.isRecording ? 22 : 19))
            .foregroundColor(Brand.onAccent)
            .frame(width: recorder.isRecording ? 58 : 44, height: recorder.isRecording ? 58 : 44)
            .background(Circle().fill(Brand.accent))
            .offset(x: recorder.isRecording ? max(-90, min(0, holdDragX)) : 0,
                    y: recorder.isRecording ? max(-70, min(0, holdDragY)) : 0)
            .overlay(alignment: .top) {
                // Candado: deslizar hacia arriba para grabar sin mantener.
                if recorder.isRecording && !recordLocked {
                    VStack(spacing: 4) {
                        Image(systemName: holdDragY < -50 ? "lock.fill" : "lock.open").font(.system(size: 15))
                        Image(systemName: "chevron.up").font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Brand.ink)
                    .frame(width: 40, height: 64)
                    .background(Color.white).clipShape(Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                    .offset(y: -86 + max(-20, min(0, holdDragY / 3)))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !holding {
                            holding = true; holdCancelled = false; holdDragX = 0; holdDragY = 0; recordLocked = false
                            recorder.start()
                        }
                        guard !recordLocked, !holdCancelled else { return }
                        holdDragX = v.translation.width
                        holdDragY = v.translation.height
                        if holdDragY < -70 {
                            recordLocked = true; holdDragX = 0; holdDragY = 0
                            FX.success()
                        } else if holdDragX < -90 {
                            holdCancelled = true
                            recorder.cancel()
                            FX.warning()
                        }
                    }
                    .onEnded { _ in
                        holding = false
                        holdDragX = 0; holdDragY = 0
                        if holdCancelled { holdCancelled = false; return }
                        if recordLocked { return }   // sigue grabando hasta pulsar enviar
                        Task { await sendVoice() }
                    }
            )
            .accessibilityLabel(Text("Hold to record a voice message"))
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

    /// Lo refleja al instante (con la respuesta citada, si la hay) y lo manda al servidor.
    private func deliver(_ base: MessageInsert) {
        guard let uid = UUID(uuidString: personId) else { return }
        var m = base
        m.reply_to = replyingTo?.id
        replyingTo = nil
        let local = ChatMessage(id: UUID().uuidString, fromMe: true, text: m.text, at: Date(), kind: m.kind,
                                mediaURL: m.media_url, posterURL: m.poster_url, w: m.media_w, h: m.media_h,
                                duration: m.duration, lat: m.lat, lon: m.lon, read: false, replyTo: m.reply_to)
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
        do { deliver(insert(for: try await MediaUploader.upload(item))) }
        catch { sendError = (error as? LocalizedError)?.errorDescription ?? L10n.t("Couldn't send. Try again.") }
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

    private func sendLocation() async {
        sending += 1; defer { sending -= 1 }
        guard let c = await OneShotLocation().fetch() else {
            sendError = L10n.t("Couldn't get your location.")
            return
        }
        deliver(MessageInsert(sender_id: "", recipient_id: "", text: "", kind: "location", lat: c.latitude, lon: c.longitude))
    }

    private func sendVoice() async {
        guard let (file, seconds) = recorder.stop() else { return }
        guard seconds >= 1 else {
            try? FileManager.default.removeItem(at: file)
            sendError = L10n.t("Hold to record, release to send.")
            return
        }
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
        let cleared = store.chatSettings[personId.lowercased()]?.cleared_at.flatMap(BackendDate.parse)
        let fresh = rows.map { $0.message(me: me) }.filter { m in cleared.map { m.at > $0 } ?? true }
        let pending = messages.filter { m in m.fromMe && !fresh.contains { $0.id == m.id } && Date().timeIntervalSince(m.at) < 20 }
        messages = fresh + pending.filter { p in !fresh.contains { $0.fromMe && abs($0.at.timeIntervalSince(p.at)) < 20 && $0.type == p.type && $0.text == p.text } }
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
            theyAreTyping = false
            if !messages.contains(where: { $0.id == msg.id }) {
                messages.append(msg)
                store.appendLocalMessage(personId, msg)
            }
        }
    }

    /// «typing…» por Realtime (difusión, sin guardar nada): un canal por pareja.
    private func subscribeTyping() async {
        guard let client = Backend.shared.client, let me else { return }
        let pair = [me, personId.lowercased()].sorted().joined(separator: ":")
        let ch = client.channel("typing:\(pair)")
        let stream = ch.broadcastStream(event: "typing")
        await ch.subscribe()
        typingChannel = ch
        for await msg in stream {
            let from = msg["payload"]?.objectValue?["from"]?.stringValue ?? msg["from"]?.stringValue
            guard from == personId.lowercased() else { continue }
            theyAreTyping = true
            typingResetTask?.cancel()
            typingResetTask = Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if !Task.isCancelled { theyAreTyping = false }
            }
        }
    }

    private func sendTyping() {
        guard Date().timeIntervalSince(lastTypingSent) > 2, let ch = typingChannel, let me else { return }
        lastTypingSent = Date()
        Task { await ch.broadcast(event: "typing", message: ["from": .string(me)]) }
    }

    private func unsubscribe() async {
        guard let client = Backend.shared.client else { return }
        if let ch = channel { await client.removeChannel(ch) }
        if let ch = typingChannel { await client.removeChannel(ch) }
        channel = nil; typingChannel = nil
    }
}

// MARK: - Burbujas

struct ChatBubble: View {
    let message: ChatMessage
    var quoted: ChatMessage? = nil
    var tail = true
    var onOpen: () -> Void
    var onReply: () -> Void
    var onLongPress: () -> Void
    @State private var dragX: CGFloat = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.fromMe { Spacer(minLength: 60) }
            VStack(alignment: message.fromMe ? .trailing : .leading, spacing: -6) {
                content
                    .background(BubbleShape(fromMe: message.fromMe, tail: tail).fill(bubbleColor))
                    .shadow(color: .black.opacity(0.06), radius: 0.5, y: 1)
                if let r = reactionsText {
                    Text(r).font(.system(size: 14))
                        .padding(.horizontal, 6).frame(height: 24)
                        .background(Color.white).clipShape(Capsule())
                        .overlay(Capsule().stroke(Brand.bg, lineWidth: 2))
                        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                        .padding(.horizontal, 10)
                }
            }
            if !message.fromMe { Spacer(minLength: 60) }
        }
        .overlay(alignment: .leading) {
            // Icono de responder que aparece al deslizar.
            Image(systemName: "arrowshape.turn.up.left.fill").font(.system(size: 14)).foregroundColor(Brand.muted)
                .frame(width: 30, height: 30).background(Color.white.opacity(0.9)).clipShape(Circle())
                .opacity(Double(min(dragX, 60)) / 60)
                .offset(x: -36 + min(dragX, 60) * 0.6)
        }
        .offset(x: dragX)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.35) { onLongPress() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onChanged { v in
                    guard abs(v.translation.width) > abs(v.translation.height), v.translation.width > 0 else { return }
                    dragX = min(v.translation.width, 80)
                }
                .onEnded { _ in
                    if dragX > 55 { FX.tap(); onReply() }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { dragX = 0 }
                }
        )
    }

    private var reactionsText: String? {
        let r = [message.theirReaction, message.myReaction].compactMap { $0 }
        if r.isEmpty { return nil }
        return r.count == 2 && r[0] == r[1] ? "\(r[0]) 2" : r.joined()
    }

    private var bubbleColor: Color { message.fromMe ? Brand.sand : Color.white }

    @ViewBuilder
    private var quote: some View {
        if let q = quoted {
            HStack(spacing: 8) {
                Rectangle().fill(Brand.bronze).frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(q.fromMe ? L10n.t("You") : L10n.t("Them")).font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.bronze)
                    Text(q.preview).font(.system(size: 13)).foregroundColor(Brand.muted).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.trailing, 8).padding(.vertical, 5)
            .background(Brand.ink.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private var content: some View {
        if message.deleted == true {
            HStack(spacing: 5) {
                Image(systemName: "nosign").font(.system(size: 13))
                Text("This message was deleted").italic()
                meta
            }
            .font(.system(size: 15)).foregroundColor(Brand.muted)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .padding(message.fromMe ? .trailing : .leading, tail ? 6 : 0)
        } else {
            switch message.type {
            case "image", "video":
                VStack(alignment: .leading, spacing: 4) {
                    quote
                    Button(action: onOpen) {
                        ZStack {
                            RemoteFill(url: message.posterURL ?? message.mediaURL ?? "")
                            if message.type == "video" {
                                Image(systemName: "play.fill").font(.system(size: 20)).foregroundColor(.white)
                                    .frame(width: 48, height: 48).background(.black.opacity(0.4)).clipShape(Circle())
                            }
                        }
                        .frame(width: 230, height: 230 / mediaAspect)
                        .overlay(alignment: .bottomTrailing) {
                            meta.foregroundColor(.white).padding(.horizontal, 6).frame(height: 18)
                                .background(.black.opacity(0.35)).clipShape(Capsule()).padding(6)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }.buttonStyle(.plain)
                }
                .padding(4)
                .padding(message.fromMe ? .trailing : .leading, tail ? 6 : 0)
            case "location":
                VStack(alignment: .leading, spacing: 4) {
                    quote
                    Button { openInMaps() } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            MapSnapshot(lat: message.lat ?? 0, lon: message.lon ?? 0).frame(width: 230, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            HStack {
                                Label("Location", systemImage: "mappin.circle.fill").font(.system(size: 14, weight: .semibold))
                                Spacer()
                                meta.foregroundColor(Brand.muted)
                            }
                            .foregroundColor(Brand.ink).padding(.horizontal, 6).padding(.vertical, 6)
                        }
                    }.buttonStyle(.plain)
                }
                .frame(width: 238)
                .padding(4)
                .padding(message.fromMe ? .trailing : .leading, tail ? 6 : 0)
            case "audio":
                VStack(alignment: .leading, spacing: 4) {
                    quote
                    AudioBubble(url: message.mediaURL ?? "", duration: message.duration ?? 0) { meta }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .padding(message.fromMe ? .trailing : .leading, tail ? 6 : 0)
            default:
                VStack(alignment: .leading, spacing: 4) {
                    quote
                    // La hora va pegada al final del texto, como en WhatsApp.
                    (Text(message.preview).font(.system(size: 16)).foregroundColor(Brand.ink)
                     + Text(message.fromMe ? "          ‎ " : "      ‎ ").font(.system(size: 11)))
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay(alignment: .bottomTrailing) { meta.foregroundColor(Brand.muted).offset(y: 2) }
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .padding(message.fromMe ? .trailing : .leading, tail ? 6 : 0)
            }
        }
    }

    private var mediaAspect: CGFloat {
        guard let w = message.w, let h = message.h, w > 0, h > 0 else { return 1 }
        return min(max(CGFloat(w) / CGFloat(h), 0.6), 1.6)
    }

    /// Hora + doble check (azul si la otra persona ya lo ha leído).
    private var meta: some View {
        HStack(spacing: 3) {
            Text(message.at, style: .time).font(.system(size: 11))
            if message.fromMe && message.deleted != true {
                ZStack {
                    Image(systemName: "checkmark").offset(x: -2.5)
                    Image(systemName: "checkmark").offset(x: 1.5)
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(message.read == true ? Color(hex: "3b9ae8") : Brand.soft)
            }
        }
    }

    private func openInMaps() {
        guard let lat = message.lat, let lon = message.lon else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
        item.name = message.fromMe ? L10n.t("My location") : L10n.t("Shared location")
        item.openInMaps()
    }
}

/// Burbuja con «colita» en la última de cada grupo, como en WhatsApp.
struct BubbleShape: Shape {
    let fromMe: Bool
    let tail: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        let tailW: CGFloat = tail ? 6 : 0
        let body = fromMe ? CGRect(x: rect.minX, y: rect.minY, width: rect.width - tailW, height: rect.height)
                          : CGRect(x: rect.minX + tailW, y: rect.minY, width: rect.width - tailW, height: rect.height)
        var p = Path(roundedRect: body, cornerRadius: r, style: .continuous)
        if tail {
            if fromMe {
                p.move(to: CGPoint(x: body.maxX - 10, y: body.maxY))
                p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: body.maxX - 2, y: body.maxY))
                p.addQuadCurve(to: CGPoint(x: body.maxX, y: body.maxY - 14), control: CGPoint(x: body.maxX, y: body.maxY - 4))
                p.addLine(to: CGPoint(x: body.maxX - 10, y: body.maxY))
            } else {
                p.move(to: CGPoint(x: body.minX + 10, y: body.maxY))
                p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: body.minX + 2, y: body.maxY))
                p.addQuadCurve(to: CGPoint(x: body.minX, y: body.maxY - 14), control: CGPoint(x: body.minX, y: body.maxY - 4))
                p.addLine(to: CGPoint(x: body.minX + 10, y: body.maxY))
            }
        }
        return p
    }
}

/// «…» mientras la otra persona escribe.
struct TypingBubble: View {
    var body: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 0.35)) { ctx in
                let step = Int(ctx.date.timeIntervalSince1970 / 0.35) % 3
                HStack(spacing: 4) {
                    ForEach(0..<3) { i in
                        Circle().fill(Brand.muted).frame(width: 7, height: 7).opacity(i == step ? 1 : 0.35)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .padding(.leading, 6)
                .background(BubbleShape(fromMe: false, tail: true).fill(Color.white))
            }
            Spacer()
        }
    }
}

/// Fondo del chat: marfil con un motivo muy suave de Bali (olas, palmeras, sol).
struct ChatWallpaper: View {
    var body: some View {
        Canvas { ctx, size in
            let symbols = ["water.waves", "sun.max", "leaf", "figure.surfing", "cup.and.saucer", "moon.stars"]
            let step: CGFloat = 78
            var row = 0
            var y: CGFloat = 10
            while y < size.height + step {
                var x: CGFloat = (row % 2 == 0) ? 12 : 12 + step / 2
                var i = row
                while x < size.width + step {
                    let img = ctx.resolve(Image(systemName: symbols[i % symbols.count]))
                    ctx.opacity = 0.07
                    ctx.draw(img, in: CGRect(x: x, y: y, width: 22, height: 22))
                    x += step; i += 1
                }
                y += step * 0.75; row += 1
            }
        }
        .background(Color(hex: "efe9df"))
    }
}

import MapKit
import CoreLocation
