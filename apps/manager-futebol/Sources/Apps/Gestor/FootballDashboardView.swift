import SwiftUI

struct FootballDashboardView: View {
    @Binding var career: FootballCareer
    let onPlayLive: () -> Void
    let onAlert: (String) -> Void
    let onSeasonEnded: (SeasonRecord) -> Void
    let onNavigate: (PhoneApp) -> Void
    let onShowPress: () -> Void
    var onOpenAgenda: ((FootballAgendaItem) -> Void)? = nil
    @State private var confirmsQuickSimulation = false
    @State private var showsPrepFlow = false
    @State private var playAfterPrepDismiss = false
    @State private var showsIconPack = false
    @State private var showsOffseason = false
    @State private var agendaSort: AgendaSort = .deadline

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let club = career.selectedClub {
                ClubHeroCard(club: club, career: career)
                attentionPanel
                dayPlanPanel
                if !career.promises.isEmpty {
                    FactoryPanel(title: "Compromissos com o elenco", systemImage: "handshake.fill") {
                        ForEach(career.promises) { promise in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(career.player(promise.playerID)?.name ?? "Atleta").font(.subheadline.weight(.bold))
                                ProgressView(value: Double(promise.startsDone), total: Double(promise.requiredStarts))
                                Text("\(promise.startsDone)/\(promise.requiredStarts) como titular · prazo J\(promise.deadlineMatchDay + 1)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Button("Preparar escalação") { onNavigate(.squad) }.buttonStyle(.bordered)
                    }
                }
                if career.isFired {
                    jobOffersPanel
                } else if career.offseason != nil {
                    offseasonPanel
                } else if career.liveMatch != nil {
                    resumePanel
                } else if let fixture = career.nextUserFixture {
                    nextMatchPanel(fixture: fixture, club: club)
                } else if career.isSeasonComplete {
                    seasonEndPanel
                } else if career.canAdvanceWithoutPlaying {
                    restDayPanel
                }
                FootballIconPanel(career: $career, onOpenPack: { showsIconPack = true }, onOpenApp: { onNavigate(.legends) })
                cupPanel
                agendaPanel
                preparationPanel
                if !career.offers.isEmpty && !career.isFired {
                    FootballOffersPanel(career: $career, onAlert: onAlert)
                }
                if let summary = career.latestUserFixture?.summary { FootballPostMatchSummaryPanel(summary: summary) }
                if let lastResult = career.latestUserFixture {
                    FactoryPanel(title: "Último resultado · \(lastResult.title)", systemImage: "sportscourt.fill") {
                        FootballMatchReport(fixture: lastResult, career: career, showAllEvents: false)
                    }
                } else {
                    firstStepsPanel
                }
                boardPanel
                if let trainingReport = career.lastTrainingReport {
                    FactoryPanel(title: "Treino da semana", systemImage: "figure.run") {
                        Label("\(trainingReport.focus.rawValue) · intensidade \(trainingReport.intensity.rawValue)", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.subheadline.weight(.semibold))
                        Text(trainingReport.summary)
                            .font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("football-training-report")
                    }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Painel do treinador")
        .onAppear {
            career.markTutorialSeen("dashboard")
            // Pacote de craque eterno esperando (começo da carreira): abre sozinho, uma vez, fora de testes e capturas.
            if career.iconState.pendingPack != nil, career.offseason == nil, career.liveMatch == nil,
               !FactoryCapture.isUITesting, FactoryCapture.screen == nil {
                showsIconPack = true
            }
        }
        .sheet(isPresented: $showsPrepFlow, onDismiss: {
            // A partida só abre depois que a folha terminou de fechar; um atraso fixo derruba a partida em simuladores lentos.
            guard playAfterPrepDismiss else { return }
            playAfterPrepDismiss = false
            onPlayLive()
        }) {
            FootballMatchPrepFlow(career: $career, onOpenSquad: { onNavigate(.squad) }, onPlay: { playAfterPrepDismiss = true })
        }
        .fullScreenCover(isPresented: $showsIconPack) {
            FootballIconPackView(career: $career) { showsIconPack = false }
        }
        .fullScreenCover(isPresented: $showsOffseason) {
            FootballOffseasonView(career: $career) {
                showsOffseason = false
                if career.isFired, let record = career.history.last { onSeasonEnded(record) }
            }
        }
        .confirmationDialog("Avançar e avaliar estes prazos?", isPresented: $confirmsQuickSimulation, titleVisibility: .visible) {
            Button("Simular e avançar o calendário") { runQuickSimulation() }
            Button("Rever prioridades", role: .cancel) {}
        } message: {
            Text(career.agendaExpiringOnNextAdvance.map { "\($0.title): \($0.detail)" }.joined(separator: "\n\n"))
        }
    }

    private var dayPlanPanel: some View {
        FootballDayPlanPanel(career: career, onShowPress: onShowPress, onNavigate: onNavigate)
    }

    private var agendaPanel: some View {
        FactoryPanel(title: "Agenda do Gestor", systemImage: "calendar.badge.clock") {
            Text("Cada avanço simula um dia do calendário, inclusive datas sem jogo do seu clube. Titularidades contam antes da avaliação das promessas; contratos são avaliados ao encerrar a temporada.")
                .font(.caption).foregroundStyle(.secondary)
            if career.agenda.isEmpty {
                Label("Nenhuma pendência com prazo", systemImage: "checkmark.circle")
                    .font(.subheadline)
            }
            if career.agenda.count > 1 {
                Picker("Ordenar", selection: $agendaSort) {
                    ForEach(AgendaSort.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("agenda-sort")
            }
            ForEach(career.sortedAgenda(by: agendaSort)) { item in
                Button {
                    if let onOpenAgenda { onOpenAgenda(item) }
                    else { openAgenda(item.destination) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.title).font(.subheadline.weight(.bold))
                            Spacer(minLength: 4)
                            PillLabel(text: item.owner.title.uppercased(), tint: .gray)
                            if item.importance >= 3 { PillLabel(text: "ALTA", tint: .red) }
                        }
                        Text(item.deadlineText).font(.caption.weight(.semibold))
                            .foregroundStyle(item.expiresOnNextAdvance ? Color.orange : Color.secondary)
                        Text(item.detail).font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("agenda-\(item.id)")
            }
        }
        .accessibilityIdentifier("football-agenda")
    }

    /// Preparação do próximo jogo: o que já está pronto e o que falta.
    @ViewBuilder
    private var preparationPanel: some View {
        let items = career.matchPreparation()
        if !items.isEmpty {
            FactoryPanel(title: "Preparação do próximo jogo · \(items.filter(\.done).count)/\(items.count)", systemImage: "checklist") {
                ForEach(items) { item in
                    Button { openAgenda(item.destination) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.done ? "checkmark.circle.fill" : "circle").foregroundStyle(item.done ? Color.green : Color.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.subheadline.weight(.semibold))
                                Text(item.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("prep-\(item.id)")
                }
            }
            .accessibilityIdentifier("match-preparation")
        }
    }

    private func openAgenda(_ destination: FootballAgendaDestination) {
        switch destination {
        case .squad, .contracts: onNavigate(.squad)
        case .market: onNavigate(.market)
        case .alerts: onNavigate(.alerts)
        }
    }

    private func requestQuickSimulation() {
        if career.agendaExpiringOnNextAdvance.isEmpty { runQuickSimulation() }
        else { confirmsQuickSimulation = true }
    }

    private func runQuickSimulation() {
        let previousDay = career.worldDay
        if !career.simulateNextMatchDay() {
            onAlert("Não foi possível avançar. Confira a escalação e tente novamente.")
            return
        }
        let days = career.worldDay - previousDay
        let next = career.agenda.first.map { "\($0.title) · \($0.deadlineText)" }
        // O resumo também vai para o histórico de ações (FLX-02): o aviso continua bloqueante até a próxima fatia.
        onAlert(career.logQuickSimulation(days: days, nextPriority: next))
    }

    // MARK: - Atenção do treinador

    @ViewBuilder
    private var attentionPanel: some View {
        let events = career.pendingEvents.count
        let unread = career.unreadCount
        let hasPress = career.pendingPress != nil
        let crisis = career.world.social.crisis != nil
        let invites = career.invitations.count
        let academyReady = career.youthReadyForDecision.count
        if hasPress || events > 0 || unread > 0 || crisis || invites > 0 || academyReady > 0 || career.shouldShowTutorial {
            FactoryPanel(title: "Precisa da sua atenção", systemImage: "bell.badge.fill") {
                if hasPress {
                    attentionRow("Coletiva de imprensa aguardando", "mic.fill", .orange, id: "attention-press", action: onShowPress)
                }
                if crisis {
                    attentionRow("Crise de imagem nas redes", "exclamationmark.triangle.fill", .red, id: "attention-crisis") { onNavigate(.social) }
                }
                if events > 0 {
                    attentionRow("\(events) acontecimento(s) para decidir", "exclamationmark.bubble.fill", .orange, id: "attention-events") { onNavigate(.alerts) }
                }
                if unread > 0 {
                    attentionRow("\(unread) mensagem(ns) não lida(s)", "tray.full.fill", FootballTheme.accent, id: "attention-inbox") { onNavigate(.messages) }
                }
                if invites > 0 {
                    attentionRow("\(invites) convite(s) de outros clubes", "envelope.open.fill", .indigo, id: "attention-invites") { onNavigate(.club) }
                }
                if academyReady > 0 {
                    attentionRow("\(academyReady) jovem(ns) pronto(s) para decidir na Academia", "graduationcap.fill", PhoneApp.academy.tint, id: "attention-academy") { onNavigate(.academy) }
                }
                if career.shouldShowTutorial {
                    let progress = career.tutorialProgress
                    if let step = career.tutorialSteps.first(where: { !$0.done }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Primeiros passos · \(progress.done)/\(progress.total)").font(.caption.weight(.heavy)).foregroundStyle(.secondary)
                            Text(step.title).font(.subheadline.weight(.bold))
                            Text(step.detail).font(.caption).foregroundStyle(.secondary)
                            Button("Dispensar dicas") { career.tutorialDismissed = true }.font(.caption.weight(.bold))
                        }
                    }
                }
            }
        }
    }

    private func attentionRow(_ text: String, _ symbol: String, _ tint: Color, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(tint).frame(width: 24)
                Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    // MARK: - Próxima partida

    private func nextMatchPanel(fixture: LeagueFixture, club: LeagueTeam) -> some View {
        let opponentID = fixture.opponent(of: club.id)
        let opponent = FootballSeason.team(opponentID)
        let opponentStyle = career.predictedOpponentStyle ?? .balanced
        let suggestion = FootballPlayStyle.bestAnswer(to: opponentStyle)
        let ownRating = career.teamRating(club.id)
        let rivalRating = career.teamRating(opponentID)

        let venue = fixture.home == club.id ? "Em casa" : "Fora de casa"
        return FactoryPanel(title: "Próxima partida", systemImage: "calendar") {
            HStack(spacing: 6) {
                PillLabel(text: fixture.title, systemImage: fixture.competition.isCup ? "trophy.fill" : "list.number",
                          tint: fixture.competition.isCup ? FootballTheme.gold : (fixture.competition.division?.tint ?? FootballTheme.accent))
                if FootballSeason.isDerby(fixture.home, fixture.away) {
                    PillLabel(text: "CLÁSSICO", systemImage: "flame.fill", tint: .red)
                }
            }
            MatchupHeader(home: FootballSeason.team(fixture.home), away: FootballSeason.team(fixture.away), homeScore: nil, awayScore: nil)
            Text("\(venue) · \(FootballCalendarClock.longDate(career.gameDay)) · \(FootballCalendarClock.clock(FootballCalendarClock.kickoff(season: career.season, matchDay: career.matchDayIndex)))\(fixture.competition.isCup ? " · mata-mata, empate vai à prorrogação" : "")")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                Text("RELATÓRIO DO OLHEIRO").font(.caption2.weight(.heavy)).tracking(1.2).foregroundStyle(.secondary)
                StatComparisonRow(
                    title: "Força da escalação",
                    home: ownRating,
                    away: rivalRating,
                    homeText: "\(Int(ownRating.rounded()))",
                    awayText: "\(Int(rivalRating.rounded()))",
                    awayColor: opponent?.primaryColor ?? .gray
                )
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sua forma").font(.caption2).foregroundStyle(.secondary)
                        FormBadges(results: career.form(teamID: club.id))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Forma do rival").font(.caption2).foregroundStyle(.secondary)
                        FormBadges(results: career.form(teamID: opponentID))
                    }
                }
                Label("Estilo provável do rival: \(opponentStyle.rawValue)", systemImage: "binoculars.fill")
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("scout-opponent-style")
                HStack(alignment: .center, spacing: 10) {
                    Label("Auxiliar sugere: \(suggestion.rawValue)", systemImage: "lightbulb.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FootballTheme.accent)
                    Spacer(minLength: 4)
                    if career.playStyle != suggestion {
                        Button("Aplicar") { career.setPlayStyle(suggestion) }
                            .font(.caption.weight(.bold))
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("apply-suggestion")
                    } else {
                        PillLabel(text: "EM USO", systemImage: "checkmark")
                    }
                }
                Text("Seu plano atual: \(career.formation.rawValue) · \(career.playStyle.rawValue)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            ForEach(career.lineupWarnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }

            Button { showsPrepFlow = true } label: {
                Label("Preparar a partida", systemImage: "checklist").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("prep-flow-open")

            Button(action: onPlayLive) {
                Label("Jogar partida ao vivo", systemImage: "play.fill")
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .accessibilityIdentifier("play-match")

            HStack(spacing: 10) {
                Button {
                    requestQuickSimulation()
                } label: {
                    Label("Simulação rápida", systemImage: "forward.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("simulate-round")
                Button { onNavigate(.squad) } label: {
                    Label("Escalação", systemImage: "person.3.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline.weight(.semibold))
            Button {
                let result = career.simulateUntilAgendaDecision()
                onAlert("\(result.days) dia(s) simulado(s). \(result.reason)")
            } label: {
                Label("Simular até a próxima decisão", systemImage: "forward.end.alt.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("simulate-until-decision")
        }
    }

    private var restDayPanel: some View {
        FactoryPanel(title: career.currentSlot?.title ?? "Dia de jogo", systemImage: "calendar.badge.clock") {
            Text(career.isEliminatedFromCup
                 ? "Seu clube está fora da copa. Os outros clubes jogam no meio de semana e o seu elenco ganha tempo para recuperar energia."
                 : "Seu clube não entra em campo nesta fase. Aproveite para recuperar o elenco antes da próxima rodada.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button {
                requestQuickSimulation()
            } label: {
                Label("Avançar para o próximo jogo", systemImage: "forward.fill")
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .accessibilityIdentifier("simulate-round")
        }
    }

    @ViewBuilder
    private var cupPanel: some View {
        if !career.cupFixtures.isEmpty && !career.isFired {
            FactoryPanel(title: "Copa Nacional", systemImage: "trophy.fill") {
                HStack {
                    Text(career.userCupStatus).font(.subheadline.weight(.semibold))
                    Spacer()
                    if let next = career.upcomingUserFixtures.first(where: { $0.competition.isCup }),
                       let opponent = career.selectedClubID.map({ next.opponent(of: $0) }),
                       let team = FootballSeason.team(opponent) {
                        HStack(spacing: 6) {
                            Text("próximo:").font(.caption).foregroundStyle(.secondary)
                            ClubCrest(team: team, size: 20)
                            Text(team.shortName).font(.caption.weight(.bold))
                        }
                    }
                }
                Button { onNavigate(.league) } label: {
                    Label("Ver chaveamento", systemImage: "list.bullet.indent")
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var resumePanel: some View {
        FactoryPanel(title: "Partida em andamento", systemImage: "pause.circle.fill") {
            if let live = career.liveMatch, let fixture = career.fixtures.first(where: { $0.id == live.fixtureID }) {
                MatchupHeader(home: FootballSeason.team(fixture.home), away: FootballSeason.team(fixture.away),
                              homeScore: live.homeGoals, awayScore: live.awayGoals)
            }
            Text("A partida está parada no minuto \(career.liveMatch?.minute ?? 0). Volte para continuar de onde parou.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button(action: onPlayLive) {
                Label("Voltar à partida", systemImage: "play.fill")
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .accessibilityIdentifier("resume-match")
        }
    }

    private var seasonEndPanel: some View {
        FactoryPanel(title: "Temporada encerrada", systemImage: "flag.checkered") {
            if let championID = career.championID, let champion = FootballSeason.team(championID) {
                HStack(spacing: 12) {
                    ClubCrest(team: champion, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Campeão da Série A").font(.caption.weight(.bold)).foregroundStyle(FootballTheme.gold)
                        Text(champion.name).font(.title3.bold())
                    }
                    Spacer()
                    Image(systemName: "trophy.fill").font(.largeTitle).foregroundStyle(FootballTheme.gold)
                }
            }
            if let position = career.userPosition, let division = career.userDivision {
                Text("Seu clube terminou em \(position)º na \(division.name). Meta da diretoria: \(career.objectiveText.lowercased()).")
                    .font(.subheadline).foregroundStyle(.secondary)
                if division == .serieB && position <= FootballSeason.relegationSpots {
                    Label("Acesso garantido à Série A!", systemImage: "arrow.up.circle.fill")
                        .font(.subheadline.weight(.bold)).foregroundStyle(.green)
                } else if division == .serieA && position > FootballSeason.teamsPerDivision - FootballSeason.relegationSpots {
                    Label("Rebaixado para a Série B.", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline.weight(.bold)).foregroundStyle(.red)
                }
            }
            Button {
                if career.beginOffseason() { showsOffseason = true }
            } label: {
                Label("Encerrar temporada", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .accessibilityIdentifier("end-season")
        }
    }

    private var offseasonPanel: some View {
        FactoryPanel(title: "Entre temporadas", systemImage: "sun.horizon.fill") {
            Text(career.offseason.map { "Você está na etapa \"\($0.step.title)\". A nova temporada só começa depois da pré-temporada." }
                 ?? "")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { showsOffseason = true } label: {
                Label("Continuar", systemImage: "play.fill")
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .accessibilityIdentifier("resume-offseason")
        }
    }

    private var jobOffersPanel: some View {
        FactoryPanel(title: "Você foi demitido", systemImage: "person.fill.xmark") {
            Text("A diretoria perdeu a confiança no seu trabalho. Três clubes querem conversar com você.")
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(career.jobOffers) { team in
                HStack(spacing: 12) {
                    ClubCrest(team: team, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(team.name).font(.subheadline.weight(.semibold))
                        Text("\(team.city) · orçamento \(FootballFormat.money(team.startingBudget / 2))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Aceitar") { career.acceptJob(team.id) }
                        .buttonStyle(.borderedProminent)
                        .font(.caption.weight(.bold))
                        .accessibilityIdentifier("accept-job-\(team.id)")
                }
            }
        }
    }

    private var firstStepsPanel: some View {
        FactoryPanel(title: "Primeiros passos", systemImage: "flag.fill") {
            Text("Ajuste formação, estilo e treino no Elenco. Antes de cada jogo, leia o relatório do olheiro: cada estilo tem vantagens e fraquezas contra o plano do rival.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { onNavigate(.squad) } label: { Label("Gerir elenco e tática", systemImage: "person.3.fill") }
                .buttonStyle(.bordered)
        }
    }

    private var boardPanel: some View {
        FactoryPanel(title: "Diretoria", systemImage: "building.columns.fill") {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Meta da temporada").font(.caption).foregroundStyle(.secondary)
                    Text(career.objectiveText).font(.subheadline.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Confiança").font(.caption).foregroundStyle(.secondary)
                    Text("\(career.boardConfidence)%").font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(ConditionBar.color(for: career.boardConfidence + 15))
                }
            }
            ConditionBar(value: career.boardConfidence)
                .accessibilityLabel("Confiança da diretoria \(career.boardConfidence)%")
            HStack {
                Label("Pressão da torcida", systemImage: "flame.fill").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(career.pressureLabel).font(.caption.weight(.bold))
                    .foregroundStyle(career.fanPressure >= 75 ? Color.red : (career.fanPressure >= 55 ? Color.orange : Color.secondary))
            }
            if career.lastRoundRevenue > 0 {
                Label("Bilheteria da última rodada: \(FootballFormat.money(career.lastRoundRevenue))", systemImage: "ticket.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Componentes do painel

struct ClubHeroCard: View {
    let club: LeagueTeam
    let career: FootballCareer

    var body: some View {
        let standing = career.standings.first { $0.team.id == club.id }
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ClubCrest(team: club, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(career.userDivision?.name.uppercased() ?? "") · T\(career.season) · \(FootballCalendarClock.shortDate(career.gameDay).uppercased())")
                        .font(.caption2.weight(.heavy)).tracking(1.1)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(club.secondaryColor)
                    Text(club.name).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(club.city).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                }
            }
            HStack(spacing: 10) {
                heroMetric(title: "Posição", value: career.userPosition.map { "\($0)º" } ?? "—")
                heroMetric(title: "Pontos", value: "\(standing?.points ?? 0)")
                heroMetric(title: "Caixa", value: FootballFormat.money(career.transferBudget))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [club.primaryColor, club.primaryColor.opacity(0.7), Color.black.opacity(0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private func heroMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.5), value: value)
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct MatchupHeader: View {
    let home: LeagueTeam?
    let away: LeagueTeam?
    let homeScore: Int?
    let awayScore: Int?
    var crestSize: CGFloat = 48

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            teamColumn(home)
            Group {
                if let homeScore, let awayScore {
                    Text("\(homeScore) – \(awayScore)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                } else {
                    Text("×").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 90)
            teamColumn(away)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func teamColumn(_ team: LeagueTeam?) -> some View {
        VStack(spacing: 6) {
            if let team { ClubCrest(team: team, size: crestSize) }
            Text(team?.name ?? "—")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FootballMatchReport: View {
    let fixture: LeagueFixture
    let career: FootballCareer
    let showAllEvents: Bool

    private var keyEvents: [MatchEvent] {
        if showAllEvents { return fixture.events }
        return fixture.events.filter { $0.kind == .goal || $0.kind == .injury || $0.kind == .redCard || $0.kind == .penaltyAwarded }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MatchupHeader(home: FootballSeason.team(fixture.home), away: FootballSeason.team(fixture.away),
                          homeScore: fixture.homeGoals, awayScore: fixture.awayGoals, crestSize: 40)
            let homeColor = FootballSeason.team(fixture.home)?.primaryColor ?? FootballTheme.accent
            let awayColor = FootballSeason.team(fixture.away)?.primaryColor ?? .gray
            if let homePossession = fixture.homePossession, let awayPossession = fixture.awayPossession {
                StatComparisonRow(title: "Posse de bola", home: Double(homePossession), away: Double(awayPossession),
                                  homeText: "\(homePossession)%", awayText: "\(awayPossession)%",
                                  homeColor: homeColor, awayColor: awayColor)
                    .accessibilityIdentifier("match-report-possession")
            }
            if let homeShots = fixture.homeShots, let awayShots = fixture.awayShots {
                StatComparisonRow(title: "Finalizações", home: Double(homeShots), away: Double(awayShots),
                                  homeText: "\(homeShots)", awayText: "\(awayShots)",
                                  homeColor: homeColor, awayColor: awayColor)
                    .accessibilityIdentifier("match-report-shots")
            }
            if let homeOnTarget = fixture.homeOnTarget, let awayOnTarget = fixture.awayOnTarget {
                StatComparisonRow(title: "No alvo", home: Double(homeOnTarget), away: Double(awayOnTarget),
                                  homeText: "\(homeOnTarget)", awayText: "\(awayOnTarget)",
                                  homeColor: homeColor, awayColor: awayColor)
            }
            if let homeXG = fixture.homeExpectedGoals, let awayXG = fixture.awayExpectedGoals {
                StatComparisonRow(title: "Gols esperados (xG)", home: homeXG, away: awayXG,
                                  homeText: FootballFormat.expectedGoals(homeXG), awayText: FootballFormat.expectedGoals(awayXG),
                                  homeColor: homeColor, awayColor: awayColor)
            }
            if !keyEvents.isEmpty {
                Divider()
                ForEach(Array(keyEvents.enumerated()), id: \.offset) { _, event in
                    MatchEventRow(event: event)
                }
            } else if !fixture.commentary.isEmpty {
                Divider()
                ForEach(Array(fixture.commentary.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct MatchEventRow: View {
    let event: MatchEvent

    private var symbol: String {
        switch event.kind {
        case .goal: return "soccerball"
        case .save: return "hand.raised.fill"
        case .chance: return "scope"
        case .halfTime: return "pause.circle.fill"
        case .fullTime: return "flag.checkered"
        case .kickoff: return "whistle.fill"
        case .tactic: return "slider.horizontal.3"
        case .substitution: return "arrow.left.arrow.right"
        case .injury: return "cross.case.fill"
        case .extraTime: return "clock.badge.exclamationmark"
        case .penalties: return "figure.soccer"
        case .yellowCard: return "rectangle.portrait.fill"
        case .redCard: return "rectangle.portrait.fill"
        case .penaltyAwarded: return "exclamationmark.circle.fill"
        case .stoppage: return "plus.circle.fill"
        case .pressure: return "flame.fill"
        case .offside: return "flag.fill"
        case .tackle: return "shield.lefthalf.filled"
        case .dribble: return "figure.run"
        case .cross: return "arrow.up.right"
        case .woodwork: return "square.dashed"
        }
    }

    private var tint: Color {
        switch event.kind {
        case .goal: return event.teamID.flatMap { FootballSeason.team($0)?.primaryColor } ?? FootballTheme.accent
        case .injury, .redCard: return .red
        case .yellowCard: return .yellow
        case .penaltyAwarded, .pressure: return .orange
        case .halfTime, .fullTime, .kickoff: return .secondary
        default: return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(event.minuteLabel)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(event.text)
                .font(event.kind == .goal ? Font.subheadline.weight(.semibold) : Font.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct FootballOffersPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        FactoryPanel(title: "Propostas recebidas", systemImage: "envelope.badge.fill") {
            ForEach(career.offers) { offer in
                if let player = career.player(offer.playerID), let buyer = FootballSeason.team(offer.clubID) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            ClubCrest(team: buyer, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(buyer.name) quer \(player.name)").font(.subheadline.weight(.semibold))
                                Text("\(player.position.rawValue) · GER \(player.overall) · valor \(FootballFormat.money(player.marketValue))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        HStack {
                            Text(FootballFormat.money(offer.amount))
                                .font(.headline.monospacedDigit()).foregroundStyle(FootballTheme.accent)
                            Text("expira em \(max(1, offer.expiresAfterRound - career.matchDayIndex)) jogo(s)").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Button("Recusar") { career.rejectOffer(offer.id) }
                                .buttonStyle(.bordered)
                            Button("Aceitar") {
                                if !career.acceptOffer(offer.id) {
                                    onAlert("Venda bloqueada: o elenco precisa continuar preenchendo a formação com pelo menos \(FootballCareer.minimumRoster) atletas.")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("accept-offer-\(offer.id)")
                        }
                        .font(.caption.weight(.bold))
                    }
                    if offer.id != career.offers.last?.id { Divider() }
                }
            }
        }
    }
}
