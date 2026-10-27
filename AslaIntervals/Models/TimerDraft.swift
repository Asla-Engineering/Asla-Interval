import Foundation

/// Editable copy of a timer, so the editor can be cancelled without side effects.
struct TimerDraft: Equatable {
    var name = "New Timer"
    var exerciseCount = 4
    var roundCount = 2
    var exerciseDuration = 20
    var startCooldown = 10
    var roundCooldown = 60
    var notes = ""
    var workoutColor: WorkoutColor = .default

    init() {}

    init(_ timer: TabataTimer) {
        name = timer.name
        exerciseCount = timer.exerciseCount
        roundCount = timer.roundCount
        exerciseDuration = timer.exerciseDuration
        startCooldown = timer.startCooldown
        roundCooldown = timer.roundCooldown
        notes = NotesSanitizer.sanitize(timer.notes)
        workoutColor = timer.workoutColor
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool { !trimmedName.isEmpty }

    var settings: WorkoutSettings {
        WorkoutSettings(
            exerciseCount: exerciseCount,
            roundCount: roundCount,
            exerciseDuration: exerciseDuration,
            startCooldown: startCooldown,
            roundCooldown: roundCooldown
        )
    }

    func makeTimer() -> TabataTimer {
        let s = settings
        return TabataTimer(
            name: trimmedName,
            exerciseCount: s.exerciseCount,
            roundCount: s.roundCount,
            exerciseDuration: s.exerciseDuration,
            startCooldown: s.startCooldown,
            roundCooldown: s.roundCooldown,
            notes: NotesSanitizer.sanitize(notes),
            workoutColor: workoutColor
        )
    }

    func apply(to timer: TabataTimer) {
        let s = settings
        timer.name = trimmedName
        timer.exerciseCount = s.exerciseCount
        timer.roundCount = s.roundCount
        timer.exerciseDuration = s.exerciseDuration
        timer.startCooldown = s.startCooldown
        timer.roundCooldown = s.roundCooldown
        timer.notes = NotesSanitizer.sanitize(notes)
        timer.workoutColor = workoutColor
    }
}
