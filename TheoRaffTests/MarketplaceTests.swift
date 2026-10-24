import Foundation
import Testing
@testable import TheoRaff

struct MarketplaceTests {
    @Test(arguments: [
        (Marketplace.depop, "https://www.depop.com/search/?q=y2k%20velour%20hoodie"),
        (.vinted, "https://www.vinted.co.uk/catalog?search_text=y2k%20velour%20hoodie"),
        (.ebay, "https://www.ebay.co.uk/sch/i.html?_nkw=y2k%20velour%20hoodie"),
    ])
    func searchesForTheQuery(marketplace: Marketplace, expected: String) {
        #expect(marketplace.searchURL(for: "y2k velour hoodie")?.absoluteString == expected)
    }

    @Test(arguments: Marketplace.allCases)
    func keepsSymbolsInsideTheSearch(marketplace: Marketplace) throws {
        let query = "cami & mini + belt"
        let url = try #require(marketplace.searchURL(for: query))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(items?.count == 1)
        #expect(items?.first?.value == query)
        // The shops read a bare "+" as a space.
        #expect(url.query(percentEncoded: true)?.contains("+") == false)
    }

    @Test func trimsTheQuery() {
        #expect(Marketplace.ebay.searchURL(for: "  baby tee\n")?.absoluteString == "https://www.ebay.co.uk/sch/i.html?_nkw=baby%20tee")
    }

    @Test func listsTheShopsInButtonOrder() {
        #expect(Marketplace.allCases.map(\.name) == ["Depop", "Vinted", "eBay"])
    }
}
