import SwiftUI

private extension View {
    /// Entrada em cascata: a linha sobe e aparece quando a cena chega ao índice dela.
    func reveal(_ shown: Bool) -> some View {
        opacity(shown ? 1 : 0).offset(y: shown ? 0 : 14)
    }
}

/// Ritual de virada de temporada: cenas em sequência, ritmo controlado e decisões que não podem ser puladas.
struct FootballOffseasonView: View {
    @Binding var career: FootballCareer
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var readyStep: OffseasonStep?
    @State private var revealedStep: OffseasonStep?
    @State private var revealed = 0
    @State private var closing = false
    @State private var impact = 0
    @State private var renewalTarget: RenewalTarget?
    @State private var showsFullReport = false

    private struct RenewalTarget: Identifiable { let id: Int }

    private var step: OffseasonStep { career.offseason?.step ?? .kickoff }
    private var visibleCount: Int { revealedStep == step ? revealed : 0 }
    private var ready: Bool { readyStep == step }

    var body: some View {
        ZStack {
            backdrop
            if step == .iconPack && !closing {
                FootballIconPackView(career: $career) { _ = career.advanceOffseason() }
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    progressBar.padding(.top, 14)
                    ScrollView {
                        scene
                            .id(step)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 24)
                    }
                    footer
                }
            }
            if closing { closingOverlay }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: step)
        .sensoryFeedback(.impact(weight: .medium), trigger: impact)
        .task(id: step) { await pace() }
        .onChange(of: career.offseason) { _, newValue in
            if newValue == nil { onFinish() }
        }
        .sheet(item: $renewalTarget) { target in
            FootballRenewalSheet(career: $career, playerID: target.id)
        }
        .sheet(isPresented: $showsFullReport) {
            if let record = career.history.last { FootballSeasonSummaryView(record: record, career: career) }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("offseason-flow")
    }

    // MARK: Ritmo

    /// Revela as linhas da cena uma a uma e só então libera o botão de continuar: nada passa de uma vez.
    private func pace() async {
        let current = step
        revealedStep = current
        revealed = 0
        if reduceMotion || FactoryCapture.screen != nil {
            revealed = 99
            readyStep = current
            return
        }
        for index in 1...6 {
            try? await Task.sleep(nanoseconds: 260_000_000)
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { revealed = index }
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        if Task.isCancelled { return }
        readyStep = current
    }

    private var requirementMet: Bool {
        guard let state = career.offseason else { return true }
        switch state.step {
        case .holiday: return state.holiday != nil
        case .sponsor: return career.sponsorOffers.isEmpty
        case .preseason: return state.camp != nil
        default: return true
        }
    }

    private var canContinue: Bool { ready && requirementMet && !closing }

    private var blocker: String? {
        guard ready, !requirementMet else { return nil }
        switch step {
        case .holiday: return "Escolha como o elenco vai passar as férias."
        case .sponsor: return "Escolha o patrocinador da temporada."
        case .preseason: return "Escolha a preparação da equipe."
        default: return nil
        }
    }

    private var continueTitle: String {
        switch step {
        case .endOfSeason: return career.expiringContractPlayers.isEmpty ? "Virar a temporada" : "Ver contratos que vencem"
        case .contracts: return "Virar a temporada"
        case .review: return career.iconState.pendingPack != nil ? "Abrir o pacote" : "Seguir para as férias"
        case .iconPack: return "Seguir para as férias"
        case .holiday: return career.sponsorOffers.isEmpty ? "Seguir para a pré-temporada" : "Seguir para o patrocínio"
        case .sponsor: return "Seguir para a pré-temporada"
        case .preseason: return "Ir para a estreia"
        case .kickoff: return "Começar a temporada"
        }
    }

    private func advance() {
        guard canContinue else { return }
        impact += 1
        let closesSeason = step == .contracts || (step == .endOfSeason && career.expiringContractPlayers.isEmpty)
        if closesSeason {
            closing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                _ = career.advanceOffseason()
                closing = false
            }
        } else {
            _ = career.advanceOffseason()
        }
    }

    // MARK: Moldura

    private var phaseColors: [Color] {
        switch step.phase {
        case 0: return [Color(red: 0.05, green: 0.08, blue: 0.16), Color.black]
        case 1: return [Color(red: 0.05, green: 0.20, blue: 0.14), Color.black]
        case 2: return [Color(red: 0.36, green: 0.16, blue: 0.20), Color(red: 0.08, green: 0.05, blue: 0.12)]
        case 3: return [Color(red: 0.05, green: 0.22, blue: 0.26), Color.black]
        case 4: return [Color(red: 0.08, green: 0.26, blue: 0.16), Color.black]
        default: return [Color(red: 0.10, green: 0.24, blue: 0.12), Color(red: 0.02, green: 0.05, blue: 0.03)]
        }
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: phaseColors, startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [FootballTheme.gold.opacity(0.16), .clear], center: .top, startRadius: 10, endRadius: 360)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: step.phase)
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<OffseasonStep.phaseTitles.count, id: \.self) { index in
                    Capsule()
                        .fill(index <= step.phase ? FootballTheme.gold : Color.white.opacity(0.2))
                        .frame(height: 4)
                }
            }
            Text("\(OffseasonStep.phaseTitles[step.phase].uppercased()) · \(step.title.uppercased())")
                .font(.caption2.weight(.heavy)).tracking(1.4)
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Etapa \(step.phase + 1) de \(OffseasonStep.phaseTitles.count): \(step.title)")
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let blocker {
                Text(blocker).font(.footnote).foregroundStyle(.white.opacity(0.7))
            }
            Button { advance() } label: {
                Label(continueTitle, systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.4)
            .accessibilityIdentifier("offseason-continue")
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var closingOverlay: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().tint(FootballTheme.gold).scaleEffect(1.4)
                Text("Fechando a temporada \(career.season)…")
                    .font(.headline).foregroundStyle(.white)
                Text("Premiações, contratos, aposentadorias e a nova base.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.65))
            }
        }
        .transition(.opacity)
    }

    // MARK: Peças de cena

    private func hero(symbol: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 54))
                .foregroundStyle(FootballTheme.gold)
                .symbolEffect(.bounce, value: step)
                .shadow(color: FootballTheme.gold.opacity(0.5), radius: 18)
            Text(title)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .reveal(visibleCount >= 0 && revealedStep == step)
    }

    private func infoRow(_ index: Int, symbol: String, label: String, value: String, tint: Color = FootballTheme.gold) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint).frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                Text(value).font(.headline).foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .reveal(visibleCount >= index)
        .accessibilityElement(children: .combine)
    }

    private func optionCard(index: Int, symbol: String, title: String, summary: String, chips: [String],
                            selected: Bool, locked: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button {
            impact += 1
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { action() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: symbol).font(.title2).frame(width: 40).foregroundStyle(FootballTheme.gold)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.headline)
                        Text(summary).font(.caption).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    if selected { Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(FootballTheme.gold) }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(chips, id: \.self) { chip in
                        Text(chip)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? FootballTheme.gold.opacity(0.18) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? FootballTheme.gold : Color.white.opacity(0.1), lineWidth: selected ? 2 : 1)
            }
            .scaleEffect(selected ? 1.02 : 1)
            .opacity(locked ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .reveal(visibleCount >= index)
        .accessibilityIdentifier(id)
    }

    // MARK: Cenas

    @ViewBuilder private var scene: some View {
        switch step {
        case .endOfSeason: endOfSeasonScene
        case .contracts: contractsScene
        case .review: reviewScene
        case .iconPack: Color.clear.frame(height: 1)
        case .holiday: holidayScene
        case .sponsor: sponsorScene
        case .preseason: preseasonScene
        case .kickoff: kickoffScene
        }
    }

    private var endOfSeasonScene: some View {
        let position = career.userPosition ?? 0
        let division = career.userDivision ?? .serieA
        let met = position > 0 && position <= career.boardTarget
        let champion = career.championID.flatMap { FootballSeason.team($0) }
        let isChampion = champion?.id == career.selectedClubID
        let promoted = division == .serieB && position > 0 && position <= FootballSeason.relegationSpots
        let relegated = division == .serieA && position > FootballSeason.teamsPerDivision - FootballSeason.relegationSpots
        let headline = isChampion ? "Campeões!" : (promoted ? "Acesso conquistado!" : (relegated ? "Rebaixados" : (met ? "Meta cumprida" : "Temporada encerrada")))
        return VStack(spacing: 22) {
            hero(symbol: isChampion ? "trophy.fill" : "flag.checkered", title: headline, subtitle: "Fim da temporada \(career.season)")
            VStack(spacing: 12) {
                infoRow(1, symbol: "list.number", label: "Posição final", value: "\(position)º · \(division.name)")
                infoRow(2, symbol: "target", label: "Meta da diretoria", value: "\(career.objectiveText) · \(met ? "cumprida" : "não cumprida")",
                        tint: met ? .green : .orange)
                if let champion {
                    infoRow(3, symbol: "crown.fill", label: "Campeão da Série A", value: champion.name)
                }
                if let scorer = career.topScorers(limit: 1, division: division).first {
                    infoRow(4, symbol: "soccerball", label: "Artilheiro da divisão", value: "\(scorer.name) · \(scorer.goals) gols")
                }
            }
            Text(met ? "A diretoria reconhece o trabalho. Antes de virar a página, resolva os contratos."
                     : "A diretoria vai cobrar. Antes de virar a página, resolva os contratos.")
                .font(.footnote).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                .reveal(visibleCount >= 5)
        }
    }

    private var contractsScene: some View {
        let expiring = career.expiringContractPlayers
        return VStack(spacing: 18) {
            hero(symbol: "doc.text.fill", title: "Contratos que vencem",
                 subtitle: expiring.isEmpty ? "Ninguém termina contrato agora." : "Quem não renovar vira agente livre quando a temporada virar.")
            ForEach(Array(expiring.prefix(8).enumerated()), id: \.element.id) { offset, player in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(player.name).font(.headline).foregroundStyle(.white)
                        Text("\(player.position.rawValue) · \(player.age) anos · geral \(player.overall)")
                            .font(.caption).foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                    Button("Renovar") { renewalTarget = RenewalTarget(id: player.id) }
                        .buttonStyle(.borderedProminent)
                        .tint(FootballTheme.gold)
                        .foregroundStyle(.black)
                        .font(.caption.weight(.bold))
                        .accessibilityIdentifier("offseason-renew-\(player.id)")
                }
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .reveal(visibleCount >= min(offset + 1, 6))
            }
            if expiring.count > 8 {
                Text("e mais \(expiring.count - 8) atletas com contrato no fim")
                    .font(.footnote).foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var reviewScene: some View {
        let record = career.history.last
        return VStack(spacing: 22) {
            hero(symbol: "star.circle.fill", title: "Balanço da temporada \(record?.season ?? career.season - 1)",
                 subtitle: record.map { $0.objectiveMet ? "A diretoria ficou satisfeita." : "A diretoria esperava mais." } ?? "")
            if let record {
                VStack(spacing: 12) {
                    if let best = record.awards?.bestPlayer {
                        infoRow(1, symbol: "medal.fill", label: "Craque do campeonato", value: best.name)
                    }
                    infoRow(2, symbol: "soccerball", label: "Artilheiro", value: "\(record.topScorerName) · \(record.topScorerGoals) gols")
                    infoRow(3, symbol: "banknote.fill", label: "Premiações", value: FootballFormat.money(record.prizeMoney))
                    infoRow(4, symbol: "figure.walk.departure", label: "Aposentadorias no clube", value: "\(record.retiredPlayers)")
                    infoRow(5, symbol: "graduationcap.fill", label: "Promovidos da base", value: "\(record.youthPromoted)")
                }
                Button { showsFullReport = true } label: {
                    Label("Ver relatório completo", systemImage: "doc.richtext")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .reveal(visibleCount >= 6)
                .accessibilityIdentifier("offseason-full-report")
            }
        }
    }

    private var holidayScene: some View {
        VStack(spacing: 18) {
            hero(symbol: "sun.max.fill", title: "Férias", subtitle: "O elenco pede uma pausa. Quanto tempo você dá?")
            ForEach(Array(HolidayPlan.allCases.enumerated()), id: \.element.id) { offset, plan in
                let chosen = career.offseason?.holiday
                optionCard(index: offset + 1, symbol: plan.symbol, title: plan.title, summary: plan.summary, chips: plan.effects,
                           selected: chosen == plan, locked: chosen != nil && chosen != plan, id: "offseason-holiday-\(plan.rawValue)") {
                    _ = career.chooseHoliday(plan)
                }
            }
            if let plan = career.offseason?.holiday {
                Text(plan.report).font(.footnote).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            }
        }
    }

    private var sponsorScene: some View {
        VStack(spacing: 18) {
            hero(symbol: "building.2.fill", title: "Patrocinador", subtitle: "O contrato anterior acabou. Quem estampa a camisa do clube?")
            if career.sponsorOffers.isEmpty, let deal = career.sponsorDeal {
                infoRow(1, symbol: "checkmark.seal.fill", label: "Patrocínio fechado", value: "\(deal.sponsor) · até a temporada \(deal.endSeason)")
            }
            ForEach(Array(career.sponsorOffers.enumerated()), id: \.element.id) { offset, offer in
                optionCard(index: offset + 1, symbol: sponsorSymbol(offer.profile), title: "\(offer.sponsor) · \(offer.profile)",
                           summary: "\(offer.seasons) temporada\(offer.seasons > 1 ? "s" : "")",
                           chips: ["Fixo \(FootballFormat.money(offer.fixedPerSeason))", "Por vitória \(FootballFormat.money(offer.bonusPerWin))",
                                   "Título \(FootballFormat.money(offer.titleBonus))"],
                           selected: false, locked: false, id: "offseason-sponsor-\(offer.id)") {
                    _ = career.acceptSponsorOffer(offer.id)
                }
            }
        }
    }

    private func sponsorSymbol(_ profile: String) -> String {
        switch profile {
        case "Equilibrado": return "scalemass.fill"
        case "Arriscado": return "flame.fill"
        default: return "shield.fill"
        }
    }

    private var preseasonScene: some View {
        VStack(spacing: 18) {
            hero(symbol: "figure.soccer", title: "Pré-temporada", subtitle: "Como a equipe se prepara para a estreia?")
            ForEach(Array(PreseasonCamp.allCases.enumerated()), id: \.element.id) { offset, camp in
                let chosen = career.offseason?.camp
                let base = career.selectedClub?.startingBudget ?? 0
                let cost = camp.cost(baseBudget: base)
                let revenue = camp.revenue(baseBudget: base)
                optionCard(index: offset + 1, symbol: camp.symbol, title: camp.title,
                           summary: career.canAffordCamp(camp) ? camp.summary : "\(camp.summary) Caixa insuficiente.",
                           chips: campChips(camp, cost: cost, revenue: revenue),
                           selected: chosen == camp, locked: (chosen != nil && chosen != camp) || !career.canAffordCamp(camp),
                           id: "offseason-camp-\(camp.rawValue)") {
                    _ = career.chooseCamp(camp)
                }
            }
            if let report = career.offseason?.campReport {
                Text(report).font(.footnote).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            }
        }
    }

    private func campChips(_ camp: PreseasonCamp, cost: Int, revenue: Int) -> [String] {
        var chips = [cost == 0 ? "Sem custo" : "Custo \(FootballFormat.money(cost))"]
        if revenue > 0 { chips.append("Renda \(FootballFormat.money(revenue))") }
        chips.append("Moral +\(camp.moraleDelta)")
        chips.append(camp.conditionDelta >= 0 ? "Físico +\(camp.conditionDelta)" : "Físico \(camp.conditionDelta)")
        if camp.fanBaseGrowth > 0 { chips.append("Torcida +\(Int((camp.fanBaseGrowth * 100).rounded()))%") }
        if camp.injuryChance > 0 { chips.append("Risco de lesão \(Int((camp.injuryChance * 100).rounded()))%") }
        return chips
    }

    private var kickoffScene: some View {
        let fixture = career.nextUserFixture
        let opponentID = fixture.map { $0.home == career.selectedClubID ? $0.away : $0.home }
        let opponent = opponentID.flatMap { FootballSeason.team($0) }
        let atHome = fixture.map { $0.home == career.selectedClubID } ?? true
        return VStack(spacing: 22) {
            hero(symbol: "sportscourt.fill", title: "Bola rolando", subtitle: "A temporada \(career.season) começa agora.")
            VStack(spacing: 12) {
                infoRow(1, symbol: "target", label: "Meta da diretoria", value: career.objectiveText)
                infoRow(2, symbol: "banknote.fill", label: "Caixa do clube", value: FootballFormat.money(career.transferBudget))
                if let deal = career.sponsorDeal {
                    infoRow(3, symbol: "building.2.fill", label: "Patrocinador", value: deal.sponsor)
                }
                if let opponent {
                    infoRow(4, symbol: "flag.fill", label: "Estreia", value: "\(atHome ? "Em casa" : "Fora") contra \(opponent.name)")
                }
            }
        }
    }
}

/// Hospeda uma etapa do ritual com uma carreira de demonstração, só para as capturas de tela de revisão.
struct FootballOffseasonCaptureHost: View {
    @State private var career: FootballCareer

    init(step: OffseasonStep) {
        _career = State(initialValue: FootballCareer.offseasonPreview(at: step))
    }

    var body: some View {
        FootballOffseasonView(career: $career) {}
    }
}
