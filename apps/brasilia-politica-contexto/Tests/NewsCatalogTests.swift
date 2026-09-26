import XCTest
@testable import BrasiliaPolitica

final class NewsCatalogTests: XCTestCase {
    func testSearchFindsTitleAndBodyCaseInsensitively() {
        XCTAssertEqual(DemoNewsCatalog.search("LEI").first?.id, "01")
        XCTAssertTrue(DemoNewsCatalog.search("servidor").isEmpty)
        XCTAssertEqual(DemoNewsCatalog.search("").count, DemoArticle.all.count)
    }
}
