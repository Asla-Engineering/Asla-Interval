import SwiftUI
import StoreKit

/// Explains Voice Timer and offers the free trial and the one-time purchase.
///
/// Follows App Review Guideline 3.1.1: the trial length and what happens when it
/// ends are stated before it starts, prices come from the App Store, and
/// Restore Purchases is always visible.
struct VoicePaywallView: View {
    @Environment(StoreManager.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Create Timers with Your Voice")
                        .font(.title2.bold())
                    Text("Describe your workout, and Apple Intelligence sets up the timer for you.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 18) {
                    FeatureRow(systemImage: "quote.bubble", title: "Just say it", text: example)
                    FeatureRow(systemImage: "globe",
                               title: "Norwegian or English",
                               text: "Speak in your iPhone's language. Other languages use English.")
                    FeatureRow(systemImage: "slider.horizontal.3",
                               title: "You stay in control",
                               text: "Check and adjust the timer before you save it.")
                    FeatureRow(systemImage: "lock.shield",
                               title: "Private",
                               text: "Apple Intelligence sets up the timer on your iPhone.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if store.access == .trialEnded {
                    Text("Your free trial has ended. Unlock Voice Timer to keep using it. Timers you've already made are yours to keep.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            purchaseButtons
        }
    }

    private var example: String {
        "“4 rounds of 40 seconds burpees and 20 seconds rest.”"
    }

    @ViewBuilder
    private var purchaseButtons: some View {
        VStack(spacing: 12) {
            if store.products.isEmpty {
                if store.productsFailedToLoad {
                    Text("Couldn't connect to the App Store.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Try Again") {
                        Task { await store.loadProducts() }
                    }
                    .buttonStyle(.bordered)
                } else {
                    ProgressView()
                }
            } else if store.access == .notStarted, let trial = store.trialProduct {
                Button {
                    Task { await store.purchase(trial) }
                } label: {
                    Text("Try Free for \(StoreManager.trialDays) Days")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if let unlock = store.unlockProduct {
                    Button {
                        Task { await store.purchase(unlock) }
                    } label: {
                        Text("Buy Now for \(unlock.displayPrice)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Text("The trial is free and ends by itself after \(StoreManager.trialDays) days. You won't be charged and nothing renews. After the trial, Voice Timer is a one-time purchase of \(unlock.displayPrice). Building timers by hand is always free.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else if let unlock = store.unlockProduct {
                Button {
                    Task { await store.purchase(unlock) }
                } label: {
                    Text("Unlock for \(unlock.displayPrice)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Text("One-time purchase. No subscription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Restore Purchases") {
                Task { await store.restorePurchases() }
            }
            .font(.footnote)
        }
        .controlSize(.large)
        .disabled(store.isPurchasing)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

private struct FeatureRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        VoicePaywallView()
    }
    .environment(StoreManager())
}
