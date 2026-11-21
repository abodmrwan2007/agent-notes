import AgentNotesCore
import XCTest

final class PageLinkTests: XCTestCase {
    func testPageLinkRoundTrip() {
        let id = UUID()
        let link = PageLink.page(id)
        XCTAssertEqual(PageLink(rawValue: link.rawValue), link)
        XCTAssertNil(PageLink(rawValue: "page:not-a-uuid"))
    }

    func testWebAddresses() {
        XCTAssertEqual(PageLink.webURL(from: "en.wikipedia.org/wiki/Heart")?.absoluteString, "https://en.wikipedia.org/wiki/Heart")
        XCTAssertEqual(PageLink.webURL(from: " http://example.com ")?.absoluteString, "http://example.com")
        XCTAssertNil(PageLink.webURL(from: "javascript:alert(1)"))
        XCTAssertNil(PageLink.webURL(from: "file:///etc/passwd"))
        XCTAssertNil(PageLink.webURL(from: "not a url"))
        XCTAssertNil(PageLink.webURL(from: "localhost"))
    }

    func testObjectsKeepLinksAndOldFilesStillDecode() throws {
        let object = PageObject(kind: .text, frame: PageRect(x: 0, y: 0, width: 10, height: 10), text: "Go", link: "https://example.com")
        let decoded = try JSONDecoder().decode(PageObject.self, from: JSONEncoder().encode(object))
        XCTAssertEqual(decoded.pageLink, .web(URL(string: "https://example.com")!))

        // An object written before links existed has no "link" key.
        let old = try JSONSerialization.data(withJSONObject: [
            "id": UUID().uuidString, "kind": "text", "rotation": 0, "isLocked": false,
            "frame": ["x": 0, "y": 0, "width": 10, "height": 10]
        ])
        XCTAssertNil(try JSONDecoder().decode(PageObject.self, from: old).link)
    }
}
