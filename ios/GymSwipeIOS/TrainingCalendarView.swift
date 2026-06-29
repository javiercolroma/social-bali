import SwiftUI

/// Carga para presentar el pop-up de los entrenos de un día.
struct DayPayload: Identifiable {
    let id: Date
    let date: Date
    let sessions: [WorkoutSession]
}

/// Construye el ActivityData de una sesión propia (autor = cuenta del usuario).
@MainActor
func meActivityData(_ s: WorkoutSession, _ store: AppStore) -> ActivityData {
    let loc = [store.profile.city, store.profile.country].filter { !$0.isEmpty }.joined(separator: ", ")
    return ActivityData(
        authorName: store.account?.name ?? "Tú",
        avatarPhoto: store.account?.photoData, avatarEmoji: "🙂",
        flag: countryFlag(store.profile.country), location: loc,
        date: s.date, title: s.name, note: s.note, photo: s.photoData,
        elapsed: s.elapsed, exercises: s.exercises, sets: s.sets,
        volume: s.volume, items: s.items ?? [],
        avgHeartRate: s.avgHeartRate, maxHeartRate: s.maxHeartRate)
}

/// Calendario mensual que resalta los días entrenados. Tocar un día con
/// entreno dispara `onSelectDay` con sus sesiones.
struct TrainingCalendarView: View {
    let sessions: [WorkoutSession]
    var onSelectDay: (Date, [WorkoutSession]) -> Void

    @State private var monthAnchor = Calendar.current.startOfDay(for: Date())

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_ES")
        c.firstWeekday = 2 // lunes
        return c
    }

    private let weekdays = ["L", "M", "X", "J", "V", "S", "D"]

    var body: some View {
        PanelCard {
            header
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { d in
                    Text(d).font(.system(size: 11, weight: .heavy)).foregroundColor(Brand.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 2)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    cell(date)
                }
            }
            HStack(spacing: 8) {
                Circle().fill(Brand.green).frame(width: 10, height: 10)
                Text("Día entrenado").font(.caption2).foregroundColor(Brand.soft)
                Spacer()
                Text("\(trainedThisMonth) este mes").font(.caption2).fontWeight(.heavy).foregroundColor(Color(hex: "4b6211"))
            }
            .padding(.top, 2)
        }
    }

    private var header: some View {
        HStack {
            Text(monthTitle).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
            Spacer()
            Button { shift(-1) } label: { navIcon("chevron.left") }
            Button { shift(1) } label: { navIcon("chevron.right") }
        }
    }

    private func navIcon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
            .frame(width: 34, height: 34).background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func cell(_ date: Date?) -> some View {
        if let date = date {
            let day = cal.component(.day, from: date)
            let daySessions = byDay[cal.startOfDay(for: date)] ?? []
            let trained = !daySessions.isEmpty
            let isToday = cal.isDateInToday(date)
            Button {
                if trained { FX.tap(); onSelectDay(date, daySessions) }
            } label: {
                Text("\(day)")
                    .font(.system(size: 14, weight: trained ? .heavy : .semibold))
                    .foregroundColor(trained ? Color(hex: "10150a") : (isToday ? Brand.ink : Brand.soft))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(trained ? Brand.green : Color.clear))
                    .overlay(Circle().stroke(isToday && !trained ? Brand.green : Color.clear, lineWidth: 2))
                    .overlay(alignment: .bottom) {
                        if daySessions.count > 1 {
                            Text("\(daySessions.count)").font(.system(size: 8, weight: .heavy))
                                .foregroundColor(.white).padding(2).background(Circle().fill(Brand.ink)).offset(y: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(!trained)
        } else {
            // Hueco vacío para los días del mes anterior/siguiente (no se muestran).
            Color.clear.frame(height: 38).frame(maxWidth: .infinity)
        }
    }

    // MARK: - Cálculo

    private var monthStart: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: monthAnchor)) ?? monthAnchor
    }

    private var daysInMonth: Int {
        cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private var leadingBlanks: Int {
        let wd = cal.component(.weekday, from: monthStart)
        return (wd - cal.firstWeekday + 7) % 7
    }

    /// Solo los días de este mes: huecos vacíos (nil) al principio, sin días del mes anterior/siguiente.
    private var cells: [Date?] {
        var arr: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for d in 0..<daysInMonth {
            arr.append(cal.date(byAdding: .day, value: d, to: monthStart))
        }
        return arr
    }

    private var byDay: [Date: [WorkoutSession]] {
        Dictionary(grouping: sessions) { cal.startOfDay(for: $0.date) }
    }

    private var trainedThisMonth: Int {
        byDay.keys.filter { cal.isDate($0, equalTo: monthStart, toGranularity: .month) }.count
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: monthStart).capitalized
    }

    private func shift(_ months: Int) {
        FX.selection()
        if let d = cal.date(byAdding: .month, value: months, to: monthAnchor) {
            monthAnchor = d
        }
    }
}

/// Pop-up con los entrenos guardados de un día concreto.
struct DaySessionsSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let sessions: [WorkoutSession]
    @State private var detail: WorkoutSession?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sessions) { s in card(s) }
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .sheet(item: $detail) { ActivityDetailView(item: meActivityData($0, store)).environmentObject(store) }
    }

    private func card(_ s: WorkoutSession) -> some View {
        Button { FX.tap(); detail = s } label: {
            PanelCard {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill").font(.system(size: 13)).foregroundColor(Color(hex: "6ea300"))
                    Text(s.name).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                }
                if let data = s.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 150).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                HStack(spacing: 8) {
                    mini(durationText(s.elapsed), "Tiempo")
                    mini("\(s.sets)", "Series")
                    mini("\(s.exercises)", "Ejerc.")
                }
            }
        }.buttonStyle(.plain)
    }

    private func mini(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(Brand.muted)
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var title: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEEE d 'de' MMMM"
        return f.string(from: date).capitalized
    }

    private func durationText(_ s: Int) -> String {
        let m = s / 60
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(max(1, m)) min"
    }
}
