import SwiftUI

struct FootballHome: View {
    @State private var career = FootballCareer.load()
    @State private var selectedTab = 0
    @State private var showNewCareerConfirmation = false
    @State private var alertMessage: String?
    private let accent = Color(red: 0.08, green: 0.37, blue: 0.25)

    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack {
            Group {
                if capture == "table" || selectedTab == 1 {
                    tableView
                } else if capture == "squad" || selectedTab == 2 {
                    squadView
                } else if capture == "market" || selectedTab == 3 {
                    marketView
                } else if career.selectedClubID == nil {
                    clubSelection
                } else {
                    dashboard
                }
            }
            .safeAreaInset(edge: .bottom) {
                if career.selectedClubID != nil && capture == nil { navigationBar }
            }
            .toolbar {
                if let club = career.selectedClub {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            Image(systemName: "sportscourt.fill")
                            Text(club.name.uppercased())
                            Text("· T\(career.season)").foregroundStyle(.secondary)
                        }
                        .font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(accent)
                        .accessibilityElement(children: .combine)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Nova carreira") { showNewCareerConfirmation = true }
                            .font(.caption.weight(.semibold))
                            .accessibilityIdentifier("new-career")
                    }
                }
            }
            .confirmationDialog("Começar uma nova carreira?", isPresented: $showNewCareerConfirmation, titleVisibility: .visible) {
                Button("Apagar carreira e começar de novo", role: .destructive) {
                    career = FootballCareer(seed: career.seed &+ 1)
                    selectedTab = 0
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("O save local atual será substituído.")
            }
            .alert("Manager de Futebol", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
        .tint(accent)
        .onAppear(perform: prepareInitialState)
        .onChange(of: career) { _, updatedCareer in updatedCareer.persist() }
    }

    private var clubSelection: some View {
        VStack(alignment: .leading, spacing: 20) {
            FactoryHeader(
                eyebrow: "Nova carreira · futebol fictício",
                title: "Escolha seu clube",
                subtitle: "Assuma um dos oito clubes e conduza o elenco ao título. A carreira funciona offline e salva automaticamente neste aparelho.",
                accent: accent
            )
            FactoryDemoNotice(message: "Clubes, atletas, orçamentos e partidas fictícios")
            ForEach(FootballSeason.teams) { club in
                Button {
                    if !career.chooseClub(club.id) {
                        alertMessage = "Não foi possível montar o elenco inicial deste clube."
                    }
                } label: {
                    FactoryPanel {
                        HStack(spacing: 14) {
                            Image(systemName: "shield.fill")
                                .font(.title2)
                                .foregroundStyle(accent)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(club.name).font(.headline).foregroundStyle(.primary)
                                Text(club.city).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("FOR \(club.strength)").font(.caption.bold().monospacedDigit()).foregroundStyle(accent)
                                Text(money(club.startingBudget)).font(.caption2).foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("choose-club-\(club.id)")
                .accessibilityLabel("Escolher \(club.name), força \(club.strength), orçamento inicial \(money(club.startingBudget))")
            }
        }
        .factoryPage()
        .navigationTitle("Escolha do clube")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dashboard: some View {
        Group {
            if let club = career.selectedClub {
                VStack(alignment: .leading, spacing: 20) {
                    FactoryHeader(
                        eyebrow: "Temporada \(career.season) · carreira local",
                        title: "Treinador, sua jornada começa aqui.",
                        subtitle: "\(club.name) · \(club.city). Monte o time, cuide do orçamento e jogue rodada a rodada.",
                        accent: accent
                    )
                    FactoryDemoNotice(message: "Liga fictícia · seed \(career.seed) · dados salvos no aparelho")
                    HStack(spacing: 12) {
                        FactoryMetric(label: "Orçamento de transferências", value: money(career.transferBudget), symbol: "banknote.fill", tint: accent)
                        FactoryMetric(label: "Temporada", value: "\(career.currentRound)/14", symbol: "calendar", tint: .orange)
                    }
                    FactoryPanel(title: career.isSeasonComplete ? "Temporada encerrada" : "Próxima partida", systemImage: "sportscourt.fill") {
                        if let fixture = career.nextUserFixture {
                            Text(fixtureTitle(fixture)).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                            Text("Rodada \(fixture.round) de 14 · \(fixture.home == club.id ? "em casa" : "fora")")
                                .font(.subheadline).foregroundStyle(.secondary)
                        } else if career.isSeasonComplete, let championID = career.championID,
                                  let champion = FootballSeason.teams.first(where: { $0.id == championID }) {
                            Label("Campeão: \(champion.name)", systemImage: "trophy.fill")
                                .font(.headline).foregroundStyle(accent)
                            Text("A classificação final foi calculada a partir dos resultados registrados.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button {
                            if career.isSeasonComplete {
                                career.startNextSeason()
                            } else if !career.simulateNextRound() {
                                alertMessage = "Não foi possível simular a próxima rodada. Confira a escalação e tente novamente."
                            }
                        } label: {
                            Label(career.isSeasonComplete ? "Iniciar temporada \(career.season + 1)" : "Simular rodada \(career.currentRound + 1)", systemImage: career.isSeasonComplete ? "arrow.clockwise" : "play.fill")
                        }
                        .accessibilityIdentifier("simulate-round")
                        .buttonStyle(FactoryPrimaryButtonStyle())
                        Text(career.isSeasonComplete
                             ? "Nova temporada, mesmos clubes fictícios e uma nova sequência de placares."
                             : "Os quatro jogos são simulados uma única vez ao avançar. A mesma seed mantém esta carreira reproduzível.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let lastResult = career.latestUserFixture {
                        FactoryPanel(title: "Último resultado", systemImage: "checkmark.circle.fill") {
                            Text(scoreLine(lastResult)).font(.headline).fixedSize(horizontal: false, vertical: true)
                            Text("Rodada \(lastResult.round) · energia atualizada para o elenco")
                                .font(.caption).foregroundStyle(.secondary)
                            if let homeShots = lastResult.homeShots, let awayShots = lastResult.awayShots,
                               let homePossession = lastResult.homePossession, let awayPossession = lastResult.awayPossession {
                                Label("Finalizações: \(homeShots) — \(awayShots)", systemImage: "scope")
                                    .font(.subheadline.weight(.medium))
                                    .accessibilityIdentifier("match-report-shots")
                                Label("Posse de bola: \(homePossession)% — \(awayPossession)%", systemImage: "circle.lefthalf.filled")
                                    .font(.subheadline.weight(.medium))
                                    .accessibilityIdentifier("match-report-possession")
                            }
                            ForEach(lastResult.commentary, id: \.self) { line in
                                Text(line).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else {
                        FactoryPanel(title: "Comece a temporada", systemImage: "flag.fill") {
                            Text("Escolha sua formação e escalação antes de avançar. A rodada só é registrada quando você toca em Simular.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button { selectedTab = 2 } label: { Label("Gerir elenco e tática", systemImage: "person.3.fill") }
                                .buttonStyle(FactoryPrimaryButtonStyle())
                        }
                    }
                    if let trainingReport = career.lastTrainingReport {
                        FactoryPanel(title: "Treino aplicado · rodada \(trainingReport.round)", systemImage: "figure.run") {
                            Label("\(trainingReport.focus.rawValue) · intensidade \(trainingReport.intensity.rawValue)", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.subheadline.weight(.semibold))
                            Text(trainingReport.summary)
                                .font(.caption).foregroundStyle(.secondary)
                                .accessibilityIdentifier("football-training-report")
                        }
                    }
                    let clubStanding = FootballSeason.standings(results: career.fixtures).first { $0.team.id == club.id }
                    if let clubStanding {
                        FactoryPanel(title: "Campanha na liga", systemImage: "chart.bar.fill") {
                            Text("\(clubStanding.points) pontos · \(clubStanding.wins)V \(clubStanding.draws)E \(clubStanding.losses)D · saldo \(signed(clubStanding.goalDifference)")
                                .font(.subheadline.weight(.semibold))
                            Text("Vitórias, saldo de gols e gols marcados definem os desempates após os pontos.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .factoryPage()
                .navigationTitle("Painel do treinador")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                clubSelection
            }
        }
    }

    private var tableView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Liga fictícia · temporada \(career.season)",
                title: "Classificação",
                subtitle: "Pontos → vitórias → saldo de gols → gols marcados → nome do clube.",
                accent: accent
            )
            FactoryDemoNotice()
            let completed = career.fixtures.filter(\.isPlayed).sorted { $0.round > $1.round }
            FactoryPanel(title: "Resultados registrados", systemImage: "checkmark.circle") {
                if completed.isEmpty {
                    Text("Nenhuma partida disputada. Simule a primeira rodada no painel do treinador.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(completed.prefix(4)) { match in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("R\(match.round)").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
                            Text(scoreLine(match)).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.72)
                        }
                        if match.id != completed.prefix(4).last?.id { Divider() }
                    }
                }
            }
            FactoryPanel {
                HStack {
                    Text("#  CLUBE").font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                    Text("J  V  E  D  PTS").font(.caption.bold()).foregroundStyle(.secondary)
                }
                ForEach(Array(FootballSeason.standings(results: career.fixtures).enumerated()), id: \.element.team.id) { index, row in
                    HStack(spacing: 8) {
                        Text(String(format: "%02d", index + 1))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(index == 0 ? accent : .secondary)
                            .frame(width: 26, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.team.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text("SG \(signed(row.goalDifference)) · GP \(row.goalsFor)").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Text("\(row.played)  \(row.wins)  \(row.draws)  \(row.losses)  \(row.points)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    if index < FootballSeason.teams.count - 1 { Divider() }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Classificação")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var squadView: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let club = career.selectedClub {
                FactoryHeader(
                    eyebrow: "Elenco · \(career.clubRoster.count)/16 atletas",
                    title: club.name,
                    subtitle: "Defina formação e estilo. No banco, use “Pôr titular” para trocar um atleta pela opção de mesma posição.",
                    accent: accent
                )
                FactoryDemoNotice(message: "Atletas fictícios · condição física muda após cada rodada")
                FactoryPanel(title: "Formação e plano de jogo", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                    Picker("Formação", selection: Binding(
                        get: { career.formation },
                        set: { career.setFormation($0) }
                    )) {
                        ForEach(FootballFormation.allCases) { formation in
                            Text(formation.rawValue).tag(formation)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(formationDescription(career.formation))
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Estilo de jogo", selection: Binding(
                        get: { career.playStyle },
                        set: { career.setPlayStyle($0) }
                    )) {
                        ForEach(FootballPlayStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("play-style-picker")
                    Text(career.playStyle.summary)
                        .font(.caption).foregroundStyle(.secondary)
                    Label("\(career.startingXI.count) titulares · orçamento \(money(career.transferBudget))", systemImage: "person.3.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(accent)
                }
                FactoryPanel(title: "Treino semanal", systemImage: "figure.run") {
                    Picker("Foco do treino", selection: Binding(
                        get: { career.trainingFocus },
                        set: { career.setTrainingFocus($0) }
                    )) {
                        ForEach(FootballTrainingFocus.allCases) { focus in
                            Text(focus.rawValue).tag(focus)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("training-focus-picker")
                    Text(career.trainingFocus.summary)
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Intensidade", selection: Binding(
                        get: { career.trainingIntensity },
                        set: { career.setTrainingIntensity($0) }
                    )) {
                        ForEach(FootballTrainingIntensity.allCases) { intensity in
                            Text(intensity.rawValue).tag(intensity)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("training-intensity-picker")
                    Text("O treino é aplicado ao simular a próxima rodada. Intensidade maior desenvolve mais atletas, mas recupera menos energia.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                FactoryPanel(title: "Titulares", systemImage: "figure.soccer") {
                    ForEach(career.clubRoster.filter { career.startingXI.contains($0.id) }) { player in
                        playerRow(player, isStarter: true)
                        if player.id != career.clubRoster.filter({ career.startingXI.contains($0.id) }).last?.id { Divider() }
                    }
                }
                FactoryPanel(title: "Banco e negociações", systemImage: "person.2.fill") {
                    ForEach(career.clubRoster.filter { !career.startingXI.contains($0.id) }) { player in
                        playerRow(player, isStarter: false)
                        if player.id != career.clubRoster.filter({ !career.startingXI.contains($0.id) }).last?.id { Divider() }
                    }
                    Text("Negocie um atleta do banco para abrir vaga e reforçar o time no mercado.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                clubSelection
            }
        }
        .factoryPage()
        .navigationTitle("Elenco e tática")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var marketView: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let club = career.selectedClub {
                FactoryHeader(
                    eyebrow: "Mercado local · atletas fictícios",
                    title: "Reforce o \(club.name)",
                    subtitle: "Contratações usam o orçamento da carreira e ocupam uma das 16 vagas do elenco.",
                    accent: accent
                )
                FactoryDemoNotice(message: "Agentes livres demonstrativos · sem transações reais")
                FactoryPanel(title: "Orçamento e elenco", systemImage: "banknote.fill") {
                    HStack {
                        FactoryMetric(label: "Disponível", value: money(career.transferBudget), symbol: "wallet.bifold.fill", tint: accent)
                        FactoryMetric(label: "Vagas ocupadas", value: "\(career.clubRoster.count)/16", symbol: "person.3.fill", tint: .orange)
                    }
                    Text(career.clubRoster.count >= 16
                         ? "Elenco completo. Venda um atleta reserva para abrir uma vaga antes de contratar."
                         : "Uma contratação só é aceita quando há vaga e saldo suficiente.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if career.marketPlayers.isEmpty {
                    FactoryPanel(title: "Mercado", systemImage: "magnifyingglass") {
                        Text("Não há agentes livres disponíveis nesta carreira.").font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    FactoryPanel(title: "Agentes livres", systemImage: "person.crop.circle.badge.plus") {
                        ForEach(career.marketPlayers) { player in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(player.name).font(.subheadline.weight(.semibold))
                                    Text("\(player.position.rawValue) · \(player.age) anos · GER \(player.overall) · POT \(player.potential)")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text("Valor: \(money(player.marketValue))").font(.caption2.weight(.medium)).foregroundStyle(accent)
                                }
                                Spacer(minLength: 4)
                                Button {
                                    if !career.signPlayer(playerID: player.id) {
                                        alertMessage = "Não foi possível contratar: confira o orçamento e as vagas no elenco."
                                    }
                                } label: {
                                    Label("Contratar", systemImage: "plus")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!career.canSign(playerID: player.id))
                                .accessibilityIdentifier("contract-player-\(player.id)")
                            }
                            if player.id != career.marketPlayers.last?.id { Divider() }
                        }
                    }
                }
            } else {
                clubSelection
            }
        }
        .factoryPage()
        .navigationTitle("Mercado")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func playerRow(_ player: FootballPlayer, isStarter: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.name).font(.subheadline.weight(.semibold))
                    Text("\(player.position.rawValue) · \(player.age) anos · GER \(player.overall) · POT \(player.potential)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(player.condition)%").font(.subheadline.monospacedDigit().weight(.bold))
                    Text("energia").font(.caption2).foregroundStyle(.secondary)
                }
                if isStarter {
                    Text("TITULAR").font(.caption2.bold()).foregroundStyle(accent)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(accent.opacity(0.1), in: Capsule())
                } else {
                    Button {
                        if !career.swapWithStarter(playerID: player.id) {
                            alertMessage = "Não foi possível fazer a troca para esta posição."
                        }
                    } label: {
                        Label("Pôr titular", systemImage: "arrow.up")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("swap-player-\(player.id)")
                }
            }
            if !isStarter {
                HStack {
                    Text("Valor estimado · \(money(player.marketValue))")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("Vender") {
                        if !career.sellPlayer(playerID: player.id) {
                            alertMessage = "Só é possível vender reservas quando o elenco ainda consegue preencher a formação."
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .disabled(!career.canSell(playerID: player.id))
                    .accessibilityIdentifier("sell-player-\(player.id)")
                }
            }
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 4) {
            tab("Painel", symbol: "rectangle.grid.1x2.fill", index: 0)
            tab("Tabela", symbol: "list.number", index: 1)
            tab("Elenco", symbol: "person.3.fill", index: 2)
            tab("Mercado", symbol: "arrow.left.arrow.right", index: 3)
        }
        .padding(7)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private func tab(_ title: String, symbol: String, index: Int) -> some View {
        Button { selectedTab = index } label: {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(selectedTab == index ? accent : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab-\(index)")
    }

    private func fixtureTitle(_ fixture: LeagueFixture) -> String {
        let home = FootballSeason.teams.first { $0.id == fixture.home }?.name ?? "Mandante"
        let away = FootballSeason.teams.first { $0.id == fixture.away }?.name ?? "Visitante"
        return "\(home)  ×  \(away)"
    }

    private func scoreLine(_ fixture: LeagueFixture) -> String {
        guard let homeGoals = fixture.homeGoals, let awayGoals = fixture.awayGoals else {
            return fixtureTitle(fixture)
        }
        let home = FootballSeason.teams.first { $0.id == fixture.home }?.name ?? "Mandante"
        let away = FootballSeason.teams.first { $0.id == fixture.away }?.name ?? "Visitante"
        return "\(home)  \(homeGoals) — \(awayGoals)  \(away)"
    }

    private func formationDescription(_ formation: FootballFormation) -> String {
        switch formation {
        case .fourFourTwo: return "Equilíbrio entre defesa, meio-campo e dois atacantes."
        case .fourThreeThree: return "Mais presença ofensiva; os três atacantes aumentam a pressão sobre a defesa."
        case .fourTwoThreeOne: return "Meio-campo reforçado para controlar a posse e abastecer um atacante."
        }
    }

    private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }

    private func money(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "R$ \(value)"
    }

    private func prepareInitialState() {
        if FactoryCapture.isUITesting {
            FactoryCapture.resetAppDefaults()
            career = FootballCareer(seed: 26)
            selectedTab = 0
        } else if capture != nil {
            var preview = FootballCareer(seed: 26)
            _ = preview.chooseClub(0)
            _ = preview.simulateNextRound()
            _ = preview.simulateNextRound()
            career = preview
            selectedTab = 0
        }
    }
}
