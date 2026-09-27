import XCTest

final class CrimeIdleFlowUITests: XCTestCase {
    func testTapAndOpenBusinessDistricts() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["A noite é sua."].waitForExistence(timeout: 10))
        let tap = app.buttons["Expandir influência"]
        XCTAssertTrue(tap.waitForExistence(timeout: 5))
        tap.tap()
        XCTAssertTrue(app.staticTexts["101"].waitForExistence(timeout: 5))
        app.buttons["Mapa"].tap()
        XCTAssertTrue(app.staticTexts["Distritos"].waitForExistence(timeout: 5))
    }

    func testActivitiesAndAchievementsAreReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["A noite é sua."].waitForExistence(timeout: 10))
        app.buttons["Ações"].tap()
        XCTAssertTrue(app.staticTexts["Preparar a Noite das Lanternas"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Conquistas"].exists)
        XCTAssertTrue(app.buttons["Iniciar"].firstMatch.exists)
    }
}
