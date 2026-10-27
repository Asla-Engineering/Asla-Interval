import Foundation

/// The numbers that define a Simple workout. Values are clamped to `TimerLimits`.
struct WorkoutSettings: Equatable {
    let exerciseCount: Int
    let roundCount: Int
    let exerciseDuration: Int
    let startCooldown: Int
    let roundCooldown: Int

    init(exerciseCount: Int, roundCount: Int, exerciseDuration: Int, startCooldown: Int, roundCooldown: Int) {
        self.exerciseCount = exerciseCount.clamped(to: TimerLimits.exerciseCount)
        self.roundCount = roundCount.clamped(to: TimerLimits.roundCount)
        self.exerciseDuration = exerciseDuration.clamped(to: TimerLimits.exerciseDuration)
        self.startCooldown = startCooldown.clamped(to: TimerLimits.cooldown)
        self.roundCooldown = roundCooldown.clamped(to: TimerLimits.cooldown)
    }

    /// Exercises × rounds – the "y" in "x / y".
    var totalIntervals: Int { exerciseCount * roundCount }

    /// Full workout length in seconds, including cooldowns.
    var totalDuration: Int {
        WorkoutPlan.phases(for: self).reduce(0) { $0 + $1.duration }
    }
}

struct WorkoutPhase: Equatable {
    enum Kind: Equatable {
        case getReady
        case work
        case rest
    }

    let kind: Kind
    /// Seconds.
    let duration: Int
    /// For `.work`: the interval being performed (1-based).
    /// For `.getReady` / `.rest`: the interval that comes next.
    let intervalNumber: Int
    /// The round this phase belongs to (1-based). Rest belongs to the upcoming round.
    let round: Int
    /// Position of the exercise within its round (1-based), starting over at 1 in
    /// every new round. For `.work`: the exercise being performed.
    /// For `.getReady` / `.rest`: the exercise that comes next.
    let exerciseNumber: Int
    /// Custom timers only: the exercise name. For `.work`: the exercise being
    /// performed. For `.getReady` / `.rest`: the exercise that comes next.
    /// `nil` for Simple timers, which show "Exercise N" instead.
    var title: String? = nil
}

enum WorkoutPlan {
    /// Builds the ordered list of phases: optional start cooldown, then every
    /// exercise interval, with a round cooldown between rounds (not after the last).
    /// Cooldowns set to 0 seconds are skipped.
    static func phases(for settings: WorkoutSettings) -> [WorkoutPhase] {
        var phases: [WorkoutPhase] = []

        if settings.startCooldown > 0 {
            phases.append(WorkoutPhase(kind: .getReady, duration: settings.startCooldown, intervalNumber: 1, round: 1, exerciseNumber: 1))
        }

        var interval = 0
        for round in 1...settings.roundCount {
            for exercise in 1...settings.exerciseCount {
                interval += 1
                phases.append(WorkoutPhase(kind: .work, duration: settings.exerciseDuration, intervalNumber: interval, round: round, exerciseNumber: exercise))
            }
            if round < settings.roundCount, settings.roundCooldown > 0 {
                phases.append(WorkoutPhase(kind: .rest, duration: settings.roundCooldown, intervalNumber: interval + 1, round: round + 1, exerciseNumber: 1))
            }
        }

        return phases
    }
}
