import SwiftUI

struct FootballHome: View {
    @State private var career = FootballHome.initialCareer()
    @State private var activeSlot = FootballSaveStore().activeSlot
    @State private var slotSummaries: [SaveSlotSummary?] = []
    @State private var tableSection: FootballTableView.LeagueSection?
    @State private var openApp: PhoneApp?
    @State private var alertMessage: String?
    @State private var showLiveMatch = false
    @State private var seasonSummary: SeasonRecord?
    @State private var showsOnboarding = FootballOnboardingGate.shouldShow
    /// Menu de entrada (Continuar, Novo jogo, Opções); UI tests e capturas entram direto no jogo.
    @State private var showsTitle = !(FactoryCapture.isUITesting || FactoryCapture.screen != nil)
    @State private var showsTitleOptions = false
    @State private var confirmsNewGame = false
    @State private var didPrepare = false
    @State private var showPress = false
    @State private var booting = !(FactoryCapture.isUITesting || FactoryCapture.screen != nil)
    /// O celular só bloqueia quando o calendário avança (troca de dia), nunca ao abrir o jogo.
    @State private var locked = false
    @State private var showNotifications = false
    @State private var showSearch = false
    @State private var searchSeed = ""
    @State private var searchedPlayer: SearchedPlayer?
    @State private var focusedContactID: Int?
    @State private var focusedEventID: Int?
    @State private var notifiedMessage: SearchedPlayer?
    @State private var pendingMessageID: Int?
    @State private var pendingPlayerID: Int?
    @State private var dayTransition: PhoneDayTransition?
    @State private var lastDayKey: DayKey?
    @State private var pressAfterUnlock = false
    @State private var guideSuggestion: FootballSuggestion?
    @State private var guideAfterUnlock = false
    @State private var momentOverride: PhoneMoment?
    @Environment(\.scenePhase) private var scenePhase

    /// Dia do calendário em que a carreira está; quando muda, o FutOS bloqueia a tela e mostra a passagem do dia.
    struct DayKey: Equatable {
        let season: Int
        let matchDay: Int
    }

    private var dayKey: DayKey { DayKey(season: career.season, matchDay: career.matchDayIndex) }

    /// Os UI tests abrem o celular já desbloqueado; só testam a tela de bloqueio ao avançar com `--lock-on-advance`.
    private var locksOnAdvance: Bool {
        capture == nil && (!FactoryCapture.isUITesting || ProcessInfo.processInfo.arguments.contains("--lock-on-advance"))
    }

    /// Tela bloqueada ou folha por cima do celular: a faixa de desbloqueio espera, para não expirar escondida.
    private var phoneIsCovered: Bool {
        locked || showLiveMatch || showPress || showNotifications || showSearch
            || searchedPlayer != nil || notifiedMessage != nil || seasonSummary != nil
    }

