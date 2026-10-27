import SwiftUI
import SwiftData

/// Lists all Simple timers. Tap a row to edit, tap Play to start.
struct SimpleModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TabataTimer.createdAt) private var timers: [TabataTimer]

    @State private var editorTarget: TimerEditorTarget?
    @State private var activeTimer: TabataTimer?

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
            .modifier(NavigationSubtitle(text: "Simple mode"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AppearanceButton()
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
                TimerEditorView(target: target)
            }
            .fullScreenCover(item: $activeTimer) { timer in
                WorkoutView(title: timer.name, settings: timer.settings, color: timer.workoutColor)
            }
        }
    }

    private var timerList: some View {
        List {
            ForEach(timers) { timer in
                TimerRow(timer: timer) {
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
            Label("No Timers", systemImage: "timer")
        } description: {
            Text("Create your first timer to get started.")
        } actions: {
            Button("New Timer") { editorTarget = .new }
                .buttonStyle(.borderedProminent)
        }
    }
}

/// Shows a smaller subtitle under the navigation title. Uses the native subtitle
/// on iOS 26 and later, and a matching caption under the title on earlier versions.
struct NavigationSubtitle: ViewModifier {
    let text: LocalizedStringResource

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.navigationSubtitle(text)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
        }
    }
}

/// One timer in the list, with its own Play button.
struct TimerRow: View {
    let timer: TabataTimer
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(timer.name)
                    .font(.headline)
                Text("^[\(timer.exerciseCount) exercise](inflect: true) × ^[\(timer.roundCount) round](inflect: true)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(timer.exerciseDuration) s per exercise · \(formatDuration(timer.settings.totalDuration)) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            .accessibilityLabel("Play \(timer.name)")
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: TabataTimer.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(
        TabataTimer(name: "Morning Tabata", exerciseCount: 4, roundCount: 2,
                    exerciseDuration: 20, startCooldown: 10, roundCooldown: 60)
    )
    return SimpleModeView()
        .modelContainer(container)
}
