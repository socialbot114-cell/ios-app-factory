import XCTest

final class PDFReaderFlowUITests: XCTestCase {
    func testOpenLocalDemoDocumentAndSearch() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Sua biblioteca."].waitForExistence(timeout: 10))
        let sample = app.descendants(matching: .any)["pdf-document-Guia de leitura demonstrativo"]
        XCTAssertTrue(sample.waitForExistence(timeout: 8))
        sample.tap()
        XCTAssertTrue(app.buttons["Buscar"].waitForExistence(timeout: 5))
        app.textFields["Buscar no documento"].tap()
        app.textFields["Buscar no documento"].typeText("biblioteca")
        app.buttons["Buscar"].tap()
        XCTAssertTrue(app.staticTexts["2 resultados · 1 de 2"].waitForExistence(timeout: 5))
        app.buttons["pdf-search-next"].tap()
        XCTAssertTrue(app.staticTexts["2 resultados · 2 de 2"].waitForExistence(timeout: 5))
        app.buttons["pdf-search-previous"].tap()
        XCTAssertTrue(app.staticTexts["2 resultados · 1 de 2"].waitForExistence(timeout: 5))
    }
}
