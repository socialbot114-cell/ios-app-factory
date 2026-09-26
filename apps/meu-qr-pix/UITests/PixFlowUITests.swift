import XCTest

final class PixFlowUITests: XCTestCase {
    func testGenerateStaticCodeAndCopyPayload() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Crie seu QR Pix."].waitForExistence(timeout: 10))
        app.buttons["Gerar QR estático"].tap()
        XCTAssertTrue(app.buttons["Copiar código Pix"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Confira antes de compartilhar."].exists)
        app.buttons["Copiar código Pix"].tap()
        XCTAssertTrue(app.buttons["Código copiado"].waitForExistence(timeout: 5))
    }
}
