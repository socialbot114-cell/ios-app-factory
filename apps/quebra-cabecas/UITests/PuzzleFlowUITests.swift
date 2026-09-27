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

        let newGame = app.buttons["Nova partida"]
        newGame.tap()
        let discard = app.buttons["Descartar e iniciar"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        app.buttons["Continuar partida"].tap()
        XCTAssertTrue(app.staticTexts["1 movimento"].exists)

        newGame.tap()
        discard.tap()
        XCTAssertTrue(app.staticTexts["0 movimentos"].waitForExistence(timeout: 5))
    }

    func testChooseOriginalImagePuzzleAndMoveTile() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Quebra-Cabeças"].waitForExistence(timeout: 10))

        let imageMode = app.segmentedControls["puzzle-mode-picker"].buttons["Imagem"]
        XCTAssertTrue(imageMode.waitForExistence(timeout: 5))
        if !imageMode.isHittable { app.swipeUp() }
        imageMode.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Serra ao amanhecer")).firstMatch.waitForExistence(timeout: 5))

        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND enabled == true", "Peça de imagem")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        if !tile.isHittable { app.swipeDown() }
        tile.tap()
        XCTAssertTrue(app.staticTexts["1 movimento"].waitForExistence(timeout: 5))
    }
}
