import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case romanian = "ro"
    case arabic = "ar"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .romanian: return "Română"
        case .arabic: return "العربية"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var layoutDirection: LayoutDirection {
        self == .arabic ? .rightToLeft : .leftToRight
    }
}

@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    var currentLanguage: AppLanguage = .english

    private init() {
        let stored = UserDefaults.standard.string(forKey: "app_language") ?? "en"
        currentLanguage = AppLanguage(rawValue: stored) ?? .english
    }

    var locale: Locale {
        currentLanguage.locale
    }

    var layoutDirection: LayoutDirection {
        currentLanguage.layoutDirection
    }

    func setLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: "app_language")
        currentLanguage = language
    }
}
