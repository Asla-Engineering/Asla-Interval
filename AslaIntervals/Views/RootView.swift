import SwiftUI
import SwiftData

/// Top level: one tab per mode.
struct RootView: View {
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    var body: some View {
        TabView {
            SimpleModeView()
                .tabItem { Label("Simple", systemImage: "timer") }

            CustomModeView()
                .tabItem { Label("Custom", systemImage: "slider.horizontal.3") }
        }
        .onAppear { appearance.apply() }
        .onChange(of: appearance) { _, newValue in
            newValue.apply(animated: true)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [TabataTimer.self, CustomTimer.self], inMemory: true)
        .environment(StoreManager())
}
