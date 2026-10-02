import XCTest
@testable import LeitorPdfBolso

final class PDFProgressTests: XCTestCase {
    func testPageIsClampedToDocumentBounds() {
        XCTAssertEqual(PDFProgress(page: -2, pageCount: 9).safePage, 0)
        XCTAssertEqual(PDFProgress(page: 15, pageCount: 9).safePage, 8)
        XCTAssertEqual(PDFProgress(page: 4, pageCount: 9).safePage, 4)
    }

    func testZeroPageDocumentHasSafeStartingPage() {
        XCTAssertEqual(PDFProgress(page: 2, pageCount: 0).safePage, 0)
    }

    func testSearchCursorMovesWithoutWrappingPastTheFirstOrLastResult() {
        var cursor = PDFSearchCursor()
        cursor.reset(resultCount: 2)
        XCTAssertEqual(cursor.currentPosition, 1)
        XCTAssertFalse(cursor.canMovePrevious)
        XCTAssertTrue(cursor.canMoveNext)
        XCTAssertNil(cursor.previous())
        XCTAssertEqual(cursor.next(), 1)
        XCTAssertEqual(cursor.currentPosition, 2)
        XCTAssertFalse(cursor.canMoveNext)
        XCTAssertNil(cursor.next())
        XCTAssertEqual(cursor.previous(), 0)
        XCTAssertEqual(cursor.currentPosition, 1)

        cursor.reset(resultCount: 0)
        XCTAssertNil(cursor.currentPosition)
        XCTAssertFalse(cursor.canMoveNext)
        XCTAssertFalse(cursor.canMovePrevious)
    }
}
