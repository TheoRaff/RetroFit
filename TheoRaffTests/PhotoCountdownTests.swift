import Testing
@testable import TheoRaff

struct PhotoCountdownTests {
    @Test func matchesTheProfileSetting() {
        #expect(PhotoCountdown.storageKey == "photoCountdownSeconds")
        #expect(PhotoCountdown.defaultSeconds == 3)
        #expect(PhotoCountdown.range == 0...10)
    }

    @Test(arguments: [(-5, 0), (0, 0), (4, 4), (10, 10), (99, 10)])
    func clampsToTheProfileRange(seconds: Int, expected: Int) {
        #expect(PhotoCountdown.clamped(seconds) == expected)
    }

    @Test(arguments: [
        (0, "Tap to take the photo", "Take photo"),
        (1, "Tap to start a 1-second timer", "Start 1 second timer"),
        (7, "Tap to start a 7-second timer", "Start 7 second timer"),
        (42, "Tap to start a 10-second timer", "Start 10 second timer"),
    ])
    func describesTheShutter(seconds: Int, hint: String, accessibilityLabel: String) {
        #expect(PhotoCountdown.shutterHint(for: seconds) == hint)
        #expect(PhotoCountdown.shutterAccessibilityLabel(for: seconds) == accessibilityLabel)
    }
}
