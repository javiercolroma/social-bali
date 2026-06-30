import SwiftUI

struct PanelCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Brand.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
    }
}

struct ScoreBarView: View {
    let label: String
    let value: Int
    var body: some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 13, weight: .bold)).foregroundColor(Brand.muted)
                .frame(width: 78, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Brand.chip)
                    Capsule().fill(Brand.green)
                        .frame(width: max(6, geo.size.width * CGFloat(value) / 100))
                }
            }
            .frame(height: 9)
            Text("\(value)").font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(width: 26, alignment: .trailing)
        }
    }
}

struct Avatar: View {
    let emoji: String
    var size: CGFloat = 42
    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(Brand.chip)
            .clipShape(Circle())
    }
}

/// Divisiones de gamificación por Gym Score: de Bronce a Diamante. Solo a nivel visual.
/// El color tiñe el badge del nivel en el avatar (y se puede mostrar como chip en el perfil).
enum ScoreTier {
    case bronce, plata, oro, platino, diamante

    static func of(_ score: Int) -> ScoreTier {
        switch score {
        case ..<20: return .bronce
        case 20..<40: return .plata
        case 40..<60: return .oro
        case 60..<80: return .platino
        default: return .diamante
        }
    }

    var name: String {
        switch self {
        case .bronce: return "Bronce"; case .plata: return "Plata"; case .oro: return "Oro"
        case .platino: return "Platino"; case .diamante: return "Diamante"
        }
    }

    /// Color base de la división (para texto/iconos sobre fondo claro).
    var color: Color {
        switch self {
        case .bronce: return Color(hex: "b9742f")
        case .plata: return Color(hex: "9aa6b2")
        case .oro: return Color(hex: "e8b020")
        case .platino: return Color(hex: "4a93b8")
        case .diamante: return Color(hex: "2bbbd6")
        }
    }

    /// Relleno del badge (degradado metálico sutil para dar empaque "tech").
    var fill: AnyShapeStyle {
        func grad(_ a: String, _ b: String) -> AnyShapeStyle {
            AnyShapeStyle(LinearGradient(colors: [Color(hex: a), Color(hex: b)], startPoint: .top, endPoint: .bottom))
        }
        switch self {
        case .bronce: return grad("d99553", "b06a26")
        case .plata: return grad("d2dae1", "a3afba")
        case .oro: return grad("ffd84d", "e6a812")
        case .platino: return grad("bfe6ec", "6fbdd6")
        case .diamante: return grad("8af0ff", "29c3e6")
        }
    }

    var textColor: Color { Color(hex: "10150a") }
    var symbol: String { self == .diamante ? "diamond.fill" : "shield.fill" }
}

/// Badge del Gym Score para la esquina inferior derecha de un avatar (sustituye la banderita).
/// El color refleja la división (Bronce → Diamante). Úsalo en un `ZStack(alignment: .bottomTrailing)`.
struct ScoreBadge: View {
    let score: Int
    var avatarSize: CGFloat = 42
    var body: some View {
        let f = max(9, avatarSize * 0.30)
        Text("\(score)")
            .font(.system(size: f, weight: .heavy)).foregroundColor(ScoreTier.of(score).textColor)
            .padding(.horizontal, f * 0.42).frame(minWidth: f * 1.6, minHeight: f * 1.5)
            .background(ScoreTier.of(score).fill).clipShape(Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: max(1, avatarSize * 0.045)))
            .offset(x: avatarSize * 0.16, y: avatarSize * 0.12)
    }
}

/// Avatar (emoji o foto) con el Gym Score en la esquina inferior derecha.
/// Reemplaza la antigua banderita en todos los perfiles de la app.
struct ScoredAvatar: View {
    var emoji: String = "🙂"
    var account: Account? = nil   // si se pasa, usa la foto de la cuenta (MeAvatar)
    let score: Int
    var size: CGFloat = 42

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let account { MeAvatar(account: account, size: size) }
            else { Avatar(emoji: emoji, size: size) }
            ScoreBadge(score: score, avatarSize: size)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .heavy))
            .foregroundColor(Color(hex: "10150a"))
            .frame(maxWidth: .infinity).frame(minHeight: 50)
            .background(enabled ? Brand.green : Brand.greenSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct Tag: View {
    let text: String
    var highlight = false
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(highlight ? Color(hex: "10150a") : Color(hex: "394234"))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(highlight ? Brand.greenSoft : Brand.chip)
            .clipShape(Capsule())
    }
}

