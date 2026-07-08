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

/// Divisiones de gamificación por Gym Score: de Hierro (bajo, apagado) a Maestro (cima, brilla).
/// Cuanto más alta la división, más vivo el color y más brillo (halo) — el nivel se lee a simple vista.
enum ScoreTier: Int, CaseIterable {
    case hierro, bronce, plata, oro, platino, diamante, maestro

    static func of(_ score: Int) -> ScoreTier {
        switch score {
        case ..<15: return .hierro
        case 15..<30: return .bronce
        case 30..<45: return .plata
        case 45..<60: return .oro
        case 60..<75: return .platino
        case 75..<90: return .diamante
        default: return .maestro
        }
    }

    var name: String {
        switch self {
        case .hierro: return "Hierro"; case .bronce: return "Bronce"; case .plata: return "Plata"
        case .oro: return "Oro"; case .platino: return "Platino"; case .diamante: return "Diamante"
        case .maestro: return "Maestro"
        }
    }

    /// Color representativo (para texto/iconos sobre fondo claro).
    var color: Color {
        switch self {
        case .hierro: return Color(hex: "7f878f")
        case .bronce: return Color(hex: "b9742f")
        case .plata: return Color(hex: "8e99a4")
        case .oro: return Color(hex: "e8b020")
        case .platino: return Color(hex: "3f93bd")
        case .diamante: return Color(hex: "1fc0e0")
        case .maestro: return Color(hex: "8a63ff")
        }
    }

    /// Relleno del badge: apagado/grisáceo abajo, vívido y saturado arriba.
    var fill: AnyShapeStyle {
        func grad(_ a: String, _ b: String) -> AnyShapeStyle {
            AnyShapeStyle(LinearGradient(colors: [Color(hex: a), Color(hex: b)], startPoint: .top, endPoint: .bottom))
        }
        switch self {
        case .hierro: return grad("aab0b6", "808890")     // gris apagado
        case .bronce: return grad("cf9560", "9c5f29")
        case .plata: return grad("d6dee5", "9fabb6")
        case .oro: return grad("ffd84d", "e6a812")
        case .platino: return grad("c2eaf2", "5fb8d8")
        case .diamante: return grad("8af0ff", "1fc0e6")
        case .maestro: return grad("b58cff", "5ad6ff")    // gradiente vívido (cima)
        }
    }

    var textColor: Color { self == .maestro ? .white : Color(hex: "10150a") }

    /// Halo: nulo en divisiones bajas, intenso en las altas (las de prestigio "brillan").
    var glow: (color: Color, radius: CGFloat) {
        switch self {
        case .hierro, .bronce: return (color, 0)
        case .plata: return (color, 1)
        case .oro: return (Color(hex: "e8b020"), 2.5)
        case .platino: return (Color(hex: "5fb8d8"), 4)
        case .diamante: return (Color(hex: "2cd3f0"), 6)
        case .maestro: return (Color(hex: "8a63ff"), 9)
        }
    }

    var symbol: String {
        switch self {
        case .hierro, .bronce, .plata: return "shield.fill"
        case .oro, .platino: return "rosette"
        case .diamante: return "diamond.fill"
        case .maestro: return "crown.fill"
        }
    }
}

/// Badge del Gym Score para la esquina inferior derecha de un avatar (sustituye la banderita).
/// El color y el brillo reflejan la división (Hierro → Maestro). Úsalo en `ZStack(alignment: .bottomTrailing)`.
struct ScoreBadge: View {
    let score: Int
    var avatarSize: CGFloat = 42
    var body: some View {
        let t = ScoreTier.of(score)
        let f = max(9, avatarSize * 0.30)
        let k = avatarSize / 42
        Text("\(score)")
            .font(.system(size: f, weight: .heavy)).foregroundColor(t.textColor)
            .padding(.horizontal, f * 0.42).frame(minWidth: f * 1.6, minHeight: f * 1.5)
            .background(t.fill).clipShape(Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: max(1, avatarSize * 0.045)))
            .shadow(color: t.glow.color.opacity(0.95), radius: t.glow.radius * k)
            .offset(x: avatarSize * 0.16, y: avatarSize * 0.12)
    }
}

