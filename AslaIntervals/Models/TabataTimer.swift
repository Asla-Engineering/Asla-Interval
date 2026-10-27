import Foundation
import SwiftData

/// A saved Simple-mode timer.
@Model
final class TabataTimer {
    var name: String
    var exerciseCount: Int
    var roundCount: Int
    /// Seconds per exercise interval.
    var exerciseDuration: Int
    /// Seconds of "get ready" before the first exercise.
    var startCooldown: Int
    /// Seconds of rest between rounds.
    var roundCooldown: Int
    /// Free-text notes, sanitized by `NotesSanitizer`. The default value lets
    /// SwiftData add this field to timers saved before notes existed.
    var notes: String = ""
    /// Raw value of `WorkoutColor`. Stored as a string with a default, so timers
    /// saved before colors existed open in the default color.
    var workoutColorRaw: String = WorkoutColor.default.rawValue
    var createdAt: Date

    init(
        name: String,
        exerciseCount: Int,
        roundCount: Int,
        exerciseDuration: Int,
        startCooldown: Int,
        roundCooldown: Int,
        notes: String = "",
        workoutColor: WorkoutColor = .default,
        createdAt: Date = .now
    ) {
        self.name = name
        self.exerciseCount = exerciseCount
        self.roundCount = roundCount
        self.exerciseDuration = exerciseDuration
        self.startCooldown = startCooldown
        self.roundCooldown = roundCooldown
        self.notes = NotesSanitizer.sanitize(notes)
        self.workoutColorRaw = workoutColor.rawValue
        self.createdAt = createdAt
    }

    /// Background color for the workout screen. Unknown stored values fall back to the default.
    var workoutColor: WorkoutColor {
        get { WorkoutColor(rawValue: workoutColorRaw) ?? .default }
        set { workoutColorRaw = newValue.rawValue }
    }

    var settings: WorkoutSettings {
        WorkoutSettings(
            exerciseCount: exerciseCount,
            roundCount: roundCount,
            exerciseDuration: exerciseDuration,
            startCooldown: startCooldown,
            roundCooldown: roundCooldown
        )
    }
}
