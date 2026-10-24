import SwiftUI

/// The profile tab: how many looks you've tried and everything you've saved.
struct ProfileView: View {
    let session: TryOnSession
    @AppStorage("photoCountdownSeconds") private var photoCountdownSeconds = 3

    var body: some View {
        VStack(spacing: 0) {
            Win95TitleBar(title: "Profile")

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    groupBox("Your style") {
                        groupBox("Photo countdown") {
                            Stepper(value: $photoCountdownSeconds, in: 0...10) {
                                HStack {
                                    Text("Before photo")
                                        .font(Win95.font(14))

                                    Spacer()

                                    Text(photoCountdownSeconds == 0
                                         ? "Off"
                                         : "\(photoCountdownSeconds) sec")
                                        .font(Win95.font(14, bold: true).monospacedDigit())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .win95Sunken()
                                }
                                .foregroundStyle(Win95.text)
                            }

                            Text("Choose from 0 to 10 seconds.")
                                .font(Win95.font(12))
                                .foregroundStyle(Win95.secondaryText)
                        }
                        statRow("Saved items", value: "\(session.closet.count)")
                        statRow("Looks in the deck", value: "\(session.outfits.count)")
                    }
                    groupBox("Saved items") {
                        if session.closet.isEmpty {
                            Text("Nothing saved yet. Tap the heart on a look or in the closet.")
                                .font(Win95.font(14))
                                .foregroundStyle(Win95.secondaryText)
                        } else {
                            ForEach(session.closet) { garment in
                                savedRow(garment)
                            }
                        }
                    }
                }
                .padding(12)
            }
            .padding(8)
        }
        .background(Win95.face.ignoresSafeArea())
    }

    /// A Windows group box: an etched frame with its caption sitting on the top edge.
    private func groupBox<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(.horizontal, 12)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Win95Bevel(style: .etched).padding(.top, 8))
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(Win95.font(13))
                    .foregroundStyle(Win95.text)
                    .padding(.horizontal, 4)
                    .background(Win95.face)
                    .padding(.leading, 8)
                    .accessibilityAddTraits(.isHeader)
            }
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Win95.font(14))
            Spacer()
            Text(value)
                .font(Win95.font(14, bold: true).monospacedDigit())
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .win95Sunken()
        }
        .foregroundStyle(Win95.text)
        .accessibilityElement(children: .combine)
    }

    private func savedRow(_ garment: Garment) -> some View {
        HStack(spacing: 10) {
            Color.clear
                .frame(width: 44, height: 44)
                .overlay {
                    if let image = ProductPhoto.named(garment.imageName) {
                        Image(uiImage: image).resizable().scaledToFit().padding(4)
                    }
                }
                .win95Sunken()
                .accessibilityHidden(true)
            Text(garment.name)
                .font(Win95.font(14))
                .foregroundStyle(Win95.text)
            Spacer(minLength: 0)
            Button {
                session.unlike(garment)
            } label: {
                Win95Heart(pixel: 1.3).frame(width: 30, height: 28)
            }
            .buttonStyle(Win95ButtonStyle())
            .accessibilityLabel("Remove \(garment.name) from saved items")
        }
    }
}
