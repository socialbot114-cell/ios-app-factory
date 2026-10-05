import Foundation

// MARK: - Projeção de caixa (F4-01)

/// Grau de certeza de um lançamento futuro: contrato assinado ou estimativa que depende de torcida, vendas e saldo.
enum CashCertainty: String, Equatable {
    case contracted, estimated

    var title: String { self == .contracted ? "Garantido" : "Estimado" }
}

/// Uma fonte de receita ou despesa no período projetado.
struct CashProjectionLine: Equatable, Identifiable {
    let category: FinanceCategory
    let title: String
    let certainty: CashCertainty
    /// Total no período (positivo = entra, negativo = sai).
    let total: Int
    /// Dia de jogo do vencimento, quando é um pagamento único.
    let dueMatchDay: Int?

    var id: String { "\(category.rawValue)-\(title)-\(dueMatchDay ?? -1)" }
}

struct CashProjectionDay: Equatable, Identifiable {
    /// Índice do dia de jogo que será processado.
    let matchDay: Int
    let contracted: Int
    let estimated: Int
    /// Saldo ao fim do dia contando só o garantido (cenário conservador).
    let contractedBalance: Int
    /// Saldo ao fim do dia contando garantido e estimado.
    let expectedBalance: Int
    let hasHomeMatch: Bool

    var id: Int { matchDay }
}

struct CashProjection: Equatable {
    let startingCash: Int
    let days: [CashProjectionDay]
    let lines: [CashProjectionLine]

    var horizon: Int { days.count }
    var endingContracted: Int { days.last?.contractedBalance ?? startingCash }
    var endingExpected: Int { days.last?.expectedBalance ?? startingCash }
    var lowestExpected: CashProjectionDay? { days.min { $0.expectedBalance < $1.expectedBalance } }
    /// Primeiro dia em que o cenário conservador fica negativo.
    var firstContractedShortfall: CashProjectionDay? { days.first { $0.contractedBalance < 0 } }
    var committedOutflows: Int { lines.filter { $0.certainty == .contracted && $0.total < 0 }.reduce(0) { $0 + $1.total } }
    var contractedInflows: Int { lines.filter { $0.certainty == .contracted && $0.total > 0 }.reduce(0) { $0 + $1.total } }
}

extension FootballCareer {
    static let defaultProjectionHorizon = 8

    /// Mesmo ajuste de dificuldade aplicado por `book` às receitas sensíveis à dificuldade.
    private func projectedAmount(_ category: FinanceCategory, _ amount: Int) -> Int {
        guard amount > 0, [FinanceCategory.gate, .members, .tv, .sponsor].contains(category) else { return amount }
        return Int(Double(amount) * difficulty.incomeFactor)
    }

