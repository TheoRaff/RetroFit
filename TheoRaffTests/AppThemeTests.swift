import Foundation
import SwiftUI
import Testing
import UIKit
@testable import TheoRaff

struct AppThemeTests {
    @Test func savesUnderItsOwnKey() {
        #expect(AppTheme.storageKey == "appTheme")
    }

    @Test(arguments: [
        (nil, AppTheme.classic),
        ("classic", .classic),
        ("chrome", .chrome),
        ("vaporwave", .classic),
    ])
    func readsTheSavedValue(saved: String?, expected: AppTheme) {
        #expect(AppTheme(storedValue: saved) == expected)
    }

    @Test func namesEachThemeForThePicker() {
        #expect(AppTheme.allCases == [.classic, .chrome])
        #expect(AppTheme.classic.name == "Classic")
        #expect(AppTheme.chrome.name == "Y2K Chrome")
    }
}

struct ThemeStoreTests {
    /// A throwaway defaults suite, so the tests never touch the app's own settings.
    private func makeDefaults() throws -> UserDefaults {
        let name = "ThemeStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func startsClassicWithNothingSaved() throws {
        let store = ThemeStore(defaults: try makeDefaults())
        #expect(store.theme == .classic)
    }

    @Test func loadsTheSavedTheme() throws {
        let defaults = try makeDefaults()
        defaults.set("chrome", forKey: AppTheme.storageKey)
        #expect(ThemeStore(defaults: defaults).theme == .chrome)
    }

    @Test func ignoresAnUnknownSavedTheme() throws {
        let defaults = try makeDefaults()
        defaults.set("vaporwave", forKey: AppTheme.storageKey)
        #expect(ThemeStore(defaults: defaults).theme == .classic)
    }

    @Test func savesTheChosenTheme() throws {
        let defaults = try makeDefaults()
        let store = ThemeStore(defaults: defaults)

        store.theme = .chrome
        #expect(defaults.string(forKey: AppTheme.storageKey) == "chrome")
        #expect(ThemeStore(defaults: defaults).theme == .chrome)

        store.theme = .classic
        #expect(defaults.string(forKey: AppTheme.storageKey) == "classic")
    }
}

struct Win95PaletteTests {
    @Test func eachThemeHasItsOwnPalette() {
        #expect(AppTheme.classic.palette == .classic)
        #expect(AppTheme.chrome.palette == .chrome)
        #expect(Win95Palette.chrome != .classic)
    }

    /// The Classic theme must look exactly as it did before themes existed.
    @Test func classicKeepsTheWindowsColours() {
        let palette = Win95Palette.classic
        let expected: [(Color, UInt32)] = [
            (palette.face, 0xD4D0C8),
            (palette.highlight, 0xFFFFFF),
            (palette.light, 0xDFDFDF),
            (palette.shadow, 0x808080),
            (palette.darkShadow, 0x404040),
            (palette.window, 0xFFFFFF),
            (palette.text, 0x000000),
            (palette.secondaryText, 0x404040),
            (palette.disabledText, 0x808080),
            (palette.navy, 0x0A246A),
            (palette.sky, 0xA6CAF0),
            (palette.heart, 0xCE1B4E),
            (palette.tooltip, 0xFFFFE1),
            (palette.ditherLight, 0xFFFFFF),
            (palette.ditherDark, 0xD4D0C8),
        ]
        for (colour, hex) in expected {
            #expect(Self.matches(colour, hex: hex), "Expected #\(String(hex, radix: 16))")
        }
    }

    @Test(arguments: [Win95Palette.classic, .chrome])
    func textIsReadableOnTheWindowGrey(palette: Win95Palette) {
        #expect(Self.contrast(palette.text, palette.face) >= 7)
        #expect(Self.contrast(palette.secondaryText, palette.face) >= 4.5)
        #expect(Self.contrast(palette.navy, palette.face) >= 4.5)
    }

    /// Chrome text sits on pearl buttons and panels, candy toggles, and glass over the backdrop.
    @Test func chromeTextIsReadableOnEverySurface() {
        let chrome = Win95Palette.chrome
        let solidFills = Chrome.pearlColours + Chrome.panelColours + [chrome.face, chrome.ditherLight, chrome.ditherDark]
        let glassFills = Chrome.backdropColours.flatMap { backdrop in
            [Self.composite(chrome.window, over: backdrop), Self.composite(Chrome.groupFill, over: backdrop)]
        }
        for fill in solidFills + glassFills {
            #expect(Self.contrast(chrome.text, fill) >= 7)
            #expect(Self.contrast(chrome.secondaryText, fill) >= 4.5)
        }
        for fill in solidFills {
            #expect(Self.contrast(chrome.navy, fill) >= 4.5)
        }
    }

    /// The ink edge round chrome lettering is what makes the pale letters readable.
    @Test func chromeLetteringEdgeStandsOutFromTheBackdrop() {
        for backdrop in Chrome.backdropColours + [Win95Palette.chrome.face] {
            #expect(Self.contrast(Chrome.ink, backdrop) >= 7)
        }
    }

    @Test(arguments: AppTheme.allCases)
    func usesFontsTheSystemShips(theme: AppTheme) {
        for bold in [false, true] {
            let name = Win95.fontName(for: theme, bold: bold)
            #expect(UIFont(name: name, size: 14) != nil, "\(name) isn't installed")
        }
    }

    @Test func classicKeepsVerdana() {
        #expect(Win95.fontName(for: .classic, bold: false) == "Verdana")
        #expect(Win95.fontName(for: .classic, bold: true) == "Verdana-Bold")
    }

    // MARK: Helpers

    private static func resolved(_ colour: Color) -> Color.Resolved {
        colour.resolve(in: EnvironmentValues())
    }

    private static func matches(_ colour: Color, hex: UInt32) -> Bool {
        let rgb = resolved(colour)
        let expected = [(hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF].map { Float($0) / 255 }
        return zip([rgb.red, rgb.green, rgb.blue], expected).allSatisfy { abs($0 - $1) < 0.002 }
            && rgb.opacity == 1
    }

    /// `top` drawn over an opaque `bottom`, as the screen shows it.
    private static func composite(_ top: Color, over bottom: Color) -> Color {
        let (upper, lower) = (resolved(top), resolved(bottom))
        func mix(_ a: Float, _ b: Float) -> Double { Double(a * upper.opacity + b * (1 - upper.opacity)) }
        return Color(red: mix(upper.red, lower.red), green: mix(upper.green, lower.green), blue: mix(upper.blue, lower.blue))
    }

    /// The WCAG contrast ratio between two opaque colours, from 1 to 21. Composite glass first.
    private static func contrast(_ first: Color, _ second: Color) -> Double {
        #expect(resolved(first).opacity == 1 && resolved(second).opacity == 1, "Contrast needs opaque colours")
        func luminance(_ colour: Color) -> Double {
            let rgb = resolved(colour)
            return 0.2126 * Double(rgb.linearRed) + 0.7152 * Double(rgb.linearGreen) + 0.0722 * Double(rgb.linearBlue)
        }
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }
}
