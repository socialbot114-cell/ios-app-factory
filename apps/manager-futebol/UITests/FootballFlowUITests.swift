import XCTest

final class FootballFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testPlayLiveMatchAndReadLeague() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Escolha seu clube"].waitForExistence(timeout: 10))
        tapWhenReady(app.buttons["choose-club-0"], in: app)
        XCTAssertTrue(app.buttons["play-match"].waitForExistence(timeout: 10))

        app.buttons["tab-1"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "squad-pitch").firstMatch.waitForExistence(timeout: 5))
        let intensity = app.segmentedControls["training-intensity-picker"]
        XCTAssertTrue(intensity.waitForExistence(timeout: 5))
        scrollUntilHittable(intensity, in: app)
        intensity.buttons["Intensa"].tap()

        app.buttons["tab-0"].tap()
        tapWhenReady(app.buttons["play-match"], in: app)

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "live-scoreboard").firstMatch.waitForExistence(timeout: 10))
        let secondHalf = app.buttons["live-second-half"]
        XCTAssertTrue(secondHalf.waitForExistence(timeout: 20))
        tapWhenReady(secondHalf, in: app)
        let finish = app.buttons["live-finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 20))
        tapWhenReady(finish, in: app)

        let training = app.descendants(matching: .any).matching(identifier: "football-training-report").firstMatch
        XCTAssertTrue(training.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "match-report-shots").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "match-report-possession").firstMatch.exists)

        app.buttons["tab-2"].tap()
        XCTAssertTrue(app.staticTexts["Classificação"].waitForExistence(timeout: 5))
        let auroraRow = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Aurora FC")).firstMatch
        XCTAssertTrue(auroraRow.waitForExistence(timeout: 5))

        app.buttons["tab-4"].tap()
        XCTAssertTrue(app.buttons["new-career"].waitForExistence(timeout: 5))
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !element.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
    }

    private func tapWhenReady(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        scrollUntilHittable(element, in: app)
        element.tap()
    }
}
