import SwiftUI

private struct FeedItem: Identifiable {
    let id: String
    let personId: String?       // nil => me
    let authorName: String
    let avatarPhoto: Data?
    let avatarEmoji: String
    let flag: String
    let location: String
    let date: Date
    let title: String
    let note: String
    let photo: Data?
    let elapsed: Int
    let exercises: Int
    let sets: Int
    let volume: Double
    let items: [SessionExercise]
    var avgHeartRate: Int? = nil
    var maxHeartRate: Int? = nil
}

/// Comentario de un post (local). Soporta respuestas (1 nivel), likes y fecha.
private struct PostComment: Identifiable {
    let id: String
    var authorName: String
    var authorEmoji: String     // vacío => usa el avatar de tu cuenta
    var isMe: Bool
    var text: String
    var date: Date
    var likes: Int
    var liked: Bool
    var replies: [PostComment]
}

struct SocialFeedView: View {
    @EnvironmentObject var store: AppStore
    var onOpenProfile: (String) -> Void
    var onOpenMyProfile: () -> Void = {}

    @State private var segment = 0
    @State private var activity: FeedItem?
    @State private var commentTarget: FeedItem?
    @State private var likesOfPost: FeedItem?
    @State private var comments: [String: [PostComment]] = [:]
    @State private var toast: String?
    // El feed es un snapshot: no se reorganiza al seguir a alguien; solo cambia al refrescar (pull-to-refresh).
    @State private var seguidosFeed: [FeedItem] = []
    @State private var seguidosLoaded = false
    @State private var seguidosNewUser = true   // modo de layout congelado hasta el refresh
    @State private var showInterleavedSuggestions = false
    @State private var suggestionsSnapshot: [SocialPerson] = []
    @State private var paraTiFeed: [FeedItem] = []
    @State private var paraTiLoaded = false

    private let tabs: [(title: String, icon: String)] = [("Seguidos", "person.2.fill"), ("Para ti", "sparkles")]

    var body: some View {
        VStack(spacing: 0) {
            switcher
            ZStack {
                seguidosTab.opacity(segment == 0 ? 1 : 0).allowsHitTesting(segment == 0)
                paraTiTab.opacity(segment == 1 ? 1 : 0).allowsHitTesting(segment == 1)
            }
        }
        .background(Brand.bg)
        .overlay(alignment: .bottom) { toastView }
        .sheet(item: $activity) { ActivityDetailView(item: feedItemView($0)).environmentObject(store) }
        .sheet(item: $commentTarget) { item in
            CommentsSheet(title: item.title, comments: Binding(
                get: { comments[item.id] ?? [] },
                set: { comments[item.id] = $0 }))
                .environmentObject(store)
        }
        .sheet(item: $likesOfPost) { postLikesSheet($0) }
    }

    // MARK: - Me gusta de una publicación