// MARK: - Workout card building blocks (shared by feed, activity, profile, calendar)

/// Discreto tile neutro con la mancuerna — afordance de "entreno" sin colores llamativos.
struct WorkoutTypeBadge: View {
    enum Size { case full, compact }
    var size: Size = .full
    private var side: CGFloat { size == .full ? 32 : 26 }
    private var glyph: CGFloat { size == .full ? 14 : 12 }
    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Brand.chip)
            .frame(width: side, height: side)
            .overlay(Image(systemName: "dumbbell.fill")
                .font(.system(size: glyph, weight: .semibold))
                .foregroundColor(Brand.soft))
    }
}

/// One metric in the stat strip. `tint` is ink except ppm (red). Icons only show in `.full`.
struct WorkoutStat: Identifiable {
    let id = UUID()
    let value: String
    let label: String
    let icon: String
    var tint: Color = Brand.ink

    static func time(_ s: String) -> WorkoutStat { .init(value: s, label: "Tiempo", icon: "clock") }
    static func sets(_ n: Int) -> WorkoutStat { .init(value: "\(n)", label: "Series", icon: "square.stack.3d.up") }
    static func exercises(_ n: Int) -> WorkoutStat { .init(value: "\(n)", label: "Ejerc.", icon: "list.bullet") }
    static func ppm(_ n: Int) -> WorkoutStat { .init(value: "\(n)", label: "ppm", icon: "heart.fill", tint: Brand.red) }
}

/// THE shared stat strip — one Brand.surface wash with hairline dividers (never gappy pills).
/// `.full` (feed) = taller, micro-icons; `.compact` (history rows) = smaller, no icons.
struct WorkoutStatStrip: View {
    enum Style { case full, compact }
    let stats: [WorkoutStat]
    var style: Style = .full

    private var valueSize: CGFloat { style == .full ? 16 : 14 }
    private var vPad: CGFloat { style == .full ? 11 : 7 }
    private var dividerH: CGFloat { style == .full ? 26 : 20 }
    private var showIcons: Bool { style == .full }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { idx, s in
                if idx > 0 { Rectangle().fill(Brand.line).frame(width: 1, height: dividerH) }
                cell(s)
            }
        }
        .padding(.vertical, vPad)
        .frame(maxWidth: .infinity)
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func cell(_ s: WorkoutStat) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                if showIcons {
                    Image(systemName: s.icon).font(.system(size: 10, weight: .semibold))
                        .foregroundColor(s.tint == Brand.ink ? Brand.soft : s.tint)
                }
                Text(s.value).font(.system(size: valueSize, weight: .heavy, design: .rounded))
                    .foregroundColor(Brand.ink).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            }
            Text(s.label.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.4)
                .foregroundColor(Brand.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity).contentShape(Rectangle())
    }

    /// Single source of truth for the metrics — no volume, no XP.
    static func metrics(time: String, sets: Int, exercises: Int, ppm: Int?) -> [WorkoutStat] {
        var m: [WorkoutStat] = [.time(time), .sets(sets), .exercises(exercises)]
        if let ppm { m.append(.ppm(ppm)) }
        return m
    }
}

/// Uniform photo block (rounded + hairline so light images don't bleed on the cream bg).
struct WorkoutPhoto: View {
    let data: Data
    var height: CGFloat = 190
    var body: some View {
        if let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(maxWidth: .infinity).frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Brand.line))
        }
    }
}

func shortTime(_ date: Date) -> String {
    let cal = Calendar.current
    let f = DateFormatter()
    if cal.isDateInToday(date) { f.dateFormat = "HH:mm"; return f.string(from: date) }
    if cal.isDateInYesterday(date) { return "Ayer" }
    f.dateFormat = "d MMM"; return f.string(from: date)
}

func relativeTime(_ date: Date) -> String {
    if Calendar.current.isDateInToday(date) {
        let mins = max(0, Int(-date.timeIntervalSinceNow / 60))
        if mins < 1 { return "Ahora" }
        if mins < 60 { return "Hace \(mins) min" }
        return "Hace \(mins / 60) h"
    }
    let f = DateFormatter()
    f.locale = Locale(identifier: "es_ES")
    f.dateFormat = "d MMM, HH:mm"
    return f.string(from: date)
}