    struct SearchedPlayer: Identifiable { let id: Int }

    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        Group {
            if let capture, Self.liveMatchCaptures.contains(capture), career.liveMatch != nil {
                FootballLiveMatchView(career: $career, staticPreview: true) { }
            } else if let capture, Self.deepCaptures.contains(capture) {
                NavigationStack { deepCapture(capture).tint(FootballTheme.accent) }
            } else if booting {
                FootballLoadingView()
            } else if showsTitle {
                FootballProfileRoom(activeSlot: activeSlot, summaries: slotSummaries,
                                    pending: career.selectedClubID == nil ? [] : career.phoneNotifications,
                                    onEnter: { slot in
                                        if slot != activeSlot { loadSlot(slot) }
                                        withAnimation(.easeOut(duration: 0.4)) { showsTitle = false }
                                    },
                                    onCreate: { slot in
                                        if !(slot == activeSlot && career.selectedClubID == nil) { startNewCareer(slot: slot) }
                                        withAnimation(.easeOut(duration: 0.4)) { showsTitle = false }
                                    },
                                    onOptions: { refreshSlots(); showsTitleOptions = true })
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if career.selectedClubID == nil {
                if showsOnboarding {
                    FootballOnboardingView(career: $career) {
                        FootballOnboardingGate.markSeen()
                        showsOnboarding = false
                    }
                } else {
                    NavigationStack { FootballClubSelectionView(career: $career, onAlert: showAlert) }
                }
            } else {
                phone
            }
        }
        .tint(FootballTheme.accent)
        .fullScreenCover(isPresented: $showLiveMatch) {
            FootballLiveMatchView(career: $career, staticPreview: false) { showLiveMatch = false }
        }
        .sheet(isPresented: $showsTitleOptions) {
            FootballTitleOptionsSheet(career: $career, activeSlot: activeSlot, summaries: slotSummaries,
                                      onLoad: { loadSlot($0); showsTitleOptions = false; showsTitle = false },
                                      onNew: { startNewCareer(slot: $0); showsTitleOptions = false; showsTitle = false },
                                      onDelete: deleteSlot)
        }
        .confirmationDialog("Começar uma nova carreira?", isPresented: $confirmsNewGame, titleVisibility: .visible) {
            Button("Começar nova carreira") { confirmNewGame() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("A carreira atual continua salva. Dá para voltar a ela em Opções.")
        }
        .sheet(item: $seasonSummary) { record in
            FootballSeasonSummaryView(record: record, career: career)
        }
        .sheet(isPresented: $showPress) {
            FootballPressView(career: $career)
        }
        .sheet(isPresented: $showNotifications, onDismiss: {
            if let id = pendingMessageID {
                pendingMessageID = nil
                openMessage(id)
            }
        }) {
            PhoneNotificationCenter(career: career, onOpen: { app in openApp = app }, onOpenMessage: { pendingMessageID = $0 },
                                    onOpenEvent: { focusedEventID = $0; openApp = .alerts })
        }
        .sheet(isPresented: $showSearch, onDismiss: {
            if let id = pendingPlayerID {
                pendingPlayerID = nil
                searchedPlayer = SearchedPlayer(id: id)
            }
        }) {
            PhoneSpotlight(career: career, initialQuery: searchSeed, onApp: { openApp = $0 }, onPlayer: { pendingPlayerID = $0 }, onContact: { focusedContactID = $0; openApp = .contacts },
                           onLeagueSection: { tableSection = $0; openApp = .league })
        }
        .sheet(item: $searchedPlayer) { selection in
            FootballPlayerDetailView(career: $career, playerID: selection.id, onAlert: showAlert)
        }
        .sheet(item: $notifiedMessage) { selection in
            NavigationStack {
                FootballInboxView(career: $career, onAlert: showAlert, onOpenApp: { app in
                    notifiedMessage = nil
                    openApp = app
                }, focusedMessageID: selection.id)
                .id(selection.id)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { notifiedMessage = nil } } }
            }
        }
        .alert("Manager de Futebol", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            prepareInitialState()
            lastDayKey = dayKey
        }
        .task {
            guard booting else { return }
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            withAnimation(.easeOut(duration: 0.3)) { booting = false }
        }
        .onChange(of: career) { _, updatedCareer in
            // Durante a partida ao vivo o save acontece só ao pausar, sair ou fechar o app.
            guard capture == nil, !showLiveMatch else { return }
            FootballSaveStore().save(updatedCareer, slot: activeSlot)
            refreshSlots()
        }
        .onChange(of: showLiveMatch) { _, isShowing in
            guard !isShowing, capture == nil else { return }
            FootballSaveStore().save(career, slot: activeSlot)
            refreshSlots()
            if career.pendingPress != nil {
                // Com a tela bloqueada, a coletiva espera o treinador desbloquear o celular.
                if locked { pressAfterUnlock = true } else { presentPress(after: 700_000_000) }
            }
        }
        .onChange(of: dayKey) { _, newKey in
            guard let previous = lastDayKey else { lastDayKey = newKey; return }
            lastDayKey = newKey
            guard newKey != previous, locksOnAdvance, !booting, career.selectedClubID != nil else { return }
            showNotifications = false
            showSearch = false
            searchedPlayer = nil
            notifiedMessage = nil
            openApp = nil
            dayTransition = PhoneDayTransition(fromSeason: previous.season, fromMatchDay: previous.matchDay,
                                               toSeason: newKey.season, toMatchDay: newKey.matchDay)
            guideSuggestion = nil
            guideAfterUnlock = true
            withAnimation(.easeOut(duration: 0.35)) { locked = true }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active, capture == nil else { return }
            FootballSaveStore().save(career, slot: activeSlot)
        }
    }

    // MARK: - O celular

    private var phone: some View {
        ZStack {
            PhoneHomeScreen(career: career, onOpen: open, onNotifications: { showNotifications = true },
                            onSearch: { searchSeed = ""; showSearch = true }, onGuide: { showGuide() }, momentOverride: momentOverride)
                .accessibilityHidden(openApp != nil || locked)
                .blur(radius: openApp != nil && !career.world.phone.preferences.reduceMotion ? 6 : 0)
                .scaleEffect(openApp != nil && !career.world.phone.preferences.reduceMotion ? 0.95 : 1)
            if let app = openApp {
                appWindow(app)
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                    .zIndex(1)
            }
            if let suggestion = guideSuggestion, !locked {
                VStack {
                    PhoneGuideBanner(suggestion: suggestion, onGo: { go(to: suggestion) }, onDismiss: { snoozeGuide(suggestion) })
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: suggestion.id) {
                            try? await Task.sleep(nanoseconds: 12_000_000_000)
                            if guideSuggestion?.id == suggestion.id { dismissGuide() }
                        }
                    Spacer()
                }
                .zIndex(3)
            }
            // Acima da janela de app aberta: a conquista aparece mesmo logo depois da partida, com o Gestor aberto.
            if let notice = career.unlockQueue.first, !phoneIsCovered, guideSuggestion == nil {
                VStack {
                    PhoneUnlockBanner(notice: notice, onOpen: { openUnlock(notice) }, onDismiss: { career.finishUnlock(id: notice.id) },
                                      onPull: { showNotifications = true })
                        .id(notice.id)
                    Spacer()
                }
                .zIndex(4)
            }
            if locked {
                PhoneLockScreen(career: career, transition: dayTransition, onUnlock: unlock, onOpen: { openApp = $0 }, onOpenMessage: openMessage,
                                onOpenEvent: { id in unlock(); focusedEventID = id; openApp = .alerts },
                                onSuggestion: { go(to: $0) })
                    .transition(.move(edge: .top))
                    .zIndex(2)
            }
        }
        .animation(career.world.phone.preferences.reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: openApp)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: openApp)
    }

    private func unlock() {
        withAnimation(.easeOut(duration: 0.3)) { locked = false }
        dayTransition = nil
        if pressAfterUnlock {
            pressAfterUnlock = false
            if career.pendingPress != nil { presentPress(after: 450_000_000) }
        } else if guideAfterUnlock {
            // Depois da noite, uma notificação aponta a primeira coisa a fazer no novo dia.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                if openApp == nil, !locked { showGuide(silentWhenEmpty: true) }
            }
        }
        guideAfterUnlock = false
    }

    // MARK: O que fazer agora

    private func showGuide() { showGuide(silentWhenEmpty: false) }

    private func showGuide(silentWhenEmpty: Bool) {
        guard let suggestion = career.nextBestAction() else {
            if !silentWhenEmpty { alertMessage = "Tudo em dia por enquanto. Avance o calendário quando quiser." }
            return
        }
        if silentWhenEmpty && suggestion.priority == 0 { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { guideSuggestion = suggestion }
    }

    /// "Depois": esconde a sugestão até o próximo dia de jogo.
    private func snoozeGuide(_ suggestion: FootballSuggestion) {
        career.snoozeSuggestion(suggestion.id)
        dismissGuide()
    }

    private func dismissGuide() {
        withAnimation(.easeOut(duration: 0.25)) { guideSuggestion = nil }
    }

    /// Leva ao app (e à mensagem ou decisão) que a sugestão indica.
    private func go(to suggestion: FootballSuggestion) {
        if locked { unlock() }
        dismissGuide()
        if let id = suggestion.messageID {
            openMessage(id)
        } else if let id = suggestion.eventID {
            focusedEventID = id
            openApp = .alerts
        } else if let app = PhoneApp(rawValue: suggestion.appID) {
            open(app)
        }
    }

    private func presentPress(after nanoseconds: UInt64) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: nanoseconds)
            showPress = true
        }
    }

    private func open(_ app: PhoneApp) {
        focusedContactID = nil
        focusedEventID = nil
        openApp = app
    }

    /// Toque na faixa de desbloqueio: tira o aviso da fila e abre Troféus ou Metas.
    private func openUnlock(_ notice: UnlockNotice) {
        career.finishUnlock(id: notice.id)
        if let app = PhoneApp(rawValue: notice.appID) { open(app) }
    }

    private func openMessage(_ id: Int) {
        openApp = .messages
        notifiedMessage = SearchedPlayer(id: id)
    }

    private func closeApp() {
        openApp = nil
    }

    private func appWindow(_ app: PhoneApp) -> some View {
        NavigationStack {
            appContent(app)
                // Cada app possui identidade própria: não reutilizar viewport/navegação de outro app.
                .id(app)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { closeApp() } label: { Label("Início", systemImage: "chevron.left") }
                            .accessibilityIdentifier("phone-home-top")
                    }
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            Image(systemName: app.symbol).foregroundStyle(app.tint)
                            Text(app.title).font(.headline)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
        }
        .id(app)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button { closeApp() } label: {
                Capsule().fill(Color.primary.opacity(0.35)).frame(width: 140, height: 5)
                    .frame(maxWidth: .infinity, minHeight: 24)
                    .contentShape(Rectangle())
            }
            .background(FactoryColor.canvas)
            .accessibilityLabel("Voltar para a tela inicial")
            .accessibilityIdentifier("phone-home")
        }
        .background(FactoryColor.canvas.ignoresSafeArea())
    }

    @ViewBuilder
    private func appContent(_ app: PhoneApp) -> some View {
        switch app {
        case .manager:
            FootballDashboardView(
                career: $career,
                onPlayLive: startLiveMatch,
                onAlert: showAlert,
                onSeasonEnded: { seasonSummary = $0 },
                onNavigate: { openApp = $0 },
                onShowPress: { showPress = true },
                onOpenAgenda: openAgendaItem
            )
        case .squad:
            FootballSquadView(career: $career, onAlert: showAlert)
        case .league:
            FootballTableView(career: career, initialSection: tableSection, onSectionChange: { tableSection = $0 })
                .onAppear { career.markTutorialSeen("table") }
        case .market:
            FootballMarketView(career: $career, onAlert: showAlert)
                .onAppear { career.markTutorialSeen("market") }
        case .club:
            FootballClubView(career: $career, onAlert: showAlert, onOpenApp: { openApp = $0 })
            .onAppear { career.markTutorialSeen("club") }
        case .messages: FootballInboxView(career: $career, onAlert: showAlert, onOpenApp: { openApp = $0 })
        case .social: FootballSocialView(career: $career, onAlert: showAlert, onOpenApp: { openApp = $0 })
        case .betting: FootballBettingView(career: $career, onAlert: showAlert)
        case .fantasy: FootballFantasyView(career: $career, onAlert: showAlert)
        case .life: FootballCoachLifeView(career: $career, onAlert: showAlert)
        case .business: FootballBusinessView(career: $career, onAlert: showAlert)
        case .quests: FootballQuestsView(career: $career, onOpenApp: { openApp = PhoneApp(rawValue: $0) })
        case .trophies: FootballAchievementsView(career: $career)
        case .legends: FootballLegendsView(career: $career)
        case .academy: FootballAcademyView(career: $career, onAlert: showAlert)
        case .store: FootballStoreView()
        case .alerts: FootballEventsView(career: $career, focusedEventID: focusedEventID)
        case .brand: FootballGrowthView(career: $career, onAlert: showAlert)
        case .bank: FootballFinanceView(career: $career, onAlert: showAlert)
        case .contacts: FootballContactsView(career: $career, onAlert: showAlert, focusedContactID: focusedContactID)
        case .settings: FootballModesView(career: $career, onStartChallenge: startChallenge, onAlert: showAlert,
            saveSlots: FootballSaveSlotsView(activeSlot: activeSlot, summaries: slotSummaries, onLoad: loadSlot, onNew: startNewCareer, onDelete: deleteSlot))
        }
    }

    /// Rotas de captura que abrem a partida ao vivo (nome exato, para não confundir com rotas como `match-prep`).
    static let liveMatchCaptures: Set<String> = ["match", "match-watch", "match-goal", "match-narration", "match-final", "match-halftime", "halftime-talk"]

    /// Etapas do ritual de virada de temporada que podem ser capturadas isoladamente.
    static let offseasonCaptures: [String: OffseasonStep] = [
        "offseason-recap": .endOfSeason, "offseason-contracts": .contracts, "offseason-review": .review, "offseason-pack": .iconPack,
        "offseason-holiday": .holiday, "offseason-sponsor": .sponsor, "offseason-preseason": .preseason, "offseason-kickoff": .kickoff,
    ]

    static let deepCaptures: Set<String> = Set(["player", "staff", "press", "renewal", "post-summary", "tactical-plans", "story-arc", "public-sphere", "save-slots", "day-plan", "chat-player", "chat-family", "chat-staff", "prep-flow", "onboarding", "onboarding-mode", "loading", "title", "title-new", "title-shade"])
        .union(FootballF4Captures.names).union(FootballF5Captures.names).union(offseasonCaptures.keys)

    @ViewBuilder
    private func deepCapture(_ name: String) -> some View {
        switch name {
        case "save-slots":
            VStack(alignment: .leading, spacing: 16) {
                FootballSaveSlotsView(activeSlot: activeSlot, summaries: slotSummaries, onLoad: { _ in }, onNew: { _ in }, onDelete: { _ in })
            }.factoryPage().navigationTitle("Carreiras do FutOS")
        case "loading": FootballLoadingView()
        case "title":
            FootballProfileRoom(activeSlot: 0, summaries: [SaveSlotSummary(slot: 0, clubID: 1, season: 2, matchDay: 8, division: .serieA, updatedAt: Date(), coachName: "Rafael",
                                                                           energy: 72, fanMood: 58, gameDay: FootballCalendarClock.day(season: 2, matchDay: 8), gameMoment: FootballCalendarClock.moment(season: 2, matchDay: 8)),
                                                           SaveSlotSummary(slot: 1, clubID: 3, season: 1, matchDay: 3, division: .serieB, updatedAt: Date(), coachName: "Marina"), nil],
                                onEnter: { _ in }, onCreate: { _ in }, onOptions: {})
        case "title-new":
            FootballProfileRoom(activeSlot: 0, summaries: [nil, nil, nil], onEnter: { _ in }, onCreate: { _ in }, onOptions: {})
        case "title-shade":
            FootballProfileRoom(activeSlot: 0, summaries: [SaveSlotSummary(slot: 0, clubID: 1, season: 2, matchDay: 8, division: .serieA, updatedAt: Date(), coachName: "Rafael"), nil, nil],
                                pending: [PhoneNotification(id: "press", title: "Coletiva de imprensa", detail: "Os jornalistas esperam suas respostas.", symbol: "mic.fill", app: .manager, priority: 3)],
                                startsWithShade: true, onEnter: { _ in }, onCreate: { _ in }, onOptions: {})
        case "onboarding": FootballOnboardingView(career: $career, startPage: 0) {}
        case "onboarding-mode": FootballOnboardingView(career: $career, startPage: 4) {}
        case let name where Self.offseasonCaptures[name] != nil:
            FootballOffseasonCaptureHost(step: Self.offseasonCaptures[name] ?? .kickoff)
        case "press": FootballPressView(career: $career)
        case "prep-flow":
            FootballMatchPrepFlow(career: $career, onOpenSquad: {}, onPlay: {})
        case "day-plan":
            ScrollView { FootballDayPlanPanel(career: career).padding(20) }
        case "chat-player", "chat-family", "chat-staff":
            FootballInboxView(career: $career, onAlert: showAlert, onOpenApp: { _ in }, initialThreadID: chatCaptureThread(name))
        case _ where FootballF4Captures.names.contains(name): FootballF4CaptureView(name: name, career: $career, onAlert: showAlert)
        case _ where FootballF5Captures.names.contains(name): FootballF5CaptureView(name: name, career: $career, onAlert: showAlert)
        case "public-sphere":
            ScrollView {
                VStack(spacing: 16) {
                    FootballComposeDraftPanel(career: $career, onAlert: showAlert) { _ in }
                    if let post = career.world.social.posts.first(where: \.isUser) {
                        FactoryPanel(title: "Sua publicação", systemImage: "bubble.left.and.text.bubble.right.fill") {
                            Text(post.text).font(.subheadline)
                            FootballPostThread(career: $career, post: post)
                        }
                    }
                    FootballPublicSpherePanel(career: career)
                }
                .padding(20)
            }
        case "story-arc":
            ScrollView { FootballStoryArcPanel(career: $career).padding(20) }
        case "tactical-plans":
            ScrollView { FootballTacticalPlansPanel(career: $career).padding(20) }
        case "post-summary":
            ScrollView {
                if let summary = career.latestUserFixture?.summary { FootballPostMatchSummaryPanel(summary: summary).padding(20) }
            }
        case "renewal": FootballRenewalSheet(career: $career, playerID: career.clubRoster.first?.id ?? 0)
        case "betting": FootballBettingView(career: $career, onAlert: showAlert)
        case "social": FootballSocialView(career: $career, onAlert: showAlert)
        case "fantasy": FootballFantasyView(career: $career, onAlert: showAlert)
        case "lifestyle": FootballCoachLifeView(career: $career, onAlert: showAlert)
        case "business": FootballBusinessView(career: $career, onAlert: showAlert)
        case "quests": FootballQuestsView(career: $career)
        case "events": FootballEventsView(career: $career)
        case "achievements": FootballAchievementsView(career: $career)
        case "staff": FootballStaffView(career: $career, onAlert: showAlert)
        case "growth": FootballGrowthView(career: $career, onAlert: showAlert)
        case "contacts": FootballContactsView(career: $career, onAlert: showAlert)
        default:
            FootballPlayerDetailView(career: $career, playerID: career.startingXI.first ?? 0, onAlert: showAlert)
        }
    }

    /// Conversa aberta nas capturas: já com uma troca de mensagens para o balão e a resposta aparecerem.
    private func chatCaptureThread(_ name: String) -> String {
        switch name {
        case "chat-player":
            return career.inbox.last(where: { $0.playerID != nil }).flatMap { $0.playerID }.map { "player-\($0)" } ?? "contact-family"
        case "chat-staff":
            return career.staff.first.map { "staff-\($0.role.rawValue)" } ?? "contact-family"
        default:
            return "contact-family"
        }
    }

    private func prepareChatCapture(_ name: String) {
        career.ensureContacts()
        let thread = chatCaptureThread(name)
        let quick: String
        if thread.hasPrefix("player-") { quick = "praise" } else if thread.hasPrefix("staff-") { quick = "advice" } else { quick = "care" }
        _ = career.sendChatQuick(threadID: thread, quickID: quick)
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        if capture == nil { career.logActionResult(message, appID: openApp?.rawValue) }
    }

    private func openAgendaItem(_ item: FootballAgendaItem) {
        switch item.kind {
        case .promise:
            if let promise = career.promises.first(where: { "promise-\($0.id)" == item.id }) {
                openApp = .squad
                searchedPlayer = SearchedPlayer(id: promise.playerID)
            }
        case .contract:
            if let athlete = career.clubRoster.first(where: { "contract-\($0.id)" == item.id }) {
                openApp = .squad
                searchedPlayer = SearchedPlayer(id: athlete.id)
            }
        case .offer:
            if let offer = career.offers.first(where: { "offer-\($0.id)" == item.id }),
               let message = career.inbox.last(where: { $0.offerID == offer.id }) {
                openMessage(message.id)
            } else { openApp = .market }
        case .event: openApp = .alerts
        case .commitment:
            openApp = .squad
            if let entity = item.entityID { searchedPlayer = SearchedPlayer(id: entity) }
        }
    }

    private func startLiveMatch() {
        if career.offseason != nil {
            alertMessage = "Termine a pré-temporada antes da estreia."
            return
        }
        if career.liveMatch == nil && !career.beginMatchDay() {
            alertMessage = "Não foi possível iniciar a partida. Confira a escalação e tente novamente."
            return
        }
        showLiveMatch = true
    }

    private var continueSubtitle: String? {
        guard let club = career.selectedClub else { return nil }
        return "\(club.name) · temporada \(career.season)"
    }

    private func startNewFromTitle() {
        if career.selectedClubID == nil {
            showsTitle = false
        } else {
            confirmsNewGame = true
        }
    }

    private func confirmNewGame() {
        let store = FootballSaveStore()
        if let slot = (0..<FootballSaveStore.slotCount).first(where: { $0 != activeSlot && store.summary(slot: $0) == nil }) {
            startNewCareer(slot: slot)
            showsTitle = false
        } else {
            alertMessage = "Todos os espaços de carreira estão ocupados. Apague uma carreira em Opções para começar outra."
        }
    }

    private func startNewCareer(slot: Int) {
        if capture == nil { FootballSaveStore().save(career, slot: activeSlot) }
        activeSlot = slot
        FootballSaveStore().activeSlot = slot
        career = FootballCareer(seed: FactoryCapture.isUITesting ? 26 : FootballCareer.randomSeed())
        openApp = nil
        lastDayKey = dayKey
        dayTransition = nil
        refreshSlots()
    }

    private func startChallenge(_ scenario: ChallengeScenario) {
        if capture == nil { FootballSaveStore().save(career, slot: activeSlot) }
        let store = FootballSaveStore()
        let target = (0..<FootballSaveStore.slotCount).first { $0 != activeSlot && store.summary(slot: $0) == nil } ?? activeSlot
        activeSlot = target
        store.activeSlot = target
        career = FootballCareer.challenge(scenario)
        openApp = nil
        lastDayKey = dayKey
        dayTransition = nil
        refreshSlots()
    }

    private func loadSlot(_ slot: Int) {
        guard slot != activeSlot else { return }
        let store = FootballSaveStore()
        if capture == nil { store.save(career, slot: activeSlot) }
        activeSlot = slot
        store.activeSlot = slot
        career = store.load(slot: slot) ?? FootballCareer(seed: FootballCareer.randomSeed())
        openApp = nil
        lastDayKey = dayKey
        dayTransition = nil
        refreshSlots()
    }

    private func deleteSlot(_ slot: Int) {
        guard slot != activeSlot else { return }
        FootballSaveStore().delete(slot: slot)
        refreshSlots()
    }

    private func refreshSlots() {
        let store = FootballSaveStore()
        slotSummaries = (0..<FootballSaveStore.slotCount).map { store.summary(slot: $0) }
    }

    /// Carrega o slot ativo, trazendo antes o save antigo do UserDefaults, se existir.
    static func initialCareer() -> FootballCareer {
        if FactoryCapture.isUITesting || FactoryCapture.screen != nil { return FootballCareer(seed: 26) }
        let store = FootballSaveStore()
        store.migrateLegacyDefaults()
        return store.load(slot: store.activeSlot) ?? FootballCareer(seed: FootballCareer.randomSeed())
    }

    private func prepareInitialState() {
        guard !didPrepare else { return }
        didPrepare = true
        if FactoryCapture.isUITesting {
            FactoryCapture.resetAppDefaults()
            FootballSaveStore().deleteAll()
            activeSlot = 0
            career = FootballCareer(seed: 26)
            openApp = nil
            refreshSlots()
            return
        }
        guard let capture else {
            refreshSlots()
            return
        }
        if capture == "select" {
            career = FootballCareer(seed: 26)
            return
        }
        career = Self.previewCareer(liveMatch: Self.liveMatchCaptures.contains(capture))
        FootballF4Captures.prepare(capture, career: &career)
        FootballF5Captures.prepare(capture, career: &career)
        if capture == "season-end" {
            // Fim de temporada: todas as rodadas jogadas, antes de abrir a próxima.
            var guardDays = 0
            while !career.isSeasonComplete, guardDays < FootballSeason.matchDaysPerSeason + 4 {
                guardDays += 1
                if career.canPlay || career.canAdvanceWithoutPlaying { career.simulateNextMatchDay(); career.skipPress() } else { break }
            }
        }
        if capture == "agenda" || capture == "commitment" { career.simulateNextMatchDay() }
        if capture == "chat-player" || capture == "chat-family" || capture == "chat-staff" { prepareChatCapture(capture) }
        if capture == "inbox-followup", let athlete = career.clubRoster.first(where: { !career.startingXI.contains($0.id) && !$0.isYouth }) {
            // Promessa quebrada: veredito, conversa de acompanhamento e memória do atleta.
            _ = career.promiseStarts(playerID: athlete.id)
            career.matchDayIndex += 20
            career.evaluatePromises(started: [])
        }
        if capture == "public-sphere" {
            career.matchDayIndex = max(career.matchDayIndex, 6)
            career.ensureProfiles()
            _ = career.publishPost(draft: PostDraft(tone: .provocative, subject: .rival(2)))
            career.matchDayIndex += 1
            career.advancePublicSphere()
            career.recordPublicMemory(id: "demo-praise", kind: .praise, text: "Elogio público ao grupo depois da vitória.", weight: 1)
        }
        if capture == "story-arc", let star = career.clubRoster.max(by: { $0.overall < $1.overall }) {
            career.matchDayIndex = max(career.matchDayIndex, 6)
            if let arc = career.openRumorArc(playerID: star.id, truth: true) {
                career.matchDayIndex += FootballCareer.arcUpdateDay
                career.advanceArcs()
                _ = career.askArcInfo(arc.id)
            }
        }
        if capture == "tactical-plans" {
            career.setPlayStyle(.defensive)
            career.saveTacticalPlan(.a)
            career.setPlayStyle(.attacking)
            career.teamInstructions.tempo = .high
            career.teamInstructions.lineHeight = .high
            career.saveTacticalPlan(.b)
        }
        if capture == "press" {
            var guardCount = 0
            while career.pendingPress == nil, guardCount < 8 {
                if career.canPlay || career.canAdvanceWithoutPlaying { career.simulateNextMatchDay() }
                guardCount += 1
            }
        }
        slotSummaries = [
            SaveSlotSummary(slot: 0, clubID: career.selectedClubID, season: career.season, matchDay: career.matchDayIndex,
                            division: career.userDivision, updatedAt: Date()),
            SaveSlotSummary(slot: 1, clubID: 11, season: 4, matchDay: 12, division: .serieB, updatedAt: Date().addingTimeInterval(-86_400)),
            nil
        ]
        switch capture {
        case "table": openApp = .league
        case "cup":
            tableSection = .cup
            openApp = .league
        case "squad": openApp = .squad
        case "market": openApp = .market
        case "club": openApp = .club
        case "world", "phone": openApp = nil
        case "betting": openApp = .betting
        case "social": openApp = .social
        case "fantasy": openApp = .fantasy
        case "lifestyle": openApp = .life
        case "business": openApp = .business
        case "quests": openApp = .quests
        case "events": openApp = .alerts
        case "finance": openApp = .bank
        case "inbox": openApp = .messages
        case "achievements": openApp = .trophies
        case "growth": openApp = .brand
        case "contacts": openApp = .contacts
        case "settings": openApp = .settings
        case "agenda", "season-end": openApp = .manager
        case "commitment", "inbox-followup": openApp = .messages
        case "lock": locked = true
        case "lock-night":
            let from = career.latestUserFixture?.matchDay ?? max(0, career.matchDayIndex - 1)
            dayTransition = PhoneDayTransition(fromSeason: career.season, fromMatchDay: from, toSeason: career.season, toMatchDay: career.matchDayIndex)
            locked = true
        case "wallpaper-night":
            momentOverride = .matchNight
            openApp = nil
        case "guide-banner":
            openApp = nil
            guideSuggestion = career.nextBestAction()
        case "notifications": showNotifications = true
        case "spotlight":
            searchSeed = "Aur"
            showSearch = true
        default: openApp = .manager
        }
    }

    /// Carreira de demonstração para capturas: uma temporada completa e oito dias de jogo da seguinte.
    static func previewCareer(liveMatch: Bool) -> FootballCareer {
        var preview = FootballCareer(seed: 26)
        _ = preview.chooseClub(0)
        for _ in 0..<FootballSeason.matchDaysPerSeason { preview.simulateNextMatchDay() }
        preview.startNextSeason()
        if preview.isFired, let job = preview.jobOffers.first { preview.acceptJob(job.id) }
        for _ in 0..<8 { preview.simulateNextMatchDay() }
        var eventRandom = FootballRandom(seed: 77)
        var attempts = 0
        while preview.pendingEvents.isEmpty && attempts < 30 {
            preview.generateWorldEvent(using: &eventRandom)
            attempts += 1
        }
        preview.claimDailyBonus()
        preview.doActivity(.tvPunditry)
        preview.publishPost(tone: .humor)
        if let reserve = preview.clubRoster.first(where: { !preview.startingXI.contains($0.id) }) {
            preview.addInbox(.playerPlayingTime, title: "\(reserve.name) quer jogar mais", body: "Quero uma oportunidade nos próximos jogos. Podemos combinar minha participação?", playerID: reserve.id)
            _ = preview.promiseStarts(playerID: reserve.id, starts: 2)
        }
        let suggestion = preview.suggestedFantasyLineup()
        preview.setFantasyLineup(ids: suggestion.ids, captainID: suggestion.captainID)
        if let fixture = preview.bettingFixtures.first,
           let option = preview.options(for: fixture).first(where: { $0.leg.market == .over25 }) {
            preview.placeBet(stake: 50, legs: [option.leg])
        }
        if liveMatch {
            while !preview.canPlay && preview.canAdvanceWithoutPlaying { preview.simulateNextMatchDay() }
            preview.beginMatchDay()
        }
        return preview
    }
}

