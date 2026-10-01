import SwiftUI

/// Al abrir la app: el círculo del logo se dibuja a mano con una luz que lo recorre y
/// aparece «Bali Circle.» (como el arranque de ChatGPT o Grindr). El fondo es el mismo
/// lila que la pantalla de carga del sistema (LaunchBackground), así no hay salto.
struct LaunchSplash: View {
    var onFinished: () -> Void
    @State private var drawn: CGFloat = 0
    @State private var glow: CGFloat = 0
    @State private var written: CGFloat = 0     // cuánto se ha escrito de «Bali Circle.»
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
                // 2) «Bali Circle.» escrito a mano, trazo a trazo, como con el rotulador del logo.
                HandwrittenWordmark()
                    .trim(from: 0, to: written)
                    .stroke(Self.ink, style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 118, height: 96)
            }
            .frame(width: 200, height: 200)
        }
        .task {
            if reduceMotion {
                drawn = 1; written = 1
                try? await Task.sleep(nanoseconds: 500_000_000)
                onFinished(); return
            }
            withAnimation(.easeInOut(duration: 0.85)) { drawn = 1 }
            withAnimation(.easeInOut(duration: 1.0)) { glow = 1 }
            try? await Task.sleep(nanoseconds: 650_000_000)
            withAnimation(.linear(duration: 1.5)) { written = 1 }
            try? await Task.sleep(nanoseconds: 1_550_000_000)
            // Una segunda pasada de luz, más suave, antes de entrar.
            glow = 0
            withAnimation(.easeInOut(duration: 0.8)) { glow = 1 }
            try? await Task.sleep(nanoseconds: 650_000_000)
            onFinished()
        }
    }
}

/// «Bali Circle.» como TRAZOS de rotulador (una línea por trazo, en el orden en que se
/// escribiría a mano), para que `trim` lo escriba de verdad y no repase contornos.
/// Coordenadas en una caja de 150 × 132: «Bali» arriba, «Circle.» abajo.
struct HandwrittenWordmark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // ─── Bali (línea base y = 56, altura de x = 30, mayúsculas desde y = 4) ───
        let ox: CGFloat = 26
        // B: palo y dos panzas
        p.move(to: CGPoint(x: ox, y: 4)); p.addLine(to: CGPoint(x: ox, y: 56))
        p.move(to: CGPoint(x: ox, y: 4))
        p.addCurve(to: CGPoint(x: ox, y: 28), control1: CGPoint(x: ox + 24, y: 2), control2: CGPoint(x: ox + 24, y: 28))
        p.addCurve(to: CGPoint(x: ox, y: 56), control1: CGPoint(x: ox + 30, y: 28), control2: CGPoint(x: ox + 30, y: 58))
        // a: panza y palo
        p.move(to: CGPoint(x: ox + 50, y: 34))
        p.addCurve(to: CGPoint(x: ox + 37, y: 56), control1: CGPoint(x: ox + 40, y: 26), control2: CGPoint(x: ox + 30, y: 44))
        p.addCurve(to: CGPoint(x: ox + 51, y: 44), control1: CGPoint(x: ox + 43, y: 62), control2: CGPoint(x: ox + 50, y: 54))
        p.move(to: CGPoint(x: ox + 51, y: 30))
        p.addCurve(to: CGPoint(x: ox + 55, y: 56), control1: CGPoint(x: ox + 51, y: 44), control2: CGPoint(x: ox + 51, y: 56))
        // l
        p.move(to: CGPoint(x: ox + 66, y: 2))
        p.addCurve(to: CGPoint(x: ox + 69, y: 56), control1: CGPoint(x: ox + 66, y: 30), control2: CGPoint(x: ox + 65, y: 56))
        // i y su punto
        p.move(to: CGPoint(x: ox + 80, y: 30)); p.addLine(to: CGPoint(x: ox + 80, y: 56))
        p.move(to: CGPoint(x: ox + 80, y: 16)); p.addLine(to: CGPoint(x: ox + 80.6, y: 16.4))

        // ─── Circle. (línea base y = 124) ───
        let oy: CGFloat = 68, cx: CGFloat = 8
        // C
        p.move(to: CGPoint(x: cx + 30, y: oy + 10))
        p.addCurve(to: CGPoint(x: cx + 2, y: oy + 32), control1: CGPoint(x: cx + 22, y: oy - 2), control2: CGPoint(x: cx + 2, y: oy + 6))
        p.addCurve(to: CGPoint(x: cx + 32, y: oy + 52), control1: CGPoint(x: cx + 2, y: oy + 58), control2: CGPoint(x: cx + 24, y: oy + 60))
        // i y su punto
        p.move(to: CGPoint(x: cx + 42, y: oy + 26)); p.addLine(to: CGPoint(x: cx + 42, y: oy + 56))
        p.move(to: CGPoint(x: cx + 42, y: oy + 12)); p.addLine(to: CGPoint(x: cx + 42.6, y: oy + 12.4))
        // r
        p.move(to: CGPoint(x: cx + 54, y: oy + 26)); p.addLine(to: CGPoint(x: cx + 54, y: oy + 56))
        p.move(to: CGPoint(x: cx + 54, y: oy + 38))
        p.addCurve(to: CGPoint(x: cx + 70, y: oy + 28), control1: CGPoint(x: cx + 58, y: oy + 28), control2: CGPoint(x: cx + 64, y: oy + 26))
        // c
        p.move(to: CGPoint(x: cx + 94, y: oy + 32))
        p.addCurve(to: CGPoint(x: cx + 77, y: oy + 42), control1: CGPoint(x: cx + 88, y: oy + 22), control2: CGPoint(x: cx + 77, y: oy + 28))
        p.addCurve(to: CGPoint(x: cx + 95, y: oy + 53), control1: CGPoint(x: cx + 77, y: oy + 58), control2: CGPoint(x: cx + 90, y: oy + 58))
        // l
        p.move(to: CGPoint(x: cx + 104, y: oy - 2))
        p.addCurve(to: CGPoint(x: cx + 107, y: oy + 56), control1: CGPoint(x: cx + 104, y: oy + 28), control2: CGPoint(x: cx + 103, y: oy + 56))
        // e: barra y vuelta
        p.move(to: CGPoint(x: cx + 115, y: oy + 42))
        p.addLine(to: CGPoint(x: cx + 136, y: oy + 41))
        p.addCurve(to: CGPoint(x: cx + 117, y: oy + 30), control1: CGPoint(x: cx + 137, y: oy + 30), control2: CGPoint(x: cx + 125, y: oy + 26))
        p.addCurve(to: CGPoint(x: cx + 137, y: oy + 54), control1: CGPoint(x: cx + 108, y: oy + 40), control2: CGPoint(x: cx + 116, y: oy + 64))
        // el punto final
        p.move(to: CGPoint(x: cx + 146, y: oy + 54)); p.addLine(to: CGPoint(x: cx + 146.8, y: oy + 54.6))

        // Encaja la caja de 150 × 132 en el rectángulo pedido.
        let box = CGRect(x: 0, y: 0, width: 156, height: 128)
        let scale = min(rect.width / box.width, rect.height / box.height)
        let t = CGAffineTransform(translationX: rect.midX - box.midX * scale, y: rect.midY - box.midY * scale)
            .scaledBy(x: scale, y: scale)
        return p.applying(t)
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
