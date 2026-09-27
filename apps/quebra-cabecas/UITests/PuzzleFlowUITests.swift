import XCTest

final class PuzzleFlowUITests: XCTestCase {
    func testMoveLegalTileAndStartAnotherPuzzle() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Quebra-Cabeças"].waitForExistence(timeout: 10))
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND enabled == true", "Peça")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        XCTAssertTrue(app.staticTexts["1 movimento"].waitForExistence(timeout: 5))
        app.buttons["Nova partida"].tap()
        // Há progresso: confirma o descarte.
        let confirm = app.buttons["Começar nova partida"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["0 movimentos"].waitForExistence(timeout: 5))
    }

    func testHintUndoGoalAndDailyControlsExist() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Quebra-Cabeças"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["undo-button"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hint-button"].exists)
        XCTAssertTrue(app.buttons["goal-button"].exists)
        XCTAssertTrue(app.buttons["daily-button"].exists)
        XCTAssertTrue(app.buttons["restart-button"].exists)

        // Dica habilita o Desfazer após um movimento.
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND enabled == true", "Peça")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        app.buttons["hint-button"].tap()
        tile.tap()
        XCTAssertTrue(app.staticTexts["1 movimento"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["undo-button"].isEnabled)
        app.buttons["undo-button"].tap()
        XCTAssertTrue(app.staticTexts["0 movimentos"].waitForExistence(timeout: 5))

        // Sheet de objetivo abre e fecha.
        app.buttons["goal-button"].tap()
        XCTAssertTrue(app.navigationBars["Objetivo"].waitForExistence(timeout: 5))
        app.buttons["Fechar"].tap()
    }

    func testDifficultyDailyAndMosaicMode() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Quebra-Cabeças"].waitForExistence(timeout: 10))
        // Níveis de dificuldade visíveis.
        XCTAssertTrue(app.buttons["Fácil"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Difícil"].exists)
        // Desafio diário: sem progresso, começa direto e marca o selo.
        app.buttons["daily-button"].tap()
        XCTAssertTrue(app.staticTexts["Desafio de hoje"].waitForExistence(timeout: 5))
        // Modo mosaico mantém o tabuleiro jogável.
        app.buttons["Mosaico"].tap()
        XCTAssertTrue(app.otherElements["puzzle-board"].waitForExistence(timeout: 5))
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND enabled == true", "Peça")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
    }
}
