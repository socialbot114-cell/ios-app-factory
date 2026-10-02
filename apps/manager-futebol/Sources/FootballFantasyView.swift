import SwiftUI

// MARK: - Rodada Mágica (fantasy)

struct FootballFantasyView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    @State private var lineup: [Int] = []
    @State private var captainID: Int?
    @State private var position: FootballPosition = .goalkeeper
    @State private var didLoad = false

    private var fantasy: FantasyState { career.world.fantasy }
    private var cost: Double { career.fantasyLineupCost(lineup) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                FactoryMetric(label: "Pontos na temporada", value: String(format: "%.1f", fantasy.seasonPoints), symbol: "star.fill", tint: FootballTheme.gold)
                FactoryMetric(label: "Títulos", value: "\(fantasy.titles)", symbol: "trophy.fill", tint: .green)
            }
            lineupPanel
            marketPanel
            standingsPanel
            historyPanel
        }
        .factoryPage()
        .navigationTitle("Rodada Mágica")
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            lineup = fantasy.lineup
            captainID = fantasy.captainID
        }
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
            if lineup.isEmpty { Text("Monte 11 atletas de qualquer clube: pontuam por gols, assistências, desarmes e nota.").font(.caption).foregroundStyle(.secondary) }
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
                        onAlert("Escalação salva! O capitão pontua em dobro.")
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
        let pool = career.fantasyPool.filter { $0.position == position && !lineup.contains($0.id) }
            .sorted { $0.overall > $1.overall }.prefix(14)
        return FactoryPanel(title: "Mercado de atletas", systemImage: "person.crop.circle.badge.plus") {
            Picker("Posição", selection: $position) {
                ForEach(FootballPosition.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("\(chosen)/\(limit) escalados nesta posição").font(.caption).foregroundStyle(.secondary)
            ForEach(Array(pool)) { athlete in
                HStack(spacing: 10) {
                    RatingBadge(value: athlete.overall, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(athlete.name).font(.subheadline).lineLimit(1)
                        Text(athlete.teamID.flatMap { FootballSeason.team($0)?.name } ?? "").font(.caption2).foregroundStyle(.secondary)
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

    private var standingsPanel: some View {
        FactoryPanel(title: "Classificação da temporada", systemImage: "list.number") {
            let rows = career.fantasyStandings
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack {
                    Text("\(index + 1)").font(.caption.weight(.heavy)).frame(width: 20)
                    Text(row.name).font(.subheadline.weight(row.isUser ? .heavy : .regular)).foregroundStyle(row.isUser ? FootballTheme.accent : .primary)
                    Spacer()
                    Text(String(format: "%.1f", row.points)).font(.subheadline.monospacedDigit())
                }
            }
            Text("O campeão da temporada ganha 500 fichas.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var historyPanel: some View {
        FactoryPanel(title: "Últimas rodadas", systemImage: "clock.arrow.circlepath") {
            if fantasy.history.isEmpty { Text("A pontuação sai depois de cada rodada.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(fantasy.history.suffix(8).reversed()) { result in
                HStack {
                    Text("T\(result.season) · R\(result.round)").font(.caption.weight(.bold))
                    Text("Capitão \(result.captainName)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Text(String(format: "%.1f pts · %dº", result.points, result.rank)).font(.caption.monospacedDigit())
                }
            }
        }
    }
}
