import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballBoardMeetingTests: XCTestCase {
    private func career(club: Int = 0, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    private func playDays(_ career: inout FootballCareer, _ count: Int) {
        for _ in 0..<count { XCTAssertTrue(career.simulateNextMatchDay()) }
    }

    func testBudgetRequestIsAnsweredLaterAndPaysOnce() throws {
        var career = career()
        career.boardConfidence = 90
        XCTAssertNil(career.boardMeetingBlocker(.budgetBoost))
        XCTAssertTrue(career.requestBoardMeeting(.budgetBoost))
        XCTAssertFalse(career.requestBoardMeeting(.targetReview), "Um assunto aberto por vez")
        let meeting = try XCTUnwrap(career.openBoardMeeting)
        XCTAssertEqual(meeting.status, .awaitingAnswer)

        playDays(&career, 1)
        XCTAssertEqual(career.openBoardMeeting?.status, .awaitingAnswer, "A resposta não é imediata")
        playDays(&career, 1)
        let answered = try XCTUnwrap(career.boardMeetings.first { $0.id == meeting.id })
        XCTAssertEqual(answered.status, .conditionRunning)
        XCTAssertEqual(answered.amount, career.boardBoostAmount)
        let grants = career.finance.entries.filter { $0.note == "Verba extra da diretoria" }
        XCTAssertEqual(grants.count, 1)
        XCTAssertEqual(grants.first?.amount, answered.amount)

        // Salvar e carregar no meio da condição não perde nem duplica nada.
        let data = try JSONEncoder().encode(career)
        var reloaded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertEqual(reloaded.boardMeetings, career.boardMeetings)
        playDays(&reloaded, 8)
        let settled = try XCTUnwrap(reloaded.boardMeetings.first { $0.id == meeting.id })
        XCTAssertTrue([.conditionMet, .conditionFailed].contains(settled.status))
        let condition = try XCTUnwrap(settled.condition)
        XCTAssertEqual(condition.gamesCounted, condition.games)
        XCTAssertEqual(Set(condition.countedFixtureIDs).count, condition.countedFixtureIDs.count, "Cada jogo conta uma vez")
        XCTAssertEqual(reloaded.finance.entries.filter { $0.note == "Verba extra da diretoria" }.count, 1, "Verba nunca paga duas vezes")
        XCTAssertNil(reloaded.openBoardMeeting)
    }

    func testConditionOutcomeMovesConfidenceBothWays() throws {
        for (wins, expectedStatus, delta) in [(3, BoardMeetingStatus.conditionMet, 4), (2, .conditionFailed, -10)] {
            var career = career()
            career.boardConfidence = 50
            // Condição já completa (seis jogos contados): o próximo avanço apenas liquida.
            let condition = BoardCondition(games: 6, winsNeeded: 3, startMatchDay: 10_000, gamesCounted: 6, winsCounted: wins)
            career.world.projects.meetings = [BoardMeeting(id: 1, clubID: 0, kind: .budgetBoost, season: career.season, requestedWorldDay: 0,
                                                           answerWorldDay: 0, status: .conditionRunning, amount: 1, condition: condition)]
            let before = career.boardConfidence
            career.progressBoardMeetings()
            XCTAssertEqual(career.boardMeetings[0].status, expectedStatus)
            XCTAssertEqual(career.boardConfidence, before + delta)
        }
    }

    func testSeasonTurnSettlesProportionallyAndArchivesPendingRequests() throws {
        var career = career()
        let condition = BoardCondition(games: 6, winsNeeded: 3, startMatchDay: 0, gamesCounted: 2, winsCounted: 1)
        career.world.projects.meetings = [
            BoardMeeting(id: 1, clubID: 0, kind: .budgetBoost, season: career.season, requestedWorldDay: 0, answerWorldDay: 0,
                         status: .conditionRunning, amount: 1, condition: condition),
            BoardMeeting(id: 2, clubID: 0, kind: .targetReview, season: career.season, requestedWorldDay: 0, answerWorldDay: 99)
        ]
        career.closeBoardSeason()
        XCTAssertEqual(career.boardMeetings[0].status, .conditionMet, "1 vitória em 2 jogos cumpre o proporcional (1 de 1)")
        XCTAssertEqual(career.boardMeetings[1].status, .closed)
        XCTAssertNil(career.openBoardMeeting)
    }

    func testRejectionCostsLittleAndCooldownBlocksSpam() throws {
        var career = career()
        career.boardConfidence = 5
        XCTAssertTrue(career.requestBoardMeeting(.budgetBoost))
        XCTAssertEqual(career.boardMood(for: .budgetBoost), "Diretoria resistente")
        let before = career.transferBudget
        playDays(&career, 2)
        let meeting = try XCTUnwrap(career.boardMeetings.last)
        XCTAssertEqual(meeting.status, .rejected)
        XCTAssertFalse(career.finance.entries.contains { $0.note == "Verba extra da diretoria" })
        XCTAssertNotEqual(career.transferBudget, before + career.boardBoostAmount)
        XCTAssertNotNil(career.boardMeetingBlocker(.targetReview), "Novo pedido só depois do intervalo")
        playDays(&career, FootballCareer.boardMeetingCooldown)
        XCTAssertNil(career.boardMeetingBlocker(.targetReview))
    }

    func testTargetReviewLowersAmbitionOnceAtAConfidenceCost() throws {
        var career = career()
        career.boardConfidence = 95
        let target = career.boardTarget
        XCTAssertTrue(career.requestBoardMeeting(.targetReview))
        playDays(&career, 2)
        let meeting = try XCTUnwrap(career.boardMeetings.last)
        XCTAssertEqual(meeting.status, .closed)
        XCTAssertEqual(career.boardTarget, target + 2)
        XCTAssertLessThan(career.boardConfidence, 95)
        playDays(&career, FootballCareer.boardMeetingCooldown)
        XCTAssertEqual(career.boardMeetingBlocker(.targetReview), "A meta desta temporada já foi revista.")
    }

    func testChangingClubClosesOpenMeetings() throws {
        var career = career()
        career.world.projects.meetings = [BoardMeeting(id: 1, clubID: 99, kind: .budgetBoost, season: career.season,
                                                       requestedWorldDay: 0, answerWorldDay: 0)]
        career.progressBoardMeetings()
        XCTAssertEqual(career.boardMeetings[0].status, .closed)
    }

    func testLegacyWorldWithoutProjectsStillLoads() throws {
        let career = career()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(json["world"] as? [String: Any])
        world.removeValue(forKey: "projects")
        json["world"] = world
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.boardMeetings.isEmpty)
        XCTAssertEqual(decoded.world.projects.nextMeetingID, 1)
    }
}
