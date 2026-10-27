import AVFoundation

/// Abstraction over sound output so the engine can be tested without audio.
@MainActor
protocol SoundPlaying: AnyObject {
    func prepare()
    func playCountdownBeep()
    func playFinishedTone()
    func stop()
}

/// Generates short sine-wave beeps in code – no audio files needed.
///
/// Uses the `.playback` category with `.mixWithOthers`, so beeps are heard even
/// with the silent switch on and play on top of your music instead of stopping it.
/// The audio engine is only built on `prepare()`, so creating a player is cheap.
///
/// Turning the audio session on and off can block for a noticeable time (iOS warns
/// about it on the main thread), so those calls run on a background queue. The
/// engine is started on the main actor once the session is ready.
@MainActor
final class BeepPlayer: SoundPlaying {
    /// Serial, so activations and deactivations always happen in the order requested.
    private static let sessionQueue = DispatchQueue(label: "no.asla.AslaIntervals.audioSession", qos: .userInitiated)

    /// Bumped on every `prepare()` and `stop()`, so a slow activation that finishes
    /// after the workout was stopped or restarted is ignored.
    private var sessionGeneration = 0
    /// True once the session is active; beeps are skipped until then.
    private var isSessionActive = false

    private var engine: AVAudioEngine?
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private lazy var countdownBeep = makeTone(frequency: 880, duration: 0.18)
    private lazy var finishedTone = makeTone(frequency: 1320, duration: 0.8)

    init() {}

    func prepare() {
        sessionGeneration += 1
        let generation = sessionGeneration

        Self.sessionQueue.async {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
            } catch {
                return // No beeps, but the timer itself keeps working.
            }
            Task { @MainActor in
                self.sessionDidActivate(generation: generation)
            }
        }
    }

    func playCountdownBeep() { play(countdownBeep) }

    func playFinishedTone() { play(finishedTone) }

    func stop() {
        sessionGeneration += 1
        isSessionActive = false
        // Stop audio output before the session is turned off.
        player.stop()
        engine?.stop()

        Self.sessionQueue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func sessionDidActivate(generation: Int) {
        // Ignore a late activation from a workout that has since been stopped or restarted.
        guard generation == sessionGeneration else { return }
        isSessionActive = true
        startEngineIfNeeded()
    }

    private func startEngineIfNeeded() {
        let engine: AVAudioEngine
        if let existing = self.engine {
            engine = existing
        } else {
            engine = AVAudioEngine()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            self.engine = engine
        }
        guard !engine.isRunning else { return }
        engine.prepare()
        try? engine.start()
    }

    private func play(_ buffer: AVAudioPCMBuffer) {
        // Starting the engine before the session is active would make iOS activate
        // it on the main thread, so skip the beep instead (only possible in the
        // first moment of a workout).
        guard isSessionActive else { return }
        startEngineIfNeeded()
        guard engine?.isRunning == true else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    private func makeTone(frequency: Double, duration: Double) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        let total = Int(frameCount)
        let fade = Int(sampleRate * 0.01) // 10 ms fade in/out avoids clicks
        for i in 0..<total {
            var amplitude = 0.7
            if i < fade { amplitude *= Double(i) / Double(fade) }
            if i > total - fade { amplitude *= Double(total - i) / Double(fade) }
            samples[i] = Float(sin(2 * .pi * frequency * Double(i) / sampleRate) * amplitude)
        }
        return buffer
    }
}
