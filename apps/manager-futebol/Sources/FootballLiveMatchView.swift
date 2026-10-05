import SwiftUI

/// Partida ao vivo, minuto a minuto: relógio com velocidades, narração, tática, números e mapa do jogo.
struct FootballLiveMatchView: View {
    enum LiveSection: String, CaseIterable, Identifiable {
        case feed = "Lances", tactics = "Tática", stats = "Números", pitch = "Campo"

        var id: String { rawValue }
    }

    @Binding var career: FootballCareer
    let staticPreview: Bool
    let onClose: () -> Void

    @State private var running = false
    @State private var speed = 1
    @State private var section: LiveSection = .feed
    @State private var tickTask: Task<Void, Never>?
    @State private var showSubstitutions = false
    @State private var didStart = false
    @State private var finishing = false
    @State private var quickFeedback = 0
    @State private var keyMoments: KeyMomentMode = .brief
    @State private var pitchExpanded = false
    @AppStorage("football.liveViewMode") private var viewModeRaw = LiveViewMode.narration.rawValue

    /// Como acompanhar a partida: texto (padrão) ou o campo animado.
    enum LiveViewMode: String, CaseIterable, Identifiable {
        case narration = "Narração", watch = "Ver jogo"

        var id: String { rawValue }
    }

    private var viewMode: LiveViewMode {
        if staticPreview {
            let screen = FactoryCapture.screen
            return screen == "match-narration" || screen == "match-final" ? .narration : .watch
        }
        return LiveViewMode(rawValue: viewModeRaw) ?? .narration
    }
    @State private var impactPreview: MatchImpact?

    /// O que o relógio faz quando sai gol, pênalti ou lesão.
    enum KeyMomentMode: String, CaseIterable, Identifiable {
        case off = "Direto", brief = "Breve", pause = "Pausar"

        var id: String { rawValue }
    }

    private var live: LiveMatchState? { career.liveMatch }

    private var tickNanoseconds: UInt64 {
        if FactoryCapture.isUITesting { return 10_000_000 }
        switch speed {
        case 4: return 45_000_000
        case 2: return 120_000_000
        default: return 280_000_000
        }
    }

    private var userTeamID: Int? { career.selectedClubID }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let live {
                    VStack(alignment: .leading, spacing: 16) {
                        scoreboard(live)
                        if live.sim.finished { fullTimePanel(live) }
                        viewModePicker
                        if viewMode == .watch {
                            watchPanel(live)
                        } else {
                            narrationCard(live)
                        }
                        controls(live)
                        if !live.sim.finished { quickActions(live) }
                                        Picker("Seção", selection: $section) {
                            ForEach(LiveSection.allCases) { item in Text(item.rawValue).tag(item) }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("live-section")
                        switch section {
                        case .feed: feedPanel(live)
                        case .tactics: FootballLiveTacticsPanel(career: $career, locked: staticPreview) { showSubstitutions = true }
                        case .stats: statsPanel(live)
                        case .pitch: pitchPanel(live)
                        }
                        othersPanel(live)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: 780)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle(live.flatMap { title(for: $0) } ?? "Partida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !staticPreview, let live, !live.sim.finished {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Sair") {
                            stopClock()
                            onClose()
                        }
                        .accessibilityHint("A partida fica salva neste minuto")
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: live?.homeGoals ?? 0)
        .sensoryFeedback(.selection, trigger: quickFeedback)
        .sensoryFeedback(.warning, trigger: live?.sim.events.filter { $0.kind == .redCard }.count ?? 0)
        .sheet(isPresented: $showSubstitutions) {
            FootballSubstitutionSheet(career: $career, outgoingID: nil)
        }
        .onAppear(perform: start)
        .onDisappear { tickTask?.cancel() }
    }

    private func title(for live: LiveMatchState) -> String? {
        career.fixtures.first { $0.id == live.fixtureID }?.title
    }

    // MARK: - Placar

