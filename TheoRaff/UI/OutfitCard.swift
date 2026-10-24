import SwiftUI

/// The card under the camera: what you're wearing, where you are in the deck, and the controls.
struct OutfitCard: View {
    let outfit: Outfit
    let position: Int
    let total: Int
    let isLiked: Bool
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onLike: () -> Void
    let onForward: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            arrowButton(systemImage: "chevron.left", label: "Previous outfit", enabled: canGoBack, action: onBack)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(outfit.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(outfit.garments.map(\.name).joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(position) of \(total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: onLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundStyle(isLiked ? .pink : .primary)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLiked ? "Remove from closet" : "Save to closet")
            
            arrowButton(systemImage: "chevron.right", label: "Next outfit", enabled: canGoForward, action: onForward)
        }
        .padding(12)
        .background(
            Color(red: 0.75, green: 0.69, blue: 0.61),
            in: RoundedRectangle(cornerRadius: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    Color(red: 0.40, green: 0.33, blue: 0.27).opacity(0.8),
                    lineWidth: 1
                )
        )
    }
        
        private func arrowButton(systemImage: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .frame(width: 40, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.3)
            .accessibilityLabel(label)
        }
    }
