import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballConstructionTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.transferBudget = 40_000_000
        return career
    }

    func testStagesArePaidAlongTheWorkAndProjected() throws {
        var career = career()
        let cost = try XCTUnwrap(career.upgradeCost(for: .trainingCenter))
        XCTAssertTrue(career.startUpgrade(.trainingCenter))
        let plan = try XCTUnwrap(career.constructionPlan)
        XCTAssertEqual(plan.stageCosts.reduce(0, +), cost)
        XCTAssertEqual(plan.stagesPaid, 1)
        let projection = career.cashProjection(horizon: 20)
        let projected = projection.lines.filter { $0.title.hasPrefix("Obra:") }.reduce(0) { $0 + $1.total }
        XCTAssertEqual(projected, -(cost - plan.stageCosts[0]), "Etapas restantes aparecem como compromisso")
        let duration = career.upgradeDuration(for: .trainingCenter)
        for _ in 0..<duration { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertNil(career.upgradeProject)
        XCTAssertNil(career.constructionPlan)
        let paid = career.finance.entries.filter { $0.note.hasPrefix("Obra: \(FacilityKind.trainingCenter.title)") }
        XCTAssertEqual(paid.count, 3)
        XCTAssertEqual(paid.reduce(0) { $0 + $1.amount }, -cost)
    }

    func testWorkStopsWithoutCashAndDeadlineMoves() throws {
        var career = career()
        XCTAssertTrue(career.startUpgrade(.medical))
        let due = try XCTUnwrap(career.upgradeProject).dueMatchDay
        career.transferBudget = 0
        let secondOffset = try XCTUnwrap(career.constructionPlan).stageOffsets[1]
        for _ in 0..<(secondOffset + 1) { XCTAssertTrue(career.simulateNextMatchDay()) }
        career.transferBudget = min(career.transferBudget, 0)
        XCTAssertTrue(career.simulateNextMatchDay())
        let plan = try XCTUnwrap(career.constructionPlan)
        XCTAssertGreaterThan(plan.pausedDays, 0)
        XCTAssertGreaterThan(try XCTUnwrap(career.upgradeProject).dueMatchDay, due, "Prazo anda com a paralisação")
        XCTAssertTrue(career.inbox.contains { $0.title == "Obra parada" })
    }

    func testWorkHasImpactWhileRunning() throws {
        var career = career()
        let fixture = try XCTUnwrap(career.fixtures.first { $0.home == 3 && $0.competition.division != nil })
        career.fanMood = 100
        career.fanBase = career.stadiumCapacity * 3
        let before = career.attendance(for: fixture)
        let training = career.trainingFacilityFactor
        XCTAssertTrue(career.startUpgrade(.stadium))
        XCTAssertLessThan(career.attendance(for: fixture), before, "Setor fechado durante a obra")
        XCTAssertEqual(career.trainingFacilityFactor, training, "Obra no estádio não mexe no treino")
        XCTAssertFalse(career.constructionImpact(for: .stadium).isEmpty)
    }

    func testSimulationShowsTheEffectBeforeCommitting() throws {
        let career = career()
        let scenario = career.upgradeScenario(.stadium)
        XCTAssertEqual(scenario.reduce(0) { $0 + $1.amount }, career.upgradeCost(for: .stadium))
        let result = career.simulate(scenario, horizon: 20)
        XCTAssertLessThan(result.after.endingContracted, result.before.endingContracted)
        XCTAssertEqual(result.before.endingContracted - result.after.endingContracted, scenario.reduce(0) { $0 + $1.amount })
        XCTAssertEqual(career, career, "Simular não muda a carreira")

        let signing = career.signingScenario(fee: 3_000_000, installments: 3, wagePerSeason: 1_200_000)
        let signed = career.simulate(signing, horizon: 8)
        let total = signing.filter { $0.worldDay <= career.worldDay + 8 }.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(signed.before.endingContracted - signed.after.endingContracted, total)
    }

    func testOldSavesWithoutPlanStillLoadAndFinish() throws {
        var career = career()
        XCTAssertTrue(career.startUpgrade(.youthAcademy))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(json["world"] as? [String: Any])
        var projects = try XCTUnwrap(world["projects"] as? [String: Any])
        projects.removeValue(forKey: "construction")
        world["projects"] = projects
        json["world"] = world
        var decoded = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.constructionPlan, "Obra antiga sem plano segue a regra antiga")
        for _ in 0..<decoded.upgradeDuration(for: .youthAcademy) { XCTAssertTrue(decoded.simulateNextMatchDay()) }
        XCTAssertNil(decoded.upgradeProject)
    }
}
