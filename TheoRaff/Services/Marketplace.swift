import Foundation

/// The second-hand shops behind the "Find it" buttons. Searches go to the UK sites.
enum Marketplace: CaseIterable, Identifiable, Sendable {
    case depop
    case vinted
    case ebay

    var id: Self { self }

    var name: String {
        switch self {
        case .depop: "Depop"
        case .vinted: "Vinted"
        case .ebay: "eBay"
        }
    }

    /// The shop's search results for `query`, such as a garment's `searchQuery`.
    func searchURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = search.host
        components.path = search.path
        components.queryItems = [
            URLQueryItem(name: search.queryName, value: query.trimmingCharacters(in: .whitespacesAndNewlines)),
        ]
        // URLComponents leaves "+" alone, and the shops would read it as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }

    private var search: (host: String, path: String, queryName: String) {
        switch self {
        case .depop: ("www.depop.com", "/search/", "q")
        case .vinted: ("www.vinted.co.uk", "/catalog", "search_text")
        case .ebay: ("www.ebay.co.uk", "/sch/i.html", "_nkw")
        }
    }
}
