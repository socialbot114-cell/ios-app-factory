import Foundation
import XCTest
@testable import ManagerFutebol

/// Nenhuma semente testada tem decisões pendentes suficientes para o meio da semana.
private struct NoMidweekFound: Error {}

final class FootballMidweekTests: XCTestCase {
    private func started(seed: Int = 26, club: Int = 0) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    /// Carreira numa rodada em que a semana já pede o meio da semana. Anda pela temporada até achar, sem forçar o estado.
    private func careerWithMidweek() throws -> FootballCareer {
        for seed in 1...12 {
            var career = started(seed: seed)
            while !career.isSeasonComplete {
                if career.midweekNeeded { return career }
                guard career.simulateNextMatchDay() else { break }
            }
        }
        throw NoMidweekFound()
    }

    /// A semana é variável: nem toda rodada pede o meio da semana, nem nenhuma. Medido em seis temporadas.
    func testMidweekIsVariableAcrossTheSeason() {
        var needed = 0
        var weeks = 0
        for seed in 1...6 {
            var career = started(seed: seed)
            while !career.isSeasonComplete {
                weeks += 1
                if career.midweekNeeded { needed += 1 }
                guard career.simulateNextMatchDay() else { break }
            }
        }
        let share = Double(needed) / Double(max(1, weeks))
        XCTAssertTrue((0.2...0.8).contains(share), "Fração de semanas com meio da semana: \(share)")
    }

    func testRestOnlyWorksInsideAnOpenMidweekAndOncePerOpening() {
        var career = started()
        XCTAssertFalse(career.restTeam())
        career.midweek = MidweekState(key: career.midweekKey, opened: true)
        for index in career.players.indices where career.players[index].teamID == career.selectedClubID {
            career.players[index].condition = 50
        }
        let energy = career.world.coach.energy
        XCTAssertTrue(career.restTeam())
        XCTAssertEqual(career.world.coach.energy, min(100, energy + FootballCareer.midweekRestEnergy))
        let squad = career.players.filter { $0.teamID == career.selectedClubID }
        XCTAssertFalse(squad.isEmpty)
        XCTAssertTrue(squad.allSatisfy { $0.condition == 50 + FootballCareer.midweekRestCondition })
        XCTAssertFalse(career.restTeam(), "Descansar vale uma vez por abertura")
    }

    func testMidweekBelongsToOneRoundOnly() {
        var career = started()
        career.midweek = MidweekState(key: career.midweekKey, opened: true)
        XCTAssertTrue(career.midweekOpen)
        career.closeMidweek()
        XCTAssertFalse(career.midweekOpen)
        career.matchDayIndex += 1
        XCTAssertFalse(career.midweekOpen)
    }

    func testARoundWithPendingDecisionsWaitsForTheMidweekBeforeTheMatch() throws {
        var career = try careerWithMidweek()
        XCTAssertTrue(career.midweekWaiting)
        XCTAssertTrue(career.canPlay, "O motor joga quando é chamado; quem espera é a interface")
        XCTAssertTrue(career.openMidweek())
        XCTAssertFalse(career.midweekWaiting)
        XCTAssertTrue(career.midweekOpen)
    }

    /// O avanço rápido para antes do jogo quando a semana pede o meio da semana.
    func testFastForwardStopsBeforeTheRoundWhileTheMidweekIsPending() throws {
        var career = try careerWithMidweek()
        let stopped = career.simulateUntilDecision(maxDays: 5)
        XCTAssertEqual(stopped.days, 0)
        XCTAssertTrue(stopped.reason.hasPrefix("Meio da semana"))
        XCTAssertTrue(career.openMidweek())
        XCTAssertFalse(career.midweekWaiting)
    }

    func testMidweekStateSurvivesASave() throws {
        var career = try careerWithMidweek()
        XCTAssertTrue(career.openMidweek())
        let data = try JSONEncoder().encode(career)
        let loaded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertTrue(loaded.midweekOpen)
        XCTAssertFalse(loaded.midweekWaiting)
    }

    func testSavesWithoutTheMidweekFieldLoadWithTheRoundPending() throws {
        let career = started()
        let data = try JSONEncoder().encode(career)
        var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        object.removeValue(forKey: "midweek")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let loaded = try JSONDecoder().decode(FootballCareer.self, from: legacy)
        XCTAssertNil(loaded.midweek)
        XCTAssertFalse(loaded.midweekOpen)
    }
}
