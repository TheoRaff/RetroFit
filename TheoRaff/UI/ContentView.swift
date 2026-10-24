import SwiftUI

struct ContentView: View {
    @State private var selectedGlasses = "Y2K_Sport_Sunglass"

    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(modelName: selectedGlasses)
                .ignoresSafeArea()

            HStack(spacing: 12) {
                styleButton(title: "Sport", modelName: "Y2K_Sport_Sunglass")
                styleButton(title: "White", modelName: "White_sunglasses")
            }
            .padding(10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 30)
        }
    }

    private func styleButton(title: String, modelName: String) -> some View {
        Button {
            selectedGlasses = modelName
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(selectedGlasses == modelName ? .white : .primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background {
                    if selectedGlasses == modelName {
                        Capsule().fill(Color.blue)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
