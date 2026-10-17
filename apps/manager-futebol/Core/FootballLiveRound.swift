import Foundation

// MARK: - Outros jogos da rodada, ao vivo

/// Placar de outro jogo da rodada no minuto atual da partida do usuário.
struct LiveRoundGame: Identifiable, Equatable {
    let fixtureID: Int
    let homeID: Int
    let awayID: Int
    let homeScore: Int
    let awayScore: Int
    let competitionName: String
    let isCup: Bool
    /// O jogo envolve um clube vizinho do seu na tabela provisória (até duas posições acima ou abaixo).
    let isRelevant: Bool

    var id: Int { fixtureID }
}

/// Um gol em outro jogo, para o aviso curto durante a partida.
struct LiveGoalNotice: Identifiable, Equatable {
    let fixtureID: Int
    let minute: Int
    let scoringTeamID: Int
    let scorerName: String?
    let homeID: Int
    let awayID: Int
    let homeScore: Int
    let awayScore: Int
    let isRelevant: Bool

    var id: String { "\(fixtureID)-\(minute)-\(homeScore)-\(awayScore)" }

    /// "Maré Alta 1 × 0 Estrela do Sul · Davi 23'"
    var text: String {
        let home = FootballSeason.teamName(homeID)
        let away = FootballSeason.teamName(awayID)
        var line = "\(home) \(homeScore) × \(awayScore) \(away)"
        if let scorerName { line += " · \(scorerName) \(minute)'" }
        return line
    }
}

/// Posição do clube do usuário na tabela se os jogos terminassem agora.
struct LiveTablePosition: Equatable {
    let now: Int
    let before: Int

    var change: Int { before - now }
}

extension FootballCareer {
    /// Tabela provisória da divisão do usuário: a tabela de hoje com os placares dos jogos do dia no minuto indicado.
    func liveTable(_ live: LiveMatchState, minute: Int? = nil) -> [FootballStanding] {
        guard let division = userDivision else { return [] }
        let at = minute ?? live.sim.minute
        var games = fixtures.filter { $0.competition == .league(division) }
        for index in games.indices where games[index].matchDay == live.matchDay {
            if games[index].id == live.fixtureID {
                games[index].homeGoals = live.homeGoals
                games[index].awayGoals = live.awayGoals
            } else if let outcome = live.others.first(where: { $0.fixtureID == games[index].id }) {
                let score = live.score(of: outcome, at: at)
                games[index].homeGoals = score.home
                games[index].awayGoals = score.away
            }
        }
        return FootballSeason.standings(teamIDs: teamIDs(in: division), fixtures: games)
    }

    /// Posição provisória do clube do usuário e a de antes da rodada.
    func liveUserTablePosition(_ live: LiveMatchState) -> LiveTablePosition? {
        guard let selectedClubID, let division = userDivision else { return nil }
        let before = standings(for: division)
        let now = liveTable(live)
        guard let beforeIndex = before.firstIndex(where: { $0.team.id == selectedClubID }),
              let nowIndex = now.firstIndex(where: { $0.team.id == selectedClubID }) else { return nil }
        return LiveTablePosition(now: nowIndex + 1, before: beforeIndex + 1)
    }

    /// Os demais jogos da rodada, os que mexem perto do seu clube na tabela primeiro.
    func liveRoundGames(_ live: LiveMatchState) -> [LiveRoundGame] {
        let relevantTeams = liveRelevantTeamIDs(live)
        let games: [LiveRoundGame] = live.others.compactMap { outcome in
            guard let fixture = fixtures.first(where: { $0.id == outcome.fixtureID }) else { return nil }
            let score = live.score(of: outcome, at: live.sim.minute)
            return LiveRoundGame(fixtureID: fixture.id, homeID: fixture.home, awayID: fixture.away,
                                 homeScore: score.home, awayScore: score.away,
                                 competitionName: fixture.competition.isCup ? "Copa" : (fixture.competition.division?.name ?? ""),
                                 isCup: fixture.competition.isCup,
                                 isRelevant: relevantTeams.contains(fixture.home) || relevantTeams.contains(fixture.away))
        }
        return games.sorted { left, right in
            if left.isRelevant != right.isRelevant { return left.isRelevant }
            return left.fixtureID < right.fixtureID
        }
    }

    /// Gols de outros jogos entre `previousMinute` (exclusive) e `minute` (inclusive), do mais antigo ao mais novo.
    func liveGoalNotices(_ live: LiveMatchState, after previousMinute: Int, upTo minute: Int) -> [LiveGoalNotice] {
        guard minute > previousMinute else { return [] }
        let relevantTeams = liveRelevantTeamIDs(live)
        var notices: [LiveGoalNotice] = []
        for outcome in live.others {
            guard let fixture = fixtures.first(where: { $0.id == outcome.fixtureID }) else { continue }
            let relevant = relevantTeams.contains(fixture.home) || relevantTeams.contains(fixture.away)
            for (isHome, minutes, scorers) in [(true, outcome.homeGoalMinutes, outcome.homeScorerIDs),
                                               (false, outcome.awayGoalMinutes, outcome.awayScorerIDs)] {
                let ordered = minutes.sorted()
                for (index, goalMinute) in ordered.enumerated() where goalMinute > previousMinute && goalMinute <= minute {
                    // Os autores seguem a ordem dos gols quando a contagem fecha; senão o aviso vem sem nome.
                    let name = scorers.count == ordered.count ? player(scorers[index])?.lastName : nil
                    let score = live.score(of: outcome, at: goalMinute)
                    notices.append(LiveGoalNotice(fixtureID: fixture.id, minute: goalMinute,
                                                  scoringTeamID: isHome ? fixture.home : fixture.away, scorerName: name,
                                                  homeID: fixture.home, awayID: fixture.away,
                                                  homeScore: score.home, awayScore: score.away, isRelevant: relevant))
                }
            }
        }
        return notices.sorted { ($0.minute, $0.fixtureID) < ($1.minute, $1.fixtureID) }
    }

    /// Clubes até duas posições acima ou abaixo do seu na tabela provisória.
    private func liveRelevantTeamIDs(_ live: LiveMatchState) -> Set<Int> {
        guard let selectedClubID else { return [] }
        let table = liveTable(live)
        guard let mine = table.firstIndex(where: { $0.team.id == selectedClubID }) else { return [] }
        let range = max(0, mine - 2)...min(table.count - 1, mine + 2)
        return Set(table[range].map(\.team.id)).subtracting([selectedClubID])
    }
}
