import Foundation

/// The numbers that define a Custom workout. Values are clamped to `CustomTimerLimits`.
struct CustomWorkoutSettings: Equatable {
    let intervals: [CustomInterval]
    let roundCount: Int
    let startCooldown: Int
    let roundCooldown: Int

    init(intervals: [CustomInterval], roundCount: Int, startCooldown: Int, roundCooldown: Int) {
        self.intervals = intervals
            .prefix(CustomTimerLimits.intervalCount.upperBound)
            .map { interval in
                var interval = interval
                interval.duration = interval.duration.clamped(to: CustomTimerLimits.intervalDuration)
                interval.name = String(interval.name.prefix(CustomTimerLimits.nameLength))
                return interval
            }
        self.roundCount = roundCount.clamped(to: CustomTimerLimits.roundCount)
        self.startCooldown = startCooldown.clamped(to: CustomTimerLimits.cooldown)
        self.roundCooldown = roundCooldown.clamped(to: CustomTimerLimits.cooldown)
    }

    /// Exercises in one round (rests not counted).
    var exercisesPerRound: Int {
        intervals.filter { $0.kind == .work }.count
    }

    /// Exercises × rounds – the "y" in "x / y".
    var totalIntervals: Int { exercisesPerRound * roundCount }

    /// Full workout length in seconds, including rests and cooldowns.
    var totalDuration: Int {
        CustomWorkoutPlan.phases(for: self).reduce(0) { $0 + $1.duration }
    }
}

enum CustomWorkoutPlan {
    /// Builds the ordered list of phases: optional start cooldown, then the
    /// intervals of every round, with a round cooldown between rounds (not after
    /// the last). Cooldowns set to 0 are skipped, and so are rests at the very end
    /// of the last round, since nothing comes after them.
    ///
    /// Get ready and rest phases carry the name of the exercise that comes next,
    /// so the workout screen can show "Next: Burpees".
    static func phases(for settings: CustomWorkoutSettings) -> [WorkoutPhase] {
        let items = settings.intervals
        let exercises = items.filter { $0.kind == .work }
        guard let firstExercise = exercises.first,
              let lastExerciseIndex = items.lastIndex(where: { $0.kind == .work }) else {
            return []
        }

        var phases: [WorkoutPhase] = []

        if settings.startCooldown > 0 {
            phases.append(WorkoutPhase(kind: .getReady, duration: settings.startCooldown,
                                       intervalNumber: 1, round: 1, exerciseNumber: 1,
                                       title: firstExercise.displayName))
        }

        var interval = 0
        for round in 1...settings.roundCount {
            let isLastRound = round == settings.roundCount
            var exercise = 0

            for (index, item) in items.enumerated() {
                switch item.kind {
                case .work:
                    interval += 1
                    exercise += 1
                    phases.append(WorkoutPhase(kind: .work, duration: item.duration,
                                               intervalNumber: interval, round: round,
                                               exerciseNumber: exercise, title: item.displayName))
                case .rest:
                    if isLastRound && index > lastExerciseIndex { continue }

                    // The exercise after this rest: later in this round, or the
                    // first exercise of the next round.
                    if let next = items[(index + 1)...].first(where: { $0.kind == .work }) {
                        phases.append(WorkoutPhase(kind: .rest, duration: item.duration,
                                                   intervalNumber: interval + 1, round: round,
                                                   exerciseNumber: exercise + 1, title: next.displayName))
                    } else {
                        phases.append(WorkoutPhase(kind: .rest, duration: item.duration,
                                                   intervalNumber: interval + 1, round: round + 1,
                                                   exerciseNumber: 1, title: firstExercise.displayName))
                    }
                }
            }

            if !isLastRound, settings.roundCooldown > 0 {
                phases.append(WorkoutPhase(kind: .rest, duration: settings.roundCooldown,
                                           intervalNumber: interval + 1, round: round + 1,
                                           exerciseNumber: 1, title: firstExercise.displayName))
            }
        }

        return phases
    }
}
