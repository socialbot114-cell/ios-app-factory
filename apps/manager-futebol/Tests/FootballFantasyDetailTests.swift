import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballFantasyDetailTests: XCTestCase {
    func testGoalWeightsCleanSheetsAndAssistsForEveryPosition() {
        let career = FootballCareer(seed: 7)
        for (position, goal, clean) in [(FootballPosition.goalkeeper, 15.0, 5.0), (.defender, 12, 4), (.midfielder, 10, 1), (.forward, 8, 0)] {
            let athlete = career.fantasyPool.first { $0.position == position }!
            var fixture = career.fixtures.first { $0.competition.division != nil && $0.involves(athlete.teamID!) }!
            let isHome = fixture.home == athlete.teamID
            fixture.homeGoals = isHome ? 2 : 0
            fixture.awayGoals = isHome ? 0 : 2
            fixture.homeScorerIDs = isHome ? [athlete.id, athlete.id] : []
            fixture.awayScorerIDs = isHome ? [] : [athlete.id, athlete.id]
            fixture.playedIDs = [athlete.id]
            fixture.assistIDs = [athlete.id]
            XCTAssertEqual(career.fantasyPoints(for: athlete, in: fixture), 1 + 2 * goal + 5 + clean + 1)
        }
    }

    func testSharingRespectsExistingCooldownBeforeAnyMutation() throws {
        var career = scoredCareer()
        career.selectedClubID = career.players.first { $0.teamID != nil }!.teamID
        career.world.social.lastPostWorldDay = career.worldDay
        let result = try XCTUnwrap(career.world.fantasy.history.first)
        let before = career.world
        XCTAssertEqual(career.fantasyShareBlockReason(result), "Uma publicação por dia de jogo.")
        XCTAssertNil(career.shareFantasyResult(result))
        XCTAssertEqual(career.world, before)
    }

    private func scoredCareer() -> FootballCareer {
        var career = FootballCareer(seed: 7)
        let lineup = career.suggestedFantasyLineup()
        XCTAssertTrue(career.setFantasyLineup(ids: lineup.ids, captainID: lineup.captainID))
        let day = career.fantasyNextRound!.matchDay
        for index in career.fixtures.indices where career.fixtures[index].matchDay == day && career.fixtures[index].competition.division != nil {
            career.fixtures[index].homeGoals = 2
            career.fixtures[index].awayGoals = 0
            let fixture = career.fixtures[index]
            career.fixtures[index].playedIDs = career.players.filter { fixture.involves($0.teamID ?? -1) }.map(\.id)
        }
        career.scoreFantasyRound(matchDay: day)
        return career
    }

    func testComponentsUseRegisteredEventsAndCaptainMultipliesPenalties() {
        let career = FootballCareer(seed: 7)
        let keeper = career.fantasyPool.first { $0.position == .goalkeeper }!
        var fixture = career.fixtures.first { $0.competition.division != nil && $0.involves(keeper.teamID!) }!
        fixture.homeGoals = 2; fixture.awayGoals = 3
        fixture.playedIDs = [keeper.id]
        fixture.assistIDs = [keeper.id]
        fixture.yellowIDs = [keeper.id]
        fixture.redIDs = [keeper.id]
        let conceded = fixture.home == keeper.teamID ? 3 : 2
        let victory = fixture.away == keeper.teamID ? 1.0 : 0.0
        let expected = 1 + 5 - Double(conceded) - 2 - 5 + victory
        let components = career.fantasyComponents(for: keeper, in: fixture)
        XCTAssertEqual(career.fantasyPoints(for: keeper, in: fixture), expected)
        let detail = FantasyAthleteDetail(id: keeper.id, name: keeper.name, fixtureID: fixture.id,
                                         status: "", components: components, isCaptain: true)
        XCTAssertEqual(detail.points, expected * 1.5)
        fixture.playedIDs = []
        XCTAssertTrue(career.fantasyComponents(for: keeper, in: fixture).isEmpty)
        fixture.homeGoals = nil
        XCTAssertEqual(career.fantasyPoints(for: keeper, in: fixture), 0)
    }

    func testSnapshotSurvivesLineupChangesAndRoundTripAndSettlementIsUnique() throws {
        var career = scoredCareer()
        let detail = try XCTUnwrap(career.fantasyLatestDetail)
        XCTAssertEqual(detail.athletes.count, 11)
        XCTAssertEqual(detail.points, career.world.fantasy.history.first?.points)
        XCTAssertFalse(career.factStore.facts.contains { $0.effects?.contains(where: { $0.hasPrefix("{") }) == true }, "Dados técnicos não devem vazar para os efeitos narrativos")
        let before = career.world.fantasy
        let chips = career.world.betting.fichas
        career.scoreFantasyRound(matchDay: career.fantasyNextRound!.matchDay)
        XCTAssertEqual(career.world.fantasy, before)
        XCTAssertEqual(career.world.betting.fichas, chips)
        career.world.fantasy.lineup = []
        career.world.fantasy.captainID = nil
        XCTAssertEqual(career.fantasyLatestDetail, detail)
        let restored = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(restored.fantasyLatestDetail, detail)
        career.factStore.facts.removeAll()
        XCTAssertNil(career.fantasyLatestDetail, "Never infer an old lineup from the current selection")
    }

    func testPendingFixturesCannotPayAndLeagueConsultationIsPure() throws {
        var career = FootballCareer(seed: 7)
        let lineup = career.suggestedFantasyLineup()
        career.setFantasyLineup(ids: lineup.ids, captainID: lineup.captainID)
        let before = try JSONEncoder().encode(career)
        career.scoreFantasyRound(matchDay: career.fantasyNextRound!.matchDay)
        XCTAssertTrue(career.world.fantasy.history.isEmpty)
        XCTAssertEqual(try JSONDecoder().decode(FootballCareer.self, from: before).world.fantasy, career.world.fantasy)
        let scored = scoredCareer()
        let rows = scored.fantasyParticipants
        XCTAssertEqual(rows.count, 8)
        XCTAssertEqual(rows, scored.fantasyParticipants)
        XCTAssertEqual(Set(rows.map(\.id)).count, 8)
        XCTAssertEqual(rows.filter(\.isUser).first?.lastRoundPoints, scored.world.fantasy.history.first?.points)
        XCTAssertTrue(rows.filter { !$0.isUser }.allSatisfy { $0.lastRoundPoints != nil })
    }

    func testSharingUsesSocialCooldownAndSurvivesRetentionWithoutRewards() throws {
        var career = scoredCareer()
        career.selectedClubID = career.players.first { $0.teamID != nil }!.teamID
        let result = try XCTUnwrap(career.world.fantasy.history.first)
        let chips = career.world.betting.fichas
        let cash = career.world.coach.personalCash
        let fantasy = career.world.fantasy
        let post = try XCTUnwrap(career.shareFantasyResult(result))
        XCTAssertEqual(post.text, career.fantasyShareText(result))
        XCTAssertEqual(post.sourceFactID, "fantasy-result-\(result.id)")
        XCTAssertEqual(post.reliability, "confirmed")
        XCTAssertNotNil(career.canPost(.humor))
        XCTAssertNil(career.shareFantasyResult(result))
        XCTAssertEqual(career.world.betting.fichas, chips)
        XCTAssertEqual(career.world.coach.personalCash, cash)
        XCTAssertEqual(career.world.fantasy, fantasy)
        career.world.social.posts.removeAll()
        career.factStore.facts.removeAll()
        career.world.social.lastPostWorldDay = -1
        var restored = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertNil(restored.shareFantasyResult(result))
    }
}
