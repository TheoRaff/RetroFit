import SwiftUI

/// A classic grey push button. Size the label yourself; the bevel wraps whatever frame it has.
/// Pass `isOn` for a toggle that stays pressed in with the dither fill.
struct Win95ButtonStyle: ButtonStyle {
    var isOn = false

    func makeBody(configuration: Configuration) -> some View {
        Win95ButtonBody(label: configuration.label, isPressed: configuration.isPressed, isOn: isOn)
    }
}

private struct Win95ButtonBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let isOn: Bool

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let pushedIn = isPressed || isOn
        label
            .foregroundStyle(isEnabled ? Win95.text : Win95.disabledText)
            .win95DisabledEmboss(!isEnabled)
            // Windows nudges a pressed button's caption down and right by a pixel.
            .offset(x: pushedIn ? 1 : 0, y: pushedIn ? 1 : 0)
            .background {
                if isOn {
                    Win95Dither()
                } else {
                    Win95.face
                }
            }
            .overlay(Win95Bevel(style: pushedIn ? .sunken : .raised))
            .contentShape(Rectangle())
    }
}

/// The blue gradient caption bar across the top of a window, with optional buttons on the right.
/// The title is centred, as in the mockups, or left-aligned like a real window's when `centred`
/// is false, which leaves more room beside wide buttons.
struct Win95TitleBar<Accessory: View>: View {
    let title: String
    var height: CGFloat = 44
    var centred = true
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        Group {
            if centred {
                titleText
                    .padding(.horizontal, 76)
                    .frame(maxWidth: .infinity, minHeight: height)
                    .overlay(alignment: .trailing) {
                        accessory().padding(.trailing, 6)
                    }
            } else {
                HStack(spacing: 6) {
                    titleText.frame(maxWidth: .infinity, alignment: .leading)
                    accessory()
                }
                .padding(.leading, 10)
                .padding(.trailing, 6)
                .frame(minHeight: height)
            }
        }
        // Stays inside its own frame instead of spilling up behind the status bar.
        .background(LinearGradient(colors: [Win95.navy, Win95.sky], startPoint: .leading, endPoint: .trailing), ignoresSafeAreaEdges: [])
        .overlay(alignment: .top) { Win95.highlight.frame(height: 1) }
        .overlay(alignment: .bottom) { Win95.darkShadow.frame(height: 1) }
    }

    private var titleText: some View {
        Text(title)
            .font(Win95.font(height > 36 ? 17 : 14, bold: true, relativeTo: .headline))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityAddTraits(.isHeader)
    }
}

extension Win95TitleBar where Accessory == EmptyView {
    init(title: String, height: CGFloat = 44, centred: Bool = true) {
        self.init(title: title, height: height, centred: centred) { EmptyView() }
    }
}

/// A sunken white search box with a magnifying glass, like the one in the closet mockup.
struct Win95SearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Win95.text)
                .accessibilityHidden(true)
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(Win95.secondaryText))
                .font(Win95.font(14))
                .foregroundStyle(Win95.text)
                .tint(Win95.navy)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 26, height: 24)
                }
                .buttonStyle(Win95ButtonStyle())
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(minHeight: 40)
        .win95Sunken()
    }
}

/// A row of joined toggle buttons with one pressed in, like the closet's category filter.
struct Win95SegmentedPicker<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let isOn = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(Win95.font(13, bold: isOn))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(Win95ButtonStyle(isOn: isOn))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// A small square toolbar button holding one icon, for tight spots such as the closet cards.
struct Win95IconLabel: View {
    let systemImage: String
    var colour: Color = Win95.text

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(colour)
            .frame(width: 30, height: 28)
    }
}

/// A pale yellow tooltip, for short messages such as "Saved to Photos".
struct Win95Tooltip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Win95.font(14))
            .foregroundStyle(Win95.text)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Win95.tooltip, ignoresSafeAreaEdges: [])
            .overlay(Rectangle().strokeBorder(Win95.text, lineWidth: 1))
    }
}

/// The small pixel heart from the mockup's Like button: pink with a black outline,
/// drawn square by square like a Windows icon.
struct Win95Heart: View {
    /// Points per pixel of the 11 x 10 bitmap.
    var pixel: CGFloat = 1.5

    private static let bitmap = [
        "  ##   ##  ",
        " #oo# #oo# ",
        "#oooo#oooo#",
        "#ooooooooo#",
        "#ooooooooo#",
        " #ooooooo# ",
        "  #ooooo#  ",
        "   #ooo#   ",
        "    #o#    ",
        "     #     ",
    ].map(Array.init)

    var body: some View {
        Canvas { context, _ in
            for (row, line) in Self.bitmap.enumerated() {
                for (column, cell) in line.enumerated() where cell != " " {
                    let square = CGRect(x: CGFloat(column) * pixel, y: CGFloat(row) * pixel, width: pixel, height: pixel)
                    context.fill(Path(square), with: .color(cell == "#" ? Win95.text : Win95.heart))
                }
            }
        }
        .frame(width: 11 * pixel, height: 10 * pixel)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Windows draws disabled captions grey with a white copy one pixel down and right.
    func win95DisabledEmboss(_ disabled: Bool) -> some View {
        shadow(color: disabled ? Win95.highlight : .clear, radius: 0, x: 1, y: 1)
    }
}

/// "✕ Skip": a bold icon beside the title, as on the mockup's buttons.
struct Win95ButtonLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.font(.system(size: 14, weight: .bold))
            configuration.title
        }
    }
}
