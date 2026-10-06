import SwiftUI

// MARK: - Rodada Mágica (fantasy)

struct FootballFantasyView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    /// Captura: só os painéis novos, no topo.
    var captureFocus = false
    var captureSection: String? = nil

    @State private var lineup: [Int] = []
    @State private var captainID: Int?
    @State private var position: FootballPosition = .goalkeeper
    @State private var didLoad = false
    @State private var filter = FantasyFilter(maxRisk: .doubt)
    @State private var maxPriceEnabled = false
    @State private var maxPrice = 8.0
    @State private var formOnly = false

    private var fantasy: FantasyState { career.world.fantasy }
    private var cost: Double { career.fantasyLineupCost(lineup) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                FactoryMetric(label: "Pontos na temporada", value: String(format: "%.1f", fantasy.seasonPoints), symbol: "star.fill", tint: FootballTheme.gold)
                FactoryMetric(label: "Títulos", value: "\(fantasy.titles)", symbol: "trophy.fill", tint: .green)
            }
            if captureSection == "league" {
                standingsPanel
            } else if captureSection == "share" {
                historyPanel
            } else {
            roundPanel
            detailPanel
            if captureSection != "result" {
            if !captureFocus { lineupPanel }
            captainPanel
            marketPanel
            if !captureFocus {
                standingsPanel
                historyPanel
            }
            }
            }
        }
        .factoryPage()
        .navigationTitle("Rodada Mágica")
        .onAppear {
            career.ensureFantasyManagers()
            guard !didLoad else { return }
            didLoad = true
            let working = career.fantasyWorkingLineup
            lineup = working.lineup
            captainID = working.captainID
        }
        .onChange(of: lineup) { _, _ in persistDraft() }
        .onChange(of: captainID) { _, _ in persistDraft() }
    }

    private func persistDraft() {
        guard didLoad else { return }
        if lineup == fantasy.lineup && captainID == fantasy.captainID { career.saveFantasyDraft(ids: [], captainID: nil) }
        else { career.saveFantasyDraft(ids: lineup, captainID: captainID) }
    }

    // MARK: Rodada

    private var roundPanel: some View {
        FactoryPanel(title: "Próxima rodada", systemImage: "clock.badge.exclamationmark") {
            if let text = career.fantasyDeadlineText {
                Text(text).font(.subheadline.weight(.semibold)).accessibilityIdentifier("fantasy-deadline")
            } else {
                Text("Temporada encerrada: a escalação volta a abrir na próxima.").font(.subheadline).foregroundStyle(.secondary)
            }
            let risky = lineup.compactMap { career.player($0) }.map { career.fantasyOutlook(for: $0) }.filter { $0.risk != .none }
            ForEach(risky) { outlook in
                Label("\(career.player(outlook.playerID)?.name ?? "") · \(outlook.riskReason ?? outlook.risk.label)",
                      systemImage: outlook.risk == .out ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(outlook.risk == .out ? .red : .orange)
            }
            if lineup != fantasy.lineup || captainID != fantasy.captainID {
                Text("Rascunho guardado. Salve o time para valer na rodada.").font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("fantasy-draft-note")
            }
        }
    }

    private var captainPanel: some View {
        let rows = career.fantasyCaptainComparison(ids: lineup)
        return Group {
            if !rows.isEmpty {
                FactoryPanel(title: "Comparar capitães", systemImage: "c.circle") {
                    ForEach(rows.prefix(5)) { outlook in
                        Button { captainID = outlook.playerID } label: {
                            HStack {
                                Image(systemName: captainID == outlook.playerID ? "c.circle.fill" : "c.circle")
                                    .foregroundStyle(captainID == outlook.playerID ? FootballTheme.gold : Color.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(career.player(outlook.playerID)?.name ?? "").font(.subheadline)
                                    Text(outlookLine(outlook)).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "forma %.1f", outlook.form)).font(.caption.monospacedDigit())
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("fantasy-captain-\(outlook.playerID)")
                    }
                    Text("Forma é a média de pontos nas últimas \(FootballCareer.fantasyFormWindow) rodadas. O capitão pontua 1,5×.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func outlookLine(_ outlook: FantasyOutlook) -> String {
        let opponent = outlook.opponentID.flatMap { FootballSeason.team($0)?.shortName }
            .map { (outlook.isHome ? "vs " : "@ ") + $0 } ?? "sem jogo"
        return [opponent, outlook.riskReason ?? outlook.risk.label].joined(separator: " · ")
    }

    // MARK: Escalação

    private var lineupPanel: some View {
        FactoryPanel(title: "Seu time dos sonhos · 4-3-3", systemImage: "sportscourt.fill") {
            HStack {
                Text("Orçamento").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", cost)) / \(Int(FantasyState.budget))")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(cost > FantasyState.budget ? .red : .primary)
            }
            if lineup.isEmpty { Text("Monte 11 atletas: presença, gols, assistências, saldo defensivo e vitória somam pontos; cartões descontam.").font(.caption).foregroundStyle(.secondary) }
            ForEach(lineup.compactMap { career.player($0) }) { athlete in
                HStack(spacing: 10) {
                    Text(athlete.position.rawValue).font(.caption2.weight(.bold)).frame(width: 28)
                    Text(athlete.name).font(.subheadline).lineLimit(1)
                    if let teamID = athlete.teamID { Text(FootballSeason.team(teamID)?.shortName ?? "").font(.caption2).foregroundStyle(.secondary) }
                    Spacer()
                    Text(String(format: "%.1f", career.fantasyPrice(athlete))).font(.caption.monospacedDigit())
                    Button { captainID = athlete.id } label: {
                        Image(systemName: captainID == athlete.id ? "c.circle.fill" : "c.circle")
                            .foregroundStyle(captainID == athlete.id ? FootballTheme.gold : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    Button { lineup.removeAll { $0 == athlete.id }; if captainID == athlete.id { captainID = nil } } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                Button {
                    let suggestion = career.suggestedFantasyLineup()
                    lineup = suggestion.ids
                    captainID = suggestion.captainID
                } label: {
                    Label("Sugestão", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("fantasy-suggest")
                Button {
                    if career.setFantasyLineup(ids: lineup, captainID: captainID) {
                        onAlert("Escalação salva! O capitão pontua 1,5×.")
                    } else {
                        onAlert(career.fantasyBlockReason(ids: lineup, captainID: captainID) ?? "Escalação inválida.")
                    }
                } label: {
                    Label("Salvar time", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("fantasy-save")
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: Mercado

    private var marketPanel: some View {
        let limit = FootballCareer.fantasyFormation[position] ?? 0
        let chosen = lineup.compactMap { career.player($0) }.filter { $0.position == position }.count
        var activeFilter = filter
        activeFilter.maxPrice = maxPriceEnabled ? maxPrice : nil
        activeFilter.minForm = formOnly ? 3 : nil
        let pool = career.fantasyFilteredPool(position: position, filter: activeFilter, excluding: Set(lineup)).prefix(14)
        return FactoryPanel(title: "Mercado de atletas", systemImage: "person.crop.circle.badge.plus") {
            Picker("Posição", selection: $position) {
                ForEach(FootballPosition.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("\(chosen)/\(limit) escalados nesta posição").font(.caption).foregroundStyle(.secondary)
            Toggle("Esconder dúvidas e ausências", isOn: Binding(get: { filter.maxRisk == .none },
                                                                set: { filter.maxRisk = $0 ? .none : .doubt }))
                .font(.caption).accessibilityIdentifier("fantasy-filter-risk")
            Toggle("Só quem pontuou em média 3+", isOn: $formOnly).font(.caption).accessibilityIdentifier("fantasy-filter-form")
            Toggle("Preço máximo \(String(format: "%.1f", maxPrice))", isOn: $maxPriceEnabled).font(.caption)
                .accessibilityIdentifier("fantasy-filter-price")
            if maxPriceEnabled { Slider(value: $maxPrice, in: 3...20, step: 0.5) }
            if pool.isEmpty { Text("Nenhum atleta atende aos filtros.").font(.caption).foregroundStyle(.secondary) }
            ForEach(Array(pool)) { outlook in
                let athlete = career.player(outlook.playerID)!
                HStack(spacing: 10) {
                    RatingBadge(value: athlete.overall, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(athlete.name).font(.subheadline).lineLimit(1)
                        Text(([athlete.teamID.flatMap { FootballSeason.team($0)?.shortName } ?? "", outlookLine(outlook)]).joined(separator: " · "))
                            .font(.caption2).foregroundStyle(outlook.risk == .none ? Color.secondary : Color.orange)
                    }
                    Spacer()
                    Text(String(format: "%.1f", career.fantasyPrice(athlete))).font(.caption.weight(.bold).monospacedDigit())
                    Button {
                        if chosen < limit { lineup.append(athlete.id) } else { onAlert("Esta posição já está completa. Remova alguém antes.") }
                    } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(FootballTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Classificação e histórico

    private var detailPanel: some View {
        FactoryPanel(title: "Como seu time pontuou", systemImage: "list.bullet.rectangle") {
            if let detail = career.fantasyLatestDetail {
                Text(String(format: "T%d · R%d · %.1f pontos", detail.season, detail.round, detail.points))
                    .font(.subheadline.weight(.bold)).accessibilityIdentifier("fantasy-detail-total")
                ForEach(detail.athletes) { athlete in
                    DisclosureGroup {
                        Text(athlete.status).font(.caption).foregroundStyle(.secondary)
                        if let fixtureID = athlete.fixtureID {
                            Text("Fonte: partida #\(fixtureID)").font(.caption2).foregroundStyle(.secondary)
                        }
                        ForEach(athlete.components) { component in
                            HStack {
                                Text("\(component.label) · \(component.quantity)")
                                Spacer()
                                Text(String(format: "%+.1f", component.points)).monospacedDigit()
                            }.font(.caption)
                        }
                        if athlete.isCaptain {
                            Text(String(format: "Capitão: %+.1f de bônus (1,5×, inclusive descontos)", athlete.captainBonus)).font(.caption)
                        }
                    } label: {
                        HStack {
                            Text(athlete.name + (athlete.isCaptain ? " · C" : ""))
                            Spacer()
                            Text(String(format: "%.1f", athlete.points)).monospacedDigit()
                        }.font(.subheadline)
                    }.accessibilityIdentifier("fantasy-detail-\(athlete.id)")
                }
            } else {
                Text("Nenhum detalhe de rodada disponível. Monte seu time e conclua uma rodada da liga.").font(.subheadline)
            }
            Text(FootballCareer.fantasyDetailLimitation).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("fantasy-detail-panel")
    }

    private var standingsPanel: some View {
        FactoryPanel(title: "Liga dos amigos · privada fictícia", systemImage: "list.number") {
            let rows = career.fantasyParticipants
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                DisclosureGroup {
                    Text(row.bio).font(.caption)
                    if let points = row.lastRoundPoints {
                        Text(String(format: "Última rodada: %.1f · diferença para você: %+.1f", points,
                                    points - (fantasy.history.first?.season == career.season ? fantasy.history.first?.points ?? 0 : 0)))
                            .font(.caption.monospacedDigit())
                    } else {
                        Text("Comparação disponível após sua primeira rodada pontuada.").font(.caption)
                    }
                    if !row.isUser {
                        Text("Participante recorrente fictício. Pontos simulados; não há escalação ou capitão registrado para comparar escolhas.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } label: {
                HStack {
                    Text("\(index + 1)").font(.caption.weight(.heavy)).frame(width: 20)
                    Text(row.name).font(.subheadline.weight(row.isUser ? .heavy : .regular)).foregroundStyle(row.isUser ? FootballTheme.accent : .primary)
                    Spacer()
                    Text(String(format: "%.1f", row.points)).font(.subheadline.monospacedDigit())
                }
                }
                .accessibilityIdentifier("fantasy-participant-\(row.id)")
            }
            Text("Consulta opcional, sem custo de entrada. O campeão da temporada ganha 500 fichas; compartilhar não paga novamente.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var historyPanel: some View {
        FactoryPanel(title: "Últimas rodadas", systemImage: "clock.arrow.circlepath") {
            if fantasy.history.isEmpty { Text("A pontuação sai depois de cada rodada.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(Array(fantasy.history.prefix(8))) { result in
                VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("T\(result.season) · R\(result.round)").font(.caption.weight(.bold))
                    Text("Capitão \(result.captainName)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Text(String(format: "%.1f pts · %dº", result.points, result.rank)).font(.caption.monospacedDigit())
                }
                Text(career.fantasyShareText(result)).font(.caption2).foregroundStyle(.secondary)
                Button("Compartilhar no Chuteira") {
                    if career.shareFantasyResult(result) != nil {
                        onAlert("Resultado publicado no Chuteira. Nenhum prêmio fantasy foi reaplicado.")
                    } else {
                        onAlert(career.fantasyShareBlockReason(result) ?? "Publicação indisponível.")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(career.fantasyShareBlockReason(result) != nil)
                .accessibilityIdentifier("fantasy-share-\(result.id)")
                if let reason = career.fantasyShareBlockReason(result) {
                    Text(reason).font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Usa a publicação diária da Chuteira, com engajamento e risco de polêmica do tom bem-humorado.").font(.caption2).foregroundStyle(.secondary)
                }
                }
            }
        }
    }
}
