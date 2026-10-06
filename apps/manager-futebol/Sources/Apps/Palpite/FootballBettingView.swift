import SwiftUI

// MARK: - Palpite+ (apostas com fichas fictícias)

struct FootballBettingView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    /// Captura: briefing e justificativa abertos, sem os painéis de cima.
    var captureFocus = false

    @State private var legs: [BetLeg] = []
    @State private var stake = 50
    @State private var expanded: Int?
    @State private var note: String?
    @State private var outrightMarket: OutrightMarket = .leagueWinner
    @State private var outrightStake = 100
    @State private var didLoadDraft = false
    @State private var detailBetID: Int?

    private var betting: BettingState { career.world.betting }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !captureFocus { walletPanel }
            if let note {
                Label(note, systemImage: "ticket.fill").font(.subheadline.weight(.medium)).foregroundStyle(FootballTheme.accent)
            }
            if career.isSelfExcluded {
                FactoryPanel(title: "Pausa ativa", systemImage: "pause.circle.fill") {
                    Text("Você pediu uma pausa nas apostas. Ela termina no dia \(betting.selfExcludedUntilWorldDay + 1) da carreira.")
                        .font(.subheadline)
                }
            }
            fixturesPanel
            if !legs.isEmpty { slipPanel }
            if !captureFocus { outrightsPanel }
            ticketsPanel
            if !captureFocus {
                tipstersPanel
                responsiblePanel
            }
        }
        .factoryPage()
        .navigationTitle("Palpite+")
        .onAppear {
            guard !didLoadDraft else { return }
            didLoadDraft = true
            if captureFocus {
                expanded = career.bettingFixtures.first?.id
                detailBetID = career.world.betting.bets.first?.id
            }
            let restored = career.restoredBettingDraft()
            if let draft = restored.draft { legs = draft.legs; stake = draft.stake }
            if restored.dropped > 0 { note = "\(restored.dropped) seleção(ões) do rascunho saíram: o mercado fechou." }
        }
        .onChange(of: legs) { _, _ in saveDraft() }
        .onChange(of: stake) { _, _ in saveDraft() }
    }

    private func saveDraft() {
        guard didLoadDraft else { return }
        career.saveBettingDraft(legs: legs, stake: stake)
    }

    // MARK: Carteira

    private var walletPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                FactoryMetric(label: "Fichas", value: "\(betting.fichas)", symbol: "circle.hexagongrid.fill", tint: .purple)
                FactoryMetric(label: "Resultado da temporada", value: FootballFormat.signed(betting.seasonProfit), symbol: "chart.line.uptrend.xyaxis",
                              tint: betting.seasonProfit >= 0 ? .green : .red)
            }
            HStack(spacing: 10) {
                Button {
                    if let bonus = career.claimDailyBonus() { note = "+\(bonus) fichas de bônus." } else { onAlert("O bônus volta a cada 4 dias de jogo.") }
                } label: {
                    Label("Bônus de fichas", systemImage: "gift.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!career.dailyBonusAvailable || career.isSelfExcluded)
                .accessibilityIdentifier("bet-bonus")
                if betting.fichas < FootballCareer.betMinimum {
                    Button {
                        if let extra = career.claimEmergencyFichas() { note = "+\(extra) fichas de emergência." } else { onAlert("As fichas de emergência já foram usadas nesta temporada.") }
                    } label: {
                        Label("Fichas de emergência", systemImage: "lifepreserver.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.subheadline.weight(.semibold))
            Text(FootballCareer.bettingRoleText)
                .font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("bet-role")
        }
    }

    // MARK: Jogos

    private var fixturesPanel: some View {
        FactoryPanel(title: "Jogos da rodada", systemImage: "sportscourt.fill") {
            let fixtures = career.bettingFixtures
            if fixtures.isEmpty {
                Text("Sem jogos abertos para palpites agora. Avance o calendário.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(fixtures) { fixture in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(FootballSeason.teamName(fixture.home)) × \(FootballSeason.teamName(fixture.away))")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text(fixture.competition.isCup ? "Copa" : (fixture.competition.division?.name ?? "")).font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(career.bettingClosingText(for: fixture)).font(.caption2).foregroundStyle(.secondary)
                        .accessibilityIdentifier("bet-closing-\(fixture.id)")
                    let options = career.options(for: fixture)
                    HStack(spacing: 8) {
                        ForEach(options.filter { [.homeWin, .draw, .awayWin].contains($0.leg.market) }) { option in oddsButton(option) }
                    }
                    Button { expanded = expanded == fixture.id ? nil : fixture.id } label: {
                        Label(expanded == fixture.id ? "Menos mercados" : "Mais mercados", systemImage: expanded == fixture.id ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                    }
                    if expanded == fixture.id {
                        briefingView(career.fixtureBriefing(fixture))
                        ForEach(options.filter { ![.homeWin, .draw, .awayWin].contains($0.leg.market) }) { option in
                            HStack {
                                Text(option.leg.description).font(.caption)
                                Spacer()
                                oddsButton(option, compact: true)
                            }
                        }
                    }
                }
                if fixture.id != fixtures.last?.id { Divider() }
            }
        }
    }

    private func briefingView(_ briefing: FixtureBriefing) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach([briefing.home, briefing.away], id: \.teamID) { side in
                HStack(spacing: 6) {
                    Text(FootballSeason.team(side.teamID)?.shortName ?? "").font(.caption.weight(.bold))
                    if side.form.isEmpty { Text("sem jogos na liga").font(.caption2).foregroundStyle(.secondary) } else { FormBadges(results: side.form) }
                }
                if !side.absences.isEmpty {
                    Text("Desfalques: " + side.absences.joined(separator: ", ")).font(.caption2).foregroundStyle(.orange)
                }
            }
            Text(briefing.headToHead.meetings == 0 ? "Sem confronto direto na temporada."
                 : "Confronto direto: \(briefing.headToHead.wins)V \(briefing.headToHead.draws)E \(briefing.headToHead.losses)D (do mandante)")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("bet-briefing")
    }

    private func oddsButton(_ option: BetOption, compact: Bool = false) -> some View {
        let selected = legs.contains { $0.id == option.leg.id }
        let blocked = career.isIntegrityViolation(market: option.leg.market, a: option.leg.a, b: option.leg.b,
                                                  fixture: career.fixtures.first { $0.id == option.leg.fixtureID } ?? career.fixtures[0])
        return Button {
            if blocked { onAlert("Regra de integridade: você não pode apostar contra o seu próprio clube."); return }
            toggle(option.leg)
        } label: {
            VStack(spacing: 2) {
                if !compact { Text(shortName(option.leg)).font(.caption2).foregroundStyle(selected ? .white : .secondary) }
                Text(String(format: "%.2f", option.leg.odds)).font(.subheadline.weight(.heavy).monospacedDigit())
                    .foregroundStyle(selected ? .white : .primary)
            }
            .frame(maxWidth: compact ? 70 : .infinity, minHeight: 40)
            .background(selected ? Color.purple : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(blocked ? 0.35 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.leg.description), cotação \(String(format: "%.2f", option.leg.odds))")
        .accessibilityIdentifier("odd-\(option.leg.id)")
    }

    private func shortName(_ leg: BetLeg) -> String {
        switch leg.market {
        case .homeWin: return "Casa"
        case .draw: return "Empate"
        case .awayWin: return "Fora"
        default: return leg.market.title
        }
    }

    private func toggle(_ leg: BetLeg) {
        if let index = legs.firstIndex(where: { $0.id == leg.id }) {
            legs.remove(at: index)
            return
        }
        legs.removeAll { $0.fixtureID == leg.fixtureID }
        if legs.count >= FootballCareer.betMaxLegs {
            onAlert("No máximo \(FootballCareer.betMaxLegs) seleções por bilhete.")
            return
        }
        legs.append(leg)
    }

    // MARK: Bilhete

    private var slipPanel: some View {
        let totalOdds = legs.reduce(1.0) { $0 * $1.odds }
        let clamped = min(max(stake, FootballCareer.betMinimum), max(FootballCareer.betMinimum, career.maxStake))
        return FactoryPanel(title: legs.count > 1 ? "Múltipla (\(legs.count))" : "Bilhete", systemImage: "ticket.fill") {
            ForEach(legs) { leg in
                HStack {
                    Text(leg.description).font(.caption)
                    Spacer()
                    Text(String(format: "%.2f", leg.odds)).font(.caption.weight(.bold).monospacedDigit())
                    Button { legs.removeAll { $0.id == leg.id } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                }
            }
            Divider()
            Stepper("Aposta: \(clamped) fichas", value: $stake, in: FootballCareer.betMinimum...max(FootballCareer.betMinimum, career.maxStake), step: 10)
                .font(.subheadline)
            HStack {
                Text("Cotação total").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f", totalOdds)).font(.subheadline.weight(.bold).monospacedDigit())
            }
            HStack {
                Text("Retorno possível").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(Double(clamped) * totalOdds)) fichas").font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(.green)
            }
            Button {
                if let reason = career.betBlockReason(stake: clamped, legs: legs) {
                    onAlert(reason)
                } else if career.placeBet(stake: clamped, legs: legs) != nil {
                    note = "Bilhete feito! Resultado depois dos jogos."
                    legs = []
                }
            } label: {
                Label("Confirmar palpite", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .accessibilityIdentifier("place-bet")
        }
    }

    // MARK: Campeonato

    private var outrightsPanel: some View {
        FactoryPanel(title: "Palpites de temporada", systemImage: "trophy.fill") {
            if !career.outrightsOpen {
                Text("O mercado de longo prazo fecha depois dos primeiros jogos da temporada.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                Picker("Mercado", selection: $outrightMarket) {
                    ForEach(OutrightMarket.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                let probabilities = career.outrightProbabilities(outrightMarket)
                let top = probabilities.sorted { $0.value > $1.value }.prefix(6)
                ForEach(Array(top), id: \.key) { entry in
                    HStack {
                        Text(FootballSeason.teamName(entry.key)).font(.subheadline)
                        Spacer()
                        if let odds = career.outrightOdds(outrightMarket, clubID: entry.key) {
                            Button(String(format: "%.2f", odds)) {
                                if career.placeOutright(market: outrightMarket, clubID: entry.key, stake: outrightStake) != nil {
                                    note = "Palpite de temporada registrado."
                                } else {
                                    onAlert(career.stakeBlockReason(outrightStake) ?? "Palpite indisponível: regra de integridade ou fichas.")
                                }
                            }
                            .buttonStyle(.bordered).font(.caption.weight(.heavy))
                        }
                    }
                }
                Stepper("Valor: \(outrightStake) fichas", value: $outrightStake, in: 10...max(10, career.maxStake), step: 10).font(.subheadline)
            }
            ForEach(betting.outrights.filter { $0.season == career.season }) { bet in
                HStack {
                    Text("\(bet.market.title): \(FootballSeason.teamName(bet.clubID))").font(.caption)
                    Spacer()
                    Text("\(bet.stake) × \(String(format: "%.2f", bet.odds))").font(.caption.monospacedDigit())
                    statusPill(bet.status)
                }
            }
        }
    }

    // MARK: Bilhetes

    private var ticketsPanel: some View {
        FactoryPanel(title: "Meus bilhetes", systemImage: "list.bullet.rectangle.fill") {
            if betting.bets.isEmpty { Text("Nenhum palpite ainda.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(betting.bets.prefix(12)) { bet in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(bet.stake) fichas × \(String(format: "%.2f", bet.totalOdds))").font(.subheadline.weight(.bold).monospacedDigit())
                        Spacer()
                        statusPill(bet.status)
                    }
                    ForEach(bet.legs) { leg in
                        HStack(spacing: 6) {
                            Image(systemName: leg.won == true ? "checkmark.circle.fill" : (leg.won == false ? "xmark.circle.fill" : "circle.dotted"))
                                .foregroundStyle(leg.won == true ? .green : (leg.won == false ? .red : .secondary))
                            Text(leg.description).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if bet.status == .won { Text("Pagou \(bet.payout) fichas").font(.caption.weight(.bold)).foregroundStyle(.green) }
                    Button { detailBetID = detailBetID == bet.id ? nil : bet.id } label: {
                        Label(detailBetID == bet.id ? "Ocultar justificativa" : "Ver partidas e justificativa", systemImage: "doc.text.magnifyingglass")
                            .font(.caption.weight(.bold))
                    }
                    .accessibilityIdentifier("bet-detail-\(bet.id)")
                    if detailBetID == bet.id {
                        ForEach(bet.legs) { leg in
                            Text(career.settlementNote(for: leg)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                if bet.id != betting.bets.prefix(12).last?.id { Divider() }
            }
        }
    }

    private func statusPill(_ status: BetStatus) -> some View {
        switch status {
        case .open: return PillLabel(text: "ABERTO", tint: .blue)
        case .won: return PillLabel(text: "GANHOU", systemImage: "checkmark", tint: .green)
        case .lost: return PillLabel(text: "PERDEU", systemImage: "xmark", tint: .red)
        case .void: return PillLabel(text: "ANULADO", tint: .gray)
        }
    }

    // MARK: Palpiteiros

    private var tipstersPanel: some View {
        FactoryPanel(title: "Ranking de palpiteiros", systemImage: "list.number") {
            let rows = career.tipsterProfiles
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack {
                    Text("\(index + 1)").font(.caption.weight(.heavy)).frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.name).font(.subheadline.weight(row.isUser ? .heavy : .regular)).foregroundStyle(row.isUser ? FootballTheme.accent : .primary)
                        Text(row.hitRate.map { "\(Int(($0 * 100).rounded()))% de acerto · \(row.hits)/\(row.picks)" } ?? "sem palpites liquidados")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(FootballFormat.signed(row.profit)).font(.subheadline.monospacedDigit()).foregroundStyle(row.profit >= 0 ? .green : .red)
                }
            }
            Text("Os palpiteiros são simulados; seu histórico vem dos seus bilhetes liquidados.").font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Jogo responsável

    private var responsiblePanel: some View {
        FactoryPanel(title: "Jogo responsável", systemImage: "hand.raised.fill") {
            Text("Perdas nos últimos 4 dias: \(career.recentBettingLoss) de \(betting.lossLimit) fichas (limite).").font(.caption)
            Stepper("Limite de perdas: \(betting.lossLimit)", value: Binding(
                get: { betting.lossLimit },
                set: { career.setLossLimit($0) }
            ), in: 100...5_000, step: 100)
            .font(.subheadline)
            HStack(spacing: 10) {
                ForEach([5, 10, 20], id: \.self) { days in
                    Button("Pausa de \(days) dias") { career.selfExclude(days: days) }
                        .buttonStyle(.bordered).font(.caption.weight(.bold))
                }
            }
            Text("Apostas reais podem viciar. Aqui são só fichas de brinquedo, mas o app mantém limites e pausas como boa prática. Se apostar de verdade te preocupa, procure ajuda profissional.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
