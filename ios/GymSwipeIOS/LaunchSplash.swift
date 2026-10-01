import SwiftUI
import CoreText

/// Al abrir la app: el círculo del logo se dibuja a mano con una luz que lo recorre y
/// aparece «Bali Circle.» (como el arranque de ChatGPT o Grindr). El fondo es el mismo
/// lila que la pantalla de carga del sistema (LaunchBackground), así no hay salto.
struct LaunchSplash: View {
    var onFinished: () -> Void
    @State private var drawn: CGFloat = 0
    @State private var glow: CGFloat = 0
    @State private var written: CGFloat = 0     // trazo de las letras y el punto
    @State private var inked: Double = 0        // relleno de las letras al terminar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let paper = Color(red: 0.883, green: 0.845, blue: 0.897)
    static let ink = Color(red: 0.11, green: 0.19, blue: 0.15)

    var body: some View {
        ZStack {
            Self.paper.ignoresSafeArea()
            ZStack {
                // 1) El círculo, dibujándose.
                HandCircle()
                    .trim(from: 0, to: drawn)
                    .stroke(Self.ink, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                // La luz que recorre la forma.
                HandCircle()
                    .trim(from: max(0, glow - 0.07), to: glow)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .blur(radius: 3)
                    .opacity(glow > 0 && glow < 1 ? 0.9 : 0)
                // 2) «Bali Circle.» escribiéndose letra a letra (el contorno se traza y luego se rellena).
                WordmarkShape()
                    .trim(from: 0, to: written)
                    .stroke(Self.ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 128, height: 92)
                WordmarkShape()
                    .fill(Self.ink)
                    .frame(width: 128, height: 92)
                    .opacity(inked)
            }
            .frame(width: 200, height: 200)
        }
        .task {
            if reduceMotion {
                drawn = 1; written = 1; inked = 1
                try? await Task.sleep(nanoseconds: 500_000_000)
                onFinished(); return
            }
            withAnimation(.easeInOut(duration: 0.85)) { drawn = 1 }
            withAnimation(.easeInOut(duration: 1.0)) { glow = 1 }
            try? await Task.sleep(nanoseconds: 650_000_000)
            withAnimation(.easeInOut(duration: 1.1)) { written = 1 }
            try? await Task.sleep(nanoseconds: 950_000_000)
            withAnimation(.easeOut(duration: 0.35)) { inked = 1 }
            try? await Task.sleep(nanoseconds: 250_000_000)
            // Una segunda pasada de luz, más suave, antes de entrar.
            glow = 0
            withAnimation(.easeInOut(duration: 0.8)) { glow = 1 }
            try? await Task.sleep(nanoseconds: 650_000_000)
            onFinished()
        }
    }
}

/// «Bali Circle.» como contornos de letra (Chalkboard SE), para poder «escribirlo» con trim.
struct WordmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let font = CTFontCreateWithName("ChalkboardSE-Light" as CFString, 40, nil)
        let lines = ["Bali", "Circle."]
        let lineHeight: CGFloat = 46
        let full = CGMutablePath()
        for (row, text) in lines.enumerated() {
            let attr = NSAttributedString(string: text, attributes: [.font: font])
            let line = CTLineCreateWithAttributedString(attr)
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            let runs = CTLineGetGlyphRuns(line) as! [CTRun]
            for run in runs {
                let n = CTRunGetGlyphCount(run)
                var glyphs = [CGGlyph](repeating: 0, count: n)
                var positions = [CGPoint](repeating: .zero, count: n)
                CTRunGetGlyphs(run, CFRange(location: 0, length: n), &glyphs)
                CTRunGetPositions(run, CFRange(location: 0, length: n), &positions)
                for i in 0..<n {
                    guard let g = CTFontCreatePathForGlyph(font, glyphs[i], nil) else { continue }
                    // Centrado en su línea; CoreText dibuja hacia arriba, SwiftUI hacia abajo.
                    var t = CGAffineTransform(translationX: positions[i].x - CGFloat(width) / 2,
                                              y: CGFloat(row) * lineHeight + lineHeight * 0.75)
                        .scaledBy(x: 1, y: -1)
                    if let moved = g.copy(using: &t) { full.addPath(moved) }
                }
            }
        }
        // Encaja el conjunto en el rectángulo pedido, centrado.
        let b = full.boundingBoxOfPath
        let scale = min(rect.width / b.width, rect.height / b.height)
        var fit = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -b.midX, y: -b.midY)
        return Path(full.copy(using: &fit) ?? full)
    }
}

/// Círculo «dibujado a mano»: ligeramente irregular, como el del logo.
struct HandCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let R = min(rect.width, rect.height) / 2
        var p = Path()
        let steps = 240
        for i in 0...steps {
            // Empieza arriba a la izquierda y da una vuelta algo más que completa (el cierre a mano).
            let t = Double(i) / Double(steps) * 2.03 * .pi + 2.4
            let r = R * CGFloat(1 + 0.025 * sin(2 * t + 0.7) + 0.015 * sin(3 * t + 2.1))
            let pt = CGPoint(x: c.x + r * CGFloat(cos(t)), y: c.y + r * CGFloat(sin(t)) * 0.97)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        return p
    }
}
