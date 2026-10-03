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
    @State private var didPrepare = false
    @State private var showPress = false
    @State private var booting = !(FactoryCapture.isUITesting || FactoryCapture.screen != nil)
    @State private var locked = !(FactoryCapture.isUITesting || FactoryCapture.screen != nil)
    @State private var showNotifications = false
    @State private var showSearch = false
    @State private var searchSeed = ""
    @State private var searchedPlayer: SearchedPlayer?
    @Environment(\.scenePhase) private var scenePhase

    struct SearchedPlayer: Identifiable { let id: Int }

    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        Group {
            if capture == "match", career.liveMatch != nil {
                FootballLiveMatchView(career: $career, staticPreview: true) { }
            } else if let capture, Self.deepCaptures.contains(capture) {
                NavigationStack { deepCapture(capture).tint(FootballTheme.accent) }
            } else if booting {
                PhoneBootView()
            } else if career.selectedClubID == nil {
                NavigationStack { FootballClubSelectionView(career: $career, onAlert: showAlert) }
            } else {
                phone
            }
        }
        .tint(FootballTheme.accent)
        .fullScreenCover(isPresented: $showLiveMatch) {
            FootballLiveMatchView(career: $career, staticPreview: false) { showLiveMatch = false }
        }
        .sheet(item: $seasonSummary) { record in
            FootballSeasonSummaryView(record: record, career: career)
        }
        .sheet(isPresented: $showPress) {
            FootballPressView(career: $career)
        }
        .sheet(isPresented: $showNotifications) {
            PhoneNotificationCenter(career: career) { app in openApp = app }
        }
        .sheet(isPresented: $showSearch) {
            PhoneSpotlight(career: career, initialQuery: searchSeed, onApp: { openApp = $0 }, onPlayer: { searchedPlayer = SearchedPlayer(id: $0) })
        }
        .sheet(item: $searchedPlayer) { selection in
            FootballPlayerDetailView(career: $career, playerID: selection.id, onAlert: showAlert)
        }
        .alert("Manager de Futebol", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear(perform: prepareInitialState)
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
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    showPress = true
                }
            }
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
                            onSearch: { searchSeed = ""; showSearch = true })
                .accessibilityHidden(openApp != nil || locked)
            if let app = openApp {
                appWindow(app)
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                    .zIndex(1)
            }
            if locked {
                PhoneLockScreen(career: career) { withAnimation(.easeOut(duration: 0.3)) { locked = false } }
                    .transition(.move(edge: .top))
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: openApp)
    }

    private func open(_ app: PhoneApp) {
        openApp = app
    }

    private func closeApp() {
        openApp = nil
    }

    private func appWindow(_ app: PhoneApp) -> some View {
        NavigationStack {
            appContent(app)
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
                onShowPress: { showPress = true }
            )
        case .squad:
            FootballSquadView(career: $career, onAlert: showAlert)
        case .league:
            FootballTableView(career: career, initialSection: tableSection)
                .onAppear { career.markTutorialSeen("table") }
        case .market:
            FootballMarketView(career: $career, onAlert: showAlert)
                .onAppear { career.markTutorialSeen("market") }
        case .club:
            FootballClubView(
                career: $career,
                onAlert: showAlert,
                onStartChallenge: startChallenge,
                activeSlot: activeSlot,
                slotSummaries: slotSummaries,
                onLoadSlot: loadSlot,
                onNewCareer: startNewCareer,
                onDeleteSlot: deleteSlot
            )
            .onAppear { career.markTutorialSeen("club") }
        case .messages: FootballInboxView(career: $career, onAlert: showAlert)
        case .social: FootballSocialView(career: $career, onAlert: showAlert)
        case .betting: FootballBettingView(career: $career, onAlert: showAlert)
        case .fantasy: FootballFantasyView(career: $career, onAlert: showAlert)
        case .life: FootballCoachLifeView(career: $career, onAlert: showAlert)
        case .business: FootballBusinessView(career: $career, onAlert: showAlert)
        case .quests: FootballQuestsView(career: $career)
        case .trophies: FootballAchievementsView(career: career)
        case .alerts: FootballEventsView(career: $career)
        case .brand: FootballGrowthView(career: $career, onAlert: showAlert)
        case .bank: FootballFinanceView(career: career)
        case .contacts: FootballContactsView(career: $career, onAlert: showAlert)
        case .settings: FootballModesView(career: $career, onStartChallenge: startChallenge)
        }
    }

    static let deepCaptures: Set<String> = ["betting", "social", "fantasy", "lifestyle", "business", "quests", "events", "finance", "player", "inbox", "achievements", "staff", "growth", "contacts"]

    @ViewBuilder
    private func deepCapture(_ name: String) -> some View {
        switch name {
        case "betting": FootballBettingView(career: $career, onAlert: showAlert)
        case "social": FootballSocialView(career: $career, onAlert: showAlert)
        case "fantasy": FootballFantasyView(career: $career, onAlert: showAlert)
        case "lifestyle": FootballCoachLifeView(career: $career, onAlert: showAlert)
        case "business": FootballBusinessView(career: $career, onAlert: showAlert)
        case "quests": FootballQuestsView(career: $career)
        case "events": FootballEventsView(career: $career)
        case "finance": FootballFinanceView(career: career)
        case "inbox": FootballInboxView(career: $career, onAlert: showAlert)
        case "achievements": FootballAchievementsView(career: career)
        case "staff": FootballStaffView(career: $career, onAlert: showAlert)
        case "growth": FootballGrowthView(career: $career, onAlert: showAlert)
        case "contacts": FootballContactsView(career: $career, onAlert: showAlert)
        default:
            FootballPlayerDetailView(career: $career, playerID: career.startingXI.first ?? 0, onAlert: showAlert)
        }
    }

    private func showAlert(_ message: String) {
        alertMessage = message
    }

    private func startLiveMatch() {
        if career.liveMatch == nil && !career.beginMatchDay() {
            alertMessage = "Não foi possível iniciar a partida. Confira a escalação e tente novamente."
            return
        }
        showLiveMatch = true
    }

    private func startNewCareer(slot: Int) {
        if capture == nil { FootballSaveStore().save(career, slot: activeSlot) }
        activeSlot = slot
        FootballSaveStore().activeSlot = slot
        career = FootballCareer(seed: FactoryCapture.isUITesting ? 26 : FootballCareer.randomSeed())
        openApp = nil
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
        career = Self.previewCareer(liveMatch: capture == "match")
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
        case "lock": locked = true
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
