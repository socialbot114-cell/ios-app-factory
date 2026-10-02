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
    @State private var career = FootballCareer.load()
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
            if capture == nil { updatedCareer.persist() }
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
                FootballTableView(career: career)
            case .market:
                FootballMarketView(career: $career, onAlert: showAlert)
            case .club:
                FootballClubView(career: $career, onNewCareer: startNewCareer)
            }
        }
    }

    private func toolbarTitle(_ club: LeagueTeam) -> some View {
        HStack(spacing: 6) {
            ClubCrest(team: club, size: 18)
            Text(club.name.uppercased())
            Text("· T\(career.season) · R\(min(career.currentRound + 1, FootballSeason.roundsPerSeason))")
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

    private func startNewCareer() {
        career = FootballCareer(seed: FactoryCapture.isUITesting ? 26 : FootballCareer.randomSeed())
        selectedTab = .dashboard
    }

    private func prepareInitialState() {
        guard !didPrepare else { return }
        didPrepare = true
        if FactoryCapture.isUITesting {
            FactoryCapture.resetAppDefaults()
            career = FootballCareer(seed: 26)
            selectedTab = .dashboard
            return
        }
        guard let capture else { return }
        if capture == "select" {
            career = FootballCareer(seed: 26)
            return
        }
        career = Self.previewCareer(liveMatch: capture == "match")
        switch capture {
        case "table": selectedTab = .table
        case "squad": selectedTab = .squad
        case "market": selectedTab = .market
        case "club": selectedTab = .club
        default: selectedTab = .dashboard
        }
    }

    /// Carreira de demonstração para capturas: uma temporada completa e três rodadas da seguinte.
    static func previewCareer(liveMatch: Bool) -> FootballCareer {
        var preview = FootballCareer(seed: 26)
        _ = preview.chooseClub(0)
        for _ in 0..<FootballSeason.roundsPerSeason { preview.simulateNextRound() }
        preview.startNextSeason()
        if preview.isFired, let job = preview.jobOffers.first { preview.acceptJob(job.id) }
        for _ in 0..<3 { preview.simulateNextRound() }
        if liveMatch { preview.beginMatchDay() }
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
                subtitle: "Oito clubes, um título. Monte o elenco, defina a tática e comande cada partida ao vivo. Tudo offline, com salvamento automático.",
                accent: FootballTheme.accent
            )
            FactoryDemoNotice(message: "Liga, clubes e atletas fictícios")
            ForEach(FootballSeason.teams) { club in
                Button {
                    if !career.chooseClub(club.id) {
                        onAlert("Não foi possível montar o elenco inicial deste clube.")
                    }
                } label: {
                    clubCard(club)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("choose-club-\(club.id)")
                .accessibilityLabel("Escolher \(club.name), força \(club.strength), orçamento \(FootballFormat.money(club.startingBudget))")
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
                Text("\(club.city) · \(club.preferredFormation.rawValue) · \(club.preferredStyle.rawValue)")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    PillLabel(text: "FOR \(club.strength)", tint: club.primaryColor)
                    PillLabel(text: FootballFormat.money(club.startingBudget), systemImage: "banknote", tint: .secondary)
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
