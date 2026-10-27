import SwiftUI
import SwiftData

enum TimerEditorTarget: Identifiable {
    case new
    case edit(TabataTimer)

    var id: AnyHashable {
        switch self {
        case .new: AnyHashable("new")
        case .edit(let timer): AnyHashable(timer.persistentModelID)
        }
    }
}

/// Create or edit a Simple timer.
struct TimerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let target: TimerEditorTarget
    @State private var draft: TimerDraft
    @State private var confirmDelete = false

    init(target: TimerEditorTarget) {
        self.target = target
        switch target {
        case .new:
            _draft = State(initialValue: TimerDraft())
        case .edit(let timer):
            _draft = State(initialValue: TimerDraft(timer))
        }
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Timer name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                    WorkoutColorPicker(selection: $draft.workoutColor)
                } header: {
                    Text("Name")
                } footer: {
                    Text("The color is the background of the workout screen.")
                }

                Section {
                    CountStepper(title: "Number of exercises",
                                 value: $draft.exerciseCount,
                                 range: TimerLimits.exerciseCount)
                    CountStepper(title: "Number of rounds",
                                 value: $draft.roundCount,
                                 range: TimerLimits.roundCount)
                } header: {
                    Text("Structure")
                } footer: {
                    Text("Max \(TimerLimits.exerciseCount.upperBound) exercises and \(TimerLimits.roundCount.upperBound) rounds.")
                }

                Section {
                    SecondsStepper(title: "Time per exercise",
                                   value: $draft.exerciseDuration,
                                   range: TimerLimits.exerciseDuration)
                    SecondsStepper(title: "Start cooldown",
                                   value: $draft.startCooldown,
                                   range: TimerLimits.cooldown)
                    SecondsStepper(title: "Round cooldown",
                                   value: $draft.roundCooldown,
                                   range: TimerLimits.cooldown)
                } header: {
                    Text("Timing")
                } footer: {
                    Text("Max \(TimerLimits.cooldown.upperBound) seconds. A cooldown of 0 is skipped.")
                }

                Section("Summary") {
                    LabeledContent("Intervals", value: "\(draft.settings.totalIntervals)")
                    LabeledContent("Total time", value: formatDuration(draft.settings.totalDuration))
                }

                NotesSection(notes: $draft.notes)

                if case .edit = target {
                    Section {
                        Button("Delete Timer", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Timer" : "Edit Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .confirmationDialog("Delete this timer?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: delete)
            }
        }
    }

    private func save() {
        switch target {
        case .new:
            modelContext.insert(draft.makeTimer())
        case .edit(let timer):
            draft.apply(to: timer)
        }
        dismiss()
    }

    private func delete() {
        if case .edit(let timer) = target {
            modelContext.delete(timer)
        }
        dismiss()
    }
}

/// One row of color swatches; a single tap picks the workout background color.
private struct WorkoutColorPicker: View {
    @Binding var selection: WorkoutColor

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WorkoutColor.allCases) { color in
                swatch(for: color)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workout color")
    }

    private func swatch(for color: WorkoutColor) -> some View {
        let isSelected = color == selection
        let style = color.active

        return Button {
            selection = color
        } label: {
            Circle()
                .fill(style.background)
                .frame(width: 34, height: 34)
                // Hairline so White and Black stay visible in both Light and Dark mode.
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(style.foreground)
                    }
                }
                .padding(4)
                .overlay {
                    Circle()
                        .strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .animation(.snappy(duration: 0.2), value: isSelected)
        }
        // Borderless, so each swatch gets its own tap instead of the whole row.
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(color.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Multi-line free text. Unsafe characters and the length limit are enforced as
/// the user types; full sanitizing happens on save (see `TimerDraft`).
struct NotesSection: View {
    @Binding var notes: String

    /// The counter appears once the note gets close to the limit.
    private let counterThreshold = NotesSanitizer.maxLength - 200

    var body: some View {
        Section {
            TextField("Notes", text: $notes,
                      prompt: Text("Add notes, like a list of your exercises"),
                      axis: .vertical)
                .lineLimit(3...10)
                .textInputAutocapitalization(.sentences)
                .onChange(of: notes) { _, newValue in
                    let limited = NotesSanitizer.limitWhileTyping(newValue)
                    if limited != newValue { notes = limited }
                }
        } header: {
            Text("Notes")
        } footer: {
            if notes.count >= counterThreshold {
                Text("\(notes.count) / \(NotesSanitizer.maxLength)")
                    .monospacedDigit()
                    .foregroundStyle(notes.count >= NotesSanitizer.maxLength ? Color.red : Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("\(notes.count) of \(NotesSanitizer.maxLength) characters used")
            }
        }
    }
}

private struct CountStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            LabeledContent(title, value: "\(value)")
        }
    }
}

private struct SecondsStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range, step: TimerLimits.durationStep) {
            LabeledContent(title, value: "\(value) s")
        }
    }
}

#Preview {
    TimerEditorView(target: .new)
        .modelContainer(for: TabataTimer.self, inMemory: true)
}