/// Píldora de puntuación teñida con su división (Hierro→Maestro): gradiente metálico
/// + icono de tier + glow que crece con el nivel. Para mostrar un score "en línea"
/// (ranking, partner…) con el mismo efecto de rango que los badges de avatar.
struct ScorePill: View {
    let score: Int
    var body: some View {
        let t = ScoreTier.of(score)
        HStack(spacing: 4) {
            Image(systemName: t.symbol).font(.system(size: 10, weight: .heavy))
            Text("\(score)").font(.system(size: 14, weight: .heavy)).monospacedDigit()
        }
        .foregroundColor(t.textColor)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(t.fill).clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
        .shadow(color: t.glow.color.opacity(0.9), radius: t.glow.radius)
    }
}

/// Avatar (emoji o foto) con el Gym Score en la esquina inferior derecha.
/// Reemplaza la antigua banderita en todos los perfiles de la app.
struct ScoredAvatar: View {
    var emoji: String = "🙂"
    var account: Account? = nil   // si se pasa, usa la foto de la cuenta (MeAvatar)
    var avatarURL: String? = nil  // foto real remota (usuarios reales); emoji de fallback
    let score: Int
    var size: CGFloat = 42

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let account { MeAvatar(account: account, size: size) }
            else if let a = avatarURL, let u = URL(string: a) {
                AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: { Avatar(emoji: emoji, size: size) }
                    .frame(width: size, height: size).clipShape(Circle())
            } else { Avatar(emoji: emoji, size: size) }
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
            Text(NSLocalizedString(s.label, comment: "").uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.4)
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
    var data: Data? = nil
    var url: String? = nil
    var height: CGFloat = 190
    private var uiImage: UIImage? { data.flatMap(UIImage.init) }
    private var remote: URL? { data == nil ? url.flatMap(URL.init(string:)) : nil }
    var body: some View {
        if uiImage != nil || remote != nil {
            content
                .frame(maxWidth: .infinity).frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Brand.line))
        }
    }
    @ViewBuilder private var content: some View {
        if let ui = uiImage {
            Image(uiImage: ui).resizable().scaledToFill()
        } else if let u = remote {
            AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: { Brand.chip }
        }
    }
}

/// Sub-pestañas con **deslizamiento horizontal** (estilo páginas): al cambiar de sección
/// la vista actual sale y la nueva entra deslizándose en la dirección del cambio, en vez de
/// un simple fundido/corte. Ambas páginas quedan montadas (conservan su estado y scroll).
struct SlidingPages<A: View, B: View>: View {
    let index: Int
    @ViewBuilder var first: () -> A
    @ViewBuilder var second: () -> B

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                first().frame(width: geo.size.width, height: geo.size.height)
                second().frame(width: geo.size.width, height: geo.size.height)
            }
            .offset(x: -CGFloat(index) * geo.size.width)
            .animation(.spring(response: 0.4, dampingFraction: 0.88), value: index)
        }
        .clipped()
    }
}

/// Portada visual para entrenos SIN foto: gradiente de marca, mancuerna en marca de
/// agua y un dato héroe (volumen movido). El feed nunca se ve como una pila de texto.
struct WorkoutCover: View {
    let elapsed: Int
    let sets: Int
    let volume: Double
    var exercises: Int = 0
    var seed: String = ""     // algo estable del post (título+fecha) para variar el héroe
    var height: CGFloat = 150

