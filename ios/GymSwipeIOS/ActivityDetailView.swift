import SwiftUI

struct ActivityData {
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
    var score: Int = 0   // Gym Score del autor, para el badge del avatar
    var xp: Int = 0      // XP ganado en la sesión (0 = no mostrar, p. ej. posts de otros)
}

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let item: ActivityData

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Author
                    HStack(spacing: 11) {
                        ZStack(alignment: .bottomTrailing) {
                            if let d = item.avatarPhoto, let ui = UIImage(data: d) {
                                Image(uiImage: ui).resizable().scaledToFill().frame(width: 46, height: 46).clipShape(Circle())
                            } else {
                                Avatar(emoji: item.avatarEmoji, size: 46)
                            }
                            ScoreBadge(score: item.score, avatarSize: 46)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.authorName).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                            HStack(spacing: 5) {
                                Text(relativeTime(item.date))
                                if !item.location.isEmpty {
                                    Text("·"); Image(systemName: "mappin.and.ellipse").font(.system(size: 9)); Text(item.location)
                                }
                            }.font(.caption).foregroundColor(Brand.soft)
                        }
                        Spacer()
                    }

                    Text(item.title).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !item.note.isEmpty {
                        Text(item.note).font(.system(size: 15)).foregroundColor(Color(hex: "2c3127"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    WorkoutMedia(photoData: item.photo, photoURL: item.photoURL,
                                 elapsed: item.elapsed, sets: item.sets, volume: item.volume,
                                 exercises: item.exercises,
                                 seed: "\(item.title)-\(Int(item.date.timeIntervalSince1970))", height: 260)

                    // Metrics
                    HStack(spacing: 10) {
                        metric(durationText(item.elapsed), "Tiempo", "clock")
                        metric("\(item.sets)", "Series", "checkmark.circle")
                        metric("\(item.exercises)", "Ejercicios", "list.bullet")
                        if item.xp > 0 { metric("+\(item.xp)", "XP", "star.fill") }
                    }
                    if let avg = item.avgHeartRate {
                        HStack(spacing: 10) {
                            metric("\(avg) ppm", "FC media", "heart.fill")
                            metric("\(item.maxHeartRate ?? avg) ppm", "FC máx", "heart.fill")
                        }
                    }

                    // Exercises
                    if !item.items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("EJERCICIOS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                            ForEach(Array(item.items.enumerated()), id: \.offset) { _, ex in
                                exerciseCard(ex)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Actividad").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { SheetBackButton { dismiss() } } }
        }
    }

    private func metric(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(Color(hex: "6ea300"))
            Text(value).font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Per-set list for an exercise: SOLO las series hechas. Usa los logs (que solo
    /// contienen las series completadas); si no hay logs, usa el conteo de hechas.
    private func expandedSets(_ ex: SessionExercise) -> [SetLog] {
        if let logs = ex.logs, !logs.isEmpty { return logs }
        return Array(repeating: SetLog(reps: ex.reps, weight: ex.weight), count: max(0, ex.sets))
    }

    private func exerciseCard(_ ex: SessionExercise) -> some View {
        let sets = expandedSets(ex)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.x(ex.name)).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                Spacer()
                Text("\(sets.count) \(sets.count == 1 ? "serie" : "series")")
                    .font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                    .padding(.horizontal, 9).padding(.vertical, 4).background(Brand.greenSoft).clipShape(Capsule())
            }
            VStack(spacing: 0) {
                ForEach(Array(sets.enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Brand.green).frame(width: 24, height: 24)
                            Text("\(i + 1)").font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                        }
                        Text("\(s.reps) reps").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "2c3127"))
                        Spacer()
                        Text("\(fmt(s.weight)) kg").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    }
                    .padding(.vertical, 8)
                    if i < sets.count - 1 { Divider() }
                }
            }
        }
        .padding(14).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
    }

    private func fmt(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }

    private func durationText(_ s: Int) -> String {
        let m = s / 60
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(max(1, m)) min"
    }
    private func weightText(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }
}
