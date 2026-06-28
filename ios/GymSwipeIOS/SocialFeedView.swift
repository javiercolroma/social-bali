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
}

struct SocialFeedView: View {
    @EnvironmentObject var store: AppStore
    var onOpenProfile: (String) -> Void
    @State private var liked: Set<String> = []
    @State private var activity: FeedItem?
    @State private var commentTarget: FeedItem?
    @State private var comments: [String: [String]] = [:]

    private var friends: [SocialPerson] { store.people.filter { store.relationship($0.id) == .friends } }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if feed.isEmpty {
                    emptyState
                } else {
                    ForEach(feed) { item in card(item) }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Brand.bg)
        .sheet(item: $activity) { ActivityDetailView(item: feedItemView($0)).environmentObject(store) }
        .sheet(item: $commentTarget) { item in
            CommentsSheet(title: item.title, comments: Binding(
                get: { comments[item.id] ?? [] },
                set: { comments[item.id] = $0 }))
                .environmentObject(store)
        }
    }

    private func feedItemView(_ item: FeedItem) -> ActivityData {
        ActivityData(authorName: item.authorName, avatarPhoto: item.avatarPhoto, avatarEmoji: item.avatarEmoji,
                     flag: item.flag, location: item.location, date: item.date, title: item.title, note: item.note,
                     photo: item.photo, elapsed: item.elapsed, exercises: item.exercises, sets: item.sets,
                     volume: item.volume, items: item.items)
    }

    private var emptyState: some View {
        PanelCard {
            HStack { Spacer(); Text("👥").font(.system(size: 44)); Spacer() }
            Text("Tu muro está vacío").font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Guarda un entreno o hazte amigo de alguien para ver actividad aquí.")
                .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
    }

    private func card(_ item: FeedItem) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header: avatar, name, time, location
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
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                }

                // Title
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill").font(.system(size: 13)).foregroundColor(Color(hex: "6ea300"))
                    Text(item.title).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                }

                // Comment / note
                if !item.note.isEmpty {
                    Text(item.note).font(.system(size: 14)).foregroundColor(Color(hex: "2c3127")).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }

                // Photo
                if let data = item.photo, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 180).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Metrics
                HStack(spacing: 8) {
                    stat(durationText(item.elapsed), "Tiempo", "clock")
                    stat("\(item.sets)", "Series", "checkmark.circle")
                    stat("\(Int(item.volume))", "kg vol.", "dumbbell.fill")
                    stat("\(item.exercises)", "Ejerc.", "list.bullet")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { FX.tap(); activity = item }

            HStack(spacing: 8) {
                // Aplausos
                Button {
                    FX.tap()
                    if liked.contains(item.id) { liked.remove(item.id) } else { liked.insert(item.id) }
                } label: {
                    let isLiked = liked.contains(item.id)
                    actionChip(icon: isLiked ? "hands.clap.fill" : "hands.clap",
                               text: "\(kudos(item) + (isLiked ? 1 : 0))", active: isLiked)
                }.buttonStyle(.plain)

                // Comentar
                Button { FX.tap(); commentTarget = item } label: {
                    let n = comments[item.id]?.count ?? 0
                    actionChip(icon: "bubble.left", text: n > 0 ? "\(n)" : "Comentar", active: n > 0)
                }.buttonStyle(.plain)

                // Compartir
                ShareLink(item: shareText(item)) {
                    actionChip(icon: "square.and.arrow.up", text: "Compartir", active: false)
                }.buttonStyle(.plain)
            }
        }
    }

    private func actionChip(icon: String, text: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 13, weight: .heavy))
        .foregroundColor(active ? Color(hex: "10150a") : Brand.muted)
        .frame(maxWidth: .infinity).frame(height: 36)
        .background(active ? Brand.greenSoft : Brand.chip).clipShape(Capsule())
    }

    private func shareText(_ item: FeedItem) -> String {
        "\(item.authorName) entrenó \(item.title): \(item.sets) series · \(Int(item.volume)) kg de volumen · \(durationText(item.elapsed)). 💪 vía Forge Loop"
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

    private var feed: [FeedItem] {
        (myItems + friendItems).sorted { $0.date > $1.date }
    }

    private var myItems: [FeedItem] {
        let loc = [store.profile.city, store.profile.country].filter { !$0.isEmpty }.joined(separator: ", ")
        return store.sessions.map { s in
            FeedItem(
                id: s.id, personId: nil, authorName: store.account?.name ?? "Tú",
                avatarPhoto: store.account?.photoData, avatarEmoji: "🙂",
                flag: countryFlag(store.profile.country), location: loc,
                date: s.date, title: s.name, note: s.note, photo: s.photoData,
                elapsed: s.elapsed, exercises: s.exercises, sets: s.sets, volume: s.volume,
                items: s.items ?? [])
        }
    }

    private let friendNotes = ["", "Buenas sensaciones hoy 💪", "", "PR en el último ejercicio 🔥", "", "Día duro pero hecho ✅"]

    private var friendItems: [FeedItem] {
        var items: [FeedItem] = []
        for p in friends {
            let history = buildFriendHistory(p)
            let sessions = Dictionary(grouping: history) { $0.sessionId ?? $0.id }
            let recent = sessions.values
                .sorted { ($0.first?.completedAt ?? .distantPast) > ($1.first?.completedAt ?? .distantPast) }
                .prefix(2)
            for entries in recent {
                let date = entries.map { $0.completedAt }.max() ?? Date()
                let sets = entries.reduce(0) { $0 + $1.sets }
                let sid = entries.first?.sessionId ?? UUID().uuidString
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
                        // build per-set logs with a small weight ramp for realism
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

/// Hoja de comentarios de un post del muro (almacenados localmente).
struct CommentsSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var comments: [String]
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if comments.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 34)).foregroundColor(Brand.soft)
                                Text("Sé el primero en comentar").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                                Text("Anima a quien ha entrenado 💬").font(.footnote).foregroundColor(Brand.muted)
                            }
                            .frame(maxWidth: .infinity).padding(.top, 40)
                        } else {
                            ForEach(Array(comments.enumerated()), id: \.offset) { _, c in commentRow(c) }
                        }
                    }
                    .padding(16)
                }
                Divider()
                HStack(spacing: 10) {
                    MeAvatar(account: store.account, size: 32)
                    TextField("Añade un comentario…", text: $draft, axis: .vertical)
                        .font(.system(size: 15))
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
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Brand.bg)
            }
            .background(Brand.bg)
            .navigationTitle("Comentarios").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private var canPost: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func post() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        FX.tap()
        comments.append(t)
        draft = ""
    }

    private func commentRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            MeAvatar(account: store.account, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.account?.name ?? "Tú").font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
                Text(text).font(.system(size: 14)).foregroundColor(Color(hex: "2c3127"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12).background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
