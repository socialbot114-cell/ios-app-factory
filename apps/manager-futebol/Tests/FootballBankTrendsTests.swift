import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballBankTrendsTests: XCTestCase {
    private func summary(_ season: Int, income: Int, expenses: Int) -> FinanceSeasonSummary {
        FinanceSeasonSummary(season: season, income: income, expenses: expenses, byCategory: [:], closingCash: 0)
    }

    private func makeBook(season: Int, income: Int, expenses: Int) -> FinanceBook {
        var book = FinanceBook()
        book.add(FinanceEntry(season: season, matchDay: 1, category: .gate, amount: income, note: "Teste"))
        book.add(FinanceEntry(season: season, matchDay: 1, category: .wages, amount: -expenses, note: "Teste"))
        return book
    }

    // MARK: BAN-08 (parte 2)

    func testSeasonTotalsUsesClosedSeasonsAndAddsTheCurrentOneFromEntries() {
        var book = makeBook(season: 3, income: 500, expenses: 200)
        book.summaries = [summary(1, income: 1_000, expenses: 400), summary(2, income: 900, expenses: 700)]
        let totals = FootballBankTrends.seasonTotals(summaries: book.summaries, book: book, currentSeason: 3)
        XCTAssertEqual(totals.map(\.season), [1, 2, 3])
        XCTAssertEqual(totals.map(\.income), [1_000, 900, 500])
        XCTAssertEqual(totals.map(\.expenses), [400, 700, 200])
        XCTAssertEqual(totals.last?.result, 300)
    }

    func testTheCurrentSeasonIsNotCountedTwiceWhenItAlreadyHasASummary() {
        var book = makeBook(season: 3, income: 500, expenses: 200)
        book.summaries = [summary(3, income: 800, expenses: 100)]
        let totals = FootballBankTrends.seasonTotals(summaries: book.summaries, book: book, currentSeason: 3)
        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals.first?.income, 800, "Vale o resumo fechado, não os lançamentos")
    }

    func testOnlyTheLastSeasonsAreShown() {
        var book = makeBook(season: 6, income: 100, expenses: 50)
        book.summaries = (1...5).map { summary($0, income: 100 * $0, expenses: 50 * $0) }
        let totals = FootballBankTrends.seasonTotals(summaries: book.summaries, book: book, currentSeason: 6)
        XCTAssertEqual(totals.map(\.season), [3, 4, 5, 6])
    }

    func testAnEmptyCurrentSeasonIsLeftOut() {
        var book = FinanceBook()
        book.summaries = [summary(1, income: 1_000, expenses: 400)]
        let totals = FootballBankTrends.seasonTotals(summaries: book.summaries, book: book, currentSeason: 2)
        XCTAssertEqual(totals.map(\.season), [1])
    }

    func testEachSeasonBecomesAnIncomeAndAnExpenseBar() {
        let bars = FootballBankTrends.seasonBars([FootballSeasonTotal(season: 2, income: 900, expenses: 700)])
        XCTAssertEqual(bars.map(\.title), ["T2 receita", "T2 despesa"])
        XCTAssertEqual(bars.map(\.amount), [900, 700])
    }
}
