import Foundation
import Observation
import StoreKit

/// Product IDs. Must match the In-App Purchases in App Store Connect and in
/// `StoreKit/AslaIntervals.storekit` (used for testing in Xcode).
enum StoreProduct {
    /// Free (price 0) non-consumable that starts the trial. Its display name in
    /// App Store Connect must be "14-day Trial" (App Review Guideline 3.1.1).
    static let voiceTimerTrial = "no.asla.AslaIntervals.voicetimer.trial"
    /// One-time purchase that unlocks Voice Timer for good.
    static let voiceTimerUnlock = "no.asla.AslaIntervals.voicetimer.unlock"

    static let all = [voiceTimerTrial, voiceTimerUnlock]
}

/// What the person can do with Voice Timer right now.
enum VoiceTimerAccess: Equatable {
    /// Still reading purchases from the App Store.
    case loading
    /// Never started the trial and never bought it.
    case notStarted
    case trial(endsAt: Date)
    case trialEnded
    case purchased

    var canUseVoiceTimer: Bool {
        switch self {
        case .trial, .purchased: true
        case .loading, .notStarted, .trialEnded: false
        }
    }
}

/// Keeps track of Voice Timer purchases with StoreKit 2. There is no server:
/// Apple's signed transactions are the record of who has paid, they follow the
/// person's Apple Account to all their devices and survive reinstalls.
@MainActor
@Observable
final class StoreManager {
    /// Length of the free trial, counted from the moment it is started.
    static let trialDays = 14

    private(set) var products: [String: Product] = [:]
    private(set) var productsFailedToLoad = false
    private(set) var isPurchasing = false
    private(set) var hasLoadedEntitlements = false
    private(set) var isUnlocked = false
    private(set) var trialStartDate: Date?
    /// Message about the last purchase or restore, shown once in an alert.
    var message: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        // Purchases can also complete outside the app (Ask to Buy, refunds,
        // purchases on another device), so listen for the whole app lifetime.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refresh() }
    }

    // MARK: State

    var access: VoiceTimerAccess { access(at: .now) }

    func access(at date: Date) -> VoiceTimerAccess {
        guard hasLoadedEntitlements else { return .loading }
        if isUnlocked { return .purchased }
        guard let start = trialStartDate else { return .notStarted }
        let end = Calendar.current.date(byAdding: .day, value: Self.trialDays, to: start) ?? start
        return date < end ? .trial(endsAt: end) : .trialEnded
    }

    var trialProduct: Product? { products[StoreProduct.voiceTimerTrial] }
    var unlockProduct: Product? { products[StoreProduct.voiceTimerUnlock] }

    // MARK: Loading

    func refresh() async {
        await loadProducts()
        await updateEntitlements()
    }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: StoreProduct.all)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            productsFailedToLoad = loaded.isEmpty
        } catch {
            productsFailedToLoad = true
        }
    }

    /// Reads which products the person owns. Refunded purchases are not counted.
    func updateEntitlements() async {
        var unlocked = false
        var trialStart: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else {
                continue
            }
            switch transaction.productID {
            case StoreProduct.voiceTimerUnlock:
                unlocked = true
            case StoreProduct.voiceTimerTrial:
                trialStart = transaction.originalPurchaseDate
            default:
                break
            }
        }

        isUnlocked = unlocked
        trialStartDate = trialStart
        hasLoadedEntitlements = true
    }

    // MARK: Actions

    /// Buys a product (or starts the free trial). Returns true when it went through.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = "The App Store couldn't confirm this purchase. Please try again."
                    return false
                }
                await transaction.finish()
                await updateEntitlements()
                return true
            case .pending:
                message = "Your purchase is waiting for approval. Voice Timer unlocks as soon as it's approved."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            message = "The purchase couldn't be completed. \(error.localizedDescription)"
            return false
        }
    }

    /// Restores earlier purchases, e.g. on a new iPhone. App Review requires a
    /// visible way to do this.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return
        } catch {
            message = "Purchases couldn't be restored. \(error.localizedDescription)"
            return
        }
        await updateEntitlements()
        if !isUnlocked && trialStartDate == nil {
            message = "No earlier Voice Timer purchase was found for this Apple Account."
        }
    }

    // MARK: Private

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await updateEntitlements()
    }
}
