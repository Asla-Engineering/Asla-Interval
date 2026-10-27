import SwiftUI

/// Background color for the workout screen, chosen per timer.
///
/// The colors are fixed (they don't change with Light/Dark mode) and strongly
/// saturated so they stay visible in a brightly lit gym. Text and the ring use
/// black or white, whichever has the higher contrast against the background
/// (all combinations meet WCAG AA, 4.5:1).
enum WorkoutColor: String, CaseIterable, Identifiable {
    case green, blue, pink, red, white, black

    static let `default`: WorkoutColor = .green

    var id: String { rawValue }

    var name: LocalizedStringKey {
        switch self {
        case .green: "Green"
        case .blue: "Blue"
        case .pink: "Pink"
        case .red: "Red"
        case .white: "White"
        case .black: "Black"
        }
    }

    /// Full-strength background, used while working and when finished.
    var active: WorkoutStyle {
        switch self {
        case .green: WorkoutStyle(background: Color(hex: 0x00E25B), isLight: true)
        case .blue: WorkoutStyle(background: Color(hex: 0x0A6CFF), isLight: false)
        case .pink: WorkoutStyle(background: Color(hex: 0xFF2E93), isLight: true)
        case .red: WorkoutStyle(background: Color(hex: 0xFF1A2D), isLight: true)
        case .white: WorkoutStyle(background: Color(hex: 0xFFFFFF), isLight: true)
        case .black: WorkoutStyle(background: Color(hex: 0x000000), isLight: false)
        }
    }

    /// Dimmed variant of the same color, used during get ready and rest, so the
    /// phase can be seen at a glance from across the room.
    var dimmed: WorkoutStyle {
        switch self {
        case .green: WorkoutStyle(background: Color(hex: 0x005F26), isLight: false)
        case .blue: WorkoutStyle(background: Color(hex: 0x042D6B), isLight: false)
        case .pink: WorkoutStyle(background: Color(hex: 0x6B133E), isLight: false)
        case .red: WorkoutStyle(background: Color(hex: 0x6B0B13), isLight: false)
        case .white: WorkoutStyle(background: Color(hex: 0xBDBDBD), isLight: true)
        case .black: WorkoutStyle(background: Color(hex: 0x2E2E30), isLight: false)
        }
    }
}

/// Colors for one workout background: the background itself and the black or
/// white content drawn on top of it.
struct WorkoutStyle: Equatable {
    let background: Color
    /// True when the background is light enough to need black content.
    let isLight: Bool

    var foreground: Color { isLight ? .black : .white }
    var secondary: Color { foreground.opacity(0.75) }
    var track: Color { foreground.opacity(0.2) }
    var colorScheme: ColorScheme { isLight ? .light : .dark }
}

extension Color {
    /// A fixed sRGB color from a hex value like `0xFF2E93`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
