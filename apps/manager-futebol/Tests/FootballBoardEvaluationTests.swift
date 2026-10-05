import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballBoardEvaluationTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    func testFrontsReactToTheirOwnCauses() {
        var career = career()
        career.transferBudget = 30_000_000
        let healthy = career.boardEvaluation
        career.transferBudget = -3_000_000
        let indebted = career.boardEvaluation
        XCTAssertLessThan(indebted.financial.score, healthy.financial.score, "Dívida pesa só na financeira")
        XCTAssertEqual(indebted.sporting.score, healthy.sporting.score)
        XCTAssertTrue(indebted.financial.reasons.contains { $0.hasPrefix("Caixa negativo") })
        XCTAssertEqual(indebted.weakest.title, "Financeira")

        career.transferBudget = 30_000_000
        career.fanMood = 90
        let happy = career.boardEvaluation.institutional.score
        career.fanMood = 10
        career.world.social.crisis = SocialCrisis(kind: .fakeNews, title: "Boato", body: "x", matchDay: career.matchDayIndex)
        let angry = career.boardEvaluation.institutional
        XCTAssertLessThan(angry.score, happy)
        XCTAssertTrue(angry.reasons.contains("Crise de imagem em aberto"))
    }

    func testSportingFrontFollowsTableAndForm() {
        var career = career()
        for _ in 0..<6 { XCTAssertTrue(career.simulateNextMatchDay()) }
        let evaluation = career.boardEvaluation
        XCTAssertTrue(evaluation.sporting.reasons.contains { $0.contains("lugar") })
        XCTAssertTrue(evaluation.sporting.reasons.contains { $0.hasPrefix("Últimos") })
        XCTAssertTrue((0...100).contains(evaluation.sporting.score))
        XCTAssertEqual(evaluation.fronts.count, 3)
    }
}
