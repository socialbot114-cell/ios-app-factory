import SwiftUI

// MARK: - Passagem de dias

/// O que mudou no calendário depois de avançar: de qual dia de jogo para qual.
/// A tela de bloqueio usa isto para mostrar os dias passando antes de entregar as novidades.
struct PhoneDayTransition: Equatable {
    let fromSeason: Int
    let fromMatchDay: Int
    let toSeason: Int
    let toMatchDay: Int

    /// Fim do dia anterior: algumas horas depois do apito final.
    var fromMoment: Date {
        FootballCalendarClock.kickoff(season: fromSeason, matchDay: fromMatchDay).addingTimeInterval(2 * 3600)
    }

    var toMoment: Date { FootballCalendarClock.moment(season: toSeason, matchDay: toMatchDay) }

    var fromDay: Date { FootballCalendarClock.day(season: fromSeason, matchDay: fromMatchDay) }
    var toDay: Date { FootballCalendarClock.day(season: toSeason, matchDay: toMatchDay) }

    /// Dias de calendário entre os dois momentos (mínimo 1).
    var days: Int { max(1, FootballCalendarClock.daysBetween(fromDay, toDay)) }

    /// Dia exibido no passo `step` de `steps`, espalhando os dias de forma uniforme.
    func day(step: Int, of steps: Int) -> Date {
        let offset = Int((Double(days) * Double(step) / Double(max(1, steps))).rounded())
        return FootballCalendarClock.calendar.date(byAdding: .day, value: offset, to: fromDay) ?? toDay
    }
}

// MARK: - Tela de bloqueio

/// Aparece ao abrir o FutOS e sempre que o calendário avança: mostra a data e a hora mudando
/// e depois as novidades do novo dia em widgets, antes de o treinador desbloquear.
struct PhoneLockScreen: View {
    let career: FootballCareer
    var transition: PhoneDayTransition? = nil
    let onUnlock: () -> Void
    var onOpen: (PhoneApp) -> Void = { _ in }
    var onOpenMessage: ((Int) -> Void)? = nil
    var onOpenEvent: ((Int) -> Void)? = nil
    /// Abre o app (e a mensagem/evento) a que uma sugestão aponta.
    var onSuggestion: (FootballSuggestion) -> Void = { _ in }

    @State private var shownDay: Date
    @State private var clockText: String
    @State private var tick = 0
    @State private var elapsedDays = 0
    @State private var settled: Bool
    @State private var digestExpanded = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    init(career: FootballCareer, transition: PhoneDayTransition? = nil, onUnlock: @escaping () -> Void,
         onOpen: @escaping (PhoneApp) -> Void = { _ in }, onOpenMessage: ((Int) -> Void)? = nil,
         onOpenEvent: ((Int) -> Void)? = nil, onSuggestion: @escaping (FootballSuggestion) -> Void = { _ in }) {
        self.career = career
        self.onSuggestion = onSuggestion
        self.transition = transition
        self.onUnlock = onUnlock
        self.onOpen = onOpen
        self.onOpenMessage = onOpenMessage
        self.onOpenEvent = onOpenEvent
        _shownDay = State(initialValue: transition?.fromDay ?? career.gameDay)
        _clockText = State(initialValue: FootballCalendarClock.clock(transition?.fromMoment ?? career.gameMoment))
        _settled = State(initialValue: transition == nil)
    }

    private var reduceMotion: Bool { systemReduceMotion || career.world.phone.preferences.reduceMotion }

    /// Dias a mostrar como fichas na faixa do calendário (só quando cabem na tela).
    private var chipDays: [Date] {
        guard let transition, transition.days <= 8 else { return [] }
        return (0...transition.days).map { transition.day(step: $0, of: transition.days) }
    }

