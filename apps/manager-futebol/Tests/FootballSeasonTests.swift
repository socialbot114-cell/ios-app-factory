import XCTest
@testable import ManagerFutebol

final class FootballSeasonTests: XCTestCase {
    func testDoubleRoundRobinHasFourMatchesAndEveryTeamPlaysOncePerRound() {
        let fixtures = FootballGame.makeFixtures()
        XCTAssertEqual(fixtures.count, 56)
        XCTAssertEqual(Set(fixtures.map(\.round)), Set(1...14))

        for round in 1...14 {
            let matches = fixtures.filter { $0.round == round }
            XCTAssertEqual(matches.count, 4)
            let participatingTeams = matches.flatMap { [$0.homeTeamID, $0.awayTeamID] }
            XCTAssertEqual(Set(participatingTeams).count, 8)
        }

        for first in 0..<8 {
            for second in (first + 1)..<8 {
                let meetings = fixtures.filter { Set([$0.homeTeamID, $0.awayTeamID]) == Set([first, second]) }
                XCTAssertEqual(meetings.count, 2)
                XCTAssertEqual(meetings.filter { $0.homeTeamID == first }.count, 1)
                XCTAssertEqual(meetings.filter { $0.homeTeamID == second }.count, 1)
            }
        }
    }

    func testEveryClubHasSixteenPlayersAndSuggestedLineupsFitAllFormations() {
        let career = FootballGame.newCareer(seed: 42)
        XCTAssertEqual(career.teams.count, 8)
        XCTAssertTrue(career.teams.allSatisfy { $0.players.count == 16 })

        for team in career.teams {
            for formation in FootballFormation.allCases {
                let lineup = FootballGame.suggestedLineup(team: team, formation: formation)
                XCTAssertTrue(FootballGame.isValidLineup(lineup, team: team, formation: formation))
            }
        }
    }

    func testTacticsAndPlayerSelectionChangeTeamRatings() throws {
        let career = FootballGame.newCareer(seed: 19)
        let team = career.teams[career.userTeamID]
        let balanced = FootballGame.teamRatings(
            team: team,
            lineup: career.startingLineup,
            formation: career.formation,
            approach: .balanced
        )
        let attacking = FootballGame.teamRatings(
            team: team,
            lineup: career.startingLineup,
            formation: career.formation,
            approach: .attacking
        )
        XCTAssertGreaterThan(attacking.attack, balanced.attack)
        XCTAssertLessThan(attacking.defense, balanced.defense)
        let alternateFormation = FootballGame.teamRatings(
            team: team,
            lineup: career.startingLineup,
            formation: .fourFourTwo,
            approach: .balanced
        )
        XCTAssertNotEqual(alternateFormation, balanced)

        let reserveForward = try XCTUnwrap(team.players.first {
            $0.position == .forward && !career.startingLineup.contains($0.id)
        })
        let weakestStarter = try XCTUnwrap(team.players
            .filter { $0.position == .forward && career.startingLineup.contains($0.id) }
            .min { $0.overall < $1.overall })
        var changedLineup = career.startingLineup.filter { $0 != weakestStarter.id }
        changedLineup.append(reserveForward.id)
        XCTAssertTrue(FootballGame.isValidLineup(changedLineup, team: team, formation: career.formation))

        var improvedTeam = team
        let reserveIndex = try XCTUnwrap(improvedTeam.players.firstIndex(where: { $0.id == reserveForward.id }))
        improvedTeam.players[reserveIndex].attack = 95
        improvedTeam.players[reserveIndex].passing = 95
        improvedTeam.players[reserveIndex].stamina = 95
        let changedRatings = FootballGame.teamRatings(
            team: improvedTeam,
            lineup: changedLineup,
            formation: career.formation,
            approach: .balanced
        )
        XCTAssertGreaterThan(changedRatings.attack, balanced.attack)
    }

    func testStandingsAreCalculatedFromPlayedResults() throws {
        var career = FootballGame.newCareer(seed: 7)
        let fixtureIndex = try XCTUnwrap(career.fixtures.firstIndex(where: { $0.round == 1 }))
        let fixture = career.fixtures[fixtureIndex]
        career.fixtures[fixtureIndex].result = FootballMatchResult(homeGoals: 2, awayGoals: 0, goalEvents: [])

        let table = FootballGame.standings(for: career)
        let home = try XCTUnwrap(table.first { $0.teamID == fixture.homeTeamID })
        let away = try XCTUnwrap(table.first { $0.teamID == fixture.awayTeamID })
        XCTAssertEqual(home.played, 1)
        XCTAssertEqual(home.wins, 1)
        XCTAssertEqual(home.points, 3)
        XCTAssertEqual(home.goalDifference, 2)
        XCTAssertEqual(away.losses, 1)
        XCTAssertEqual(away.points, 0)
        XCTAssertEqual(table.filter { $0.played > 0 }.count, 2)
    }

