import Foundation

/// Where the render function lives, and the token it expects in `x-app-token`.
///
/// Info.plist reads both from build settings: `RENDER_HOST` is set in Config/Shared.xcconfig,
/// and `RENDER_API_TOKEN` in each person's gitignored Config/Local.xcconfig.
struct RenderConfig: Equatable, Sendable {
    static let hostKey = "RenderHost"
    static let tokenKey = "RenderAPIToken"
    /// The value Local.xcconfig.example ships with, which is never a real token.
    static let tokenPlaceholder = "PASTE_APP_TOKEN_HERE"

    let baseURL: URL
    let token: String

    static func fromBundle(_ bundle: Bundle = .main) throws -> RenderConfig {
        try fromInfoDictionary(bundle.infoDictionary)
    }

    static func fromInfoDictionary(_ info: [String: Any]?) throws -> RenderConfig {
        let host = setting(info?[hostKey])
        guard let host, let url = URL(string: "https://\(host)"), url.host != nil else {
            throw RenderError.missingConfig(hostKey)
        }
        guard let token = setting(info?[tokenKey]), token != tokenPlaceholder else {
            throw RenderError.missingConfig(tokenKey)
        }
        return RenderConfig(baseURL: url, token: token)
    }

    /// A trimmed build-setting value, or nil when it's blank or was never expanded.
    private static func setting(_ value: Any?) -> String? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, !text.contains("$(") else {
            return nil
        }
        return text
    }
}
