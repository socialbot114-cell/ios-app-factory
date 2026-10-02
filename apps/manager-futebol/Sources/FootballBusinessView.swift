import SwiftUI

// MARK: - Negócios do clube

struct FootballBusinessView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var note: String?

    private var business: BusinessState { career.world.business }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                FactoryMetric(label: "Caixa do clube", value: FootballFormat.money(career.transferBudget), symbol: "banknote.fill", tint: FootballTheme.accent)
                FactoryMetric(label: "Lojinha por jogo", value: FootballFormat.money(career.merchRevenuePerMatchDay), symbol: "bag.fill", tint: .indigo)
            }
            if let note {
                Label(note, systemImage: "checkmark.circle.fill").font(.subheadline.weight(.medium)).foregroundStyle(FootballTheme.accent)
            }
            shopPanel
            namingPanel
            programsPanel
            friendliesPanel
            agentsPanel
        }
        .factoryPage()
        .navigationTitle("Negócios do clube")
    }

    // MARK: Loja

    private var shopPanel: some View {
        FactoryPanel(title: "Loja oficial · nível \(business.shopLevel)", systemImage: "bag.fill") {
            Picker("Preço", selection: Binding(get: { business.shopPrice }, set: { career.setShopPrice($0) })) {
                ForEach(ShopPrice.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("Preço alto rende mais por camisa, mas vende menos. Promoção enche a loja.").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button {
                    if career.upgradeShop() { note = "Loja ampliada." } else { onAlert("Sem caixa ou a loja já está no nível máximo.") }
                } label: {
                    Label(career.shopUpgradeCost().map { "Ampliar · \(FootballFormat.money($0))" } ?? "Nível máximo", systemImage: "arrow.up.square.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    if career.launchCollection() { note = "Nova coleção lançada: vendas em alta por alguns jogos." } else { onAlert("Caixa insuficiente ou coleção já ativa.") }
                } label: {
                    Label(career.collectionActive ? "Coleção ativa" : "Coleção · \(FootballFormat.money(career.collectionCost()))", systemImage: "tshirt.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(career.collectionActive)
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: Naming

    private var namingPanel: some View {
        FactoryPanel(title: "Nome do estádio", systemImage: "building.columns.fill") {
            Text(career.stadiumDisplayName).font(.subheadline.weight(.bold))
            if let deal = business.naming {
                Label("\(deal.sponsor) · \(FootballFormat.money(deal.perSeason))/temporada até a T\(deal.endSeason)", systemImage: "signature")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(business.namingOffers) { offer in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.stadiumName).font(.subheadline.weight(.semibold))
                        Text("\(FootballFormat.money(offer.perSeason))/temporada por \(offer.seasons) temporadas").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Aceitar") {
                        if career.acceptNamingOffer(offer.id) { note = "Novo nome do estádio: \(offer.stadiumName)." }
                    }
                    .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                }
            }
            if business.namingOffers.isEmpty && business.naming == nil {
                Text("Propostas de naming rights chegam no começo da temporada, conforme o prestígio do clube.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Programas

    private var programsPanel: some View {
        FactoryPanel(title: "Projetos sociais · \(business.programs.count)/\(FootballCareer.maxPrograms)", systemImage: "heart.circle.fill") {
            ForEach(CommunityProgram.allCases) { program in
                let active = business.programs.contains(program)
                HStack(spacing: 12) {
                    Image(systemName: program.symbol).frame(width: 28).foregroundStyle(active ? FootballTheme.accent : Color.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(program.title).font(.subheadline.weight(.semibold))
                        Text(program.summary).font(.caption).foregroundStyle(.secondary)
                        Text("\(FootballFormat.money(program.costPerSeason))/temporada").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(active ? "Encerrar" : "Iniciar") {
                        if !career.toggle(program) { onAlert(career.canToggle(program) ?? "Indisponível.") }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(active ? Color.gray : FootballTheme.accent)
                    .font(.caption.weight(.bold))
                }
                if program != CommunityProgram.allCases.last { Divider() }
            }
        }
    }

    // MARK: Amistosos e turnê

    private var friendliesPanel: some View {
        FactoryPanel(title: "Amistosos e turnê", systemImage: "airplane") {
            Text("Amistosos rendem bilheteria e ritmo de jogo, com pouco desgaste. \(business.friendliesThisSeason)/\(FootballCareer.friendlyLimit) nesta temporada.")
                .font(.caption).foregroundStyle(.secondary)
            if let block = career.canPlayFriendly() {
                Label(block, systemImage: "lock.fill").font(.caption).foregroundStyle(.secondary)
            } else {
                let opponents = FootballSeason.teams.filter { $0.id != career.selectedClubID }.prefix(6)
                ForEach(Array(opponents)) { team in
                    HStack {
                        ClubCrest(team: team, size: 22)
                        Text(team.name).font(.subheadline)
                        Spacer()
                        Button("Jogar em casa") {
                            if let record = career.playFriendly(opponentID: team.id, home: true) {
                                note = "Amistoso: \(record.goalsFor) × \(record.goalsAgainst) contra \(team.name) · \(FootballFormat.money(record.revenue))."
                            }
                        }
                        .buttonStyle(.bordered).font(.caption.weight(.bold))
                    }
                }
            }
            Divider()
            Button {
                if career.doPreseasonTour() { note = "Turnê internacional realizada: torcida e caixa cresceram." } else { onAlert(career.canDoTour() ?? "Turnê indisponível.") }
            } label: {
                Label("Turnê de pré-temporada", systemImage: "globe.americas.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .font(.subheadline.weight(.semibold))
            ForEach(business.friendlies.suffix(4).reversed()) { record in
                Text("T\(record.season): \(record.goalsFor) × \(record.goalsAgainst) vs \(FootballSeason.teamName(record.opponentID))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Agentes

    private var agentsPanel: some View {
        FactoryPanel(title: "Propostas de empresários", systemImage: "briefcase.fill") {
            if business.agentOffers.isEmpty {
                Text("Empresários oferecem renovações com desconto no salário em troca de uma comissão.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(business.agentOffers) { offer in
                if let athlete = career.player(offer.playerID) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(offer.agentName) · \(athlete.name)").font(.subheadline.weight(.semibold))
                            Text("Salário \(FootballFormat.money(offer.discountedWage)) · comissão \(FootballFormat.money(offer.agentFee))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Aceitar") {
                            if career.acceptAgentOffer(offer.id) { note = "Renovação fechada via \(offer.agentName)." } else { onAlert("Sem caixa para a comissão.") }
                        }
                        .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                    }
                }
            }
        }
    }
}
