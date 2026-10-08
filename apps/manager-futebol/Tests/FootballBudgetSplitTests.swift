import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballBudgetSplitTests: XCTestCase {
    private func entry(_ category: FinanceCategory, _ amount: Int, season: Int = 2) -> FinanceEntry {
        FinanceEntry(season: season, matchDay: 1, category: category, amount: amount, note: "Teste")
    }

    private func summary(_ season: Int, income: Int) -> FinanceSeasonSummary {
        FinanceSeasonSummary(season: season, income: income, expenses: 0, byCategory: [:], closingCash: 0)
    }

    // MARK: BAN-09

    func testTargetsAddUpToTheWholeReference() {
        let buckets = FootballBudgetSplit.buckets(reference: 1_000_000, entries: [])
        XCTAssertEqual(buckets.map(\.target).reduce(0, +), 1_000_000)
        XCTAssertEqual(buckets.map(\.area), [.transfers, .wages, .facilities, .academy])
    }

    func testSpendingOverTheTargetIsOverAndNearTheLimitIsNear() {
        let entries = [
            entry(.playerPurchases, -450_000),
            entry(.wages, -200_000),
            entry(.staff, -100_000),
            entry(.facilities, -10_000)
        ]
        let buckets = FootballBudgetSplit.buckets(reference: 1_000_000, entries: entries)
        let byArea = Dictionary(uniqueKeysWithValues: buckets.map { ($0.area, $0) })
        // Transferências: meta 400 mil, gasto 450 mil.
        XCTAssertTrue(byArea[.transfers]?.isOver ?? false)
        // Folha: meta 350 mil, gasto 300 mil (salários e comissão somados): 86%, perto do limite.
        XCTAssertFalse(byArea[.wages]?.isOver ?? true)
        XCTAssertTrue(byArea[.wages]?.isNear ?? false)
        // Estrutura: meta 100 mil, gasto 10 mil: dentro da meta.
        XCTAssertFalse(byArea[.facilities]?.isOver ?? true)
        XCTAssertFalse(byArea[.facilities]?.isNear ?? true)
    }

    func testIncomeInTheSameCategoryDoesNotCountAsSpending() {
        let buckets = FootballBudgetSplit.buckets(reference: 1_000_000, entries: [entry(.playerPurchases, 300_000)])
        XCTAssertEqual(buckets.first { $0.area == .transfers }?.spent, 0)
    }

    func testReferenceUsesTheLastFinishedSeason() {
        var book = FinanceBook()
        book.add(entry(.gate, 200_000, season: 2))
        let summaries = [summary(1, income: 900_000)]
        XCTAssertEqual(FootballBudgetSplit.reference(summaries: summaries, book: book, currentSeason: 2), 900_000)
    }

    func testFirstSeasonReferenceIsTheCurrentIncomeSoFar() {
        var book = FinanceBook()
        book.add(entry(.gate, 200_000, season: 1))
        book.add(entry(.gate, 50_000, season: 1))
        XCTAssertEqual(FootballBudgetSplit.reference(summaries: [], book: book, currentSeason: 1), 250_000)
    }

    func testNoReferenceMeansNoTargetsAndNoWarnings() {
        let buckets = FootballBudgetSplit.buckets(reference: 0, entries: [entry(.wages, -100)])
        XCTAssertTrue(buckets.allSatisfy { $0.target == 0 })
        XCTAssertFalse(buckets.contains { $0.isOver || $0.isNear })
    }
}
