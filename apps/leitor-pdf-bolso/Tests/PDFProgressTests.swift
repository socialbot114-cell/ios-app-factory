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
}
