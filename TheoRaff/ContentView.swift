import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("TheoRaff")
                .font(.title)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
