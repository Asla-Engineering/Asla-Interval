#if canImport(FoundationModels)
import SwiftUI

/// Speak (or type) a workout, and Apple Intelligence sets up the timer.
/// The result opens in the editor for review before anything is saved.
@available(iOS 26.0, *)
struct VoiceCreatorView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.openURL) private var openURL

    let onCreated: (CustomTimerDraft) -> Void

    @State private var listener = SpeechListener()
    @State private var text = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var needsPermission = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                if case .trial(let endsAt) = store.access {
                    TrialBanner(endsAt: endsAt)
                }

                VStack(spacing: 8) {
                    Text("Describe Your Workout")
                        .font(.title2.bold())
                    Text(example)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    microphoneButton
                    Text(listener.isListening ? "Listening… Tap to stop." : "Tap the microphone and start talking.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                TextField("Or type it here", text: $text, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($isTextFieldFocused)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    .disabled(listener.isListening || isGenerating)
                    .onChange(of: text) { _, newValue in
                        if newValue.count > NotesSanitizer.maxLength {
                            text = String(newValue.prefix(NotesSanitizer.maxLength))
                        }
                    }

                if let errorMessage {
                    VStack(spacing: 8) {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        if needsPermission, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            Button("Open Settings") { openURL(settingsURL) }
                        }
                    }
                }
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            createButton
        }
        .onChange(of: listener.transcript) { _, newValue in
            text = newValue
        }
        .onDisappear {
            listener.cancel()
        }
    }

    // MARK: Pieces

    private var example: String {
        VoiceFeature.speaksNorwegian
            ? "For eksempel: «4 runder med 40 sekunder burpees og 20 sekunder pause, og ett minutt hvile mellom rundene.»"
            : "For example: “4 rounds of 40 seconds burpees and 20 seconds rest, with one minute of rest between rounds.”"
    }

    private var microphoneButton: some View {
        Button(action: toggleListening) {
            Image(systemName: listener.isListening ? "stop.fill" : "mic.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, isActive: listener.isListening)
                .frame(width: 96, height: 96)
                .background(Circle().fill(listener.isListening ? Color.red : Color.accentColor))
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
        .accessibilityLabel(listener.isListening ? "Stop Listening" : "Start Listening")
    }

    private var createButton: some View {
        Button(action: create) {
            Group {
                if isGenerating {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Setting Up Your Timer…")
                    }
                } else {
                    Label("Create Timer", systemImage: "sparkles")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isGenerating || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: Actions

    private func toggleListening() {
        errorMessage = nil
        needsPermission = false

        if listener.isListening {
            listener.stop()
            return
        }

        isTextFieldFocused = false
        Task {
            guard await SpeechListener.requestPermissions() else {
                needsPermission = true
                errorMessage = SpeechListener.Failure.notAuthorized.errorDescription
                return
            }
            do {
                try listener.start(locale: VoiceFeature.speechLocale)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func create() {
        let description = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty, store.access.canUseVoiceTimer else { return }

        listener.stop()
        isTextFieldFocused = false
        errorMessage = nil
        isGenerating = true

        Task {
            defer { isGenerating = false }
            do {
                let draft = try await WorkoutGenerator.makeDraft(from: description)
                onCreated(draft)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Shows how long the free trial lasts, with a shortcut to buy.
@available(iOS 26.0, *)
private struct TrialBanner: View {
    @Environment(StoreManager.self) private var store
    let endsAt: Date

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text("Free trial ends \(endsAt, format: .relative(presentation: .named))")
            } icon: {
                Image(systemName: "gift")
            }
            .font(.subheadline)

            Spacer(minLength: 8)

            if let unlock = store.unlockProduct {
                Button("Buy \(unlock.displayPrice)") {
                    Task { await store.purchase(unlock) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.isPurchasing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.12)))
    }
}
#endif
