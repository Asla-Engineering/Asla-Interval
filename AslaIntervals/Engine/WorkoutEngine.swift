import Foundation
import Observation

/// Runs a workout: counts down each phase and beeps on the last three seconds.
///
/// Time is measured against wall-clock end dates rather than by counting ticks,
/// so the countdown never drifts and catches up correctly after the app has been
/// in the background.
@MainActor
@Observable
final class WorkoutEngine {
    enum State: Equatable {
        case ready
        case running
        case paused
        case finished
    }

    let phases: [WorkoutPhase]
    /// Number of rounds, for "Round x of y".
    let roundCount: Int
    /// Number of exercise intervals – the "y" in "x / y".
    let totalIntervals: Int

    private(set) var state: State = .ready
    private(set) var phaseIndex = 0
    /// Whole seconds left in the current phase (what the big number shows).
    private(set) var secondsRemaining: Int
    /// 0...1, how much of the current phase has elapsed. Drives the progress ring.
    private(set) var phaseProgress: Double = 0

    @ObservationIgnored private var phaseEndDate: Date?
    @ObservationIgnored private var pausedTimeLeft: TimeInterval = 0
    @ObservationIgnored private var lastBeepSecond: Int?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    private let sound: SoundPlaying

    /// Number of final seconds in each phase that get a beep.
    static let beepSeconds = 3

    /// Uses the real `BeepPlayer`. Created inside the initializer (which runs on the
    /// main actor) rather than as a default argument, because default arguments are
    /// evaluated outside the main actor in Swift 5 mode.
    convenience init(settings: WorkoutSettings) {
        self.init(settings: settings, sound: BeepPlayer())
    }

    /// Runs a Custom timer with the real `BeepPlayer`.
    convenience init(custom: CustomWorkoutSettings) {
        self.init(custom: custom, sound: BeepPlayer())
    }

    /// Lets tests inject a silent `SoundPlaying` implementation.
    convenience init(settings: WorkoutSettings, sound: SoundPlaying) {
        self.init(phases: WorkoutPlan.phases(for: settings),
                  roundCount: settings.roundCount,
                  totalIntervals: settings.totalIntervals,
                  sound: sound)
    }

    convenience init(custom: CustomWorkoutSettings, sound: SoundPlaying) {
        self.init(phases: CustomWorkoutPlan.phases(for: custom),
                  roundCount: custom.roundCount,
                  totalIntervals: custom.totalIntervals,
                  sound: sound)
    }

    init(phases: [WorkoutPhase], roundCount: Int, totalIntervals: Int, sound: SoundPlaying) {
        self.phases = phases
        self.roundCount = roundCount
        self.totalIntervals = totalIntervals
        self.sound = sound
        self.secondsRemaining = phases.first?.duration ?? 0
    }

    var currentPhase: WorkoutPhase? {
        phases.indices.contains(phaseIndex) ? phases[phaseIndex] : nil
    }

    /// The "x" in "x / y".
    var currentInterval: Int {
        state == .finished ? totalIntervals : (currentPhase?.intervalNumber ?? 1)
    }

    // MARK: Controls

    func start(now: Date = .now) {
        guard let first = phases.first else { return }
        sound.prepare()
        phaseIndex = 0
        lastBeepSecond = nil
        phaseEndDate = now.addingTimeInterval(TimeInterval(first.duration))
        state = .running
        tick(now: now)
        startTicking()
    }

    func pause(now: Date = .now) {
        guard state == .running, let end = phaseEndDate else { return }
        pausedTimeLeft = max(0, end.timeIntervalSince(now))
        phaseEndDate = nil
        state = .paused
        stopTicking()
    }

    func resume(now: Date = .now) {
        guard state == .paused else { return }
        phaseEndDate = now.addingTimeInterval(pausedTimeLeft)
        state = .running
        tick(now: now)
        startTicking()
    }

    func togglePause() {
        state == .running ? pause() : resume()
    }

    /// Stops everything and releases audio. Call when leaving the workout screen.
    func stop() {
        stopTicking()
        phaseEndDate = nil
        sound.stop()
    }

    // MARK: Ticking

    private func startTicking() {
        stopTicking()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// Advances the countdown to `now`. Internal (not private) so it can be unit tested.
    func tick(now: Date = .now) {
        guard state == .running, var end = phaseEndDate else { return }

        // Move past every phase whose end date has already passed.
        while end <= now {
            guard phaseIndex + 1 < phases.count else {
                finish()
                return
            }
            phaseIndex += 1
            lastBeepSecond = nil
            end = end.addingTimeInterval(TimeInterval(phases[phaseIndex].duration))
        }
        phaseEndDate = end

        let timeLeft = end.timeIntervalSince(now)
        let wholeSeconds = Int(timeLeft.rounded(.up))
        if wholeSeconds != secondsRemaining {
            secondsRemaining = wholeSeconds
        }

        let duration = Double(phases[phaseIndex].duration)
        phaseProgress = duration > 0 ? min(1, max(0, 1 - timeLeft / duration)) : 1

        // Beep once at 3, 2 and 1 seconds left.
        if (1...Self.beepSeconds).contains(wholeSeconds), wholeSeconds != lastBeepSecond {
            lastBeepSecond = wholeSeconds
            sound.playCountdownBeep()
        }
    }

    private func finish() {
        stopTicking()
        phaseEndDate = nil
        phaseIndex = phases.count - 1
        secondsRemaining = 0
        phaseProgress = 1
        state = .finished
        sound.playFinishedTone()
    }
}
