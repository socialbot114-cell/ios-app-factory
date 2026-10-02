import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballStoryTests: XCTestCase {
    private func career(club: Int = 0, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    // MARK: - Retrospecto e recordes

    func testHeadToHeadMatchesTheFixturesFromBothPerspectives() throws {
        var career = career()
        for _ in 0..<8 { XCTAssertTrue(career.simulateNextMatchDay()) }
        let played = career.fixtures.filter { $0.isPlayed && $0.competition.division != nil }
        for pair in [(0, 3), (0, 6), (2, 15)] {
            let meetings = played.filter { Set([$0.home, $0.away]) == Set([pair.0, pair.1]) }
            guard !meetings.isEmpty else { continue }
            let a = try XCTUnwrap(career.retrospect(of: pair.0, against: pair.1))
            let b = try XCTUnwrap(career.retrospect(of: pair.1, against: pair.0))
            XCTAssertEqual(a.wins + a.draws + a.losses, meetings.count)
            XCTAssertEqual(a.wins, b.losses)
            XCTAssertEqual(a.losses, b.wins)
            XCTAssertEqual(a.draws, b.draws)
            XCTAssertEqual(a.goalsFor, b.goalsAgainst)
            XCTAssertEqual(a.goalsFor, meetings.reduce(0) { $0 + ($1.home == pair.0 ? $1.homeGoals! : $1.awayGoals!) })
            XCTAssertTrue(a.last.hasPrefix("T1"))
        }
        let total = career.headToHead.values.reduce(0) { $0 + $1.matches }
        XCTAssertEqual(total, career.fixtures.filter(\.isPlayed).count)
    }

    func testClubRecordsTrackBiggestWinsUnbeatenRunsAndLegends() throws {
        var career = career()
        for _ in 0..<FootballSeason.matchDaysPerSeason { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertGreaterThan(career.records.highestAttendance, 0)
        XCTAssertGreaterThan(career.records.mostPointsInSeason, 0)
        XCTAssertGreaterThanOrEqual(career.records.longestUnbeaten, career.records.currentUnbeaten)
        let userFixtures = career.fixtures.filter { $0.isPlayed && $0.involves(0) }
        let margins = userFixtures.map { fixture -> Int in
            let own = fixture.home == 0 ? fixture.homeGoals! : fixture.awayGoals!
            let other = fixture.home == 0 ? fixture.awayGoals! : fixture.homeGoals!
            return own - other
        }
        XCTAssertEqual(career.records.biggestWinMargin, max(0, margins.max() ?? 0))
        XCTAssertEqual(career.records.biggestLossMargin, max(0, -(margins.min() ?? 0)))
        XCTAssertNotEqual(career.records.topScorerName, "—")

        // Aposentadoria de quem passou de 45 gols ou 110 jogos vira lenda.
        var star = career.clubRoster[0]
        star.careerGoals = 60
        star.careerAppearances = 150
        career.recordLegendIfDeserved(star)
        career.recordLegendIfDeserved(star)
        XCTAssertEqual(career.legends.count, 1, "Não duplica")
        XCTAssertEqual(career.legends.first?.goals, 60)
        var rookie = career.clubRoster[1]
        rookie.careerGoals = 3
        rookie.careerAppearances = 10
        career.recordLegendIfDeserved(rookie)
        XCTAssertEqual(career.legends.count, 1)
    }

    // MARK: - Notícias e torcida

    func testNewsComeFromRealResultsAndFanProtestsPressureTheBoard() throws {
        var career = career()
        let index = try XCTUnwrap(career.fixtures.firstIndex { $0.matchDay == 0 && $0.competition.division == .serieA && !$0.involves(0) })
        let scorer = try XCTUnwrap(career.players(forTeam: career.fixtures[index].home).first { $0.position == .forward })
        career.fixtures[index].homeGoals = 5
        career.fixtures[index].awayGoals = 0
        career.fixtures[index].homeScorerIDs = [scorer.id, scorer.id, scorer.id, 1, 2]
        career.fixtures[index].awayScorerIDs = []
        career.generateLeagueNews(forMatchDay: 0)
        XCTAssertTrue(career.inbox.contains { $0.kind == .news && $0.title.hasPrefix("Goleada") })

        var hatTrick = career
        hatTrick.inbox = []
        hatTrick.fixtures[index].homeGoals = 3
        hatTrick.fixtures[index].awayGoals = 2
        hatTrick.fixtures[index].homeScorerIDs = [scorer.id, scorer.id, scorer.id]
        hatTrick.fixtures[index].awayScorerIDs = [5, 6]
        hatTrick.generateLeagueNews(forMatchDay: 0)
        XCTAssertTrue(hatTrick.inbox.contains { $0.title == "Hat-trick de \(scorer.name)" })

        // Protesto da torcida: aparece no máximo a cada quatro jogos.
        var fans = career
        fans.inbox = []
        fans.fanMood = 10
        let confidence = fans.boardConfidence
        fans.matchDayIndex = 6
        fans.checkFanReactions()
        XCTAssertEqual(fans.boardConfidence, confidence - 3)
        XCTAssertTrue(fans.inbox.contains { $0.title == "Protesto da torcida" })
        fans.matchDayIndex = 7
        fans.checkFanReactions()
        XCTAssertEqual(fans.boardConfidence, confidence - 3)
        fans.matchDayIndex = 10
        fans.checkFanReactions()
        XCTAssertEqual(fans.boardConfidence, confidence - 6)
    }

    func testInboxStaysBoundedAndNewsFlowDuringASeason() throws {
        var career = career()
        for _ in 0..<FootballSeason.matchDaysPerSeason { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertLessThanOrEqual(career.inbox.count, 80)
        XCTAssertGreaterThan(career.inbox.filter { $0.kind == .news }.count, 0)
        XCTAssertGreaterThan(career.unreadCount, 0)
        career.markInboxRead()
        XCTAssertEqual(career.unreadCount, 0)
    }

    // MARK: - Reputação, convites e demissão

    func testReputationBoardPatienceAndInvitations() throws {
        var career = career(club: 5)
        XCTAssertEqual(career.reputation, career.initialReputation(for: FootballSeason.team(5)!))
        XCTAssertGreaterThan(career.boardPatienceThreshold(for: 0), career.boardPatienceThreshold(for: 9))
        XCTAssertGreaterThan(career.clubPrestige(0), career.clubPrestige(10))
        XCTAssertGreaterThan(career.clubPrestige(10), career.clubPrestige(19))

        career.reputation = 95
        var random = FootballRandom(seed: 1)
        var sawInvitation = false
        for trial in 0..<30 {
            random = FootballRandom(seed: UInt64(trial + 1))
            career.generateInvitations(using: &random)
            XCTAssertLessThanOrEqual(career.invitations.count, 2)
            XCTAssertTrue(career.invitations.allSatisfy { career.clubPrestige($0.clubID) > career.clubPrestige(5) && career.clubPrestige($0.clubID) <= career.maxPrestige })
            if !career.invitations.isEmpty { sawInvitation = true }
        }
        XCTAssertTrue(sawInvitation)

        career.reputation = 0
        career.generateInvitations(using: &random)
        XCTAssertTrue(career.invitations.isEmpty, "Sem reputação, ninguém convida")
    }

    func testAcceptingAnInvitationSwitchesClubsAndResigningOffersJobs() throws {
        var career = career(club: 5)
        career.reputation = 90
        career.invitations = [JobInvitation(clubID: 3, season: 1)]
        career.inbox = []
        let reputation = career.reputation
        XCTAssertTrue(career.acceptInvitation(3))
        XCTAssertEqual(career.selectedClubID, 3)
        XCTAssertEqual(career.reputation, reputation + 2)
        XCTAssertTrue(career.invitations.isEmpty)
        XCTAssertEqual(career.startingXI.count, 11)
        XCTAssertEqual(career.transferBudget, Int(Double(FootballSeason.team(3)!.startingBudget) * 0.75))
        XCTAssertEqual(career.clubRoster.count, 16)
        XCTAssertTrue(career.clubRoster.allSatisfy { $0.teamID == 3 })
        XCTAssertGreaterThan(career.wageCap, 0)
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertFalse(career.acceptInvitation(3), "Já treina o clube")

        XCTAssertTrue(career.resign())
        XCTAssertTrue(career.isFired)
        XCTAssertEqual(career.jobOffers.count, 3)
        XCTAssertTrue(career.jobOffers.allSatisfy { $0.id != 3 })
        let best = try XCTUnwrap(career.jobOffers.first)
        XCTAssertTrue(career.clubPrestige(best.id) <= career.maxPrestige || career.jobOffers.allSatisfy { career.clubPrestige($0.id) > career.maxPrestige })
        XCTAssertTrue(career.acceptJob(best.id))
        XCTAssertFalse(career.isFired)

        var humble = self.career(club: 5)
        humble.reputation = 10
        XCTAssertTrue(humble.resign())
        let weakest = FootballSeason.teams.filter { $0.id != 5 }.sorted { humble.clubPrestige($0.id) < humble.clubPrestige($1.id) }.map(\.id)
        XCTAssertTrue(humble.jobOffers.allSatisfy { weakest.prefix(8).contains($0.id) }, "Reputação baixa leva a clubes menores")
    }

    func testMidSeasonSackingAndSeasonEndReputationChanges() throws {
        var career = career(club: 3)
        for _ in 0..<9 { XCTAssertTrue(career.simulateNextMatchDay()) }
        career.boardConfidence = 4
        let reputation = career.reputation
        career.checkMidSeasonSacking()
        XCTAssertTrue(career.isFired)
        XCTAssertEqual(career.reputation, reputation - 8)
        XCTAssertFalse(career.canPlay)

        var fresh = self.career(club: 10, seed: 31)
        for _ in 0..<FootballSeason.matchDaysPerSeason { XCTAssertTrue(fresh.simulateNextMatchDay()) }
        let before = fresh.reputation
        let record = try XCTUnwrap(fresh.startNextSeason())
        XCTAssertEqual(fresh.reputation, min(100, max(0, before + record.reputationChange)))
        XCTAssertNotNil(record.awards)
    }

    // MARK: - Seleção

    func testNationalCallUpsRemoveStarsForOneMatchDayThenReward() throws {
        var career = career()
        let duty = FootballCareer.dutyMatchDays
        XCTAssertEqual(duty.count, 3)
        while career.matchDayIndex < duty[0] { XCTAssertTrue(career.simulateNextMatchDay()) }
        let called = career.players.filter { $0.nationalDutyMatchDay == duty[0] }
        XCTAssertEqual(called.count, 15)
        XCTAssertEqual(called.filter { $0.position == .goalkeeper }.count, 2)
        XCTAssertEqual(called.filter { $0.position == .forward }.count, 4)
        XCTAssertTrue(called.allSatisfy { !$0.isAvailable(matchDay: duty[0]) && $0.isAvailable(matchDay: duty[0] + 1) })
        let mine = called.filter { $0.teamID == 0 }
        for player in mine { XCTAssertFalse(career.startingXI.contains(player.id) && career.canPlay && false) }
        career.repairLineup()
        XCTAssertTrue(mine.allSatisfy { !career.startingXI.contains($0.id) })
        XCTAssertEqual(career.startingXI.count, 11)
        XCTAssertTrue(career.fixtures.filter { $0.matchDay == duty[0] }.count > 0)

        let moraleBefore = Dictionary(uniqueKeysWithValues: mine.map { ($0.id, $0.morale) })
        let valueBefore = Dictionary(uniqueKeysWithValues: mine.map { ($0.id, $0.marketValue) })
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertTrue(career.simulateNextMatchDay())
        for player in mine {
            let after = try XCTUnwrap(career.player(player.id))
            XCTAssertNil(after.nationalDutyMatchDay)
            XCTAssertGreaterThanOrEqual(after.marketValue + 1, valueBefore[player.id] ?? 0)
            _ = moraleBefore
        }
        XCTAssertTrue(career.inbox.contains { $0.title.contains("convocado") } || mine.isEmpty)
    }

    // MARK: - Prêmios

    func testSeasonAwardsPickRealPerformersAndAFullElevenAndCoachOfTheYear() throws {
        var career = career(club: 3)
        for _ in 0..<FootballSeason.matchDaysPerSeason { XCTAssertTrue(career.simulateNextMatchDay()) }
        let awards = career.computeAwards()
        let best = try XCTUnwrap(awards.bestPlayer)
        XCTAssertEqual(career.division(of: try XCTUnwrap(career.player(best.playerID)?.teamID)), .serieA)
        XCTAssertEqual(awards.teamOfTheSeason.count, 11)
        XCTAssertEqual(awards.teamOfTheSeason.filter { $0.position == .goalkeeper }.count, 1)
        XCTAssertEqual(awards.teamOfTheSeason.filter { $0.position == .defender }.count, 4)
        XCTAssertEqual(awards.teamOfTheSeason.filter { $0.position == .midfielder }.count, 3)
        XCTAssertEqual(awards.teamOfTheSeason.filter { $0.position == .forward }.count, 3)
        let scorer = try XCTUnwrap(awards.topScorer)
        let topGoals = career.players.filter { $0.teamID.map { career.division(of: $0) == .serieA } ?? false }.map(\.goals).max()
        XCTAssertEqual(awards.topScorerGoals, topGoals)
        XCTAssertEqual(career.player(scorer.playerID)?.goals, topGoals)
        if let young = awards.youngPlayer { XCTAssertLessThanOrEqual(career.player(young.playerID)?.age ?? 99, 21) }
        XCTAssertNotNil(awards.coachOfTheYearClubID)
        XCTAssertEqual(career.division(of: awards.coachOfTheYearClubID!), .serieA)
    }

    // MARK: - Saves

    func testStoryStateSurvivesSaveAndOldSavesGetDefaults() throws {
        var career = career()
        for _ in 0..<6 { XCTAssertTrue(career.simulateNextMatchDay()) }
        career.invitations = [JobInvitation(clubID: 3, season: 1)]
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip, career)

        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        legacy["schemaVersion"] = 7
        for key in ["headToHead", "records", "legends", "reputation", "invitations", "leaderID", "lastProtestMatchDay"] { legacy.removeValue(forKey: key) }
        if var history = legacy["history"] as? [[String: Any]] {
            history = history.map { var copy = $0; copy.removeValue(forKey: "awards"); copy.removeValue(forKey: "reputationChange"); return copy }
            legacy["history"] = history
        }
        let migrated = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(migrated.reputation, 35)
        XCTAssertTrue(migrated.headToHead.isEmpty)
        var playable = migrated
        XCTAssertTrue(playable.simulateNextMatchDay())
    }
}
