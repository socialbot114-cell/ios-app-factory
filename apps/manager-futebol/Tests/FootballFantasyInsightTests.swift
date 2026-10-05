import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballFantasyInsightTests: XCTestCase {
    func testDeadlineAndOutlookOnFreshCareer() {
        let career = FootballCareer(seed: 7)
        XCTAssertNotNil(career.fantasyNextRound)
        XCTAssertNotNil(career.fantasyDeadlineText)
        let athlete = career.fantasyPool.first { !$0.isInjured && !$0.isSuspended && $0.condition >= FootballCareer.fantasyDoubtCondition }!
        let outlook = career.fantasyOutlook(for: athlete)
        XCTAssertEqual(outlook.risk, .none)
        XCTAssertNotNil(outlook.opponentID)
        XCTAssertEqual(outlook.form, 0)
    }

    func testInjuredAthleteIsFlaggedOutAndFilteredByRisk() {
        var career = FootballCareer(seed: 7)
        let index = career.players.firstIndex { $0.teamID != nil && !$0.isYouth && !$0.onLoan }!
        career.players[index].injuryRounds = 3
        let injured = career.players[index]
        XCTAssertEqual(career.fantasyOutlook(for: injured).risk, .out)
        let safe = career.fantasyFilteredPool(position: injured.position, filter: FantasyFilter(maxRisk: .doubt))
        XCTAssertFalse(safe.contains { $0.playerID == injured.id })
        let all = career.fantasyFilteredPool(position: injured.position, filter: FantasyFilter())
        XCTAssertTrue(all.contains { $0.playerID == injured.id })
    }

    func testPriceFilterAndCaptainOrdering() {
        var career = FootballCareer(seed: 7)
        let cheap = career.fantasyFilteredPool(position: .forward, filter: FantasyFilter(maxPrice: 6))
        XCTAssertTrue(cheap.allSatisfy { $0.price <= 6 })
        let suggestion = career.suggestedFantasyLineup()
        XCTAssertTrue(career.setFantasyLineup(ids: suggestion.ids, captainID: suggestion.captainID))
        let ordered = career.fantasyCaptainComparison(ids: suggestion.ids)
        XCTAssertEqual(ordered.count, 11)
        XCTAssertTrue(zip(ordered, ordered.dropFirst()).allSatisfy { $0.risk <= $1.risk })
    }

    func testDraftPersistsAndSavingClearsIt() throws {
        var career = FootballCareer(seed: 7)
        let suggestion = career.suggestedFantasyLineup()
        career.saveFantasyDraft(ids: Array(suggestion.ids.prefix(5)), captainID: nil)
        let data = try JSONEncoder().encode(career.world)
        let restored = try JSONDecoder().decode(WorldState.self, from: data)
        XCTAssertEqual(restored.fantasy.draft?.lineup.count, 5)
        XCTAssertEqual(career.fantasyWorkingLineup.lineup.count, 5)
        XCTAssertTrue(career.setFantasyLineup(ids: suggestion.ids, captainID: suggestion.captainID))
        XCTAssertNil(career.world.fantasy.draft)
        XCTAssertEqual(career.fantasyWorkingLineup.lineup, suggestion.ids)
        career.saveFantasyDraft(ids: [], captainID: nil)
        XCTAssertNil(career.world.fantasy.draft)
    }
}
