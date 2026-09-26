import XCTest

final class PuzzleFlowUITests: XCTestCase {
    func testMoveLegalTileAndStartAnotherPuzzle() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Encontre o seu ritmo."].waitForExistence(timeout: 10))
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND enabled == true", "Peça")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        XCTAssertTrue(app.staticTexts["1 movimento"].waitForExistence(timeout: 5))
        app.buttons["Nova partida"].tap()
        XCTAssertTrue(app.buttons["Nova partida"].exists)
    }
}
