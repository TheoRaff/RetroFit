import SwiftUI

/// A small Windows message box: a title bar with a close button, an icon beside the message,
/// and a row of buttons. Show it with `win95Modal`, which centres it and blocks what's behind.
struct Win95MessageBox<Buttons: View>: View {
    let title: String
    let message: String
    var systemImage = "questionmark.circle.fill"
    var iconColour: Color = Win95.navy
    let onClose: () -> Void
    @ViewBuilder var buttons: () -> Buttons

    var body: some View {
        VStack(spacing: 0) {
            Win95TitleBar(title: title, height: 32, centred: false) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .heavy))
                        .frame(width: 30, height: 24)
                }
                .buttonStyle(Win95ButtonStyle())
                .accessibilityLabel("Close")
            }

            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 30))
                        .foregroundStyle(.white, iconColour)
                        .accessibilityHidden(true)
                    Text(message)
                        .font(Win95.font(14))
                        .foregroundStyle(Win95.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 10) {
                    buttons()
                }
            }
            .padding(14)
        }
        .padding(2)
        .win95Raised()
        .frame(maxWidth: 340)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

/// A message box button. The default choice gets the black ring Windows draws round it,
/// inside the same overall size as its neighbours.
struct Win95DialogButton: View {
    let title: String
    var isDefault = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Win95.font(14))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
                .frame(minWidth: isDefault ? 88 : 90, minHeight: isDefault ? 34 : 36)
        }
        .buttonStyle(Win95ButtonStyle())
        .padding(isDefault ? 1 : 0)
        .overlay {
            if isDefault {
                Rectangle().strokeBorder(Win95.text, lineWidth: 1)
            }
        }
    }
}

extension View {
    /// Shows `box` centred over the whole screen while `item` is set, the way Windows shows a
    /// modal dialog: everything behind stops responding and VoiceOver can't reach it.
    /// Tapping outside the box dismisses it.
    func win95Modal<Item: Identifiable, Box: View>(item: Binding<Item?>, @ViewBuilder box: @escaping (Item) -> Box) -> some View {
        self
            .accessibilityHidden(item.wrappedValue != nil)
            .overlay {
                if let value = item.wrappedValue {
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture { item.wrappedValue = nil }
                            .accessibilityHidden(true)
                        box(value)
                            .padding(24)
                    }
                    .accessibilityAction(.escape) { item.wrappedValue = nil }
                    .transition(.opacity)
                }
            }
            .animation(.snappy(duration: 0.15), value: item.wrappedValue?.id)
    }
}
