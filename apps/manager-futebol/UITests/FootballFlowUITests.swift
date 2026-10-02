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
        let club = app.buttons["choose-club-0"]
        tapWhenReady(club, in: app)
        if !app.buttons["play-match"].waitForExistence(timeout: 6), club.exists {
            attachScreenshot(app, name: "after-first-club-tap")
            club.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
        }
        if !app.buttons["play-match"].waitForExistence(timeout: 10) {
            attachScreenshot(app, name: "dashboard-missing")
            XCTFail("O painel não abriu após escolher o clube. Hierarquia:\n\(app.debugDescription)")
        }

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
        let newCareer = app.descendants(matching: .any).matching(identifier: "new-career").firstMatch
        XCTAssertTrue(newCareer.waitForExistence(timeout: 8))
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
