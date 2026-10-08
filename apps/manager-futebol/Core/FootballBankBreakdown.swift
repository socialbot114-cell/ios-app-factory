import Foundation

// MARK: - Quebra do Banco por categoria (BAN-08, parte 1)

/// Uma barra do gráfico de categorias: o total do período para uma origem ou categoria.
struct FootballBankBar: Identifiable, Equatable {
    let id: String
    let title: String
    let amount: Int
}

/// Monta as barras de receita por origem e de despesa por categoria. Só leitura: não muda lançamentos.
enum FootballBankBreakdown {
    /// Quantas categorias aparecem antes de "Outros", para o gráfico continuar legível.
    static let visibleLimit = 6

    /// Receitas (valores positivos) somadas por categoria, da maior para a menor.
    static func income(_ entries: [FinanceEntry]) -> [FootballBankBar] {
        bars(entries.filter { $0.amount > 0 }, sign: 1)
    }

    /// Despesas (valores negativos) somadas por categoria, em valor absoluto, da maior para a menor.
    static func expenses(_ entries: [FinanceEntry]) -> [FootballBankBar] {
        bars(entries.filter { $0.amount < 0 }, sign: -1)
    }

    private static func bars(_ entries: [FinanceEntry], sign: Int) -> [FootballBankBar] {
        var totals: [FinanceCategory: Int] = [:]
        for entry in entries { totals[entry.category, default: 0] += entry.amount * sign }
        // Empate ordena pelo nome da categoria, para a barra não trocar de lugar a cada tela.
        let sorted = totals
            .filter { $0.value > 0 }
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value
            }
            .map { FootballBankBar(id: $0.key.rawValue, title: $0.key.title, amount: $0.value) }
        guard sorted.count > visibleLimit else { return sorted }
        let shown = Array(sorted.prefix(visibleLimit))
        let rest = sorted.dropFirst(visibleLimit).reduce(0) { $0 + $1.amount }
        return shown + [FootballBankBar(id: "other", title: "Outros", amount: rest)]
    }
}
