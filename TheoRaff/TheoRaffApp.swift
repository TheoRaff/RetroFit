import SwiftUI

@main
struct TheoRaffApp: App {
    @State private var session = TryOnSession(outfits: Catalog.bundled.liveLooks)

    var body: some Scene {
        WindowGroup {
            AppShellView(session: session)
        }
    }
}
