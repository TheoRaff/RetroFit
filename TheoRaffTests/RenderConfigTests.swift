import Foundation
import Testing
@testable import TheoRaff

struct RenderConfigTests {
    @Test func readsHostAndToken() throws {
        let config = try RenderConfig.fromInfoDictionary([
            "RenderHost": "theoraff-render.vercel.app",
            "RenderAPIToken": " secret ",
        ])
        #expect(config.baseURL.absoluteString == "https://theoraff-render.vercel.app")
        #expect(config.token == "secret")
    }

    @Test(arguments: [nil, "", "  ", "$(RENDER_HOST)"] as [String?])
    func needsAHost(host: String?) {
        let info: [String: Any] = ["RenderHost": host as Any, "RenderAPIToken": "secret"]
        #expect(throws: RenderError.missingConfig("RenderHost")) {
            try RenderConfig.fromInfoDictionary(info)
        }
    }

    @Test(arguments: [nil, "", "$(RENDER_API_TOKEN)", "PASTE_APP_TOKEN_HERE"] as [String?])
    func needsARealToken(token: String?) {
        let info: [String: Any] = ["RenderHost": "theoraff-render.vercel.app", "RenderAPIToken": token as Any]
        #expect(throws: RenderError.missingConfig("RenderAPIToken")) {
            try RenderConfig.fromInfoDictionary(info)
        }
    }

    @Test func handlesAMissingInfoDictionary() {
        #expect(throws: RenderError.missingConfig("RenderHost")) {
            try RenderConfig.fromInfoDictionary(nil)
        }
    }
}
