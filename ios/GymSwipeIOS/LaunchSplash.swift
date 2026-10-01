import SwiftUI

/// Al abrir la app: el círculo del logo se dibuja a mano con una luz que lo recorre y
/// aparece «Bali Circle.» (como el arranque de ChatGPT o Grindr). El fondo es el mismo
/// lila que la pantalla de carga del sistema (LaunchBackground), así no hay salto.
struct LaunchSplash: View {
    var onFinished: () -> Void
    @State private var drawn: CGFloat = 0
    @State private var glow: CGFloat = 0
    @State private var textIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let paper = Color(red: 0.883, green: 0.845, blue: 0.897)
    static let ink = Color(red: 0.11, green: 0.19, blue: 0.15)

    var body: some View {
        ZStack {
            Self.paper.ignoresSafeArea()
            ZStack {
                // El trazo del círculo, dibujándose.
                HandCircle()
                    .trim(from: 0, to: drawn)
                    .stroke(Self.ink, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                // La luz que recorre la forma.
                HandCircle()
                    .trim(from: max(0, glow - 0.07), to: glow)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .blur(radius: 3)
                    .opacity(glow > 0 && glow < 1 ? 0.9 : 0)
                Text("Bali\nCircle.")
                    .font(.custom("ChalkboardSE-Light", size: 40))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-6)
                    .foregroundColor(Self.ink)
                    .opacity(textIn ? 1 : 0)
                    .scaleEffect(textIn ? 1 : 0.94)
            }
            .frame(width: 200, height: 200)
        }
        .task {
            if reduceMotion {
                drawn = 1; textIn = true
                try? await Task.sleep(nanoseconds: 500_000_000)
                onFinished(); return
            }
            withAnimation(.easeInOut(duration: 0.9)) { drawn = 1 }
            withAnimation(.easeInOut(duration: 1.1)) { glow = 1 }
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(.easeOut(duration: 0.5)) { textIn = true }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            // Una segunda pasada de luz, más suave, antes de entrar.
            glow = 0
            withAnimation(.easeInOut(duration: 0.8)) { glow = 1 }
            try? await Task.sleep(nanoseconds: 700_000_000)
            onFinished()
        }
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