    var body: some View {
        ZStack {
            PhoneWallpaper(team: career.selectedClub, moment: career.phoneMoment)
            VStack(spacing: 16) {
                PhoneStatusBar(career: career).padding(.top, 8)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        clockBlock
                        if transition != nil { dayStrip }
                        if settled { widgets.transition(.move(edge: .bottom).combined(with: .opacity)) }
                    }
                    .padding(.top, 12)
                }
                unlockButton
            }
            .padding(.horizontal, 16)
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { value in if value.translation.height < -60 { onUnlock() } })
        .sensoryFeedback(.impact(flexibility: .soft), trigger: tick)
        .task(id: transition) { await playTransition() }
    }

    // MARK: Relógio e data

    private var clockBlock: some View {
        VStack(spacing: 4) {
            Text(clockText)
                .font(.system(size: 76, weight: .thin, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .accessibilityIdentifier("lock-clock")
            Text(FootballCalendarClock.longDate(shownDay))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .contentTransition(.numericText())
                .accessibilityIdentifier("lock-date")
            Text("Temporada \(career.season) · \(career.currentSlot?.title ?? "Fim de temporada")")
                .font(.footnote.weight(.medium)).foregroundStyle(.white.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(clockText), \(FootballCalendarClock.longDate(shownDay))")
    }

    /// Faixa com os dias que passaram: cada ficha acende conforme a data avança.
    @ViewBuilder
    private var dayStrip: some View {
        if let transition {
            VStack(spacing: 8) {
                if !chipDays.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(chipDays.enumerated()), id: \.offset) { index, day in
                            let isPast = index <= elapsedDays
                            VStack(spacing: 2) {
                                Text(FootballCalendarClock.weekdayShort(day)).font(.caption2.weight(.semibold))
                                Text("\(FootballCalendarClock.calendar.component(.day, from: day))")
                                    .font(.subheadline.weight(.heavy).monospacedDigit())
                            }
                            .foregroundStyle(isPast ? Color.black : Color.white.opacity(0.7))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(isPast ? Color.white.opacity(0.92) : Color.white.opacity(0.14),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .scaleEffect(index == elapsedDays && !settled ? 1.08 : 1)
                        }
                    }
                }
                Label(daysCaption(transition), systemImage: settled ? "sunrise.fill" : "moon.stars.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityIdentifier("lock-days-caption")
            }
            .padding(12)
            .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private func daysCaption(_ transition: PhoneDayTransition) -> String {
        let days = transition.days
        let unit = days == 1 ? "dia" : "dias"
        return settled ? "Amanheceu · \(days) \(unit) depois" : "Passando o calendário · \(days) \(unit)"
    }

    private func playTransition() async {
        guard let transition else { return }
        if reduceMotion || FactoryCapture.isUITesting || FactoryCapture.screen != nil {
            shownDay = transition.toDay
            clockText = FootballCalendarClock.clock(transition.toMoment)
            elapsedDays = transition.days
            settled = true
            return
        }
        let steps = min(transition.days, 10)
        let perStep = UInt64(min(0.45, 2.4 / Double(max(1, steps))) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: 450_000_000)
        for step in 1...steps {
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                shownDay = transition.day(step: step, of: steps)
                clockText = step == steps ? FootballCalendarClock.clock(transition.toMoment) : "00:00"
                elapsedDays = Int((Double(transition.days) * Double(step) / Double(steps)).rounded())
                tick += 1
            }
            try? await Task.sleep(nanoseconds: perStep)
        }
        try? await Task.sleep(nanoseconds: 250_000_000)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { settled = true }
    }

    // MARK: Widgets com as novidades

    private var widgets: some View {
        VStack(spacing: 10) {
            if let fixture = resultFixture { resultWidget(fixture) }
            nightDigest
            nextMatchWidget
            countersWidget
            tipCard
            if career.overnightItems().isEmpty { notificationsList }
        }
    }

    // MARK: Resumo da noite e guia

    /// Tudo que ficou esperando durante a noite: o que precisa ser feito, respondido ou decidido.
    @ViewBuilder
    private var nightDigest: some View {
        let items = career.overnightItems()
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(transition == nil ? "Pendências · \(items.count)" : "Durante a noite · \(items.count) para você", systemImage: "moon.stars.fill")
                    .font(.caption.weight(.heavy)).tracking(0.5).foregroundStyle(.white.opacity(0.8))
                if let first = items.first {
                    Button { onUnlock(); onSuggestion(first) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles").font(.title3)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("O QUE FAZER AGORA").font(.caption2.weight(.heavy)).tracking(1)
                                Text(first.title).font(.subheadline.weight(.bold)).lineLimit(1)
                            }
                            Spacer()
                            Text(first.actionTitle).font(.caption.weight(.bold))
                                .padding(.horizontal, 10).padding(.vertical, 5).background(.white.opacity(0.25), in: Capsule())
                        }
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(FootballTheme.accent.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("lock-guide")
                }
                let rest = Array(items.dropFirst())
                if !rest.isEmpty {
                    Button { withAnimation(.easeInOut(duration: 0.25)) { digestExpanded.toggle() } } label: {
                        HStack {
                            Text(digestExpanded ? "Mostrar menos" : "Mais \(rest.count) pendência\(rest.count == 1 ? "" : "s")")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Image(systemName: digestExpanded ? "chevron.up" : "chevron.down").font(.caption.bold())
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("lock-digest-toggle")
                }
                if digestExpanded {
                    ForEach(rest) { item in
                        Button { onUnlock(); onSuggestion(item) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.symbol).frame(width: 26).foregroundStyle(item.priority >= 3 ? Color.red : Color.white.opacity(0.9))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Text(item.detail).font(.caption).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.white.opacity(0.5))
                            }
                            .foregroundStyle(.white)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("lock-digest-\(item.id)")
                    }
                }
                }
            .padding(14)
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityIdentifier("lock-night-digest")
        }
    }

    @ViewBuilder
    private var tipCard: some View {
        if career.showsTipToday {
            let tip = career.dailyTip()
            Button {
                onUnlock()
                if let app = PhoneApp(rawValue: tip.appID) { onOpen(app) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Dica · \(tip.title)").font(.caption.weight(.heavy)).foregroundStyle(.white)
                        Text(tip.text).font(.caption).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("lock-tip")
        }
    }

    /// Resultado do jogo que acabou de acontecer (só quando o avanço veio de uma partida do clube).
    private var resultFixture: LeagueFixture? {
        guard let transition, transition.fromSeason == career.season, let fixture = career.latestUserFixture,
              fixture.matchDay == transition.fromMatchDay, fixture.isPlayed else { return nil }
        return fixture
    }

    private func resultWidget(_ fixture: LeagueFixture) -> some View {
        let id = career.selectedClubID
        let mine = fixture.home == id ? fixture.homeGoals : fixture.awayGoals
        let theirs = fixture.home == id ? fixture.awayGoals : fixture.homeGoals
        let verdict: (String, Color) = {
            guard let mine, let theirs else { return ("Jogo encerrado", .white) }
            if mine > theirs { return ("VITÓRIA", .green) }
            if mine < theirs { return ("DERROTA", .red) }
            return ("EMPATE", .yellow)
        }()
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ÚLTIMO JOGO · \(fixture.title.uppercased())").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(verdict.0).font(.caption2.weight(.heavy)).foregroundStyle(verdict.1)
            }
            MatchupHeader(home: FootballSeason.team(fixture.home), away: FootballSeason.team(fixture.away),
                          homeScore: fixture.homeGoals, awayScore: fixture.awayGoals, crestSize: 30)
                .environment(\.colorScheme, .dark)
        }
        .padding(14)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityIdentifier("lock-widget-result")
    }

    private var nextMatchWidget: some View {
        Button { onUnlock(); onOpen(.manager) } label: {
            VStack(alignment: .leading, spacing: 8) {
                if let fixture = career.nextUserFixture {
                    HStack {
                        Text("PRÓXIMO JOGO · \(fixture.title.uppercased())").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        Text(kickoffText).font(.caption2.weight(.bold)).foregroundStyle(.white.opacity(0.85))
                    }
                    MatchupHeader(home: FootballSeason.team(fixture.home), away: FootballSeason.team(fixture.away),
                                  homeScore: nil, awayScore: nil, crestSize: 30)
                        .environment(\.colorScheme, .dark)
                } else if career.isSeasonComplete {
                    Text("TEMPORADA ENCERRADA").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.white.opacity(0.75))
                    Text("Abra o Gestor para virar a temporada.").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                } else {
                    Text("DIA SEM JOGO DO SEU CLUBE").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.white.opacity(0.75))
                    Text("Use o dia para cuidar do elenco, dos negócios e da vida fora de campo.").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("lock-widget-next")
    }

    private var kickoffText: String {
        let kickoff = FootballCalendarClock.kickoff(season: career.season, matchDay: career.matchDayIndex)
        return "\(FootballCalendarClock.shortDate(kickoff)) · \(FootballCalendarClock.clock(kickoff))"
    }

    private static let counterApps: [PhoneApp] = [.messages, .market, .alerts, .quests]

    private var countersWidget: some View {
        let active = Self.counterApps.filter { career.badge(for: $0) > 0 }
        return HStack(spacing: 8) {
            if active.isEmpty {
                Label("Nada novo na caixa de entrada. Bom dia para treinar.", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(active) { app in
                Button { onUnlock(); onOpen(app) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: app.symbol).font(.subheadline).foregroundStyle(.white.opacity(0.85))
                        Text("\(career.badge(for: app))").font(.title3.weight(.heavy).monospacedDigit()).foregroundStyle(.white)
                        Text(counterLabel(app)).font(.caption2).foregroundStyle(.white.opacity(0.75)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(app.tint.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(app.title), \(career.badge(for: app)) \(counterLabel(app))")
                .accessibilityIdentifier("lock-counter-\(app.rawValue)")
            }
        }
        .padding(active.isEmpty ? 14 : 0)
        .background(active.isEmpty ? Color.black.opacity(0.28) : Color.clear, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func counterLabel(_ app: PhoneApp) -> String {
        switch app {
        case .messages: return "mensagens"
        case .market: return "propostas"
        case .alerts: return "alertas"
        case .quests: return "metas"
        default: return app.title.lowercased()
        }
    }

    private var notificationsList: some View {
        VStack(spacing: 8) {
            ForEach(career.phoneNotifications.prefix(3)) { item in
                Button {
                    onUnlock()
                    if let id = item.messageID, let onOpenMessage { onOpenMessage(id) }
                    else if let id = item.eventID, let onOpenEvent { onOpenEvent(id) }
                    else { onOpen(item.app) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.symbol).frame(width: 28).foregroundStyle(item.app.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("lock-notification-\(item.id)")
            }
        }
    }

    private var unlockButton: some View {
        Button(action: onUnlock) {
            VStack(spacing: 6) {
                Image(systemName: "chevron.compact.up").font(.title)
                Text(settled ? "Toque para abrir" : "Toque para pular").font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("phone-unlock")
        .padding(.bottom, 12)
    }
}