    @ViewBuilder
    private func postLikesSheet(_ item: FeedItem) -> some View {
        let liked = store.appliedKudos.contains(item.id)
        let others = kudos(item)                      // likes de la comunidad (sin contar el tuyo)
        let people = Array(postLikers(item).prefix(others))
        let remaining = max(0, others - people.count)
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if liked { likeRow(emoji: "", name: store.account?.name ?? "Tú", handle: store.account?.handle ?? "tu_usuario", isMe: true) }
                    ForEach(people) { p in likeRow(emoji: p.avatar, name: p.name, handle: p.handle, isMe: false) }
                    if remaining > 0 {
                        Text("y \(remaining) persona\(remaining == 1 ? "" : "s") más")
                            .font(.footnote).foregroundColor(Brand.muted)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                }.padding(.vertical, 8)
            }
            .background(Brand.bg)
            .navigationTitle("Me gusta").navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func likeRow(emoji: String, name: String, handle: String, isMe: Bool) -> some View {
        HStack(spacing: 11) {
            if isMe { MeAvatar(account: store.account, size: 40) } else { Avatar(emoji: emoji, size: 40) }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                Text("@\(handle)").font(.caption2).foregroundColor(Brand.soft)
            }
            Spacer()
            Image(systemName: "heart.fill").font(.system(size: 14)).foregroundColor(Brand.red)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    /// Lista determinista de quién dio like a una publicación (demo).
    private func postLikers(_ item: FeedItem) -> [SocialPerson] {
        guard !store.people.isEmpty else { return [] }
        var seed: UInt64 = 7
        for ch in item.id.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
        let start = Int(seed % UInt64(store.people.count))
        return Array(store.people[start...] + store.people[..<start])
    }

    // MARK: - Switcher

    private var switcher: some View {
        HStack(spacing: 6) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { idx, t in
                let active = segment == idx
                Button { FX.selection(); withAnimation { segment = idx } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: t.icon).font(.system(size: 13, weight: .heavy))
                        Text(t.title).font(.system(size: 14, weight: .heavy))
                    }
                    .foregroundColor(active ? Color(hex: "10150a") : Brand.soft)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(active ? Brand.green : Brand.chip)
                    .clipShape(RoundedRectangle(cornerRadius: 12)).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.top, 2).padding(.bottom, 8)
    }

    // MARK: - SEGUIDOS

    private var seguidosTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if seguidosNewUser {
                    // Usuario nuevo: sugerencias arriba (activación) + feed de cercanos.
                    // El modo se congela hasta el próximo refresh: seguir a alguien NO
                    // reorganiza el muro al instante (las sugerencias solo se bajan al refrescar).
                    newUserHeader
                    if hasSuggestions { suggestionsStrip }
                    if seguidosFeed.isEmpty {
                        emptyFeed("Sigue a atletas o registra un entreno para llenar tu muro.")
                    } else {
                        ForEach(seguidosFeed) { item in feedCard(item) }
                    }
                } else if seguidosFeed.isEmpty {
                    if hasSuggestions { suggestionsStrip }
                    emptyFeed("Registra un entreno o desliza para refrescar tu muro.")
                } else {
                    // Con seguidos: las sugerencias se INTERCALAN entre posts, pero solo tras refrescar (no automático).
                    let insertAt = min(2, seguidosFeed.count - 1)
                    ForEach(Array(seguidosFeed.enumerated()), id: \.element.id) { idx, item in
                        feedCard(item)
                        if showInterleavedSuggestions && hasSuggestions && idx == insertAt { suggestionsStrip }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { refreshSeguidos(manual: true) }
        }
        .onAppear { if !seguidosLoaded { refreshSeguidos(manual: false) } }
    }

    private func feedCard(_ item: FeedItem) -> some View {
        card(item, showFollow: item.personId != nil && store.relationship(item.personId ?? "") == .none)
    }

    private func refreshSeguidos(manual: Bool) {
        // Congela el modo de layout (usuario nuevo vs con seguidos) en el momento del refresh.
        seguidosNewUser = store.following.isEmpty
        seguidosFeed = store.following.isEmpty
            ? (myItems + discoverFeed).sorted { $0.date > $1.date }
            : followedFeed
        // Las recomendaciones son un snapshot: solo se rehacen (quitando a quien ya sigues) al refrescar.
        suggestionsSnapshot = nearbyPeople(limit: 10)
        // Las sugerencias intercaladas aparecen al refrescar manualmente, no en la carga inicial.
        if manual { showInterleavedSuggestions = true }
        seguidosLoaded = true
    }

