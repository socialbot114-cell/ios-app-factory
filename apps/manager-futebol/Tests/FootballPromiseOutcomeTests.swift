import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballPromiseOutcomeTests: XCTestCase {
    private func makeCareer(seed: Int = 31) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    private func benchedPlayer(_ career: FootballCareer) throws -> FootballPlayer {
        try XCTUnwrap(career.clubRoster.filter { !career.startingXI.contains($0.id) && !$0.isYouth }.first)
    }

    private func set(_ career: inout FootballCareer, _ id: Int, professionalism: Int? = nil, morale: Int? = nil) throws {
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == id })
        if let professionalism { career.players[index].attributes[.professionalism] = professionalism }
        if let morale { career.players[index].morale = morale }
    }

    func testFulfilledPromiseRaisesMoraleAndAgentRelationOnce() throws {
        var career = makeCareer()
        let id = try benchedPlayer(career).id
        try set(&career, id, professionalism: 12, morale: 50)
        let relation = career.relationship(.agent)
        XCTAssertTrue(career.promiseStarts(playerID: id, starts: 2))
        let afterPromise = career.player(id)?.morale ?? 0
        career.evaluatePromises(started: [id])
        career.evaluatePromises(started: [id])
        XCTAssertTrue(career.promises.isEmpty)
        XCTAssertEqual(career.player(id)?.morale, afterPromise + 8)
        XCTAssertEqual(career.relationship(.agent), min(100, relation + 3))
        let outcome = try XCTUnwrap(career.inbox.last)
        XCTAssertEqual(outcome.title, "Promessa cumprida")
        XCTAssertTrue(outcome.body.contains("“"), "O atleta responde com uma fala")
        let count = career.inbox.count
        career.evaluatePromises(started: [id])
        XCTAssertEqual(career.inbox.count, count, "O veredito não se repete")
    }

    func testPartialPromiseIsSofterThanBroken() throws {
        var career = makeCareer()
        let id = try benchedPlayer(career).id
        try set(&career, id, professionalism: 10)
        XCTAssertTrue(career.promiseStarts(playerID: id, starts: 3))
        career.evaluatePromises(started: [id])
        career.evaluatePromises(started: [id])
        let morale = career.player(id)?.morale ?? 0
        let board = career.boardConfidence
        career.matchDayIndex += 20
        career.evaluatePromises(started: [])
        XCTAssertEqual(career.player(id)?.morale, morale - 8)
        XCTAssertEqual(career.boardConfidence, board, "Cumprir mais da metade não custa a diretoria")
        XCTAssertEqual(career.inbox.last?.title, "Promessa cumprida pela metade")
    }

    func testBrokenPromiseDependsOnProfessionalismAndHitsAgentRelation() throws {
        for (professionalism, expected) in [(4, -22), (10, -18), (16, -12)] {
            var career = makeCareer()
            let id = try benchedPlayer(career).id
            try set(&career, id, professionalism: professionalism, morale: 70)
            XCTAssertTrue(career.promiseStarts(playerID: id))
            let before = career.player(id)?.morale ?? 0
            let relation = career.relationship(.agent)
            let board = career.boardConfidence
            career.matchDayIndex += 20
            career.evaluatePromises(started: [])
            XCTAssertEqual((career.player(id)?.morale ?? 0) - before, expected, "Profissionalismo \(professionalism)")
            XCTAssertEqual(career.boardConfidence, board - 1)
            XCTAssertEqual(career.relationship(.agent), max(0, relation - 6))
            XCTAssertEqual(career.inbox.last?.title, "Promessa quebrada")
        }
    }

    func testInjuredAthleteGetsAnExcusedDeadline() throws {
        var career = makeCareer()
        let id = try benchedPlayer(career).id
        XCTAssertTrue(career.promiseStarts(playerID: id))
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == id })
        career.players[index].injuryRounds = 6
        let before = career.player(id)?.morale ?? 0
        let board = career.boardConfidence
        career.matchDayIndex += 20
        career.evaluatePromises(started: [])
        XCTAssertEqual(career.boardConfidence, board)
        XCTAssertEqual((career.player(id)?.morale ?? 0) - before, -3)
        XCTAssertEqual(career.inbox.last?.title, "Prazo vencido sem culpa")
    }

    func testPublicRepercussionOnlyForStarsWhoFeelCheated() throws {
        var career = makeCareer()
        let star = try XCTUnwrap(career.clubRoster.max { $0.overall < $1.overall })
        try set(&career, star.id, professionalism: 8)
        XCTAssertTrue(career.promiseStarts(playerID: star.id))
        let mood = career.fanMood
        career.matchDayIndex += 20
        career.evaluatePromises(started: [])
        XCTAssertTrue(career.inbox.contains { $0.kind == .news && $0.title.hasPrefix("Bastidores") })
        XCTAssertEqual(career.fanMood, mood - 1)
        XCTAssertEqual(career.inbox.last?.title, "Promessa quebrada")

        var quiet = makeCareer()
        let reserve = try XCTUnwrap(quiet.clubRoster.filter { !quiet.isStar($0) && !$0.isYouth }.first)
        try set(&quiet, reserve.id, professionalism: 8)
        XCTAssertTrue(quiet.promiseStarts(playerID: reserve.id))
        quiet.matchDayIndex += 20
        quiet.evaluatePromises(started: [])
        XCTAssertFalse(quiet.inbox.contains { $0.kind == .news && $0.title.hasPrefix("Bastidores") }, "Reserva não vira notícia")

        var calm = makeCareer()
        let patient = try XCTUnwrap(calm.clubRoster.max { $0.overall < $1.overall })
        try set(&calm, patient.id, professionalism: 16)
        XCTAssertTrue(calm.promiseStarts(playerID: patient.id))
        calm.matchDayIndex += 20
        calm.evaluatePromises(started: [])
        XCTAssertFalse(calm.inbox.contains { $0.kind == .news && $0.title.hasPrefix("Bastidores") }, "Profissional não vaza")
    }

    func testRefusingAndIgnoringARequestHaveDifferentPrices() throws {
        var career = makeCareer()
        let refused = try benchedPlayer(career)
        career.addInbox(.playerPlayingTime, title: "Pedido", body: "Quero jogar", playerID: refused.id)
        let before = career.player(refused.id)?.morale ?? 0
        career.dismissRequest(playerID: refused.id)
        XCTAssertEqual(career.player(refused.id)?.morale, before - 6)
        XCTAssertTrue(career.inbox.last?.isResolved ?? false)

        var ignored = makeCareer()
        let silent = try benchedPlayer(ignored)
        ignored.addInbox(.playerPlayingTime, title: "Pedido", body: "Quero jogar", playerID: silent.id)
        let moraleBefore = ignored.player(silent.id)?.morale ?? 0
        let relation = ignored.relationship(.agent)
        ignored.matchDayIndex += 2
        ignored.escalateIgnoredRequests()
        XCTAssertEqual(ignored.player(silent.id)?.morale, moraleBefore, "Ainda dentro do prazo")
        ignored.matchDayIndex += 1
        ignored.escalateIgnoredRequests()
        XCTAssertEqual(ignored.player(silent.id)?.morale, moraleBefore - 4)
        XCTAssertEqual(ignored.relationship(.agent), max(0, relation - 1))
        ignored.escalateIgnoredRequests()
        XCTAssertEqual(ignored.player(silent.id)?.morale, moraleBefore - 4, "Cobra uma vez só")
        XCTAssertFalse(ignored.inbox.first { $0.title == "Pedido" }?.isResolved ?? true, "O pedido continua aberto")
        XCTAssertNotNil(ignored.inbox.first { $0.title == "Pedido" }?.coachReply)
    }

    func testPromiseAndOutcomeSurviveSaveAndReopen() throws {
        var career = makeCareer()
        let id = try benchedPlayer(career).id
        XCTAssertTrue(career.promiseStarts(playerID: id, starts: 2))
        career.evaluatePromises(started: [id])
        var reopened = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(reopened.promises, career.promises)
        reopened.evaluatePromises(started: [id])
        XCTAssertTrue(reopened.promises.isEmpty)
        XCTAssertEqual(reopened.inbox.last?.title, "Promessa cumprida")
        let again = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(reopened))
        XCTAssertEqual(again.inbox.last?.sourcePromiseID, reopened.inbox.last?.sourcePromiseID)
        XCTAssertTrue(again.promises.isEmpty)
    }
}