    func testStandingsPrioritizeWinsBeforeGoalDifference() throws {
        var career = FootballGame.newCareer(seed: 9)
        let targetFixtures = career.fixtures.indices.filter { index in
            let fixture = career.fixtures[index]
            return fixture.round <= 3
                && (fixture.homeTeamID == 0 || fixture.awayTeamID == 0 || fixture.homeTeamID == 1 || fixture.awayTeamID == 1)
        }

        for index in targetFixtures {
            let fixture = career.fixtures[index]
            if fixture.homeTeamID == 0 || fixture.awayTeamID == 0 {
                let teamZeroWins = fixture.round == 3
                if fixture.homeTeamID == 0 {
                    career.fixtures[index].result = FootballMatchResult(homeGoals: teamZeroWins ? 1 : 0, awayGoals: teamZeroWins ? 0 : 3, goalEvents: [])
                } else {
                    career.fixtures[index].result = FootballMatchResult(homeGoals: teamZeroWins ? 0 : 3, awayGoals: teamZeroWins ? 1 : 0, goalEvents: [])
                }
            } else {
                career.fixtures[index].result = FootballMatchResult(homeGoals: 1, awayGoals: 1, goalEvents: [])
            }
        }

        let table = FootballGame.standings(for: career)
        let teamZero = try XCTUnwrap(table.first { $0.teamID == 0 })
        let teamOne = try XCTUnwrap(table.first { $0.teamID == 1 })
        XCTAssertEqual(teamZero.points, 3)
        XCTAssertEqual(teamZero.wins, 1)
        XCTAssertLessThan(teamZero.goalDifference, teamOne.goalDifference)
        XCTAssertEqual(teamZero.goalDifference, -5)
        XCTAssertEqual(teamOne.points, 3)
        XCTAssertEqual(teamOne.wins, 0)
        let zeroIndex = try XCTUnwrap(table.firstIndex(where: { $0.teamID == 0 }))
        let oneIndex = try XCTUnwrap(table.firstIndex(where: { $0.teamID == 1 }))
        XCTAssertLessThan(zeroIndex, oneIndex)
    }

    func testSimulatingRoundStoresFourResultsAndIsReproducible() {
        var firstCareer = FootballGame.newCareer(seed: 31)
        var secondCareer = FootballGame.newCareer(seed: 31)

        let firstReport = FootballGame.simulateNextRound(career: &firstCareer)
        let secondReport = FootballGame.simulateNextRound(career: &secondCareer)

        XCTAssertEqual(firstCareer, secondCareer)
        XCTAssertEqual(firstReport?.fixtures.count, 4)
        XCTAssertEqual(firstReport?.round, 1)
        XCTAssertEqual(firstCareer.completedRounds, 1)
        XCTAssertEqual(firstCareer.fixtures.filter { $0.round == 1 && $0.result != nil }.count, 4)
        XCTAssertEqual(firstCareer.fixtures.filter { $0.round == 2 && $0.result != nil }.count, 0)

        let startingPlayers = Set(firstCareer.startingLineup)
        let starters = firstCareer.teams[firstCareer.userTeamID].players.filter { startingPlayers.contains($0.id) }
        XCTAssertTrue(starters.allSatisfy { $0.condition < 100 })
    }

    func testOfflineTransferMarketSignsAndSellsReservePlayersWithinBudget() throws {
        var career = FootballGame.newCareer(seed: 16)
        let initialBudget = career.budget
        let initialMarketSize = career.marketPlayers.count
        let signing = try XCTUnwrap(career.marketPlayers.first)
        let fee = FootballGame.transferFee(for: signing)

        XCTAssertTrue(FootballGame.signPlayer(playerID: signing.id, career: &career))
        XCTAssertEqual(career.budget, initialBudget - fee)
        XCTAssertEqual(career.teams[career.userTeamID].players.count, 17)
        XCTAssertEqual(career.marketPlayers.count, initialMarketSize - 1)
        XCTAssertFalse(career.startingLineup.contains(signing.id))

        let saleValue = FootballGame.saleValue(for: signing)
        XCTAssertTrue(FootballGame.sellPlayer(playerID: signing.id, career: &career))
        XCTAssertEqual(career.budget, initialBudget - fee + saleValue)
        XCTAssertEqual(career.teams[career.userTeamID].players.count, 16)
        XCTAssertEqual(career.marketPlayers.count, initialMarketSize)
        XCTAssertTrue(FootballGame.isValidLineup(career.startingLineup, team: career.teams[career.userTeamID], formation: career.formation))
    }

    func testTransferWindowClosesAfterTheFirstRound() {
        var career = FootballGame.newCareer(seed: 28)
        let availablePlayerID = career.marketPlayers[0].id
        XCTAssertNotNil(FootballGame.simulateNextRound(career: &career))
        XCTAssertFalse(FootballGame.signPlayer(playerID: availablePlayerID, career: &career))
    }

