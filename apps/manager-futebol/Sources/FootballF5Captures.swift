import SwiftUI

/// Rotas de captura da F5: a tela nova já no topo, sem rolar.
enum FootballF5Captures {
    static let names: Set<String> = ["league-insight", "fantasy-insight", "betting-insight", "goals-origin", "trophy-legacy", "settings-phone"]

    static func prepare(_ name: String, career: inout FootballCareer) {
        switch name {
        case "league-insight":
            // Algumas rodadas jogadas para haver forma, confronto e calendário restante.
            for _ in 0..<4 where career.canPlay || career.canAdvanceWithoutPlaying { career.simulateNextMatchDay() }
        case "fantasy-insight":
            let suggestion = career.suggestedFantasyLineup()
            _ = career.setFantasyLineup(ids: suggestion.ids, captainID: suggestion.captainID)
            if let athlete = career.player(suggestion.ids.last ?? -1), let index = career.players.firstIndex(where: { $0.id == athlete.id }) {
                career.players[index].condition = 55
            }
        case "betting-insight":
            if let fixture = career.bettingFixtures.first(where: { !$0.involves(career.selectedClubID ?? -1) }),
               let option = career.options(for: fixture).first {
                _ = career.placeBet(stake: 50, legs: [option.leg])
                if career.canPlay || career.canAdvanceWithoutPlaying { career.simulateNextMatchDay() }
            }
        case "goals-origin":
            career.adoptGoal(templateID: "w-wins")
            career.bump("wins")
            var random = FootballRandom(seed: 5)
            career.refreshQuests(using: &random)
        case "trophy-legacy":
            var fixture = LeagueFixture(id: 9_501, matchDay: career.matchDayIndex, round: 3, competition: .league(career.userDivision ?? .serieA),
                                        home: career.selectedClubID ?? 0, away: (career.selectedClubID ?? 0) == 1 ? 2 : 1)
            fixture.homeGoals = 3
            fixture.awayGoals = 0
            career.counters["wins"] = 1
            career.records.longestWinStreak = 4
            career.checkAchievements(fixture: fixture)
            career.setHighlight(.firstWin, on: true)
        case "settings-phone":
            career.logActionResult("Bilhete feito! Resultado depois dos jogos.", appID: "betting")
            career.logActionResult("Escalação salva! O capitão pontua 1,5×.", appID: "fantasy")
            career.world.phone.preferences.minimumPriority = 2
            career.world.phone.preferences.mutedApps = ["betting"]
            if let scenario = ChallengeScenario.all.first {
                // Como no início real do desafio: a dificuldade do cenário passa a valer na carreira.
                career.difficulty = scenario.difficulty
                career.challenge = ChallengeState(scenarioID: scenario.id, startSeason: career.season, seasonsAllowed: scenario.seasonsAllowed)
            }
        default:
            break
        }
    }
}

struct FootballF5CaptureView: View {
    let name: String
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        switch name {
        case "league-insight":
            VStack(alignment: .leading, spacing: 18) {
                FootballLeagueInsightPanel(career: career, division: career.userDivision ?? .serieA)
            }
            .factoryPage()
            .navigationTitle("Liga")
        case "fantasy-insight":
            FootballFantasyView(career: $career, onAlert: onAlert, captureFocus: true)
        case "betting-insight":
            FootballBettingView(career: $career, onAlert: onAlert, captureFocus: true)
        case "trophy-legacy":
            FootballAchievementsView(career: $career)
        case "settings-phone":
            FootballModesView(career: $career, onStartChallenge: { _ in }, onAlert: onAlert)
        default:
            VStack(alignment: .leading, spacing: 18) {
                FootballGoalsPlannerPanel(career: $career)
                FootballGoalsHistoryPanel(career: career)
            }
            .factoryPage()
            .navigationTitle("Metas")
        }
    }
}
