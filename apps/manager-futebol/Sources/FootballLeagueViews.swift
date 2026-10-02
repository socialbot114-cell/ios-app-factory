import SwiftUI

// MARK: - Liga

struct FootballTableView: View {
    let career: FootballCareer
    @State private var section: LeagueSection = .table

    enum LeagueSection: String, CaseIterable, Identifiable {
        case table = "Classificação"
        case scorers = "Artilharia"
        case rounds = "Rodadas"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Liga · temporada \(career.season)",
                title: "Classificação",
                subtitle: "Pontos, vitórias, saldo e gols marcados definem a ordem.",
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
            case .table: standingsPanel
            case .scorers: scorersPanel
            case .rounds: roundsPanel
            }
        }
        .factoryPage()
        .navigationTitle("Liga")
    }

    private var standingsPanel: some View {
        let rows = career.standings
        return FactoryPanel {
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
                standingRow(index: index, row: row)
            }
            HStack(spacing: 12) {
                legend(color: FootballTheme.gold, text: "Líder")
                legend(color: FootballTheme.accent, text: "Seu clube")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private static let numberWidth: CGFloat = 24
    private static let pointsWidth: CGFloat = 32

    private func standingRow(index: Int, row: FootballStanding) -> some View {
        let isUser = row.team.id == career.selectedClubID
        let numbers = [row.played, row.wins, row.draws, row.losses]
        return HStack(spacing: 4) {
            Text("\(index + 1)")
                .font(.caption.weight(.heavy).monospacedDigit())
                .foregroundStyle(index == 0 ? FootballTheme.gold : .secondary)
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

    private var scorersPanel: some View {
        let scorers = career.topScorers(limit: 12)
        return FactoryPanel(title: "Artilheiros", systemImage: "soccerball") {
            if scorers.isEmpty {
                Text("Ninguém marcou ainda nesta temporada.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(Array(scorers.enumerated()), id: \.element.id) { index, player in
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
                if index < scorers.count - 1 { Divider() }
            }
        }
    }

    private var roundsPanel: some View {
        let lastRound = career.currentRound
        let nextRound = career.isSeasonComplete ? nil : career.currentRound + 1
        return VStack(alignment: .leading, spacing: 18) {
            if lastRound > 0 {
                FactoryPanel(title: "Resultados · rodada \(lastRound)", systemImage: "checkmark.circle.fill") {
                    roundList(career.fixtures.filter { $0.round == lastRound })
                }
            } else {
                FactoryPanel(title: "Resultados", systemImage: "checkmark.circle") {
                    Text("Nenhuma partida disputada nesta temporada.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if let nextRound {
                FactoryPanel(title: "Próxima rodada · \(nextRound)", systemImage: "calendar") {
                    roundList(career.fixtures.filter { $0.round == nextRound })
                }
            }
        }
    }

    private func roundList(_ fixtures: [LeagueFixture]) -> some View {
        VStack(spacing: 12) {
            ForEach(fixtures) { fixture in
                HStack(spacing: 8) {
                    teamLabel(fixture.home, alignment: .trailing)
                    Group {
                        if let home = fixture.homeGoals, let away = fixture.awayGoals {
                            Text("\(home) – \(away)")
                        } else {
                            Text("×").foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline.weight(.heavy).monospacedDigit())
                    .frame(width: 56)
                    teamLabel(fixture.away, alignment: .leading)
                }
                .padding(.vertical, 4)
                .background(fixture.involves(career.selectedClubID ?? -1) ? FootballTheme.accent.opacity(0.08) : .clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func teamLabel(_ teamID: Int, alignment: HorizontalAlignment) -> some View {
        let team = FootballSeason.team(teamID)
        return HStack(spacing: 6) {
            if alignment == .trailing { Spacer(minLength: 0) }
            if alignment == .leading, let team { ClubCrest(team: team, size: 20) }
            Text(team?.name ?? "—").font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            if alignment == .trailing, let team { ClubCrest(team: team, size: 20) }
            if alignment == .leading { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mercado

struct FootballMarketView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var filter: FootballPosition?
    @State private var pendingSigning: FootballPlayer?

    private var visiblePlayers: [FootballPlayer] {
        career.marketPlayers.filter { filter == nil || $0.position == filter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let club = career.selectedClub {
                FactoryHeader(
                    eyebrow: "Mercado de agentes livres",
                    title: "Reforce o \(club.name)",
                    subtitle: "O mercado é renovado a cada temporada. Propostas dos rivais pelos seus atletas aparecem aqui e no painel.",
                    accent: FootballTheme.accent
                )
                HStack(spacing: 12) {
                    FactoryMetric(label: "Disponível", value: FootballFormat.money(career.transferBudget), symbol: "wallet.bifold.fill", tint: FootballTheme.accent)
                    FactoryMetric(label: "Vagas ocupadas", value: "\(career.clubRoster.count)/\(FootballCareer.rosterLimit)", symbol: "person.3.fill", tint: .orange)
                }
                if !career.offers.isEmpty {
                    FootballOffersPanel(career: $career, onAlert: onAlert)
                }
                Picker("Posição", selection: $filter) {
                    Text("Todos").tag(FootballPosition?.none)
                    ForEach(FootballPosition.allCases, id: \.self) { position in
                        Text(position.rawValue).tag(FootballPosition?.some(position))
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("market-filter")
                FactoryPanel(title: "Agentes livres · \(visiblePlayers.count)", systemImage: "person.crop.circle.badge.plus") {
                    if visiblePlayers.isEmpty {
                        Text("Nenhum atleta disponível com este filtro.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(visiblePlayers) { player in
                        HStack(spacing: 10) {
                            PlayerRow(player: player, showValue: true)
                            Button {
                                pendingSigning = player
                            } label: {
                                Image(systemName: "plus").font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!career.canSign(playerID: player.id))
                            .accessibilityLabel("Contratar \(player.name)")
                            .accessibilityIdentifier("contract-player-\(player.id)")
                        }
                        if player.id != visiblePlayers.last?.id { Divider() }
                    }
                    Text(career.clubRoster.count >= FootballCareer.rosterLimit
                         ? "Elenco completo. Venda um atleta para abrir vaga."
                         : "Contratações exigem vaga no elenco e saldo suficiente.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .factoryPage()
        .navigationTitle("Mercado")
        .confirmationDialog(
            "Contratar \(pendingSigning?.name ?? "atleta")?",
            isPresented: Binding(get: { pendingSigning != nil }, set: { if !$0 { pendingSigning = nil } }),
            titleVisibility: .visible
        ) {
            if let player = pendingSigning {
                Button("Contratar por \(FootballFormat.money(player.marketValue))") {
                    if !career.signPlayer(playerID: player.id) {
                        onAlert("Não foi possível contratar: confira o orçamento e as vagas no elenco.")
                    }
                    pendingSigning = nil
                }
            }
            Button("Cancelar", role: .cancel) { pendingSigning = nil }
        } message: {
            Text("O valor sai do caixa de transferências.")
        }
    }
}

// MARK: - Clube

struct FootballClubView: View {
    @Binding var career: FootballCareer
    let onNewCareer: () -> Void
    @State private var confirmNewCareer = false

    private var titles: Int {
        career.history.filter { $0.championID == $0.clubID }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let club = career.selectedClub {
                HStack(spacing: 16) {
                    ClubCrest(team: club, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(club.name).font(.title.bold())
                        Text("\(club.city) · temporada \(career.season)").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    FactoryMetric(label: "Títulos do treinador", value: "\(titles)", symbol: "trophy.fill", tint: FootballTheme.gold)
                    FactoryMetric(label: "Temporadas", value: "\(career.history.count)", symbol: "calendar", tint: FootballTheme.accent)
                }
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
                    Text("Vitórias acima do esperado aumentam a confiança. Terminar a temporada abaixo da meta com confiança baixa leva à demissão.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                FactoryPanel(title: "Histórico do treinador", systemImage: "clock.arrow.circlepath") {
                    if career.history.isEmpty {
                        Text("Sua primeira temporada ainda está em andamento.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(career.history.reversed()) { record in
                        historyRow(record)
                        if record.id != career.history.first?.id { Divider() }
                    }
                }
                .accessibilityIdentifier("club-history")
                FactoryPanel(title: "Campeões da liga", systemImage: "trophy") {
                    if career.champions.isEmpty {
                        Text("O primeiro campeão será conhecido ao fim da temporada.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(Array(career.champions.enumerated().reversed()), id: \.offset) { index, championID in
                        if let champion = FootballSeason.team(championID) {
                            HStack(spacing: 10) {
                                Text("T\(index + 1)").font(.caption.weight(.heavy).monospacedDigit()).foregroundStyle(.secondary).frame(width: 30)
                                ClubCrest(team: champion, size: 22)
                                Text(champion.name).font(.subheadline.weight(.semibold))
                                Spacer()
                                if championID == career.history.first(where: { $0.season == index + 1 })?.clubID {
                                    PillLabel(text: "SEU TÍTULO", systemImage: "star.fill", tint: FootballTheme.gold)
                                }
                            }
                        }
                    }
                }
                FactoryPanel(title: "Carreira", systemImage: "gearshape.fill") {
                    Text("O progresso é salvo automaticamente neste aparelho. Clubes, atletas e competições são fictícios.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(role: .destructive) { confirmNewCareer = true } label: {
                        Label("Começar nova carreira", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("new-career")
                }
            }
        }
        .factoryPage()
        .navigationTitle("Clube")
        .confirmationDialog("Começar uma nova carreira?", isPresented: $confirmNewCareer, titleVisibility: .visible) {
            Button("Apagar carreira e começar de novo", role: .destructive, action: onNewCareer)
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("O save atual será substituído e não poderá ser recuperado.")
        }
    }

    private func historyRow(_ record: SeasonRecord) -> some View {
        HStack(spacing: 12) {
            Text("T\(record.season)").font(.caption.weight(.heavy).monospacedDigit()).foregroundStyle(.secondary).frame(width: 30)
            if let team = FootballSeason.team(record.clubID) { ClubCrest(team: team, size: 26) }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(record.position)º lugar · \(record.points) pts").font(.subheadline.weight(.semibold))
                Text(record.objectiveMet ? "Meta cumprida" : (record.wasFired ? "Demitido" : "Meta não cumprida"))
                    .font(.caption)
                    .foregroundStyle(record.objectiveMet ? .green : .red)
            }
            Spacer()
            if record.championID == record.clubID {
                Image(systemName: "trophy.fill").foregroundStyle(FootballTheme.gold)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
