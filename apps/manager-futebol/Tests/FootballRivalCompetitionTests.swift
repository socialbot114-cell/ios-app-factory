import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballRivalCompetitionTests: XCTestCase {
    /// Carreira no começo da janela do meio do ano, com os melhores atletas de outros clubes na lista de observação.
    private func careerInWindow(seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(3))
        career.transferBudget = 80_000_000
        while career.matchDayIndex < TransferWindow.midseason.start, career.simulateNextMatchDay() {}
        XCTAssertTrue(career.isTransferWindowOpen)
        career.watchlist = career.players.filter { $0.teamID != nil && $0.teamID != career.selectedClubID && !$0.onLoan && !$0.isYouth }
            .sorted { $0.overall > $1.overall }.prefix(12).map(\.id)
        return career
    }

    private func careerWithRace(seed: Int = 7) throws -> FootballCareer {
        for attempt in 0..<6 {
            var career = careerInWindow(seed: seed + attempt * 11)
            career.progressTransferRaces()
            if !career.openTransferRaces.isEmpty { return career }
        }
        throw XCTSkip("Nenhuma disputa aberta nas sementes testadas")
    }

    func testRaceOpensWithRumorCommitmentAndLimit() throws {
        let career = try careerWithRace()
        XCTAssertLessThanOrEqual(career.openTransferRaces.count, FootballCareer.maxOpenRaces)
        let race = try XCTUnwrap(career.openTransferRaces.first)
        XCTAssertNotEqual(race.rivalID, race.sellerID)
        XCTAssertNotEqual(race.rivalID, career.selectedClubID)
        XCTAssertLessThanOrEqual(race.deadlineWorldDay, (career.season - 1) * FootballSeason.matchDaysPerSeason + TransferWindow.midseason.end,
                                 "Prazo dentro da janela")
        let fact = try XCTUnwrap(career.fact(race.factID))
        XCTAssertEqual(fact.reliability, .rumor)
        XCTAssertTrue(career.inbox.contains { $0.sourceFactID == race.factID })
        XCTAssertTrue(career.world.social.posts.contains { $0.sourceFactID == race.factID })
        let commitment = try XCTUnwrap(career.commitments.first { $0.id == race.commitmentID })
        XCTAssertEqual(commitment.kind, .transferRace)
        XCTAssertEqual(commitment.state, .open)
        XCTAssertTrue(career.agenda.contains { $0.id == "commitment-\(race.commitmentID)" }, "Prazo aparece na agenda")

        var again = career
        again.progressTransferRaces()
        XCTAssertEqual(again.transferRaces.filter { $0.playerID == race.playerID }.count, 1, "Uma disputa por atleta por temporada")
    }

    func testSigningFirstWinsTheRace() throws {
        var career = try careerWithRace()
        let race = try XCTUnwrap(career.openTransferRaces.first)
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == race.playerID })
        career.players[index].teamID = career.selectedClubID
        career.resolveTransferRaces()
        XCTAssertEqual(career.transferRaces.first { $0.id == race.id }?.status, .userWon)
        XCTAssertEqual(career.commitments.first { $0.id == race.commitmentID }?.state, .fulfilled)
        XCTAssertNotNil(career.fact("\(race.factID)-won"))
    }

    func testRivalSigningMovesPlayerAndSuggestsAlternativesOnce() throws {
        var career = try careerWithRace()
        let race = try XCTUnwrap(career.openTransferRaces.first)
        let index = try XCTUnwrap(career.transferRaces.firstIndex { $0.id == race.id })
        let athlete = try XCTUnwrap(career.player(race.playerID))
        career.completeRivalSigning(raceIndex: index, athlete: athlete)
        let done = try XCTUnwrap(career.transferRaces.first { $0.id == race.id })
        XCTAssertEqual(done.status, .rivalWon)
        XCTAssertEqual(career.player(race.playerID)?.teamID, race.rivalID)
        XCTAssertFalse(career.watchlist.contains(race.playerID))
        XCTAssertTrue(career.transferLog.contains { $0.playerID == race.playerID })
        for id in done.alternativeIDs {
            let alternative = try XCTUnwrap(career.player(id))
            XCTAssertEqual(alternative.position, athlete.position)
            XCTAssertNotEqual(alternative.teamID, career.selectedClubID)
        }
        XCTAssertEqual(career.fact("\(race.factID)-lost")?.reliability, .confirmed)
        XCTAssertEqual(career.memories(of: race.playerID).filter { $0.kind == .lostToRival }.count, 1, "Atleta lembra da sondagem")
        let messages = career.inbox.filter { $0.sourceFactID == "\(race.factID)-lost" }.count
        career.resolveTransferRaces()
        XCTAssertEqual(career.inbox.filter { $0.sourceFactID == "\(race.factID)-lost" }.count, messages, "Desfecho entregue uma vez")
    }

    func testDeadlineResolvesInsideTheWindowAndClosingWindowEndsRaces() throws {
        var career = try careerWithRace()
        let race = try XCTUnwrap(career.openTransferRaces.first)
        while career.worldDay < race.deadlineWorldDay, career.simulateNextMatchDay() {}
        let resolved = try XCTUnwrap(career.transferRaces.first { $0.id == race.id })
        XCTAssertTrue([.rivalWon, .rivalGaveUp, .userWon, .cancelled].contains(resolved.status), "Resolvida no prazo, não pela janela")

        var other = try careerWithRace(seed: 19)
        other.matchDayIndex = TransferWindow.midseason.end + 1
        other.resolveTransferRaces()
        XCTAssertTrue(other.openTransferRaces.isEmpty)
        XCTAssertTrue(other.transferRaces.allSatisfy { $0.status == .windowClosed || !$0.isOpen })
    }

    func testClubChangeCancelsRacesAndOldSavesLoad() throws {
        var career = try careerWithRace()
        let race = try XCTUnwrap(career.openTransferRaces.first)
        XCTAssertTrue(career.resign())
        let job = try XCTUnwrap(career.jobOffers.first { $0.id != race.rivalID })
        XCTAssertTrue(career.acceptJob(job.id))
        XCTAssertTrue(career.openTransferRaces.isEmpty)
        XCTAssertEqual(career.commitments.first { $0.id == race.commitmentID }?.state, .cancelled)

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(json["world"] as? [String: Any])
        var projects = try XCTUnwrap(world["projects"] as? [String: Any])
        projects.removeValue(forKey: "transferRaces")
        projects.removeValue(forKey: "nextRaceID")
        world["projects"] = projects
        json["world"] = world
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.transferRaces.isEmpty)
    }
}