    /// Héroe VARIADO por tarjeta (estable por post, no cambia al re-renderizar):
    /// a veces el tiempo, a veces las series, a veces los ejercicios.
    private var hero: (String, String, String) {
        var h: UInt64 = 1469598103934665603
        for c in seed.unicodeScalars { h = (h ^ UInt64(c.value)) &* 1099511628211 }
        var options: [(String, String, String)] = []
        if elapsed >= 60 { options.append(("\(max(1, elapsed / 60)) min", "De entreno",
            "\(sets) series" + (exercises > 0 ? " · \(exercises) ejercicios" : ""))) }
        if sets > 0 { options.append(("\(sets)", sets == 1 ? "Serie completada" : "Series completadas",
            "\(max(1, elapsed / 60)) min" + (exercises > 0 ? " · \(exercises) ejercicios" : ""))) }
        if exercises > 0 { options.append(("\(exercises)", exercises == 1 ? "Ejercicio" : "Ejercicios",
            "\(max(1, elapsed / 60)) min · \(sets) series")) }
        guard !options.isEmpty else { return ("💪", "Entreno completado", "") }
        return options[Int(h % UInt64(options.count))]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Brand.greenSoft.opacity(0.85), Color(hex: "eef7d8")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "dumbbell.fill")
                .font(.system(size: height * 0.62, weight: .bold))
                .foregroundColor(Brand.green.opacity(0.30))
                .rotationEffect(.degrees(-18))
                .offset(x: height * 0.62, y: height * 0.16)
            VStack(alignment: .leading, spacing: 3) {
                Text(hero.0).font(.system(size: 34, weight: .heavy)).foregroundColor(Brand.ink)
                Text(hero.1).font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "4b6211"))
                if !hero.2.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11, weight: .bold))
                        Text(hero.2).font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundColor(Brand.muted).padding(.top, 5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Foto de la tarjeta: LLENA el marco (scaledToFill, recorte mínimo centrado) para que una
/// foto horizontal 4:3 no deje márgenes ni descuadre el tamaño de la tarjeta — todas las
/// tarjetas quedan idénticas. La versión SIN recortes vive en el visor a pantalla completa.
struct FullWorkoutPhoto: View {
    let data: Data?
    let url: String?
    var height: CGFloat = 320

    var body: some View {
        ZStack {
            Brand.chip
            if let d = data, let ui = UIImage(data: d) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if let u = url, let link = URL(string: u) {
                AsyncImage(url: link) { img in img.resizable().scaledToFill() } placeholder: { ProgressView() }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Fila compacta de medallas (emoji oro/plata/bronce) del entreno, estilo Strava.
struct WorkoutMedalsRow: View {
    let medals: [SessionMedal]
    var size: CGFloat = 26
    var body: some View {
        if medals.isEmpty { EmptyView() }
        else {
            HStack(spacing: 6) {
                ForEach(medals.prefix(5)) { m in Text(m.emoji).font(.system(size: size)) }
            }
        }
    }
}

/// Tarjetas de PROGRESO estilo Strava: cada ejercicio mejorado como una tarjeta blanca con
/// icono + nombre + «Antes → Ahora» + insignia del delta (+5%, +3 reps, PR), y una píldora
/// «N/M mejoraron». Los avances tienen así más protagonismo que las métricas normales.
struct WorkoutProgressCards: View {
    let insights: [ProgressInsight]
    let totalExercises: Int
    var maxCards: Int = 3

    private var exercise: [ProgressInsight] { insights.filter { $0.isExercise } }

    var body: some View {
        let ex = exercise
        if ex.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 9) {
                ForEach(ex.prefix(maxCards)) { card($0) }
                if totalExercises > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.green)
                        Text(String(format: NSLocalizedString("%1$lld/%2$lld mejoraron", comment: ""),
                                    min(ex.count, totalExercises), totalExercises))
                            .font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.white).clipShape(Capsule())
                }
            }
        }
    }

    private func card(_ ins: ProgressInsight) -> some View {
        let isPR = ins.kind == .newPR
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Brand.greenSoft)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: ins.exerciseIcon).font(.system(size: 18, weight: .semibold)).foregroundColor(Color(hex: "4b6211")))
            VStack(alignment: .leading, spacing: 3) {
                Text(ins.displaySubject).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                if ins.hasBeforeAfter {
                    HStack(spacing: 6) {
                        Text(ins.beforeText).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.soft)
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .heavy)).foregroundColor(Brand.green)
                        Text(ins.afterText).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                        Text(ins.unit).font(.system(size: 10, weight: .bold)).foregroundColor(Brand.muted)
                    }
                } else {
                    Text(ins.localizedText).font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.soft)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            VStack(spacing: 3) {
                ZStack {
                    Circle().fill(isPR ? Color(hex: "e8b020").opacity(0.18) : Brand.green.opacity(0.16)).frame(width: 30, height: 30)
                    Image(systemName: ins.icon).font(.system(size: 13, weight: .bold))
                        .foregroundColor(isPR ? Color(hex: "b8860b") : Color(hex: "4b6211"))
                }
                Text(ins.deltaBadge).font(.system(size: 13, weight: .heavy))
                    .foregroundColor(isPR ? Color(hex: "b8860b") : Color(hex: "4b6211")).fixedSize()
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Página de INFORMACIÓN de la tarjeta: 2ª página del pager (al deslizar la foto) o portada
/// cuando no hay foto. RESUMEN VISUAL premium: los LOGROS/PROGRESOS destacan (tarjetas
/// Antes→Ahora + medallas) sobre las métricas normales (tira de stats abajo). La foto tiene
/// la prioridad en la 1ª pantalla; al deslizar llega este detalle.
struct WorkoutInfoPanel: View {
    let elapsed: Int
    let sets: Int
    let exercises: Int
    var ppm: Int? = nil
    var insights: [ProgressInsight] = []
    var medals: [SessionMedal] = []
    /// Altura fija (página del pager, para casar con la foto) o nil = ajusta al contenido (sin foto).
    var height: CGFloat? = nil

    private var timeText: String {
        let m = elapsed / 60
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(max(1, m)) min"
    }
    private var hasHighlights: Bool { !medals.isEmpty || insights.contains { $0.isExercise } }
    private var cardCount: Int { height == nil ? 3 : 2 }   // fijo (pager) muestra menos para casar altura

    var body: some View {
        ZStack {
            LinearGradient(colors: [Brand.greenSoft.opacity(0.60), Color(hex: "eef7d8")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 12) {
                if !medals.isEmpty { WorkoutMedalsRow(medals: medals, size: 30) }
                WorkoutProgressCards(insights: insights, totalExercises: exercises, maxCards: cardCount)
                WorkoutStatStrip(stats: WorkoutStatStrip.metrics(time: timeText, sets: sets,
                                                 exercises: exercises, ppm: ppm), style: .full)
            }
            .padding(14).frame(maxWidth: .infinity)
            .frame(maxHeight: height == nil ? nil : .infinity, alignment: .center)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// EL medio visual de TODA tarjeta de entreno (regla: post = historial = perfiles =
/// calendario = detalle). Con foto → pager [FOTO limpia protagonista | INFO (logros+stats+
/// progreso)]: primero la foto, al deslizar el detalle. Sin foto → el panel de info directo.
/// Cambios de tarjeta se hacen AQUÍ, una vez.
struct WorkoutMedia: View {
    let photoData: Data?
    let photoURL: String?
    let elapsed: Int
    let sets: Int
    let volume: Double
    let exercises: Int
    let seed: String
    var height: CGFloat = 150
    var ppm: Int? = nil
    var insights: [ProgressInsight] = []
    var medals: [SessionMedal] = []

    var body: some View {
        if photoData != nil || photoURL != nil {
            TabView {
                FullWorkoutPhoto(data: photoData, url: photoURL, height: height)
                WorkoutInfoPanel(elapsed: elapsed, sets: sets, exercises: exercises,
                                 ppm: ppm, insights: insights, medals: medals, height: height)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            // Puntitos discretos: sin la cápsula de fondo del sistema.
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            // Sin foto: el panel de info ES la tarjeta (resumen visual premium) y se ajusta a
            // su contenido — sin gradiente vacío ni hueco reservado para imagen.
            WorkoutInfoPanel(elapsed: elapsed, sets: sets, exercises: exercises,
                             ppm: ppm, insights: insights, medals: medals, height: nil)
        }
    }
}

/// Visor a PANTALLA COMPLETA de la foto del entreno: aspect-fit sobre negro (sin recortes,
/// proporción correcta) con pellizco para ampliar. Se cierra con la X.
struct FullScreenPhotoView: View {
    let data: Data?
    let url: String?
    var onClose: () -> Void
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                if let d = data, let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFit()
                } else if let u = url, let link = URL(string: u) {
                    AsyncImage(url: link) { img in img.resizable().scaledToFit() } placeholder: { ProgressView().tint(.white) }
                }
            }
            .scaleEffect(scale)
            .gesture(MagnificationGesture()
                .onChanged { scale = max(1, min(4, $0)) }
                .onEnded { _ in withAnimation(.spring(response: 0.3)) { scale = 1 } })
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .heavy)).foregroundColor(.white)
                            .frame(width: 38, height: 38).background(.black.opacity(0.45)).clipShape(Circle())
                    }.padding(16)
                }
                Spacer()
            }
        }
    }
}

