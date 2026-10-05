import Foundation

// MARK: - Delegação ao gerente comercial (F4-05 / CLB-05)

/// Quanto risco o gerente aceita ao lançar coleções sozinho.
enum DelegationRisk: String, Codable, CaseIterable, Identifiable {
    case cautious, bold

    var id: String { rawValue }

    var title: String { self == .cautious ? "Cauteloso" : "Ousado" }

    /// Previsão mínima em relação ao investimento para lançar.
    var minimumReturn: Double { self == .cautious ? 1.5 : 1.1 }

    var allowedSizes: [CollectionSize] { self == .cautious ? [.capsule, .season] : CollectionSize.allCases }

    var summary: String {
        self == .cautious ? "Só lança coleções pequenas e médias com previsão 50% acima do custo."
                          : "Aceita coleções grandes com previsão 10% acima do custo."
    }
}

/// Teto de investimento por temporada, em fração do orçamento inicial do clube.
enum DelegationLimit: String, Codable, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var fraction: Double {
        switch self {
        case .small: return 0.02
        case .medium: return 0.04
        case .large: return 0.08
        }
    }
}

struct CommercialDelegation: Codable, Equatable {
    let clubID: Int
    var season: Int
    let startWorldDay: Int
    var risk: DelegationRisk
    var limit: DelegationLimit
    var spentThisSeason = 0
    var feesPaid = 0
    var launchedIDs: [Int] = []
    var lastReportWorldDay: Int
    /// Decisões desde o último relatório, para o texto do próximo.
    var pendingNotes: [String] = []
}

extension FootballCareer {
    static let delegationReportInterval = 5

    var commercialDelegation: CommercialDelegation? { world.commercial.delegation }

    /// Teto da temporada em dinheiro.
    func delegationCap(_ limit: DelegationLimit) -> Int {
        guard let club = selectedClub else { return 0 }
        return Int(Double(club.startingBudget) * limit.fraction / 10_000) * 10_000
    }

    /// Custo do gerente por dia de jogo: 6% das vendas-base da loja, no mínimo 2 mil.
    var delegationFeePerMatchDay: Int {
        max(2_000, Int(Double(baseMerchRevenuePerMatchDay) * 0.06 / 500) * 500)
    }

    @discardableResult
    mutating func delegateCommercial(risk: DelegationRisk, limit: DelegationLimit) -> Bool {
        guard let selectedClubID, !isFired else { return false }
        if var current = world.commercial.delegation, current.clubID == selectedClubID {
            current.risk = risk
            current.limit = limit
            world.commercial.delegation = current
            return true
        }
        world.commercial.delegation = CommercialDelegation(clubID: selectedClubID, season: season, startWorldDay: worldDay,
                                                           risk: risk, limit: limit, lastReportWorldDay: worldDay)
        addInbox(.staff, title: "Gerente comercial contratado",
                 body: "Perfil \(risk.title.lowercased()), teto de \(FootballFormat.money(delegationCap(limit))) por temporada. Custa \(FootballFormat.money(delegationFeePerMatchDay)) por dia de jogo; relatório a cada \(Self.delegationReportInterval) dias.")
        return true
    }

    mutating func endCommercialDelegation() {
        guard world.commercial.delegation != nil else { return }
        sendDelegationReport(final: true)
        world.commercial.delegation = nil
    }

    /// Melhor coleção que o gerente lançaria agora, ou nil se nada cumpre o perfil e o teto.
    func delegatedCollectionChoice() -> CollectionBrief? {
        guard let delegation = world.commercial.delegation else { return nil }
        let remaining = delegationCap(delegation.limit) - delegation.spentThisSeason
        var best: (CollectionBrief, Int)?
        for audience in CollectionAudience.allCases {
            for size in delegation.risk.allowedSizes {
                let brief = CollectionBrief(audience: audience, size: size)
                let cost = collectionCost(brief)
                let forecast = collectionForecast(brief)
                guard cost <= remaining, collectionBlocker(brief) == nil,
                      Double(forecast) >= Double(cost) * delegation.risk.minimumReturn else { continue }
                let margin = forecast - cost
                if best == nil || margin > best!.1 { best = (brief, margin) }
            }
        }
        return best?.0
    }

    /// Rotina diária: cobra o gerente, lança coleção se houver oportunidade e manda relatório periódico.
    mutating func runCommercialDelegation() {
        guard var delegation = world.commercial.delegation else { return }
        guard delegation.clubID == selectedClubID, !isFired else {
            world.commercial.delegation = nil
            return
        }
        if delegation.season != season {
            delegation.season = season
            delegation.spentThisSeason = 0
        }
        let fee = delegationFeePerMatchDay
        book(.marketing, -fee, "Gerente comercial")
        linkLastFinanceEntry(note: "Gerente comercial", FinanceLink(kind: .delegation, id: "delegation", title: "Gerente comercial"))
        delegation.feesPaid += fee
        world.commercial.delegation = delegation

        if activeCollection == nil {
            if let brief = delegatedCollectionChoice(), launchCollection(brief), let project = activeCollection {
                delegation.spentThisSeason += project.cost
                delegation.launchedIDs.append(project.id)
                delegation.pendingNotes.append("Lançou \(project.name) por \(FootballFormat.money(project.cost)), previsão de \(FootballFormat.money(project.forecast)).")
            } else if delegationCap(delegation.limit) - delegation.spentThisSeason < collectionCost(CollectionBrief(audience: .traditional, size: .capsule)) {
                if !delegation.pendingNotes.contains(where: { $0.hasPrefix("Teto") }) {
                    delegation.pendingNotes.append("Teto da temporada atingido: nenhuma coleção nova até a próxima.")
                }
            }
            world.commercial.delegation = delegation
        }
        if worldDay - delegation.lastReportWorldDay >= Self.delegationReportInterval { sendDelegationReport(final: false) }
    }

    /// Resultado das coleções lançadas pelo gerente: realizado, custo e taxa paga.
    var delegationResult: (realized: Int, invested: Int, fees: Int) {
        guard let delegation = world.commercial.delegation else { return (0, 0, 0) }
        let projects = world.commercial.collections.filter { delegation.launchedIDs.contains($0.id) }
        return (projects.reduce(0) { $0 + $1.realized }, projects.reduce(0) { $0 + $1.cost }, delegation.feesPaid)
    }

    private mutating func sendDelegationReport(final: Bool) {
        guard var delegation = world.commercial.delegation else { return }
        let result = delegationResult
        let net = result.realized - result.invested - result.fees
        var body = delegation.pendingNotes.isEmpty ? "Sem lançamentos no período." : delegation.pendingNotes.joined(separator: " ")
        body += " Acumulado: vendas extras \(FootballFormat.money(result.realized)), investido \(FootballFormat.money(result.invested)), honorários \(FootballFormat.money(result.fees)); saldo \(FootballFormat.money(net))."
        body += " Teto usado: \(FootballFormat.money(delegation.spentThisSeason)) de \(FootballFormat.money(delegationCap(delegation.limit)))."
        addInbox(.staff, title: final ? "Gerente comercial: relatório final" : "Gerente comercial: relatório", body: body)
        delegation.pendingNotes = []
        delegation.lastReportWorldDay = worldDay
        world.commercial.delegation = delegation
    }
}
