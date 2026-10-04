import XCTest
@testable import ManagerFutebol

final class FootballCommitmentTests: XCTestCase {
    private func makeCareer() -> FootballCareer {
        var career = FootballCareer(seed: 26)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    func testPromiseCannotBeRepeatedForMoraleOrDeadline() throws {
        var career = makeCareer()
        let id = try XCTUnwrap(career.clubRoster.first?.id)
        XCTAssertTrue(career.promiseStarts(playerID: id, starts: 2))
        let state = career
        XCTAssertFalse(career.promiseStarts(playerID: id, starts: 3))
        XCTAssertEqual(career, state)
        XCTAssertFalse(career.promiseStarts(playerID: id, starts: 0))
    }

    func testFulfillmentSurvivesSaveAndIsAppliedOnce() throws {
        var career = makeCareer()
        let id = try XCTUnwrap(career.clubRoster.first?.id)
        XCTAssertTrue(career.promiseStarts(playerID: id, starts: 2))
        career.evaluatePromises(started: [id])
        career = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(career.promises.first?.startsDone, 1)
        career.evaluatePromises(started: [id])
        XCTAssertTrue(career.promises.isEmpty)
        let morale = career.player(id)?.morale
        career.evaluatePromises(started: [id])
        XCTAssertEqual(career.player(id)?.morale, morale)
        XCTAssertEqual(career.inbox.filter { $0.sourcePromiseID != nil }.count, 1)
    }

    func testBrokenPromiseHasPersistentOutcome() throws {
        var career = makeCareer()
        let id = try XCTUnwrap(career.clubRoster.first?.id)
        XCTAssertTrue(career.promiseStarts(playerID: id))
        career.matchDayIndex = try XCTUnwrap(career.promises.first?.deadlineMatchDay)
        let confidence = career.boardConfidence
        career.evaluatePromises(started: [])
        XCTAssertTrue(career.promises.isEmpty)
        XCTAssertEqual(career.boardConfidence, confidence - 1)
        XCTAssertEqual(career.inbox.last?.title, "Promessa quebrada")
    }

    func testReadAndRefusalAreIndividualAndIdempotent() throws {
        var career = makeCareer()
        let id = try XCTUnwrap(career.clubRoster.first?.id)
        career.addInbox(.playerPlayingTime, title: "Pedido", body: "Quero jogar", playerID: id)
        career.addInbox(.general, title: "Outra", body: "Notícia")
        let request = try XCTUnwrap(career.inbox.first { $0.title == "Pedido" }?.id)
        career.markMessageRead(id: request)
        XCTAssertFalse(try XCTUnwrap(career.inbox.last).isRead)
        career.dismissRequest(playerID: id)
        let morale = career.player(id)?.morale
        career.dismissRequest(playerID: id)
        XCTAssertEqual(career.player(id)?.morale, morale)
        XCTAssertNotNil(career.inbox.first { $0.id == request }?.coachReply)
    }
}
