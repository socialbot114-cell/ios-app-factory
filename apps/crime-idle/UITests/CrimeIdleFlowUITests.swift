import XCTest

final class CrimeIdleFlowUITests: XCTestCase {
    func testTapAndOpenBusinessDistricts() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["A noite é sua."].waitForExistence(timeout: 10))
        let tap = app.buttons["Atrair público · +1 caixa"]
        XCTAssertTrue(tap.waitForExistence(timeout: 5))
        tap.tap()
        XCTAssertTrue(app.staticTexts["101"].waitForExistence(timeout: 5))
        app.buttons["Mapa"].tap()
        XCTAssertTrue(app.staticTexts["Distritos"].waitForExistence(timeout: 5))
    }

    func testProjectsAndAchievementsAreReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["A noite é sua."].waitForExistence(timeout: 10))
        app.buttons["Projetos"].tap()
        XCTAssertTrue(app.staticTexts["Noite das Lanternas"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Conquistas"].exists)
        XCTAssertTrue(app.buttons["Investir e realizar"].firstMatch.exists)
    }

    func testFirstBusinessUnlocksNarrativeChoice() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["A noite é sua."].waitForExistence(timeout: 10))
        app.buttons["Negócios"].tap()
        app.buttons["Comprar Café Aurora"].tap()
        app.buttons["História"].tap()
        XCTAssertTrue(app.staticTexts["A primeira luz"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Festival das Lanternas"].exists)
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Escolher")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["A cidade comenta"].waitForExistence(timeout: 5))
    }
}
