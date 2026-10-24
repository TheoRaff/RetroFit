import SwiftUI

@main
struct TheoRaffApp: App {
    @State private var session = TryOnSession(outfits: SampleCatalog.outfits())

    var body: some Scene {
        WindowGroup {
            AppShellView(session: session)
        }
    }
}
