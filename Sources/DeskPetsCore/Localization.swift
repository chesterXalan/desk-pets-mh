import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case system
    case english = "en"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        let parts = (preferredLanguages.first ?? "en").lowercased()
            .replacingOccurrences(of: "_", with: "-").split(separator: "-")
        switch parts.first {
        case "en": return .english
        case "ja": return .japanese
        case "zh":
            if parts.contains("hans") { return .english }
            if parts.contains("hant") || parts.contains("tw") || parts.contains("hk") || parts.contains("mo") || parts.count == 1 {
                return .traditionalChinese
            }
            return .english
        default: return .english
        }
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