    private var newUserHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Hola, \(store.account?.name ?? "atleta") 👋").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
            Text("Pon en marcha tu Forge Loop").font(.footnote).foregroundColor(Brand.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - PARA TI (solo posts de gente cercana que aún no sigues)

    private var paraTiTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if paraTiFeed.isEmpty {
                    emptyFeed("No hay entrenos por descubrir ahora mismo. ¡Vuelve pronto!")
                } else {
                    ForEach(paraTiFeed) { item in
                        card(item, showFollow: item.personId != nil && store.relationship(item.personId ?? "") == .none)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { refreshParaTi() }
        }
        .onAppear { if !paraTiLoaded { refreshParaTi() } }
    }

    private func refreshParaTi() {
        paraTiFeed = discoverFeed
        paraTiLoaded = true
    }

    private var hasSuggestions: Bool { !suggestionsSnapshot.isEmpty }

    private func emptyFeed(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.run").font(.system(size: 34)).foregroundColor(Brand.soft)
            Text(msg).font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.top, 40)
    }

    private func sectionHeader(_ t: String) -> some View {
        HStack { Text(t).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted); Spacer() }
            .padding(.horizontal, 4).padding(.top, 4)
    }

    // MARK: - Sugerencias (tira horizontal deslizable, estilo Strava)

    private var suggestionsStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("A QUIÉN SEGUIR")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestionsSnapshot) { p in suggestionCard(p) }
                }
                .padding(.horizontal, 4).padding(.bottom, 2)
            }
        }
    }

    private func suggestionCard(_ p: SocialPerson) -> some View {
        VStack(spacing: 8) {
            Button { FX.tap(); onOpenProfile(p.id) } label: {
                ZStack(alignment: .bottomTrailing) {
                    Avatar(emoji: p.avatar, size: 60)
                    Text(p.flag).font(.system(size: 12)).frame(width: 19, height: 19)
                        .background(Circle().fill(.white)).overlay(Circle().stroke(Brand.line)).offset(x: 3, y: 3)
                }
            }.buttonStyle(.plain)
            VStack(spacing: 1) {
                Text(p.name).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                Text("@\(p.handle)").font(.caption2).foregroundColor(Brand.soft).lineLimit(1)
            }
            let rel = store.relationship(p.id)
            let label = rel == .friends ? "Siguiendo" : (rel == .outgoing ? "Pendiente" : "Seguir")
            Button { if rel == .none { followPerson(p) } } label: {
                Text(label).font(.system(size: 13, weight: .heavy)).foregroundColor(rel == .none ? Color(hex: "10150a") : Brand.ink)
                    .frame(maxWidth: .infinity).frame(height: 32).background(rel == .none ? Brand.green : Brand.chip).clipShape(Capsule())
            }.buttonStyle(.plain).disabled(rel != .none)
        }
        .padding(12).frame(width: 140)
        .background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
    }

    private func followPerson(_ p: SocialPerson) {
        FX.success()
        if store.relationship(p.id) == .incoming {
            store.acceptFriendRequest(p.id); showToast("Ahora sigues a \(p.name)")
        } else {
            store.followOrRequest(p.id)
            showToast(p.isPrivate ? "Solicitud enviada a \(p.name)" : "Ahora sigues a \(p.name)")
        }
    }

    /// Toca el avatar/nombre de un post → su perfil (el tuyo si el post es tuyo).
    private func openProfile(_ item: FeedItem) {
        FX.tap()
        if let pid = item.personId { onOpenProfile(pid) } else { onOpenMyProfile() }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { if toast == text { toast = nil } }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let t = toast {
            Text(t).font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Brand.ink).clipShape(Capsule())
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Cercanía

    /// Personas que no sigues, ordenadas de más cerca a más lejos.
    private func nearbyPeople(limit: Int) -> [SocialPerson] {
        Array(store.people.filter { store.relationship($0.id) == .none }
            .sorted { distanceMeters($0) < distanceMeters($1) }
            .prefix(limit))
    }

    /// Orden de cercanía determinista por persona (no se muestra la distancia).
    private func distanceMeters(_ p: SocialPerson) -> Double {
        var seed: UInt64 = 0
        for ch in p.id.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
        return Double(seed % 100000)
    }

    // MARK: - Card

    private func feedItemView(_ item: FeedItem) -> ActivityData {
        ActivityData(authorName: item.authorName, avatarPhoto: item.avatarPhoto, avatarEmoji: item.avatarEmoji,
                     flag: item.flag, location: item.location, date: item.date, title: item.title, note: item.note,
                     photo: item.photo, elapsed: item.elapsed, exercises: item.exercises, sets: item.sets,
                     volume: item.volume, items: item.items,
                     avgHeartRate: item.avgHeartRate, maxHeartRate: item.maxHeartRate)
    }

    private func card(_ item: FeedItem, showFollow: Bool = false) -> some View {
        PanelCard {
            // Cabecera: avatar/nombre abre el PERFIL (zona de toque propia).
            HStack(spacing: 11) {
                Button { openProfile(item) } label: {
                    HStack(spacing: 11) {
                        ZStack(alignment: .bottomTrailing) {
                            authorAvatar(item)
                            Text(item.flag).font(.system(size: 11)).frame(width: 17, height: 17)
                                .background(Circle().fill(.white)).overlay(Circle().stroke(Brand.line)).offset(x: 3, y: 3)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.authorName).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                            HStack(spacing: 5) {
                                Text(relativeTime(item.date))
                                if !item.location.isEmpty {
                                    Text("·"); Image(systemName: "mappin.and.ellipse").font(.system(size: 9)); Text(item.location)
                                }
                            }.font(.caption2).foregroundColor(Brand.soft)
                        }
                    }
                }.buttonStyle(.plain)
                Spacer()
                if showFollow, let pid = item.personId, let p = store.person(pid) {
                    Button { followPerson(p) } label: {
                        Text("Seguir").font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                            .padding(.horizontal, 12).frame(height: 30).background(Brand.green).clipShape(Capsule())
                    }.buttonStyle(.plain)
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                }
            }

            Rectangle().fill(Brand.line).frame(height: 1)   // separa persona de contenido

            // Cuerpo: abre el DETALLE del entreno.
            Button { FX.tap(); activity = item } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        WorkoutTypeBadge(size: .full)
                        Text(item.title).font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                    }
                    if !item.note.isEmpty {
                        Text(item.note).font(.system(size: 14)).foregroundColor(Color(hex: "2c3127")).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                    if let data = item.photo { WorkoutPhoto(data: data, height: 190) }
                    WorkoutStatStrip(stats: WorkoutStatStrip.metrics(time: durationText(item.elapsed), sets: item.sets,
                                                     exercises: item.exercises, ppm: item.avgHeartRate), style: .full)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)

            // Acciones estilo Instagram: like (corazón), comentario, compartir (avión), con contadores.
            HStack(spacing: 20) {
                LikeButton(id: item.id, baseCount: kudos(item), onShowLikes: { likesOfPost = item }).environmentObject(store)

                Button {
                    FX.tap()
                    if comments[item.id] == nil { comments[item.id] = demoComments(for: item) }
                    commentTarget = item
                } label: {
                    actionIcon("bubble.right", "\(commentTotal(item))", tint: Brand.ink)
                }.buttonStyle(.plain)

                ShareLink(item: shareText(item)) {
                    actionIcon("paperplane", "\(shareBase(item))", tint: Brand.ink)
                }.buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 2)
        }
    }

    private func actionIcon(_ icon: String, _ count: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundColor(tint)
            Text(count).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.ink)
        }
    }

    private func shareBase(_ item: FeedItem) -> Int {
        var s: UInt64 = 5
        for ch in item.id.unicodeScalars { s = s &* 17 &+ UInt64(ch.value) }
        return 1 + Int(s % 9)
    }

    private func commentTotal(_ item: FeedItem) -> Int {
        let list = comments[item.id] ?? demoComments(for: item)
        return list.reduce(0) { $0 + 1 + $1.replies.count }
    }

    /// Comentarios demo deterministas por post (de gente de la comunidad), para que el muro se sienta vivo.
    private func demoComments(for item: FeedItem) -> [PostComment] {
        guard !store.people.isEmpty else { return [] }
        var seed: UInt64 = 0
        for ch in item.id.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
        let texts = ["¡Bestia! 🔥", "Qué máquina 💪", "Buen volumen", "Vaya progreso 👏", "Crack", "Esto es constancia", "Menudo PR 😳", "A tope!"]
        let replyTexts = ["¡Gracias! 🙌", "Aquí seguimos 💪", "jaja gracias crack", "¡Vamos!"]
        let n = Int(seed % 4)   // 0..3 comentarios
        var out: [PostComment] = []
        for i in 0..<n {
            let p = store.people[Int((seed / UInt64(i + 1)) % UInt64(store.people.count))]
            let mins = Int((seed >> (i * 3)) % 1440) + 2
            var replies: [PostComment] = []
            if i == 0 && seed % 2 == 0 {
                replies.append(PostComment(
                    id: "\(item.id)-r0", authorName: item.authorName,
                    authorEmoji: item.personId == nil ? "" : item.avatarEmoji, isMe: item.personId == nil,
                    text: replyTexts[Int(seed % UInt64(replyTexts.count))],
                    date: Date().addingTimeInterval(-Double(max(1, mins - 7)) * 60),
                    likes: Int(seed % 3), liked: false, replies: []))
            }
            out.append(PostComment(
                id: "\(item.id)-c\(i)", authorName: p.name, authorEmoji: p.avatar, isMe: false,
                text: texts[Int((seed >> (i * 2)) % UInt64(texts.count))],
                date: Date().addingTimeInterval(-Double(mins) * 60),
                likes: Int((seed >> i) % 14), liked: false, replies: replies))
        }
        return out
    }

    private func shareText(_ item: FeedItem) -> String {
        "\(item.authorName) entrenó \(item.title): \(item.sets) series · \(durationText(item.elapsed)). 💪 vía Forge Loop"
    }

    @ViewBuilder
    private func authorAvatar(_ item: FeedItem) -> some View {
        if let d = item.avatarPhoto, let ui = UIImage(data: d) {
            Image(uiImage: ui).resizable().scaledToFill().frame(width: 42, height: 42).clipShape(Circle())
        } else {
            Avatar(emoji: item.avatarEmoji, size: 42)
        }
    }

    private func durationText(_ s: Int) -> String {
        let m = s / 60
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(max(1, m)) min"
    }

    private func kudos(_ item: FeedItem) -> Int {
        var seed: UInt64 = 0
        for ch in item.id.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
        return 3 + Int(seed % 22)
    }

    // MARK: - Feed sources

    private var myItems: [FeedItem] {
        let loc = [store.profile.city, store.profile.country].filter { !$0.isEmpty }.joined(separator: ", ")
        return store.sessions.map { s in
            FeedItem(
                id: s.id, personId: nil, authorName: store.account?.name ?? "Tú",
                avatarPhoto: store.account?.photoData, avatarEmoji: "🙂",
                flag: countryFlag(store.profile.country), location: loc,
                date: s.date, title: s.name, note: s.note, photo: s.photoData,
                elapsed: s.elapsed, exercises: s.exercises, sets: s.sets, volume: s.volume,
                items: s.items ?? [], avgHeartRate: s.avgHeartRate, maxHeartRate: s.maxHeartRate)
        }
    }

    private var followedFeed: [FeedItem] {
        (myItems + posts(for: store.following)).sorted { $0.date > $1.date }
    }

    private var discoverFeed: [FeedItem] {
        let strangers = store.people.filter { store.relationship($0.id) == .none }
            .sorted { distanceMeters($0) < distanceMeters($1) }
        return Array(posts(for: strangers).prefix(12))
    }

    private let friendNotes = ["", "Buenas sensaciones hoy 💪", "", "PR en el último ejercicio 🔥", "", "Día duro pero hecho ✅"]

    private func posts(for people: [SocialPerson]) -> [FeedItem] {
        var items: [FeedItem] = []
        for p in people {
            let history = buildFriendHistory(p)
            let sessions = Dictionary(grouping: history) { $0.sessionId ?? $0.id }
            let recent = sessions.values
                .sorted { ($0.first?.completedAt ?? .distantPast) > ($1.first?.completedAt ?? .distantPast) }
                .prefix(2)
            for (idx, entries) in recent.enumerated() {
                let date = entries.map { $0.completedAt }.max() ?? Date()
                let sets = entries.reduce(0) { $0 + $1.sets }
                let sid = entries.first?.sessionId ?? "\(p.id)-post-\(idx)"
                var seed: UInt64 = 0
                for ch in sid.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
                let avgHR = 118 + Int(seed % 42)                 // 118–159 ppm
                let maxHR = avgHR + 12 + Int((seed >> 5) % 22)   // +12..+33
                items.append(FeedItem(
                    id: sid, personId: p.id, authorName: p.name,
                    avatarPhoto: nil, avatarEmoji: p.avatar, flag: p.flag,
                    location: "\(p.city), \(p.country)", date: date,
                    title: Self.title(for: entries), note: friendNotes[Int(seed % UInt64(friendNotes.count))],
                    photo: nil, elapsed: entries.count * 240 + sets * 40,
                    exercises: entries.count, sets: sets,
                    volume: entries.reduce(0) { $0 + $1.volume },
                    items: entries.map { e in
                        let logs = (0..<max(1, e.sets)).map { i in
                            SetLog(reps: e.reps, weight: max(0, e.weight + Double(i) * 2.5 - Double(max(0, e.sets - 1)) * 1.25))
                        }
                        return SessionExercise(name: e.exerciseName, sets: e.sets, reps: e.reps, weight: e.weight, logs: logs)
                    },
                    avgHeartRate: avgHR, maxHeartRate: maxHR))
            }
        }
        return items
    }

    private static func title(for entries: [HistoryEntry]) -> String {
        var counts: [String: Int] = [:]
        for e in entries { counts[GymScoreEngine.pattern(for: e.exerciseName).group, default: 0] += 1 }
        let top = counts.max { $0.value < $1.value }?.key ?? "accesorio"
        let names = ["pierna": "Pierna", "bisagra": "Cadena posterior", "empuje": "Empuje",
                     "tiron": "Tirón", "condicion": "Cardio & core", "accesorio": "Full body"]
        return names[top] ?? "Entreno"
    }
}

