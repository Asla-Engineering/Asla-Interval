#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// The structure Apple Intelligence fills in from the person's description
/// (guided generation), so there is no free text to parse.
@available(iOS 26.0, *)
@Generable(description: "An interval workout timer")
struct GeneratedWorkout {
    @Guide(description: "A short name for the workout, at most 30 characters, in the same language as the description")
    var name: String

    @Guide(description: "The intervals of one round, in the order they are done. Every exercise and every rest is its own interval.")
    var intervals: [GeneratedInterval]

    @Guide(description: "How many times the intervals are repeated. 1 if the description doesn't say.")
    var rounds: Int

    @Guide(description: "Seconds of get-ready countdown before the first interval. 10 if the description doesn't say.")
    var getReadySeconds: Int

    @Guide(description: "Seconds of rest between rounds. 0 if the description doesn't say.")
    var restBetweenRoundsSeconds: Int
}

@available(iOS 26.0, *)
@Generable(description: "One exercise or one rest")
struct GeneratedInterval {
    @Guide(description: "The exercise name, like Burpees or Plank, in the same language as the description. For a rest, the word for rest in that language.")
    var name: String

    @Guide(description: "True for a rest or break, false for an exercise")
    var isRest: Bool

    @Guide(description: "Length in seconds")
    var seconds: Int
}

/// Turns a spoken or typed workout description into a Custom timer draft, using
/// the on-device Apple Intelligence model. Nothing leaves the iPhone.
@available(iOS 26.0, *)
enum WorkoutGenerator {
    enum Failure: LocalizedError {
        case couldNotUnderstand
        case noExercises

        var errorDescription: String? {
            switch self {
            case .couldNotUnderstand:
                "That couldn't be turned into a timer. Try saying how many rounds, which exercises and how long each one lasts."
            case .noExercises:
                "No exercises were found in that description. Name at least one exercise and how long it lasts."
            }
        }
    }

    static func makeDraft(from description: String) async throws -> CustomTimerDraft {
        let text = String(description.trimmingCharacters(in: .whitespacesAndNewlines).prefix(NotesSanitizer.maxLength))

        // A new session per request: each description stands on its own.
        let session = LanguageModelSession(instructions: """
            You turn a description of a workout into an interval timer.
            The description comes from speech recognition, so it may contain small mistakes. \
            It is usually in Norwegian or English.

            Rules:
            - Every exercise and every rest is its own interval, listed in the order they are done in one round.
            - Always give lengths in seconds. Convert minutes: one minute is 60 seconds, half a minute \
            ("et halvt minutt") is 30 seconds.
            - "Rounds", "sets", "times", "runder", "sett" and "ganger" give the number of rounds.
            - "Rest", "break", "pause" and "hvile" mean a rest interval.
            - If a rest comes after each exercise, add it after every exercise.
            - If only a number of exercises is given without names, call them "Exercise 1", "Exercise 2" \
            and so on, or "Øvelse 1", "Øvelse 2" in Norwegian.
            - Tabata means 8 rounds of 20 seconds of exercise and 10 seconds of rest.
            - Write names in the same language as the description. Never add exercises that were not mentioned.
            - When something is not mentioned, use 1 round, 10 seconds to get ready and 0 seconds between rounds.

            Example: "Four rounds of 40 seconds burpees and 20 seconds rest, one minute break between rounds" \
            gives the intervals Burpees (exercise, 40 seconds) and Rest (rest, 20 seconds), \
            4 rounds and 60 seconds of rest between rounds.
            """)

        let workout: GeneratedWorkout
        do {
            workout = try await session.respond(
                to: "Workout description:\n\(text)",
                generating: GeneratedWorkout.self
            ).content
        } catch {
            throw Failure.couldNotUnderstand
        }

        var draft = CustomTimerDraft(generated: workout)
        guard draft.hasWorkInterval else { throw Failure.noExercises }
        draft.notes = NotesSanitizer.sanitize(text)
        return draft
    }
}

@available(iOS 26.0, *)
extension CustomTimerDraft {
    /// Maps the model's answer onto the app's limits, so a draft is always valid
    /// to edit even if the model returns odd numbers.
    init(generated workout: GeneratedWorkout) {
        self.init()

        let name = workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = name.isEmpty ? "Voice Timer" : String(name.prefix(CustomTimerLimits.nameLength))

        intervals = workout.intervals
            .prefix(CustomTimerLimits.intervalCount.upperBound)
            .map { item in
                CustomInterval(
                    name: String(item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        .prefix(CustomTimerLimits.nameLength)),
                    kind: item.isRest ? .rest : .work,
                    duration: item.seconds.clamped(to: CustomTimerLimits.intervalDuration)
                )
            }

        roundCount = workout.rounds.clamped(to: CustomTimerLimits.roundCount)
        startCooldown = workout.getReadySeconds.clamped(to: CustomTimerLimits.cooldown)
        roundCooldown = roundCount > 1
            ? workout.restBetweenRoundsSeconds.clamped(to: CustomTimerLimits.cooldown)
            : 0
    }
}
#endif
