import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballSeasonTests: XCTestCase {
    func testDoubleRoundRobinContainsFourMatchesPerRound() {
        let fixtures = FootballSeason.fixtures()
        XCTAssertEqual(fixtures.count, 56)
        XCTAssertEqual(Set(fixtures.map(\.round)), Set(1...14))
        XCTAssertTrue((1...14).allSatisfy { round in fixtures.filter { $0.round == round }.count == 4 })
        XCTAssertTrue(fixtures.allSatisfy { $0.home != $0.away })
        XCTAssertTrue(fixtures.allSatisfy { !$0.isPlayed })
        for first in 0..<8 {
            for second in (first + 1)..<8 {
                let meetings = fixtures.filter { Set([$0.home, $0.away]) == Set([first, second]) }
                XCTAssertEqual(meetings.count, 2)
                XCTAssertEqual(meetings.filter { $0.home == first }.count, 1)
                XCTAssertEqual(meetings.filter { $0.home == second }.count, 1)
            }
        }
    }

    func testCareerGeneratesCompleteSquadsAndValidFormations() {
        var career = FootballCareer(seed: 7)
        XCTAssertEqual(FootballSeason.teams.count, 8)
        XCTAssertTrue(FootballSeason.teams.allSatisfy { career.players(forTeam: $0.id).count == 16 })
        XCTAssertEqual(career.marketPlayers.count, 12)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertEqual(career.startingXI.count, 11)

        for formation in FootballFormation.allCases {
            career.setFormation(formation)
            XCTAssertEqual(career.startingXI.count, 11)
            let starters = career.startingXI.compactMap { id in career.players.first { $0.id == id } }
            for (position, required) in formation.requiredPlayers {
                XCTAssertEqual(starters.filter { $0.position == position }.count, required)
            }
        }

        let reserve = career.clubRoster.first { !career.startingXI.contains($0.id) }
        XCTAssertNotNil(reserve)
        XCTAssertTrue(career.swapWithStarter(playerID: reserve!.id))
        XCTAssertTrue(career.startingXI.contains(reserve!.id))
        XCTAssertEqual(career.startingXI.count, 11)
    }

    func testRoundResultsAreGeneratedOnceAndStandingsUseRecordedResults() throws {
        var firstCareer = FootballCareer(seed: 7)
        var secondCareer = FootballCareer(seed: 7)
        XCTAssertTrue(firstCareer.chooseClub(0))
        XCTAssertTrue(secondCareer.chooseClub(0))

        XCTAssertTrue(firstCareer.simulateNextRound())
        XCTAssertTrue(secondCareer.simulateNextRound())
        XCTAssertEqual(firstCareer.fixtures, secondCareer.fixtures)
        XCTAssertEqual(firstCareer.currentRound, 1)
        XCTAssertEqual(firstCareer.fixtures.filter(\.isPlayed).count, 4)
        XCTAssertTrue(firstCareer.fixtures.filter { $0.round > 1 }.allSatisfy { !$0.isPlayed })
        XCTAssertEqual(FootballSeason.standings(results: firstCareer.fixtures).reduce(0) { $0 + $1.played }, 8)

        let scoredGoals = firstCareer.fixtures.filter(\.isPlayed).reduce(0) { total, fixture in
            total + (fixture.homeGoals ?? 0) + (fixture.awayGoals ?? 0)
        }
        XCTAssertEqual(firstCareer.players.reduce(0) { $0 + $1.goals }, scoredGoals)

        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(firstCareer))
        XCTAssertEqual(roundTrip, firstCareer)
        XCTAssertEqual(roundTrip.fixtures.filter(\.isPlayed).count, 4)

        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(firstCareer)) as? [String: Any])
        legacyObject.removeValue(forKey: "playStyle")
        legacyObject.removeValue(forKey: "trainingFocus")
        legacyObject.removeValue(forKey: "trainingIntensity")
        legacyObject.removeValue(forKey: "lastTrainingReport")
        legacyObject.removeValue(forKey: "champions")
        if var legacyFixtures = legacyObject["fixtures"] as? [[String: Any]] {
            for index in legacyFixtures.indices {
                legacyFixtures[index].removeValue(forKey: "homeShots")
                legacyFixtures[index].removeValue(forKey: "awayShots")
                legacyFixtures[index].removeValue(forKey: "homePossession")
                legacyFixtures[index].removeValue(forKey: "awayPossession")
            }
            legacyObject["fixtures"] = legacyFixtures
        }
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyCareer = try JSONDecoder().decode(FootballCareer.self, from: legacyData)
        XCTAssertEqual(legacyCareer.playStyle, .balanced)
        XCTAssertEqual(legacyCareer.trainingFocus, .tactical)
        XCTAssertEqual(legacyCareer.trainingIntensity, .balanced)
        XCTAssertNil(legacyCareer.lastTrainingReport)
        XCTAssertEqual(legacyCareer.champions, [])
        XCTAssertNil(legacyCareer.latestUserFixture?.homeShots)

        let suiteName = "FootballCareerTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        firstCareer.persist(defaults: defaults)
        XCTAssertEqual(FootballCareer.load(defaults: defaults), firstCareer)
    }

    func testMarketRequiresAnOpenRosterSlotAndSufficientBudget() {
        var career = FootballCareer(seed: 13)
        XCTAssertTrue(career.chooseClub(0))
        let target = career.marketPlayers.first!
        XCTAssertFalse(career.canSign(playerID: target.id))
        XCTAssertFalse(career.signPlayer(playerID: target.id))

        let reserve = career.clubRoster.first { career.canSell(playerID: $0.id) }
        XCTAssertNotNil(reserve)
        let startingBudget = career.transferBudget
        XCTAssertTrue(career.sellPlayer(playerID: reserve!.id))
        XCTAssertEqual(career.clubRoster.count, 15)
        XCTAssertEqual(career.transferBudget, startingBudget + reserve!.marketValue)

        let signing = career.marketPlayers.first { career.canSign(playerID: $0.id) }
        XCTAssertNotNil(signing)
        XCTAssertTrue(career.signPlayer(playerID: signing!.id))
        XCTAssertEqual(career.clubRoster.count, 16)
        XCTAssertFalse(career.canSign(playerID: career.marketPlayers.first!.id))
    }

    func testPlayStylesChangeFatigueAndRecordMatchReportStats() throws {
        var highPressCareer = FootballCareer(seed: 21)
        var defensiveCareer = FootballCareer(seed: 21)
        XCTAssertTrue(highPressCareer.chooseClub(0))
        XCTAssertTrue(defensiveCareer.chooseClub(0))
        highPressCareer.setPlayStyle(.highPress)
        defensiveCareer.setPlayStyle(.defensive)
        let initialConditions = Dictionary(uniqueKeysWithValues: highPressCareer.clubRoster.map { ($0.id, $0.condition) })

        XCTAssertTrue(highPressCareer.simulateNextRound())
        XCTAssertTrue(defensiveCareer.simulateNextRound())

        for playerID in highPressCareer.startingXI {
            let initial = initialConditions[playerID]!
            let highPressPlayer = highPressCareer.players.first { $0.id == playerID }!
            let defensivePlayer = defensiveCareer.players.first { $0.id == playerID }!
            let trainedCondition = min(100, initial + FootballTrainingIntensity.balanced.conditionRecovery(for: .tactical))
            XCTAssertEqual(highPressPlayer.condition, max(42, trainedCondition - FootballPlayStyle.highPress.fatigueCost))
            XCTAssertEqual(defensivePlayer.condition, max(42, trainedCondition - FootballPlayStyle.defensive.fatigueCost))
        }

        let report = highPressCareer.latestUserFixture!
        let homeGoals = report.homeGoals!
        let awayGoals = report.awayGoals!
        XCTAssertGreaterThanOrEqual(report.homeShots!, homeGoals)
        XCTAssertGreaterThanOrEqual(report.awayShots!, awayGoals)
        XCTAssertEqual(report.homePossession! + report.awayPossession!, 100)
        XCTAssertEqual(report.homeScorerIDs.count, homeGoals)
        XCTAssertEqual(report.awayScorerIDs.count, awayGoals)

        let restored = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(highPressCareer))
        XCTAssertEqual(restored.playStyle, .highPress)
        XCTAssertEqual(restored.latestUserFixture?.id, report.id)
    }

    func testWeeklyTrainingIsDeterministicAndRecoveryFocusRestoresMoreCondition() throws {
        var technicalCareer = FootballCareer(seed: 26)
        var repeatedTechnicalCareer = FootballCareer(seed: 26)
        var recoveryCareer = FootballCareer(seed: 26)
        XCTAssertTrue(technicalCareer.chooseClub(0))
        XCTAssertTrue(repeatedTechnicalCareer.chooseClub(0))
        XCTAssertTrue(recoveryCareer.chooseClub(0))

        technicalCareer.setTrainingFocus(.technical)
        technicalCareer.setTrainingIntensity(.intense)
        repeatedTechnicalCareer.setTrainingFocus(.technical)
        repeatedTechnicalCareer.setTrainingIntensity(.intense)
        recoveryCareer.setTrainingFocus(.recovery)
        recoveryCareer.setTrainingIntensity(.intense)
        let originalPlayers = Dictionary(uniqueKeysWithValues: technicalCareer.clubRoster.map { ($0.id, $0) })

        XCTAssertTrue(technicalCareer.simulateNextRound())
        XCTAssertTrue(repeatedTechnicalCareer.simulateNextRound())
        XCTAssertTrue(recoveryCareer.simulateNextRound())
        XCTAssertEqual(technicalCareer.players, repeatedTechnicalCareer.players)
        XCTAssertEqual(technicalCareer.lastTrainingReport, repeatedTechnicalCareer.lastTrainingReport)
        XCTAssertGreaterThan(
            recoveryCareer.lastTrainingReport!.averageConditionGain,
            technicalCareer.lastTrainingReport!.averageConditionGain
        )

        let developedPlayers = technicalCareer.clubRoster.filter { player in
            player.overall > originalPlayers[player.id]!.overall
        }
        XCTAssertGreaterThan(technicalCareer.lastTrainingReport!.developedPlayers, 0)
        XCTAssertEqual(technicalCareer.lastTrainingReport!.developedPlayers, developedPlayers.count)
        XCTAssertTrue(technicalCareer.clubRoster.allSatisfy { $0.overall <= $0.potential })
        XCTAssertTrue(developedPlayers.allSatisfy { FootballTrainingFocus.technical.developmentPositions.contains($0.position) })

        let restored = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(technicalCareer))
        XCTAssertEqual(restored.trainingFocus, .technical)
        XCTAssertEqual(restored.trainingIntensity, .intense)
        XCTAssertEqual(restored.lastTrainingReport, technicalCareer.lastTrainingReport)
    }

    func testCompletedSeasonHasChampionAndStartsFreshSchedule() {
        var career = FootballCareer(seed: 31)
        XCTAssertTrue(career.chooseClub(3))
        for _ in 0..<14 {
            XCTAssertTrue(career.simulateNextRound())
        }

        XCTAssertTrue(career.isSeasonComplete)
        XCTAssertEqual(career.fixtures.filter(\.isPlayed).count, 56)
        let champion = career.championID
        XCTAssertNotNil(champion)
        XCTAssertEqual(FootballSeason.standings(results: career.fixtures).first?.team.id, champion)

        career.startNextSeason()
        XCTAssertEqual(career.season, 2)
        XCTAssertEqual(career.currentRound, 0)
        XCTAssertEqual(career.champions, [champion!])
        XCTAssertTrue(career.fixtures.allSatisfy { !$0.isPlayed })
        XCTAssertEqual(career.players.reduce(0) { $0 + $1.goals }, 0)
    }
}
