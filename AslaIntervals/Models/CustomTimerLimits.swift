import Foundation

/// Allowed ranges for every configurable value of a Custom timer.
enum CustomTimerLimits {
    /// Exercises and rests in one round.
    static let intervalCount: ClosedRange<Int> = 1...30
    /// Number of rounds.
    static let roundCount: ClosedRange<Int> = 1...20
    /// Length of one exercise or rest, in seconds.
    static let intervalDuration: ClosedRange<Int> = 5...600
    /// Length of the start and round cooldowns, in seconds. 0 means "skip".
    static let cooldown: ClosedRange<Int> = 0...300
    /// Step used by the duration steppers, in seconds.
    static let durationStep = 5
    /// Maximum length of a timer or interval name.
    static let nameLength = 40
}

/// Formats seconds as "45 s" under a minute and as `m:ss` from a minute up.
func formatSeconds(_ seconds: Int) -> String {
    seconds < 60 ? "\(seconds) s" : formatDuration(seconds)
}
