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
/// have personality (no audio files needed). One warm bell instrument moving up a
/// C-major pentatonic scale: up = progress/reward, low-soft = neutral skip, a held
/// major triad = workout finished. Keeps the whole session sounding composed.
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

    // Marimba/bell-like partials (fundamental + octave + fifth-octave) for a warm, premium tone.
    private let partials: [(mult: Double, amp: Double)] = [(1.0, 1.0), (2.0, 0.38), (3.0, 0.13)]

    /// note = (frequency Hz, start seconds, duration seconds)
    private func play(_ notes: [(Double, Double, Double)], gain: Float = 0.45) {
        ensureRunning()
        guard ready else { return }
        let total = (notes.map { $0.1 + $0.2 }.max() ?? 0.3) + 0.08
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
                let attack = min(1, t / 0.006)
                let decay = exp(-3.4 * t / dur)
                var sample = 0.0
                for p in partials { sample += sin(2 * .pi * freq * p.mult * t) * p.amp }
                out[idx] += Float(sample * attack * decay) * gain
            }
        }
        // Soft clip so overlapping harmonics never distort.
        for i in 0..<n { out[i] = max(-1, min(1, out[i])) }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    // Notes (Hz) — C major pentatonic across octaves
    private let g4 = 392.0, c5 = 523.25, d5 = 587.33, e5 = 659.25, g5 = 783.99, a5 = 880.0
    private let c6 = 1046.5, d6 = 1174.66, e6 = 1318.5, g6 = 1567.98, a6 = 1760.0
    private lazy var ladder = [c6, d6, e6, g6, a6]

    func start()    { play([(c5, 0, 0.12), (e5, 0.08, 0.12), (g5, 0.16, 0.13), (c6, 0.25, 0.24)], gain: 0.5) }

    /// Set completed. `step` climbs the pentatonic ladder with the combo (0-based);
    /// hot streaks (step ≥ 3) add a perfect-fifth sparkle so building a streak shimmers.
    func done(step: Int = 0) {
        let i = max(0, min(step, ladder.count - 1))
        let n = ladder[i]
        var notes: [(Double, Double, Double)] = [(n, 0, 0.12)]
        if i >= 3 { notes.append((n * 1.5, 0.05, 0.13)) }
        play(notes, gain: 0.4)
    }

    func skip()     { play([(g4, 0, 0.10)], gain: 0.26) }                                  // low, soft, no judgment
    func exercise() { play([(e5, 0, 0.11), (g5, 0.10, 0.11), (c6, 0.20, 0.18)], gain: 0.45) } // chapter cleared
    func restOver() { play([(g5, 0, 0.10), (c6, 0.10, 0.16)], gain: 0.34) }                // rest over → go

    /// Checkpoint: halfway (full=false) or session complete (full=true).
    func milestone(full: Bool) {
        if full { play([(c6, 0, 0.10), (e6, 0.10, 0.10), (g6, 0.20, 0.18)], gain: 0.45) }
        else    { play([(g5, 0, 0.12), (d6, 0.12, 0.18)], gain: 0.45) }
    }

    func success()  { play([(g5, 0, 0.11), (c6, 0.09, 0.2)], gain: 0.42) }
    func finish()   { play([(c5, 0, 0.13), (e5, 0.11, 0.13), (g5, 0.22, 0.13), (c6, 0.33, 0.18),
                            (c5, 0.46, 0.5), (e5, 0.46, 0.5), (g5, 0.46, 0.5),       // sustained C-major triad
                            (c6, 0.6, 0.16), (e6, 0.72, 0.2)], gain: 0.38) }          // top-octave sparkle
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
