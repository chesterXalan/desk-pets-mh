import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case system
    case english = "en"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for language in preferredLanguages {
            switch language.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-").first {
            case "en": return .english
            case "zh": return .traditionalChinese
            case "ja": return .japanese
            default: continue
            }
        }
        return .english
    }
}

public struct AppLocalization {
    private let bundles: [AppLanguage: Bundle]

    public init(resourceURL: URL? = Bundle.main.resourceURL) {
        var bundles: [AppLanguage: Bundle] = [:]
        if let resourceURL {
            for language in AppLanguage.allCases where language != .system {
                bundles[language] = Bundle(url: resourceURL.appendingPathComponent("\(language.rawValue).lproj"))
            }
        }
        self.bundles = bundles
    }

    public func text(_ key: String, language: AppLanguage) -> String {
        let fallback = bundles[.english]?.localizedString(forKey: key, value: key, table: nil) ?? key
        return bundles[language.resolved()]?.localizedString(forKey: key, value: fallback, table: nil) ?? fallback
    }
}
