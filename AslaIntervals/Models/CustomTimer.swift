import Foundation
import SwiftData

/// One step in a Custom timer: an exercise or a rest.
struct CustomInterval: Codable, Hashable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case work
        case rest
    }

    var id = UUID()
    var name: String
    var kind: Kind
    /// Seconds.
    var duration: Int

    /// The name to show, with a sensible fallback when it is left empty.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return kind == .work ? "Exercise" : "Rest"
    }
}

/// A saved Custom-mode timer: a list of exercises and rests that is repeated
/// for a number of rounds. Made by hand or with Voice Timer.
@Model
final class CustomTimer {
    var name: String
    var roundCount: Int
    /// Seconds of "get ready" before the first interval.
    var startCooldown: Int
    /// Seconds of rest between rounds.
    var roundCooldown: Int
    /// Free-text notes, sanitized by `NotesSanitizer`.
    var notes: String = ""
    var createdAt: Date
    /// The intervals of one round, stored as JSON so their order is always kept
    /// (SwiftData does not keep the order of to-many relationships).
    var intervalsData: Data = Data()

    init(
        name: String,
        intervals: [CustomInterval],
        roundCount: Int,
        startCooldown: Int,
        roundCooldown: Int,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.name = name
        self.roundCount = roundCount
        self.startCooldown = startCooldown
        self.roundCooldown = roundCooldown
        self.notes = NotesSanitizer.sanitize(notes)
        self.createdAt = createdAt
        self.intervals = intervals
    }

    var intervals: [CustomInterval] {
        get { (try? JSONDecoder().decode([CustomInterval].self, from: intervalsData)) ?? [] }
        set { intervalsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var settings: CustomWorkoutSettings {
        CustomWorkoutSettings(
            intervals: intervals,
            roundCount: roundCount,
            startCooldown: startCooldown,
            roundCooldown: roundCooldown
        )
    }
}
