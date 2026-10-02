import XCTest

final class CrimeIdleFlowUITests: XCTestCase {
    func testStreetHustleRacketHeistCrewAndMap() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        let tap = app.buttons["tap-street"]
        XCTAssertTrue(tap.waitForExistence(timeout: 10))
        for _ in 0..<3 { tap.tap() }

        app.buttons["tab-Negócios"].tap()
        let buy = app.buttons["buy-racket-0"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        XCTAssertTrue(buy.isEnabled)
        buy.tap()
        let run = app.buttons["run-racket-0"]
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        XCTAssertFalse(app.buttons["buy-racket-2"].exists, "Negócios de bairros fechados ficam ocultos")

        app.buttons["tab-Golpes"].tap()
        let start = app.buttons["start-heist-0"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.buttons["plan-stealth"].tap()
        start.tap()
        XCTAssertTrue(app.staticTexts["heist-active"].waitForExistence(timeout: 5))
        XCTAssertFalse(start.isEnabled, "Só um golpe por vez")

        app.buttons["tab-Família"].tap()
        XCTAssertTrue(app.staticTexts["Dona Zica"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["crew-0"].isEnabled, "Recrutar exige respeito")

        app.buttons["tab-Mapa"].tap()
        XCTAssertTrue(app.staticTexts["Porto Velho"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["conquer-1"].isEnabled)

        app.buttons["tab-Golpes"].tap()
        let reveal = app.buttons["reveal-heist"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 30))
        reveal.tap()
        XCTAssertTrue(app.staticTexts["heist-outcome"].waitForExistence(timeout: 5))
        app.buttons["dismiss-outcome"].tap()
        XCTAssertTrue(app.buttons["start-heist-0"].waitForExistence(timeout: 5))
    }
}
