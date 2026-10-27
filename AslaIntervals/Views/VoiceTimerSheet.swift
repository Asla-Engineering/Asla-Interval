import SwiftUI

/// Voice Timer. Shows the paywall, the trial or the voice creator, depending on
/// what this iPhone supports and what the person has bought.
struct VoiceTimerSheet: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Called with the timer Apple Intelligence set up, for the person to review.
    let onCreated: (CustomTimerDraft) -> Void

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Voice Timer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        .task { await store.updateEntitlements() }
        .alert("Voice Timer", isPresented: messageIsShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.message ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch VoiceFeature.status {
        case .available:
            switch store.access {
            case .loading:
                ProgressView()
            case .notStarted, .trialEnded:
                VoicePaywallView()
            case .trial, .purchased:
                creator
            }
        case .appleIntelligenceOff:
            ContentUnavailableView {
                Label("Turn On Apple Intelligence", systemImage: "sparkles")
            } description: {
                Text("Voice Timer uses Apple Intelligence on your iPhone. Turn it on in Settings › Apple Intelligence & Siri, then come back here.")
            }
        case .modelNotReady:
            ContentUnavailableView {
                Label("Almost Ready", systemImage: "arrow.down.circle")
            } description: {
                Text("Apple Intelligence is still getting ready on your iPhone. Try again in a little while.")
            }
        case .unsupported:
            ContentUnavailableView {
                Label("Not Available", systemImage: "mic.slash")
            } description: {
                Text("Voice Timer needs an iPhone with Apple Intelligence.")
            }
        }
    }

    @ViewBuilder
    private var creator: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            VoiceCreatorView(onCreated: onCreated)
        }
        #endif
    }

    private var messageIsShown: Binding<Bool> {
        Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )
    }
}
