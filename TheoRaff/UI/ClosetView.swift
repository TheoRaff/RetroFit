import SwiftUI

/// The closet tab: every garment in the catalog, with search, a category filter and a
/// "Saved" toggle. Tapping a garment offers the AI try-on, or adding it to an outfit to try on
/// with other pieces; the bag button offers Find it. The dialogs are shown by `AppShellView`,
/// so they cover the tab bar too.
struct ClosetView: View {
    let garments: [Garment]
    let session: TryOnSession
    @Binding var tryOnPrompt: AITryOnLook?
    @Binding var findIt: Garment?

    @State private var searchText = ""
    @State private var selectedCategory = ClosetCategory.all
    @State private var showsSavedOnly = false

    private let columns = [
        GridItem(.flexible(), spacing: 10, alignment: .top),
        GridItem(.flexible(), spacing: 10, alignment: .top),
    ]

    private var filteredGarments: [Garment] {
        garments.filter { garment in
            let matchesSaved = !showsSavedOnly || session.isLiked(garment)
            let searchableText = ([garment.name, garment.searchQuery] + garment.tags).joined(separator: " ")
            let matchesSearch = searchText.isEmpty || searchableText.localizedCaseInsensitiveContains(searchText)
            return matchesSaved && selectedCategory.includes(garment.category) && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Win95TitleBar(title: "Closet") {
                Button {
                    showsSavedOnly.toggle()
                } label: {
                    // Sized for the bold label, so the button doesn't grow when switched on.
                    Text("Saved")
                        .font(Win95.font(15, bold: true))
                        .hidden()
                        .overlay { Text("Saved").font(Win95.font(15, bold: showsSavedOnly)) }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 32)
                }
                .buttonStyle(Win95ButtonStyle(isOn: showsSavedOnly))
                .accessibilityLabel("Saved items only")
                .accessibilityAddTraits(showsSavedOnly ? .isSelected : [])
            }

            VStack(spacing: 8) {
                Win95SearchField(prompt: "Search closet", text: $searchText)
                Win95SegmentedPicker(options: ClosetCategory.available(for: garments), selection: $selectedCategory) { $0.rawValue }
                garmentList
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(2)
                    .win95Sunken()
                if !session.fittingRoom.isEmpty {
                    fittingRoomBar
                }
            }
            .padding(8)
        }
        .background(Win95.face.ignoresSafeArea())
    }

    @ViewBuilder
    private var garmentList: some View {
        if filteredGarments.isEmpty {
            let nothingSaved = showsSavedOnly && !garments.contains { session.isLiked($0) }
            VStack(spacing: 8) {
                Image(systemName: nothingSaved ? "heart" : "tshirt")
                    .font(.system(size: 34))
                Text("No clothes found")
                    .font(Win95.font(16, bold: true))
                Text(nothingSaved ? "Tap the heart on anything you like to save it here." : "Try another search or category.")
                    .font(Win95.font(14))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Win95.secondaryText)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 13) {
                    ForEach(filteredGarments) { garment in
                        GarmentCard(garment: garment, session: session) { findIt = garment }
                            .contentShape(Rectangle())
                            .onTapGesture { tryOnPrompt = AITryOnLook(garment: garment) }
                            .accessibilityAction(named: "Try on with AI") { tryOnPrompt = AITryOnLook(garment: garment) }
                    }
                }
                .padding(8)
            }
        }
    }
}

extension ClosetView {
    /// The pieces picked to try on together, with buttons to try them on or clear them.
    private var fittingRoomBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your outfit")
                    .font(Win95.font(12, bold: true))
                Text(session.fittingRoom.map(\.name).joined(separator: " + "))
                    .font(Win95.font(12))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Win95.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button {
                tryOnPrompt = AITryOnLook(title: "Your outfit", garments: session.fittingRoom)
            } label: {
                Label("AI try on", systemImage: "wand.and.stars")
                    .labelStyle(Win95ButtonLabelStyle())
                    .font(Win95.font(13, bold: true))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 36)
            }
            .buttonStyle(Win95ButtonStyle())

            Button {
                withAnimation(.snappy) { session.clearFittingRoom() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(Win95ButtonStyle())
            .accessibilityLabel("Clear the outfit")
        }
        .padding(8)
        .win95Raised()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private enum ClosetCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case tops = "Tops"
    case bottoms = "Bottoms"
    case head = "Head"
    case shoes = "Shoes"

    var id: Self { self }

    func includes(_ category: GarmentCategory) -> Bool {
        switch self {
        case .all: true
        case .tops: category == .top
        case .bottoms: category == .bottom
        case .head: category == .headwear || category == .eyewear
        case .shoes: category == .shoes
        }
    }

    /// The filters worth showing: Shoes only once the catalog has some.
    static func available(for garments: [Garment]) -> [ClosetCategory] {
        allCases.filter { $0 != .shoes || garments.contains { $0.category == .shoes } }
    }
}

/// One closet item: its photo in a sunken frame, with Find it and Save buttons in the corner,
/// then its name and category underneath.
private struct GarmentCard: View {
    let garment: Garment
    let session: TryOnSession
    let onFindIt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { photo }
                .overlay(alignment: .topTrailing) { cornerButtons }
                .overlay(alignment: .topLeading) {
                    if session.isInFittingRoom(garment) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Win95.navy)
                            .padding(4)
                            .accessibilityLabel("In your outfit")
                    }
                }
                .win95Sunken()

            VStack(alignment: .leading, spacing: 2) {
                Text(garment.name)
                    .font(Win95.font(14, bold: true))
                    .foregroundStyle(Win95.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(categoryName)
                    .font(Win95.font(12))
                    .foregroundStyle(Win95.secondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let image = ProductPhoto.named(garment.imageName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(12)
                .accessibilityHidden(true)
        } else {
            Image(systemName: placeholderSymbol)
                .font(.system(size: 42))
                .foregroundStyle(Win95.shadow)
                .accessibilityHidden(true)
        }
    }

    private var cornerButtons: some View {
        let isLiked = session.isLiked(garment)
        return HStack(spacing: 0) {
            Button(action: onFindIt) {
                Win95IconLabel(systemImage: "bag")
            }
            .buttonStyle(Win95ButtonStyle())
            .accessibilityLabel("Find \(garment.name) second-hand")
            Button {
                if isLiked {
                    session.unlike(garment)
                } else {
                    session.like(garment)
                }
            } label: {
                if isLiked {
                    Win95Heart(pixel: 1.3).frame(width: 30, height: 28)
                } else {
                    Win95IconLabel(systemImage: "heart")
                }
            }
            .buttonStyle(Win95ButtonStyle())
            .accessibilityLabel(isLiked ? "Remove \(garment.name) from saved items" : "Save \(garment.name)")
        }
        .padding(4)
    }

    private var categoryName: String {
        switch garment.category {
        case .eyewear, .headwear: "Head"
        case .top: "Top"
        case .bottom: "Bottom"
        case .fullLook: "Look"
        case .shoes: "Shoes"
        }
    }

    private var placeholderSymbol: String {
        switch garment.category {
        case .eyewear: "eyeglasses"
        case .headwear: "person.crop.circle"
        case .top: "tshirt"
        case .bottom: "figure.walk"
        case .fullLook: "sparkles"
        case .shoes: "shoe"
        }
    }
}
