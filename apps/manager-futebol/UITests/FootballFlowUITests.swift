import XCTest

final class FootballFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testPlayLiveMatchAndReadLeague() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Seu primeiro contrato"].waitForExistence(timeout: 10))
        let offer = app.buttons["choose-offer-0"]
        tapWhenReady(offer, in: app)
        if !app.buttons["dock-manager"].waitForExistence(timeout: 6), offer.exists {
            attachScreenshot(app, name: "after-first-offer-tap")
            offer.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
        }
        if !app.buttons["dock-manager"].waitForExistence(timeout: 10) {
            attachScreenshot(app, name: "home-screen-missing")
            XCTFail("A tela inicial do celular não abriu após aceitar a proposta. Hierarquia:\n\(app.debugDescription)")
        }
        XCTAssertTrue(app.buttons["phone-search"].exists)
        XCTAssertTrue(app.buttons["phone-notifications"].exists)

        app.buttons["dock-manager"].tap()
        XCTAssertTrue(app.buttons["play-match"].waitForExistence(timeout: 8))
        app.buttons["phone-home"].tap()

        tapWhenReady(app.buttons["app-squad"], in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "squad-pitch").firstMatch.waitForExistence(timeout: 5))
        let intensity = app.segmentedControls["training-intensity-picker"]
        XCTAssertTrue(intensity.waitForExistence(timeout: 5))
        scrollUntilHittable(intensity, in: app)
        intensity.buttons["Intensa"].tap()
        app.buttons["phone-home"].tap()

        app.buttons["dock-manager"].tap()
        tapWhenReady(app.buttons["play-match"], in: app)

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "live-scoreboard").firstMatch.waitForExistence(timeout: 10))
        let skip = app.buttons["live-skip"]
        tapWhenReady(skip, in: app)
        let finish = app.buttons["live-finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 20))
        tapWhenReady(finish, in: app)
        let skipPress = app.buttons["press-skip"]
        if skipPress.waitForExistence(timeout: 5) { skipPress.tap() }

        let training = app.descendants(matching: .any).matching(identifier: "football-training-report").firstMatch
        XCTAssertTrue(training.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "match-report-shots").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "match-report-possession").firstMatch.exists)
        app.buttons["phone-home"].tap()

        tapWhenReady(app.buttons["app-league"], in: app)
        XCTAssertTrue(app.staticTexts["Classificação"].waitForExistence(timeout: 5))
        let auroraRow = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Aurora FC")).firstMatch
        XCTAssertTrue(auroraRow.waitForExistence(timeout: 5))
        app.buttons["phone-home"].tap()

        tapWhenReady(app.buttons["app-contacts"], in: app)
        XCTAssertTrue(app.buttons["contact-family"].waitForExistence(timeout: 6))
        app.buttons["phone-home"].tap()

        tapWhenReady(app.buttons["app-betting"], in: app)
        XCTAssertTrue(app.staticTexts["Palpite+"].waitForExistence(timeout: 6))
        app.buttons["phone-home"].tap()

        app.buttons["dock-club"].tap()
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
