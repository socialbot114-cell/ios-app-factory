import SwiftUI

enum FootballTab: Int, CaseIterable, Identifiable {
    case dashboard, squad, table, market, club

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Painel"
        case .squad: return "Elenco"
        case .table: return "Liga"
        case .market: return "Mercado"
        case .club: return "Clube"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "house.fill"
        case .squad: return "person.3.fill"
        case .table: return "list.number"
        case .market: return "arrow.left.arrow.right"
        case .club: return "trophy.fill"
        }
    }
}

struct FootballHome: View {
    @State private var career = FootballHome.initialCareer()
    @State private var activeSlot = FootballSaveStore().activeSlot
    @State private var slotSummaries: [SaveSlotSummary?] = []
    @State private var tableSection: FootballTableView.LeagueSection?
    @State private var selectedTab: FootballTab = .dashboard
    @State private var alertMessage: String?
    @State private var showLiveMatch = false
    @State private var seasonSummary: SeasonRecord?
    @State private var didPrepare = false

    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        Group {
            if capture == "match", career.liveMatch != nil {
                FootballLiveMatchView(career: $career, staticPreview: true) { }
            } else {
                navigationContent
            }
        }
        .tint(FootballTheme.accent)
        .fullScreenCover(isPresented: $showLiveMatch) {
            FootballLiveMatchView(career: $career, staticPreview: false) { showLiveMatch = false }
        }
        .sheet(item: $seasonSummary) { record in
            FootballSeasonSummaryView(record: record, career: career)
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
        .onChange(of: career) { _, updatedCareer in
            guard capture == nil else { return }
            FootballSaveStore().save(updatedCareer, slot: activeSlot)
            refreshSlots()
        }
    }

    private var navigationContent: some View {
        NavigationStack {
            content
                .safeAreaInset(edge: .bottom) {
                    if career.selectedClubID != nil && capture != "match" { tabBar }
                }
                .toolbar {
                    if let club = career.selectedClub, capture != "match" {
                        ToolbarItem(placement: .principal) { toolbarTitle(club) }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var content: some View {
        if career.selectedClubID == nil {
            FootballClubSelectionView(career: $career, onAlert: showAlert)
        } else {
            switch selectedTab {
            case .dashboard:
                FootballDashboardView(
                    career: $career,
                    onPlayLive: startLiveMatch,
                    onAlert: showAlert,
                    onSeasonEnded: { seasonSummary = $0 },
                    onNavigate: { selectedTab = $0 }
                )
            case .squad:
                FootballSquadView(career: $career, onAlert: showAlert)
            case .table:
                FootballTableView(career: career, initialSection: tableSection)
            case .market:
                FootballMarketView(career: $career, onAlert: showAlert)
            case .club:
                FootballClubView(
                    career: $career,
                    activeSlot: activeSlot,
                    slotSummaries: slotSummaries,
                    onLoadSlot: loadSlot,
                    onNewCareer: startNewCareer,
                    onDeleteSlot: deleteSlot
                )
            }
        }
    }

    private func toolbarTitle(_ club: LeagueTeam) -> some View {
        HStack(spacing: 6) {
            ClubCrest(team: club, size: 18)
            Text(club.name.uppercased())
            Text("· T\(career.season) · SEM. \(career.currentSlot?.week ?? FootballSeason.calendar.last?.week ?? 1)")
                .foregroundStyle(.secondary)
        }
        .font(.caption.weight(.bold))
        .tracking(0.8)
        .accessibilityElement(children: .combine)
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(FootballTab.allCases) { tab in
                Button { selectedTab = tab } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol).font(.system(size: 16, weight: .semibold))
                        Text(tab.title).font(.system(size: 10, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(selectedTab == tab ? FootballTheme.accent : .secondary)
                    .background(selectedTab == tab ? FootballTheme.accent.opacity(0.12) : .clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab-\(tab.rawValue)")
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
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
        selectedTab = .dashboard
        refreshSlots()
    }

    private func loadSlot(_ slot: Int) {
        guard slot != activeSlot else { return }
        let store = FootballSaveStore()
        if capture == nil { store.save(career, slot: activeSlot) }
        activeSlot = slot
        store.activeSlot = slot
        career = store.load(slot: slot) ?? FootballCareer(seed: FootballCareer.randomSeed())
        selectedTab = .dashboard
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
            selectedTab = .dashboard
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
        case "table": selectedTab = .table
        case "cup":
            tableSection = .cup
            selectedTab = .table
        case "squad": selectedTab = .squad
        case "market": selectedTab = .market
        case "club": selectedTab = .club
        default: selectedTab = .dashboard
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
        if liveMatch {
            while !preview.canPlay && preview.canAdvanceWithoutPlaying { preview.simulateNextMatchDay() }
            preview.beginMatchDay()
        }
        return preview
    }
}

// MARK: - Escolha de clube

struct FootballClubSelectionView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Nova carreira",
                title: "Escolha seu clube",
                subtitle: "Vinte clubes em duas divisões, uma copa nacional e uma carreira sem fim. Comande cada partida ao vivo, tudo offline e com salvamento automático.",
                accent: FootballTheme.accent
            )
            FactoryDemoNotice(message: "Liga, clubes e atletas fictícios")
            ForEach(Division.allCases) { division in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(division.name.uppercased())
                            .font(.caption.weight(.heavy)).tracking(1.4)
                            .foregroundStyle(division.tint)
                        Spacer()
                        Text(division == .serieA ? "Brigue pelo título" : "Desafio: conquiste o acesso")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(FootballSeason.teams.filter { career.division(of: $0.id) == division }) { club in
                        Button {
                            if !career.chooseClub(club.id) {
                                onAlert("Não foi possível montar o elenco inicial deste clube.")
                            }
                        } label: {
                            clubCard(club)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("choose-club-\(club.id)")
                        .accessibilityLabel("Escolher \(club.name), \(division.name), força \(club.strength), orçamento \(FootballFormat.money(club.startingBudget))")
                    }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Escolha do clube")
    }

    private func clubCard(_ club: LeagueTeam) -> some View {
        HStack(spacing: 14) {
            ClubCrest(team: club, size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(club.name).font(.headline).foregroundStyle(.primary)
                Text("\(club.city) · \(club.stadium)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 6) {
                    PillLabel(text: "FOR \(club.strength)", tint: club.primaryColor)
                    PillLabel(text: FootballFormat.money(club.startingBudget), systemImage: "banknote", tint: .secondary)
                    PillLabel(text: club.preferredStyle.rawValue, tint: .secondary)
                }
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22, style: .continuous)
                .fill(club.primaryColor)
                .frame(width: 5)
        }
    }
}
