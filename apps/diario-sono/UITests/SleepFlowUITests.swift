import XCTest

final class SleepFlowUITests: XCTestCase {
    func testStartSessionAndOpenReviewControls() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Desacelere."].waitForExistence(timeout: 10))
        app.buttons["Iniciar registro manual"].tap()
        let finish = app.buttons["Acordei — finalizar"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        XCTAssertTrue(app.navigationBars["Ao acordar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Salvar"].exists)
        app.buttons["Salvar"].tap()
        XCTAssertTrue(app.staticTexts["Última avaliação"].exists)
    }
}
