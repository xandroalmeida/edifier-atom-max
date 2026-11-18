import Foundation

/// Looks up the key (English text) in Resources/<lang>.lproj/Localizable.strings.
/// macOS picks the language from the system preferences; anything other than
/// Portuguese or Spanish falls back to English (CFBundleDevelopmentRegion).
func L(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), locale: Locale.current, arguments: arguments)
}
