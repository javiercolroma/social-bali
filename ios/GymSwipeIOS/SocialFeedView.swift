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
    var photoURL: String? = nil
    let elapsed: Int
    let exercises: Int
    let sets: Int
    let volume: Double
    let items: [SessionExercise]
    var avgHeartRate: Int? = nil
    var maxHeartRate: Int? = nil
    var kudosCount: Int = 0     // likes REALES del servidor (0 si nadie ha dado like)
    var commentCount: Int = 0   // comentarios REALES del servidor
    var avatarURL: String? = nil // foto real del autor (Storage)
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
    var personId: String? = nil  // id de la persona (para abrir su perfil); nil si eres tú
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
    @State private var showDiscover = false
    @State private var realFeed: [FeedItem] = []      // posts reales: TUYOS + de a quien sigues
    @State private var realDiscover: [FeedItem] = []  // posts reales de gente que NO sigues (→ Para ti)
    @State private var realFollowedEmpty = true       // ¿aún no sigues a nadie? (modo usuario nuevo)

    private let tabs: [(title: String, icon: String)] = [("Seguidos", "person.2.fill"), ("Para ti", "sparkles")]

    var body: some View {
        VStack(spacing: 0) {
            switcher
            SlidingPages(index: segment) { seguidosTab } second: { paraTiTab }
        }
        .background(Brand.bg)
        .overlay(alignment: .bottom) { toastView }
        .sheet(item: $activity) { ActivityDetailView(item: feedItemView($0)).environmentObject(store) }
        .sheet(item: $commentTarget) { item in
            CommentsSheet(title: item.title, sessionId: item.id, comments: Binding(
                get: { comments[item.id] ?? [] },
                set: { comments[item.id] = $0 }))
                .environmentObject(store)
        }
        .sheet(item: $likesOfPost) { postLikesSheet($0) }
        .sheet(isPresented: $showDiscover) { DiscoverPeopleView().environmentObject(store) }
    }

    // MARK: - Me gusta de una publicación

    @ViewBuilder
    private func postLikesSheet(_ item: FeedItem) -> some View {
        let liked = store.appliedKudos.contains(item.id)
        let people = Array(postLikers(item).prefix(max(1, kudos(item))))
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if liked {
                        likeRow(ScoredAvatar(account: store.account, score: store.gymScore.total, size: 42),
                                name: store.account?.name ?? "Tú", handle: store.account?.handle ?? "tu_usuario") {
                            likesOfPost = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onOpenMyProfile() }
                        }
                    }
                    ForEach(people) { p in
                        likeRow(ScoredAvatar(emoji: p.avatar, score: store.personScore(p.id), size: 42),
                                name: p.name, handle: p.handle) {
                            let pid = p.id; likesOfPost = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onOpenProfile(pid) }
                        }
                    }
                }.padding(.vertical, 8)
            }
            .background(Brand.bg)
            .navigationTitle("Me gusta").navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    /// Fila de "Me gusta": avatar con su Gym Score, nombre y @usuario. Toca para ver el perfil.
    private func likeRow<A: View>(_ avatar: A, name: String, handle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("@\(handle)").font(.caption2).foregroundColor(Brand.soft)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
            }
            .padding(.horizontal, 16).padding(.vertical, 9).contentShape(Rectangle())
        }.buttonStyle(.plain)
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
            // Buscar usuarios reales (solo con backend): abre el grafo social real.
            if Backend.shared.isConfigured {
                Button { FX.tap(); showDiscover = true } label: {
                    Image(systemName: "person.badge.plus").font(.system(size: 15, weight: .heavy))
                        .foregroundColor(Brand.ink).frame(width: 46, height: 40)
                        .background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.top, 2).padding(.bottom, 8)
        .tourAnchor("social.switch")
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
                        ForEach(seguidosFeed) { item in
                            feedCard(item).tourAnchor("social.card", if: item.id == seguidosFeed.first?.id)
                        }
                    }
                } else if seguidosFeed.isEmpty {
                    if hasSuggestions { suggestionsStrip }
                    emptyFeed("Registra un entreno o desliza para refrescar tu muro.")
                } else {
                    // Con seguidos: las sugerencias se INTERCALAN entre posts, pero solo tras refrescar (no automático).
                    let insertAt = min(2, seguidosFeed.count - 1)
                    ForEach(Array(seguidosFeed.enumerated()), id: \.element.id) { idx, item in
                        feedCard(item).tourAnchor("social.card", if: item.id == seguidosFeed.first?.id)
                        if showInterleavedSuggestions && hasSuggestions && idx == insertAt { suggestionsStrip }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .refreshable {
            await loadRealFeed()
            await MainActor.run { refreshSeguidos(manual: true) }
        }
        .onAppear { if !seguidosLoaded { refreshSeguidos(manual: false) } }
        .task { await loadRealFeed() }
    }

    /// Carga el feed real (tuyo + de a quien sigues) desde Supabase y reconstruye la lista.
    private func loadRealFeed() async {
        guard BackendConfig.isConfigured else { return }
        // Espera a la sesión restaurada: en frío `currentUserId` podía ser nil y tus
        // propios posts acababan clasificados como "de otros" (→ Para ti).
        let me = (await Backend.shared.currentUserIdAsync())?.uuidString.lowercased()
        // Trae TODO primero y muta el estado UNA vez al final: cambiar la lista a mitad
        // de un pull-to-refresh puede cancelar la Task y la petición de sugerencias
        // (la última) moría cancelada → la tira "A quién seguir" se vaciaba al refrescar.
        async let rowsReq = Backend.shared.fetchFeedWithAuthors()
        async let followsReq = Backend.shared.fetchFollowing()
        async let suggestedReq = Backend.shared.fetchSuggestedProfiles()
        // Si algo falla o se cancela, CONSERVA lo que había en pantalla (no lo machaques).
        guard let rows = try? await rowsReq, let follows = try? await followsReq else { return }
        let suggested = (try? await suggestedReq) ?? []
        let followed = Set(follows.filter { $0.status == "accepted" }.map { $0.following_id.lowercased() })
        // Partición: Seguidos = tuyos + de a quien sigues; el resto (público) → Para ti.
        var mineAndFollowed: [FeedItem] = [], discover: [FeedItem] = []
        for r in rows {
            let uid = r.user_id.lowercased()
            if uid == me || followed.contains(uid) { mineAndFollowed.append(feedItem(from: r, me: me)) }
            else { discover.append(feedItem(from: r, me: me)) }
        }
        realFeed = mineAndFollowed
        realDiscover = discover
        realFollowedEmpty = followed.isEmpty
        paraTiFeed = discover
        paraTiLoaded = true
        // Sugerencias "A quién seguir": solo se reescriben si la petición trajo datos.
        // Excluye SIEMPRE tu propia cuenta (por uid y por @usuario, por si el uid llega nil).
        let myHandle = store.account?.handle.lowercased()
        if !suggested.isEmpty {
            suggestionsSnapshot = Array(AppStore.asPeople(suggested)
                .filter { $0.id != me && $0.handle.lowercased() != myHandle && !followed.contains($0.id) }
                .prefix(10))
        }
        store.loadMyLikes()
        refreshSeguidos(manual: false)
    }

    private func feedItem(from r: FeedRow, me: String?) -> FeedItem {
        let isMe = r.user_id.lowercased() == me
        return FeedItem(
            id: r.id,
            personId: isMe ? nil : r.user_id,
            authorName: isMe ? (store.account?.name ?? "Tú") : (r.author?.name ?? r.author?.handle ?? "Atleta"),
            avatarPhoto: isMe ? store.account?.photoData : nil,
            avatarEmoji: "🙂",
            flag: "", location: r.location ?? "",
            date: BackendDate.parse(r.date) ?? Date(),
            title: r.name, note: r.note ?? "", photo: nil, photoURL: r.photo_url,
            elapsed: r.elapsed, exercises: r.exercises, sets: r.sets, volume: r.volume,
            items: r.items, avgHeartRate: r.avg_hr, maxHeartRate: r.max_hr,
            kudosCount: r.kudos?.first?.count ?? 0,
            commentCount: r.comments?.first?.count ?? 0,
            avatarURL: isMe ? nil : r.author?.avatar_url)
    }

    private func feedCard(_ item: FeedItem) -> some View {
        card(item, showFollow: item.personId != nil && store.relationship(item.personId ?? "") == .none)
    }

    private func refreshSeguidos(manual: Bool) {
        // Con backend real: Seguidos = TUS posts + los de a quien sigues (+ locales sin sincronizar).
        // Si aún no sigues a nadie → modo usuario nuevo: se añaden posts para descubrir gente
        // (con la tira "A quién seguir" arriba). En cuanto sigues a alguien, el descubrimiento
        // pasa a "Para ti" y Seguidos queda solo con los tuyos + seguidos.
        if BackendConfig.isConfigured {
            let localExtra = myItems.filter { m in !realFeed.contains { $0.id.lowercased() == m.id.lowercased() } }
            seguidosNewUser = realFollowedEmpty
            let base = realFeed + localExtra + (realFollowedEmpty ? realDiscover : [])
            seguidosFeed = base.sorted { $0.date > $1.date }
            if manual { showInterleavedSuggestions = true }
            seguidosLoaded = true
            return
        }
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
        HStack(spacing: 10) {
            // Forgey te saluda al llegar (y ya refleja tu nivel).
            Mascot(size: 52, wave: true, stage: store.forgeyStage)
            VStack(alignment: .leading, spacing: 3) {
                Text("Hola, \(store.account?.name ?? "atleta") 👋").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
                Text("Pon en marcha tu Forge Loop").font(.footnote).foregroundColor(Brand.muted)
            }
            Spacer()
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
            if BackendConfig.isConfigured { await loadRealFeed() }
            else { try? await Task.sleep(nanoseconds: 500_000_000); await MainActor.run { refreshParaTi() } }
        }
        .onAppear { if !paraTiLoaded { refreshParaTi() } }
    }

    private func refreshParaTi() {
        // Con backend, Para ti lo alimenta loadRealFeed (posts públicos de gente que no sigues).
        if BackendConfig.isConfigured { paraTiFeed = realDiscover; paraTiLoaded = true; return }
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
                ScoredAvatar(emoji: p.avatar, avatarURL: p.avatarURL, score: store.personScore(p.id), size: 60)
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

    private func withName(_ p: SocialPerson, _ name: String) -> SocialPerson {
        var c = p; c.name = name; return c
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
                     avgHeartRate: item.avgHeartRate, maxHeartRate: item.maxHeartRate,
                     score: item.personId == nil ? store.gymScore.total : store.personScore(item.personId ?? ""))
    }

    private func reportPost(_ item: FeedItem) {
        FX.tap()
        if let pid = item.personId {
            Task { try? await Backend.shared.report(targetType: "session", targetId: item.id, reportedUserId: pid, reason: "reported from feed") }
        }
        showToast("Gracias. Revisaremos esta publicación en 24 h.")
    }

    private func blockAuthor(_ item: FeedItem, pid: String) {
        FX.tap()
        Task {
            try? await Backend.shared.blockUser(pid)
            await loadRealFeed()   // desaparece el contenido del bloqueado
            store.loadFollowing()
        }
        showToast("Has bloqueado a \(item.authorName). No verás su contenido.")
    }

    private func card(_ item: FeedItem, showFollow: Bool = false) -> some View {
        PanelCard {
            // Cabecera: avatar/nombre abre el PERFIL (zona de toque propia).
            HStack(spacing: 11) {
                Button { openProfile(item) } label: {
                    HStack(spacing: 11) {
                        ZStack(alignment: .bottomTrailing) {
                            authorAvatar(item)
                            ScoreBadge(score: item.personId == nil ? store.gymScore.total : store.personScore(item.personId ?? ""))
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
                if let pid = item.personId {
                    HStack(spacing: 8) {
                        if showFollow {
                            // Persona construida desde el propio post (nombre real del autor).
                            let p = store.person(pid).map { $0.name == "Atleta" ? withName($0, item.authorName) : $0 }
                                ?? SocialPerson(id: pid, name: item.authorName, handle: "", avatar: item.avatarEmoji, gym: "")
                            Button { followPerson(p) } label: {
                                Text("Seguir").font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                                    .padding(.horizontal, 12).frame(height: 30).background(Brand.green).clipShape(Capsule())
                            }.buttonStyle(.plain)
                        }
                        // Moderación (App Store): reportar publicación / bloquear al autor.
                        Menu {
                            Button(role: .destructive) { reportPost(item) } label: { Label("Reportar publicación", systemImage: "flag") }
                            Button(role: .destructive) { blockAuthor(item, pid: pid) } label: { Label("Bloquear a \(item.authorName)", systemImage: "hand.raised") }
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundColor(Brand.soft).frame(width: 28, height: 34)
                        }
                    }
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
                    WorkoutPhoto(data: item.photo, url: item.photoURL, height: 190)
                    WorkoutStatStrip(stats: WorkoutStatStrip.metrics(time: durationText(item.elapsed), sets: item.sets,
                                                     exercises: item.exercises, ppm: item.avgHeartRate), style: .full)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)

            // Acciones estilo Instagram: like (corazón), comentario, compartir (avión), con contadores.
            HStack(spacing: 20) {
                // baseCount = likes de OTROS (el mío lo suma LikeButton según mi estado real).
                LikeButton(id: item.id, baseCount: max(0, kudos(item) - (store.appliedKudos.contains(item.id) ? 1 : 0)), onShowLikes: { likesOfPost = item }).environmentObject(store)

                Button { openComments(item) } label: {
                    actionIcon("bubble.right", "\(commentTotal(item))", tint: Brand.ink)
                }.buttonStyle(.plain)

                ShareLink(item: shareText(item)) {
                    actionIcon("paperplane", "\(shareBase(item))", tint: Brand.ink)
                }.buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 2)

            commentPreview(item)
        }
    }

    /// Vista previa de comentarios estilo Instagram: "Ver los N comentarios" + 1-2 comentarios recientes.
    @ViewBuilder private func commentPreview(_ item: FeedItem) -> some View {
        let total = commentTotal(item)
        let preview = previewComments(item)
        if !preview.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                if total > preview.count {
                    Button { openComments(item) } label: {
                        Text("Ver los \(total) comentarios")
                            .font(.system(size: 13)).foregroundColor(Brand.soft)
                    }.buttonStyle(.plain)
                }
                ForEach(preview) { c in
                    Button { openComments(item) } label: {
                        (Text(c.authorName).font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
                         + Text("  ")
                         + Text(c.text).font(.system(size: 13)).foregroundColor(Color(hex: "2c3127")))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.top, 1)
        }
    }

    private func openComments(_ item: FeedItem) {
        FX.tap()
        if comments[item.id] == nil { comments[item.id] = demoComments(for: item) }
        commentTarget = item
    }

    private func commentList(_ item: FeedItem) -> [PostComment] { comments[item.id] ?? demoComments(for: item) }

    /// Hasta 2 comentarios de nivel superior, los más recientes primero (como Instagram).
    private func previewComments(_ item: FeedItem) -> [PostComment] {
        Array(commentList(item).sorted { $0.date > $1.date }.prefix(2))
    }

    private func actionIcon(_ icon: String, _ count: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundColor(tint)
            Text(count).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.ink)
        }
    }

    private func shareBase(_ item: FeedItem) -> Int {
        if store.people.isEmpty { return 0 }   // sin datos inventados con backend real
        var s: UInt64 = 5
        for ch in item.id.unicodeScalars { s = s &* 17 &+ UInt64(ch.value) }
        return 1 + Int(s % 9)
    }

    private func commentTotal(_ item: FeedItem) -> Int {
        // Real: si ya cargamos los comentarios de este post, cuéntalos; si no, el contador del servidor.
        if store.people.isEmpty {
            if let loaded = comments[item.id] { return loaded.reduce(0) { $0 + 1 + $1.replies.count } }
            return item.commentCount
        }
        return commentList(item).reduce(0) { $0 + 1 + $1.replies.count }
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
                    likes: Int(seed % 3), liked: false, replies: [], personId: item.personId))
            }
            out.append(PostComment(
                id: "\(item.id)-c\(i)", authorName: p.name, authorEmoji: p.avatar, isMe: false,
                text: texts[Int((seed >> (i * 2)) % UInt64(texts.count))],
                date: Date().addingTimeInterval(-Double(mins) * 60),
                likes: Int((seed >> i) % 14), liked: false, replies: replies, personId: p.id))
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
        } else if let a = item.avatarURL, let u = URL(string: a) {
            AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: { Avatar(emoji: item.avatarEmoji, size: 42) }
                .frame(width: 42, height: 42).clipShape(Circle())
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
        // Con backend real: likes REALES (0 si nadie ha dado). Sin backend: número demo.
        if store.people.isEmpty { return item.kudosCount }
        var seed: UInt64 = 0
        for ch in item.id.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
        return 3 + Int(seed % 22)
    }

    // MARK: - Feed sources

    private var myItems: [FeedItem] {
        let profileLoc = [store.profile.city, store.profile.country].filter { !$0.isEmpty }.joined(separator: ", ")
        return store.sessions.map { s in
            // Zona aproximada del entreno (GPS); fallback a la ciudad del perfil si no se capturó.
            let loc = (s.location?.isEmpty == false) ? s.location! : profileLoc
            return FeedItem(
                id: s.id, personId: nil, authorName: store.account?.name ?? "Tú",
                avatarPhoto: store.account?.photoData, avatarEmoji: "🙂",
                flag: countryFlag(store.profile.country), location: loc,
                date: s.date, title: s.name, note: s.note, photo: s.photoData, photoURL: s.photoURL,
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
    var sessionId: String? = nil
    @Binding var comments: [PostComment]
    @State private var draft = ""
    @State private var replyTo: String?
    @State private var replyToName: String?
    @State private var likesOf: PostComment?
    @State private var profileTarget: IdString?
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
        .task { await loadReal() }
        .sheet(item: $likesOf) { likesSheet($0) }
        .sheet(item: $profileTarget) { item in
            if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
        }
    }

    /// Carga los comentarios REALES del servidor (con autor) para esta publicación.
    private func loadReal() async {
        guard BackendConfig.isConfigured, let sid = sessionId else { return }
        let rows = (try? await Backend.shared.fetchCommentsWithAuthors(sessionId: sid)) ?? []
        let me = Backend.shared.currentUserId?.uuidString.lowercased()
        func make(_ r: CommentAuthorRow) -> PostComment {
            let isMe = r.user_id.lowercased() == me
            return PostComment(id: r.id,
                authorName: isMe ? (store.account?.name ?? "Tú") : (r.author?.name ?? r.author?.handle ?? "Atleta"),
                authorEmoji: isMe ? "" : "🙂", isMe: isMe, text: r.text,
                date: BackendDate.parse(r.created_at) ?? Date(), likes: 0, liked: false,
                replies: [], personId: isMe ? nil : r.user_id)
        }
        var byId: [String: PostComment] = [:]
        var order: [String] = []
        for r in rows where r.parent_id == nil { byId[r.id] = make(r); order.append(r.id) }
        for r in rows where r.parent_id != nil {
            if let pid = r.parent_id, byId[pid] != nil { byId[pid]!.replies.append(make(r)) }
        }
        comments = order.compactMap { byId[$0] }
    }

    @ViewBuilder
    private func likesSheet(_ c: PostComment) -> some View {
        let people = Array(likers(for: c).prefix(max(1, c.likes)))
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if c.liked {
                        likeRow(ScoredAvatar(account: store.account, score: store.gymScore.total, size: 42),
                                name: store.account?.name ?? "Tú", handle: store.account?.handle ?? "tu_usuario", action: nil)
                    }
                    ForEach(people) { p in
                        likeRow(ScoredAvatar(emoji: p.avatar, score: store.personScore(p.id), size: 42),
                                name: p.name, handle: p.handle) {
                            let pid = p.id; likesOf = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { profileTarget = IdString(id: pid) }
                        }
                    }
                }.padding(.vertical, 8)
            }
            .background(Brand.bg)
            .navigationTitle("Me gusta").navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    /// Fila de "Me gusta": avatar con su Gym Score + nombre. Toca (si hay acción) para ver el perfil.
    private func likeRow<A: View>(_ avatar: A, name: String, handle: String, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            HStack(spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("@\(handle)").font(.caption2).foregroundColor(Brand.soft)
                }
                Spacer()
                if action != nil { Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft) }
            }
            .padding(.horizontal, 16).padding(.vertical, 9).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(action == nil)
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

    /// Avatar del autor con su Gym Score (igual que el resto de la plataforma) y, si es
    /// otra persona, tocable para abrir su perfil.
    @ViewBuilder
    private func avatar(_ c: PostComment) -> some View {
        let canOpen = !c.isMe && (c.personId.flatMap { store.person($0) } != nil)
        Button { openAuthor(c) } label: { scoredAvatar(c) }
            .buttonStyle(.plain)
            .disabled(!canOpen)
    }

    @ViewBuilder
    private func scoredAvatar(_ c: PostComment) -> some View {
        if c.isMe {
            ScoredAvatar(account: store.account, score: store.gymScore.total, size: 32)
        } else {
            ScoredAvatar(emoji: c.authorEmoji.isEmpty ? "🙂" : c.authorEmoji, score: authorScore(c), size: 32)
        }
    }

    private func authorScore(_ c: PostComment) -> Int {
        if c.isMe { return store.gymScore.total }
        if let pid = c.personId { return store.personScore(pid) }
        return 0
    }

    private func openAuthor(_ c: PostComment) {
        guard !c.isMe, let pid = c.personId, store.person(pid) != nil else { return }
        FX.tap()
        profileTarget = IdString(id: pid)
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
        // Escribe el comentario REAL en el servidor (best-effort).
        if BackendConfig.isConfigured, let sid = sessionId {
            let parent = replyTo
            Task { try? await Backend.shared.addComment(sessionId: sid, text: t, parentId: parent) }
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
