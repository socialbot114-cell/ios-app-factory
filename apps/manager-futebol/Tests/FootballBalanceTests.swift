import Foundation
import XCTest
@testable import ManagerFutebol

/// Metas numéricas de balanceamento. Uma mudança no motor que tire a liga destas faixas falha no CI.
final class FootballBalanceTests: XCTestCase {
    func testLeagueBalanceStaysWithinTargets() {
        var goals = 0
        var matches = 0
        var leagueMatches = 0
        var homeWins = 0
        var draws = 0
        var shots = 0
        var onTarget = 0
        var yellow = 0
        var red = 0
        var corners = 0
        var fouls = 0
        var championPoints = 0
        var relegatedPoints = 0
        var strongestTitles = 0
        var cupUpsets = 0
        var cupTies = 0
        let seasons = 10
        for seed in 1...seasons {
            var career = FootballCareer(seed: seed * 7_919)
            XCTAssertTrue(career.chooseClub(15))
            for _ in 0..<FootballSeason.matchDaysPerSeason { career.simulateNextMatchDay() }
            for fixture in career.fixtures {
                guard let home = fixture.homeGoals, let away = fixture.awayGoals else { continue }
                goals += home + away
                matches += 1
                shots += (fixture.homeShots ?? 0) + (fixture.awayShots ?? 0)
                onTarget += (fixture.homeOnTarget ?? 0) + (fixture.awayOnTarget ?? 0)
                yellow += (fixture.homeYellow ?? 0) + (fixture.awayYellow ?? 0)
                red += (fixture.homeRed ?? 0) + (fixture.awayRed ?? 0)
                corners += (fixture.homeCorners ?? 0) + (fixture.awayCorners ?? 0)
                fouls += (fixture.homeFouls ?? 0) + (fixture.awayFouls ?? 0)
                if fixture.competition.division != nil {
                    leagueMatches += 1
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
        let perMatch = Double(matches)
        let averageGoals = Double(goals) / perMatch
        let homeWinRate = Double(homeWins) / Double(leagueMatches)
        let drawRate = Double(draws) / Double(leagueMatches)
        let championAverage = Double(championPoints) / Double(seasons)
        let safetyAverage = Double(relegatedPoints) / Double(seasons)
        print("BALANCE goals \(averageGoals) home \(homeWinRate) draws \(drawRate) shots \(Double(shots) / perMatch) onTarget \(Double(onTarget) / perMatch) yellow \(Double(yellow) / perMatch) red \(Double(red) / perMatch) corners \(Double(corners) / perMatch) fouls \(Double(fouls) / perMatch) champion \(championAverage) safety \(safetyAverage) strongestTitles \(strongestTitles)/\(seasons) cupUpsets \(cupUpsets)/\(cupTies)")

        XCTAssertTrue((2.5...3.2).contains(averageGoals), "Média de gols fora da faixa: \(averageGoals)")
        XCTAssertTrue((0.36...0.52).contains(homeWinRate), "Vitórias do mandante fora da faixa: \(homeWinRate)")
        XCTAssertTrue((0.18...0.32).contains(drawRate), "Empates fora da faixa: \(drawRate)")
        XCTAssertTrue((22.0...34.0).contains(Double(shots) / perMatch), "Finalizações por jogo fora da faixa")
        XCTAssertTrue((8.0...14.0).contains(Double(onTarget) / perMatch), "Finalizações no alvo fora da faixa")
        XCTAssertTrue((3.0...5.5).contains(Double(yellow) / perMatch), "Amarelos por jogo fora da faixa")
        XCTAssertTrue((0.05...0.30).contains(Double(red) / perMatch), "Vermelhos por jogo fora da faixa")
        XCTAssertTrue((8.0...13.0).contains(Double(corners) / perMatch), "Escanteios por jogo fora da faixa")
        XCTAssertTrue((18.0...30.0).contains(Double(fouls) / perMatch), "Faltas por jogo fora da faixa")
        XCTAssertTrue((32...46).contains(championAverage), "Pontos do campeão fora da faixa: \(championAverage)")
        XCTAssertTrue((14...28).contains(safetyAverage), "Pontos do 8º colocado fora da faixa: \(safetyAverage)")
        XCTAssertLessThanOrEqual(strongestTitles, seasons * 11 / 20, "O clube mais forte não pode vencer mais de 55% das temporadas")
        XCTAssertGreaterThan(cupUpsets, 0, "A copa precisa ter zebras")
    }
}
