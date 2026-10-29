import AVFoundation
import Observation
import Speech

/// Turns what the person says into text with Apple's speech recognizer.
///
/// Recognition runs on the iPhone when the language supports it; otherwise
/// Apple's speech service is used. The recognizer is made for short requests,
/// so listening stops by itself after `maxListeningTime`.
@MainActor
@Observable
final class SpeechListener {
    enum Failure: LocalizedError {
        case notAuthorized
        case unavailable
        case microphone

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                "Allow Microphone and Speech Recognition for Asla Intervals in Settings to create timers with your voice. You can also type your workout instead."
            case .unavailable:
                "Speech recognition isn't available right now. Check your internet connection, or type your workout instead."
            case .microphone:
                "The microphone couldn't be started. Please try again."
            }
        }
    }

    /// What has been recognized so far. Updates while the person speaks.
    private(set) var transcript = ""
    private(set) var isListening = false

    static let maxListeningTime: Duration = .seconds(45)

    /// Words that help the recognizer with workout vocabulary in both languages.
    private static let contextualStrings = [
        "sekunder", "minutter", "runder", "pause", "hvile", "øvelse",
        "seconds", "minutes", "rounds", "rest", "exercise",
        "burpees", "tabata", "planke", "plank", "knebøy", "squats", "utfall", "lunges",

        // CrossFit exercises, English and Norwegian. Terms Norwegians say in
        // English (wall balls, thrusters, dips) are listed once.
        "push-ups", "armhevinger",
        "pull-ups",
        "sit-ups", "situps",
        "deadlifts", "markløft",
        "box jumps", "boksehopp",
        "jumping jacks", "sprellemann",
        "mountain climbers", "fjellklatrer",
        "kettlebell swings", "kettlebellsving",
        "wall balls",
        "thrusters",
        "double unders", "dobbelthopp",
        "jump rope", "hoppetau",
        "rowing", "roing",
        "toes to bar", "tær til stang",
        "handstand push-ups", "håndstående armhevinger",
        "dips",
        "clean and jerk", "støt",
        "snatch", "rykk",
        "rope climb", "tauklatring",
        "high knees", "høye kneløft",
    ]

    private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var recognizer: SFSpeechRecognizer?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var isAudioRunning = false

    /// Asks for speech recognition and microphone access the first time, and
    /// returns true if both are allowed.
    nonisolated static func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Starts listening. Call `requestPermissions()` first.
    func start(locale: Locale) throws {
        cancel()

        guard let recognizer = Self.makeRecognizer(for: locale), recognizer.isAvailable else {
            throw Failure.unavailable
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw Failure.microphone
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.contextualStrings = Self.contextualStrings
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            Self.deactivateAudioSession()
            throw Failure.microphone
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.makeTapBlock(for: request))
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            Self.deactivateAudioSession()
            throw Failure.microphone
        }

        isAudioRunning = true
        transcript = ""
        isListening = true
        self.recognizer = recognizer
        self.request = request
        task = recognizer.recognitionTask(with: request, resultHandler: Self.makeResultHandler { [weak self] text, isDone in
            Task { @MainActor in
                self?.receive(text: text, isDone: isDone)
            }
        })

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.maxListeningTime)
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    /// Stops listening but keeps the recognizer running, so the final text still arrives.
    func stop() {
        guard isListening else { return }
        stopAudio()
        request?.endAudio()
        isListening = false
    }

    /// Stops everything and drops any result still on its way.
    func cancel() {
        stopAudio()
        task?.cancel()
        task = nil
        request = nil
        isListening = false
    }

    // MARK: Private

    private func receive(text: String?, isDone: Bool) {
        if let text {
            transcript = text
        }
        if isDone {
            stopAudio()
            task = nil
            request = nil
            isListening = false
        }
    }

    private func stopAudio() {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard isAudioRunning else { return }
        isAudioRunning = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        Self.deactivateAudioSession()
    }

    /// The recognizer for the locale, or English (US) if that locale isn't supported.
    private static func makeRecognizer(for locale: Locale) -> SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // The two closures below are called on audio and recognizer threads, so
    // they are made in nonisolated functions to keep them off the main actor.

    nonisolated private static func makeTapBlock(for request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func makeResultHandler(
        _ onUpdate: @escaping @Sendable (String?, Bool) -> Void
    ) -> @Sendable (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            onUpdate(result?.bestTranscription.formattedString, error != nil || (result?.isFinal ?? false))
        }
    }

    /// Turning the audio session off can block, so it happens off the main thread.
    /// Other apps' audio (like music) is told it can resume.
    nonisolated private static func deactivateAudioSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
