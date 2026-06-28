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
    let elapsed: Int
    let exercises: Int
    let sets: Int
    let volume: Double
    let items: [SessionExercise]
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
                            Text(item.flag).font(.system(size: 12)).frame(width: 18, height: 18)
                                .background(Circle().fill(.white)).overlay(Circle().stroke(Brand.line)).offset(x: 3, y: 3)
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

                    if let data = item.photo, let ui = UIImage(data: data) {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 220).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Metrics
                    HStack(spacing: 10) {
                        metric(durationText(item.elapsed), "Tiempo", "clock")
                        metric("\(item.sets)", "Series", "checkmark.circle")
                    }
                    HStack(spacing: 10) {
                        metric("\(Int(item.volume)) kg", "Volumen", "dumbbell.fill")
                        metric("\(item.exercises)", "Ejercicios", "list.bullet")
                    }

                    // Exercises
                    if !item.items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("EJERCICIOS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                            ForEach(Array(item.items.enumerated()), id: \.offset) { idx, ex in
                                let info = setSummary(ex)
                                HStack(spacing: 12) {
                                    Text("\(idx + 1)").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.muted).frame(width: 22)
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text(ex.name).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.ink)
                                            Spacer()
                                            Text(info.headline).font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                                        }
                                        HStack(spacing: 5) {
                                            ForEach(0..<info.dots, id: \.self) { _ in
                                                Circle().fill(Brand.green).frame(width: 11, height: 11)
                                            }
                                            Text(info.detail).font(.footnote).foregroundColor(Brand.muted)
                                        }
                                    }
                                }
                                .padding(12).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line))
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Actividad").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
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

    /// Builds "4 × 6" headline and a weight detail. If reps/weights vary per set,
    /// lists them per set (e.g. "70 · 72.5 · 75 kg").
    private func setSummary(_ ex: SessionExercise) -> (dots: Int, headline: String, detail: String) {
        let logs = ex.logs ?? []
        let reps = logs.isEmpty ? [ex.reps] : logs.map { $0.reps }
        let weights = logs.isEmpty ? [ex.weight] : logs.map { $0.weight }
        let count = logs.isEmpty ? max(1, ex.sets) : logs.count

        let repsUniform = Set(reps).count <= 1
        let repsText = repsUniform ? "\(reps.first ?? ex.reps)" : reps.map { "\($0)" }.joined(separator: "·")
        let headline = "\(count) × \(repsText)"

        let weightsUniform = Set(weights).count <= 1
        let weightText = weightsUniform
            ? "\(fmt(weights.first ?? ex.weight)) kg"
            : weights.map { fmt($0) }.joined(separator: " · ") + " kg"
        return (count, headline, weightText)
    }

    private func fmt(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }

    private func durationText(_ s: Int) -> String {
        let m = s / 60
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(max(1, m)) min"
    }
    private func weightText(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }
}
