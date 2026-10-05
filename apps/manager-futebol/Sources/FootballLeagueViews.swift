import SwiftUI

// MARK: - Liga

struct FootballTableView: View {
    let career: FootballCareer
    @State private var section: LeagueSection
    @State private var serieARound: Int?
    @State private var serieBRound: Int?

    enum LeagueSection: String, CaseIterable, Identifiable {
        case serieA = "Série A"
        case serieB = "Série B"
        case cup = "Copa"
        case scorers = "Artilharia"

        var id: String { rawValue }
    }

    init(career: FootballCareer, initialSection: LeagueSection? = nil) {
        self.career = career
        let fallback: LeagueSection = career.userDivision == .serieB ? .serieB : .serieA
        _section = State(initialValue: initialSection ?? fallback)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Temporada \(career.season) · \(career.completedLeagueRounds) de \(FootballSeason.leagueRounds) rodadas",
                title: section == .cup ? "Copa Nacional" : (section == .scorers ? "Artilharia" : "Classificação"),
                subtitle: subtitle,
                accent: FootballTheme.accent
            )
            Picker("Seção", selection: $section) {
                ForEach(LeagueSection.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("league-section")
            switch section {
            case .serieA: divisionPanels(.serieA)
            case .serieB: divisionPanels(.serieB)
            case .cup: cupPanel
            case .scorers: scorersPanel
            }
        }
        .factoryPage()
        .navigationTitle("Liga")
    }

    private var subtitle: String {
        switch section {
        case .serieA: return "Os 2 últimos caem para a Série B. Pontos, vitórias, saldo e gols marcados definem a ordem."
        case .serieB: return "Os 2 primeiros sobem para a Série A."
        case .cup: return "Mata-mata em jogo único no meio de semana. Empate vai à prorrogação e aos pênaltis."
        case .scorers: return "Gols em todas as competições da temporada."
        }
    }

    // MARK: Divisões

