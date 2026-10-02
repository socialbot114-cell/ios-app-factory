import SwiftUI

/// Partida ao vivo: relógio animado, narração lance a lance e vestiário no intervalo.
struct FootballLiveMatchView: View {
    enum Phase {
        case firstHalf, halfTime, secondHalf, fullTime
    }

    @Binding var career: FootballCareer
    let staticPreview: Bool
    let onClose: () -> Void

    @State private var phase: Phase = .firstHalf
    @State private var minute = 0
    @State private var fixtureID: Int?
    @State private var tickTask: Task<Void, Never>?
    @State private var showSubstitutions = false
    @State private var didStart = false

    private var tickNanoseconds: UInt64 {
        FactoryCapture.isUITesting ? 20_000_000 : 120_000_000
    }

    private var fixture: LeagueFixture? {
        guard let fixtureID else { return nil }
        return career.fixtures.first { $0.id == fixtureID }
    }

    private var sourceEvents: [MatchEvent] {
        switch phase {
        case .firstHalf, .halfTime: return career.liveMatch?.events ?? []
        case .secondHalf, .fullTime: return fixture?.events ?? []
        }
    }

    private var visibleEvents: [MatchEvent] {
        sourceEvents.filter { event in
            switch phase {
            case .firstHalf:
                return event.kind != .halfTime && event.kind != .substitution && event.minute <= minute
            case .halfTime:
                return true
            case .secondHalf:
                return event.kind != .fullTime && event.kind != .injury && event.minute <= minute
            case .fullTime:
                return true
            }
        }
    }

    private func goals(for teamID: Int?) -> Int {
        visibleEvents.filter { $0.kind == .goal && $0.teamID == teamID }.count
    }

