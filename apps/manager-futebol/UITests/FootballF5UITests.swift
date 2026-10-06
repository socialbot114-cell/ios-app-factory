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

    // LIG-01..03: jornada completa em FootballFlowUITests, usando IDs reais do FutOS.

    func testBankSimulatorChangesProjectionAndResetRestoresIt() {
        let app = openApp("app-bank")
        let summary = element("budget-summary", in: app)
        XCTAssertTrue(reveal(summary, in: app))
        let before = summary.label
        XCTAssertFalse(before.isEmpty)
        let simulator = element("budget-simulator", in: app)
        XCTAssertTrue(reveal(simulator, in: app))
        simulator.tap()
        let preset = app.buttons["budget-roster-preset"]
        XCTAssertTrue(reveal(preset, in: app))
        preset.tap()
        for _ in 0..<6 {
            if summary.exists && summary.isHittable { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).press(forDuration: 0.05,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)))
        }
        XCTAssertNotEqual(before, summary.label)
        let reset = app.buttons["budget-reset"]
        XCTAssertTrue(reveal(reset, in: app))
        reset.tap()
        XCTAssertTrue(reveal(summary, in: app))
        XCTAssertEqual(before, summary.label)
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

    func testSettingsCanCreateAndRestoreCareerSlot() {
        let app = openApp("app-settings")
        XCTAssertTrue(reveal(element("settings-save-slots", in: app), in: app))
        let create = app.buttons["settings-new-slot-1"]
        XCTAssertTrue(reveal(create, in: app))
        create.tap()
        XCTAssertTrue(app.staticTexts["Seu primeiro contrato"].waitForExistence(timeout: 8))
        let offer = app.buttons["choose-offer-0"]
        XCTAssertTrue(offer.waitForExistence(timeout: 8))
        offer.tap()
        XCTAssertTrue(app.buttons["dock-manager"].waitForExistence(timeout: 8))
        let settings = app.buttons["app-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()
        XCTAssertTrue(reveal(element("settings-active-slot-1", in: app), in: app))
        let restore = app.buttons["settings-load-slot-0"]
        XCTAssertTrue(reveal(restore, in: app))
        restore.tap()
        XCTAssertTrue(app.buttons["dock-manager"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["app-settings"].waitForExistence(timeout: 8))
        app.buttons["app-settings"].tap()
        XCTAssertTrue(reveal(element("settings-active-slot-0", in: app), in: app))
    }

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
        for up in [true, false] {
            for _ in 0..<8 {
                if element.exists && (element.elementType != .button || element.isHittable) { return true }
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.65 : 0.3))
                start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.3 : 0.65)))
            }
        }
        if element.exists { return element.elementType != .button || element.isHittable }
        XCTFail("Elemento ausente: \(element). Hierarquia:\n\(app.debugDescription)")
        return false
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
        icon.tap()
        XCTAssertTrue(app.buttons["phone-home"].waitForExistence(timeout: 8), "O app \(appIdentifier) não abriu")
        return app
    }
}
