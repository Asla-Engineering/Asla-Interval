import SwiftUI

/// Toolbar button that switches between Light and Dark mode with one tap.
/// Touch and hold to choose Light, Dark or Use System Setting.
struct AppearanceButton: View {
    @AppStorage(AppearanceMode.storageKey) private var mode: AppearanceMode = .system
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Menu {
            Picker("Appearance", selection: $mode) {
                ForEach(AppearanceMode.allCases) { option in
                    Label(option.title, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                .contentTransition(.symbolEffect(.replace))
        } primaryAction: {
            mode = isDark ? .light : .dark
        }
        .accessibilityLabel(isDark ? "Switch to Light Mode" : "Switch to Dark Mode")
        .accessibilityHint("Touch and hold for more options.")
    }
}

#Preview {
    NavigationStack {
        Text("Preview")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AppearanceButton() }
            }
    }
}
