import Foundation

/// Valores hipotéticos; nunca registra lançamentos nem executa uma contratação.
struct FootballBudgetScenario: Equatable {
    var upfront = 0
    var annualWage = 0
    var installmentAmount = 0
    var installmentCount = 0

    func projection(for career: FootballCareer, horizon: Int) -> CashProjection {
        var copy = career
        copy.transferBudget -= max(0, upfront)
        // A folha é arredondada depois de somar todos os salários, como no motor.
        if let clubID = copy.selectedClubID,
           let index = copy.players.firstIndex(where: { $0.teamID == clubID }) {
            copy.players[index].contract.wage += max(0, annualWage)
        }
        // Mercado: parcelas a cada dois dias, liquidadas após avançar o índice.
        for step in 1...max(1, min(12, installmentCount)) where step <= installmentCount {
            copy.pendingPayments.append(PendingPayment(id: -step, amount: max(0, installmentAmount),
                dueMatchDay: copy.matchDayIndex + step * 2, season: copy.season,
                note: "Simulação: parcela \(step)"))
        }
        return copy.cashProjection(horizon: horizon)
    }

    static func minimum(_ projection: CashProjection, expected: Bool) -> Int {
        min(projection.startingCash, projection.days.map {
            expected ? $0.expectedBalance : $0.contractedBalance
        }.min() ?? projection.startingCash)
    }
}
