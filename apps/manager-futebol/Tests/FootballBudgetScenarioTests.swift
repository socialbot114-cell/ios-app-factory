import XCTest
@testable import ManagerFutebol

final class FootballBudgetScenarioTests: XCTestCase {
    private func career() -> FootballCareer {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    func testZeroScenarioIsIdentityAndPureAcrossDifficulties() {
        var career = career()
        for difficulty in [Difficulty.easy, .normal, .hard] {
            career.difficulty = difficulty
            let before = career
            XCTAssertEqual(FootballBudgetScenario().projection(for: career, horizon: 8), career.cashProjection(horizon: 8))
            XCTAssertEqual(career, before)
        }
    }

    func testUpfrontMinimumReconcilesWithExistingSpendingAPI() {
        let career = career()
        let amount = career.transferBudget + 1_000_000
        let scenario = FootballBudgetScenario(upfront: amount)
        let projection = scenario.projection(for: career, horizon: 8)
        XCTAssertEqual(FootballBudgetScenario.minimum(projection, expected: false),
                       career.projectionAfterSpending(amount).lowestContracted)
        XCTAssertTrue(projection.lines.contains { $0.category == .interest && $0.total < 0 })
        XCTAssertEqual(projection.startingCash, career.transferBudget - amount)
    }

    func testSalaryAndInstallmentsReconcileWithEngineAndRemainPure() throws {
        let original = career()
        let snapshot = original
        let scenario = FootballBudgetScenario(upfront: 123_456, annualWage: 777_777,
                                              installmentAmount: 234_567, installmentCount: 2)
        let projection = scenario.projection(for: original, horizon: 4)
        XCTAssertEqual(original, snapshot)
        var engine = original
        engine.transferBudget -= scenario.upfront
        let index = try XCTUnwrap(engine.players.firstIndex { $0.teamID == engine.selectedClubID })
        engine.players[index].contract.wage += scenario.annualWage
        engine.pendingPayments.append(PendingPayment(id: -1, amount: scenario.installmentAmount,
            dueMatchDay: engine.matchDayIndex + 2, season: engine.season, note: "Simulação: parcela 1"))
        engine.pendingPayments.append(PendingPayment(id: -2, amount: scenario.installmentAmount,
            dueMatchDay: engine.matchDayIndex + 4, season: engine.season, note: "Simulação: parcela 2"))
        XCTAssertEqual(projection, engine.cashProjection(horizon: 4))
        let start = engine.finance.entries.count
        XCTAssertTrue(engine.beginMatchDay())
        XCTAssertTrue(engine.finishMatchDay())
        let actualWages = engine.finance.entries.dropFirst(start).filter { $0.category == .wages }.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(actualWages, -(original.wageBill + scenario.annualWage) / FootballSeason.matchDaysPerSeason)
        XCTAssertEqual(projection.lines.filter { $0.title.hasPrefix("Simulação:") }.reduce(0) { $0 + $1.total }, -2 * scenario.installmentAmount)
        XCTAssertEqual(projection.days[0].contracted - original.cashProjection(horizon: 4).days[0].contracted,
                       -((original.wageBill + scenario.annualWage) / FootballSeason.matchDaysPerSeason - original.wageBill / FootballSeason.matchDaysPerSeason))
        XCTAssertEqual(projection.endingExpected - projection.startingCash, projection.lines.reduce(0) { $0 + $1.total })
        XCTAssertTrue(engine.beginMatchDay())
        XCTAssertTrue(engine.finishMatchDay())
        XCTAssertFalse(engine.pendingPayments.contains { $0.id == -1 })
        XCTAssertTrue(engine.pendingPayments.contains { $0.id == -2 })
        for _ in 0..<2 {
            // Dias de copa sem o clube também avançam o caixa e os vencimentos.
            XCTAssertTrue(engine.simulateNextMatchDay())
        }
        XCTAssertFalse(engine.pendingPayments.contains { $0.id == -2 })
    }

    func testBoundsEmptySeasonAndPaymentsOutsideHorizon() {
        var career = career()
        let negative = FootballBudgetScenario(upfront: -100, annualWage: -100, installmentAmount: -100, installmentCount: -2)
        XCTAssertEqual(negative.projection(for: career, horizon: 4), career.cashProjection(horizon: 4))
        let scenario = FootballBudgetScenario(upfront: 100, installmentAmount: 500, installmentCount: 2)
        XCTAssertFalse(scenario.projection(for: career, horizon: 1).lines.contains { $0.title.hasPrefix("Simulação:") })
        career.matchDayIndex = FootballSeason.matchDaysPerSeason
        let end = scenario.projection(for: career, horizon: 100)
        XCTAssertTrue(end.days.isEmpty)
        XCTAssertEqual(FootballBudgetScenario.minimum(end, expected: true), career.transferBudget - 100)
        XCTAssertTrue(scenario.projection(for: FootballCareer(seed: 1), horizon: 8).days.isEmpty)
        XCTAssertTrue(scenario.projection(for: career, horizon: -1).days.isEmpty)
    }
}