/// Hoja de comentarios de un post estilo Instagram: respuestas (1 nivel), likes
/// por comentario y antigüedad ("hace ..."). Almacenado localmente.
private struct CommentsSheet: View {
    @EnvironmentObject var store: AppStore
    let title: String
    @Binding var comments: [PostComment]
    @State private var draft = ""
    @State private var replyTo: String?
    @State private var replyToName: String?
    @State private var likesOf: PostComment?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if comments.isEmpty {
                            emptyState
                        } else {
                            ForEach(comments) { c in
                                commentRow(c, isReply: false)
                                ForEach(c.replies) { r in commentRow(r, isReply: true) }
                            }
                        }
                    }
                    .padding(16)
                }
                composer
            }
            .background(Brand.bg)
            .navigationTitle("Comentarios").navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .sheet(item: $likesOf) { likesSheet($0) }
    }

    @ViewBuilder
    private func likesSheet(_ c: PostComment) -> some View {
        let otherTarget = max(0, c.likes - (c.liked ? 1 : 0))
        let people = Array(likers(for: c).prefix(otherTarget))
        let remaining = max(0, otherTarget - people.count)
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if c.liked { likeRow(emoji: "", name: store.account?.name ?? "Tú", handle: store.account?.handle ?? "tu_usuario", isMe: true) }
                    ForEach(people) { p in likeRow(emoji: p.avatar, name: p.name, handle: p.handle, isMe: false) }
                    if remaining > 0 {
                        Text("y \(remaining) persona\(remaining == 1 ? "" : "s") más")
                            .font(.footnote).foregroundColor(Brand.muted)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                }.padding(.vertical, 8)
            }
            .background(Brand.bg)
            .navigationTitle("Me gusta").navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func likeRow(emoji: String, name: String, handle: String, isMe: Bool) -> some View {
        HStack(spacing: 11) {
            if isMe { MeAvatar(account: store.account, size: 40) } else { Avatar(emoji: emoji, size: 40) }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                Text("@\(handle)").font(.caption2).foregroundColor(Brand.soft)
            }
            Spacer()
            Image(systemName: "heart.fill").font(.system(size: 14)).foregroundColor(Brand.red)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    /// Lista determinista de quién dio like a un comentario (demo).
    private func likers(for c: PostComment) -> [SocialPerson] {
        guard !store.people.isEmpty, c.likes > 0 else { return [] }
        var seed: UInt64 = 0
        for ch in c.id.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
        let start = Int(seed % UInt64(store.people.count))
        return Array(store.people[start...] + store.people[..<start])
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 34)).foregroundColor(Brand.soft)
            Text("Sé el primero en comentar").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
            Text("Anima a quien ha entrenado 💬").font(.footnote).foregroundColor(Brand.muted)
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }

    private func commentRow(_ c: PostComment, isReply: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            avatar(c)
            VStack(alignment: .leading, spacing: 4) {
                (Text(c.authorName).font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
                 + Text("  ").font(.system(size: 14))
                 + Text(c.text).font(.system(size: 14)).foregroundColor(Color(hex: "2c3127")))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Text(commentTime(c.date))
                    Button("Responder") { startReply(c, isReply: isReply) }
                }
                .font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.soft)
            }
            Spacer()
            Button { toggleLike(c.id) } label: {
                VStack(spacing: 2) {
                    Image(systemName: c.liked ? "heart.fill" : "heart")
                        .font(.system(size: 14)).foregroundColor(c.liked ? Brand.red : Brand.soft)
                    if c.likes > 0 {
                        Text("\(c.likes)").font(.system(size: 11, weight: .semibold)).foregroundColor(Brand.soft)
                    }
                }
            }
            .buttonStyle(.plain)
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                if c.likes > 0 { FX.tap(); likesOf = c }
            })
        }
        .padding(.leading, isReply ? 42 : 0)
    }

    private var composer: some View {
        VStack(spacing: 0) {
            if let name = replyToName {
                HStack {
                    Text("Respondiendo a \(name)").font(.caption).foregroundColor(Brand.muted)
                    Spacer()
                    Button { replyTo = nil; replyToName = nil } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundColor(Brand.soft)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 6).background(Brand.chip)
            }
            Divider()
            HStack(spacing: 10) {
                TextField(replyToName == nil ? "Añade un comentario…" : "Añade una respuesta…", text: $draft, axis: .vertical)
                    .font(.system(size: 15)).focused($focused)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 18))
                    .lineLimit(1...4)
                Button { post() } label: {
                    Image(systemName: "paperplane.fill").font(.system(size: 16, weight: .heavy))
                        .foregroundColor(canPost ? Color(hex: "10150a") : Brand.soft)
                        .frame(width: 38, height: 38)
                        .background(canPost ? Brand.green : Brand.chip).clipShape(Circle())
                }.disabled(!canPost)
            }
            .padding(.horizontal, 14).padding(.vertical, 10).background(Brand.bg)
        }
    }

    @ViewBuilder
    private func avatar(_ c: PostComment) -> some View {
        if c.isMe { MeAvatar(account: store.account, size: 32) }
        else { Avatar(emoji: c.authorEmoji.isEmpty ? "🙂" : c.authorEmoji, size: 32) }
    }

    private var canPost: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Antigüedad estilo Instagram: "34 min" → "6 h" → "2 d" → "d MMM yyyy".
    private func commentTime(_ date: Date) -> String {
        let mins = Int(max(0, -date.timeIntervalSinceNow) / 60)
        if mins < 1 { return "ahora" }
        if mins < 60 { return "\(mins) min" }
        let hours = mins / 60
        if hours < 24 { return "\(hours) h" }
        let days = hours / 24
        if days < 7 { return "\(days) d" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }

    private func startReply(_ c: PostComment, isReply: Bool) {
        if isReply {
            replyTo = comments.first(where: { $0.replies.contains(where: { $0.id == c.id }) })?.id
        } else {
            replyTo = c.id
        }
        replyToName = c.authorName
        focused = true
    }

    private func post() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        FX.tap()
        let new = PostComment(id: UUID().uuidString, authorName: store.account?.name ?? "Tú",
                              authorEmoji: "", isMe: true, text: t, date: Date(), likes: 0, liked: false, replies: [])
        if let pid = replyTo, let i = comments.firstIndex(where: { $0.id == pid }) {
            comments[i].replies.append(new)
        } else {
            comments.append(new)
        }
        draft = ""; replyTo = nil; replyToName = nil; focused = false
    }

    private func toggleLike(_ id: String) {
        FX.tap()
        if let i = comments.firstIndex(where: { $0.id == id }) {
            comments[i].liked.toggle()
            comments[i].likes += comments[i].liked ? 1 : -1
            return
        }
        for pi in comments.indices {
            if let ri = comments[pi].replies.firstIndex(where: { $0.id == id }) {
                comments[pi].replies[ri].liked.toggle()
                comments[pi].replies[ri].likes += comments[pi].replies[ri].liked ? 1 : -1
                return
            }
        }
    }
}

