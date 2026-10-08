import Foundation

// MARK: - Tendências do Banco (BAN-08, parte 2)

/// Receita e despesa de uma temporada, para comparar temporadas lado a lado.
struct FootballSeasonTotal: Identifiable, Equatable {
    let season: Int
    let income: Int
    let expenses: Int

    var id: Int { season }
    var result: Int { income - expenses }
}

/// Séries do Banco para a comparação entre temporadas. Só leitura: não muda lançamentos nem resumos.
enum FootballBankTrends {
    /// Quantas temporadas aparecem na comparação, contando a atual.
    static let seasonLimit = 4

    /// Temporadas encerradas (resumos) mais a atual, lida dos lançamentos quando ela ainda não tem resumo.
    /// Ordem da mais antiga para a mais nova; as mais antigas saem quando passa do limite.
    static func seasonTotals(summaries: [FinanceSeasonSummary], book: FinanceBook, currentSeason: Int) -> [FootballSeasonTotal] {
        var totals = summaries.map { FootballSeasonTotal(season: $0.season, income: $0.income, expenses: $0.expenses) }
        if !summaries.contains(where: { $0.season == currentSeason }) {
            let income = book.income(season: currentSeason)
            let expenses = book.expenses(season: currentSeason)
            if income != 0 || expenses != 0 {
                totals.append(FootballSeasonTotal(season: currentSeason, income: income, expenses: expenses))
            }
        }
        return Array(totals.sorted { $0.season < $1.season }.suffix(seasonLimit))
    }

    /// Cada temporada vira duas barras, receita e despesa, para a comparação lado a lado.
    static func seasonBars(_ totals: [FootballSeasonTotal]) -> [FootballBankBar] {
        totals.flatMap { total in
            [FootballBankBar(id: "s\(total.season)-in", title: "T\(total.season) receita", amount: total.income),
             FootballBankBar(id: "s\(total.season)-out", title: "T\(total.season) despesa", amount: total.expenses)]
        }
    }
}
