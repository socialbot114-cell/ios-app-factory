import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballBankBreakdownTests: XCTestCase {
    private func entry(_ category: FinanceCategory, _ amount: Int) -> FinanceEntry {
        FinanceEntry(season: 1, matchDay: 1, category: category, amount: amount, note: "Teste")
    }

    // MARK: BAN-08 (parte 1)

    func testIncomeSumsPositiveEntriesByCategoryAndSortsDescending() {
        let bars = FootballBankBreakdown.income([
            entry(.gate, 300_000), entry(.gate, 200_000), entry(.sponsor, 400_000), entry(.wages, -900_000)
        ])
        XCTAssertEqual(bars.map(\.amount), [500_000, 400_000])
        XCTAssertEqual(bars.map(\.title), ["Bilheteria", "Patrocínio"])
    }

    func testExpensesUseAbsoluteValuesAndIgnoreIncome() {
        let bars = FootballBankBreakdown.expenses([
            entry(.wages, -700_000), entry(.staff, -100_000), entry(.gate, 900_000), entry(.wages, -200_000)
        ])
        XCTAssertEqual(bars.map(\.title), ["Salários", "Comissão técnica"])
        XCTAssertEqual(bars.map(\.amount), [900_000, 100_000])
    }

    func testTiesAreOrderedByCategoryNameSoTheChartDoesNotJump() {
        let bars = FootballBankBreakdown.income([entry(.tv, 100), entry(.gate, 100)])
        XCTAssertEqual(bars.map(\.id), ["gate", "tv"])
    }

    func testMoreThanTheLimitFoldsTheTailIntoOther() {
        let entries: [FinanceEntry] = [
            entry(.gate, 900), entry(.members, 800), entry(.tv, 700), entry(.sponsor, 600),
            entry(.prize, 500), entry(.merchandise, 400), entry(.naming, 300), entry(.community, 200)
        ]
        let bars = FootballBankBreakdown.income(entries)
        XCTAssertEqual(bars.count, FootballBankBreakdown.visibleLimit + 1)
        XCTAssertEqual(bars.last?.title, "Outros")
        XCTAssertEqual(bars.last?.amount, 300 + 200)
        XCTAssertEqual(bars.reduce(0) { $0 + $1.amount }, 900 + 800 + 700 + 600 + 500 + 400 + 300 + 200, "Nada se perde ao agrupar")
    }

    func testEmptyEntriesGiveNoBars() {
        XCTAssertTrue(FootballBankBreakdown.income([]).isEmpty)
        XCTAssertTrue(FootballBankBreakdown.expenses([]).isEmpty)
    }
}
