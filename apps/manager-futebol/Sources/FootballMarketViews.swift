import SwiftUI

// MARK: - Mercado

struct FootballMarketView: View {
    enum MarketSection: String, CaseIterable, Identifiable {
        case free = "Livres", clubs = "Clubes", scouting = "Olheiros", youth = "Base", log = "Histórico"

        var id: String { rawValue }
    }

    struct PlayerSelection: Identifiable {
        let id: Int
    }

    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var section: MarketSection = .free
    @State private var filter: FootballPosition?
    @State private var clubFilter: Int?
    @State private var pendingSigning: FootballPlayer?
    @State private var selected: PlayerSelection?
    @State private var missionPosition: FootballPosition?
    @State private var missionRegion: Int?
    @State private var missionAge = 23
    @State private var missionValue = 5_000_000

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let club = career.selectedClub {
                FactoryHeader(
                    eyebrow: career.transferWindow?.title ?? "Janela fechada",
                    title: "Reforce o \(club.name)",
                    subtitle: career.transferWindow.map { "\($0.daysLeft) dia(s) de jogo até o fim da janela. Contratar de outros clubes só com a janela aberta." }
                        ?? "Só agentes livres podem ser contratados fora das janelas. As próximas janelas abrem na pré-temporada e no meio do ano.",
                    accent: FootballTheme.accent
                )
                HStack(spacing: 12) {
                    FactoryMetric(label: "Caixa", value: FootballFormat.money(career.transferBudget), symbol: "wallet.bifold.fill", tint: FootballTheme.accent)
                    FactoryMetric(label: "Vagas", value: "\(career.clubRoster.count)/\(FootballCareer.rosterLimit)", symbol: "person.3.fill", tint: .orange)
                }
                if career.isTransferBanned {
                    Label("Transfer ban: o clube está devendo e não pode contratar.", systemImage: "hand.raised.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.red)
                }
                if !career.offers.isEmpty { FootballOffersPanel(career: $career, onAlert: onAlert) }
                FootballTransferRacePanel(career: $career) { selected = PlayerSelection(id: $0) }
                FootballRecruitmentHub(career: $career, onAlert: onAlert) { selected = PlayerSelection(id: $0) }
                Picker("Seção", selection: $section) {
                    ForEach(MarketSection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("market-section")
                switch section {
                case .free: freeAgents
                case .clubs: clubPlayers
                case .scouting: scouting
                case .youth: youth
                case .log: log
                }
            }
        }
        .factoryPage()
        .navigationTitle("Mercado")
        .sheet(item: $selected) { selection in
            FootballPlayerDetailView(career: $career, playerID: selection.id, onAlert: onAlert)
        }
        .confirmationDialog(
            "Contratar \(pendingSigning?.name ?? "atleta")?",
            isPresented: Binding(get: { pendingSigning != nil }, set: { if !$0 { pendingSigning = nil } }),
            titleVisibility: .visible
        ) {
            if let player = pendingSigning {
                Button("Contratar por \(FootballFormat.money(player.marketValue))") {
                    if !career.signPlayer(playerID: player.id) {
                        onAlert(career.signBlockReason(playerID: player.id) ?? "Não foi possível contratar: confira o orçamento e as vagas no elenco.")
                    }
                    pendingSigning = nil
                }
            }
            Button("Cancelar", role: .cancel) { pendingSigning = nil }
        } message: {
            Text("O valor sai do caixa de transferências.")
        }
    }

    private var positionFilter: some View {
        Picker("Posição", selection: $filter) {
            Text("Todos").tag(FootballPosition?.none)
            ForEach(FootballPosition.allCases, id: \.self) { Text($0.rawValue).tag(FootballPosition?.some($0)) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("market-filter")
    }

    // MARK: Agentes livres

    private var freeAgents: some View {
        let visible = career.marketPlayers.filter { filter == nil || $0.position == filter }
        return VStack(alignment: .leading, spacing: 14) {
            positionFilter
            FactoryPanel(title: "Agentes livres · \(visible.count)", systemImage: "person.crop.circle.badge.plus") {
                if visible.isEmpty { Text("Nenhum atleta disponível com este filtro.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(visible.prefix(40)) { player in
                    HStack(spacing: 10) {
                        Button { selected = PlayerSelection(id: player.id) } label: { PlayerRow(player: player, showValue: true) }
                            .buttonStyle(.plain)
                        Button { pendingSigning = player } label: { Image(systemName: "plus").font(.headline) }
                            .buttonStyle(.borderedProminent)
                            .disabled(!career.canSign(playerID: player.id))
                            .accessibilityLabel("Contratar \(player.name)")
                            .accessibilityIdentifier("contract-player-\(player.id)")
                    }
                    if player.id != visible.prefix(40).last?.id { Divider() }
                }
                Text(career.clubRoster.count >= FootballCareer.rosterLimit
                     ? "Elenco completo. Venda ou dispense um atleta para abrir vaga."
                     : "Contratações exigem vaga no elenco, folha salarial dentro do teto e saldo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Outros clubes

    private var clubPlayers: some View {
        let pool = career.players
            .filter { $0.teamID != nil && $0.teamID != career.selectedClubID && !$0.isYouth && !$0.onLoan }
            .filter { (filter == nil || $0.position == filter) && (clubFilter == nil || $0.teamID == clubFilter) }
            .sorted { $0.overall > $1.overall }
            .prefix(30)
        return VStack(alignment: .leading, spacing: 14) {
            positionFilter
            HStack {
                Text("Clube").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Clube", selection: $clubFilter) {
                    Text("Todos").tag(Int?.none)
                    ForEach(FootballSeason.teams.filter { $0.id != career.selectedClubID }) { Text($0.name).tag(Int?.some($0.id)) }
                }
                .pickerStyle(.menu)
            }
            FactoryPanel(title: "Atletas de outros clubes", systemImage: "arrow.left.arrow.right") {
                Text("Toque no atleta para ver a ficha, observar e fazer proposta. O rating aparece em faixa até o olheiro conhecer o jogador.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(pool)) { player in
                    Button { selected = PlayerSelection(id: player.id) } label: {
                        HStack(spacing: 10) {
                            let range = career.visibleOverallRange(of: player.id)
                            Text(range.lowerBound == range.upperBound ? "\(range.lowerBound)" : "\(range.lowerBound)–\(range.upperBound)")
                                .font(.caption.weight(.heavy).monospacedDigit()).foregroundStyle(.white)
                                .frame(width: 44, height: 30)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text("\(player.position.rawValue) · \(player.age) anos · \(FootballSeason.team(player.teamID ?? 0)?.shortName ?? "")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(FootballFormat.money(career.askingPrice(for: player))).font(.caption.weight(.bold)).foregroundStyle(FootballTheme.accent)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("club-player-\(player.id)")
                }
            }
        }
    }

    // MARK: Olheiros

    private var scouting: some View {
        VStack(alignment: .leading, spacing: 14) {
            FactoryPanel(title: "Missões de observação", systemImage: "binoculars.fill") {
                Text("Olheiro-chefe: habilidade \(career.scoutAbility). \(career.activeScoutMissions.count)/\(career.scoutSlots) missões em andamento.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(career.activeScoutMissions) { mission in
                    Label(mission.summary, systemImage: "hourglass").font(.caption)
                }
                Picker("Posição", selection: $missionPosition) {
                    Text("Qualquer posição").tag(FootballPosition?.none)
                    ForEach(FootballPosition.allCases, id: \.self) { Text($0.title).tag(FootballPosition?.some($0)) }
                }
                Picker("Região", selection: $missionRegion) {
                    Text("Todo o país").tag(Int?.none)
                    ForEach(0..<LeagueTeam.regionNames.count, id: \.self) { Text(LeagueTeam.regionNames[$0]).tag(Int?.some($0)) }
                }
                Stepper("Idade máxima: \(missionAge)", value: $missionAge, in: 17...34)
                Stepper("Valor máximo: \(FootballFormat.money(missionValue))", value: $missionValue, in: 500_000...50_000_000, step: 500_000)
                Button {
                    if !career.startScoutMission(region: missionRegion, position: missionPosition, maxAge: missionAge, maxValue: missionValue) {
                        onAlert("Todos os olheiros já estão em missão.")
                    }
                } label: {
                    Label("Enviar olheiro", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("start-scout")
            }
            FactoryPanel(title: "Relatórios", systemImage: "doc.text.magnifyingglass") {
                if career.scoutReports.isEmpty { Text("Os relatórios chegam alguns jogos depois do envio.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(career.scoutReports.reversed().prefix(10)) { report in
                    if let player = career.player(report.playerID) {
                        Button { selected = PlayerSelection(id: player.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.name).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                                HStack(spacing: 12) {
                                    stars("Hoje", report.currentStars)
                                    stars("Potencial", report.potentialStars)
                                }
                                Text(report.note).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            FactoryPanel(title: "Lista de observação", systemImage: "eye.fill") {
                if career.watchlist.isEmpty { Text("Marque atletas na ficha para acompanhá-los aqui.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(career.watchlist.compactMap { career.player($0) }) { player in
                    Button { selected = PlayerSelection(id: player.id) } label: { PlayerRow(player: player, showValue: true) }.buttonStyle(.plain)
                }
            }
        }
    }

    private func stars(_ title: String, _ count: Int) -> some View {
        HStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < count ? "star.fill" : "star").font(.caption2).foregroundStyle(FootballTheme.gold)
            }
        }
    }

    // MARK: Base

    private var youth: some View {
        VStack(alignment: .leading, spacing: 14) {
            FactoryPanel(title: "Programa da base · nível \(career.youthAcademyLevel)", systemImage: "graduationcap.fill") {
                Picker("Programa", selection: Binding(get: { career.world.growth.youthProgram }, set: { career.setYouthProgram($0) })) {
                    ForEach(YouthProgram.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(career.world.growth.youthProgram.summary).font(.caption).foregroundStyle(.secondary)
                Button {
                    if career.holdTryout(region: missionRegion).isEmpty { onAlert(career.canHoldTryout() ?? "Não foi possível realizar a peneira.") }
                } label: {
                    Label("Fazer peneira · \(FootballFormat.money(career.tryoutCost))", systemImage: "figure.soccer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("hold-tryout")
                Text("Uma peneira por temporada traz 2 jovens da região escolhida na aba Olheiros.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(YouthCategory.allCases) { category in
                FactoryPanel(title: "\(category.title) · \(career.youth(in: category).count)", systemImage: category == .under17 ? "person.crop.circle" : "person.crop.circle.fill") {
                    if career.youth(in: category).isEmpty { Text("Nenhum atleta nesta categoria.").font(.subheadline).foregroundStyle(.secondary) }
                    ForEach(career.youth(in: category)) { player in
                        VStack(alignment: .leading, spacing: 8) {
                            Button { selected = PlayerSelection(id: player.id) } label: { PlayerRow(player: player) }.buttonStyle(.plain)
                            HStack(spacing: 10) {
                                Button("Promover") {
                                    if !career.promoteYouth(playerID: player.id) { onAlert("Sem vaga no elenco ou folha salarial no teto.") }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!career.canPromote(playerID: player.id))
                                Button("Dispensar", role: .destructive) { career.releaseYouth(playerID: player.id) }.buttonStyle(.bordered)
                            }
                            .font(.caption.weight(.bold))
                        }
                        if player.id != career.youth(in: category).last?.id { Divider() }
                    }
                }
            }
            ForEach(career.youthCupHistory.suffix(3).reversed()) { result in
                Text("Copinha T\(result.season): \(result.userResult) · campeão \(FootballSeason.teamName(result.winnerID))").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Histórico

    private var log: some View {
        FactoryPanel(title: "Transferências recentes", systemImage: "list.bullet.rectangle") {
            if career.transferLog.isEmpty { Text("Ainda sem movimentação.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(career.transferLog.suffix(25).reversed()) { record in
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.playerName).font(.subheadline.weight(.semibold))
                    Text("\(record.fromClubID.map { FootballSeason.teamName($0) } ?? "Livre") → \(record.toClubID.map { FootballSeason.teamName($0) } ?? "Livre") · \(record.isLoan ? "empréstimo " : "")\(FootballFormat.money(record.fee))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
