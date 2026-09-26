import XCTest

final class ColoringFlowUITests: XCTestCase {
    func testOpenEditorAndColorArtwork() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Um momento só seu."].waitForExistence(timeout: 10))
        let start = app.buttons["Começar a colorir"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        app.buttons["palette-color-0"].tap()
        app.buttons["color-region-0"].tap()
        XCTAssertTrue(app.buttons["Desfazer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Salvar e compartilhar PNG"].exists)
    }
}