    private func scoreboard(_ live: LiveMatchState) -> some View {
        let sim = live.sim
        return VStack(spacing: 12) {
            MatchupHeader(home: FootballSeason.team(sim.home.teamID), away: FootballSeason.team(sim.away.teamID),
                          homeScore: sim.home.goals, awayScore: sim.away.goals, crestSize: 54)
                .accessibilityIdentifier("live-scoreboard")
            HStack(spacing: 8) {
                Circle().fill(running ? Color.red : Color.secondary).frame(width: 8, height: 8)
                Text(clockText(sim))
                    .font(.headline.monospacedDigit())
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06), in: Capsule())
            .accessibilityIdentifier("live-clock")
            ProgressView(value: Double(min(sim.minute, sim.inExtraTime || sim.wentToExtraTime ? 120 : sim.regulationEnd)),
                         total: Double(sim.inExtraTime || sim.wentToExtraTime ? 120 : sim.regulationEnd))
                .tint(FootballTheme.accent)
            momentumBar(sim)
        }
        .padding(18)
        .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func clockText(_ sim: MatchSimulation) -> String {
        if sim.finished { return "Fim de jogo" }
        if sim.minute == 45 && !running { return "Intervalo · 45′" }
        if sim.inExtraTime || sim.wentToExtraTime { return sim.minute > 90 ? "Prorrogação · \(sim.minute)′" : "\(sim.minute)′" }
        if sim.minute > 90 { return "Acréscimos · 90+\(sim.minute - 90)′" }
        return "\(sim.minute)′"
    }

