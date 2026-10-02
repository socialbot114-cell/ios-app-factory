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
        XCTAssertEqual(Set(career.players.map(\.id)).count, career.players.count)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertEqual(career.startingXI.count, 11)
        XCTAssertGreaterThan(career.boardTarget, 0)

        for formation in FootballFormation.allCases {
            XCTAssertTrue(career.setFormation(formation))
            XCTAssertEqual(career.startingXI.count, 11)
            for (position, required) in formation.requiredPlayers {
                XCTAssertEqual(career.starters.filter { $0.position == position }.count, required)
            }
        }
    }

    func testSubstitutionReplacesTheChosenStarterAndFormationKeepsManualChoices() throws {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.setFormation(.fourFourTwo))

        // Escolhe explicitamente o MELHOR zagueiro titular para sair (antes o jogo sempre tirava o pior).
        let bestDefender = try XCTUnwrap(career.starters.filter { $0.position == .defender }.max { $0.overall < $1.overall })
        let benchDefender = try XCTUnwrap(career.clubRoster.first { $0.position == .defender && !career.startingXI.contains($0.id) })
        XCTAssertTrue(career.substitute(outgoingID: bestDefender.id, incomingID: benchDefender.id))
        XCTAssertFalse(career.startingXI.contains(bestDefender.id))
        XCTAssertTrue(career.startingXI.contains(benchDefender.id))
        XCTAssertEqual(career.startingXI.count, 11)

        // Trocar de formação preserva a escolha manual do zagueiro reserva.
        XCTAssertTrue(career.setFormation(.fourThreeThree))
        XCTAssertTrue(career.startingXI.contains(benchDefender.id))
        XCTAssertFalse(career.startingXI.contains(bestDefender.id))

        career.autoSelectLineup()
        XCTAssertEqual(career.startingXI.count, 11)
    }

    func testRoundResultsAreDeterministicAndGoalkeepersNeverScore() throws {
        var firstCareer = FootballCareer(seed: 7)
        var secondCareer = FootballCareer(seed: 7)
        XCTAssertTrue(firstCareer.chooseClub(0))
        XCTAssertTrue(secondCareer.chooseClub(0))

        XCTAssertTrue(firstCareer.simulateNextRound())
        XCTAssertTrue(secondCareer.simulateNextRound())
        XCTAssertEqual(firstCareer, secondCareer)
        XCTAssertEqual(firstCareer.currentRound, 1)
        XCTAssertNil(firstCareer.liveMatch)
        XCTAssertEqual(firstCareer.fixtures.filter(\.isPlayed).count, 4)
        XCTAssertTrue(firstCareer.fixtures.filter { $0.round > 1 }.allSatisfy { !$0.isPlayed })
        XCTAssertEqual(firstCareer.standings.reduce(0) { $0 + $1.played }, 8)

        for _ in 0..<13 { XCTAssertTrue(firstCareer.simulateNextRound()) }
        let scoredGoals = firstCareer.fixtures.reduce(0) { $0 + ($1.homeGoals ?? 0) + ($1.awayGoals ?? 0) }
        XCTAssertEqual(firstCareer.players.reduce(0) { $0 + $1.goals }, scoredGoals)
        XCTAssertEqual(firstCareer.players.filter { $0.position == .goalkeeper }.reduce(0) { $0 + $1.goals }, 0)
        for fixture in firstCareer.fixtures {
            XCTAssertEqual(fixture.homeScorerIDs.count, fixture.homeGoals)
            XCTAssertEqual(fixture.awayScorerIDs.count, fixture.awayGoals)
            XCTAssertGreaterThanOrEqual(fixture.homeShots ?? 0, fixture.homeOnTarget ?? 0)
            XCTAssertGreaterThanOrEqual(fixture.homeOnTarget ?? 0, fixture.homeGoals ?? 0)
            XCTAssertEqual((fixture.homePossession ?? 0) + (fixture.awayPossession ?? 0), 100)
        }
        let userFixture = try XCTUnwrap(firstCareer.latestUserFixture)
        XCTAssertTrue(userFixture.events.contains { $0.kind == .fullTime })
        XCTAssertEqual(userFixture.events.filter { $0.kind == .goal }.count, (userFixture.homeGoals ?? 0) + (userFixture.awayGoals ?? 0))
    }

    func testSaveRoundTripLegacyDecodingAndCorruptedBackup() throws {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(2))
        XCTAssertTrue(career.simulateNextRound())

        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip, career)

        // Save antigo: sem campos novos na carreira, nos atletas e nas partidas.
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        for key in ["playStyle", "trainingFocus", "trainingIntensity", "lastTrainingReport", "champions", "boardTarget",
                    "boardConfidence", "isFired", "history", "offers", "nextOfferID", "nextPlayerID", "liveMatch",
                    "lastRoundRevenue", "schemaVersion"] {
            legacy.removeValue(forKey: key)
        }
        if var players = legacy["players"] as? [[String: Any]] {
            for index in players.indices {
                for key in ["goals", "assists", "appearances", "injuryRounds", "careerGoals"] {
                    players[index].removeValue(forKey: key)
                }
            }
            legacy["players"] = players
        }
        if var fixtures = legacy["fixtures"] as? [[String: Any]] {
            for index in fixtures.indices {
                for key in ["homeScorerIDs", "awayScorerIDs", "commentary", "events", "homeShots", "awayShots",
                            "homeOnTarget", "awayOnTarget", "homePossession", "awayPossession", "homeExpectedGoals", "awayExpectedGoals"] {
                    fixtures[index].removeValue(forKey: key)
                }
            }
            legacy["fixtures"] = fixtures
        }
        let legacyCareer = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(legacyCareer.playStyle, .balanced)
        XCTAssertEqual(legacyCareer.fixtures.filter(\.isPlayed).count, 4)
        XCTAssertEqual(legacyCareer.players.count, career.players.count)
        XCTAssertGreaterThan(legacyCareer.nextPlayerID, legacyCareer.players.map(\.id).max() ?? 0)
        XCTAssertEqual(legacyCareer.selectedClubID, 2)

        let suiteName = "FootballCareerTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        career.persist(defaults: defaults)
        XCTAssertEqual(FootballCareer.load(defaults: defaults), career)

        let corrupted = Data("{ não é json".utf8)
        defaults.set(corrupted, forKey: FootballCareer.saveKey)
        let fresh = FootballCareer.load(defaults: defaults)
        XCTAssertNil(fresh.selectedClubID)
        XCTAssertEqual(defaults.data(forKey: FootballCareer.backupKey), corrupted)
    }

    func testMarketHasNoBuySellArbitrageAndRespectsRosterLimits() throws {
        var career = FootballCareer(seed: 13)
        XCTAssertTrue(career.chooseClub(0))
        let target = try XCTUnwrap(career.marketPlayers.first { career.canSign(playerID: $0.id) })
        let budgetBefore = career.transferBudget
        XCTAssertTrue(career.signPlayer(playerID: target.id))
        XCTAssertEqual(career.transferBudget, budgetBefore - target.marketValue)
        XCTAssertEqual(career.clubRoster.count, 17)

        // Vender logo em seguida devolve só 70%: comprar e revender nunca dá lucro imediato.
        let salePrice = career.quickSalePrice(playerID: target.id)
        XCTAssertLessThan(salePrice, target.marketValue)
        XCTAssertTrue(career.sellPlayer(playerID: target.id))
        XCTAssertLessThan(career.transferBudget, budgetBefore)
        XCTAssertTrue(career.marketPlayers.contains { $0.id == target.id })

        // Vende até o mínimo do elenco; depois disso a venda é bloqueada.
        while let sellable = career.clubRoster.first(where: { career.canSell(playerID: $0.id) }) {
            XCTAssertTrue(career.sellPlayer(playerID: sellable.id))
        }
        XCTAssertGreaterThanOrEqual(career.clubRoster.count, FootballCareer.minimumRoster)
        XCTAssertTrue(FootballSeason.canFill(roster: career.clubRoster, formation: career.formation))
        XCTAssertEqual(career.startingXI.count, 11)

        // Valores de mercado usam uma única fórmula para agentes livres e atletas de clubes.
        for player in career.players {
            XCTAssertEqual(player.marketValue, FootballSeason.marketValue(overall: player.overall, age: player.age, potential: player.potential))
        }
    }

    func testLiveMatchHalfTimeChangesAffectSecondHalfAndAreSaved() throws {
        var career = FootballCareer(seed: 21)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        let live = try XCTUnwrap(career.liveMatch)
        XCTAssertEqual(live.round, 1)
        XCTAssertEqual(career.currentRound, 0)
        XCTAssertTrue(live.events.contains { $0.kind == .halfTime })
        XCTAssertFalse(career.beginMatchDay(), "Não pode iniciar outra rodada com uma partida no intervalo")
        XCTAssertFalse(career.canSign(playerID: career.marketPlayers[0].id))

        // A partida no intervalo sobrevive ao salvamento.
        let restored = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(restored.liveMatch, live)

        let outgoing = try XCTUnwrap(career.starters.first { $0.position == .forward })
        let incoming = try XCTUnwrap(career.clubRoster.first { $0.position == .forward && !career.startingXI.contains($0.id) })
        XCTAssertTrue(career.substitute(outgoingID: outgoing.id, incomingID: incoming.id))
        XCTAssertEqual(career.liveMatch?.substitutionsUsed, 1)
        career.setPlayStyle(.counter)

        XCTAssertTrue(career.finishMatchDay())
        XCTAssertNil(career.liveMatch)
        XCTAssertEqual(career.currentRound, 1)
        let fixture = try XCTUnwrap(career.latestUserFixture)
        XCTAssertTrue(fixture.events.contains { $0.kind == .substitution })
        XCTAssertTrue(fixture.events.contains { $0.kind == .tactic })
        XCTAssertGreaterThanOrEqual(fixture.homeGoals ?? 0, live.homeGoals)
        XCTAssertGreaterThanOrEqual(fixture.awayGoals ?? 0, live.awayGoals)
        // Quem saiu e quem entrou contam como participação.
        XCTAssertEqual(career.player(outgoing.id)?.appearances, 1)
        XCTAssertEqual(career.player(incoming.id)?.appearances, 1)
        XCTAssertEqual(career.fixtures.filter(\.isPlayed).count, 4)
    }

    func testTacticalMatchupsFormARockPaperScissorsCycle() {
        XCTAssertEqual(FootballPlayStyle.bestAnswer(to: .possession), .highPress)
        XCTAssertEqual(FootballPlayStyle.bestAnswer(to: .highPress), .counter)
        XCTAssertEqual(FootballPlayStyle.bestAnswer(to: .counter), .defensive)
        XCTAssertEqual(FootballPlayStyle.bestAnswer(to: .defensive), .possession)
        XCTAssertNotEqual(FootballPlayStyle.bestAnswer(to: .balanced), .balanced)

        let more = FootballMatchEngine.expectedGoals(attack: 80, defense: 72, possessionShare: 0.5)
        let less = FootballMatchEngine.expectedGoals(attack: 72, defense: 80, possessionShare: 0.5)
        let withBall = FootballMatchEngine.expectedGoals(attack: 75, defense: 75, possessionShare: 0.62)
        let withoutBall = FootballMatchEngine.expectedGoals(attack: 75, defense: 75, possessionShare: 0.38)
        XCTAssertGreaterThan(more, less * 2)
        XCTAssertGreaterThan(withBall, withoutBall, "Posse de bola precisa influenciar as chances, não só a estatística")
    }

    func testWeeklyTrainingIsDeterministicAndRecoveryFocusRestoresMoreCondition() throws {
        var technical = FootballCareer(seed: 26)
        var repeated = FootballCareer(seed: 26)
        var recovery = FootballCareer(seed: 26)
        XCTAssertTrue(technical.chooseClub(0))
        XCTAssertTrue(repeated.chooseClub(0))
        XCTAssertTrue(recovery.chooseClub(0))
        technical.setTrainingFocus(.technical)
        technical.setTrainingIntensity(.intense)
        repeated.setTrainingFocus(.technical)
        repeated.setTrainingIntensity(.intense)
        recovery.setTrainingFocus(.recovery)
        recovery.setTrainingIntensity(.intense)
        let original = Dictionary(uniqueKeysWithValues: technical.clubRoster.map { ($0.id, $0) })

        technical.applyWeeklyTraining(for: 1)
        repeated.applyWeeklyTraining(for: 1)
        recovery.applyWeeklyTraining(for: 1)
        XCTAssertEqual(technical.players, repeated.players)
        let technicalReport = try XCTUnwrap(technical.lastTrainingReport)
        let recoveryReport = try XCTUnwrap(recovery.lastTrainingReport)
        XCTAssertGreaterThan(recoveryReport.averageConditionGain, technicalReport.averageConditionGain)
        XCTAssertEqual(recoveryReport.developedPlayers, 0)

        let developed = technical.clubRoster.filter { $0.overall > (original[$0.id]?.overall ?? 0) }
        XCTAssertEqual(technicalReport.developedPlayers, developed.count)
        XCTAssertTrue(technical.clubRoster.allSatisfy { $0.overall <= $0.potential })
        XCTAssertTrue(developed.allSatisfy { FootballTrainingFocus.technical.developmentPositions.contains($0.position) })
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
        XCTAssertFalse(FootballSeason.bestLineup(roster: career.clubRoster, formation: career.formation).contains(starterID))
    }

    func testAcceptingAnOfferTransfersThePlayerAndKeepsRostersBalanced() throws {
        var career = FootballCareer(seed: 9)
        XCTAssertTrue(career.chooseClub(4))
        let player = try XCTUnwrap(career.clubRoster.first { !career.startingXI.contains($0.id) })
        career.offers = [TransferOffer(id: 99, playerID: player.id, clubID: 1, amount: 2_000_000, expiresAfterRound: 3)]
        let budget = career.transferBudget
        let buyerCount = career.players(forTeam: 1).count
        XCTAssertTrue(career.acceptOffer(99))
        XCTAssertEqual(career.player(player.id)?.teamID, 1)
        XCTAssertEqual(career.transferBudget, budget + 2_000_000)
        XCTAssertEqual(career.players(forTeam: 1).count, buyerCount)
        XCTAssertTrue(career.offers.isEmpty)
        XCTAssertEqual(career.clubRoster.count, 15)
    }

    func testCompletedSeasonAgesPlayersRecordsHistoryAndRefreshesMarket() throws {
        var career = FootballCareer(seed: 31)
        XCTAssertTrue(career.chooseClub(3))
        for _ in 0..<14 { XCTAssertTrue(career.simulateNextRound()) }
        XCTAssertTrue(career.isSeasonComplete)
        XCTAssertFalse(career.simulateNextRound())
        XCTAssertEqual(career.fixtures.filter(\.isPlayed).count, 56)
        let champion = try XCTUnwrap(career.championID)
        let ages = Dictionary(uniqueKeysWithValues: career.players.map { ($0.id, $0.age) })
        let budget = career.transferBudget

        let record = try XCTUnwrap(career.startNextSeason())
        XCTAssertEqual(record.season, 1)
        XCTAssertEqual(record.championID, champion)
        XCTAssertEqual(career.history, [record])
        XCTAssertEqual(career.champions, [champion])
        XCTAssertEqual(career.season, 2)
        XCTAssertEqual(career.currentRound, 0)
        XCTAssertTrue(career.fixtures.allSatisfy { !$0.isPlayed })
        XCTAssertEqual(career.players.reduce(0) { $0 + $1.goals }, 0)
        XCTAssertEqual(career.transferBudget, budget + record.prizeMoney)
        XCTAssertGreaterThanOrEqual(career.marketPlayers.count, 14)
        XCTAssertEqual(Set(career.players.map(\.id)).count, career.players.count)
        for player in career.players {
            if let previousAge = ages[player.id] { XCTAssertEqual(player.age, previousAge + 1) }
            XCTAssertLessThanOrEqual(player.overall, player.potential)
        }
        for team in FootballSeason.teams where team.id != career.selectedClubID {
            XCTAssertEqual(career.players(forTeam: team.id).count, 16, "Aposentados da IA são repostos pela base")
        }
        if career.isFired {
            XCTAssertFalse(career.simulateNextRound())
            let job = try XCTUnwrap(career.jobOffers.first)
            XCTAssertTrue(career.acceptJob(job.id))
        }
        XCTAssertTrue(career.simulateNextRound())
    }

    func testLeagueBalanceOverSeveralSeasons() {
        var totalGoals = 0
        var totalMatches = 0
        var homeWins = 0
        var strongPoints = 0
        var weakPoints = 0
        for seed in 1...6 {
            var career = FootballCareer(seed: seed * 101)
            XCTAssertTrue(career.chooseClub(5))
            for _ in 0..<14 { career.simulateNextRound() }
            for fixture in career.fixtures {
                totalGoals += (fixture.homeGoals ?? 0) + (fixture.awayGoals ?? 0)
                totalMatches += 1
                if (fixture.homeGoals ?? 0) > (fixture.awayGoals ?? 0) { homeWins += 1 }
            }
            strongPoints += career.standings.first { $0.team.id == 0 }?.points ?? 0
            weakPoints += career.standings.first { $0.team.id == 6 }?.points ?? 0
            XCTAssertEqual(career.players.filter { $0.position == .goalkeeper }.reduce(0) { $0 + $1.goals }, 0)
        }
        let average = Double(totalGoals) / Double(totalMatches)
        XCTAssertGreaterThan(average, 1.8, "Média de gols muito baixa: \(average)")
        XCTAssertLessThan(average, 3.6, "Média de gols muito alta: \(average)")
        XCTAssertGreaterThan(Double(homeWins) / Double(totalMatches), 0.3)
        XCTAssertGreaterThan(strongPoints, weakPoints, "O clube mais forte deve somar mais pontos que o mais fraco")
    }
}
