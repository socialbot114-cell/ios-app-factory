import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballLeagueAnalysisTests: XCTestCase {
    private func row(_ id: Int, played: Int, points: Int) -> FootballStanding {
        var standing = FootballStanding(team: FootballSeason.team(id)!)
        standing.played = played
        standing.points = points
        return standing
    }

    func testTitleClinchedWhenNoRivalCanReach() {
        let table = [row(0, played: 16, points: 40)] + (1..<10).map { row($0, played: 16, points: 20) }
        // rivais chegam a 26 no máximo
        XCTAssertEqual(FootballLeagueAnalysis.status(for: 0, in: table, topPositions: 1), .clinched)
    }

    func testTitleOpenReportsPointsNeeded() {
        let table = [row(0, played: 16, points: 30), row(1, played: 16, points: 29)] + (2..<10).map { row($0, played: 16, points: 10) }
        // rival chega a 35; precisa de 36 -> faltam 6, mas só restam 6 pontos possíveis
        XCTAssertEqual(FootballLeagueAnalysis.status(for: 0, in: table, topPositions: 1), .open(pointsToSecure: 6))
    }

    func testTitleImpossibleWhenRivalAlreadyAboveMaximum() {
        let table = [row(0, played: 17, points: 10), row(1, played: 17, points: 50)] + (2..<10).map { row($0, played: 17, points: 5) }
        XCTAssertEqual(FootballLeagueAnalysis.status(for: 0, in: table, topPositions: 1), .impossible)
    }

    func testRelegationScenarioUsesBottomSpots() {
        let table = (0..<8).map { row($0, played: 16, points: 30) } + [row(8, played: 16, points: 5), row(9, played: 16, points: 4)]
        let scenarios = FootballLeagueAnalysis.scenarios(table: table, division: .serieA, teamID: 9)
        let safety = scenarios.first { $0.goal == .avoidRelegation }
        XCTAssertEqual(safety?.status, .impossible)
    }

    func testHeadToHeadCountsOnlyPlayedLeagueMeetings() {
        let division = Division.serieA
        var a = LeagueFixture(id: 1, matchDay: 0, round: 1, competition: .league(division), home: 0, away: 1)
        a.homeGoals = 2; a.awayGoals = 1
        var b = LeagueFixture(id: 2, matchDay: 1, round: 2, competition: .league(division), home: 1, away: 0)
        b.homeGoals = 1; b.awayGoals = 1
        let pending = LeagueFixture(id: 3, matchDay: 2, round: 3, competition: .league(division), home: 0, away: 1)
        let record = FootballLeagueAnalysis.headToHead(0, against: 1, fixtures: [a, b, pending])
        XCTAssertEqual(record, .init(wins: 1, draws: 1, losses: 0, goalsFor: 3, goalsAgainst: 2))
    }

    func testDifficultyRanksRemainingOpponents() {
        let career = FootballCareer(seed: 7)
        let ids = career.teamIDs(in: .serieA)
        let fixtures = career.fixtures.filter { $0.competition == .league(.serieA) }
        let results = ids.map { FootballLeagueAnalysis.difficulty(of: $0, among: ids, fixtures: fixtures) }
        XCTAssertTrue(results.allSatisfy { $0.remainingMatches == 18 })
        XCTAssertTrue(results.allSatisfy { (1...10).contains($0.rank ?? 0) })
        // Sem jogos pendentes não há dificuldade a mostrar.
        XCTAssertNil(FootballLeagueAnalysis.difficulty(of: ids[0], among: ids, fixtures: []).rank)
    }
}
