import Foundation

// MARK: - Orçamento da temporada por área (BAN-09)

/// Uma área do orçamento de gasto: a meta da temporada e quanto já foi gasto nela.
struct FootballBudgetBucket: Identifiable, Equatable {
    enum Area: String, CaseIterable {
        case transfers, wages, facilities, academy

        var title: String {
            switch self {
            case .transfers: return "Transferências"
            case .wages: return "Folha"
            case .facilities: return "Estrutura"
            case .academy: return "Base"
            }
        }

        /// Parte da referência do orçamento, em porcentagem. As quatro somam 100.
        var sharePercent: Int {
            switch self {
            case .transfers: return 40
            case .wages: return 35
            case .facilities: return 10
            case .academy: return 15
            }
        }

        /// Categorias de lançamento que gastam esta área.
        var categories: [FinanceCategory] {
            switch self {
            case .transfers: return [.playerPurchases]
            case .wages: return [.wages, .staff]
            case .facilities: return [.facilities]
            case .academy: return [.academy]
            }
        }
    }

    let area: Area
    let target: Int
    let spent: Int

    var id: String { area.rawValue }
    /// Passou da meta.
    var isOver: Bool { target > 0 && spent > target }
    /// Chegou a 80% da meta, sem passar dela.
    var isNear: Bool { !isOver && target > 0 && spent * 5 >= target * 4 }
}

/// Divide a referência do orçamento entre as áreas. Só leitura: não registra gasto nem muda contrato.
enum FootballBudgetSplit {
    /// Referência: a receita da última temporada encerrada. Na primeira temporada, a receita da atual até agora.
    static func reference(summaries: [FinanceSeasonSummary], book: FinanceBook, currentSeason: Int) -> Int {
        if let last = summaries.filter({ $0.season < currentSeason }).max(by: { $0.season < $1.season }) {
            return last.income
        }
        return book.income(season: currentSeason)
    }

    /// Metas e gastos das quatro áreas. `entries` são os lançamentos da temporada atual.
    static func buckets(reference: Int, entries: [FinanceEntry]) -> [FootballBudgetBucket] {
        FootballBudgetBucket.Area.allCases.map { area in
            let spent = entries
                .filter { $0.amount < 0 && area.categories.contains($0.category) }
                .reduce(0) { $0 - $1.amount }
            return FootballBudgetBucket(area: area, target: max(0, reference) * area.sharePercent / 100, spent: spent)
        }
    }
}