    private func momentumBar(_ sim: MatchSimulation) -> some View {
        let recent = sim.momentum.suffix(10)
        let value = recent.isEmpty ? 0 : Double(recent.reduce(0, +)) / Double(recent.count)
        let share = min(1, max(0, 0.5 + value / 200))
        let homeColor = FootballSeason.team(sim.home.teamID)?.primaryColor ?? FootballTheme.accent
        let awayColor = FootballSeason.team(sim.away.teamID)?.primaryColor ?? .gray
        return VStack(spacing: 4) {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    Capsule().fill(homeColor).frame(width: max(6, (proxy.size.width - 2) * share))
                    Capsule().fill(awayColor)
                }
            }
            .frame(height: 6)
            Text("Pressão nos últimos minutos").font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pressão recente: \(Int(share * 100))% para o mandante")
    }

    // MARK: - Controles

    private func controls(_ live: LiveMatchState) -> some View {
        VStack(spacing: 10) {
            if !live.sim.finished {
                HStack(spacing: 10) {
                    Button(action: toggleClock) {
                        Label(running ? "Pausar" : (live.sim.minute == 0 ? "Começar" : "Continuar"),
                              systemImage: running ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(staticPreview)
                    .accessibilityIdentifier("live-toggle")
                    Picker("Velocidade", selection: $speed) {
                        Text("1×").tag(1)
                        Text("2×").tag(2)
                        Text("4×").tag(4)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 150)
                    .accessibilityIdentifier("live-speed")
                }
                HStack(spacing: 10) {
                    Button { advance(minutes: 5) } label: {
                        Label("+5 min", systemImage: "goforward.5").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(staticPreview)
                    Button { showSubstitutions = true } label: {
                        Label("Trocar (\(live.substitutionsUsed)/\(LiveMatchState.maxSubstitutions))", systemImage: "arrow.left.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(staticPreview || live.substitutionsUsed >= LiveMatchState.maxSubstitutions)
                    .accessibilityIdentifier("live-substitutions")
                    Button(action: skipToEnd) {
                        Label("Ao final", systemImage: "forward.end.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(staticPreview)
                    .accessibilityIdentifier("live-skip")
                }
                .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    Text("Lances-chave").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Lances-chave", selection: $keyMoments) {
                        ForEach(KeyMomentMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("live-key-moments")
                }
                if live.sim.minute == 45 && !running {
                    Label("Intervalo: troque jogadores à vontade e ajuste a tática antes do 2º tempo.", systemImage: "person.2.wave.2.fill")
                        .font(.caption.weight(.medium)).foregroundStyle(FootballTheme.accent)
                }
            }
        }
    }

    // MARK: - Narração e campo

    private var viewModePicker: some View {
        Picker("Acompanhar", selection: Binding(get: { viewMode }, set: { viewModeRaw = $0.rawValue })) {
            ForEach(LiveViewMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode == .narration ? "text.bubble.fill" : "sportscourt.fill").tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .disabled(staticPreview)
        .accessibilityIdentifier("live-view-mode")
    }

    private func watchPanel(_ live: LiveMatchState) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            FootballLivePitchView(live: live, career: career, running: running, speed: speed, height: pitchExpanded ? 340 : 230)
            Button {
                withAnimation(.snappy) { pitchExpanded.toggle() }
            } label: {
                Label(pitchExpanded ? "Reduzir" : "Ampliar", systemImage: pitchExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("live-pitch-expand")
        }
    }

    /// Texto grande com o lance do momento e os anteriores, como um narrador de rádio.
    private func narrationCard(_ live: LiveMatchState) -> some View {
        let recent = Array(live.sim.events.filter { $0.kind != .tactic }.suffix(3).reversed())
        return FactoryPanel(title: "Narração", systemImage: "mic.fill") {
            if recent.isEmpty {
                Text("A bola vai rolar…").font(.title3.weight(.semibold))
            }
            ForEach(Array(recent.enumerated()), id: \.offset) { position, event in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(event.minuteLabel)
                        .font((position == 0 ? Font.title3 : Font.subheadline).weight(.heavy).monospacedDigit())
                        .foregroundStyle(event.kind == .goal ? FootballTheme.accent : .secondary)
                        .frame(width: 66, alignment: .trailing)
                    Text(event.text)
                        .font(position == 0 ? Font.title3.weight(.semibold) : Font.subheadline)
                        .foregroundStyle(position == 0 ? Color.primary : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("live-narration")
    }

    // MARK: - Ações rápidas

    private func quickActions(_ live: LiveMatchState) -> some View {
        let side = live.userSide
        let active = QuickTacticPreset.allCases.first { $0.isActive(on: side) }
        return FactoryPanel(title: "Ações rápidas", systemImage: "bolt.circle.fill") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(QuickTacticPreset.allCases) { preset in
                        let selected = preset == active
                        Button {
                            if career.liveApplyPreset(preset) { quickFeedback += 1 }
                        } label: {
                            Label(preset.title, systemImage: preset.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .background(selected ? FootballTheme.accent : Color.primary.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(staticPreview)
                        .accessibilityIdentifier("quick-preset-\(preset.rawValue)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            Text(active?.summary ?? "Plano personalizado. Escolha um atalho para trocar tudo de uma vez.")
                .font(.caption).foregroundStyle(.secondary)
            if career.tacticalPlan(.a) != nil || career.tacticalPlan(.b) != nil {
                HStack(spacing: 8) {
                    ForEach(PlanSlot.allCases) { slot in
                        Button {
                            if career.liveApplyTacticalPlan(slot).applied { quickFeedback += 1 }
                        } label: {
                            Label(slot.title, systemImage: "square.on.square").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(staticPreview || career.tacticalPlan(slot) == nil)
                        .accessibilityIdentifier("quick-plan-\(slot.rawValue)")
                    }
                }
            }
            HStack(spacing: 8) {
                ForEach(QuickSubstitutionKind.allCases) { kind in
                    let plan = career.liveQuickSubstitutionPlan(kind)
                    Button {
                        if career.liveQuickSubstitute(kind) { quickFeedback += 1 }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: kind.systemImage)
                            Text(kind.title).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
                            Text(quickSubLabel(plan))
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(staticPreview || plan == nil)
                    .accessibilityIdentifier("quick-sub-\(kind.rawValue)")
                }
            }
        }
        .accessibilityIdentifier("live-quick-actions")
    }

    private func quickSubLabel(_ plan: (out: FootballPlayer, incoming: FootballPlayer)?) -> String {
        guard let plan else { return "Indisponível" }
        let outName = plan.out.name.split(separator: " ").last.map(String.init) ?? plan.out.name
        let inName = plan.incoming.name.split(separator: " ").last.map(String.init) ?? plan.incoming.name
        return "\(outName) → \(inName)"
    }

    private func fullTimePanel(_ live: LiveMatchState) -> some View {
        let userGoals = live.userIsHome ? live.homeGoals : live.awayGoals
        let rivalGoals = live.userIsHome ? live.awayGoals : live.homeGoals
        let result: FootballResult = userGoals > rivalGoals ? .win : (userGoals == rivalGoals ? .draw : .loss)
        return VStack(alignment: .leading, spacing: 12) {
            resultBanner(result, penalties: live.sim.needsShootout)
            if let impactPreview { MatchImpactCard(impact: impactPreview, hypeTitle: hypeTitle(for: impactPreview)) }
            Button {
                finishing = true
                stopClock()
                _ = career.finishMatchDay()
                onClose()
            } label: {
                Label("Concluir rodada", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .disabled(staticPreview || finishing)
            .accessibilityIdentifier("live-finish")
        }
        .task { if impactPreview == nil { impactPreview = career.previewMatchImpact() } }
    }

    private func hypeTitle(for impact: MatchImpact) -> String {
        var copy = career
        copy.clubHype = impact.hypeAfter
        return copy.hypeTitle
    }

    private func resultBanner(_ result: FootballResult, penalties: Bool) -> some View {
        let text: String
        let tint: Color
        switch result {
        case .win:
            text = "Vitória! Três pontos para a conta."
            tint = .green
        case .draw:
            text = penalties ? "Empate no tempo regulamentar: a decisão vai aos pênaltis." : "Empate. Um ponto na tabela."
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

    // MARK: - Lance a lance

    private func feedPanel(_ live: LiveMatchState) -> some View {
        let events = live.sim.events
        return FactoryPanel(title: "Lance a lance", systemImage: "text.bubble.fill") {
            if events.isEmpty {
                Text("A bola vai rolar…").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(Array(Array(events.enumerated()).suffix(60).reversed()), id: \.offset) { _, event in
                MatchEventRow(event: event)
            }
        }
        .accessibilityIdentifier("live-feed")
    }

    // MARK: - Números

    private func statsPanel(_ live: LiveMatchState) -> some View {
        let sim = live.sim
        let homeColor = FootballSeason.team(sim.home.teamID)?.primaryColor ?? FootballTheme.accent
        let awayColor = FootballSeason.team(sim.away.teamID)?.primaryColor ?? .gray
        let possession = sim.minute > 0 ? Int((sim.home.possessionAccumulator / Double(sim.minute) * 100).rounded()) : 50
        return FactoryPanel(title: "Estatísticas ao vivo", systemImage: "chart.bar.fill") {
            StatComparisonRow(title: "Posse de bola", home: Double(possession), away: Double(100 - possession),
                              homeText: "\(possession)%", awayText: "\(100 - possession)%", homeColor: homeColor, awayColor: awayColor)
            statRow("Finalizações", sim.home.shots, sim.away.shots, homeColor, awayColor)
            statRow("No alvo", sim.home.shotsOnTarget, sim.away.shotsOnTarget, homeColor, awayColor)
            StatComparisonRow(title: "Gols esperados (xG)", home: sim.home.expectedGoals, away: sim.away.expectedGoals,
                              homeText: FootballFormat.expectedGoals(sim.home.expectedGoals),
                              awayText: FootballFormat.expectedGoals(sim.away.expectedGoals), homeColor: homeColor, awayColor: awayColor)
            statRow("Escanteios", sim.home.corners, sim.away.corners, homeColor, awayColor)
            statRow("Faltas", sim.home.fouls, sim.away.fouls, homeColor, awayColor)
            statRow("Cartões amarelos", sim.home.yellowCards, sim.away.yellowCards, homeColor, awayColor)
            if sim.home.redCards + sim.away.redCards > 0 {
                statRow("Cartões vermelhos", sim.home.redCards, sim.away.redCards, homeColor, awayColor)
            }
            Divider()
            Text("Seus atletas em campo").font(.caption.weight(.heavy)).foregroundStyle(.secondary)
            ForEach(live.userSide.onPitch, id: \.self) { id in
                if let player = career.player(id) {
                    HStack(spacing: 10) {
                        Text(player.position.rawValue).font(.caption2.weight(.bold)).frame(width: 26)
                        Text(player.name).font(.subheadline).lineLimit(1)
                        Spacer()
                        let condition = Int(live.userSide.matchCondition[id] ?? Double(player.condition))
                        Text("\(condition)%").font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(ConditionBar.color(for: condition))
                    }
                }
            }
        }
    }

    private func statRow(_ title: String, _ home: Int, _ away: Int, _ homeColor: Color, _ awayColor: Color) -> some View {
        StatComparisonRow(title: title, home: Double(home), away: Double(away), homeText: "\(home)", awayText: "\(away)",
                          homeColor: homeColor, awayColor: awayColor)
    }

    // MARK: - Campo

    private func pitchPanel(_ live: LiveMatchState) -> some View {
        FactoryPanel(title: "Mapa de finalizações", systemImage: "scope") {
            VStack(alignment: .leading, spacing: 6) {
                Label("Ambiente da partida", systemImage: "figure.soccer")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(FootballTheme.accent)
                Image(matchSceneName(live))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("Ilustração do estádio durante a partida")
            }
            FootballShotMap(sim: live.sim)
            Text("Cada bolinha é uma finalização; as maiores têm mais chance de gol. O anel marca os gols.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Mapa de calor do seu time").font(.caption.weight(.heavy)).foregroundStyle(.secondary)
            FootballHeatMap(heat: teamHeat(live.userSide), color: career.selectedClub?.primaryColor ?? FootballTheme.accent)
        }
    }

    /// Copa vai para a transmissão, rodadas ímpares à noite e as demais de dia.
    private func matchSceneName(_ live: LiveMatchState) -> String {
        if career.fixtures.first(where: { $0.id == live.fixtureID })?.competition.isCup == true { return "MatchSceneTv" }
        return live.matchDay % 2 == 1 ? "MatchSceneNoite" : "MatchSceneDia"
    }

    private func teamHeat(_ side: MatchSideState) -> [Int] {
        var total = [Int](repeating: 0, count: MatchSideState.heatColumns * MatchSideState.heatRows)
        for (_, cells) in side.heat {
            for (index, value) in cells.enumerated() where index < total.count { total[index] += value }
        }
        return total
    }

    // MARK: - Outros jogos

    @ViewBuilder
    private func othersPanel(_ live: LiveMatchState) -> some View {
        if !live.others.isEmpty {
            FactoryPanel(title: "Outros jogos da rodada", systemImage: "list.bullet.rectangle") {
                ForEach(Array(live.others.enumerated()), id: \.offset) { _, outcome in
                    if let fixture = career.fixtures.first(where: { $0.id == outcome.fixtureID }) {
                        let score = live.score(of: outcome, at: live.sim.minute)
                        HStack(spacing: 8) {
                            Text(FootballSeason.team(fixture.home)?.shortName ?? "—").font(.caption.weight(.bold)).frame(width: 40, alignment: .trailing)
                            Text("\(score.home) – \(score.away)").font(.subheadline.weight(.heavy).monospacedDigit()).frame(width: 60)
                            Text(FootballSeason.team(fixture.away)?.shortName ?? "—").font(.caption.weight(.bold)).frame(width: 40, alignment: .leading)
                            Spacer()
                            Text(fixture.competition.isCup ? "Copa" : (fixture.competition.division?.name ?? "")).font(.caption2).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    // MARK: - Relógio

    private func start() {
        guard !didStart else { return }
        didStart = true
        guard career.liveMatch != nil else {
            onClose()
            return
        }
        if staticPreview {
            switch FactoryCapture.screen {
            case "match-final":
                career.liveAdvance(minutes: 200)
            case "match-goal":
                career.liveAdvance(to: 5)
                while let sim = career.liveMatch?.sim, !sim.finished, sim.minute < 90 {
                    career.liveAdvance(minutes: 1)
                    if career.liveMatch?.sim.events.last(where: { $0.kind == .goal })?.minute == career.liveMatch?.sim.minute { break }
                }
            default:
                career.liveAdvance(to: 38)
            }
            return
        }
        // Partida retomada fica pausada; partida nova começa sozinha.
        if (career.liveMatch?.sim.minute ?? 0) == 0 { startClock() }
    }

    private func toggleClock() {
        if running { stopClock() } else { startClock() }
    }

    private func stopClock() {
        running = false
        tickTask?.cancel()
    }

    private func startClock() {
        tickTask?.cancel()
        guard !staticPreview, career.liveMatch?.sim.finished == false else { return }
        running = true
        tickTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: tickNanoseconds)
                if Task.isCancelled { return }
                guard career.liveMatch?.sim.finished == false else {
                    running = false
                    return
                }
                let reds = career.liveMatch?.sim.events.filter { $0.kind == .redCard }.count ?? 0
                let keyBefore = keyMomentCount(career.liveMatch)
                career.liveAdvance(minutes: 1)
                let after = career.liveMatch
                if after?.sim.finished == true {
                    running = false
                    return
                }
                // Pausa automática no intervalo e a cada expulsão para o treinador reagir.
                if after?.sim.minute == 45 || (after?.sim.events.filter { $0.kind == .redCard }.count ?? 0) > reds {
                    running = false
                    return
                }
                // Gol, pênalti e lesão: pausa total ou uma respirada para o lance render.
                if keyMoments != .off, keyMomentCount(after) > keyBefore {
                    if keyMoments == .pause {
                        running = false
                        return
                    }
                    if !FactoryCapture.isUITesting { try? await Task.sleep(nanoseconds: 1_300_000_000) }
                }
            }
        }
    }

    private func keyMomentCount(_ live: LiveMatchState?) -> Int {
        live?.sim.events.filter { $0.kind == .goal || $0.kind == .penaltyAwarded || $0.kind == .injury }.count ?? 0
    }

    private func advance(minutes: Int) {
        stopClock()
        career.liveAdvance(minutes: minutes)
    }

    private func skipToEnd() {
        stopClock()
        career.liveAdvance(minutes: 200)
    }
}

// MARK: - Tática ao vivo

struct FootballLiveTacticsPanel: View {
    @Binding var career: FootballCareer
    let locked: Bool
    let onSubstitutions: () -> Void

    private var userSide: MatchSideState? { career.liveMatch?.userSide }

    var body: some View {
        if let side = userSide {
            VStack(alignment: .leading, spacing: 16) {
                FactoryPanel(title: "Plano de jogo", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                    if let opponentStyle = career.predictedOpponentStyle {
                        Label("Auxiliar sugere: \(FootballPlayStyle.bestAnswer(to: opponentStyle).rawValue)", systemImage: "lightbulb.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(FootballTheme.accent)
                    }
                    Picker("Formação", selection: Binding(get: { side.formation }, set: { career.liveSetFormation($0) })) {
                        ForEach(FootballFormation.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(locked)
                    HStack {
                        Text("Estilo").font(.subheadline.weight(.semibold))
                        Spacer()
                        Picker("Estilo", selection: Binding(get: { side.style }, set: { career.liveSetStyle($0) })) {
                            ForEach(FootballPlayStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .disabled(locked)
                        .accessibilityIdentifier("live-style-picker")
                    }
                    Text(side.style.summary).font(.caption).foregroundStyle(.secondary)
                }
                FactoryPanel(title: "Instruções", systemImage: "slider.horizontal.3") {
                    levelPicker("Altura da linha", TeamInstructions.lineHeightTitles, side.instructions.lineHeight) { $0.lineHeight = $1 }
                    levelPicker("Ritmo", TeamInstructions.tempoTitles, side.instructions.tempo) { $0.tempo = $1 }
                    levelPicker("Largura", TeamInstructions.widthTitles, side.instructions.width) { $0.width = $1 }
                    levelPicker("Pressão", TeamInstructions.pressingTitles, side.instructions.pressing) { $0.pressing = $1 }
                    Toggle("Fazer cera", isOn: Binding(
                        get: { side.instructions.timeWasting },
                        set: { value in
                            var instructions = side.instructions
                            instructions.timeWasting = value
                            career.liveSetInstructions(instructions)
                        }
                    ))
                    .font(.subheadline)
                    .disabled(locked)
                    Text("Linha alta e pressão forte cansam mais e geram mais faltas. Cera protege o placar, mas entrega a bola.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                FactoryPanel(title: "Funções e marcação", systemImage: "person.crop.rectangle.stack.fill") {
                    ForEach(side.onPitch, id: \.self) { id in
                        if let player = career.player(id), player.position != .goalkeeper {
                            HStack {
                                Text(player.name).font(.subheadline).lineLimit(1)
                                Spacer()
                                Picker("Função", selection: Binding(
                                    get: { side.roles[id] ?? .balanced },
                                    set: { career.liveSetRole(playerID: id, role: $0) }
                                )) {
                                    ForEach(PlayerRole.options(for: player.detail)) { Text($0.title).tag($0) }
                                }
                                .pickerStyle(.menu)
                                .disabled(locked)
                            }
                        }
                    }
                    HStack {
                        Text("Marcação individual").font(.subheadline.weight(.semibold))
                        Spacer()
                        Picker("Marcar", selection: Binding(
                            get: { side.markTargetID },
                            set: { career.liveSetMarking(targetID: $0) }
                        )) {
                            Text("Ninguém").tag(Int?.none)
                            ForEach(career.liveRivalOnPitch.filter { $0.position != .goalkeeper }) { rival in
                                Text(rival.name).tag(Int?.some(rival.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(locked)
                    }
                }
                Button(action: onSubstitutions) {
                    Label("Substituições (\(side.substitutionsUsed)/\(LiveMatchState.maxSubstitutions))", systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(locked || side.substitutionsUsed >= LiveMatchState.maxSubstitutions)
            }
        }
    }

    private func levelPicker(_ title: String, _ names: [String], _ current: Level3,
                             _ update: @escaping (inout TeamInstructions, Level3) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Picker(title, selection: Binding(
                get: { current },
                set: { value in
                    var instructions = career.liveMatch?.userSide.instructions ?? TeamInstructions()
                    update(&instructions, value)
                    career.liveSetInstructions(instructions)
                }
            )) {
                ForEach(Level3.allCases) { level in Text(names[level.rawValue]).tag(level) }
            }
            .pickerStyle(.segmented)
            .disabled(locked)
        }
    }
}

// MARK: - Mapas

struct FootballShotMap: View {
    let sim: MatchSimulation

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [FootballTheme.pitchTop, FootballTheme.pitchBottom], startPoint: .top, endPoint: .bottom))
                ShotMapMarkings().stroke(Color.white.opacity(0.35), lineWidth: 1.2).padding(8)
                ForEach(Array(sim.events.enumerated()), id: \.offset) { _, event in
                    if let x = event.x, let y = event.y, event.kind == .goal || event.kind == .chance || event.kind == .save {
                        let isHome = event.teamID == sim.home.teamID
                        let color = FootballSeason.team(event.teamID ?? -1)?.primaryColor ?? .white
                        let radius = 5 + CGFloat(min(0.6, event.xg ?? 0.1)) * 18
                        let px = 8 + (size.width - 16) * CGFloat(y)
                        // Mandante ataca para cima, visitante para baixo.
                        let distance = CGFloat(x) * (size.height - 16) / 2
                        let py = isHome ? 8 + distance : size.height - 8 - distance
                        Circle()
                            .fill(color.opacity(event.kind == .goal ? 1 : 0.7))
                            .overlay(Circle().stroke(event.kind == .goal ? Color.white : Color.clear, lineWidth: 2.5))
                            .frame(width: radius * 2, height: radius * 2)
                            .position(x: px, y: py)
                    }
                }
            }
        }
        .frame(height: 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mapa de finalizações da partida")
    }
}

private struct ShotMapMarkings: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        let radius = min(rect.width, rect.height) * 0.1
        path.addEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2))
        let boxWidth = rect.width * 0.55
        let boxHeight = rect.height * 0.16
        path.addRect(CGRect(x: rect.midX - boxWidth / 2, y: rect.minY, width: boxWidth, height: boxHeight))
        path.addRect(CGRect(x: rect.midX - boxWidth / 2, y: rect.maxY - boxHeight, width: boxWidth, height: boxHeight))
        return path
    }
}

struct FootballHeatMap: View {
    let heat: [Int]
    let color: Color

    var body: some View {
        let columns = MatchSideState.heatColumns
        let rows = MatchSideState.heatRows
        let peak = Double(max(1, heat.max() ?? 1))
        VStack(spacing: 2) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        let value = index < heat.count ? Double(heat[index]) / peak : 0
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color.opacity(0.12 + 0.88 * value))
                            .frame(height: 44)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mapa de calor do time")
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

    private var pitchIDs: [Int] { career.liveMatch?.userSide.onPitch ?? career.startingXI }

    private var benchPlayers: [FootballPlayer] {
        if let side = career.liveMatch?.userSide { return side.bench.compactMap { career.player($0) } }
        return career.clubRoster.filter { !career.startingXI.contains($0.id) && !$0.isYouth }
    }

    var body: some View {
        NavigationStack {
            List {
                if let live = career.liveMatch {
                    Section {
                        Text("Trocas: \(live.substitutionsUsed)/\(LiveMatchState.maxSubstitutions) · paradas: \(live.substitutionStops)/\(LiveMatchState.maxSubstitutionStops). O intervalo não conta como parada.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let outgoingID, let outgoing = career.player(outgoingID) {
                    Section("Sai") {
                        PlayerRow(player: outgoing, isStarter: true)
                        Button("Escolher outro titular") { self.outgoingID = nil }.font(.subheadline)
                    }
                    let same = benchPlayers.filter { $0.position == outgoing.position }
                    let others = benchPlayers.filter { $0.position != outgoing.position }
                    Section("Entra · \(outgoing.position.title.lowercased())") {
                        if same.isEmpty { Text("Nenhum reserva desta posição.").font(.subheadline).foregroundStyle(.secondary) }
                        ForEach(same) { player in incomingButton(player, replacing: outgoing) }
                    }
                    if !others.isEmpty {
                        Section("Improvisar outra posição") {
                            ForEach(others) { player in incomingButton(player, replacing: outgoing) }
                        }
                    }
                } else {
                    Section("Quem sai?") {
                        ForEach(pitchIDs.compactMap { career.player($0) }) { player in
                            Button { outgoingID = player.id } label: { PlayerRow(player: player, isStarter: true) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("sub-out-\(player.id)")
                        }
                    }
                }
            }
            .navigationTitle(career.liveMatch == nil ? "Trocar titular" : "Substituição")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
        }
        .tint(FootballTheme.accent)
    }

    private func incomingButton(_ player: FootballPlayer, replacing outgoing: FootballPlayer) -> some View {
        let allowed = career.canSubstitute(outgoingID: outgoing.id, incomingID: player.id)
        return Button {
            if career.substitute(outgoingID: outgoing.id, incomingID: player.id) { dismiss() }
        } label: {
            PlayerRow(player: player)
        }
        .buttonStyle(.plain)
        .disabled(!allowed)
        .opacity(allowed ? 1 : 0.45)
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
                            Text("\(champion.name) é campeão da Série A na temporada \(record.season)")
                                .font(.title3.bold()).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    FactoryPanel(title: "Sua campanha", systemImage: "chart.line.uptrend.xyaxis") {
                        summaryRow("Posição final", "\(record.position)º · \(record.points) pts")
                        summaryRow("Divisão", record.division.name)
                        summaryRow("Meta da diretoria", FootballCareer.objectiveText(target: record.target, division: record.division))
                        Label(record.objectiveMet ? "Meta cumprida" : "Meta não cumprida",
                              systemImage: record.objectiveMet ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(record.objectiveMet ? .green : .red)
                        summaryRow("Copa Nacional", record.cupResult)
                        summaryRow("Premiação recebida", FootballFormat.money(record.prizeMoney))
                        if record.promoted {
                            Label("Acesso à Série A conquistado!", systemImage: "arrow.up.circle.fill")
                                .font(.subheadline.weight(.bold)).foregroundStyle(.green)
                        } else if record.relegated {
                            Label("Rebaixado para a Série B.", systemImage: "arrow.down.circle.fill")
                                .font(.subheadline.weight(.bold)).foregroundStyle(.red)
                        }
                        if record.reputationChange != 0 {
                            summaryRow("Reputação", (record.reputationChange > 0 ? "+" : "") + "\(record.reputationChange)")
                        }
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

// MARK: - Repercussão do jogo

/// Nota do time, torcida, bilheteria, camisas e reputação depois do apito final.
struct MatchImpactCard: View {
    let impact: MatchImpact
    let hypeTitle: String

    var body: some View {
        FactoryPanel(title: "Repercussão do jogo", systemImage: "megaphone.fill") {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(impact.verdict).font(.headline)
                    if !hypeTitle.isEmpty { Text(hypeTitle).font(.caption.weight(.semibold)).foregroundStyle(FootballTheme.accent) }
                }
                Spacer()
                VStack(spacing: 0) {
                    Text(String(format: "%.1f", impact.teamGrade)).font(.title.weight(.heavy).monospacedDigit())
                    Text("nota do time").font(.caption2).foregroundStyle(.secondary)
                }
            }
            ForEach(impact.highlights, id: \.self) { line in
                Label(line, systemImage: "sparkle").font(.subheadline)
            }
            Divider()
            impactRow("Embalo da torcida", "\(impact.hypeChange >= 0 ? "+" : "")\(impact.hypeChange) → \(impact.hypeAfter)/100", impact.hypeChange)
            impactRow("Humor da torcida", signed(impact.fanMoodChange), impact.fanMoodChange)
            if impact.newFans > 0 { impactRow("Novos torcedores", "+\(impact.newFans)", 1) }
            if impact.gateRevenue > 0 {
                impactRow("Bilheteria", "\(FootballFormat.money(impact.gateRevenue)) · \(impact.attendance) pagantes", 1)
                if impact.crowdBonusPercent > 0 { impactRow("Bônus do embalo no público", "+\(impact.crowdBonusPercent)%", 1) }
            }
            if impact.shirtsSold > 0 { impactRow("Camisas vendidas", "\(impact.shirtsSold) · \(FootballFormat.money(impact.shirtRevenue))", 1) }
            if impact.reputationChange != 0 { impactRow("Reputação", signed(impact.reputationChange), impact.reputationChange) }
            if impact.boardChange != 0 { impactRow("Confiança da diretoria", signed(impact.boardChange), impact.boardChange) }
        }
        .accessibilityIdentifier("match-impact")
    }

    private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }

    private func impactRow(_ title: String, _ value: String, _ trend: Int) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(trend > 0 ? Color.green : (trend < 0 ? Color.red : Color.primary))
        }
    }
}
