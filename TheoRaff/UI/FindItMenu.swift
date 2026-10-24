import SwiftUI

/// The "Find it" button: a menu of Depop, Vinted and eBay searches for a garment,
/// so you can thrift what you just tried on. Pass the button's look as `label`.
struct FindItMenu<Content: View>: View {
    let garment: Garment
    @ViewBuilder let label: () -> Content

    var body: some View {
        Menu {
            Section("Find \(garment.name) second-hand") {
                ForEach(Marketplace.allCases) { marketplace in
                    if let url = marketplace.searchURL(for: garment.searchQuery) {
                        Link(destination: url) {
                            Label(marketplace.name, systemImage: "arrow.up.right")
                        }
                    }
                }
            }
        } label: {
            label()
        }
        .accessibilityLabel("Find \(garment.name) second-hand")
    }
}