/// Botón de like del muro con animación: el corazón hace pop y, al dar like,
/// brota una pequeña explosión de corazones (estilo Instagram).
private struct LikeButton: View {
    @EnvironmentObject var store: AppStore
    let id: String
    let baseCount: Int
    var onShowLikes: () -> Void = {}
    @State private var pop: CGFloat = 1
    @State private var burst = false

    private var liked: Bool { store.appliedKudos.contains(id) }
    private var total: Int { baseCount + (liked ? 1 : 0) }

    var body: some View {
        HStack(spacing: 6) {
            // El corazón da/quita like (con animación).
            Button {
                let wasLiked = liked
                store.toggleKudo(id)
                if wasLiked {
                    FX.tap()
                } else {
                    Haptics.rigid()
                    pop = 0.6
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.38)) { pop = 1.35 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { pop = 1 }
                    }
                    burst = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { burst = false }
                }
            } label: {
                ZStack {
                    if burst { HeartBurst() }
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(liked ? Brand.red : Brand.ink)
                        .scaleEffect(pop)
                }
            }.buttonStyle(.plain)

            // El número abre la lista de a quién le gusta (como en los comentarios).
            Button { if total > 0 { FX.tap(); onShowLikes() } } label: {
                Text("\(total)")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.ink)
                    .contentTransition(.numericText())
            }.buttonStyle(.plain).disabled(total == 0)
        }
    }
}

/// Pequeños corazones que salen disparados al dar like.
private struct HeartBurst: View {
    @State private var go = false
    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) / 6 * 2 * .pi
                Image(systemName: "heart.fill")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(Brand.red)
                    .offset(x: go ? CGFloat(cos(angle)) * 22 : 0, y: go ? CGFloat(sin(angle)) * 22 : 0)
                    .scaleEffect(go ? 0.3 : 0.9)
                    .opacity(go ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.55)) { go = true } }
    }
}
