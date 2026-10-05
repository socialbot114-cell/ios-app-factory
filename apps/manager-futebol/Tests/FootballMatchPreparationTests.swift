import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballMatchPreparationTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    // MARK: TAC-02

    func testMatchupComparesFitnessRolesAndThreats() throws {
        var career = career()
        for _ in 0..<4 { XCTAssertTrue(career.simulateNextMatchDay()) }
        let report = try XCTUnwrap(career.matchupReport())
        let fixture = try XCTUnwrap(career.nextUserFixture)
        XCTAssertEqual(report.opponentID, fixture.home == career.selectedClubID ? fixture.away : fixture.home)
        XCTAssertTrue((25...100).contains(report.ownFitness))
        XCTAssertEqual(report.rivalKeyPlayers.count, 3)
        XCTAssertNil(report.rivalStyle, "Sem preparação, o estilo do rival é desconhecido")
        XCTAssertTrue(report.suggestions.contains { $0.contains("preparação") })

        career.setOpponentPrep(true)
        XCTAssertNotNil(try XCTUnwrap(career.matchupReport()).rivalStyle)
    }

    func testThreatsAreMarkedObservedOnlyAfterScouting() throws {
        var career = career()
        for _ in 0..<6 { XCTAssertTrue(career.simulateNextMatchDay()) }
        let report = try XCTUnwrap(career.matchupReport())
        for threat in report.threats where threat.id == "scorer" {
            let rivalScorer = try XCTUnwrap(career.players(forTeam: report.opponentID).max { $0.goals < $1.goals })
            XCTAssertEqual(threat.observed, career.scoutKnowledge(of: rivalScorer.id) >= 50)
        }
    }

    // MARK: TAC-03

    func testRotationProjectsFatigueAndSuggestsRecoveryWhenTired() throws {
        var career = career()
        for index in career.players.indices where career.startingXI.contains(career.players[index].id) {
            career.players[index].condition = 62
        }
        let plan = try XCTUnwrap(career.rotationPlan())
        XCTAssertEqual(plan.upcoming.count, 3)
        XCTAssertEqual(plan.suggestedFocus, .recovery)
        XCTAssertTrue(plan.rows.allSatisfy { $0.projectedCondition <= $0.condition })
        XCTAssertTrue(plan.rows.contains { $0.advice.hasPrefix("Poupe") })
    }

    func testPromisedStartsAppearWithTheirDeadline() throws {
        var career = career()
        let reserve = try XCTUnwrap(career.clubRoster.first { !career.startingXI.contains($0.id) && !$0.isYouth })
        career.promises = [PlayerPromise(id: 1, playerID: reserve.id, requiredStarts: 2, startsDone: 0,
                                         deadlineMatchDay: career.matchDayIndex + 1, season: career.season)]
        let plan = try XCTUnwrap(career.rotationPlan())
        let row = try XCTUnwrap(plan.rows.first { $0.playerID == reserve.id })
        XCTAssertEqual(row.promisedStartsLeft, 2)
        XCTAssertTrue(row.advice.contains("promessa"))
        XCTAssertTrue(plan.reasons.contains { $0.contains("promessas") })
    }
}
