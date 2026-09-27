import XCTest

final class FootballFlowUITests: XCTestCase {
    func testSimulateRoundAndReadStandings() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Escolha seu clube"].waitForExistence(timeout: 10))
        let chooseClub = app.buttons["choose-club-0"]
        XCTAssertTrue(chooseClub.waitForExistence(timeout: 5))
        chooseClub.tap()
        XCTAssertTrue(app.staticTexts["Treinador, sua jornada começa aqui."].waitForExistence(timeout: 10))
        app.buttons["tab-2"].tap()
        XCTAssertTrue(app.staticTexts["Um plano sem grandes riscos, com energia preservada."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Treino semanal"].exists)
        let intensity = app.segmentedControls["training-intensity-picker"]
        if !intensity.isHittable { app.swipeUp() }
        intensity.buttons["Intensa"].tap()
        app.buttons["tab-0"].tap()
        let simulate = app.buttons["simulate-round"]
        XCTAssertTrue(simulate.waitForExistence(timeout: 5))
        simulate.tap()
        let training = app.descendants(matching: .any).matching(identifier: "football-training-report").firstMatch
        XCTAssertTrue(training.waitForExistence(timeout: 5))
        let shots = app.descendants(matching: .any).matching(identifier: "match-report-shots").firstMatch
        let possession = app.descendants(matching: .any).matching(identifier: "match-report-possession").firstMatch
        XCTAssertTrue(shots.waitForExistence(timeout: 5))
        XCTAssertTrue(possession.exists)
        app.buttons["tab-1"].tap()
        XCTAssertTrue(app.staticTexts["Classificação"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Aurora FC"].exists)
        XCTAssertTrue(app.staticTexts["Resultados registrados"].exists)
    }
}
