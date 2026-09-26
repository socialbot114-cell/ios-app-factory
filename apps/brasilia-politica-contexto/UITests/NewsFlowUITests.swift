import XCTest

final class NewsFlowUITests: XCTestCase {
    func testOpenAndSaveDemoArticle() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Brasília em contexto."].waitForExistence(timeout: 10))
        let article = app.staticTexts["Como funciona uma lei distrital?"]
        XCTAssertTrue(article.waitForExistence(timeout: 5))
        article.tap()
        XCTAssertTrue(app.staticTexts["CONTEÚDO FICTÍCIO · PARA AVALIAÇÃO DA INTERFACE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Como funciona uma lei distrital?"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        let save = app.buttons["Salvar matéria"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        app.buttons["Ver conteúdo salvo"].tap()
        XCTAssertTrue(app.staticTexts["Leitura salva"].waitForExistence(timeout: 5))
    }
}
