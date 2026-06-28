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
