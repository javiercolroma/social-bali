import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        if cleaned.count == 8 {
            r = Double((value >> 24) & 0xff) / 255
            g = Double((value >> 16) & 0xff) / 255
            b = Double((value >> 8) & 0xff) / 255
            a = Double(value & 0xff) / 255
        } else {
            r = Double((value >> 16) & 0xff) / 255
            g = Double((value >> 8) & 0xff) / 255
            b = Double(value & 0xff) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Paleta de Bali Circle: marfil cálido, tinta casi negra y un acento arena/bronce.
/// Elegante y adulta — nada de verde lima de app de gimnasio.
enum Brand {
    static let bg = Color(hex: "f7f4ee")         // marfil
    static let ink = Color(hex: "161514")        // tinta
    static let muted = Color(hex: "6f6a62")
    static let soft = Color(hex: "a09a90")
    /// Relleno de los botones principales (negro) y su texto.
    static let accent = Color(hex: "161514")
    static let onAccent = Color(hex: "faf8f3")
    /// Arena: chips seleccionados, burbujas propias, fondos suaves.
    static let sand = Color(hex: "e9e0d0")
    static let sandDeep = Color(hex: "d8cab2")
    /// Bronce: iconos y textos de acento sobre fondo claro.
    static let bronze = Color(hex: "8a6a3d")
    static let online = Color(hex: "34c46a")
    static let panel = Color.white
    static let line = Color(hex: "161514").opacity(0.08)
    static let red = Color(hex: "d9534f")
    static let redSoft = Color(hex: "f8ebe7")
    static let redText = Color(hex: "a33a2f")
    static let chip = Color(hex: "efeae1")
    static let surface = Color(hex: "f2eee6")
}

extension Font {
    /// Titulares con serifa (New York): el toque editorial de la marca.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
