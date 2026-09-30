import SwiftUI
import Charts

/// Evolución de UN ejercicio a lo largo del tiempo (entre entrenos distintos):
/// gráfica grande y limpia (peso / reps / 1RM estimado), rango temporal, mejores
/// marcas y el historial de series. Prima la sencillez: una métrica a la vez.
struct ExerciseProgressView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String

    private enum Metric: String, CaseIterable { case peso = "Weight", reps = "Reps", rm = "Est. 1RM" }
    private enum Range: String, CaseIterable { case m1 = "1M", m3 = "3M", all = "All" }
    @State private var metric: Metric = .peso
    @State private var range: Range = .all

    // Una marca por sesión que incluyó el ejercicio (mejor serie de esa sesión).
    private struct Mark: Identifiable {
        let id: String
        let date: Date
        let bestWeight: Double
        let bestReps: Int
        let bestE1RM: Double
        let volume: Double
        let setsSummary: String
    }

    private var allMarks: [Mark] {
        let key = exerciseName.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        var out: [Mark] = []
        for s in store.sessions where s.verified {   // solo entrenos fiables
            for it in (s.items ?? [])
            where it.name.folding(options: .diacriticInsensitive, locale: .current).lowercased() == key {
                let sets: [SetLog] = it.logs ?? Array(repeating: SetLog(reps: it.reps, weight: it.weight), count: max(1, it.sets))
                guard let best = sets.max(by: { e1rm($0.weight, $0.reps) < e1rm($1.weight, $1.reps) }) else { continue }
                out.append(Mark(
                    id: s.id, date: s.date,
                    bestWeight: best.weight, bestReps: best.reps,
                    bestE1RM: e1rm(best.weight, best.reps),
                    volume: sets.reduce(0) { $0 + Double($1.reps) * $1.weight },
                    setsSummary: sets.map { "\(fmt($0.weight))×\($0.reps)" }.joined(separator: " · ")))
            }
        }
        return out.sorted { $0.date < $1.date }
    }

    private var marks: [Mark] {
        guard range != .all else { return allMarks }
        let days: Double = range == .m1 ? 31 : 92
        let from = Date().addingTimeInterval(-days * 24 * 3600)
        let filtered = allMarks.filter { $0.date >= from }
        return filtered.count >= 2 ? filtered : allMarks   // si el rango deja <2 puntos, muestra todo
    }

    private func value(_ m: Mark) -> Double {
        switch metric {
        case .peso: return m.bestWeight
        case .reps: return Double(m.bestReps)
        case .rm:   return m.bestE1RM
        }
    }
    private var unit: String { metric == .reps ? "reps" : "kg" }

    private var deltaPct: Double? {
        guard let f = marks.first, let l = marks.last, value(f) > 0, marks.count >= 2 else { return nil }
        return (value(l) - value(f)) / value(f) * 100
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    picker(Metric.allCases.map(\.rawValue), selected: metric.rawValue) { metric = Metric(rawValue: $0) ?? .peso }
                    chart
                    picker(Range.allCases.map(\.rawValue), selected: range.rawValue) { range = Range(rawValue: $0) ?? .all }
                    statsRow
                    history
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle(L10n.x(exerciseName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { SheetBackButton { dismiss() } } }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Piezas

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let last = marks.last {
                Text(metric == .reps ? "\(last.bestReps)" : fmt(value(last)))
                    .font(.system(size: 40, weight: .heavy)).foregroundColor(Brand.ink)
                Text(unit).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.muted)
                if metric == .peso { Text("× \(last.bestReps)").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.soft) }
            }
            Spacer()
            if let pct = deltaPct {
                let up = pct >= 0.5, flat = abs(pct) < 0.5
                HStack(spacing: 4) {
                    Image(systemName: flat ? "arrow.right" : (up ? "arrow.up.right" : "arrow.down.right"))
                    Text(String(format: "%+.0f%%", pct))
                }
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(flat ? Brand.muted : (up ? Color(hex: "3f7d12") : Color(hex: "a73232")))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(flat ? Brand.chip : (up ? Brand.greenSoft.opacity(0.5) : Brand.redSoft))
                .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var chart: some View {
        if marks.count < 2 {
            PanelCard {
                Text("Aún no hay suficiente historial.")
                    .font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                Text("Haz este ejercicio en un par de entrenos y aquí verás tu evolución.")
                    .font(.footnote).foregroundColor(Brand.muted)
            }
        } else {
            let values = marks.map(value(_:))
            let lo = (values.min() ?? 0), hi = (values.max() ?? 1)
            let pad = max(1, (hi - lo) * 0.25)
            Chart(marks) { m in
                AreaMark(x: .value("Date", m.date), y: .value(unit, value(m)))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Brand.green.opacity(0.32), Brand.green.opacity(0.02)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", m.date), y: .value(unit, value(m)))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Brand.green)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                PointMark(x: .value("Date", m.date), y: .value(unit, value(m)))
                    .foregroundStyle(Color(hex: "4b6211"))
                    .symbolSize(m.id == marks.last?.id ? 90 : 36)
            }
            .chartYScale(domain: max(0, lo - pad)...(hi + pad))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Brand.line.opacity(0.6))
                    AxisValueLabel(format: .dateTime.day().month(), centered: false)
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.soft)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Brand.line.opacity(0.6))
                    AxisValueLabel().font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.soft)
                }
            }
            .frame(height: 220)
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.line))
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            stat(fmt(allMarks.map(\.bestWeight).max() ?? 0) + " kg", "Best weight")
            stat(fmt(allMarks.map(\.bestE1RM).max() ?? 0) + " kg", "Best est. 1RM")
            stat("\(allMarks.count)", "Sessions")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label.uppercased()).font(.system(size: 9, weight: .heavy)).foregroundColor(Brand.soft)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HISTORIAL").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            VStack(spacing: 0) {
                ForEach(Array(allMarks.reversed().prefix(12).enumerated()), id: \.element.id) { i, m in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.date.formatted(.dateTime.day().month(.wide))).font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
                            Text(m.setsSummary).font(.system(size: 12)).foregroundColor(Brand.muted).lineLimit(1)
                        }
                        Spacer()
                        Text("\(fmt(m.bestWeight))×\(m.bestReps)")
                            .font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                    }
                    .padding(.vertical, 9)
                    if i < min(12, allMarks.count) - 1 { Divider() }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 4)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
        }
    }

    private func picker(_ options: [String], selected: String, onPick: @escaping (String) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { opt in
                let active = opt == selected
                Button { FX.selection(); withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { onPick(opt) } } label: {
                    Text(opt).font(.system(size: 13, weight: .heavy))
                        .foregroundColor(active ? Color(hex: "10150a") : Brand.soft)
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(active ? Brand.green : Brand.chip)
                        .clipShape(Capsule())
                }.buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func e1rm(_ w: Double, _ r: Int) -> Double { w * (1 + Double(min(20, r)) / 30) }
    private func fmt(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }
}
