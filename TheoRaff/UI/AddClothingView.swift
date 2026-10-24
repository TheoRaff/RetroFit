import SwiftUI

struct ClothingImportDraft: Identifiable {
    let id = UUID()
    let photo: UIImage
}

/// The library selection creates a product, with an explicit category before it is saved.
struct AddClothingView: View {
    let draft: ClothingImportDraft
    let onAdded: (Garment) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = GarmentCategory.top
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Win95TitleBar(title: "Add clothes", centred: false) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: 36, height: 32)
                }
                .buttonStyle(Win95ButtonStyle())
                .accessibilityLabel("Cancel clothing import")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Add a photo of the clothing item, ideally on a plain background.")
                        .font(Win95.font(14))
                    Image(uiImage: draft.photo)
                        .resizable().scaledToFit().frame(maxHeight: 260)
                        .frame(maxWidth: .infinity).background(.white).win95Sunken()
                        .accessibilityLabel("Clothing photo preview")
                    TextField("Clothing name", text: $name)
                        .font(Win95.font(16)).padding(12).background(.white).win95Sunken()
                        .accessibilityLabel("Clothing name")
                    Picker("Category", selection: $category) {
                        ForEach(ImportedGarmentStore.categories, id: \.self) { category in
                            Text(category.importTitle).tag(category)
                        }
                    }
                    .pickerStyle(.menu).tint(Win95.navy)
                    if let error { Text(error).font(Win95.font(14)).foregroundStyle(.red) }
                    Button(action: save) {
                        Label("Add to Closet", systemImage: "plus")
                            .font(Win95.font(16, bold: true))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(Win95ButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16)
                .foregroundStyle(Win95.text)
            }
        }
        .background(Win95.face.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    private func save() {
        do {
            let garment = try ImportedGarmentStore.shared.add(photo: draft.photo, name: name, category: category)
            onAdded(garment)
            dismiss()
        } catch {
            self.error = "Couldn't save those clothes. \(error.localizedDescription)"
        }
    }
}

private extension GarmentCategory {
    var importTitle: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bottoms"
        case .fullLook: "Full look"
        case .shoes: "Shoes"
        case .eyewear: "Glasses"
        case .headwear: "Hat"
        }
    }
}
