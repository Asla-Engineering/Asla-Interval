import SwiftUI
import SwiftData

enum CustomEditorTarget: Identifiable {
    case new
    case edit(CustomTimer)
    /// A timer set up by Voice Timer, shown for review before it is saved.
    case generated(CustomTimerDraft)

    var id: AnyHashable {
        switch self {
        case .new: AnyHashable("new")
        case .edit(let timer): AnyHashable(timer.persistentModelID)
        case .generated(let draft): AnyHashable(draft.id)
        }
    }
}

/// Lists Custom timers. Build them by hand (free), or describe them with your
/// voice (Voice Timer, a one-time purchase with a 14-day free trial).
struct CustomModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomTimer.createdAt) private var timers: [CustomTimer]

    @State private var editorTarget: CustomEditorTarget?
    @State private var activeTimer: CustomTimer?
    @State private var showVoiceTimer = false
    /// A timer from Voice Timer, opened in the editor once the voice sheet has closed.
    @State private var generatedDraft: CustomTimerDraft?

    /// False on iPhones that can never run Apple Intelligence – the button is hidden there.
    private let voiceTimerOffered = VoiceFeature.isOffered

    var body: some View {
        NavigationStack {
            Group {
                if timers.isEmpty {
                    emptyState
                } else {
                    timerList
                }
            }
            .navigationTitle("Timers")
            .modifier(NavigationSubtitle(text: "Custom mode"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AppearanceButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    if voiceTimerOffered {
                        Button {
                            showVoiceTimer = true
                        } label: {
                            Label("Create with Voice", systemImage: "mic")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorTarget = .new
                    } label: {
                        Label("Add Timer", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editorTarget) { target in
                CustomTimerEditorView(target: target)
            }
            .sheet(isPresented: $showVoiceTimer, onDismiss: openGeneratedDraft) {
                VoiceTimerSheet { draft in
                    generatedDraft = draft
                    showVoiceTimer = false
                }
            }
            .fullScreenCover(item: $activeTimer) { timer in
                WorkoutView(title: timer.name, custom: timer.settings)
            }
        }
    }

    private var timerList: some View {
        List {
            ForEach(timers) { timer in
                CustomTimerRow(timer: timer) {
                    activeTimer = timer
                }
                .contentShape(Rectangle())
                .onTapGesture { editorTarget = .edit(timer) }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        modelContext.delete(timer)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editorTarget = .edit(timer)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.gray)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Custom Timers", systemImage: "slider.horizontal.3")
        } description: {
            if voiceTimerOffered {
                Text("Build a timer with your own exercises and rests, or simply describe it with your voice.")
            } else {
                Text("Build a timer with your own exercises and rests.")
            }
        } actions: {
            Button("New Timer") { editorTarget = .new }
                .buttonStyle(.borderedProminent)
            if voiceTimerOffered {
                Button {
                    showVoiceTimer = true
                } label: {
                    Label("Create with Voice", systemImage: "mic")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func openGeneratedDraft() {
        guard let draft = generatedDraft else { return }
        generatedDraft = nil
        editorTarget = .generated(draft)
    }
}

/// One Custom timer in the list, with its own Play button.
struct CustomTimerRow: View {
    let timer: CustomTimer
    let onPlay: () -> Void

    var body: some View {
        let settings = timer.settings
        let exerciseNames = settings.intervals
            .filter { $0.kind == .work }
            .map(\.displayName)
            .joined(separator: ", ")

        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(timer.name)
                    .font(.headline)
                Text("^[\(settings.exercisesPerRound) exercise](inflect: true) × ^[\(settings.roundCount) round](inflect: true)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(exerciseNames) · \(formatDuration(settings.totalDuration)) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.accentColor))
            }
            .buttonStyle(.borderless)
            .disabled(settings.totalIntervals == 0)
            .accessibilityLabel("Play \(timer.name)")
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: CustomTimer.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(
        CustomTimer(
            name: "Leg Day",
            intervals: [
                CustomInterval(name: "Squats", kind: .work, duration: 45),
                CustomInterval(name: "Rest", kind: .rest, duration: 15),
                CustomInterval(name: "Lunges", kind: .work, duration: 45),
                CustomInterval(name: "Rest", kind: .rest, duration: 15),
            ],
            roundCount: 3, startCooldown: 10, roundCooldown: 60
        )
    )
    return CustomModeView()
        .modelContainer(container)
        .environment(StoreManager())
}
