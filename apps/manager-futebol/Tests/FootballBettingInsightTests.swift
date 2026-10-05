import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballBettingInsightTests: XCTestCase {
    private func career() -> FootballCareer {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    private func neutralFixture(_ career: FootballCareer) throws -> LeagueFixture {
        try XCTUnwrap(career.bettingFixtures.first { !$0.involves(0) && $0.competition.division == .serieA })
    }

    func testBriefingUsesOnlyPublicFacts() throws {
        var career = career()
        let fixture = try neutralFixture(career)
        let index = try XCTUnwrap(career.players.firstIndex { $0.teamID == fixture.home })
        career.players[index].injuryRounds = 2
        let briefing = career.fixtureBriefing(fixture)
        XCTAssertEqual(briefing.home.teamID, fixture.home)
        XCTAssertTrue(briefing.home.absences.contains { $0.contains(career.players[index].name) })
        XCTAssertEqual(briefing.headToHead.meetings, 0)
        XCTAssertTrue(briefing.home.form.isEmpty)
    }

    func testDraftRestoresOnlyOpenMarkets() throws {
        var career = career()
        let fixture = try neutralFixture(career)
        let option = try XCTUnwrap(career.options(for: fixture).first)
        let stale = BetLeg(fixtureID: -5, market: .draw, a: 0, b: 0, odds: 3, description: "antigo")
        career.saveBettingDraft(legs: [option.leg, stale], stake: 70)
        let encoded = try JSONEncoder().encode(career.world)
        let restoredWorld = try JSONDecoder().decode(WorldState.self, from: encoded)
        XCTAssertEqual(restoredWorld.betting.draft?.legs.count, 2)
        let restored = career.restoredBettingDraft()
        XCTAssertEqual(restored.draft?.legs, [option.leg])
        XCTAssertEqual(restored.draft?.stake, 70)
        XCTAssertEqual(restored.dropped, 1)
        career.saveBettingDraft(legs: [], stake: 50)
        XCTAssertNil(career.world.betting.draft)
        XCTAssertTrue(career.bettingClosingText(for: fixture).hasPrefix("Fecha"))
    }

    func testSettlementNoteExplainsRealResult() throws {
        var career = career()
        let fixture = try neutralFixture(career)
        let leg = try XCTUnwrap(career.options(for: fixture).first { $0.leg.market == .homeWin }).leg
        XCTAssertEqual(career.settlementNote(for: leg), "Aguardando o jogo.")
        let index = try XCTUnwrap(career.fixtures.firstIndex { $0.id == fixture.id })
        career.fixtures[index].homeGoals = 2
        career.fixtures[index].awayGoals = 1
        var won = leg
        won.won = true
        let note = career.settlementNote(for: won)
        XCTAssertTrue(note.contains("2 × 1") && note.contains("acertada"), note)
    }

    func testTipsterHistoryAccumulatesAndProfilesAreComparable() {
        var career = career()
        career.ensureTipsters()
        career.recordTipsterPicks()
        career.matchDayIndex += 1
        career.recordTipsterPicks()
        XCTAssertTrue(career.world.betting.tipsters.allSatisfy { $0.picks == 2 * FootballCareer.tipsterPicksPerRound })
        XCTAssertTrue(career.world.betting.tipsters.allSatisfy { ($0.hits ?? -1) >= 0 && ($0.hits ?? 99) <= ($0.picks ?? 0) })
        let profiles = career.tipsterProfiles
        XCTAssertEqual(profiles.count, career.world.betting.tipsters.count + 1)
        XCTAssertEqual(profiles.filter(\.isUser).count, 1)
        XCTAssertNil(profiles.first(where: \.isUser)?.hitRate, "Sem bilhetes liquidados não há taxa")
    }

    func testFichasStayApartFromPersonalCashAndClubBudget() throws {
        var career = career()
        let fixture = try neutralFixture(career)
        let leg = try XCTUnwrap(career.options(for: fixture).first).leg
        let cash = career.world.coach.personalCash
        let budget = career.transferBudget
        let fichas = career.world.betting.fichas
        XCTAssertNotNil(career.placeBet(stake: 50, legs: [leg]))
        XCTAssertEqual(career.world.betting.fichas, fichas - 50)
        let index = try XCTUnwrap(career.fixtures.firstIndex { $0.id == fixture.id })
        career.fixtures[index].homeGoals = 0
        career.fixtures[index].awayGoals = 3
        career.settleBets()
        XCTAssertEqual(career.world.coach.personalCash, cash)
        XCTAssertEqual(career.transferBudget, budget)
        // Liquidar de novo não paga nem desconta outra vez.
        let after = career.world.betting
        career.settleBets()
        XCTAssertEqual(career.world.betting, after)
        XCTAssertTrue(FootballCareer.bettingRoleText.contains("opcional"))
    }
}
