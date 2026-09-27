import XCTest

final class FootballFlowUITests: XCTestCase {
    func testPrepareSquadPlayRoundReadStandingsAndOpenMarket() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Treinador, sua jornada começa aqui."].waitForExistence(timeout: 10))

        app.buttons["Mercado"].tap()
        XCTAssertTrue(app.staticTexts["Agentes disponíveis · 8"].waitForExistence(timeout: 5))
        let signing = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "sign-FA-1-")).firstMatch
        XCTAssertTrue(signing.waitForExistence(timeout: 5))
        signing.tap()
        XCTAssertTrue(app.staticTexts["17/18"].waitForExistence(timeout: 5))

        app.buttons["Painel"].tap()
        let simulate = app.buttons["simulate-round"]
        XCTAssertTrue(simulate.waitForExistence(timeout: 5))
        simulate.tap()

        XCTAssertTrue(app.staticTexts["Resumo da rodada"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Todos os resultados"].exists)
        XCTAssertTrue(app.staticTexts.matching(identifier: "match-report-stats").firstMatch.exists)
        app.buttons["close-match-report"].tap()

        app.buttons["Tabela"].tap()
        XCTAssertTrue(app.staticTexts["Classificação"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Resultados da última rodada"].exists)
        XCTAssertTrue(app.staticTexts["Aurora FC"].exists)

        app.buttons["Elenco"].tap()
        XCTAssertTrue(app.buttons["auto-lineup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["11/11 titulares"].exists)
    }
}
