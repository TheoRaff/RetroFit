import Foundation
import Observation

/// The look picked on the Profile tab.
enum AppTheme: String, CaseIterable, Identifiable {
    /// Windows 2000 grey, as in the design mockups.
    case classic
    /// Pink iridescent Y2K, with liquid-chrome lettering and glossy glass.
    case chrome

    /// The UserDefaults key the theme is saved under.
    static let storageKey = "appTheme"

    var id: Self { self }

    /// The saved theme, or Classic when nothing (or something unknown) was saved.
    init(storedValue: String?) {
        self = storedValue.flatMap(AppTheme.init(rawValue:)) ?? .classic
    }

    var name: String {
        switch self {
        case .classic: "Classic"
        case .chrome: "Y2K Chrome"
        }
    }
}

/// Holds the current theme and saves it between launches. `Win95` reads it for every colour
/// and font, so views that use them redraw as soon as it changes.
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: AppTheme.storageKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = AppTheme(storedValue: defaults.string(forKey: AppTheme.storageKey))
    }
}
