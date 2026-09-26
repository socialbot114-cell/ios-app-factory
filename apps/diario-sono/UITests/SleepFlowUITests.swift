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
        XCTAssertTrue(app.staticTexts["Como você se sente?"].waitForExistence(timeout: 10))
        let save = app.buttons["Salvar"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.staticTexts["Última avaliação"].exists)
    }
}
