import Foundation

/// Editable copy of a Custom timer, so the editor can be cancelled without side
/// effects. Voice Timer also produces one of these for the person to review.
struct CustomTimerDraft: Equatable, Identifiable {
    let id = UUID()
    var name = "New Timer"
    var intervals: [CustomInterval] = [
        CustomInterval(name: "Exercise 1", kind: .work, duration: 40),
        CustomInterval(name: "Rest", kind: .rest, duration: 20),
    ]
    var roundCount = 3
    var startCooldown = 10
    var roundCooldown = 60
    var notes = ""

    init() {}

    init(_ timer: CustomTimer) {
        name = timer.name
        intervals = timer.intervals
        roundCount = timer.roundCount
        startCooldown = timer.startCooldown
        roundCooldown = timer.roundCooldown
        notes = NotesSanitizer.sanitize(timer.notes)
    }

    var trimmedName: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(CustomTimerLimits.nameLength))
    }

    var hasWorkInterval: Bool {
        intervals.contains { $0.kind == .work }
    }

    var isValid: Bool { !trimmedName.isEmpty && hasWorkInterval }

    var settings: CustomWorkoutSettings {
        CustomWorkoutSettings(
            intervals: intervals,
            roundCount: roundCount,
            startCooldown: startCooldown,
            roundCooldown: roundCooldown
        )
    }

    func makeTimer() -> CustomTimer {
        let s = settings
        return CustomTimer(
            name: trimmedName,
            intervals: s.intervals,
            roundCount: s.roundCount,
            startCooldown: s.startCooldown,
            roundCooldown: s.roundCooldown,
            notes: NotesSanitizer.sanitize(notes)
        )
    }

    func apply(to timer: CustomTimer) {
        let s = settings
        timer.name = trimmedName
        timer.intervals = s.intervals
        timer.roundCount = s.roundCount
        timer.startCooldown = s.startCooldown
        timer.roundCooldown = s.roundCooldown
        timer.notes = NotesSanitizer.sanitize(notes)
    }
}
