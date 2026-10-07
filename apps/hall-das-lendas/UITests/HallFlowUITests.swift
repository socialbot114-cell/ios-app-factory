import XCTest

final class HallFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        return app
    }

    func testShowcaseCollectionAndShopTabsOpen() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["HALL DAS LENDAS"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["showcase-progress"].exists)
        app.tabBars.buttons["Coleção"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["collection-progress"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Loja"].tap()
        XCTAssertTrue(app.buttons["restore-purchases"].waitForExistence(timeout: 5))
    }

    func testBuyingACardInTheShopUnlocksItAndShowsCelebration() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["HALL DAS LENDAS"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Loja"].tap()
        let buy = app.buttons["buy-garrincha"]
        XCTAssertTrue(buy.waitForExistence(timeout: 8))
        buy.tap()
        XCTAssertTrue(app.descendants(matching: .any)["celebration-layer"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["celebration-layer"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["owned-garrincha"].waitForExistence(timeout: 5))
    }

    func testDailyPackOpensAndRevealsACard() {
        let app = launch()
        let banner = app.buttons["daily-pack-banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        banner.tap()
        let pack = app.descendants(matching: .any)["pack-open"]
        XCTAssertTrue(pack.waitForExistence(timeout: 5))
        pack.tap()
        XCTAssertTrue(app.buttons["pack-continue"].waitForExistence(timeout: 8))
        app.buttons["pack-continue"].tap()
        XCTAssertTrue(app.staticTexts["HALL DAS LENDAS"].waitForExistence(timeout: 5))
    }
}
