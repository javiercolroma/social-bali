import SwiftUI

private struct FeedItem: Identifiable {
    let id: String
    let person: SocialPerson
    let date: Date
    let title: String
    let exercises: Int
    let sets: Int
    let volume: Double
    let names: [String]
}

struct SocialFeedView: View {
    @EnvironmentObject var store: AppStore
    var onOpenProfile: (String) -> Void
    @State private var liked: Set<String> = []

    private var friends: [SocialPerson] { store.people.filter { store.relationship($0.id) == .friends } }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if friends.isEmpty {
                    emptyState
                } else {
                    ForEach(feed) { item in card(item) }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Brand.bg)
    }

    private var emptyState: some View {
        PanelCard {
            HStack { Spacer(); Text("👥").font(.system(size: 44)); Spacer() }
            Text("Aún no sigues a nadie").font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Cuando tengas amigos, aquí verás sus entrenos y estadísticas.")
                .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
    }

    private func card(_ item: FeedItem) -> some View {
        PanelCard {
            Button { onOpenProfile(item.person.id) } label: {
                HStack(spacing: 11) {
                    ZStack(alignment: .bottomTrailing) {
                        Avatar(emoji: item.person.avatar, size: 42)
                        Text(item.person.flag).font(.system(size: 11)).frame(width: 17, height: 17)
                            .background(Circle().fill(.white)).overlay(Circle().stroke(Brand.line)).offset(x: 3, y: 3)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.person.name).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                        Text(relativeTime(item.date)).font(.caption2).foregroundColor(Brand.soft)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                }
            }.buttonStyle(.plain)

            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill").font(.system(size: 13)).foregroundColor(Color(hex: "6ea300"))
                Text(item.title).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
            }
            Text(item.names.joined(separator: " · ")).font(.footnote).foregroundColor(Brand.muted).lineLimit(1)

            HStack(spacing: 10) {
                stat("\(item.exercises)", "ejercicios")
                stat("\(item.sets)", "series")
                stat("\(Int(item.volume)) kg", "volumen")
            }

            Button {
                FX.tap()
                if liked.contains(item.id) { liked.remove(item.id) } else { liked.insert(item.id) }
            } label: {
                let isLiked = liked.contains(item.id)
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "hands.clap.fill" : "hands.clap")
                    Text("\(kudos(item) + (isLiked ? 1 : 0))")
                }
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(isLiked ? Color(hex: "10150a") : Brand.muted)
                .padding(.horizontal, 12).frame(height: 34)
                .background(isLiked ? Brand.greenSoft : Brand.chip).clipShape(Capsule())
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
        }.frame(maxWidth: .infinity).padding(.vertical, 8).background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func kudos(_ item: FeedItem) -> Int {
        var seed: UInt64 = 0
        for ch in item.id.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
        return 3 + Int(seed % 22)
    }

    private var feed: [FeedItem] {
        var items: [FeedItem] = []
        for p in friends {
            let history = buildFriendHistory(p)
            let sessions = Dictionary(grouping: history) { $0.sessionId ?? $0.id }
            let recent = sessions.values
                .sorted { ($0.first?.completedAt ?? .distantPast) > ($1.first?.completedAt ?? .distantPast) }
                .prefix(2)
            for entries in recent {
                let date = entries.map { $0.completedAt }.max() ?? Date()
                items.append(FeedItem(
                    id: entries.first?.sessionId ?? UUID().uuidString,
                    person: p, date: date, title: Self.title(for: entries),
                    exercises: entries.count, sets: entries.reduce(0) { $0 + $1.sets },
                    volume: entries.reduce(0) { $0 + $1.volume },
                    names: entries.prefix(3).map { $0.exerciseName }))
            }
        }
        return items.sorted { $0.date > $1.date }
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
