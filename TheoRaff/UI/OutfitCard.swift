import SwiftUI

/// The card under the camera: the look you're wearing with a photo of its main piece,
/// where you are in the deck, and a button to the next look. The edges of the next cards
/// peek out above it while there are more to come.
struct OutfitCard: View {
    let outfit: Outfit
    let position: Int
    let total: Int
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(outfit.name)
                    .font(Win95.font(17, bold: true, relativeTo: .headline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(Win95.font(14, relativeTo: .subheadline))
                    .lineLimit(1)
                Text("\(position) of \(total)")
                    .font(Win95.font(12, relativeTo: .caption).monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                    .overlay(Win95Bevel(style: .thinSunken))
            }
            .foregroundStyle(Win95.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button(action: onForward) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(canGoForward ? Win95.text : Win95.disabledText)
                    .win95DisabledEmboss(!canGoForward)
                    .frame(width: 34, height: 60, alignment: .trailing)
                    .padding(.trailing, 3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
            .accessibilityLabel("Next look")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .win95Raised()
        .background(alignment: .top) { deckEdges }
        .accessibilityAction(named: "Previous look") {
            if canGoBack { onBack() }
        }
    }

    /// What's in the look. A single glasses or hat card says what kind it is instead of
    /// repeating its name.
    private var subtitle: String {
        if outfit.garments.count == 1, let garment = outfit.garments.first {
            switch garment.category {
            case .eyewear: return "Glasses · live try-on"
            case .headwear: return "Hat · live try-on"
            default: break
            }
        }
        return outfit.garments.map(\.name).joined(separator: " · ")
    }

    /// The main piece: the top if the look has one, otherwise its first garment.
    private var thumbnail: some View {
        let garment = outfit.garment(for: .top) ?? outfit.garments.first
        return Color.clear
            .frame(width: 78, height: 78)
            .overlay {
                if let garment, let image = ProductPhoto.named(garment.imageName) {
                    Image(uiImage: image).resizable().scaledToFit().padding(5)
                }
            }
            .win95Sunken()
            .accessibilityHidden(true)
    }

    /// Up to two card edges stacked behind, one per look still to come.
    private var deckEdges: some View {
        let cardsBehind = min(2, max(0, total - position))
        return ZStack(alignment: .top) {
            ForEach((1...2).reversed(), id: \.self) { depth in
                if depth <= cardsBehind {
                    Color.clear
                        .frame(height: 20)
                        .win95Raised()
                        .padding(.horizontal, CGFloat(depth) * 8)
                        .offset(y: CGFloat(depth) * -6)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
