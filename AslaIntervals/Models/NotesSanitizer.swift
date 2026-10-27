import Foundation

/// Cleans the free-text Notes field so stored text is plain, bounded and free of
/// invisible characters that could hide or disguise content.
///
/// SwiftUI shows notes as plain text, so there is no markup or script risk on
/// screen. Sanitizing keeps the stored data safe if it is later exported, shared
/// or synced. Lengths are counted in visible characters (grapheme clusters), so an
/// emoji is never cut in half.
enum NotesSanitizer {
    /// Maximum number of characters in a note.
    static let maxLength = 1000

    /// Light cleaning applied while the user types: removes unsafe characters and
    /// enforces the length limit, but leaves whitespace alone so typing feels normal.
    static func limitWhileTyping(_ text: String) -> String {
        String(removingUnsafeCharacters(from: text).prefix(maxLength))
    }

    /// Full cleaning applied when a note is saved or loaded.
    static func sanitize(_ text: String) -> String {
        var result = removingUnsafeCharacters(from: text)
            // Use one consistent Unicode form, so "é" is always stored the same way.
            .precomposedStringWithCanonicalMapping

        // Collapse runs of blank lines to a single empty line.
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(result.prefix(maxLength))
    }

    // MARK: Private

    private static func removingUnsafeCharacters(from text: String) -> String {
        var scalars = String.UnicodeScalarView()
        // Treat Windows and old Mac line endings as plain line breaks.
        let normalizedLineEndings = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        for scalar in normalizedLineEndings.unicodeScalars {
            switch scalar.value {
            case 0x0A:
                scalars.append(scalar)                       // Line break: keep.
            case 0x09:
                scalars.append(" ")                          // Tab: becomes a space.
            case 0x2028, 0x2029:
                scalars.append("\n")                         // Line/paragraph separator.
            case 0x00...0x1F, 0x7F...0x9F:
                continue                                     // Other control characters.
            case 0x200B, 0x2060, 0xFEFF, 0x180E:
                continue                                     // Invisible zero-width characters.
            case 0x202A...0x202E, 0x2066...0x2069:
                continue                                     // Bidi overrides that can disguise text.
            case 0xFFF9...0xFFFB, 0xFFFE, 0xFFFF:
                continue                                     // Interlinear annotations, non-characters.
            default:
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }
}
