import Foundation
import XCTest
@testable import ManagerFutebol

/// Metas numéricas de balanceamento. Uma mudança no motor que tire a liga destas faixas falha no CI.
final class FootballBalanceTests: XCTestCase {
    func testLeagueBalanceStaysWithinTargets() {
        var goals = 0
        var matches = 0
        var homeWins = 0
        var draws = 0
        var championPoints = 0
        var relegatedPoints = 0
        var strongestTitles = 0
        var cupUpsets = 0
        var cupTies = 0
        let seasons = 8
        for seed in 1...seasons {
            var career = FootballCareer(seed: seed * 7_919)
            XCTAssertTrue(career.chooseClub(15))
            for _ in 0..<FootballSeason.matchDaysPerSeason { career.simulateNextMatchDay() }
            for fixture in career.fixtures {
                guard let home = fixture.homeGoals, let away = fixture.awayGoals else { continue }
                goals += home + away
                matches += 1
                if fixture.competition.division != nil {
                    if home > away { homeWins += 1 } else if home == away { draws += 1 }
                } else if let winner = fixture.winner {
                    cupTies += 1
                    let loser = fixture.opponent(of: winner)
                    if career.division(of: winner) > career.division(of: loser) { cupUpsets += 1 }
                }
            }
            let tableA = career.standings(for: .serieA)
            championPoints += tableA.first?.points ?? 0
            relegatedPoints += tableA[tableA.count - 3].points
            if tableA.first?.team.id == 0 { strongestTitles += 1 }
            XCTAssertEqual(career.players.filter { $0.position == .goalkeeper }.reduce(0) { $0 + $1.goals }, 0)
        }
        let leagueMatches = Double(seasons * 180)
        let averageGoals = Double(goals) / Double(matches)
        let homeWinRate = Double(homeWins) / leagueMatches
        let drawRate = Double(draws) / leagueMatches
        let championAverage = Double(championPoints) / Double(seasons)
        let safetyAverage = Double(relegatedPoints) / Double(seasons)
        print("BALANCE goals \(averageGoals) home \(homeWinRate) draws \(drawRate) champion \(championAverage) safety \(safetyAverage) strongestTitles \(strongestTitles)/\(seasons) cupUpsets \(cupUpsets)/\(cupTies)")

        XCTAssertTrue((2.3...3.2).contains(averageGoals), "Média de gols fora da faixa: \(averageGoals)")
        XCTAssertTrue((0.36...0.52).contains(homeWinRate), "Vitórias do mandante fora da faixa: \(homeWinRate)")
        XCTAssertTrue((0.18...0.32).contains(drawRate), "Empates fora da faixa: \(drawRate)")
        XCTAssertTrue((32...46).contains(championAverage), "Pontos do campeão fora da faixa: \(championAverage)")
        XCTAssertTrue((14...28).contains(safetyAverage), "Pontos do 8º colocado fora da faixa: \(safetyAverage)")
        XCTAssertLessThanOrEqual(strongestTitles, seasons / 2, "O clube mais forte não pode vencer mais da metade das temporadas")
        XCTAssertGreaterThan(cupUpsets, 0, "A copa precisa ter zebras")
    }
}
