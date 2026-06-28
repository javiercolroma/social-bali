import SwiftUI

/// Pestaña "Actividad": tu historial personal de entrenos con estadísticas
/// resumidas. Reutiliza ActivityDetailView para el detalle de cada sesión.
struct ActivityView: View {
    @EnvironmentObject var store: AppStore
    @State private var detail: WorkoutSession?

    private var sessions: [WorkoutSession] {
        store.sessions.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                summaryCard
                if sessions.isEmpty {
                    emptyState
                } else {
                    HStack {
                        Text("TU HISTORIAL").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        Spacer()
                        Text("\(sessions.count)").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.soft)
                    }.padding(.horizontal, 4).padding(.top, 2)
                    ForEach(sessions) { s in sessionCard(s) }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Brand.bg)
        .sheet(item: $detail) { ActivityDetailView(item: activityData($0)).environmentObject(store) }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let totalVol = sessions.reduce(0.0) { $0 + $1.volume }
        let week = sessionsThisWeek
        return PanelCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TU ACTIVIDAD").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    Text("\(sessions.count)").font(.system(size: 44, weight: .heavy)).foregroundColor(Brand.ink)
                    Text(sessions.count == 1 ? "entreno guardado" : "entrenos guardados")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Label("\(store.player.streak) días", systemImage: "flame.fill")
                        .font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "8a4b00"))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(hex: "ffe2a3")).clipShape(Capsule())
                    Label("Score \(store.gymScore.total)", systemImage: "trophy.fill")
                        .font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Brand.greenSoft).clipShape(Capsule())
                }
            }
            HStack(spacing: 10) {
                stat("\(week)", "Esta semana", "calendar")
                stat("\(Int(totalVol)) kg", "Volumen total", "dumbbell.fill")
            }
        }
    }

    private var sessionsThisWeek: Int {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.date >= weekAgo }.count
    }

    private func stat(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 15)).foregroundColor(Color(hex: "6ea300"))
            Text(value).font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Session card

    private func sessionCard(_ s: WorkoutSession) -> some View {
        Button {
            FX.tap()
            detail = s
        } label: {
            PanelCard {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill").font(.system(size: 13)).foregroundColor(Color(hex: "6ea300"))
                    Text(s.name).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                }
                Text(relativeTime(s.date)).font(.caption).foregroundColor(Brand.soft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let data = s.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 150).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                HStack(spacing: 8) {
                    miniStat(durationText(s.elapsed), "Tiempo")
                    miniStat("\(s.sets)", "Series")
                    miniStat("\(Int(s.volume))", "kg vol.")
                    miniStat("\(s.exercises)", "Ejerc.")
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(Brand.muted)
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 30)
            ZStack {
                Circle().fill(Brand.greenSoft).frame(width: 88, height: 88)
                Image(systemName: "chart.bar.fill").font(.system(size: 36, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
            }
            Text("Aún no tienes actividad").font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink)
            Text("Completa y guarda un entreno para ver aquí tu historial y tus estadísticas.")
                .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity).padding(.top, 10)
    }

    // MARK: - Helpers

    private func activityData(_ s: WorkoutSession) -> ActivityData {
        let loc = [store.profile.city, store.profile.country].filter { !$0.isEmpty }.joined(separator: ", ")
        return ActivityData(
            authorName: store.account?.name ?? "Tú",
            avatarPhoto: store.account?.photoData, avatarEmoji: "🙂",
            flag: countryFlag(store.profile.country), location: loc,
            date: s.date, title: s.name, note: s.note, photo: s.photoData,
            elapsed: s.elapsed, exercises: s.exercises, sets: s.sets,
            volume: s.volume, items: s.items ?? [])
    }

    private func durationText(_ s: Int) -> String {
        let m = s / 60
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(max(1, m)) min"
    }
}