/// Foto PROTAGONISTA con efecto elástico: al tirar del scroll hacia abajo, la foto se
/// amplía (estilo post). Aspect-fit sobre blanco (sin recortes). Tocarla → callback.
struct StretchyWorkoutPhoto: View {
    let data: Data?
    let url: String?
    var baseHeight: CGFloat
    /// Espacio de coordenadas del ScrollView contenedor: en él, en reposo, minY = 0 (arriba
    /// del contenido), y solo crece al tirar hacia abajo. Con `.global` la línea base sería
    /// el inset de la nav bar (~100pt) → la foto saldría pre-estirada y metida bajo la barra.
    var space: String = "activityScroll"
    var onTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named(space)).minY
            let stretch = max(0, minY)   // cuánto se ha tirado hacia abajo (0 en reposo)
            ZStack {
                Color.white
                if let d = data, let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFit()
                } else if let u = url, let link = URL(string: u) {
                    AsyncImage(url: link) { img in img.resizable().scaledToFit() } placeholder: { Brand.chip }
                }
            }
            .frame(width: geo.size.width, height: baseHeight + stretch)
            .clipped()
            .offset(y: -stretch)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
        .frame(height: baseHeight)
    }
}

/// Tira de PROGRESO de la tarjeta: traduce el historial en 1-3 avances legibles
/// ("En remo sentado subiste el peso un 5%"), en vez de cifras brutas. Se renderiza
/// AQUÍ una vez (regla de fuente única) y aparece en toda tarjeta cuyo entreno lleve
/// insights (solo los propios); vacío → no ocupa nada.
struct WorkoutInsightsStrip: View {
    let insights: [ProgressInsight]
    var body: some View {
        if insights.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 10, weight: .heavy))
                    Text(LocalizedStringKey("Progreso")).font(.system(size: 10, weight: .heavy)).tracking(0.6)
                }
                .foregroundColor(Color(hex: "4b6211"))
                ForEach(insights.prefix(3)) { ins in
                    HStack(spacing: 9) {
                        ZStack {
                            Circle().fill(ins.kind == .newPR ? Color(hex: "e8b020").opacity(0.20) : Brand.green.opacity(0.16))
                                .frame(width: 24, height: 24)
                            Image(systemName: ins.icon).font(.system(size: 11, weight: .bold))
                                .foregroundColor(ins.kind == .newPR ? Color(hex: "b8860b") : Color(hex: "4b6211"))
                        }
                        Text(ins.localizedText).font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Brand.ink).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.greenSoft.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Brand.green.opacity(0.22)))
        }
    }
}

/// Flecha de VOLVER para hojas (pop-ups): circulito con chevron, arriba a la izquierda.
/// (Deslizar hacia abajo sigue funcionando; esto da una salida visible y familiar.)
struct SheetBackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(width: 34, height: 34).background(Brand.chip).clipShape(Circle())
        }.buttonStyle(.plain)
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