    /// Projeta o caixa do clube nos próximos dias de jogo da temporada, sem alterar a carreira.
    /// Considera só compromissos já assumidos e fluxos recorrentes atuais; não supõe vendas, compras ou prêmios.
    func cashProjection(horizon: Int = defaultProjectionHorizon) -> CashProjection {
        guard let selectedClubID, let club = selectedClub, !isFired else {
            return CashProjection(startingCash: transferBudget, days: [], lines: [])
        }
        let perSeason = FootballSeason.matchDaysPerSeason
        let count = max(0, min(horizon, perSeason - matchDayIndex))

        // Recorrentes por dia de jogo, espelhando collectMatchDayIncome, chargeMatchDayWages, chargeOperatingCosts,
        // tickBusiness e tickGrowth.
        var recurring: [(FinanceCategory, String, CashCertainty, Int)] = [
            (.tv, "Cotas de TV", .contracted, projectedAmount(.tv, tvIncomePerMatchDay)),
            (.wages, "Folha salarial", .contracted, -(wageBill / perSeason)),
            (.staff, "Comissão técnica", .contracted, -(staff.reduce(0) { $0 + $1.wage } / perSeason)),
            (.members, "Sócios-torcedores", .estimated, projectedAmount(.members, Int(Double(members) * 1.4 / 100) * 100)),
            (.merchandise, "Loja do clube", .estimated, baseMerchRevenuePerMatchDay)
        ]
        // Coleção à venda: o extra só vale nos dias que faltam do projeto.
        let collection = activeCollection
        let collectionDaysLeft = collection.map { $0.brief.size.matchDays - $0.dailySales.count } ?? 0
        let collectionExtraToday = collection.map { collectionExtra($0.brief) } ?? 0
        let levels = trainingCenterLevel + medicalLevel + youthAcademyLevel + stadiumLevel
        let upkeep = Int(Double(club.startingBudget) * 0.004 * Double(levels) / Double(perSeason) / 100) * 100
        recurring.append((.facilities, "Manutenção da estrutura", .contracted, -upkeep))
        if let deal = sponsorDeal {
            recurring.append((.sponsor, "Patrocínio \(deal.sponsor)", .contracted, projectedAmount(.sponsor, deal.fixedPerSeason / perSeason)))
        }
        if let deal = world.business.naming {
            recurring.append((.naming, "Naming rights \(deal.sponsor)", .contracted, deal.perSeason / perSeason))
        }
        for deal in world.growth.slotDeals {
            recurring.append((.sponsor, "Cota \(deal.slot.title): \(deal.sponsor)", .contracted, projectedAmount(.sponsor, deal.perSeason / perSeason)))
        }
        if let delegation = world.commercial.delegation, delegation.clubID == selectedClubID {
            recurring.append((.marketing, "Gerente comercial", .contracted, -delegationFeePerMatchDay))
        }
        for program in world.business.programs {
            recurring.append((.community, program.title, .contracted, -(program.costPerSeason / perSeason)))
        }

        var lines: [String: CashProjectionLine] = [:]
        func add(_ category: FinanceCategory, _ title: String, _ certainty: CashCertainty, _ amount: Int, due: Int? = nil) {
            guard amount != 0 else { return }
            let line = CashProjectionLine(category: category, title: title, certainty: certainty, total: amount, dueMatchDay: due)
            if let existing = lines[line.id] {
                lines[line.id] = CashProjectionLine(category: category, title: title, certainty: certainty, total: existing.total + amount, dueMatchDay: due)
            } else {
                lines[line.id] = line
            }
        }

        var days: [CashProjectionDay] = []
        var contractedBalance = transferBudget
        var expectedBalance = transferBudget
        for offset in 0..<count {
            let matchDay = matchDayIndex + offset
            var contracted = 0
            var estimated = 0

            // Bilheteria: lançada no dia da partida em casa (estimativa pela demanda atual).
            let homeFixture = fixtures.first { $0.matchDay == matchDay && $0.home == selectedClubID && !$0.isPlayed }
            if let homeFixture {
                let gate = projectedAmount(.gate, gateRevenue(attendance: attendance(for: homeFixture)))
                estimated += gate
                add(.gate, "Bilheteria", .estimated, gate)
            }
            for (category, title, certainty, amount) in recurring {
                if certainty == .contracted { contracted += amount } else { estimated += amount }
                add(category, title, certainty, amount)
            }
            if let collection, offset < collectionDaysLeft {
                estimated += collectionExtraToday
                add(.merchandise, "Vendas extras: \(collection.name)", .estimated, collectionExtraToday)
            }
            // Juros: cobrados quando o caixa fica negativo depois das receitas e custos do dia.
            let beforeInterest = expectedBalance + contracted + estimated
            if beforeInterest < 0 {
                let interest = -Int(Double(-beforeInterest) * 0.02)
                estimated += interest
                add(.interest, "Juros da dívida", .estimated, interest)
            }
            // Parcelas: o índice avança antes do acerto, então este dia quita o que vence até matchDay + 1.
            for payment in pendingPayments {
                let due = payment.dueMatchDay
                let paysToday = offset == 0 ? due <= matchDay + 1 : due == matchDay + 1
                guard paysToday else { continue }
                contracted -= payment.amount
                add(.playerPurchases, payment.note, .contracted, -payment.amount, due: due)
            }
            contractedBalance += contracted
            expectedBalance += contracted + estimated
            days.append(CashProjectionDay(matchDay: matchDay, contracted: contracted, estimated: estimated,
                                          contractedBalance: contractedBalance, expectedBalance: expectedBalance,
                                          hasHomeMatch: homeFixture != nil))
        }
        let sorted = lines.values.sorted {
            if $0.certainty != $1.certainty { return $0.certainty == .contracted }
            return abs($0.total) > abs($1.total)
        }
        return CashProjection(startingCash: transferBudget, days: days, lines: sorted)
    }

    /// Simula um gasto único hoje e diz se o caixa conservador aguenta o período (base para BAN-03).
    func projectionAfterSpending(_ amount: Int, horizon: Int = defaultProjectionHorizon) -> (projection: CashProjection, lowestContracted: Int) {
        let projection = cashProjection(horizon: horizon)
        let lowest = (projection.days.map(\.contractedBalance).min() ?? projection.startingCash) - amount
        return (projection, min(lowest, projection.startingCash - amount))
    }
}
