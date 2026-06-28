import SwiftUI
import Charts

/// Pestaña "Actividad" con dos secciones:
///  - Progreso: métricas elaboradas (1RM estimado por ejercicio + tendencia
///    de volumen por sesión/semana), no solo la suma bruta de kilos.
///  - Actividades: histórico de sesiones guardadas (lista + detalle).
struct ActivityView: View {
    @EnvironmentObject var store: AppStore
    @State private var section = 0
    @State private var detail: WorkoutSession?
    @State private var daySheet: DayPayload?
    @State private var showEpleyInfo = false

    private let tabs: [(title: String, icon: String)] = [
        ("Progreso", "chart.line.uptrend.xyaxis"),
        ("Actividades", "clock.arrow.circlepath"),
    ]

    private var sessions: [WorkoutSession] { store.sessions.sorted { $0.date > $1.date } }
    private var sessionsChrono: [WorkoutSession] { store.sessions.sorted { $0.date < $1.date } }

    var body: some View {
        VStack(spacing: 0) {
            switcher
            ScrollView {
                VStack(spacing: 12) {
                    if section == 0 { progressContent } else { historyContent }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
        }
        .background(Brand.bg)
        .sheet(item: $detail) { ActivityDetailView(item: activityData($0)).environmentObject(store) }
        .sheet(item: $daySheet) { DaySessionsSheet(date: $0.date, sessions: $0.sessions).environmentObject(store) }
    }

    private var switcher: some View {
        HStack(spacing: 6) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { idx, t in
                let active = section == idx
                Button { FX.selection(); section = idx } label: {
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

    // MARK: - PROGRESO

    @ViewBuilder
    private var progressContent: some View {
        rachaCard
        gymScoreCard
        TrainingCalendarView(sessions: sessions) { date, daySessions in
            daySheet = DayPayload(id: date, date: date, sessions: daySessions)
        }
        if store.sessions.isEmpty {
            Text("Completa y guarda entrenos para medir tu evolución de carga.")
                .font(.footnote).foregroundColor(Brand.muted)
                .frame(maxWidth: .infinity, alignment: .center).padding(.top, 6)
        } else {
            trendCard
            strengthCard
            if store.sessions.count < 2 {
                Text("Guarda al menos 2 entrenos para ver tendencias más fiables.")
                    .font(.caption).foregroundColor(Brand.soft)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.top, 2)
            }
        }
    }

    /// Tendencia general: progreso de carga (1RM medio) + volumen semanal.
    private var trendCard: some View {
        PanelCard {
            Text("TENDENCIA").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            trendTile("Carga (1RM medio)", strengthTrendPct, "dumbbell.fill")
            Text("Compara tu 1RM estimado actual con el primero que registraste, promediado entre tus ejercicios.")
                .font(.caption2).foregroundColor(Brand.soft)
        }
    }

    private func trendTile(_ label: String, _ pct: Double?, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(Color(hex: "6ea300"))
            if let pct = pct {
                let up = pct >= 0
                HStack(spacing: 3) {
                    Image(systemName: up ? "arrow.up.right" : "arrow.down.right").font(.system(size: 12, weight: .heavy))
                    Text("\(up ? "+" : "")\(Int(pct.rounded()))%").font(.system(size: 20, weight: .heavy))
                }.foregroundColor(up ? Color(hex: "3f7d12") : Color(hex: "a73232"))
            } else {
                Text("—").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.soft)
            }
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Fuerza estimada (1RM) por ejercicio: la medida certera del progreso de carga.
    private var strengthCard: some View {
        PanelCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fuerza por ejercicio").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("1RM estimado (fórmula de Epley)").font(.caption2).foregroundColor(Brand.soft)
                }
                Spacer()
                Button { FX.tap(); showEpleyInfo = true } label: {
                    Image(systemName: "info.circle").font(.system(size: 19)).foregroundColor(Brand.soft)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Qué es el 1RM estimado")
            }
            if liftProgress.isEmpty {
                Text("Registra series con peso y repeticiones para estimar tu 1RM.")
                    .font(.footnote).foregroundColor(Brand.muted)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(liftProgress.prefix(6).enumerated()), id: \.element.id) { i, lift in
                        liftRow(lift)
                        if i < min(6, liftProgress.count) - 1 { Divider().padding(.vertical, 2) }
                    }
                }
            }
        }
        .alert("1RM estimado (Epley)", isPresented: $showEpleyInfo) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Tu 1RM es el peso máximo que podrías levantar una sola vez. Medirlo de verdad es arriesgado, así que se estima a partir de una serie normal con la fórmula de Epley:\n\n1RM ≈ peso × (1 + repeticiones / 30)\n\nTomamos tu mejor serie de cada entreno, de modo que el progreso refleja tu fuerza real y no solo el volumen total. Es más fiable en series de 1 a 12 repeticiones.")
        }
    }

    private func liftRow(_ lift: LiftProgress) -> some View {
        let delta = lift.current - lift.first
        let pct = lift.first > 0 ? delta / lift.first * 100 : 0
        let hasTrend = lift.points.count >= 2
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(lift.name).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(fmt(lift.current)) kg").font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                        .padding(.horizontal, 8).padding(.vertical, 2).background(Brand.greenSoft).clipShape(Capsule())
                    if hasTrend && abs(delta) >= 0.5 {
                        let up = delta >= 0
                        HStack(spacing: 2) {
                            Image(systemName: up ? "arrow.up" : "arrow.down").font(.system(size: 9, weight: .heavy))
                            Text("\(up ? "+" : "")\(fmt(delta)) kg · \(up ? "+" : "")\(Int(pct.rounded()))%")
                                .font(.system(size: 11, weight: .heavy))
                        }.foregroundColor(up ? Color(hex: "3f7d12") : Color(hex: "a73232"))
                    } else if !hasTrend {
                        Text("nuevo").font(.system(size: 11, weight: .heavy)).foregroundColor(Brand.soft)
                    }
                }
            }
            Spacer()
            if hasTrend {
                Chart(lift.points) { pt in
                    LineMark(x: .value("f", pt.date), y: .value("1RM", pt.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color(hex: "6ea300"))
                    AreaMark(x: .value("f", pt.date), y: .value("1RM", pt.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(LinearGradient(colors: [Brand.green.opacity(0.25), .clear],
                                                        startPoint: .top, endPoint: .bottom))
                }
                .chartXAxis(.hidden).chartYAxis(.hidden)
                .frame(width: 84, height: 38)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - ACTIVIDADES (histórico)

    @ViewBuilder
    private var historyContent: some View {
        if sessions.isEmpty {
            emptyState(icon: "clock.arrow.circlepath",
                       title: "Aún no tienes actividad",
                       msg: "Completa y guarda un entreno para ver aquí tu historial.")
        } else {
            ForEach(sessions) { s in sessionCard(s) }
        }
    }

    /// Racha en horizontal, de extremo a extremo, con el número dentro de una llama.
    private var rachaCard: some View {
        PanelCard {
            HStack(spacing: 16) {
                ZStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "ffb33b"), Color(hex: "f0560a")],
                                                        startPoint: .top, endPoint: .bottom))
                    Text("\(store.player.streak)")
                        .font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
                        .offset(y: 9)
                }
                .frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.player.streak == 1 ? "1 día en racha" : "\(store.player.streak) días en racha")
                        .font(.system(size: 19, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("\(sessionsThisWeek) \(sessionsThisWeek == 1 ? "entreno" : "entrenos") esta semana")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(Brand.soft)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Gym Score igual que en Comunidad: puntuación + tier + fiabilidad + barras de pilares.
    private var gymScoreCard: some View {
        let s = store.gymScore
        return PanelCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("GYM SCORE").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    Text("\(s.total)").font(.system(size: 48, weight: .heavy)).foregroundColor(Brand.ink)
                    Text(s.tier).font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                        .padding(.horizontal, 10).padding(.vertical, 3).background(Brand.greenSoft).clipShape(Capsule())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(s.reliable ? "Fiable · \(s.reliability)%" : "Provisional")
                        .font(.system(size: 11, weight: .heavy)).foregroundColor(s.reliable ? Color(hex: "18320d") : Color(hex: "7a4d00"))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(s.reliable ? Color(hex: "dff0bf") : Color(hex: "ffe2a3")).clipShape(Capsule())
                    if !s.reliable {
                        Text("Faltan \(s.daysUntilReliable) días").font(.caption2).foregroundColor(Brand.soft)
                    }
                }
            }
            if !s.reliable {
                Text("Entrena 3 semanas para tu score real (potencial \(s.potential)).")
                    .font(.footnote).foregroundColor(Brand.muted)
            }
            VStack(spacing: 8) {
                ScoreBarView(label: "Fuerza", value: s.strength)
                ScoreBarView(label: "Constancia", value: s.consistency)
                ScoreBarView(label: "Progreso", value: s.progression)
                ScoreBarView(label: "Volumen", value: s.volume)
                ScoreBarView(label: "Calidad", value: s.quality)
                ScoreBarView(label: "Variedad", value: s.variety)
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

    private func sessionCard(_ s: WorkoutSession) -> some View {
        Button { FX.tap(); detail = s } label: {
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
        }.buttonStyle(.plain)
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(Brand.muted)
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func emptyState(icon: String, title: String, msg: String) -> some View {
        VStack(spacing: 14) {
            Spacer(minLength: 30)
            ZStack {
                Circle().fill(Brand.greenSoft).frame(width: 88, height: 88)
                Image(systemName: icon).font(.system(size: 34, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
            }
            Text(title).font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink)
            Text(msg).font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity).padding(.top, 10)
    }

    // MARK: - Métricas

    private struct E1RMPoint: Identifiable { let id = UUID(); let date: Date; let value: Double }
    private struct LiftProgress: Identifiable { let id: String; let name: String; let current: Double; let first: Double; let points: [E1RMPoint] }

    /// 1RM estimado (Epley): w · (1 + reps/30).
    private func e1rm(_ w: Double, _ reps: Int) -> Double { w * (1 + Double(reps) / 30) }

    private var liftProgress: [LiftProgress] {
        var map: [String: [E1RMPoint]] = [:]
        for s in sessionsChrono {
            for ex in (s.items ?? []) {
                let sets = ex.logs ?? Array(repeating: SetLog(reps: ex.reps, weight: ex.weight), count: max(1, ex.sets))
                let best = sets.map { e1rm($0.weight, $0.reps) }.max() ?? 0
                if best <= 0 { continue }
                map[ex.name, default: []].append(E1RMPoint(date: s.date, value: best))
            }
        }
        return map.compactMap { name, pts -> LiftProgress? in
            let sorted = pts.sorted { $0.date < $1.date }
            guard let first = sorted.first, let last = sorted.last else { return nil }
            return LiftProgress(id: name, name: name, current: last.value, first: first.value, points: sorted)
        }
        .sorted { ($0.points.count, $0.current) > ($1.points.count, $1.current) }
    }

    /// Variación media (%) del 1RM estimado entre el primer y el último registro de cada ejercicio con tendencia.
    private var strengthTrendPct: Double? {
        let tracked = liftProgress.filter { $0.points.count >= 2 && $0.first > 0 }
        guard !tracked.isEmpty else { return nil }
        let pcts = tracked.map { ($0.current - $0.first) / $0.first * 100 }
        return pcts.reduce(0, +) / Double(pcts.count)
    }

    // MARK: - Helpers

    private func fmt(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }

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