    func testSeasonProgressionKeepsCareerHistoryAndDevelopsSquad() {
        var career = FootballGame.newCareer(seed: 4)
        for _ in 0..<FootballGame.numberOfRounds {
            XCTAssertNotNil(FootballGame.simulateNextRound(career: &career))
        }
        let previousSeason = career.seasonNumber
        let previousPlayer = career.teams[career.userTeamID].players[0]

        XCTAssertTrue(FootballGame.startNextSeason(career: &career))
        XCTAssertEqual(career.seasonNumber, previousSeason + 1)
        XCTAssertEqual(career.completedRounds, 0)
        XCTAssertEqual(career.history.count, 1)
        XCTAssertEqual(career.history[0].seasonNumber, previousSeason)
        XCTAssertGreaterThan(career.budget, 24_000_000)
        XCTAssertEqual(career.marketPlayers.count, 8)
        XCTAssertEqual(career.teams[career.userTeamID].players[0].age, previousPlayer.age + 1)
        XCTAssertEqual(career.teams[career.userTeamID].players[0].condition, 100)
        XCTAssertEqual(career.fixtures.filter { $0.result != nil }.count, 0)
    }

    // Fase 1: estatísticas, forma, artilharia e calendário (ver docs/roadmap.md).
    func testSimulatedMatchesRecordShotsAndPossessionDeterministically() {
        var firstCareer = FootballGame.newCareer(seed: 51)
        var secondCareer = FootballGame.newCareer(seed: 51)
        XCTAssertNotNil(FootballGame.simulateNextRound(career: &firstCareer))
        XCTAssertNotNil(FootballGame.simulateNextRound(career: &secondCareer))

        let firstResults = firstCareer.fixtures.filter { $0.round == 1 }.compactMap(\.result)
        XCTAssertEqual(firstResults.count, 4)
        for result in firstResults {
            XCTAssertTrue((0...30).contains(result.homeShots))
            XCTAssertTrue((0...30).contains(result.awayShots))
            XCTAssertTrue((20...80).contains(result.homePossession))
            XCTAssertGreaterThan(result.homeShots + result.awayShots, 0)
        }
        XCTAssertEqual(
            firstCareer.fixtures.filter { $0.round == 1 }.compactMap(\.result),
            secondCareer.fixtures.filter { $0.round == 1 }.compactMap(\.result)
        )
    }

    func testFormTopScorersAndCalendarHelpersStayConsistent() {
        var career = FootballGame.newCareer(seed: 77)
        XCTAssertNotNil(FootballGame.simulateNextRound(career: &career))
        XCTAssertNotNil(FootballGame.simulateNextRound(career: &career))

        // Calendário por rodada.
        XCTAssertEqual(FootballGame.fixturesForRound(1, in: career).count, 4)
        XCTAssertEqual(FootballGame.fixturesForRound(3, in: career).count, 4)
        // Próximos jogos do usuário partem da rodada 3.
        let upcoming = FootballGame.upcomingFixtures(for: career, limit: 3)
        XCTAssertEqual(upcoming.count, 3)
        XCTAssertTrue(upcoming.allSatisfy { $0.round > career.completedRounds })

        // Forma recente tem 2 entradas após 2 rodadas.
        let form = FootballGame.recentForm(teamID: career.userTeamID, in: career)
        XCTAssertEqual(form.count, 2)
        XCTAssertTrue(form.allSatisfy { ["V", "E", "D"].contains($0) })

        // Artilharia soma exatamente os gols registrados nos eventos.
        let scorers = FootballGame.topScorers(in: career, limit: 128)
        let totalGoals = career.fixtures.compactMap(\.result).reduce(0) { $0 + $1.homeGoals + $1.awayGoals }
        XCTAssertEqual(scorers.reduce(0) { $0 + $1.goals }, totalGoals)
        XCTAssertTrue(scorers.allSatisfy { $0.goals > 0 })
        XCTAssertLessThanOrEqual(FootballGame.topScorers(in: career, limit: 5).count, 5)
    }

    func testCareerSaveRestoresAndMigratesLegacyRoundAndSeed() throws {
        let suiteName = "FootballCareerTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(12, forKey: "football.seed")
        defaults.set(2, forKey: "football.currentRound")

        let migrated = FootballCareerStore.load(defaults: defaults)
        XCTAssertEqual(migrated.seed, 12)
        XCTAssertEqual(migrated.completedRounds, 2)
        XCTAssertEqual(migrated.fixtures.filter { $0.result != nil }.count, 8)

        var careerWithTransfer = FootballGame.newCareer(seed: migrated.seed)
        let signing = try XCTUnwrap(careerWithTransfer.marketPlayers.first)
        XCTAssertTrue(FootballGame.signPlayer(playerID: signing.id, career: &careerWithTransfer))
        FootballCareerStore.save(careerWithTransfer, defaults: defaults)
        XCTAssertEqual(FootballCareerStore.load(defaults: defaults), careerWithTransfer)
    }
}
