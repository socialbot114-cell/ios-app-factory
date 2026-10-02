import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballSeasonTests: XCTestCase {
    // MARK: - Mundo e calendário

    func testWorldHasTwentyClubsInTwoDivisions() {
        let career = FootballCareer(seed: 7)
        XCTAssertEqual(FootballSeason.teams.count, 20)
        XCTAssertEqual(Set(FootballSeason.teams.map(\.id)), Set(0..<20))
        XCTAssertEqual(career.teamIDs(in: .serieA).count, 10)
        XCTAssertEqual(career.teamIDs(in: .serieB).count, 10)
        XCTAssertTrue(FootballSeason.teams.allSatisfy { career.players(forTeam: $0.id).count == 16 })
        XCTAssertEqual(career.marketPlayers.count, 12)
        XCTAssertEqual(Set(career.players.map(\.id)).count, career.players.count)
        XCTAssertGreaterThan(career.nextPlayerID, career.players.map(\.id).max() ?? 0)
    }

    func testCalendarInterleavesLeagueRoundsAndMidweekCup() {
        let calendar = FootballSeason.calendar
        XCTAssertEqual(calendar.count, 23)
        XCTAssertEqual(calendar.compactMap(\.leagueRound), Array(1...18))
        XCTAssertEqual(calendar.compactMap(\.cupRound), CupRound.allCases)
        XCTAssertTrue(calendar.filter { $0.cupRound != nil }.allSatisfy(\.isMidweek))
        XCTAssertEqual(calendar.map(\.index), Array(0..<23))

        let career = FootballCareer(seed: 7)
        for division in Division.allCases {
            let league = career.fixtures.filter { $0.competition == .league(division) }
            XCTAssertEqual(league.count, 90)
            let ids = career.teamIDs(in: division)
            for round in 1...18 {
                let teams = league.filter { $0.round == round }.flatMap { [$0.home, $0.away] }
                XCTAssertEqual(Set(teams), Set(ids), "Cada clube joga uma vez por rodada")
                XCTAssertEqual(teams.count, 10)
            }
            for first in ids {
                for second in ids where second > first {
                    let meetings = league.filter { Set([$0.home, $0.away]) == Set([first, second]) }
                    XCTAssertEqual(meetings.count, 2)
                    XCTAssertEqual(meetings.filter { $0.home == first }.count, 1)
                }
            }
        }
        let preliminary = career.fixtures.filter { $0.competition == .cup(.preliminary) }
        XCTAssertEqual(preliminary.count, 4)
        XCTAssertTrue(preliminary.allSatisfy { career.division(of: $0.home) == .serieB && career.division(of: $0.away) == .serieB })
        XCTAssertTrue(preliminary.allSatisfy { $0.matchDay == FootballSeason.matchDayIndex(cupRound: .preliminary) })
        XCTAssertEqual(Set(career.fixtures.map(\.id)).count, career.fixtures.count)
    }

    // MARK: - Elenco

    func testSubstitutionReplacesTheChosenStarterAndFormationKeepsManualChoices() throws {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.setFormation(.fourFourTwo))
        let bestDefender = try XCTUnwrap(career.starters.filter { $0.position == .defender }.max { $0.overall < $1.overall })
        let benchDefender = try XCTUnwrap(career.clubRoster.first { $0.position == .defender && !career.startingXI.contains($0.id) })
        XCTAssertTrue(career.substitute(outgoingID: bestDefender.id, incomingID: benchDefender.id))
        XCTAssertFalse(career.startingXI.contains(bestDefender.id))
        XCTAssertTrue(career.setFormation(.fourThreeThree))
        XCTAssertTrue(career.startingXI.contains(benchDefender.id))
        XCTAssertFalse(career.startingXI.contains(bestDefender.id))
        for formation in FootballFormation.allCases {
            XCTAssertTrue(career.setFormation(formation))
            for (position, required) in formation.requiredPlayers {
                XCTAssertEqual(career.starters.filter { $0.position == position }.count, required)
            }
        }
    }

    func testInjuredPlayersAreNeverSelected() throws {
        var career = FootballCareer(seed: 5)
        XCTAssertTrue(career.chooseClub(1))
        let starterID = try XCTUnwrap(career.startingXI.first)
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == starterID })
        career.players[index].injuryRounds = 2
        career.repairLineup()
        XCTAssertFalse(career.startingXI.contains(starterID))
        XCTAssertEqual(career.startingXI.count, 11)
    }

    // MARK: - Temporada completa

    func testFullSeasonIsDeterministicAndConsistent() throws {
        var first = FootballCareer(seed: 7)
        var second = FootballCareer(seed: 7)
        XCTAssertTrue(first.chooseClub(0))
        XCTAssertTrue(second.chooseClub(0))
        for _ in 0..<FootballSeason.matchDaysPerSeason {
            XCTAssertTrue(first.simulateNextMatchDay())
            XCTAssertTrue(second.simulateNextMatchDay())
        }
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.isSeasonComplete)
        XCTAssertFalse(first.simulateNextMatchDay())
        XCTAssertTrue(first.fixtures.allSatisfy(\.isPlayed))

        let goals = first.fixtures.reduce(0) { $0 + ($1.homeGoals ?? 0) + ($1.awayGoals ?? 0) }
        XCTAssertEqual(first.players.reduce(0) { $0 + $1.goals }, goals)
        XCTAssertEqual(first.players.filter { $0.position == .goalkeeper }.reduce(0) { $0 + $1.goals }, 0)
        for fixture in first.fixtures {
            XCTAssertEqual(fixture.homeScorerIDs.count, fixture.homeGoals)
            XCTAssertEqual(fixture.awayScorerIDs.count, fixture.awayGoals)
            XCTAssertGreaterThanOrEqual(fixture.homeShots ?? 0, fixture.homeOnTarget ?? 0)
            XCTAssertEqual((fixture.homePossession ?? 0) + (fixture.awayPossession ?? 0), 100)
        }
        XCTAssertEqual(first.standings(for: .serieA).reduce(0) { $0 + $1.played }, 180)
        XCTAssertEqual(first.standings(for: .serieB).reduce(0) { $0 + $1.played }, 180)
    }

    func testCupRunsFromPreliminaryToFinalWithAWinnerInEveryTie() throws {
        var career = FootballCareer(seed: 11)
        XCTAssertTrue(career.chooseClub(3))
        for _ in 0..<FootballSeason.matchDaysPerSeason { XCTAssertTrue(career.simulateNextMatchDay()) }
        let cup = career.cupFixtures
        XCTAssertEqual(cup.filter { $0.competition == .cup(.preliminary) }.count, 4)
        XCTAssertEqual(cup.filter { $0.competition == .cup(.roundOf16) }.count, 8)
        XCTAssertEqual(cup.filter { $0.competition == .cup(.quarterFinal) }.count, 4)
        XCTAssertEqual(cup.filter { $0.competition == .cup(.semiFinal) }.count, 2)
        XCTAssertEqual(cup.filter { $0.competition == .cup(.final) }.count, 1)
        XCTAssertTrue(cup.allSatisfy { $0.winner != nil })
        for fixture in cup where fixture.homeGoals == fixture.awayGoals {
            XCTAssertTrue(fixture.wentToExtraTime)
            XCTAssertNotNil(fixture.homePenalties)
            XCTAssertNotEqual(fixture.homePenalties, fixture.awayPenalties)
        }
        let roundOf16Teams = Set(cup.filter { $0.competition == .cup(.roundOf16) }.flatMap { [$0.home, $0.away] })
        XCTAssertTrue(Set(career.teamIDs(in: .serieA)).isSubset(of: roundOf16Teams))
        XCTAssertNotNil(career.cupWinnerThisSeason)
        XCTAssertEqual(career.cupWinners.count, 1)
    }

    func testDaysWithoutTheUserClubAdvanceWithoutPlaying() {
        var career = FootballCareer(seed: 3)
        XCTAssertTrue(career.chooseClub(0))
        for _ in 0..<3 { XCTAssertTrue(career.simulateNextMatchDay()) }
        // O 4º dia de jogo é a fase preliminar da copa, só com clubes da Série B.
        XCTAssertEqual(career.currentSlot?.cupRound, .preliminary)
        XCTAssertFalse(career.canPlay)
        XCTAssertTrue(career.canAdvanceWithoutPlaying)
        XCTAssertFalse(career.beginMatchDay())
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertEqual(career.matchDayIndex, 4)
        XCTAssertTrue(career.fixtures.filter { $0.competition == .cup(.preliminary) }.allSatisfy(\.isPlayed))
        XCTAssertEqual(career.fixtures.filter { $0.competition == .cup(.roundOf16) }.count, 8)
    }

    func testPromotionRelegationAndSeasonRecord() throws {
        var career = FootballCareer(seed: 31)
        XCTAssertTrue(career.chooseClub(10))
        XCTAssertEqual(career.userDivision, .serieB)
        XCTAssertEqual(career.objectiveText, "Conquistar o acesso")
        for _ in 0..<FootballSeason.matchDaysPerSeason { XCTAssertTrue(career.simulateNextMatchDay()) }
        let promoted = career.standings(for: .serieB).prefix(2).map(\.team.id)
        let relegated = career.standings(for: .serieA).suffix(2).map(\.team.id)
        let ages = Dictionary(uniqueKeysWithValues: career.players.map { ($0.id, $0.age) })
        let budget = career.transferBudget

        let record = try XCTUnwrap(career.startNextSeason())
        XCTAssertEqual(record.division, .serieB)
        XCTAssertEqual(record.promoted, promoted.contains(10))
        XCTAssertTrue(promoted.allSatisfy { career.division(of: $0) == .serieA })
        XCTAssertTrue(relegated.allSatisfy { career.division(of: $0) == .serieB })
        XCTAssertEqual(career.teamIDs(in: .serieA).count, 10)
        XCTAssertEqual(career.teamIDs(in: .serieB).count, 10)
        XCTAssertEqual(career.transferBudget, budget + record.prizeMoney)
        XCTAssertEqual(career.season, 2)
        XCTAssertEqual(career.matchDayIndex, 0)
        XCTAssertTrue(career.fixtures.allSatisfy { !$0.isPlayed })
        XCTAssertEqual(career.fixtures.filter { $0.competition.division != nil }.count, 180)
        XCTAssertGreaterThanOrEqual(career.marketPlayers.count, FootballCareer.freeAgentPoolSize)
        XCTAssertEqual(Set(career.players.map(\.id)).count, career.players.count)
        for player in career.players {
            if let age = ages[player.id] { XCTAssertEqual(player.age, age + 1) }
            XCTAssertLessThanOrEqual(player.overall, player.potential)
        }
        for team in FootballSeason.teams where team.id != career.selectedClubID {
            XCTAssertEqual(career.players(forTeam: team.id).count, 16)
        }
        if career.isFired {
            let job = try XCTUnwrap(career.jobOffers.first)
            XCTAssertTrue(career.acceptJob(job.id))
        }
        XCTAssertTrue(career.simulateNextMatchDay())
    }

    // MARK: - Partida ao vivo

    func testLiveMatchHalfTimeChangesAffectSecondHalfAndAreSaved() throws {
        var career = FootballCareer(seed: 21)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        let live = try XCTUnwrap(career.liveMatch)
        XCTAssertEqual(live.matchDay, 0)
        XCTAssertEqual(career.matchDayIndex, 0)
        XCTAssertFalse(career.beginMatchDay())
        XCTAssertFalse(career.canSign(playerID: career.marketPlayers[0].id))
        let restored = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(restored.liveMatch, live)

        let outgoing = try XCTUnwrap(career.starters.first { $0.position == .forward })
        let incoming = try XCTUnwrap(career.clubRoster.first { $0.position == .forward && !career.startingXI.contains($0.id) })
        XCTAssertTrue(career.substitute(outgoingID: outgoing.id, incomingID: incoming.id))
        career.setPlayStyle(.counter)
        XCTAssertTrue(career.finishMatchDay())
        XCTAssertNil(career.liveMatch)
        XCTAssertEqual(career.matchDayIndex, 1)
        let fixture = try XCTUnwrap(career.latestUserFixture)
        XCTAssertTrue(fixture.events.contains { $0.kind == .substitution })
        XCTAssertTrue(fixture.events.contains { $0.kind == .tactic })
        XCTAssertEqual(career.player(outgoing.id)?.appearances, 1)
        XCTAssertEqual(career.player(incoming.id)?.appearances, 1)
        XCTAssertTrue(career.fixtures.filter { $0.matchDay == 0 }.allSatisfy(\.isPlayed))
    }

    func testPenaltyShootoutAlwaysProducesAWinner() {
        let career = FootballCareer(seed: 2)
        let home = career.side(teamID: 0, opponentID: 1, isHome: true, style: .balanced, opponentStyle: .balanced)
        let away = career.side(teamID: 1, opponentID: 0, isHome: false, style: .balanced, opponentStyle: .balanced)
        for seed in 1...200 {
            var random = FootballRandom(seed: UInt64(seed))
            let result = FootballMatchEngine.penaltyShootout(home: home, away: away, using: &random)
            XCTAssertNotEqual(result.homeScore, result.awayScore)
            XCTAssertFalse(result.events.isEmpty)
        }
    }

    // MARK: - Saves

    func testSaveRoundTripAndLegacyWorldMigration() throws {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(2))
        XCTAssertTrue(career.simulateNextMatchDay())
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip, career)

        // Save v2: liga única de 8 clubes, sem divisões, copa, calendário nem campos novos.
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        legacy["schemaVersion"] = 2
        legacy["currentRound"] = 5
        for key in ["matchDayIndex", "divisionOfTeam", "cupWinners", "liveMatch", "boardTarget", "history"] {
            legacy.removeValue(forKey: key)
        }
        if let players = legacy["players"] as? [[String: Any]] {
            legacy["players"] = players.filter { ($0["teamID"] as? Int).map { $0 < 8 } ?? true }.map { player in
                var copy = player
                for key in ["injuryRounds", "careerGoals"] { copy.removeValue(forKey: key) }
                return copy
            }
        }
        if let fixtures = legacy["fixtures"] as? [[String: Any]] {
            legacy["fixtures"] = fixtures.map { fixture in
                var copy = fixture
                for key in ["matchDay", "competition", "events", "wentToExtraTime"] { copy.removeValue(forKey: key) }
                return copy
            }
        }
        let migrated = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(migrated.selectedClubID, 2)
        XCTAssertEqual(migrated.transferBudget, career.transferBudget)
        XCTAssertEqual(migrated.matchDayIndex, 0)
        XCTAssertTrue(migrated.fixtures.allSatisfy { !$0.isPlayed })
        XCTAssertEqual(migrated.fixtures.filter { $0.competition.division != nil }.count, 180)
        XCTAssertTrue(FootballSeason.teams.allSatisfy { migrated.players(forTeam: $0.id).count == 16 })
        XCTAssertEqual(Set(migrated.players.map(\.id)).count, migrated.players.count)
        XCTAssertEqual(migrated.startingXI.count, 11)
        var playable = migrated
        XCTAssertTrue(playable.simulateNextMatchDay())
    }

    func testFileSaveStoreSlotsSummaryBackupAndLegacyImport() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FootballSaves-\(UUID().uuidString)")
        let suiteName = "FootballSaveStoreTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = FootballSaveStore(directory: directory, defaults: defaults)
        XCTAssertNil(store.load(slot: 0))

        var career = FootballCareer(seed: 4)
        XCTAssertTrue(career.chooseClub(12))
        XCTAssertTrue(store.save(career, slot: 1))
        XCTAssertEqual(store.load(slot: 1), career)
        let summary = try XCTUnwrap(store.summary(slot: 1))
        XCTAssertEqual(summary.clubID, 12)
        XCTAssertEqual(summary.division, .serieB)

        store.activeSlot = 2
        XCTAssertEqual(store.activeSlot, 2)

        try Data("{ quebrado".utf8).write(to: store.careerURL(slot: 1))
        XCTAssertNil(store.load(slot: 1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.backupURL(slot: 1).path))
        XCTAssertFalse(store.hasCareer(slot: 1))

        defaults.set(try JSONEncoder().encode(career), forKey: FootballCareer.saveKey)
        XCTAssertTrue(store.migrateLegacyDefaults())
        XCTAssertNil(defaults.data(forKey: FootballCareer.saveKey))
        XCTAssertEqual(store.load(slot: 0)?.selectedClubID, 12)
        store.delete(slot: 0)
        XCTAssertFalse(store.hasCareer(slot: 0))
    }

    // MARK: - Mercado

    func testMarketHasNoBuySellArbitrageAndRespectsRosterLimits() throws {
        var career = FootballCareer(seed: 13)
        XCTAssertTrue(career.chooseClub(0))
        let target = try XCTUnwrap(career.marketPlayers.first { career.canSign(playerID: $0.id) })
        let budgetBefore = career.transferBudget
        XCTAssertTrue(career.signPlayer(playerID: target.id))
        XCTAssertEqual(career.transferBudget, budgetBefore - target.marketValue)
        XCTAssertLessThan(career.quickSalePrice(playerID: target.id), target.marketValue)
        XCTAssertTrue(career.sellPlayer(playerID: target.id))
        XCTAssertLessThan(career.transferBudget, budgetBefore)
        while let sellable = career.clubRoster.first(where: { career.canSell(playerID: $0.id) }) {
            XCTAssertTrue(career.sellPlayer(playerID: sellable.id))
        }
        XCTAssertGreaterThanOrEqual(career.clubRoster.count, FootballCareer.minimumRoster)
        XCTAssertEqual(career.startingXI.count, 11)
        for player in career.players {
            XCTAssertEqual(player.marketValue, FootballSeason.marketValue(overall: player.overall, age: player.age, potential: player.potential))
        }
    }

    func testAcceptingAnOfferTransfersThePlayerAndKeepsRostersBalanced() throws {
        var career = FootballCareer(seed: 9)
        XCTAssertTrue(career.chooseClub(4))
        let player = try XCTUnwrap(career.clubRoster.first { !career.startingXI.contains($0.id) })
        career.offers = [TransferOffer(id: 999, playerID: player.id, clubID: 1, amount: 2_000_000, expiresAfterRound: 3)]
        let budget = career.transferBudget
        let buyerCount = career.players(forTeam: 1).count
        XCTAssertTrue(career.acceptOffer(999))
        XCTAssertEqual(career.player(player.id)?.teamID, 1)
        XCTAssertEqual(career.transferBudget, budget + 2_000_000)
        XCTAssertEqual(career.players(forTeam: 1).count, buyerCount)
        XCTAssertEqual(career.clubRoster.count, 15)
    }

    func testOffersExpireAfterTheirDeadline() {
        var career = FootballCareer(seed: 9)
        XCTAssertTrue(career.chooseClub(4))
        let player = career.clubRoster[5]
        career.offers = [TransferOffer(id: 999, playerID: player.id, clubID: 1, amount: 1_000_000, expiresAfterRound: 1)]
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertFalse(career.offers.contains { $0.id == 999 })
        XCTAssertTrue(career.offers.allSatisfy { $0.expiresAfterRound > career.matchDayIndex })
    }

    // MARK: - Tática e treino

    func testTacticalMatchupsFormARockPaperScissorsCycle() {
        XCTAssertEqual(FootballPlayStyle.bestAnswer(to: .possession), .highPress)
        XCTAssertEqual(FootballPlayStyle.bestAnswer(to: .highPress), .counter)
        XCTAssertEqual(FootballPlayStyle.bestAnswer(to: .counter), .defensive)
        XCTAssertEqual(FootballPlayStyle.bestAnswer(to: .defensive), .possession)
        let withBall = FootballMatchEngine.expectedGoals(attack: 75, defense: 75, possessionShare: 0.62)
        let withoutBall = FootballMatchEngine.expectedGoals(attack: 75, defense: 75, possessionShare: 0.38)
        XCTAssertGreaterThan(withBall, withoutBall)
    }

    func testTrainingIsDeterministicAndMidweekRecoversLessWithoutDevelopment() throws {
        func prepared() -> FootballCareer {
            var career = FootballCareer(seed: 26)
            _ = career.chooseClub(0)
            career.setTrainingFocus(.technical)
            career.setTrainingIntensity(.intense)
            for index in career.players.indices { career.players[index].condition = 60 }
            return career
        }
        var weekend = prepared()
        var repeated = prepared()
        var midweek = prepared()
        weekend.applyWeeklyTraining(for: 0)
        repeated.applyWeeklyTraining(for: 0)
        midweek.applyWeeklyTraining(for: 0, midweek: true)
        XCTAssertEqual(weekend.players, repeated.players)
        let weekendReport = try XCTUnwrap(weekend.lastTrainingReport)
        let midweekReport = try XCTUnwrap(midweek.lastTrainingReport)
        XCTAssertGreaterThan(weekendReport.averageConditionGain, midweekReport.averageConditionGain)
        XCTAssertEqual(midweekReport.developedPlayers, 0)
        XCTAssertTrue(weekend.clubRoster.allSatisfy { $0.overall <= $0.potential })
    }
}
