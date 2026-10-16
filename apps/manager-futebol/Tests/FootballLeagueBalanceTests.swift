import Foundation
import XCTest
@testable import ManagerFutebol

/// Equilíbrio do campeonato: mando de campo, empates, gols e disputa pelo título.
/// As faixas vêm de simulações de 30 campeonatos (build 24) e são largas de propósito: com poucas temporadas
/// o acaso mexe alguns pontos percentuais. Se um ajuste de partida ou de mercado sair delas, vale medir de novo.
final class FootballLeagueBalanceTests: XCTestCase {
    private struct Totals {
        var matches = 0
        var homeWins = 0
        var draws = 0
        var awayWins = 0
        var goals = 0
        var bigScores = 0
        var champions: [Int] = []
        var strongestWon = 0
        var seasons = 0

        func share(_ value: Int) -> Double { matches == 0 ? 0 : Double(value) * 100 / Double(matches) }
    }

    private func simulate(seeds: ClosedRange<Int>) -> Totals {
        var totals = Totals()
        for seed in seeds {
            var career = FootballCareer(seed: seed)
            XCTAssertTrue(career.chooseClub(3))
            let strongest = FootballSeason.teams.filter { $0.initialDivision == .serieA }
                .max { career.teamRating($0.id) < career.teamRating($1.id) }?.id
            for _ in 0..<FootballSeason.matchDaysPerSeason { XCTAssertTrue(career.simulateNextMatchDay()) }
            for fixture in career.fixtures where fixture.isPlayed && fixture.competition.division != nil {
                let home = fixture.homeGoals ?? 0
                let away = fixture.awayGoals ?? 0
                totals.matches += 1
                totals.goals += home + away
                if home > away { totals.homeWins += 1 } else if home == away { totals.draws += 1 } else { totals.awayWins += 1 }
                if home + away >= 8 { totals.bigScores += 1 }
            }
            if let champion = career.standings(for: .serieA).first?.team.id {
                totals.champions.append(champion)
                totals.seasons += 1
                if champion == strongest { totals.strongestWon += 1 }
            }
        }
        return totals
    }

    func testHomeAdvantageDrawsAndGoalsStayInRealisticRanges() {
        let totals = simulate(seeds: 1...6)
        XCTAssertGreaterThan(totals.matches, 1_000)
        let home = totals.share(totals.homeWins)
        let draw = totals.share(totals.draws)
        let away = totals.share(totals.awayWins)
        let goals = Double(totals.goals) / Double(totals.matches)
        XCTAssertTrue((39...52).contains(home), "Mandante: \(home)%")
        XCTAssertTrue((21...32).contains(draw), "Empates: \(draw)%")
        XCTAssertTrue((24...37).contains(away), "Visitante: \(away)%")
        XCTAssertGreaterThan(home, away + 6, "Jogar em casa precisa fazer diferença")
        XCTAssertTrue((2.4...3.0).contains(goals), "Gols por jogo: \(goals)")
        XCTAssertLessThanOrEqual(totals.share(totals.bigScores), 2.5, "Jogos com 8 gols ou mais precisam ser raros")
    }

    func testTheTitleIsContestedAndNotAlwaysTheStrongestTeam() {
        let totals = simulate(seeds: 1...8)
        XCTAssertEqual(totals.seasons, 8)
        XCTAssertGreaterThanOrEqual(Set(totals.champions).count, 2, "Sempre o mesmo campeão tira a graça da liga")
        XCTAssertLessThan(totals.strongestWon, totals.seasons, "O time mais forte no papel não pode ganhar tudo")
    }
}
