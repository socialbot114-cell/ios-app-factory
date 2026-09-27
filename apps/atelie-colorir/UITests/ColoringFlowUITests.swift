import XCTest

final class ColoringFlowUITests: XCTestCase {
    func testOpenEditorAndColorArtwork() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Um momento só seu."].waitForExistence(timeout: 10))
        let start = app.buttons["Começar a colorir"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        app.buttons["palette-color-0"].tap()
        app.buttons["color-region-0"].tap()
        XCTAssertTrue(app.buttons["Desfazer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Salvar e compartilhar PNG"].exists)
    }

    func testLibraryShowsTwelveArtworks() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Um momento só seu."].waitForExistence(timeout: 10))
        app.buttons["Explorar as 12 artes"].tap()
        XCTAssertTrue(app.staticTexts["O que vamos colorir?"].waitForExistence(timeout: 5))
        // A grade é preguiçosa: usa a busca para trazer o item para a tela.
        let search = app.textFields["Buscar arte"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("noite")
        XCTAssertTrue(app.staticTexts["Mandala da noite"].waitForExistence(timeout: 5))
        app.buttons["Limpar busca"].tap()
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Vitral do Planalto"].waitForExistence(timeout: 5))
    }

    func testGalleryOpensFromHome() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Um momento só seu."].waitForExistence(timeout: 10))
        app.buttons["Abrir minhas artes"].tap()
        XCTAssertTrue(app.staticTexts["Minhas artes"].waitForExistence(timeout: 5))
    }
}
