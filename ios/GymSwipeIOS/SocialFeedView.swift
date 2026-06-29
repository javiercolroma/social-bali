import SwiftUI
import CoreLocation

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

    @State private var segment = 0
    @State private var activity: FeedItem?
    @State private var commentTarget: FeedItem?
    @State private var comments: [String: [PostComment]] = [:]
    @State private var toast: String?
    @StateObject private var location = LocationManager()

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
        .onAppear { if store.account != nil { location.request() } }
        .onChange(of: store.account?.handle) { _ in if store.account != nil { location.request() } }
        .sheet(item: $activity) { ActivityDetailView(item: feedItemView($0)).environmentObject(store) }
        .sheet(item: $commentTarget) { item in
            CommentsSheet(title: item.title, comments: Binding(
                get: { comments[item.id] ?? [] },
                set: { comments[item.id] = $0 }))
                .environmentObject(store)
        }
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
            VStack(spacing: 12) {
                if store.following.isEmpty {
                    newUserHeader
                    if !myItems.isEmpty {
                        sectionHeader("TUS ENTRENOS")
                        ForEach(myItems) { card($0) }
                    }
                    sectionHeader("CERCA DE TI")
                    ForEach(nearbyPeople(limit: 5)) { recRow($0) }
                    Button { FX.tap(); withAnimation { segment = 1 } } label: {
                        Text("Descubre más en Para ti ›").font(.system(size: 14, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                    }.frame(maxWidth: .infinity).padding(.top, 4)
                } else {
                    ForEach(followedFeed) { card($0) }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
    }

    private var newUserHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Hola, \(store.account?.name ?? "atleta") 👋").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
            Text("Pon en marcha tu Forge Loop").font(.footnote).foregroundColor(Brand.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - PARA TI

    private var paraTiTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                let incoming = store.people.filter { store.relationship($0.id) == .incoming }
                if !incoming.isEmpty {
                    sectionHeader("TE QUIEREN SEGUIR")
                    ForEach(incoming) { incomingRow($0) }
                }

                let nearby = nearbyPeople(limit: 6)
                sectionHeader("CERCA DE TI")
                if nearby.isEmpty {
                    Text("Ya sigues a toda la comunidad 🎉").font(.footnote).foregroundColor(Brand.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                } else {
                    ForEach(nearby) { recRow($0) }
                }

                let disc = discoverFeed
                if !disc.isEmpty {
                    sectionHeader("DESCUBRE ENTRENOS")
                    ForEach(disc) { card($0, showFollow: true) }
                } else if nearby.isEmpty {
                    Text("No hay más entrenos por descubrir ahora mismo. ¡Vuelve pronto!")
                        .font(.footnote).foregroundColor(Brand.muted).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
    }

    private func sectionHeader(_ t: String) -> some View {
        HStack { Text(t).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted); Spacer() }
            .padding(.horizontal, 4).padding(.top, 4)
    }

    private func recRow(_ p: SocialPerson) -> some View {
        PanelCard {
            HStack(spacing: 11) {
                Button { FX.tap(); onOpenProfile(p.id) } label: { personAvatar(p) }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.name).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("@\(p.handle)").font(.caption2).foregroundColor(Brand.soft)
                    Tag(text: "📍 a \(distanceLabel(distanceMeters(p)))", highlight: true)
                }
                Spacer()
                followButton(p)
            }
        }
    }

    private func incomingRow(_ p: SocialPerson) -> some View {
        PanelCard {
            HStack(spacing: 11) {
                Button { FX.tap(); onOpenProfile(p.id) } label: { personAvatar(p) }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.name).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("@\(p.handle)").font(.caption2).foregroundColor(Brand.soft)
                    Tag(text: "Te quiere seguir", highlight: true)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button { FX.success(); store.acceptFriendRequest(p.id); showToast("Ahora sigues a \(p.name)") } label: {
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                            .frame(width: 44, height: 44).background(Brand.green).clipShape(Circle())
                    }.buttonStyle(.plain)
                    Button { FX.warning(); store.rejectFriendRequest(p.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .heavy)).foregroundColor(Color(hex: "a73232"))
                            .frame(width: 44, height: 44).background(Brand.redSoft).clipShape(Circle())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func followButton(_ p: SocialPerson) -> some View {
        Button { followPerson(p) } label: {
            Text("Seguir").font(.system(size: 14, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                .padding(.horizontal, 16).frame(height: 38).background(Brand.green).clipShape(Capsule())
        }.buttonStyle(.plain)
    }

    @ViewBuilder
    private func personAvatar(_ p: SocialPerson) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Avatar(emoji: p.avatar, size: 44)
            Text(p.flag).font(.system(size: 11)).frame(width: 17, height: 17)
                .background(Circle().fill(.white)).overlay(Circle().stroke(Brand.line)).offset(x: 3, y: 3)
        }
    }

    private func followPerson(_ p: SocialPerson) {
        FX.success()
        if store.relationship(p.id) == .incoming { store.acceptFriendRequest(p.id) } else { store.follow(p.id) }
        showToast("Ahora sigues a \(p.name)")
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

    /// Distancia aproximada a una persona. Usa tu ubicación real si está disponible
    /// (posición determinista alrededor de ti, coherente con el mapa de Ranking);
    /// si no, una distancia sintética estable por persona.
    private func distanceMeters(_ p: SocialPerson) -> Double {
        var seed: UInt64 = 0
        for ch in p.id.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
        let r1 = Double(seed % 1000) / 1000.0
        let r2 = Double((seed / 1000) % 1000) / 1000.0
        if let c = location.coordinate {
            let here = CLLocation(latitude: c.latitude, longitude: c.longitude)
            let there = CLLocation(latitude: c.latitude + (r1 - 0.5) * 0.02,
                                   longitude: c.longitude + (r2 - 0.5) * 0.02)
            return here.distance(from: there)
        }
        return 120 + r1 * 2600   // 120 m – 2,7 km sin ubicación
    }

    private func distanceLabel(_ m: Double) -> String {
        if m < 1000 { return "\(Int((m / 10).rounded()) * 10) m" }
        return String(format: "%.1f", m / 1000).replacingOccurrences(of: ".", with: ",") + " km"
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
            VStack(alignment: .leading, spacing: 12) {
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

                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill").font(.system(size: 13)).foregroundColor(Color(hex: "6ea300"))
                    Text(item.title).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                }

                if !item.note.isEmpty {
                    Text(item.note).font(.system(size: 14)).foregroundColor(Color(hex: "2c3127")).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }

                if let data = item.photo, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 180).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 8) {
                    stat(durationText(item.elapsed), "Tiempo", "clock")
                    stat("\(item.sets)", "Series", "checkmark.circle")
                    stat("\(item.exercises)", "Ejerc.", "list.bullet")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { FX.tap(); activity = item }

            // Acciones estilo Instagram: like (corazón), comentario, compartir (avión), con contadores.
            HStack(spacing: 20) {
                Button { FX.tap(); store.toggleKudo(item.id) } label: {
                    let liked = store.appliedKudos.contains(item.id)
                    actionIcon(liked ? "heart.fill" : "heart", "\(kudos(item) + (liked ? 1 : 0))",
                               tint: liked ? Brand.red : Brand.ink)
                }.buttonStyle(.plain)

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
            Image(systemName: icon).font(.system(size: 21, weight: .regular)).foregroundColor(tint)
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

    private func stat(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(Brand.muted)
        }.frame(maxWidth: .infinity).padding(.vertical, 8).background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
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
                    }))
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
                    Text(relativeTime(c.date))
                    if c.likes > 0 { Text("\(c.likes) me gusta") }
                    Button("Responder") { startReply(c, isReply: isReply) }
                }
                .font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.soft)
            }
            Spacer()
            Button { toggleLike(c.id) } label: {
                Image(systemName: c.liked ? "heart.fill" : "heart")
                    .font(.system(size: 13)).foregroundColor(c.liked ? Brand.red : Brand.soft)
            }.buttonStyle(.plain)
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
                MeAvatar(account: store.account, size: 32)
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