    private var goalCount: Int {
        visibleEvents.filter { $0.kind == .goal }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    scoreboard
                    switch phase {
                    case .firstHalf, .secondHalf:
                        runningControls
                    case .halfTime:
                        halfTimePanel
                    case .fullTime:
                        fullTimePanel
                    }
                    FactoryPanel(title: "Lance a lance", systemImage: "text.bubble.fill") {
                        if visibleEvents.isEmpty {
                            Text("A bola vai rolar…").font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(Array(visibleEvents.enumerated().reversed()), id: \.offset) { _, event in
                            MatchEventRow(event: event)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .accessibilityIdentifier("live-feed")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 780)
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: 0.25), value: visibleEvents.count)
            }
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle("Rodada \(fixture?.round ?? career.currentRound + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if phase == .halfTime && !staticPreview {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Sair") { onClose() }
                            .accessibilityHint("A partida fica salva no intervalo")
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: goalCount)
        .sheet(isPresented: $showSubstitutions) {
            FootballSubstitutionSheet(career: $career, outgoingID: nil)
        }
        .onAppear(perform: start)
        .onDisappear { tickTask?.cancel() }
    }

    // MARK: - Placar

    private var scoreboard: some View {
        VStack(spacing: 14) {
            if let fixture {
                MatchupHeader(home: FootballSeason.team(fixture.home), away: FootballSeason.team(fixture.away),
                              homeScore: goals(for: fixture.home), awayScore: goals(for: fixture.away), crestSize: 54)
                    .accessibilityIdentifier("live-scoreboard")
            }
            HStack(spacing: 8) {
                Circle().fill(isRunning ? Color.red : Color.secondary).frame(width: 8, height: 8)
                Text(clockText)
                    .font(.headline.monospacedDigit())
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06), in: Capsule())
            .accessibilityIdentifier("live-clock")
            ProgressView(value: Double(minute), total: 90)
                .tint(FootballTheme.accent)
        }
        .padding(18)
        .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var isRunning: Bool { phase == .firstHalf || phase == .secondHalf }

    private var clockText: String {
        switch phase {
        case .firstHalf, .secondHalf: return "\(minute)′"
        case .halfTime: return "Intervalo"
        case .fullTime: return "Fim de jogo"
        }
    }

    // MARK: - Controles

    private var runningControls: some View {
        Button(action: skip) {
            Label(phase == .firstHalf ? "Pular para o intervalo" : "Pular para o apito final", systemImage: "forward.end.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .font(.subheadline.weight(.semibold))
        .accessibilityIdentifier("live-skip")
    }

    private var halfTimePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let live = career.liveMatch, let fixture {
                FactoryPanel(title: "Estatísticas do 1º tempo", systemImage: "chart.bar.fill") {
                    liveStats(live: live, fixture: fixture)
                }
            }
            FactoryPanel(title: "Vestiário", systemImage: "person.2.wave.2.fill") {
                if let opponentStyle = career.predictedOpponentStyle {
                    Label("O rival deve voltar: \(opponentStyle.rawValue)", systemImage: "binoculars.fill")
                        .font(.subheadline.weight(.medium))
                    Label("Auxiliar sugere: \(FootballPlayStyle.bestAnswer(to: opponentStyle).rawValue)", systemImage: "lightbulb.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FootballTheme.accent)
                }
                Picker("Estilo para o 2º tempo", selection: Binding(
                    get: { career.playStyle },
                    set: { career.setPlayStyle($0) }
                )) {
                    ForEach(FootballPlayStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .disabled(staticPreview)
                .accessibilityIdentifier("live-style-picker")
                Text(career.playStyle.summary).font(.caption).foregroundStyle(.secondary)
                Button { showSubstitutions = true } label: {
                    Label("Substituições (\(career.liveMatch?.substitutionsUsed ?? 0)/\(LiveMatchState.maxSubstitutions))",
                          systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(staticPreview || (career.liveMatch?.substitutionsUsed ?? 0) >= LiveMatchState.maxSubstitutions)
                .accessibilityIdentifier("live-substitutions")
                tiredStarters
            }
            Button(action: startSecondHalf) {
                Label("Começar o 2º tempo", systemImage: "play.fill")
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .accessibilityIdentifier("live-second-half")
        }
    }

    @ViewBuilder
    private var tiredStarters: some View {
        let tired = career.starters.filter { $0.condition < 70 }
        if !tired.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Titulares cansados").font(.caption.weight(.bold)).foregroundStyle(.orange)
                ForEach(tired) { player in
                    HStack {
                        Text(player.name).font(.caption)
                        Spacer()
                        Text("\(player.condition)%").font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(ConditionBar.color(for: player.condition))
                    }
                }
            }
        }
    }

    private var fullTimePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let fixture, let club = career.selectedClubID, let result = fixture.result(for: club) {
                resultBanner(result)
                FactoryPanel(title: "Estatísticas finais", systemImage: "chart.bar.fill") {
                    FootballMatchReport(fixture: fixture, career: career, showAllEvents: false)
                }
            }
            Button {
                tickTask?.cancel()
                onClose()
            } label: {
                Label("Concluir rodada", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .accessibilityIdentifier("live-finish")
        }
    }

    private func resultBanner(_ result: FootballResult) -> some View {
        let text: String
        let tint: Color
        switch result {
        case .win:
            text = "Vitória! Três pontos para a conta."
            tint = .green
        case .draw:
            text = "Empate. Um ponto na tabela."
            tint = .gray
        case .loss:
            text = "Derrota. Hora de rever o plano."
            tint = .red
        }
        return Label(text, systemImage: result == .win ? "star.fill" : (result == .draw ? "equal.circle.fill" : "xmark.circle.fill"))
            .font(.headline)
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func liveStats(live: LiveMatchState, fixture: LeagueFixture) -> some View {
        let homeColor = FootballSeason.team(fixture.home)?.primaryColor ?? FootballTheme.accent
        let awayColor = FootballSeason.team(fixture.away)?.primaryColor ?? .gray
        return VStack(spacing: 12) {
            StatComparisonRow(title: "Posse de bola", home: Double(live.homePossession), away: Double(100 - live.homePossession),
                              homeText: "\(live.homePossession)%", awayText: "\(100 - live.homePossession)%",
                              homeColor: homeColor, awayColor: awayColor)
            StatComparisonRow(title: "Finalizações", home: Double(live.homeShots), away: Double(live.awayShots),
                              homeText: "\(live.homeShots)", awayText: "\(live.awayShots)",
                              homeColor: homeColor, awayColor: awayColor)
            StatComparisonRow(title: "Gols esperados (xG)", home: live.homeExpectedGoals, away: live.awayExpectedGoals,
                              homeText: FootballFormat.expectedGoals(live.homeExpectedGoals),
                              awayText: FootballFormat.expectedGoals(live.awayExpectedGoals),
                              homeColor: homeColor, awayColor: awayColor)
        }
    }

    // MARK: - Relógio

    private func start() {
        guard !didStart else { return }
        didStart = true
        fixtureID = career.liveMatch?.fixtureID
        guard career.liveMatch != nil else {
            onClose()
            return
        }
        if staticPreview {
            minute = 45
            phase = .halfTime
            return
        }
        // Uma partida retomada (app reaberto no intervalo) volta direto ao vestiário.
        let resumed = (career.liveMatch?.substitutionsUsed ?? 0) > 0 || career.liveMatch?.styleAtKickoff != career.playStyle
        if resumed {
            minute = 45
            phase = .halfTime
            return
        }
        runClock(to: 45) { phase = .halfTime }
    }

    private func runClock(to end: Int, completion: @escaping () -> Void) {
        tickTask?.cancel()
        let delay = tickNanoseconds
        tickTask = Task { @MainActor in
            while minute < end {
                try? await Task.sleep(nanoseconds: delay)
                if Task.isCancelled { return }
                withAnimation(.easeOut(duration: 0.1)) { minute += 1 }
            }
            completion()
        }
    }

    private func skip() {
        tickTask?.cancel()
        switch phase {
        case .firstHalf:
            minute = 45
            phase = .halfTime
        case .secondHalf:
            minute = 90
            phase = .fullTime
        default:
            break
        }
    }

    private func startSecondHalf() {
        guard !staticPreview else { return }
        guard career.finishMatchDay() else {
            onClose()
            return
        }
        minute = 45
        phase = .secondHalf
        runClock(to: 90) { phase = .fullTime }
    }
}

// MARK: - Substituições

struct FootballSubstitutionSheet: View {
    @Binding var career: FootballCareer
    @State private var outgoingID: Int?
    @Environment(\.dismiss) private var dismiss

    init(career: Binding<FootballCareer>, outgoingID: Int?) {
        _career = career
        _outgoingID = State(initialValue: outgoingID)
    }

    private var bench: [FootballPlayer] {
        career.clubRoster.filter { !career.startingXI.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let outgoingID, let outgoing = career.player(outgoingID) {
                    Section("Sai") {
                        PlayerRow(player: outgoing, isStarter: true)
                        Button("Escolher outro titular") { self.outgoingID = nil }
                            .font(.subheadline)
                    }
                    let samePosition = bench.filter { $0.position == outgoing.position }
                    let others = bench.filter { $0.position != outgoing.position }
                    Section("Entra · \(outgoing.position.title.lowercased())") {
                        if samePosition.isEmpty {
                            Text("Nenhum reserva desta posição.").font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(samePosition) { player in incomingButton(player, replacing: outgoing) }
                    }
                    if !others.isEmpty {
                        Section("Improvisar outra posição") {
                            ForEach(others) { player in incomingButton(player, replacing: outgoing) }
                        }
                    }
                } else {
                    Section("Quem sai?") {
                        ForEach(career.starters) { player in
                            Button { outgoingID = player.id } label: {
                                PlayerRow(player: player, isStarter: true)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("sub-out-\(player.id)")
                        }
                    }
                }
            }
            .navigationTitle(career.liveMatch == nil ? "Trocar titular" : "Substituição")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .tint(FootballTheme.accent)
    }

    private func incomingButton(_ player: FootballPlayer, replacing outgoing: FootballPlayer) -> some View {
        Button {
            if career.substitute(outgoingID: outgoing.id, incomingID: player.id) { dismiss() }
        } label: {
            PlayerRow(player: player)
        }
        .buttonStyle(.plain)
        .disabled(!career.canSubstitute(outgoingID: outgoing.id, incomingID: player.id))
        .opacity(career.canSubstitute(outgoingID: outgoing.id, incomingID: player.id) ? 1 : 0.45)
        .accessibilityIdentifier("sub-in-\(player.id)")
    }
}

// MARK: - Resumo de temporada

struct FootballSeasonSummaryView: View {
    let record: SeasonRecord
    let career: FootballCareer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let champion = FootballSeason.team(record.championID) {
                        VStack(spacing: 10) {
                            Image(systemName: "trophy.fill").font(.system(size: 44)).foregroundStyle(FootballTheme.gold)
                            ClubCrest(team: champion, size: 64)
                            Text("\(champion.name) é campeão da temporada \(record.season)")
                                .font(.title3.bold()).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    FactoryPanel(title: "Sua campanha", systemImage: "chart.line.uptrend.xyaxis") {
                        summaryRow("Posição final", "\(record.position)º · \(record.points) pts")
                        summaryRow("Meta da diretoria", FootballCareer.objectiveText(target: record.target))
                        Label(record.objectiveMet ? "Meta cumprida" : "Meta não cumprida",
                              systemImage: record.objectiveMet ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(record.objectiveMet ? .green : .red)
                        summaryRow("Premiação recebida", FootballFormat.money(record.prizeMoney))
                    }
                    FactoryPanel(title: "Destaques", systemImage: "star.fill") {
                        summaryRow("Artilheiro da liga", "\(record.topScorerName) · \(record.topScorerGoals) gols")
                        summaryRow("Aposentadorias no elenco", "\(record.retiredPlayers)")
                        summaryRow("Promessas da base", "\(record.youthPromoted)")
                        Text("Na pré-temporada todos os atletas envelheceram um ano: jovens evoluem e veteranos perdem rendimento.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if record.wasFired {
                        FactoryPanel(title: "Diretoria", systemImage: "person.fill.xmark") {
                            Text("A diretoria decidiu encerrar seu ciclo. Escolha um novo clube no painel para continuar a carreira.")
                                .font(.subheadline)
                        }
                    }
                    Button { dismiss() } label: {
                        Label("Começar temporada \(record.season + 1)", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(FactoryPrimaryButtonStyle())
                    .accessibilityIdentifier("summary-continue")
                }
                .padding(20)
            }
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle("Fim da temporada")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(FootballTheme.accent)
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).multilineTextAlignment(.trailing)
        }
    }
}
