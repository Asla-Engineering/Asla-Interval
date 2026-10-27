import SwiftUI
import UIKit

/// The user's choice of Light, Dark or following the system setting.
/// Stored with `@AppStorage(AppearanceMode.storageKey)`.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearanceMode"

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: "Use System Setting"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Applies the mode to every window of the app, so sheets and covers follow too.
    ///
    /// The window style is set directly instead of using `.preferredColorScheme`,
    /// because that modifier does not reliably return to the system setting once a
    /// fixed scheme has been chosen. Screens that force their own scheme (the dark
    /// workout screen) still keep it.
    @MainActor
    func apply(animated: Bool = false) {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows where window.overrideUserInterfaceStyle != userInterfaceStyle {
                if animated {
                    UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
                        window.overrideUserInterfaceStyle = userInterfaceStyle
                    })
                } else {
                    window.overrideUserInterfaceStyle = userInterfaceStyle
                }
            }
        }
    }
}