    private func divisionPanels(_ division: Division) -> some View {
        let rows = career.standings(for: division)
        return VStack(alignment: .leading, spacing: 18) {
            FactoryPanel {
                HStack(spacing: 4) {
                    Text("#").frame(width: 20, alignment: .leading)
                    Text("CLUBE").frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(["J", "V", "E", "D", "SG"], id: \.self) { title in
                        Text(title).frame(width: Self.numberWidth, alignment: .trailing)
                    }
                    Text("PTS").frame(width: Self.pointsWidth, alignment: .trailing)
                }
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.secondary)
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    Divider()
                    NavigationLink {
                        FootballLeagueClubProfile(career: career, team: row.team)
                    } label: {
                        standingRow(index: index, row: row, division: division)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("league-club-\(row.team.id)")
                }
                HStack(spacing: 12) {
                    if division == .serieA {
                        legend(color: FootballTheme.gold, text: "Líder")
                        legend(color: .red, text: "Rebaixamento")
                    } else {
                        legend(color: .green, text: "Acesso")
                    }
                    legend(color: FootballTheme.accent, text: "Seu clube")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            FootballLeagueInsightPanel(career: career, division: division)
            let fixtures = career.fixtures.filter { $0.competition == .league(division) }
            let rounds = Array(Set(fixtures.map(\.round))).sorted()
            let defaultRound = fixtures.filter { $0.isPlayed }.map(\.round).max() ?? rounds.first ?? 1
            let selection = division == .serieA ? $serieARound : $serieBRound
            let selectedRound = rounds.contains(selection.wrappedValue ?? defaultRound) ? (selection.wrappedValue ?? defaultRound) : defaultRound
            if !rounds.isEmpty {
                FactoryPanel(title: "Jogos · rodada \(selectedRound)", systemImage: "calendar") {
                    HStack {
                        Button { selection.wrappedValue = rounds.last { $0 < selectedRound } } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(selectedRound == rounds.first)
                        .accessibilityLabel("Rodada anterior")
                        Picker("Rodada", selection: Binding(get: { selectedRound }, set: { selection.wrappedValue = $0 })) {
                            ForEach(rounds, id: \.self) { round in
                                Text("Rodada \(round)").tag(round)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("league-round-picker")
                        Button { selection.wrappedValue = rounds.first { $0 > selectedRound } } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(selectedRound == rounds.last)
                        .accessibilityLabel("Próxima rodada")
                    }
                    roundList(fixtures.filter { $0.round == selectedRound })
                }
            } else {
                Text("O calendário desta divisão ainda não está disponível.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private static let numberWidth: CGFloat = 24
    private static let pointsWidth: CGFloat = 32

    private func zoneColor(index: Int, division: Division) -> Color? {
        let count = FootballSeason.teamsPerDivision
        if division == .serieA {
            if index == 0 { return FootballTheme.gold }
            if index >= count - FootballSeason.relegationSpots { return .red }
        } else if index < FootballSeason.relegationSpots {
            return .green
        }
        return nil
    }

    private func standingRow(index: Int, row: FootballStanding, division: Division) -> some View {
        let isUser = row.team.id == career.selectedClubID
        let numbers = [row.played, row.wins, row.draws, row.losses]
        let zone = zoneColor(index: index, division: division)
        return HStack(spacing: 4) {
            Text("\(index + 1)")
                .font(.caption.weight(.heavy).monospacedDigit())
                .foregroundStyle(zone ?? .secondary)
                .frame(width: 20, alignment: .leading)
            HStack(spacing: 8) {
                ClubCrest(team: row.team, size: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.team.name)
                        .font(.subheadline.weight(isUser ? .heavy : .semibold))
                        .foregroundStyle(isUser ? FootballTheme.accent : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    FormBadges(results: row.form)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(numbers.enumerated()), id: \.offset) { _, value in
                Text("\(value)").frame(width: Self.numberWidth, alignment: .trailing)
            }
            Text(FootballFormat.signed(row.goalDifference)).frame(width: Self.numberWidth, alignment: .trailing)
            Text("\(row.points)")
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .frame(width: Self.pointsWidth, alignment: .trailing)
        }
        .font(.caption.monospacedDigit())
        .padding(.vertical, 2)
        .overlay(alignment: .leading) {
            if let zone {
                Capsule().fill(zone).frame(width: 3).offset(x: -8)
            }
        }
        .background(isUser ? FootballTheme.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(index + 1)º \(row.team.name), \(row.points) pontos, \(row.played) jogos, saldo \(row.goalDifference)")
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
    }

    // MARK: Copa

    private var cupPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let winner = career.cupWinnerThisSeason, let team = FootballSeason.team(winner) {
                HStack(spacing: 12) {
                    ClubCrest(team: team, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Campeão da Copa").font(.caption.weight(.bold)).foregroundStyle(FootballTheme.gold)
                        Text(team.name).font(.title3.bold())
                    }
                    Spacer()
                    Image(systemName: "trophy.fill").font(.title).foregroundStyle(FootballTheme.gold)
                }
                .padding(16)
                .background(FootballTheme.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            Label(career.userCupStatus, systemImage: "flag.fill")
                .font(.subheadline.weight(.semibold))
            ForEach(CupRound.allCases.reversed(), id: \.self) { round in
                let ties = career.cupFixtures.filter { $0.competition == .cup(round) }
                if !ties.isEmpty {
                    FactoryPanel(title: round.name, systemImage: round == .final ? "trophy" : "rectangle.split.2x1") {
                        roundList(ties)
                    }
                }
            }
            let pending = CupRound.allCases.filter { round in !career.cupFixtures.contains { $0.competition == .cup(round) } }
            if !pending.isEmpty {
                Text("Próximas fases: \(pending.map(\.name).joined(separator: ", ")). O sorteio acontece ao fim de cada fase.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("cup-bracket")
    }

    // MARK: Listas

    private var scorersPanel: some View {
        let scorers = career.topScorers(limit: 15)
        return FactoryPanel(title: "Artilheiros", systemImage: "soccerball") {
            if scorers.isEmpty {
                Text("Ninguém marcou ainda nesta temporada.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(Array(scorers.enumerated()), id: \.element.id) { index, player in
                NavigationLink {
                    FootballLeaguePlayerProfile(career: career, player: player)
                } label: {
                HStack(spacing: 10) {
                    Text("\(index + 1)").font(.caption.weight(.heavy).monospacedDigit()).foregroundStyle(.secondary).frame(width: 20)
                    if let teamID = player.teamID, let team = FootballSeason.team(teamID) {
                        ClubCrest(team: team, size: 22)
                    } else {
                        Image(systemName: "person.crop.circle.badge.questionmark").foregroundStyle(.secondary).frame(width: 22)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name).font(.subheadline.weight(.semibold))
                            .foregroundStyle(player.teamID == career.selectedClubID ? FootballTheme.accent : .primary)
                        Text("\(player.position.rawValue) · \(player.appearances) jogos · \(player.assists) assist.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(player.goals)").font(.title3.weight(.heavy).monospacedDigit())
                }
                .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("league-scorer-\(player.id)")
                if index < scorers.count - 1 { Divider() }
            }
        }
    }

    fileprivate func roundList(_ fixtures: [LeagueFixture]) -> some View {
        VStack(spacing: 12) {
            ForEach(fixtures) { fixture in
                NavigationLink {
                    FootballLeagueMatchDetail(career: career, fixture: fixture)
                } label: {
                VStack(spacing: 3) {
                    HStack(spacing: 8) {
                        teamLabel(fixture.home, alignment: .trailing, isWinner: fixture.competition.isCup && fixture.winner == fixture.home)
                        Group {
                            if let home = fixture.homeGoals, let away = fixture.awayGoals {
                                Text("\(home) – \(away)")
                            } else {
                                Text("×").foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline.weight(.heavy).monospacedDigit())
                        .frame(width: 56)
                        teamLabel(fixture.away, alignment: .leading, isWinner: fixture.competition.isCup && fixture.winner == fixture.away)
                    }
                    if let penalties = fixture.penaltySummary {
                        Text(penalties).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    } else if fixture.wentToExtraTime {
                        Text("após prorrogação").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .background(fixture.involves(career.selectedClubID ?? -1) ? FootballTheme.accent.opacity(0.08) : .clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("league-match-\(fixture.id)")
            }
        }
    }

    private func teamLabel(_ teamID: Int, alignment: HorizontalAlignment, isWinner: Bool) -> some View {
        let team = FootballSeason.team(teamID)
        return HStack(spacing: 6) {
            if alignment == .trailing { Spacer(minLength: 0) }
            if alignment == .leading, let team { ClubCrest(team: team, size: 20) }
            Text(team?.name ?? "—")
                .font(isWinner ? Font.caption.weight(.heavy) : Font.caption.weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.7)
            if alignment == .trailing, let team { ClubCrest(team: team, size: 20) }
            if alignment == .leading { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Clube

private struct FootballLeagueMatchDetail: View {
    let career: FootballCareer
    let fixture: LeagueFixture

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(fixture.competition.name) · rodada \(fixture.round) · dia \(fixture.matchDay + 1)")
                .font(.subheadline).foregroundStyle(.secondary)
            FactoryPanel(title: fixture.isPlayed ? "Relatório da partida" : "Partida agendada", systemImage: "soccerball") {
                FootballMatchReport(fixture: fixture, career: career, showAllEvents: true)
                if let penalties = fixture.penaltySummary {
                    Text(penalties).font(.subheadline.weight(.semibold))
                } else if fixture.wentToExtraTime {
                    Text("Após prorrogação").font(.subheadline)
                }
                if !fixture.isPlayed {
                    Text("O resultado e os eventos estarão disponíveis após a partida.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if fixture.events.isEmpty && fixture.commentary.isEmpty {
                    Text("Não há lances detalhados registrados para esta partida.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let impact = fixture.impact {
                MatchImpactCard(impact: impact, hypeTitle: "")
            }
            FactoryPanel(title: "Clubes", systemImage: "shield") {
                ForEach([fixture.home, fixture.away], id: \.self) { teamID in
                    if let team = FootballSeason.team(teamID) {
                        NavigationLink(team.name) { FootballLeagueClubProfile(career: career, team: team) }
                    }
                }
            }
        }
        .factoryPage()
        .navigationTitle(fixture.isPlayed ? "Relatório" : "Pré-jogo")
    }
}

private struct FootballLeaguePlayerProfile: View {
    let career: FootballCareer
    let player: FootballPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Ficha de consulta", title: player.name,
                          subtitle: "\(player.position.rawValue) · \(player.age) anos", accent: FootballTheme.accent)
            if let teamID = player.teamID, let team = FootballSeason.team(teamID) {
                NavigationLink { FootballLeagueClubProfile(career: career, team: team) } label: {
                    HStack { ClubCrest(team: team, size: 32); Text(team.name); Spacer(); Image(systemName: "chevron.right") }
                }
                .buttonStyle(.plain)
            } else {
                Text("Sem clube").foregroundStyle(.secondary)
            }
            FactoryPanel(title: "Temporada · todas as competições", systemImage: "soccerball") {
                LabeledContent("Jogos", value: "\(player.appearances)")
                LabeledContent("Gols", value: "\(player.goals)")
                LabeledContent("Assistências", value: "\(player.assists)")
            }
            FactoryPanel(title: "Perfil atual", systemImage: "person.fill") {
                LabeledContent("Geral", value: "\(player.overall)")
                LabeledContent("Condição", value: "\(player.condition)%")
                LabeledContent("Moral", value: "\(player.morale)%")
                LabeledContent("Valor de mercado", value: FootballFormat.money(player.marketValue))
                if player.isInjured { Text("Lesionado · \(player.injuryRounds) jogo(s)").foregroundStyle(.red) }
                if player.isSuspended { Text("Suspenso").foregroundStyle(.red) }
            }
        }
        .factoryPage()
        .navigationTitle("Atleta")
    }
}

private struct FootballLeagueClubProfile: View {
    let career: FootballCareer
    let team: LeagueTeam

    private var fixtures: [LeagueFixture] {
        career.fixtures.filter { $0.involves(team.id) }
            .sorted { $0.matchDay == $1.matchDay ? $0.id < $1.id : $0.matchDay < $1.matchDay }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ClubCrest(team: team, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name).font(.title2.bold())
                    Text("\(team.city) · \(career.division(of: team.id).name)").font(.subheadline).foregroundStyle(.secondary)
                    Text(team.stadium).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let row = career.standings(for: career.division(of: team.id)).first(where: { $0.team.id == team.id }) {
                FactoryPanel(title: "Forma na liga", systemImage: "chart.line.uptrend.xyaxis") {
                    Text("\(row.points) pontos · \(row.played) jogos · saldo \(FootballFormat.signed(row.goalDifference))")
                    if row.form.isEmpty { Text("Ainda sem resultados na liga.").foregroundStyle(.secondary) }
                    FormBadges(results: row.form)
                }
            }
            FactoryPanel(title: "Elenco", systemImage: "person.3.fill") {
                let players = career.players.filter { $0.teamID == team.id }.sorted {
                    $0.overall == $1.overall ? $0.id < $1.id : $0.overall > $1.overall
                }
                if players.isEmpty { Text("Nenhum atleta registrado neste clube.").foregroundStyle(.secondary) }
                ForEach(players) { player in
                    NavigationLink { FootballLeaguePlayerProfile(career: career, player: player) } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(player.name).font(.subheadline.weight(.semibold))
                                Text("\(player.position.rawValue) · \(player.age) anos").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("GER \(player.overall)").font(.caption.bold())
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            FactoryPanel(title: "Calendário da temporada", systemImage: "calendar") {
                if fixtures.isEmpty { Text("Nenhuma partida agendada.").foregroundStyle(.secondary) }
                ForEach(fixtures) { fixture in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(fixture.competition.name) · rodada \(fixture.round) · dia \(fixture.matchDay + 1) · \(fixture.isPlayed ? "Disputada" : "Agendada")")
                            .font(.caption).foregroundStyle(.secondary)
                        FootballTableView(career: career).roundList([fixture])
                    }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Ficha do clube")
    }
}

struct FootballClubView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    let onStartChallenge: (ChallengeScenario) -> Void
    let activeSlot: Int
    let slotSummaries: [SaveSlotSummary?]
    let onLoadSlot: (Int) -> Void
    let onNewCareer: (Int) -> Void
    let onDeleteSlot: (Int) -> Void
    @State private var pendingAction: SlotAction?

    enum SlotAction: Identifiable {
        case replace(Int)
        case delete(Int)

        var id: String {
            switch self {
            case .replace(let slot): return "replace-\(slot)"
            case .delete(let slot): return "delete-\(slot)"
            }
        }
    }

    private var leagueTitles: Int {
        career.history.filter { $0.championID == $0.clubID }.count
    }

    private var cupTitles: Int {
        career.history.filter { $0.cupWinnerID == $0.clubID }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let club = career.selectedClub {
                HStack(spacing: 16) {
                    ClubCrest(team: club, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(club.name).font(.title.bold())
                        Text("\(club.city) · \(club.stadium) · \(club.capacity.formatted(.number.locale(Locale(identifier: "pt_BR")))) lugares")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if let division = career.userDivision {
                            PillLabel(text: division.name, tint: division.tint)
                        }
                    }
                }
                FactoryPanel(title: "Estádio", systemImage: "sportscourt.fill") {
                    Image("StadiumPilot")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .accessibilityLabel("Ilustração isométrica de um estádio de futebol")
                    HStack {
                        Label(career.stadiumDisplayName, systemImage: "mappin.and.ellipse")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(career.stadiumCapacity.formatted(.number.locale(Locale(identifier: "pt_BR")))) lugares")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 12) {
                    FactoryMetric(label: "Títulos da Série A", value: "\(leagueTitles)", symbol: "trophy.fill", tint: FootballTheme.gold)
                    FactoryMetric(label: "Copas", value: "\(cupTitles)", symbol: "trophy", tint: FootballTheme.gold)
                    FactoryMetric(label: "Temporadas", value: "\(career.history.count)", symbol: "calendar", tint: FootballTheme.accent)
                }
                managementPanel
                FactoryPanel(title: "Diretoria", systemImage: "building.columns.fill") {
                    HStack {
                        Text("Meta").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text(career.objectiveText).font(.subheadline.weight(.semibold))
                    }
                    HStack {
                        Text("Confiança").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(career.boardConfidence)%").font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    ConditionBar(value: career.boardConfidence)
                    Text("Vitórias acima do esperado e clássicos vencidos aumentam a confiança. Terminar abaixo da meta com confiança baixa leva à demissão.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                FootballBoardMeetingPanel(career: $career, onAlert: onAlert)
                FactoryPanel(title: "Histórico do treinador", systemImage: "clock.arrow.circlepath") {
                    if career.history.isEmpty {
                        Text("Sua primeira temporada ainda está em andamento.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(career.history.reversed()) { record in
                        historyRow(record)
                        if record.id != career.history.first?.id { Divider() }
                    }
                }
                FactoryPanel(title: "Galeria de campeões", systemImage: "trophy") {
                    if career.history.isEmpty {
                        Text("Os primeiros campeões serão conhecidos ao fim da temporada.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(career.history.reversed()) { record in
                        HStack(spacing: 10) {
                            Text("T\(record.season)").font(.caption.weight(.heavy).monospacedDigit()).foregroundStyle(.secondary).frame(width: 30)
                            championLabel(title: "Série A", teamID: record.championID, isUser: record.championID == record.clubID)
                            Spacer(minLength: 4)
                            if let cupWinner = record.cupWinnerID {
                                championLabel(title: "Copa", teamID: cupWinner, isUser: cupWinner == record.clubID)
                            }
                        }
                    }
                }
                savesPanel
                FactoryDemoNotice(message: "Clubes, atletas e competições fictícios")
            }
        }
        .factoryPage()
        .navigationTitle("Clube")
        .confirmationDialog(dialogTitle, isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }),
                            titleVisibility: .visible) {
            switch pendingAction {
            case .replace(let slot):
                Button("Começar nova carreira", role: .destructive) { onNewCareer(slot) }
            case .delete(let slot):
                Button("Apagar carreira", role: .destructive) { onDeleteSlot(slot) }
            case .none:
                EmptyView()
            }
            Button("Cancelar", role: .cancel) { pendingAction = nil }
        } message: {
            Text("Essa ação não pode ser desfeita.")
        }
    }

    private func link<Destination: View>(_ title: String, _ symbol: String, badge: Int = 0, id: String,
                                          @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 28).foregroundStyle(FootballTheme.accent)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer()
                if badge > 0 {
                    Text("\(badge)").font(.caption2.weight(.heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3).background(Color.red, in: Capsule())
                }
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var managementPanel: some View {
        FactoryPanel(title: "Gestão do clube", systemImage: "briefcase.fill") {
            link("Finanças", "banknote.fill", id: "club-finance") { FootballFinanceView(career: $career, onAlert: onAlert) }
            Divider()
            link("Estrutura e ingressos", "building.2.fill", id: "club-facilities") { FootballFacilitiesView(career: $career, onAlert: onAlert) }
            Divider()
            link("Comissão técnica", "person.2.fill", id: "club-staff") { FootballStaffView(career: $career, onAlert: onAlert) }
            Divider()
            link("Marketing, TV e cotas", "tv.and.mediabox.fill", id: "club-growth") { FootballGrowthView(career: $career, onAlert: onAlert) }
            Divider()
            link("Patrocínio", "megaphone.fill", id: "club-sponsor") { FootballSponsorView(career: $career, onAlert: onAlert) }
            Divider()
            link("História, recordes e convites", "list.star", badge: career.invitations.count, id: "club-story") { FootballStoryView(career: $career, onAlert: onAlert) }
            Divider()
            link("Modos de jogo e tutorial", "dial.medium.fill", id: "club-modes") { FootballModesView(career: $career, onStartChallenge: onStartChallenge) }
        }
    }

    private var dialogTitle: String {
        switch pendingAction {
        case .replace(let slot): return "Substituir a carreira do espaço \(slot + 1)?"
        case .delete(let slot): return "Apagar a carreira do espaço \(slot + 1)?"
        case .none: return ""
        }
    }

    private var savesPanel: some View {
        FactoryPanel(title: "Carreiras salvas", systemImage: "externaldrive.fill") {
            Text("Até \(FootballSaveStore.slotCount) carreiras ao mesmo tempo. O progresso é salvo automaticamente.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(0..<FootballSaveStore.slotCount, id: \.self) { slot in
                slotRow(slot)
                if slot < FootballSaveStore.slotCount - 1 { Divider() }
            }
        }
    }

    private func slotRow(_ slot: Int) -> some View {
        let summary = slotSummaries.indices.contains(slot) ? slotSummaries[slot] : nil
        let team = summary?.clubID.flatMap { FootballSeason.team($0) }
        let isActive = slot == activeSlot
        return HStack(spacing: 12) {
            if let team {
                ClubCrest(team: team, size: 30)
            } else {
                Image(systemName: "plus.circle").font(.title2).foregroundStyle(.secondary).frame(width: 30)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(team?.name ?? (summary == nil ? "Espaço \(slot + 1) vazio" : "Carreira sem clube"))
                    .font(.subheadline.weight(.semibold))
                if let summary {
                    Text("Temporada \(summary.season) · \(summary.division?.name ?? "—") · \(summary.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if isActive {
                PillLabel(text: "EM JOGO", systemImage: "gamecontroller.fill")
                Button { pendingAction = .replace(slot) } label: { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Começar nova carreira neste espaço")
                    .accessibilityIdentifier("new-career")
            } else if summary != nil {
                Button("Carregar") { onLoadSlot(slot) }
                    .buttonStyle(.borderedProminent)
                    .font(.caption.weight(.bold))
                    .accessibilityIdentifier("load-slot-\(slot)")
                Button(role: .destructive) { pendingAction = .delete(slot) } label: { Image(systemName: "trash") }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Apagar carreira do espaço \(slot + 1)")
            } else {
                Button("Nova") { onNewCareer(slot) }
                    .buttonStyle(.bordered)
                    .font(.caption.weight(.bold))
                    .accessibilityIdentifier("new-slot-\(slot)")
            }
        }
    }

    private func championLabel(title: String, teamID: Int, isUser: Bool) -> some View {
        HStack(spacing: 6) {
            if let team = FootballSeason.team(teamID) { ClubCrest(team: team, size: 20) }
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(FootballSeason.teamName(teamID)).font(.caption.weight(isUser ? .heavy : .semibold))
                    .foregroundStyle(isUser ? FootballTheme.gold : .primary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    private func historyRow(_ record: SeasonRecord) -> some View {
        HStack(spacing: 12) {
            Text("T\(record.season)").font(.caption.weight(.heavy).monospacedDigit()).foregroundStyle(.secondary).frame(width: 30)
            if let team = FootballSeason.team(record.clubID) { ClubCrest(team: team, size: 26) }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(record.position)º na \(record.division.name) · \(record.points) pts").font(.subheadline.weight(.semibold))
                Text(historyNote(record))
                    .font(.caption)
                    .foregroundStyle(record.objectiveMet ? .green : .red)
                Text("Copa: \(record.cupResult)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if record.championID == record.clubID || record.cupWinnerID == record.clubID {
                Image(systemName: "trophy.fill").foregroundStyle(FootballTheme.gold)
            } else if record.promoted {
                Image(systemName: "arrow.up.circle.fill").foregroundStyle(.green)
            } else if record.relegated {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.red)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func historyNote(_ record: SeasonRecord) -> String {
        var parts = [record.objectiveMet ? "Meta cumprida" : "Meta não cumprida"]
        if record.promoted { parts.append("acesso") }
        if record.relegated { parts.append("rebaixado") }
        if record.wasFired { parts.append("demitido") }
        return parts.joined(separator: " · ")
    }
}