// MARK: - Início de carreira: nome e seis propostas

struct FootballClubSelectionView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var coachName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Nova carreira",
                title: "Seu primeiro contrato",
                subtitle: "Diga como você se chama e escolha entre seis propostas. Orçamento, meta, paciência da diretoria e pressão da torcida mudam a dificuldade da sua carreira.",
                accent: FootballTheme.accent
            )
            FactoryPanel(title: "Treinador", systemImage: "person.text.rectangle.fill") {
                TextField("Seu nome", text: $coachName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .font(.title3.weight(.semibold))
                    .padding(12)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("coach-name-field")
                    .onChange(of: coachName) { _, value in
                        if value.count > FootballCareer.coachNameLimit { coachName = String(value.prefix(FootballCareer.coachNameLimit)) }
                    }
                Text("Aparece nas redes, na imprensa e nos contratos.").font(.caption).foregroundStyle(.secondary)
            }
            FactoryDemoNotice(message: "Liga, clubes e atletas fictícios")
            Text("PROPOSTAS").font(.caption.weight(.heavy)).tracking(1.4).foregroundStyle(.secondary)
            let offers = career.careerOffers()
            ForEach(Array(offers.enumerated()), id: \.element.id) { index, offer in
                if let club = FootballSeason.team(offer.clubID) {
                    Button {
                        if !career.acceptCareerOffer(clubID: offer.clubID, coachName: coachName) {
                            onAlert("Não foi possível fechar esta proposta.")
                        } else if !FactoryCapture.isUITesting {
                            // A primeira lenda chega junto com o contrato; os UI tests mantêm o Gestor como sempre foi.
                            career.grantStartingIconPack()
                        }
                    } label: {
                        offerCard(offer, club: club)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("choose-offer-\(index)")
                    .accessibilityLabel("Proposta do \(club.name), dificuldade \(offer.difficulty) de 5, orçamento \(FootballFormat.money(offer.budget))")
                }
            }
        }
        .factoryPage()
        .navigationTitle("Nova carreira")
    }

    private func offerCard(_ offer: CareerOffer, club: LeagueTeam) -> some View {
        let division = career.division(of: club.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ClubCrest(team: club, size: 46)
                VStack(alignment: .leading, spacing: 4) {
                    Text(club.name).font(.headline).foregroundStyle(.primary)
                    Text("\(club.city) · \(club.stadium)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    HStack(spacing: 6) {
                        PillLabel(text: division.name, tint: division.tint)
                        PillLabel(text: "FOR \(club.strength)", tint: club.primaryColor)
                    }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 1) {
                        ForEach(0..<5, id: \.self) { Image(systemName: $0 < offer.difficulty ? "flame.fill" : "flame").font(.caption2) }
                    }
                    .foregroundStyle(offer.difficulty >= 4 ? Color.red : (offer.difficulty >= 3 ? Color.orange : Color.green))
                    Text(["", "Tranquilo", "Moderado", "Exigente", "Difícil", "Extremo"][offer.difficulty]).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                }
            }
            Text(offer.pitch).font(.subheadline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    term("Orçamento", FootballFormat.money(offer.budget))
                    term("Meta", FootballCareer.objectiveText(target: offer.boardTarget, division: division))
                }
                GridRow {
                    term("Contrato", "\(offer.contractSeasons) temporada(s)")
                    term("Luvas", FootballFormat.money(offer.signingBonus))
                }
                GridRow {
                    term("Diretoria", offer.patienceBonus >= 5 ? "Paciente" : (offer.patienceBonus < 0 ? "Impaciente" : "Normal"))
                    term("Torcida", offer.fanMood >= 60 ? "Tranquila" : (offer.fanMood >= 48 ? "Exigente" : "Pressionando"))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22, style: .continuous)
                .fill(club.primaryColor)
                .frame(width: 5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func term(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(2).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
