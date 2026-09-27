import SwiftUI

@main
struct ManagerFutebolApp: App {
    var body: some Scene { WindowGroup { FootballHome() } }
}

struct FootballHome: View {
    @State private var career = FootballCareerStore.load()
    @State private var selectedTab = 0
    @State private var report: FootballRoundReport?
    @State private var didApplyTestReset = false

    private let accent = Color(red: 0.08, green: 0.37, blue: 0.25)
    private var capture: String? { FactoryCapture.screen }
    private var teamsByID: [Int: FootballTeam] { Dictionary(uniqueKeysWithValues: career.teams.map { ($0.id, $0) }) }
    private var userTeam: FootballTeam { career.teams.first(where: { $0.id == career.userTeamID }) ?? career.teams[0] }
    private var nextRound: Int { min(career.completedRounds + 1, FootballGame.numberOfRounds) }
    private var nextFixture: FootballFixture? {
        guard career.completedRounds < FootballGame.numberOfRounds else { return nil }
        return career.fixtures.first {
            $0.round == career.completedRounds + 1
                && ($0.homeTeamID == career.userTeamID || $0.awayTeamID == career.userTeamID)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if capture == "table" || selectedTab == 1 {
                    tableView
                } else if capture == "squad" || selectedTab == 2 {
                    squadView
                } else if capture == "market" || selectedTab == 3 {
                    marketView
                } else {
                    dashboard
                }
            }
            .safeAreaInset(edge: .bottom) { navigationBar }
        }
        .tint(accent)
        .onAppear {
            if (FactoryCapture.isUITesting || capture != nil) && !didApplyTestReset {
                if FactoryCapture.isUITesting { FactoryCapture.resetAppDefaults() }
                career = FootballGame.newCareer()
                if capture == "table" {
                    for _ in 0..<4 { _ = FootballGame.simulateNextRound(career: &career) }
                }
                if capture == "table" { selectedTab = 1 }
                else if capture == "squad" { selectedTab = 2 }
                else if capture == "market" { selectedTab = 3 }
                else { selectedTab = 0 }
                didApplyTestReset = true
            }
            if shouldPersistCareer { FootballCareerStore.save(career) }
        }
        .onChange(of: career) { _, updatedCareer in
            if shouldPersistCareer { FootballCareerStore.save(updatedCareer) }
        }
        .sheet(item: $report) { matchReport in
            FootballReportView(report: matchReport, teamsByID: teamsByID)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 20) {
            FactoryHeader(
                eyebrow: "Carreira offline · temporada \(career.seasonNumber)",
                title: "Treinador, sua jornada começa aqui.",
                subtitle: "Monte seu time, escolha como jogar e leve o Aurora FC ao topo da liga.",
                accent: accent
            )
            FactoryDemoNotice(message: "Clubes e atletas fictícios · carreira salva neste aparelho")

            FactoryPanel {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(career.completedRounds == FootballGame.numberOfRounds ? "TEMPORADA ENCERRADA" : "PRÓXIMA PARTIDA")
                            .font(.caption.bold()).tracking(1.2).foregroundStyle(.secondary)
                        if let nextFixture {
                            Text(fixtureTitle(nextFixture))
                                .font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                            Text("Rodada \(nextRound) de \(FootballGame.numberOfRounds) · \(venueDescription(for: nextFixture))")
                                .font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            Text("\(userTeam.name) concluiu a temporada")
                                .font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                            Text(seasonOutcomeDescription)
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: career.completedRounds == FootballGame.numberOfRounds ? "trophy.fill" : "sportscourt.fill")
                        .font(.largeTitle).foregroundStyle(accent)
                }

                Button(action: primaryAction) {
                    Label(primaryActionTitle, systemImage: career.completedRounds == FootballGame.numberOfRounds ? "arrow.clockwise" : "play.fill")
                }
                .accessibilityIdentifier("simulate-round")
                .buttonStyle(FactoryPrimaryButtonStyle())
                .disabled(!canRunPrimaryAction)

                if career.completedRounds < FootballGame.numberOfRounds {
                    Text("Sua escalação e abordagem tática afetam a partida. Os outros jogos da rodada são simulados automaticamente.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                FactoryMetric(label: "Seu clube", value: userTeam.name, symbol: "shield.fill", tint: accent)
                FactoryMetric(label: "Campanha", value: "\(career.completedRounds) / \(FootballGame.numberOfRounds)", symbol: "calendar", tint: .orange)
            }

            FactoryPanel(title: "Plano de jogo", systemImage: "slider.horizontal.3") {
                HStack {
                    Label(career.formation.rawValue, systemImage: "rectangle.3.group.fill")
                    Spacer()
                    Text(career.approach.rawValue).foregroundStyle(.secondary)
                }
                Text("\(career.startingLineup.count) titulares · condição física dos atletas considerada")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Ajustar elenco e tática") { selectedTab = 2 }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("open-squad")
            }

            // Fase 1: próximos jogos + último resultado com estatísticas (ver docs/roadmap.md).
            FactoryPanel(title: "Próximos jogos", systemImage: "calendar") {
                let upcoming = FootballGame.upcomingFixtures(for: career, limit: 3)
                if upcoming.isEmpty {
                    Text("Temporada concluída. Inicie a próxima para ver o novo calendário.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(upcoming) { fixture in
                        Text("R\(fixture.round) · \(fixtureTitle(fixture))")
                            .font(.subheadline)
                    }
                }
            }

            if let latestReport {
                FactoryPanel(title: "Rodada \(latestReport.round) · resultado", systemImage: "checkmark.circle") {
                    if let result = latestReport.userFixture.result {
                        Text(scoreline(latestReport.userFixture, result: result))
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Finalizações: \(result.homeShots) — \(result.awayShots) · Posse: \(result.homePossession)% — \(100 - result.homePossession)%")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("A classificação já considera os quatro jogos da rodada.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Ver resumo da rodada") { report = latestReport }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("open-match-report")
                }
            }

            if let summary = career.history.last {
                FactoryPanel(title: "Temporada anterior", systemImage: "trophy") {
                    Text("\(summary.championName) foi campeão. \(userTeam.name) terminou em \(summary.userPosition)º com \(summary.userPoints) pontos.")
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }

            FactoryPanel(title: "Finanças do clube", systemImage: "banknote") {
                HStack {
                    Text("Saldo disponível")
                    Spacer()
                    Text(money(career.budget)).font(.headline.monospacedDigit().bold()).foregroundStyle(accent)
                }
                Button("Abrir mercado de transferências") { selectedTab = 3 }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("open-market")
            }
        }
        .factoryPage()
        .navigationTitle("Painel do treinador")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tableView: some View {
        let standings = FootballGame.standings(for: career)
        let latestRound = career.fixtures.filter { $0.round == career.completedRounds && $0.result != nil }

        return VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Temporada \(career.seasonNumber) · rodada \(career.completedRounds)",
                title: "Classificação",
                subtitle: "Pontos → vitórias → saldo de gols → gols marcados → nome do clube.",
                accent: accent
            )
            FactoryDemoNotice(message: "Resultados disputados e tabela salvos localmente")

            FactoryPanel(title: career.completedRounds == 0 ? "A temporada vai começar" : "Resultados da última rodada", systemImage: "checkmark.circle") {
                if latestRound.isEmpty {
                    Text("Dispute a primeira rodada para ver os resultados e a tabela ganhar vida.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(latestRound) { fixture in
                        if let result = fixture.result {
                            Text(scoreline(fixture, result: result))
                                .font(.caption.weight(fixture.homeTeamID == career.userTeamID || fixture.awayTeamID == career.userTeamID ? .bold : .regular))
                                .lineLimit(2).minimumScaleFactor(0.75)
                        }
                    }
                }
            }

            // Fase 1: tabela completa J/V/E/D + GP/GC/SG + forma recente (ver docs/roadmap.md).
            FactoryPanel {
                HStack {
                    Text("#   CLUBE").font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text("J  V  E  D  P").font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary)
                }
                ForEach(Array(standings.enumerated()), id: \.element.teamID) { index, row in
                    HStack(spacing: 9) {
                        Text(String(format: "%02d", index + 1))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(row.teamID == career.userTeamID ? accent : .secondary)
                            .frame(width: 26, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.teamName).font(.subheadline.weight(.semibold))
                            Text("\(row.city) · GP \(row.goalsFor) · GC \(row.goalsAgainst) · SG \(signed(row.goalDifference))")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text("Forma: \(FootballGame.recentForm(teamID: row.teamID, in: career).joined(separator: " "))")
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Text("\(row.played)  \(row.wins)  \(row.draws)  \(row.losses)  \(row.points)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .frame(width: 116, alignment: .trailing)
                    }
                    if index < standings.count - 1 { Divider() }
                }
            }

            // Fase 1: artilharia da temporada a partir do log real de gols.
            FactoryPanel(title: "Artilharia", systemImage: "soccerball") {
                let scorers = FootballGame.topScorers(in: career, limit: 5)
                if scorers.isEmpty {
                    Text("Nenhum gol registrado ainda. Dispute a primeira rodada.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(scorers.enumerated()), id: \.element.player.id) { index, entry in
                        HStack {
                            Text("\(index + 1)º").font(.caption.monospacedDigit().bold()).foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.player.name).font(.subheadline.weight(.semibold))
                                Text(entry.teamName).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(entry.goals) gols").font(.subheadline.monospacedDigit().bold()).foregroundStyle(accent)
                        }
                        if index < scorers.count - 1 { Divider() }
                    }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Classificação")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var squadView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "\(userTeam.city) · temporada \(career.seasonNumber)",
                title: userTeam.name,
                subtitle: "Escolha quem começa e como o time vai jogar. As decisões alteram o desempenho e o desgaste físico.",
                accent: accent
            )
            FactoryDemoNotice(message: "Elenco fictício · 16 atletas · progresso salvo offline")

            FactoryPanel(title: "Formação", systemImage: "rectangle.3.group.fill") {
                Picker("Formação", selection: formationBinding) {
                    ForEach(FootballFormation.allCases) { formation in
                        Text(formation.rawValue).tag(formation)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("formation-picker")

                Picker("Abordagem", selection: $career.approach) {
                    ForEach(FootballApproach.allCases) { approach in
                        Text(approach.rawValue).tag(approach)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("approach-picker")

                HStack {
                    Label(career.approachDescription, systemImage: approachSymbol)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(career.startingLineup.count)/11 titulares")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(isLineupValid ? accent : .orange)
                }

                Button("Escalar melhor time") { career.startingLineup = FootballGame.suggestedLineup(team: userTeam, formation: career.formation) }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("auto-lineup")
            }

            ForEach(FootballPosition.allCases) { position in
                let players = userTeam.players.filter { $0.position == position }.sorted {
                    $0.overall == $1.overall ? $0.name < $1.name : $0.overall > $1.overall
                }
                FactoryPanel(title: "\(position.title) · \(selectedCount(for: position))/\(career.formation.requirements[position, default: 0]) titulares", systemImage: "person.2.fill") {
                    ForEach(players) { player in
                        playerRow(player)
                        if player.id != players.last?.id { Divider() }
                    }
                }
            }

            Button(action: primaryAction) {
                Label("Jogar próxima partida", systemImage: "play.fill")
            }
            .accessibilityIdentifier("play-next-match")
            .buttonStyle(FactoryPrimaryButtonStyle())
            .disabled(!isLineupValid || career.completedRounds >= FootballGame.numberOfRounds)
        }
        .factoryPage()
        .navigationTitle("Elenco e tática")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var marketView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Carreira offline · temporada \(career.seasonNumber)",
                title: "Mercado",
                subtitle: "Reforce o Aurora FC com atletas fictícios. Contratações e vendas ficam salvas na carreira.",
                accent: accent
            )
            FactoryDemoNotice(message: "Janela local de transferências · sem conexão ou compras externas")

            FactoryPanel(title: "Orçamento e elenco", systemImage: "banknote") {
                HStack {
                    Text("Saldo de transferências")
                    Spacer()
                    Text(money(career.budget)).font(.headline.monospacedDigit().bold()).foregroundStyle(accent)
                }
                HStack {
                    Text("Atletas no elenco")
                    Spacer()
                    Text("\(userTeam.players.count)/18").font(.subheadline.monospacedDigit().bold())
                }
                Text(transferWindowOpen ? "A janela fecha quando a primeira partida for disputada." : "A janela reabre no início da próxima temporada.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if transferWindowOpen {
                FactoryPanel(title: "Agentes disponíveis · \(career.marketPlayers.count)", systemImage: "person.crop.rectangle.stack") {
                    if career.marketPlayers.isEmpty {
                        Text("Todos os agentes disponíveis já foram contratados.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(career.marketPlayers.sorted { $0.overall > $1.overall }) { player in
                        marketPlayerRow(player)
                        if player.id != career.marketPlayers.last?.id { Divider() }
                    }
                }

                if userTeam.players.count > 16 {
                    FactoryPanel(title: "Negociar reservas", systemImage: "arrow.left.arrow.right") {
                        Text("Você pode vender atletas contratados que estejam no banco. O elenco base é preservado.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(userTeam.players.filter { $0.id.hasPrefix("FA-") && !career.startingLineup.contains($0.id) }.sorted { $0.overall < $1.overall }) { player in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(player.name).font(.subheadline.weight(.semibold))
                                    Text("\(player.position.rawValue) · nota \(player.overall)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Vender · \(money(FootballGame.saleValue(for: player)))") {
                                    _ = FootballGame.sellPlayer(playerID: player.id, career: &career)
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("sell-\(player.id)")
                            }
                            if player.id != userTeam.players.last?.id { Divider() }
                        }
                    }
                }
            } else {
                FactoryPanel(title: "Janela fechada", systemImage: "calendar.badge.clock") {
                    Text("Conclua a temporada para abrir uma nova janela, receber o bônus anual e encontrar outros agentes.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .factoryPage()
        .navigationTitle("Mercado")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var navigationBar: some View {
        HStack {
            tab("Painel", symbol: "rectangle.grid.1x2.fill", index: 0)
            tab("Tabela", symbol: "list.number", index: 1)
            tab("Elenco", symbol: "person.3.fill", index: 2)
            tab("Mercado", symbol: "arrow.left.arrow.right", index: 3)
        }
        .padding(8)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var latestReport: FootballRoundReport? {
        guard career.completedRounds > 0 else { return nil }
        let fixtures = career.fixtures.filter { $0.round == career.completedRounds }
        guard let userFixture = fixtures.first(where: {
            $0.homeTeamID == career.userTeamID || $0.awayTeamID == career.userTeamID
        }), fixtures.count == FootballGame.matchesPerRound else { return nil }
        return FootballRoundReport(seasonNumber: career.seasonNumber, round: career.completedRounds, userTeamID: career.userTeamID, fixtures: fixtures, userFixture: userFixture)
    }

    private var formationBinding: Binding<FootballFormation> {
        Binding(
            get: { career.formation },
            set: { newFormation in
                career.formation = newFormation
                career.startingLineup = FootballGame.suggestedLineup(team: userTeam, formation: newFormation)
            }
        )
    }

    private var isLineupValid: Bool {
        FootballGame.isValidLineup(career.startingLineup, team: userTeam, formation: career.formation)
    }

    private var transferWindowOpen: Bool { career.completedRounds == 0 }
    private var shouldPersistCareer: Bool { !FactoryCapture.isUITesting && capture == nil }

    private var canRunPrimaryAction: Bool {
        career.completedRounds == FootballGame.numberOfRounds || isLineupValid
    }

    private var primaryActionTitle: String {
        career.completedRounds == FootballGame.numberOfRounds ? "Começar temporada \(career.seasonNumber + 1)" : "Jogar partida · rodada \(nextRound)"
    }

    private var seasonOutcomeDescription: String {
        guard let standing = FootballGame.standings(for: career).first(where: { $0.teamID == career.userTeamID }) else {
            return "Veja a tabela final da temporada."
        }
        let position = FootballGame.standings(for: career).firstIndex(where: { $0.teamID == career.userTeamID }).map { $0 + 1 } ?? 0
        return "\(position)º lugar · \(standing.points) pontos · \(standing.wins) vitórias"
    }

    private var approachSymbol: String {
        switch career.approach {
        case .balanced: return "equal.circle"
        case .attacking: return "arrow.up.forward.circle"
        case .defensive: return "shield.lefthalf.filled"
        }
    }

    private func selectedCount(for position: FootballPosition) -> Int {
        let selected = Set(career.startingLineup)
        return userTeam.players.filter { $0.position == position && selected.contains($0.id) }.count
    }

    private func playerRow(_ player: FootballPlayer) -> some View {
        let isStarter = career.startingLineup.contains(player.id)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name).font(.subheadline.weight(.semibold))
                Text("\(player.position.rawValue) · ATQ \(player.attack) · PAS \(player.passing) · DEF \(player.defense)")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill").foregroundStyle(player.condition < 65 ? .orange : accent)
                    Text("Condição \(player.condition)%")
                    Text("· \(player.age) anos")
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text("\(player.overall)")
                .font(.headline.monospacedDigit().bold())
                .foregroundStyle(accent)
                .frame(width: 34)
                .accessibilityLabel("Nota \(player.overall)")
            Button(isStarter ? "Titular" : "Escalar") { toggleStarter(player) }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(isStarter ? accent : .secondary)
                .accessibilityIdentifier("lineup-\(player.id)")
                .accessibilityLabel("\(isStarter ? "Remover" : "Escalar") \(player.name)")
        }
    }

    private func marketPlayerRow(_ player: FootballPlayer) -> some View {
        let fee = FootballGame.transferFee(for: player)
        let canSign = userTeam.players.count < 18 && career.budget >= fee
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.name).font(.subheadline.weight(.semibold))
                    Text("\(player.position.rawValue) · \(player.age) anos · ATQ \(player.attack) · PAS \(player.passing) · DEF \(player.defense)")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Text("\(player.overall)").font(.headline.monospacedDigit().bold()).foregroundStyle(accent)
            }
            HStack {
                Text("Valor: \(money(fee))").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Button(userTeam.players.count >= 18 ? "Elenco cheio" : (canSign ? "Contratar" : "Sem verba")) {
                    _ = FootballGame.signPlayer(playerID: player.id, career: &career)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .disabled(!canSign)
                .accessibilityIdentifier("sign-\(player.id)")
                .accessibilityLabel("Contratar \(player.name) por \(money(fee))")
            }
        }
    }

    private func toggleStarter(_ player: FootballPlayer) {
        var lineup = Set(career.startingLineup)
        if lineup.contains(player.id) {
            lineup.remove(player.id)
        } else {
            let required = career.formation.requirements[player.position, default: 0]
            let samePosition = userTeam.players.filter { $0.position == player.position && lineup.contains($0.id) }
            guard required > 0 else { return }
            if samePosition.count >= required,
               let replacement = samePosition.min(by: { $0.overall == $1.overall ? $0.id < $1.id : $0.overall < $1.overall }) {
                lineup.remove(replacement.id)
            }
            lineup.insert(player.id)
        }
        career.startingLineup = lineup.sorted()
    }

    private func primaryAction() {
        if career.completedRounds == FootballGame.numberOfRounds {
            _ = FootballGame.startNextSeason(career: &career)
            report = nil
            return
        }
        guard let roundReport = FootballGame.simulateNextRound(career: &career) else { return }
        report = roundReport
    }

    private func fixtureTitle(_ fixture: FootballFixture) -> String {
        "\(teamsByID[fixture.homeTeamID]?.name ?? "Clube")  ×  \(teamsByID[fixture.awayTeamID]?.name ?? "Clube")"
    }

    private func venueDescription(for fixture: FootballFixture) -> String {
        fixture.homeTeamID == career.userTeamID ? "em casa · Estádio Horizonte" : "fora de casa"
    }

    private func scoreline(_ fixture: FootballFixture, result: FootballMatchResult) -> String {
        "\(teamsByID[fixture.homeTeamID]?.name ?? "Clube")  \(result.homeGoals) — \(result.awayGoals)  \(teamsByID[fixture.awayTeamID]?.name ?? "Clube")"
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func money(_ value: Int) -> String {
        String(format: "R$ %.1f mi", locale: Locale(identifier: "pt_BR"), arguments: [Double(value) / 1_000_000])
    }

    private func tab(_ title: String, symbol: String, index: Int) -> some View {
        Button { selectedTab = index } label: {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(selectedTab == index ? accent : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
    }
}

private extension FootballCareer {
    var approachDescription: String {
        switch approach {
        case .balanced: return "Equilíbrio entre construção e proteção"
        case .attacking: return "Mais presença ofensiva · maior desgaste"
        case .defensive: return "Bloco protegido · menos pressão no ataque"
        }
    }
}

private struct FootballReportView: View {
    @Environment(\.dismiss) private var dismiss
    let report: FootballRoundReport
    let teamsByID: [Int: FootballTeam]

    private var userResult: FootballMatchResult? { report.userFixture.result }
    private var userWon: Bool {
        guard let result = userResult else { return false }
        return report.userFixture.homeTeamID == report.userTeamID
            ? result.homeGoals > result.awayGoals
            : result.awayGoals > result.homeGoals
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FactoryHeader(
                        eyebrow: "Temporada \(report.seasonNumber) · rodada \(report.round)",
                        title: "Resumo da rodada",
                        subtitle: "O resultado da sua equipe considera a escalação, a formação e a abordagem escolhidas.",
                        accent: Color(red: 0.08, green: 0.37, blue: 0.25)
                    )

                    if let result = userResult {
                        FactoryPanel(title: "Sua partida", systemImage: userWon ? "trophy.fill" : "sportscourt.fill") {
                            Text(scoreline(report.userFixture, result: result))
                                .font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                            Text(resultCaption(result))
                                .font(.subheadline).foregroundStyle(.secondary)
                            // Fase 1: estatísticas da partida (ver docs/roadmap.md).
                            Text("Finalizações \(result.homeShots) — \(result.awayShots) · Posse \(result.homePossession)% — \(100 - result.homePossession)%")
                                .font(.caption).foregroundStyle(.secondary)
                                .accessibilityIdentifier("match-report-stats")
                            if result.goalEvents.isEmpty {
                                Label("Defesas seguras dos dois lados. Ninguém balançou a rede.", systemImage: "hand.raised.fill")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            } else {
                                ForEach(result.goalEvents) { event in
                                    Label("\(event.minute)'  \(playerName(event.playerID)) · \(teamsByID[event.teamID]?.name ?? "Equipe")", systemImage: "soccerball")
                                        .font(.subheadline)
                                }
                            }
                        }
                    }

                    FactoryPanel(title: "Todos os resultados", systemImage: "list.bullet.rectangle") {
                        ForEach(report.fixtures) { fixture in
                            if let result = fixture.result {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(scoreline(fixture, result: result))
                                        .font(.subheadline.weight(fixture.id == report.userFixture.id ? .bold : .regular))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("FIN \(result.homeShots)—\(result.awayShots) · POS \(result.homePossession)%—\(100 - result.homePossession)%")
                                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
                .frame(maxWidth: 780, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle("Relatório da partida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continuar") { dismiss() }
                        .accessibilityIdentifier("close-match-report")
                }
            }
        }
    }

    private func playerName(_ id: String) -> String {
        for team in teamsByID.values {
            if let player = team.players.first(where: { $0.id == id }) { return player.name }
        }
        return "Autor do gol"
    }

    private func scoreline(_ fixture: FootballFixture, result: FootballMatchResult) -> String {
        "\(teamsByID[fixture.homeTeamID]?.name ?? "Clube")  \(result.homeGoals) — \(result.awayGoals)  \(teamsByID[fixture.awayTeamID]?.name ?? "Clube")"
    }

    private func resultCaption(_ result: FootballMatchResult) -> String {
        if result.homeGoals == result.awayGoals { return "Um ponto para cada equipe. A tabela da rodada já foi atualizada." }
        let won = userWon
        return "\(won ? "Três pontos conquistados" : "A equipe adversária ficou com os três pontos") · tabela da rodada atualizada."
    }
}
