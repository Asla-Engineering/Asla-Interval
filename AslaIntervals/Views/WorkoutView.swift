import SwiftUI

/// Full-screen countdown shown while a timer is running.
struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var engine: WorkoutEngine
    let title: String
    let color: WorkoutColor

    init(title: String, settings: WorkoutSettings, color: WorkoutColor = .default) {
        self.title = title
        self.color = color
        _engine = State(initialValue: WorkoutEngine(settings: settings))
    }

    init(title: String, custom: CustomWorkoutSettings, color: WorkoutColor = .default) {
        self.title = title
        self.color = color
        _engine = State(initialValue: WorkoutEngine(custom: custom))
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 24) {
                topBar

                Spacer(minLength: 0)

                Text(phaseLabel)
                    .font(.title2.weight(.heavy))
                    .tracking(4)

                countdown

                VStack(spacing: 6) {
                    Text("\(engine.currentInterval) / \(engine.totalIntervals)")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .accessibilityLabel("Interval \(engine.currentInterval) of \(engine.totalIntervals)")
                    if let phase = engine.currentPhase, engine.state != .finished {
                        Text("Round \(phase.round) of \(engine.roundCount)")
                            .font(.subheadline)
                            .foregroundStyle(style.secondary)
                    }
                }

                Spacer(minLength: 0)

                controls
            }
            .padding(24)
            .foregroundStyle(style.foreground)
        }
        // System controls and the home indicator follow the background's lightness.
        .environment(\.colorScheme, style.colorScheme)
        .statusBarHidden()
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            engine.start()
        }
        .onDisappear {
            engine.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(style.track))
            }
            .accessibilityLabel("Close")

            Spacer()

            Text(title)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var countdown: some View {
        ZStack {
            Circle()
                .stroke(style.track, lineWidth: 14)
            // The gap opens at 12 o'clock and sweeps clockwise as time runs out.
            Circle()
                .trim(from: engine.phaseProgress, to: 1)
                .stroke(style.foreground, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if engine.state == .finished {
                Image(systemName: "checkmark")
                    .font(.system(size: 110, weight: .bold))
            } else {
                VStack(spacing: 0) {
                    Text("\(engine.secondsRemaining)")
                        .font(.system(size: 150, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: engine.secondsRemaining)
                        .accessibilityLabel("\(engine.secondsRemaining) seconds")

                    if let exerciseLabel {
                        Text(exerciseLabel)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(style.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .contentTransition(.opacity)
                            .animation(.easeInOut, value: exerciseLabel)
                    }
                }
                .padding(40)
            }
        }
        .frame(maxWidth: 320, maxHeight: 320)
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private var controls: some View {
        if engine.state == .finished {
            HStack(spacing: 16) {
                Button {
                    engine.start()
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    dismiss()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(style.background)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            .tint(style.foreground)
        } else {
            Button {
                engine.togglePause()
            } label: {
                Image(systemName: engine.state == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(style.background)
                    .frame(width: 88, height: 88)
                    .background(Circle().fill(style.foreground))
            }
            .accessibilityLabel(engine.state == .paused ? "Resume" : "Pause")
        }
    }

    /// "Exercise 2" while working, "Next: Exercise 1" during get ready and rest.
    /// The number starts over at 1 in every round. Custom timers show the
    /// exercise name instead, like "Burpees" and "Next: Plank".
    private var exerciseLabel: String? {
        guard engine.state != .finished, let phase = engine.currentPhase else { return nil }
        let exercise = phase.title ?? "Exercise \(phase.exerciseNumber)"
        switch phase.kind {
        case .work: return exercise
        case .getReady, .rest: return "Next: \(exercise)"
        }
    }

    // MARK: Styling

    private var phaseLabel: String {
        if engine.state == .finished { return "DONE" }
        if engine.state == .paused { return "PAUSED" }
        switch engine.currentPhase?.kind {
        case .getReady: return "GET READY"
        case .work: return "WORK"
        case .rest: return "REST"
        case nil: return ""
        }
    }

    /// Full color while working and when finished; the dimmed variant during
    /// get ready and rest, so the phase is visible from across the room.
    private var style: WorkoutStyle {
        if engine.state == .finished { return color.active }
        switch engine.currentPhase?.kind {
        case .work, nil: return color.active
        case .getReady, .rest: return color.dimmed
        }
    }

    private var background: some View {
        style.background
            .animation(.easeInOut(duration: 0.4), value: style)
    }
}

#Preview {
    WorkoutView(
        title: "Morning Tabata",
        settings: WorkoutSettings(exerciseCount: 3, roundCount: 2, exerciseDuration: 20,
                                  startCooldown: 5, roundCooldown: 30),
        color: .pink
    )
}
