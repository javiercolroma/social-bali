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
    /// Sonidos apagados: los heredados de la app anterior no encajan con el club.
    static var soundOn: Bool { false }

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
}

/// Tiny tone synthesizer — a short, warm two-note cue for positive moments
/// (no audio files needed).
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
    /// Seno puro y suave, con rampa de entrada y salida para que no chasquee. Sin
    /// armónicos duros ni clipping: tonos limpios y discretos.
    private func play(_ notes: [(Double, Double, Double)], gain: Float = 0.32) {
        ensureRunning()
        guard ready else { return }
        let total = (notes.map { $0.1 + $0.2 }.max() ?? 0.3) + 0.06
        let frames = AVAudioFrameCount(total * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        let out = buffer.floatChannelData![0]
        let n = Int(frames)
        for i in 0..<n { out[i] = 0 }
        for (freq, start, dur) in notes {
            let s = Int(start * sampleRate)
            let d = Int(dur * sampleRate)
            for j in 0..<d {
                let idx = s + j
                if idx >= n { break }
                let t = Double(j) / sampleRate
                let attack = min(1, t / 0.010)                                  // fade-in suave
                let release = min(1, Double(d - j) / sampleRate / 0.045)        // fade-out suave (sin click)
                let decay = exp(-2.8 * t / dur)
                out[idx] += Float(sin(2 * .pi * freq * t) * attack * decay * release) * gain
            }
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    // Notes (Hz)
    private let g5 = 783.99, c6 = 1046.5

    func success()  { play([(g5, 0, 0.12), (c6, 0.10, 0.20)], gain: 0.30) }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
