import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Whether Voice Timer can run on this iPhone right now.
enum VoiceFeatureStatus: Equatable {
    case available
    /// The iPhone supports Apple Intelligence, but it is turned off in Settings.
    case appleIntelligenceOff
    /// Apple Intelligence is still downloading or getting ready.
    case modelNotReady
    /// Older iOS or an iPhone without Apple Intelligence. This never changes.
    case unsupported
}

enum VoiceFeature {
    static var status: VoiceFeatureStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceOff
            case .unavailable(.modelNotReady):
                return .modelNotReady
            case .unavailable:
                return .unsupported
            @unknown default:
                return .unsupported
            }
        }
        #endif
        return .unsupported
    }

    /// Whether to show Voice Timer at all. It is hidden on iPhones that can never
    /// run it, so nobody is offered something they can't use (Human Interface
    /// Guidelines; App Review Guideline 2.3).
    static var isOffered: Bool { status != .unsupported }

    /// The language to listen for: the iPhone's language when it is Norwegian or
    /// English, otherwise English. Nynorsk is recognized as Norwegian Bokmål.
    static var speechLocale: Locale {
        let preferred = Locale.preferredLanguages.first ?? "en-US"
        switch Locale(identifier: preferred).language.languageCode?.identifier {
        case "nb", "no", "nn":
            return Locale(identifier: "nb-NO")
        case "en":
            return Locale(identifier: preferred)
        default:
            return Locale(identifier: "en-US")
        }
    }

    /// The name of the language Voice Timer listens in, shown under the microphone.
    static var speechLanguageName: String {
        speechLocale.language.languageCode?.identifier == "nb" ? "Norwegian" : "English"
    }
}
