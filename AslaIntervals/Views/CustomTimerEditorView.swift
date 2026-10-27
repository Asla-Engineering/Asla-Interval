import SwiftUI
import SwiftData

/// Create, edit or review a Custom timer.
struct CustomTimerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let target: CustomEditorTarget
    @State private var draft: CustomTimerDraft
    @State private var confirmDelete = false

    init(target: CustomEditorTarget) {
        self.target = target
        switch target {
        case .new:
            _draft = State(initialValue: CustomTimerDraft())
        case .edit(let timer):
            _draft = State(initialValue: CustomTimerDraft(timer))
        case .generated(let draft):
            _draft = State(initialValue: draft)
        }
    }

    private var title: LocalizedStringKey {
        switch target {
        case .new: "New Timer"
        case .edit: "Edit Timer"
        case .generated: "Review Timer"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if case .generated = target {
                    Section {
                        Label("Set up from your description. Check it and make any changes before you save.",
                              systemImage: "sparkles")
                            .font(.subheadline)
                    }
                }

                Section("Name") {
                    TextField("Timer name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .onChange(of: draft.name) { _, newValue in
                            if newValue.count > CustomTimerLimits.nameLength {
                                draft.name = String(newValue.prefix(CustomTimerLimits.nameLength))
                            }
                        }
                }

                intervalsSection

                Section {
                    DraftCountStepper(title: "Number of rounds",
                                      value: $draft.roundCount,
                                      range: CustomTimerLimits.roundCount)
                    DraftSecondsStepper(title: "Start cooldown",
                                        value: $draft.startCooldown,
                                        range: CustomTimerLimits.cooldown)
                    DraftSecondsStepper(title: "Round cooldown",
                                        value: $draft.roundCooldown,
                                        range: CustomTimerLimits.cooldown)
                        .disabled(draft.roundCount == 1)
                } header: {
                    Text("Rounds")
                } footer: {
                    Text("A cooldown of 0 is skipped. The round cooldown is never used after the last round.")
                }

                Section("Summary") {
                    LabeledContent("Exercises per round", value: "\(draft.settings.exercisesPerRound)")
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
            .navigationTitle(title)
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

    private var intervalsSection: some View {
        Section {
            ForEach($draft.intervals) { $interval in
                NavigationLink {
                    IntervalEditorView(interval: $interval)
                } label: {
                    IntervalRow(interval: interval)
                }
            }
            .onDelete { draft.intervals.remove(atOffsets: $0) }
            .onMove { draft.intervals.move(fromOffsets: $0, toOffset: $1) }

            if draft.intervals.count < CustomTimerLimits.intervalCount.upperBound {
                Button {
                    addInterval(.work)
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                }
                Button {
                    addInterval(.rest)
                } label: {
                    Label("Add Rest", systemImage: "pause.circle")
                }
            }
        } header: {
            HStack {
                Text("Each Round")
                Spacer()
                EditButton()
                    .font(.subheadline)
                    .textCase(nil)
            }
        } footer: {
            if draft.hasWorkInterval {
                Text("Tap an interval to change it. Use Edit to reorder. Up to \(CustomTimerLimits.intervalCount.upperBound) per round.")
            } else {
                Text("Add at least one exercise.")
                    .foregroundStyle(.red)
            }
        }
    }

    private func addInterval(_ kind: CustomInterval.Kind) {
        let exerciseCount = draft.intervals.filter { $0.kind == .work }.count
        let interval = kind == .work
            ? CustomInterval(name: "Exercise \(exerciseCount + 1)", kind: .work, duration: 40)
            : CustomInterval(name: "Rest", kind: .rest, duration: 20)
        draft.intervals.append(interval)
    }

    private func save() {
        switch target {
        case .new, .generated:
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

/// One exercise or rest in the editor list. Colors match the workout screen.
private struct IntervalRow: View {
    let interval: CustomInterval

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: interval.kind == .work ? "figure.run" : "pause.circle.fill")
                .foregroundStyle(interval.kind == .work ? Color.green : Color.cyan)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(interval.displayName)
                .lineLimit(1)
            Spacer()
            Text(formatSeconds(interval.duration))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(interval.kind == .work ? "Exercise" : "Rest")
    }
}

/// Edit one interval: type, name and length.
private struct IntervalEditorView: View {
    @Binding var interval: CustomInterval

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $interval.kind) {
                    Text("Exercise").tag(CustomInterval.Kind.work)
                    Text("Rest").tag(CustomInterval.Kind.rest)
                }
                .pickerStyle(.segmented)
            }

            Section("Name") {
                TextField(interval.kind == .work ? "Exercise name" : "Rest", text: $interval.name)
                    .textInputAutocapitalization(.words)
                    .onChange(of: interval.name) { _, newValue in
                        if newValue.count > CustomTimerLimits.nameLength {
                            interval.name = String(newValue.prefix(CustomTimerLimits.nameLength))
                        }
                    }
            }

            Section {
                DraftSecondsStepper(title: "Duration",
                                    value: $interval.duration,
                                    range: CustomTimerLimits.intervalDuration)
            } footer: {
                Text("From \(CustomTimerLimits.intervalDuration.lowerBound) seconds to \(CustomTimerLimits.intervalDuration.upperBound / 60) minutes.")
            }
        }
        .navigationTitle(interval.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DraftCountStepper: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            LabeledContent(title, value: "\(value)")
        }
    }
}

private struct DraftSecondsStepper: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range, step: CustomTimerLimits.durationStep) {
            LabeledContent(title, value: formatSeconds(value))
        }
    }
}

#Preview {
    CustomTimerEditorView(target: .new)
        .modelContainer(for: CustomTimer.self, inMemory: true)
}
