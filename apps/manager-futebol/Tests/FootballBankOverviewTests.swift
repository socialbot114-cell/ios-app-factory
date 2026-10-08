import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballBankOverviewTests: XCTestCase {
    private func career() -> FootballCareer {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(3))
        career.finance = FinanceBook()
        career.transferBudget = 3_000_000
        return career
    }

    /// Partida 1 cai no mês 1; partidas 5 e 9 caem nos meses 2 e 3 (quatro partidas por mês).
    private func post(_ career: inout FootballCareer, matchDay: Int, amount: Int) {
        career.finance.add(FinanceEntry(season: career.season, matchDay: matchDay,
                                        category: amount > 0 ? .gate : .wages, amount: amount, note: "Teste"))
    }

    // MARK: BAN-07

    func testEmptySeasonHasNoBreathAndNoTrend() {
        let overview = career().bankOverview
        XCTAssertEqual(overview.balance, 3_000_000)
        XCTAssertNil(overview.monthsOfBreath)
        XCTAssertNil(overview.incomeChange)
        XCTAssertNil(overview.expenseChange)
        XCTAssertEqual(overview.monthIncome, 0)
        XCTAssertEqual(overview.monthExpenses, 0)
    }

    func testLastMonthAndTrendComeFromMonthReports() {
        var career = career()
        post(&career, matchDay: 1, amount: 500_000)
        post(&career, matchDay: 1, amount: -200_000)
        post(&career, matchDay: 5, amount: 800_000)
        post(&career, matchDay: 5, amount: -300_000)
        let overview = career.bankOverview
        XCTAssertEqual(overview.monthIncome, 800_000)
        XCTAssertEqual(overview.monthExpenses, 300_000)
        XCTAssertEqual(overview.incomeChange, 300_000)
        XCTAssertEqual(overview.expenseChange, 100_000)
    }

    func testBreathUsesAverageOfRecentMonths() {
        var career = career()
        for matchDay in [1, 5, 9] { post(&career, matchDay: matchDay, amount: -1_000_000) }
        // Três meses de despesa de 1 milhão contra 3 milhões de caixa: três meses de fôlego.
        XCTAssertEqual(career.bankOverview.monthsOfBreath ?? -1, 3, accuracy: 0.0001)
    }

    func testNegativeBalanceIsCritical() {
        var career = career()
        career.transferBudget = -500_000
        XCTAssertEqual(career.bankOverview.risk, .critical)
    }

    func testLessThanOneMonthOfBreathIsCritical() {
        var career = career()
        career.transferBudget = 500_000
        post(&career, matchDay: 1, amount: -1_000_000)
        XCTAssertEqual(career.bankOverview.monthsOfBreath ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(career.bankOverview.risk, .critical)
    }
}
