import Foundation

// MARK: - Vitória grande (ANI-03)

/// Tamanho de uma vitória, para escolher a comemoração e a faixa do fim de jogo.
enum VictoryTier: Equatable {
    /// Vitória comum: comemoração de sempre.
    case regular
    /// Vitória que pesa: virada, clássico ou decisão de título, com saldo de um ou dois gols.
    case big
    /// Goleada: saldo de três gols ou mais.
    case goleada

    /// Texto curto da faixa de fim de jogo.
    var headline: String {
        switch self {
        case .regular: return "VITÓRIA"
        case .big: return "VITÓRIA GRANDE"
        case .goleada: return "GOLEADA"
        }
    }
}

/// O que se sabe de um jogo do clube quando ele termina.
struct VictoryContext: Equatable {
    var goalsFor: Int
    var goalsAgainst: Int
    /// O clube esteve perdendo em algum momento e ainda assim venceu.
    var cameFromBehind = false
    /// Clássico, pela regra do motor (FootballSeason.isDerby).
    var isClassic = false
    /// A partida decide o título.
    var decidesTitle = false
}

enum FootballVictory {
    /// Quão grande foi a vitória; nil quando o clube não venceu.
    static func tier(_ context: VictoryContext) -> VictoryTier? {
        let margin = context.goalsFor - context.goalsAgainst
        guard margin > 0 else { return nil }
        if margin >= 3 { return .goleada }
        if context.cameFromBehind || context.isClassic || context.decidesTitle { return .big }
        return .regular
    }

    /// A partida decide o título: é a última rodada da divisão e o clube está em 1º (ANI-03 v4).
    /// Sem calendário, sem tabela ou sem clube escolhido, não decide.
    static func decidesTitle(matchDay: Int, lastMatchDay: Int?, leaderID: Int?, clubID: Int?) -> Bool {
        guard let lastMatchDay, matchDay == lastMatchDay, let clubID else { return false }
        return leaderID == clubID
    }

    /// O clube esteve atrás no placar em algum momento, pela ordem dos gols (true quando o gol foi do clube).
    static func wasBehind(scorers: [Bool]) -> Bool {
        var ours = 0
        var theirs = 0
        for byClub in scorers {
            if byClub { ours += 1 } else { theirs += 1 }
            if theirs > ours { return true }
        }
        return false
    }
}

extension FootballCareer {
    /// Liga a regra ao calendário e à tabela da divisão do jogo (ANI-03 v4).
    /// Aproximação: a tabela é a de agora, no fim de jogo; se o resultado ou os outros jogos da rodada ainda não estiverem somados, a conta sai um passo atrás.
    func decidesTitle(fixtureID: Int) -> Bool {
        guard let fixture = fixtures.first(where: { $0.id == fixtureID }),
              case .league(let division) = fixture.competition else { return false }
        let lastMatchDay = fixtures.filter { $0.competition == fixture.competition }.map(\.matchDay).max()
        return FootballVictory.decidesTitle(matchDay: fixture.matchDay, lastMatchDay: lastMatchDay,
                                            leaderID: standings(for: division).first?.team.id, clubID: selectedClubID)
    }
}
