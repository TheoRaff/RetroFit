import SwiftUI

/// The "Buffering…" bar shown while the AI render runs.
struct BufferingBar: View {
    let text: String

    @State private var sweep = false

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let width = proxy.size.width
                Capsule()
                    .fill(.white.opacity(0.25))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [.white.opacity(0.2), .white, .white.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: width * 0.35)
                            .offset(x: sweep ? width * 0.65 : 0)
                    }
                    .clipShape(Capsule())
            }
            .frame(height: 12)

            Text(text)
                .font(.headline.monospaced())
                .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                sweep = true
            }
        }
        .accessibilityElement(children: .combine)
    }
}
