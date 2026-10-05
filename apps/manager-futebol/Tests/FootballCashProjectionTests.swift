import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballCashProjectionTests: XCTestCase {
    private func career(club: Int = 0, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    /// O que a projeção chama de garantido para o próximo dia é exatamente o que o motor lança ao jogá-lo.
    func testFirstProjectedDayReconcilesWithTheBookedMatchDay() throws {
        var career = career()
        let projection = career.cashProjection(horizon: 1)
        let day = try XCTUnwrap(projection.days.first)
        XCTAssertEqual(day.matchDay, career.matchDayIndex)
        let before = career.finance.entries.count
        let season = career.season
        XCTAssertTrue(career.beginMatchDay())
        XCTAssertTrue(career.finishMatchDay())
        let booked = career.finance.entries.dropFirst(before).filter { $0.season == season }
        for category in [FinanceCategory.wages, .staff, .facilities, .tv] {
            let projected = projection.lines.filter { $0.category == category }.reduce(0) { $0 + $1.total }
            let actual = booked.filter { $0.category == category }.reduce(0) { $0 + $1.amount }
            XCTAssertEqual(projected, actual, "Categoria \(category.title) não reconcilia")
        }
        let members = booked.filter { $0.category == .members }.reduce(0) { $0 + $1.amount }
        let projectedMembers = projection.lines.first { $0.category == .members }?.total ?? 0
        XCTAssertEqual(Double(projectedMembers), Double(members), accuracy: Double(max(1, members)) * 0.1, "Sócios: estimativa próxima")
    }

    func testPendingPaymentsAppearOnTheDayTheyAreSettled() throws {
        var career = career()
        let today = career.matchDayIndex
        career.pendingPayments = [
            PendingPayment(id: 1, amount: 300_000, dueMatchDay: today + 1, season: career.season, note: "Parcela A"),
            PendingPayment(id: 2, amount: 500_000, dueMatchDay: today + 3, season: career.season, note: "Parcela B")
        ]
        let projection = career.cashProjection(horizon: 4)
        XCTAssertEqual(projection.lines.first { $0.title == "Parcela A" }?.dueMatchDay, today + 1)
        XCTAssertEqual(projection.lines.first { $0.title == "Parcela B" }?.total, -500_000)
        XCTAssertEqual(projection.committedOutflows <= -800_000, true)
        // A parcela B cai no terceiro dia processado (índice today + 2, que avança para today + 3).
        let withoutB = projection.days[1].contractedBalance - projection.days[2].contractedBalance
        let regular = projection.days[0].contractedBalance - projection.days[1].contractedBalance
        XCTAssertEqual(withoutB - regular, 500_000)

        // O motor quita a parcela A ao processar o primeiro dia, como projetado.
        XCTAssertTrue(career.beginMatchDay())
        XCTAssertTrue(career.finishMatchDay())
        XCTAssertFalse(career.pendingPayments.contains { $0.id == 1 })
        XCTAssertTrue(career.pendingPayments.contains { $0.id == 2 })
    }

    func testProjectionIsPureAndStopsAtSeasonEnd() {
        let career = career()
        let copy = career
        let projection = career.cashProjection(horizon: 500)
        XCTAssertEqual(career, copy, "Consultar a projeção não muda a carreira")
        XCTAssertEqual(projection.horizon, FootballSeason.matchDaysPerSeason - career.matchDayIndex)
        XCTAssertEqual(projection.days.map(\.matchDay), Array(career.matchDayIndex..<FootballSeason.matchDaysPerSeason))
        let homeDays = projection.days.filter(\.hasHomeMatch).count
        XCTAssertGreaterThan(homeDays, 0)
        XCTAssertTrue(projection.lines.contains { $0.category == .gate && $0.certainty == .estimated })
    }

    func testBalancesAccumulateAndConservativeNeverBeatsExpectedIncome() throws {
        let career = career()
        let projection = career.cashProjection()
        var contracted = projection.startingCash
        var expected = projection.startingCash
        for day in projection.days {
            contracted += day.contracted
            expected += day.contracted + day.estimated
            XCTAssertEqual(day.contractedBalance, contracted)
            XCTAssertEqual(day.expectedBalance, expected)
        }
        let total = projection.lines.reduce(0) { $0 + $1.total }
        XCTAssertEqual(projection.endingExpected - projection.startingCash, total, "Linhas somam o mesmo que os dias")
    }

    func testDebtGeneratesEstimatedInterestAndSpendingSimulationWarns() throws {
        var career = career()
        career.transferBudget = -2_000_000
        let projection = career.cashProjection(horizon: 3)
        XCTAssertTrue(projection.lines.contains { $0.category == .interest && $0.total < 0 })
        XCTAssertNotNil(projection.firstContractedShortfall)

        career.transferBudget = 1_000_000
        let simulation = career.projectionAfterSpending(5_000_000)
        XCTAssertLessThan(simulation.lowestContracted, 0, "Gasto acima do caixa aparece como falta")
    }

    func testNoProjectionWithoutClub() {
        let career = FootballCareer(seed: 3)
        XCTAssertTrue(career.cashProjection().days.isEmpty)
    }
}
