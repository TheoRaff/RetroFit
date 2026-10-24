import Foundation

/// The "Before photo" countdown chosen on the Profile tab, shared by every camera screen.
enum PhotoCountdown {
    /// The UserDefaults key the Profile tab's stepper writes with `@AppStorage`.
    static let storageKey = "photoCountdownSeconds"
    static let defaultSeconds = 3
    /// The choices the Profile tab offers. 0 means take the photo straight away.
    static let range = 0...10

    /// Keeps a value inside `range`, e.g. an old or hand-edited setting.
    static func clamped(_ seconds: Int) -> Int {
        min(max(seconds, range.lowerBound), range.upperBound)
    }

    /// The hint under a shutter button.
    static func shutterHint(for seconds: Int) -> String {
        let seconds = clamped(seconds)
        return seconds == 0 ? "Tap to take the photo" : "Tap to start a \(seconds)-second timer"
    }

    /// The shutter button's VoiceOver label.
    static func shutterAccessibilityLabel(for seconds: Int) -> String {
        let seconds = clamped(seconds)
        return seconds == 0 ? "Take photo" : "Start \(seconds) second timer"
    }
}
