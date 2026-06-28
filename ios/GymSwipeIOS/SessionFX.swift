import SwiftUI
import UIKit
import AudioToolbox

enum Haptics {
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func rigid() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

/// App-wide feedback helper that respects the user's Sonidos/Vibración toggles.
enum FX {
    static var hapticsOn: Bool { UserDefaults.standard.object(forKey: "fxHaptics") as? Bool ?? true }
    static var soundOn: Bool { UserDefaults.standard.object(forKey: "fxSound") as? Bool ?? true }

    /// Light feedback for routine taps (navigation, toggles, minor actions).
    static func tap() { if hapticsOn { Haptics.soft() } }
    /// Selection change (tab switch, segmented control).
    static func selection() { if hapticsOn { Haptics.selection() } }
    /// Meaningful positive moment. Plays a sound only when `sound` is true.
    static func success(sound: Bool = false) {
        if hapticsOn { Haptics.success() }
        if sound && soundOn { SoundFX.play(SoundFX.done) }
    }
    /// Destructive / cautionary action.
    static func warning() { if hapticsOn { Haptics.warning() } }
    /// Starting a workout — always a sound (if sounds on) + success haptic.
    static func start() { if hapticsOn { Haptics.success() }; if soundOn { SoundFX.play(SoundFX.start) } }
}

enum SoundFX {
    static let start: SystemSoundID = 1113     // empezar entreno
    static let done: SystemSoundID = 1057      // Tink (serie hecha)
    static let skip: SystemSoundID = 1104      // Tock
    static let exercise: SystemSoundID = 1054  // cambio de ejercicio (distinto a serie)
    static let rest: SystemSoundID = 1075      // fin de descanso
    static let finish: SystemSoundID = 1025    // entreno terminado
    static func play(_ id: SystemSoundID) { AudioServicesPlaySystemSound(id) }
}

/// Lightweight celebratory confetti, animates once on appear.
struct ConfettiView: View {
    @State private var go = false
    private let colors: [Color] = [Brand.green, Brand.gold, Brand.teal, Brand.red, Color(hex: "ff8a3d")]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<26, id: \.self) { i in
                    ConfettiPiece(index: i, color: colors[i % colors.count], size: geo.size, go: go)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { go = true }
    }
}

private struct ConfettiPiece: View {
    let index: Int
    let color: Color
    let size: CGSize
    let go: Bool

    var body: some View {
        let x = CGFloat((index * 61) % Int(max(1, size.width)))
        let endY = size.height + 30
        let duration = 1.1 + Double(index % 5) * 0.25
        let delay = Double(index % 6) * 0.06
        return RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 7, height: 11)
            .position(x: x, y: go ? endY : -30)
            .rotationEffect(.degrees(go ? Double((index * 71) % 360) : 0))
            .opacity(go ? 0 : 1)
            .animation(.easeIn(duration: duration).delay(delay), value: go)
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
