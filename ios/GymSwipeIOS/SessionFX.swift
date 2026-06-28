import SwiftUI
import UIKit
import AVFoundation

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
        if sound && soundOn { Synth.shared.success() }
    }
    /// Destructive / cautionary action.
    static func warning() { if hapticsOn { Haptics.warning() } }
    /// Starting a workout — always a sound (if sounds on) + success haptic.
    static func start() { if hapticsOn { Haptics.success() }; if soundOn { Synth.shared.start() } }
}

/// Tiny tone synthesizer — generates short melodic cues so the app's sounds
/// have personality (no audio files needed).
final class Synth {
    static let shared = Synth()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private let format: AVAudioFormat
    private var ready = false

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    private func ensureRunning() {
        guard !ready else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        do { try engine.start(); ready = true } catch { ready = false }
    }

    /// note = (frequency Hz, start seconds, duration seconds)
    private func play(_ notes: [(Double, Double, Double)], gain: Float = 0.45) {
        ensureRunning()
        guard ready else { return }
        let total = (notes.map { $0.1 + $0.2 }.max() ?? 0.3) + 0.05
        let frames = AVAudioFrameCount(total * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        let out = buffer.floatChannelData![0]
        for i in 0..<Int(frames) { out[i] = 0 }
        for (freq, start, dur) in notes {
            let s = Int(start * sampleRate)
            let d = Int(dur * sampleRate)
            for j in 0..<d {
                let idx = s + j
                if idx >= Int(frames) { break }
                let t = Double(j) / sampleRate
                let attack = min(1, t / 0.006)
                let decay = exp(-3.2 * t / dur)
                out[idx] += Float(sin(2 * .pi * freq * t) * attack * decay) * gain
            }
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    // Notes (Hz)
    private let c5 = 523.25, d5 = 587.33, e5 = 659.25, g5 = 783.99, a5 = 880.0, b5 = 987.77, c6 = 1046.5, e6 = 1318.5, g4 = 392.0

    func start()    { play([(c5, 0, 0.12), (e5, 0.08, 0.12), (g5, 0.16, 0.13), (c6, 0.25, 0.22)], gain: 0.5) }
    func done()     { play([(c6, 0, 0.11)], gain: 0.4) }
    func exercise() { play([(e5, 0, 0.12), (b5, 0.1, 0.18)], gain: 0.45) }
    func skip()     { play([(g4, 0, 0.1)], gain: 0.28) }
    func rest()     { play([(g5, 0, 0.12), (c6, 0.14, 0.18)], gain: 0.42) }
    func success()  { play([(g5, 0, 0.11), (c6, 0.09, 0.2)], gain: 0.42) }
    func finish()   { play([(c5, 0, 0.13), (e5, 0.11, 0.13), (g5, 0.22, 0.13), (c6, 0.33, 0.16),
                            (c5, 0.42, 0.45), (e5, 0.42, 0.45), (g5, 0.42, 0.45)], gain: 0.4) }
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
