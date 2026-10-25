import SwiftUI

/// A classic grey push button, or a glossy chrome pill in Y2K Chrome. Size the label yourself;
/// the bevel wraps whatever frame it has. Pass `isOn` for a toggle that stays pressed in with
/// the dither fill.
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
        let isChrome = Win95.isChrome
        let pushedIn = isPressed || isOn
        label
            .foregroundStyle(isEnabled ? Win95.text : Win95.disabledText)
            .win95DisabledEmboss(!isEnabled)
            // Windows nudges a pressed button's caption down and right by a pixel.
            .offset(x: pushedIn && !isChrome ? 1 : 0, y: pushedIn && !isChrome ? 1 : 0)
            .background {
                if isChrome {
                    // A chrome pill sinks a little instead.
                    Capsule()
                        .fill(pushedIn ? Chrome.candy : Chrome.pearl)
                        .overlay { Capsule().fill(Chrome.sheen).padding(1.5) }
                        .overlay { Capsule().strokeBorder(Chrome.rim, lineWidth: 1.5) }
                        .shadow(color: Chrome.shadowTint, radius: pushedIn ? 1 : 3, y: pushedIn ? 0.5 : 2)
                        .scaleEffect(isPressed ? 0.95 : 1)
                        .animation(.snappy(duration: 0.12), value: isPressed)
                } else if isOn {
                    Win95Dither()
                } else {
                    Win95.face
                }
            }
            .overlay {
                if !isChrome {
                    Win95Bevel(style: pushedIn ? .sunken : .raised)
                }
            }
            .contentShape(Rectangle())
    }
}

/// The blue gradient caption bar across the top of a window, with optional buttons on the right.
/// The title is centred, as in the mockups, or left-aligned like a real window's when `centred`
/// is false, which leaves more room beside wide buttons. In Y2K Chrome the bar is clear and
/// the title is liquid-chrome lettering.
struct Win95TitleBar<Accessory: View>: View {
    let title: String
    var height: CGFloat = 44
    var centred = true
    @ViewBuilder var accessory: () -> Accessory

    @ScaledMetric(relativeTo: .headline) private var chromeTitleSize: CGFloat = 26

    /// A window's own caption, rather than the small one on a dialog.
    private var isLarge: Bool { height > 36 }

    var body: some View {
        let isChrome = Win95.isChrome
        let minHeight = isChrome && isLarge ? max(height, 52) : height
        Group {
            if centred {
                titleText
                    .padding(.horizontal, 76)
                    .frame(maxWidth: .infinity, minHeight: minHeight)
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
                .frame(minHeight: minHeight)
            }
        }
        // Stays inside its own frame instead of spilling up behind the status bar.
        .background(isChrome ? AnyShapeStyle(Color.clear) : AnyShapeStyle(LinearGradient(colors: [Win95.navy, Win95.sky], startPoint: .leading, endPoint: .trailing)), ignoresSafeAreaEdges: [])
        .overlay(alignment: .top) {
            if !isChrome {
                Win95.highlight.frame(height: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if !isChrome {
                Win95.darkShadow.frame(height: 1)
            } else if !isLarge {
                Rectangle().fill(Chrome.divider).frame(height: 1).padding(.horizontal, 10)
            }
        }
    }

    @ViewBuilder
    private var titleText: some View {
        if Win95.isChrome && isLarge && centred {
            ChromeLettering(text: title.uppercased(), size: chromeTitleSize)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isHeader)
        } else if Win95.isChrome {
            // Chrome lettering smears at dialog size and runs out of room beside window buttons,
            // so those captions are plain ink.
            Text(title)
                .font(Win95.font(isLarge ? 17 : 15, bold: true, relativeTo: .headline))
                .foregroundStyle(Win95.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
        } else {
            Text(title)
                .font(Win95.font(height > 36 ? 17 : 14, bold: true, relativeTo: .headline))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
        }
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
        // Unclipped, so the text field's selection handles can reach past the well.
        .win95Sunken(clipsContent: false)
    }
}

/// A row of joined toggle buttons with one pressed in, like the closet's category filter.
/// Pass a vertical `axis` to stack them, for options too wide to sit side by side.
struct Win95SegmentedPicker<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    var axis: Axis = .horizontal
    let title: (Option) -> String

    var body: some View {
        // Joined in Classic; separate pills in Y2K Chrome.
        let spacing: CGFloat = Win95.isChrome ? 6 : 0
        let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: spacing)) : AnyLayout(VStackLayout(spacing: spacing))
        layout {
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

/// A pale yellow tooltip, for short messages such as "Saved to Photos". A glass bubble in Y2K Chrome.
struct Win95Tooltip: View {
    let text: String

    var body: some View {
        let label = Text(text)
            .font(Win95.font(14))
            .foregroundStyle(Win95.text)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        if Win95.isChrome {
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            label
                .padding(.horizontal, 4)
                .background(Chrome.panel, in: shape)
                .overlay(shape.strokeBorder(Chrome.rim, lineWidth: 1.5))
                .compositingGroup()
                .shadow(color: Chrome.shadowTint, radius: 6, y: 2)
        } else {
            label
                .background(Win95.tooltip, ignoresSafeAreaEdges: [])
                .overlay(Rectangle().strokeBorder(Win95.text, lineWidth: 1))
        }
    }
}

/// The small pixel heart from the mockup's Like button: pink with a black outline,
/// drawn square by square like a Windows icon. A glossy candy heart in Y2K Chrome.
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
        Group {
            if Win95.isChrome {
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Chrome.heart)
                    // An ink edge, so the pink still stands out on pearl and candy buttons.
                    .overlay {
                        Image(systemName: "heart")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Chrome.ink)
                    }
                    .shadow(color: Chrome.glow, radius: 3)
            } else {
                let (outline, fill) = (Win95.text, Win95.heart)
                Canvas { context, _ in
                    for (row, line) in Self.bitmap.enumerated() {
                        for (column, cell) in line.enumerated() where cell != " " {
                            let square = CGRect(x: CGFloat(column) * pixel, y: CGFloat(row) * pixel, width: pixel, height: pixel)
                            context.fill(Path(square), with: .color(cell == "#" ? outline : fill))
                        }
                    }
                }
            }
        }
        .frame(width: 11 * pixel, height: 10 * pixel)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Windows draws disabled captions grey with a white copy one pixel down and right.
    /// Y2K Chrome just greys them.
    func win95DisabledEmboss(_ disabled: Bool) -> some View {
        shadow(color: disabled && !Win95.isChrome ? Win95.highlight : .clear, radius: 0, x: 1, y: 1)
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
