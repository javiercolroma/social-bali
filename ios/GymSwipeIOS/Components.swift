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

struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Brand.onAccent)
            .frame(maxWidth: .infinity).frame(minHeight: 54)
            .background(Brand.accent.opacity(enabled ? 1 : 0.25))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct Tag: View {
    let text: String
    var highlight = false
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(highlight ? Brand.ink : Color(hex: "394234"))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(highlight ? Brand.sand : Brand.chip)
            .clipShape(Capsule())
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
    let f = DateFormatter(); f.locale = L10n.locale
    if cal.isDateInToday(date) { f.dateFormat = "HH:mm"; return f.string(from: date) }
    if cal.isDateInYesterday(date) { return "Yesterday" }
    f.dateFormat = "d MMM"; return f.string(from: date)
}

func relativeTime(_ date: Date) -> String {
    if Calendar.current.isDateInToday(date) {
        let mins = max(0, Int(-date.timeIntervalSinceNow / 60))
        if mins < 1 { return "Now" }
        if mins < 60 { return "\(mins) min ago" }
        return "\(mins / 60) h ago"
    }
    let f = DateFormatter()
    f.locale = L10n.locale
    f.dateFormat = "d MMM, HH:mm"
    return f.string(from: date)
}
