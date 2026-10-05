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
        // Conteúdo fora da viewport pode não existir ainda na árvore de acessibilidade.
        for _ in 0..<6 {
            if app.buttons["play-match"].exists { break }
            app.swipeUp()
        }
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
        // A tela Clube ganhou painéis (estádio, caixa, projetos): o botão pode estar fora da viewport.
        for _ in 0..<10 {
            if newCareer.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(newCareer.waitForExistence(timeout: 8))
    }


    // MARK: - Teste de fumaça de todos os apps

    private struct AppCheck {
        let id: String
        let title: String
        let dock: Bool
        let action: (XCUIApplication) -> Void
    }

    func testEveryAppOpensAndItsMainActionWorks() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Seu primeiro contrato"].waitForExistence(timeout: 10))
        let offer = app.buttons["choose-offer-0"]
        tapWhenReady(offer, in: app)
        if !app.buttons["dock-manager"].waitForExistence(timeout: 6), offer.exists { offer.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap() }
        XCTAssertTrue(app.buttons["dock-manager"].waitForExistence(timeout: 10))

        let checks: [AppCheck] = [
            AppCheck(id: "manager", title: "Gestor", dock: true) { app in XCTAssertTrue(app.buttons["play-match"].waitForExistence(timeout: 6)) },
            AppCheck(id: "squad", title: "Tática", dock: false) { app in
                XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "squad-pitch").firstMatch.waitForExistence(timeout: 6))
                self.tapWhenReady(app.buttons["auto-lineup"], in: app)
            },
            AppCheck(id: "league", title: "Liga", dock: false) { app in XCTAssertTrue(app.staticTexts["Classificação"].waitForExistence(timeout: 6)) },
            AppCheck(id: "market", title: "Transfer", dock: false) { app in
                let sections = app.segmentedControls["market-section"]
                XCTAssertTrue(sections.waitForExistence(timeout: 6))
                sections.buttons["Clubes"].tap()
                let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "club-player-")
                XCTAssertTrue(app.descendants(matching: .any).matching(predicate).firstMatch.waitForExistence(timeout: 6))
            },
            AppCheck(id: "club", title: "Clube", dock: true) { app in
                XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "new-career").firstMatch.waitForExistence(timeout: 6))
            },
            AppCheck(id: "messages", title: "Mensagens", dock: true) { app in
                XCTAssertTrue(app.staticTexts["Bem-vindo, Treinador"].waitForExistence(timeout: 6))
            },
            AppCheck(id: "social", title: "Chuteira", dock: true) { app in
                self.tapWhenReady(app.buttons["post-motivational"], in: app)
                XCTAssertTrue(app.alerts.count == 0)
            },
            AppCheck(id: "betting", title: "Palpite+", dock: false) { app in
                self.tapWhenReady(app.buttons["bet-bonus"], in: app)
                let odds = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "odd-"))
                XCTAssertTrue(odds.firstMatch.waitForExistence(timeout: 6))
                // Apostas contra o próprio clube são bloqueadas por integridade: tenta as próximas seleções.
                for index in 0..<min(odds.count, 8) {
                    let candidate = odds.element(boundBy: index)
                    self.scrollUntilHittable(candidate, in: app)
                    candidate.tap()
                    if app.alerts.firstMatch.waitForExistence(timeout: 1) { app.alerts.firstMatch.buttons.firstMatch.tap(); continue }
                    if app.buttons["place-bet"].waitForExistence(timeout: 2) { break }
                }
                self.tapWhenReady(app.buttons["place-bet"], in: app)
            },
            AppCheck(id: "fantasy", title: "Rodada", dock: false) { app in
                self.tapWhenReady(app.buttons["fantasy-suggest"], in: app)
                self.tapWhenReady(app.buttons["fantasy-save"], in: app)
                XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 4))
            },
            AppCheck(id: "life", title: "Vida", dock: false) { app in self.tapWhenReady(app.buttons["activity-rest"], in: app) },
            AppCheck(id: "business", title: "Negócios", dock: false) { app in self.tapWhenReady(app.buttons["shop-upgrade"], in: app) },
            AppCheck(id: "quests", title: "Metas", dock: false) { app in XCTAssertTrue(app.staticTexts["Missões concluídas"].waitForExistence(timeout: 6)) },
            AppCheck(id: "trophies", title: "Troféus", dock: false) { app in XCTAssertTrue(app.staticTexts["Galeria"].waitForExistence(timeout: 6)) },
            AppCheck(id: "alerts", title: "Alertas", dock: false) { app in XCTAssertTrue(app.staticTexts["Tudo calmo"].exists || app.staticTexts["Histórico"].exists || app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "event-")).firstMatch.exists) },
            AppCheck(id: "brand", title: "Marca", dock: false) { app in
                self.tapWhenReady(app.buttons["tv-performance"], in: app)
                self.tapWhenReady(app.buttons["campaign-localMedia"], in: app)
            },
            AppCheck(id: "bank", title: "Banco", dock: false) { app in self.tapWhenReady(app.buttons["lend-100000"], in: app) },
            AppCheck(id: "contacts", title: "Contatos", dock: false) { app in self.tapWhenReady(app.buttons["contact-family"], in: app) },
            AppCheck(id: "settings", title: "Ajustes", dock: false) { app in
                let picker = app.segmentedControls["difficulty-picker"]
                XCTAssertTrue(picker.waitForExistence(timeout: 6))
                picker.buttons["Difícil"].tap()
                // Estrutura, comissão e patrocínio ficam no Clube; Ajustes só configura o app e a simulação.
                XCTAssertFalse(app.buttons["settings-staff"].exists)
                XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "settings-notification-priority").firstMatch.waitForExistence(timeout: 6))
            }
        ]

        for check in checks {
            let prefix = check.dock ? "dock-" : "app-"
            let icon = app.buttons[prefix + check.id]
            XCTAssertTrue(icon.waitForExistence(timeout: 8), "Ícone ausente: \(check.title)")
            scrollUntilHittable(icon, in: app)
            icon.tap()
            XCTAssertTrue(app.buttons["phone-home"].waitForExistence(timeout: 8), "App não abriu: \(check.title)")
            check.action(app)
            dismissAlertIfAny(app)
            attachScreenshot(app, name: "app-\(check.id)")
            app.buttons["phone-home"].tap()
            XCTAssertTrue(app.buttons["dock-manager"].waitForExistence(timeout: 8), "Não voltou à tela inicial: \(check.title)")
        }
    }

    private func dismissAlertIfAny(_ app: XCUIApplication) {
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 1) { alert.buttons.firstMatch.tap() }
    }

    func testFutOSNotificationOpensTheActualMessageAndAgenda() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        tapWhenReady(app.buttons["choose-offer-0"], in: app)
        XCTAssertTrue(app.buttons["dock-manager"].waitForExistence(timeout: 10))
        tapWhenReady(app.buttons["phone-notifications"], in: app)
        tapWhenReady(app.buttons["notification-inbox"], in: app)
        XCTAssertTrue(app.staticTexts["Bem-vindo, Treinador"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Fechar"].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "futos-contextual-message")
        app.buttons["Fechar"].tap()
        tapWhenReady(app.buttons["phone-home"], in: app)
        tapWhenReady(app.buttons["dock-manager"], in: app)
        let agenda = app.descendants(matching: .any).matching(identifier: "football-agenda").firstMatch
        for _ in 0..<6 {
            if agenda.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(agenda.waitForExistence(timeout: 8))
        attachScreenshot(app, name: "futos-manager-agenda")
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
        guard element.waitForExistence(timeout: 10) else {
            attachScreenshot(app, name: "missing-element")
            XCTFail("Elemento ausente: \(element). Hierarquia:\n\(app.debugDescription)")
            return
        }
        scrollUntilHittable(element, in: app)
        element.tap()
    }
}
