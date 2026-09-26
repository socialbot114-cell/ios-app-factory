import XCTest

final class FootballFlowUITests: XCTestCase {
    func testSimulateRoundAndReadStandings() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Treinador, sua jornada começa aqui."].waitForExistence(timeout: 10))
        let simulate = app.buttons["simulate-round"]
        XCTAssertTrue(simulate.waitForExistence(timeout: 5))
        simulate.tap()
        app.buttons["Tabela"].tap()
        XCTAssertTrue(app.staticTexts["Classificação"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Aurora FC"].exists)
    }
}
