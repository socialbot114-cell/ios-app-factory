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
}
