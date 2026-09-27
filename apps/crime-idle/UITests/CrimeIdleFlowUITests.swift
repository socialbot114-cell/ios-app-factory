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
        app.buttons["Negócios"].tap()
        let quantity = app.segmentedControls["business-buy-quantity"]
        XCTAssertTrue(quantity.waitForExistence(timeout: 5))
        quantity.buttons["×10"].tap()
        let districtLockedBusiness = app.buttons["buy-business-2"]
        XCTAssertTrue(districtLockedBusiness.waitForExistence(timeout: 5))
        XCTAssertFalse(districtLockedBusiness.isEnabled)
        app.buttons["Mapa"].tap()
        XCTAssertTrue(app.staticTexts["Distritos"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Multiplicador da cidade:")).firstMatch.exists)
    }
}
