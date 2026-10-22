import DeskPetsCore
import Foundation

@MainActor
enum L {
    static var language: AppLanguage = .system
    private static let localization = AppLocalization()

    static func t(_ key: String) -> String {
        localization.text(key, language: language)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), arguments: arguments)
    }

    static func languageName(_ language: AppLanguage) -> String {
        switch language {
        case .system: return t("language.system")
        case .english: return "English"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        }
    }

    static func error(_ error: Error) -> String {
        if let error = error as? GhosttyFocusError {
            switch error {
            case .automationDenied: return t("error.ghosttyPermission")
            case .unavailable: return t("error.ghosttyUnavailable")
            case .notFound: return t("error.ghosttyNotFound")
            case .ambiguous: return t("error.ghosttyAmbiguous")
            }
        }
        if let error = error as? CharacterError {
            switch error {
            case .invalidName: return t("error.characterName")
            case .alreadyExists(let name): return format("error.characterExists", name)
            case .notAGIF(let file): return format("error.notGIF", file)
            case .builtIn: return t("error.builtIn")
            }
        }
        if let error = error as? HookInstallerError {
            switch error {
            case .notAnObject(let path): return format("error.jsonObject", path)
            case .malformedHooks(let path): return format("error.hooksLayout", path)
            }
        }
        return error.localizedDescription
    }
}
