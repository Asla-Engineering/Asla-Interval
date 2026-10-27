import SwiftUI
import SwiftData

@main
struct AslaIntervalsApp: App {
    /// Created once at launch, so purchases made anywhere (also outside the app,
    /// like Ask to Buy approvals) are picked up right away.
    @State private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .modelContainer(for: [TabataTimer.self, CustomTimer.self])
    }
}
