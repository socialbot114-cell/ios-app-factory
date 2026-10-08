import Foundation

// MARK: - Visão geral do Banco (BAN-07)

/// Números da visão geral do Banco: saldo, fôlego em meses, receitas e despesas do último mês fechado, com tendência e alerta.
/// Só leitura: calcular a visão geral não muda caixa, lançamentos nem relatórios.
struct FootballBankOverview: Equatable {
    enum Risk: Equatable {
        case stable, watch, critical
    }

    /// Caixa disponível do clube.
    let balance: Int
    /// Meses que o caixa cobre no ritmo médio das despesas dos três últimos meses fechados. Nil sem despesa registrada.
    let monthsOfBreath: Double?
    /// Receitas e despesas do último mês fechado.
    let monthIncome: Int
    let monthExpenses: Int
    /// Diferença para o mês anterior. Nil quando há só um mês fechado.
    let incomeChange: Int?
    let expenseChange: Int?
    let risk: Risk
}

extension FootballCareer {
    /// Fôlego abaixo de três meses pede atenção; abaixo de um mês é crítico.
    static let breathWatchMonths: Double = 3
    static let breathCriticalMonths: Double = 1

    var bankOverview: FootballBankOverview {
        let reports = monthReports(season: season)
        let last: MonthReport? = reports.last
        let previous: MonthReport? = reports.count > 1 ? reports[reports.count - 2] : nil
        let recent = reports.suffix(3)
        let recentExpenses = recent.reduce(0) { $0 + $1.expenses }
        let averageExpenses = recent.isEmpty ? 0 : recentExpenses / recent.count
        let breath: Double? = averageExpenses > 0 ? Double(max(0, transferBudget)) / Double(averageExpenses) : nil

        let risk: FootballBankOverview.Risk
        if transferBudget < 0 || (breath ?? .infinity) < Self.breathCriticalMonths {
            risk = .critical
        } else if (breath ?? .infinity) < Self.breathWatchMonths || projectedSeasonEndCash < 0 {
            risk = .watch
        } else {
            risk = .stable
        }

        var incomeChange: Int?
        var expenseChange: Int?
        if let last, let previous {
            incomeChange = last.income - previous.income
            expenseChange = last.expenses - previous.expenses
        }

        return FootballBankOverview(balance: transferBudget,
                                    monthsOfBreath: breath,
                                    monthIncome: last?.income ?? 0,
                                    monthExpenses: last?.expenses ?? 0,
                                    incomeChange: incomeChange,
                                    expenseChange: expenseChange,
                                    risk: risk)
    }
}
