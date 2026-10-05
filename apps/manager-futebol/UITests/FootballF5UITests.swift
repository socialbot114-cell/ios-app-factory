import XCTest

/// Um teste curto por tela da F5: confirma que a parte nova aparece e é acessível pelo identificador.
final class FootballF5UITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Liga, Rodada e Palpite+

    func testLeagueShowsScenariosDifficultyAndHeadToHead() {
        let app = openApp("app-league")
        XCTAssertTrue(element("league-scenario-Título", in: app).waitForExistence(timeout: 8), "Cenário de título ausente")
        XCTAssertTrue(reveal(element("league-difficulty", in: app), in: app))
        XCTAssertTrue(reveal(element("league-head-to-head", in: app), in: app))
    }

    /// LIG-01..03: tabela abre a ficha do clube, rodadas navegam, jogo abre o relatório/pré-jogo.
    func testLeagueRowsOpenClubProfileMatchesAndRoundsNavigate() {
        let app = openApp("app-league")
        let clubRow = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "league-club-")).firstMatch
        XCTAssertTrue(clubRow.waitForExistence(timeout: 8))
        clubRow.tap()
        XCTAssertTrue(app.navigationBars["Ficha do clube"].waitForExistence(timeout: 5), "A linha da tabela deve abrir a ficha do clube")
        app.navigationBars.buttons.firstMatch.tap()

        let next = app.buttons["Próxima rodada"]
        XCTAssertTrue(reveal(next, in: app))
        let before = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Jogos · rodada")).firstMatch.label
        next.tap()
        let after = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Jogos · rodada")).firstMatch
        XCTAssertTrue(after.waitForExistence(timeout: 4))
        XCTAssertNotEqual(before, after.label, "Navegar para a próxima rodada deve trocar a rodada exibida")

        let match = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "league-match-")).firstMatch
        XCTAssertTrue(reveal(match, in: app))
        match.tap()
        XCTAssertTrue(app.navigationBars["Pré-jogo"].waitForExistence(timeout: 5) || app.navigationBars["Relatório"].exists)
    }

    func testFantasyShowsDeadlineAndFilters() {
        let app = openApp("app-fantasy")
        XCTAssertTrue(element("fantasy-deadline", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(reveal(element("fantasy-filter-risk", in: app), in: app))
        XCTAssertTrue(reveal(element("fantasy-filter-price", in: app), in: app))
    }

    func testBettingStatesItsOptionalRoleAndClosingTime() {
        let app = openApp("app-betting")
        let role = element("bet-role", in: app)
        XCTAssertTrue(role.waitForExistence(timeout: 8))
        XCTAssertTrue(role.label.contains("opcional"), "O papel opcional do app deve estar escrito: \(role.label)")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Fecha")).firstMatch.waitForExistence(timeout: 6)
                      || app.staticTexts["Sem jogos abertos para palpites agora. Avance o calendário."].exists)
    }

    // MARK: Metas, Troféus e Ajustes

    func testGoalsLetThePlayerChooseAndKeepHistory() {
        let app = openApp("app-quests")
        XCTAssertTrue(reveal(element("goal-adopt", in: app), in: app))
        XCTAssertTrue(reveal(element("goals-history", in: app), in: app))
    }

    func testTrophiesShowTimelineAndOpenDetail() {
        let app = openApp("app-trophies")
        XCTAssertTrue(element("career-timeline", in: app).waitForExistence(timeout: 8))
        let first = element("trophy-firstWin", in: app)
        XCTAssertTrue(reveal(first, in: app))
        first.tap()
        XCTAssertTrue(app.staticTexts["Primeira vitória"].waitForExistence(timeout: 5))
    }

    func testSettingsShowPreferencesDifficultyAndActionHistory() {
        let app = openApp("app-settings")
        XCTAssertTrue(element("difficulty-picker", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(reveal(element("settings-notification-priority", in: app), in: app))
        XCTAssertTrue(reveal(element("settings-reduce-motion", in: app), in: app))
        XCTAssertTrue(reveal(element("action-history", in: app), in: app))
    }

    // MARK: Apoio

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Rola até o elemento existir; conteúdo fora da tela pode não estar na árvore ainda.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if element.exists { return true }
            app.swipeUp()
        }
        return element.exists
    }

    private func openApp(_ appIdentifier: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Seu primeiro contrato"].waitForExistence(timeout: 10))
        let offer = app.buttons["choose-offer-0"]
        XCTAssertTrue(offer.waitForExistence(timeout: 10))
        offer.tap()
        if !app.buttons["dock-manager"].waitForExistence(timeout: 6), offer.exists {
            offer.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
        }
        XCTAssertTrue(app.buttons["dock-manager"].waitForExistence(timeout: 10), "A tela inicial do celular não abriu")
        let icon = app.buttons[appIdentifier]
        XCTAssertTrue(icon.waitForExistence(timeout: 8), "Ícone ausente: \(appIdentifier)")
        for _ in 0..<4 where !icon.isHittable { app.swipeUp() }
        icon.tap()
        return app
    }
}
