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

enum Brand {
    static let bg = Color(hex: "fbfcf7")
    static let ink = Color(hex: "171913")
    static let muted = Color(hex: "71756d")
    static let soft = Color(hex: "8a8f82")
    static let green = Color(hex: "a7f22d")
    static let greenSoft = Color(hex: "c8e98a")
    static let panel = Color.white.opacity(0.9)
    static let line = Color(hex: "171913").opacity(0.08)
    static let red = Color(hex: "e95752")
    static let redSoft = Color(hex: "fff0ef")
    static let chip = Color(hex: "ece9df")
    static let surface = Color(hex: "f8f6ee")
    static let gold = Color(hex: "ffcf3f")
    static let teal = Color(hex: "26d9c4")
}
