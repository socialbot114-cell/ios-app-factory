import XCTest

final class DetectiveFlowUITests: XCTestCase {
    func testStartRoundAndScoreCard() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["O que está na minha testa?"].waitForExistence(timeout: 10))
        let play = app.buttons["Jogar agora"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        XCTAssertTrue(app.buttons["Acertou"].waitForExistence(timeout: 5))
        app.buttons["Acertou"].tap()
        XCTAssertTrue(app.staticTexts["1 acertos  ·  0 pulos"].waitForExistence(timeout: 5))
    }

    func testChooseThemeAndStartThemedRound() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["O que está na minha testa?"].waitForExistence(timeout: 10))

        let categoryMenu = app.buttons["detective-category-menu"]
        XCTAssertTrue(categoryMenu.waitForExistence(timeout: 5))
        if !categoryMenu.isHittable { app.swipeUp() }
        categoryMenu.tap()
        let animals = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Animais")).firstMatch
        XCTAssertTrue(animals.waitForExistence(timeout: 5))
        animals.tap()

        let play = app.buttons["Jogar agora"]
        if !play.isHittable { app.swipeDown() }
        play.tap()
        XCTAssertTrue(app.staticTexts["ANIMAIS"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Acertou"].exists)
    }
}
