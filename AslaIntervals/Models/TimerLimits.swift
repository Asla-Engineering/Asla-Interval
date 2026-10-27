import Foundation

/// Allowed ranges for every configurable value of a Simple timer.
enum TimerLimits {
    /// Number of exercises per round.
    static let exerciseCount: ClosedRange<Int> = 1...20
    /// Number of rounds.
    static let roundCount: ClosedRange<Int> = 1...20
    /// Length of one exercise interval, in seconds.
    static let exerciseDuration: ClosedRange<Int> = 5...90
    /// Length of the start and round cooldowns, in seconds. 0 means "skip".
    static let cooldown: ClosedRange<Int> = 0...90
    /// Step used by the duration steppers, in seconds.
    static let durationStep = 5
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Formats a number of seconds as `m:ss`.
func formatDuration(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}
