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

        openFromHome("dock-manager", in: app)
        XCTAssertTrue(app.buttons["play-match"].waitForExistence(timeout: 8))
        goHome(app)

        tapWhenReady(app.buttons["app-squad"], in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "squad-pitch").firstMatch.waitForExistence(timeout: 5))
        let intensity = app.segmentedControls["training-intensity-picker"]
        XCTAssertTrue(intensity.waitForExistence(timeout: 5))
        scrollUntilHittable(intensity, in: app)
        intensity.buttons["Intensa"].tap()
        goHome(app)

        openFromHome("dock-manager", in: app)
        // Conteúdo fora da viewport pode não existir ainda na árvore de acessibilidade: rola com arrasto no meio da tela.
        for _ in 0..<8 {
            if app.buttons["play-match"].exists { break }
            dragUp(app)
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
        goHome(app)

        tapWhenReady(app.buttons["app-league"], in: app)
        XCTAssertTrue(app.staticTexts["Classificação"].waitForExistence(timeout: 5))
        let auroraRow = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Aurora FC")).firstMatch
        XCTAssertTrue(auroraRow.waitForExistence(timeout: 5))
        goHome(app)

        tapWhenReady(app.buttons["app-contacts"], in: app)
        XCTAssertTrue(app.buttons["contact-family"].waitForExistence(timeout: 6))
        goHome(app)

        tapWhenReady(app.buttons["app-betting"], in: app)
        XCTAssertTrue(app.staticTexts["Palpite+"].waitForExistence(timeout: 6))
        goHome(app)

        openFromHome("dock-club", in: app)
        let newCareer = app.descendants(matching: .any).matching(identifier: "club-management").firstMatch
        // A tela Clube ganhou painéis (estádio, diretoria, gestão): o painel de gestão pode estar fora da viewport.
        for _ in 0..<10 {
            if newCareer.exists { break }
            dragUp(app)
        }
        XCTAssertTrue(newCareer.waitForExistence(timeout: 8))
    }


    /// Avançar o calendário bloqueia o celular, mostra a nova data e só então libera as novidades do dia.
    func testAdvancingTheCalendarLocksThePhoneWithTheNewDate() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--lock-on-advance"]
        app.launch()
        tapWhenReady(app.buttons["choose-offer-0"], in: app)
        XCTAssertTrue(app.buttons["dock-manager"].waitForExistence(timeout: 10))

        openFromHome("dock-manager", in: app)
        leagueTap(app.buttons["play-match"], in: app)
        XCTAssertTrue(leagueElement("live-scoreboard", in: app).waitForExistence(timeout: 10))
        leagueTap(app.buttons["live-skip"], in: app)
        XCTAssertTrue(app.buttons["live-finish"].waitForExistence(timeout: 30))
        leagueTap(app.buttons["live-finish"], in: app)

        let unlock = app.buttons["phone-unlock"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 10), "A tela de bloqueio deve aparecer depois de avançar o dia")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "lock-date").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "lock-widget-next").firstMatch.waitForExistence(timeout: 5))
        unlock.tap()
        XCTAssertTrue(app.buttons["dock-manager"].waitForExistence(timeout: 10))
        if app.buttons["press-skip"].waitForExistence(timeout: 5) { app.buttons["press-skip"].tap() }
    }

    /// Preparação em passos, conversa do intervalo e resumo de fim de jogo, de ponta a ponta.
    func testPrepFlowHalftimeTalkAndFullTimeCard() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        tapWhenReady(app.buttons["choose-offer-0"], in: app)
        XCTAssertTrue(app.buttons["dock-manager"].waitForExistence(timeout: 10))

        openFromHome("dock-manager", in: app)
        leagueTap(app.buttons["prep-flow-open"], in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "prep-flow").firstMatch.waitForExistence(timeout: 8))
        for _ in 0..<10 where !app.buttons["prep-go"].exists {
            if app.buttons["prep-next"].exists { app.buttons["prep-next"].tap() }
        }
        XCTAssertTrue(app.buttons["prep-go"].waitForExistence(timeout: 6))
        app.buttons["prep-go"].tap()

        XCTAssertTrue(leagueElement("live-scoreboard", in: app).waitForExistence(timeout: 15))
        let talk = app.descendants(matching: .any).matching(identifier: "halftime-talk").firstMatch
        XCTAssertTrue(talk.waitForExistence(timeout: 30), "A conversa de vestiário aparece no intervalo")
        let praise = app.buttons["halftime-praise"]
        if praise.waitForExistence(timeout: 4) { scrollUntilHittable(praise, in: app); praise.tap() }
        leagueTap(app.buttons["live-skip"], in: app)
        XCTAssertTrue(app.buttons["live-finish"].waitForExistence(timeout: 30))
        let card = app.descendants(matching: .any).matching(identifier: "fulltime-card").firstMatch
        for _ in 0..<6 where !card.exists { dragUp(app) }
        XCTAssertTrue(card.exists, "O resumo do jogo aparece abaixo do botão de concluir")
        leagueTap(app.buttons["live-finish"], in: app)
        if app.buttons["press-skip"].waitForExistence(timeout: 5) { app.buttons["press-skip"].tap() }
    }

    /// LIG-01..03: usa entidades e estados da Liga, sem depender do header do FutOS.
    func testLeagueRowsOpenClubProfileMatchesAndRoundsNavigate() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        tapWhenReady(app.buttons["choose-offer-0"], in: app)
        XCTAssertTrue(app.buttons["dock-manager"].waitForExistence(timeout: 10))

        // Produz um relatório real; não aceita pré-jogo como substituto de partida histórica.
        openFromHome("dock-manager", in: app)
        leagueTap(app.buttons["play-match"], in: app)
        XCTAssertTrue(leagueElement("live-scoreboard", in: app).waitForExistence(timeout: 10))
        leagueTap(app.buttons["live-skip"], in: app)
        XCTAssertTrue(app.buttons["live-finish"].waitForExistence(timeout: 30))
        leagueTap(app.buttons["live-finish"], in: app)
        if app.buttons["press-skip"].waitForExistence(timeout: 5) { app.buttons["press-skip"].tap() }
        XCTAssertTrue(leagueElement("football-training-report", in: app).waitForExistence(timeout: 10))
        goHome(app)
        openFromHome("app-league", in: app)
        XCTAssertTrue(app.staticTexts["league-section-state"].waitForExistence(timeout: 8))
        let section = app.staticTexts["league-section-state"].label

        let club = leagueFirst("league-club-", in: app)
        leagueReveal(club, in: app)
        let clubID = String(club.identifier.dropFirst("league-club-".count))
        leagueTap(club, in: app)
        XCTAssertTrue(app.staticTexts["league-club-profile-\(clubID)"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Forma na liga"].exists)
        let player = leagueFirst("league-club-player-", in: app)
        leagueReveal(player, in: app)
        let playerID = String(player.identifier.dropFirst("league-club-player-".count))
        leagueTap(player, in: app)
        XCTAssertTrue(app.staticTexts["league-player-profile-\(playerID)"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Temporada · todas as competições"].exists)
        leagueTap(app.buttons["league-player-back"], in: app)
        XCTAssertTrue(app.staticTexts["league-club-profile-\(clubID)"].waitForExistence(timeout: 8))
        leagueTap(app.buttons["league-club-back"], in: app)
        XCTAssertTrue(app.staticTexts["league-section-state"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["league-section-state"].label, section)

        let round = app.staticTexts["league-round-state"]
        leagueReveal(round, in: app)
        let pastRound = round.label
        let pastMatch = leagueFirst("league-match-", in: app)
        leagueReveal(pastMatch, in: app)
        let pastID = String(pastMatch.identifier.dropFirst("league-match-".count))
        XCTAssertEqual(pastMatch.value as? String, "Disputada")
        leagueTap(app.buttons["league-round-next"], in: app)
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", pastRound), object: round)
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 8), .completed)
        let futureRound = round.label
        let futureMatch = leagueFirst("league-match-", in: app)
        leagueReveal(futureMatch, in: app)
        let futureID = String(futureMatch.identifier.dropFirst("league-match-".count))
        XCTAssertNotEqual(futureID, pastID)
        XCTAssertEqual(futureMatch.value as? String, "Agendada")
        leagueTap(futureMatch, in: app)
        XCTAssertTrue(app.staticTexts["league-match-detail-\(futureID)"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["league-match-detail-\(futureID)"].label, "Partida agendada")
        XCTAssertTrue(app.staticTexts["O resultado e os eventos estarão disponíveis após a partida."].exists)
        leagueTap(app.buttons["league-match-back"], in: app)
        leagueReveal(round, in: app)
        XCTAssertEqual(round.label, futureRound)
        leagueTap(app.buttons["league-round-previous"], in: app)
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", pastRound), object: round)
        XCTAssertEqual(XCTWaiter().wait(for: [restored], timeout: 8), .completed)
        let historical = leagueElement("league-match-\(pastID)", in: app)
        leagueTap(historical, in: app)
        XCTAssertTrue(app.staticTexts["league-match-detail-\(pastID)"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["league-match-detail-\(pastID)"].label, "Relatório da partida")
        leagueReveal(leagueElement("match-report-shots", in: app), in: app)
        XCTAssertTrue(leagueElement("match-report-shots", in: app).exists)
        leagueReveal(leagueElement("match-report-possession", in: app), in: app)
        XCTAssertTrue(leagueElement("match-report-possession", in: app).exists)
        leagueTap(app.buttons["league-match-back"], in: app)
        leagueReveal(round, in: app)
        XCTAssertEqual(round.label, pastRound)

        let sections = app.segmentedControls["league-section"]
        leagueReveal(sections, in: app)
        sections.buttons["Artilharia"].tap()
        XCTAssertEqual(app.staticTexts["league-section-state"].label, "Artilharia")
        let scorer = leagueFirst("league-scorer-", in: app)
        leagueReveal(scorer, in: app)
        let scorerID = String(scorer.identifier.dropFirst("league-scorer-".count))
        leagueTap(scorer, in: app)
        XCTAssertTrue(app.staticTexts["league-player-profile-\(scorerID)"].waitForExistence(timeout: 8))
        leagueTap(app.buttons["league-player-back"], in: app)
        XCTAssertTrue(app.staticTexts["league-section-state"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["league-section-state"].label, "Artilharia")
        attachScreenshot(app, name: "league-navigation-restored")
        goHome(app)
    }

    private func leagueElement(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func leagueFirst(_ prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// Busca nos dois sentidos: destinos aninhados podem restaurar a rolagem anterior.
    private func leagueReveal(_ element: XCUIElement, in app: XCUIApplication) {
        for direction in [true, false] {
            for _ in 0..<16 {
                if element.exists && element.isHittable { return }
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: direction ? 0.65 : 0.3))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: direction ? 0.3 : 0.65))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
        }
        attachScreenshot(app, name: "league-element-unreachable")
        XCTFail("Elemento da Liga inacessível: \(element). Hierarquia:\n\(app.debugDescription)")
    }

    private func leagueTap(_ element: XCUIElement, in app: XCUIApplication) {
        leagueReveal(element, in: app)
        element.tap()
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
                XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "club-management").firstMatch.waitForExistence(timeout: 6))
            },
            AppCheck(id: "messages", title: "Mensagens", dock: true) { app in
                XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Bem-vindo, Treinador")).firstMatch.waitForExistence(timeout: 6))
            },
            AppCheck(id: "social", title: "Chuteira", dock: true) { app in
                self.tapWhenReady(app.buttons["post-publish"], in: app)
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
                self.leagueReveal(app.descendants(matching: .any).matching(identifier: "settings-notification-priority").firstMatch, in: app)
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
            goHome(app)
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
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Bem-vindo, Treinador")).firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Fechar"].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "futos-contextual-message")
        app.buttons["Fechar"].tap()
        goHome(app)
        openFromHome("dock-manager", in: app)
        let agenda = app.descendants(matching: .any).matching(identifier: "football-agenda").firstMatch
        for _ in 0..<6 {
            if agenda.exists { break }
            dragUp(app)
        }
        XCTAssertTrue(agenda.waitForExistence(timeout: 8))
        attachScreenshot(app, name: "futos-manager-agenda")
    }

    /// Volta à tela inicial e espera a janela do app sair: `phone-home` só existe com um app aberto.
    /// Tocar no dock durante a animação de saída cai na janela que está fechando e o toque se perde.
    private func goHome(_ app: XCUIApplication) {
        let home = app.buttons["phone-home"]
        XCTAssertTrue(home.waitForExistence(timeout: 8), "Nenhum app aberto para fechar")
        home.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: home)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 8), .completed, "A janela do app não fechou")
        XCTAssertTrue(app.buttons["dock-manager"].waitForExistence(timeout: 8))
    }

    /// Abre um app pelo ícone da tela inicial e espera a janela abrir.
    private func openFromHome(_ identifier: String, in app: XCUIApplication) {
        let icon = app.buttons[identifier]
        XCTAssertTrue(icon.waitForExistence(timeout: 8), "Ícone ausente: \(identifier)")
        icon.tap()
        XCTAssertTrue(app.buttons["phone-home"].waitForExistence(timeout: 8), "O app \(identifier) não abriu")
    }

    /// Rola o conteúdo com um arrasto no meio da tela, longe da barra de início na borda inferior.
    private func dragUp(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        start.press(forDuration: 0.05, thenDragTo: end)
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
            dragUp(app)
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
