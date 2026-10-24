import SwiftUI

extension View {
    /// When `garment` is set, shows a "Find it second-hand" message box with a button for each
    /// shop. Each opens that shop's search for the garment, in its app if it's installed.
    func findItPrompt(for garment: Binding<Garment?>) -> some View {
        modifier(FindItPrompt(garment: garment))
    }
}

private struct FindItPrompt: ViewModifier {
    @Binding var garment: Garment?
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.win95Modal(item: $garment) { item in
            Win95MessageBox(
                title: "Find it second-hand",
                message: "Search for \(item.name) on:",
                systemImage: "bag.circle.fill",
                onClose: { garment = nil }
            ) {
                ForEach(Marketplace.allCases) { marketplace in
                    if let url = marketplace.searchURL(for: item.searchQuery) {
                        Win95DialogButton(title: marketplace.name) {
                            garment = nil
                            openURL(url)
                        }
                        .accessibilityLabel("Search \(marketplace.name) for \(item.name)")
                    }
                }
            }
        }
    }
}
