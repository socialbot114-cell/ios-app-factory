import Foundation

/// Análise derivada da tabela e do calendário (LIG-04, LIG-05). Só lê fatos já registrados:
/// resultados disputados e jogos restantes; não inventa probabilidades.
enum FootballLeagueAnalysis {
    enum Goal: Equatable {
        case title
        case promotion
        case avoidRelegation

        /// Posições finais que satisfazem a meta, para uma divisão de `size` clubes.
        func topPositions(size: Int) -> Int {
            switch self {
            case .title: return 1
            case .promotion: return FootballSeason.relegationSpots
            case .avoidRelegation: return size - FootballSeason.relegationSpots
            }
        }

        var title: String {
            switch self {
            case .title: return "Título"
            case .promotion: return "Acesso"
            case .avoidRelegation: return "Permanência"
            }
        }
    }

    enum Status: Equatable {
        case clinched
        case open(pointsToSecure: Int?)
        case impossible
    }

    struct Scenario: Equatable {
        let goal: Goal
        let teamID: Int
        let status: Status
    }

    /// Pontos máximos que o clube ainda pode somar.
    static func maxPoints(_ row: FootballStanding, leagueRounds: Int = FootballSeason.leagueRounds) -> Int {
        row.points + 3 * max(0, leagueRounds - row.played)
    }

    /// Empates de pontos contam contra o clube ao garantir e a favor ao descartar: o desempate
    /// (vitórias, saldo, gols) só se conhece no fim, então a análise fica conservadora.
    static func status(for teamID: Int, in table: [FootballStanding], topPositions: Int,
                       leagueRounds: Int = FootballSeason.leagueRounds) -> Status {
        guard let me = table.first(where: { $0.team.id == teamID }) else { return .impossible }
        let rivals = table.filter { $0.team.id != teamID }
        let threats = rivals.filter { maxPoints($0, leagueRounds: leagueRounds) >= me.points }.count
        if threats < topPositions { return .clinched }
        let ahead = rivals.filter { $0.points > maxPoints(me, leagueRounds: leagueRounds) }.count
        if ahead >= topPositions { return .impossible }
        // Pontos que tornam o clube seguro mesmo que todos os rivais vençam o restante.
        let needed = rivals.map { maxPoints($0, leagueRounds: leagueRounds) }.sorted(by: >)
        let target = needed.indices.contains(topPositions - 1) ? needed[topPositions - 1] + 1 : 0
        let missing = max(0, target - me.points)
        return .open(pointsToSecure: missing <= 3 * max(0, leagueRounds - me.played) ? missing : nil)
    }

    static func scenarios(table: [FootballStanding], division: Division, teamID: Int,
                          leagueRounds: Int = FootballSeason.leagueRounds) -> [Scenario] {
        let goals: [Goal]
        switch division {
        case .serieA: goals = [.title, .avoidRelegation]
        case .serieB: goals = [.promotion, .title]
        }
        return goals.map { goal in
            Scenario(goal: goal, teamID: teamID,
                     status: status(for: teamID, in: table, topPositions: goal.topPositions(size: table.count),
                                    leagueRounds: leagueRounds))
        }
    }

    // MARK: Confronto direto

    struct HeadToHead: Equatable {
        var wins = 0
        var draws = 0
        var losses = 0
        var goalsFor = 0
        var goalsAgainst = 0
        var meetings: Int { wins + draws + losses }
    }

    /// Confrontos de liga já disputados, do ponto de vista de `teamID`.
    static func headToHead(_ teamID: Int, against opponentID: Int, fixtures: [LeagueFixture]) -> HeadToHead {
        var record = HeadToHead()
        for fixture in fixtures where fixture.competition.division != nil
            && Set([fixture.home, fixture.away]) == Set([teamID, opponentID]) {
            guard let homeGoals = fixture.homeGoals, let awayGoals = fixture.awayGoals else { continue }
            let mine = fixture.home == teamID ? homeGoals : awayGoals
            let theirs = fixture.home == teamID ? awayGoals : homeGoals
            record.goalsFor += mine
            record.goalsAgainst += theirs
            if mine > theirs { record.wins += 1 } else if mine == theirs { record.draws += 1 } else { record.losses += 1 }
        }
        return record
    }

    // MARK: Dificuldade do calendário

    struct Difficulty: Equatable {
        let remainingMatches: Int
        /// Força média dos adversários restantes; nil sem jogos pendentes.
        let averageOpponentStrength: Double?
        /// Posição de 1 (mais difícil) até N entre os clubes da divisão; nil sem jogos pendentes.
        let rank: Int?
    }

    static func remainingOpponents(of teamID: Int, fixtures: [LeagueFixture]) -> [Int] {
        fixtures.filter { $0.competition.division != nil && !$0.isPlayed && $0.involves(teamID) }
            .map { $0.home == teamID ? $0.away : $0.home }
    }

    static func difficulty(of teamID: Int, among teamIDs: [Int], fixtures: [LeagueFixture]) -> Difficulty {
        func average(_ id: Int) -> Double? {
            let strengths = remainingOpponents(of: id, fixtures: fixtures).compactMap { FootballSeason.team($0)?.strength }
            return strengths.isEmpty ? nil : Double(strengths.reduce(0, +)) / Double(strengths.count)
        }
        let count = remainingOpponents(of: teamID, fixtures: fixtures).count
        guard let mine = average(teamID) else { return Difficulty(remainingMatches: 0, averageOpponentStrength: nil, rank: nil) }
        let harder = teamIDs.filter { $0 != teamID }.filter { (average($0) ?? -1) > mine }.count
        return Difficulty(remainingMatches: count, averageOpponentStrength: mine, rank: harder + 1)
    }
}
