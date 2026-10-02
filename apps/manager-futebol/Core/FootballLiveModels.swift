import Foundation

// MARK: - Instruções de equipe

enum Level3: Int, Codable, CaseIterable, Identifiable {
    case low = 0, normal, high

    var id: Int { rawValue }
}

struct TeamInstructions: Codable, Equatable {
    var lineHeight: Level3 = .normal
    var tempo: Level3 = .normal
    var width: Level3 = .normal
    var pressing: Level3 = .normal
    var timeWasting = false

    static let lineHeightTitles = ["Linha baixa", "Linha média", "Linha alta"]
    static let tempoTitles = ["Ritmo lento", "Ritmo normal", "Ritmo rápido"]
    static let widthTitles = ["Estreito", "Normal", "Aberto"]
    static let pressingTitles = ["Pressão leve", "Pressão normal", "Pressão forte"]

    /// Ajustes em pontos de ataque, defesa e controle.
    var modifiers: (attack: Double, defense: Double, control: Double) {
        var attack = 0.0, defense = 0.0, control = 0.0
        switch lineHeight {
        case .low: defense += 1.5; attack -= 1.5; control -= 1
        case .normal: break
        case .high: attack += 1.5; defense -= 2; control += 1.5
        }
        switch tempo {
        case .low: control += 1.5; attack -= 1
        case .normal: break
        case .high: attack += 1.5; control -= 1
        }
        switch width {
        case .low: control += 1; attack -= 0.5
        case .normal: break
        case .high: attack += 1; defense -= 0.8
        }
        switch pressing {
        case .low: defense += 1
        case .normal: break
        case .high: control += 1.5; defense += 0.5
        }
        if timeWasting { attack -= 3 }
        return (attack, defense, control)
    }

    var fatigueFactor: Double {
        var factor = 1.0
        if tempo == .high { factor *= 1.12 } else if tempo == .low { factor *= 0.9 }
        if pressing == .high { factor *= 1.15 } else if pressing == .low { factor *= 0.9 }
        return factor
    }

    var foulFactor: Double {
        var factor = 1.0
        if pressing == .high { factor *= 1.25 } else if pressing == .low { factor *= 0.85 }
        if timeWasting { factor *= 1.15 }
        return factor
    }
}

// MARK: - Funções individuais

enum PlayerRole: String, Codable, CaseIterable, Identifiable {
    case balanced
    case fullbackAttacking, fullbackDefensive
    case ballPlayingDefender
    case destroyer, builder
    case playmaker
    case dribblingWinger, insideForward
    case poacher, targetMan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: return "Padrão"
        case .fullbackAttacking: return "Lateral ofensivo"
        case .fullbackDefensive: return "Lateral defensivo"
        case .ballPlayingDefender: return "Zagueiro construtor"
        case .destroyer: return "Volante destruidor"
        case .builder: return "Volante construtor"
        case .playmaker: return "Armador"
        case .dribblingWinger: return "Ponta driblador"
        case .insideForward: return "Ponta por dentro"
        case .poacher: return "Centroavante de área"
        case .targetMan: return "Pivô"
        }
    }

    /// Funções disponíveis para cada posição detalhada.
    static func options(for detail: PositionDetail) -> [PlayerRole] {
        switch detail {
        case .goalkeeper: return [.balanced]
        case .rightBack, .leftBack: return [.balanced, .fullbackAttacking, .fullbackDefensive]
        case .centreBack: return [.balanced, .ballPlayingDefender]
        case .defensiveMid: return [.balanced, .destroyer, .builder]
        case .centralMid: return [.balanced, .builder, .playmaker]
        case .attackingMid: return [.balanced, .playmaker, .insideForward]
        case .winger: return [.balanced, .dribblingWinger, .insideForward]
        case .striker: return [.balanced, .poacher, .targetMan]
        }
    }

    var modifiers: (attack: Double, defense: Double, control: Double) {
        switch self {
        case .balanced: return (0, 0, 0)
        case .fullbackAttacking: return (4, -3, 1)
        case .fullbackDefensive: return (-3, 4, 0)
        case .ballPlayingDefender: return (0, -1, 3)
        case .destroyer: return (0, 4, -1)
        case .builder: return (0, -1, 4)
        case .playmaker: return (3, 0, 3)
        case .dribblingWinger: return (4, -1, 0)
        case .insideForward: return (3, -1, 1)
        case .poacher: return (4, -1, -1)
        case .targetMan: return (2, 0, 1)
        }
    }

    /// Peso extra na escolha de quem finaliza.
    var shotWeight: Double {
        switch self {
        case .poacher: return 1.35
        case .insideForward: return 1.2
        case .targetMan: return 0.9
        default: return 1.0
        }
    }
}

// MARK: - Estado de uma partida

struct MatchSideState: Codable, Equatable {
    var teamID: Int
    var formation: FootballFormation
    var style: FootballPlayStyle
    var instructions = TeamInstructions()
    var onPitch: [Int]
    var bench: [Int]
    var removed: [Int] = []
    var roles: [Int: PlayerRole] = [:]
    var markTargetID: Int? = nil
    var penaltyTakerID: Int? = nil
    var isUserControlled = false
    var substitutionsUsed = 0
    var substitutionMinutes: [Int] = []
    var goals = 0
    var shots = 0
    var shotsOnTarget = 0
    var corners = 0
    var fouls = 0
    var yellowCards = 0
    var redCards = 0
    var expectedGoals = 0.0
    var possessionAccumulator = 0.0
    var attackBoost = 0.0
    var defenseBoost = 0.0
    var injuryFactor = 1.0
    var setPieceBoost = 0.0
    var matchCondition: [Int: Double]
    var stats: [Int: PlayerMatchStats] = [:]
    /// Atletas que já levaram amarelo na partida.
    var booked: [Int] = []
    /// Atletas que sofreram lesão na partida e quanto tempo ficam fora.
    var injuries: [Int: Int] = [:]
    var yellowCardIDs: [Int] = []
    var redCardIDs: [Int] = []
    var scorerIDs: [Int] = []
    var assistIDs: [Int] = []
    var appeared: [Int] = []
    var cachedAttack = 0.0
    var cachedDefense = 0.0
    var cachedControl = 0.0
    var cachedTypeWeights: [Double] = []
    var cachedShotMean = 0.0963
    var heat: [Int: [Int]] = [:]

    static let heatColumns = 4
    static let heatRows = 3
}

struct MatchSimulation: Codable, Equatable {
    static let maxSubstitutions = 5
    static let maxSubstitutionStops = 3

    let fixtureID: Int
    let seed: UInt64
    let isCup: Bool
    let isDerby: Bool
    let detailed: Bool
    var minute = 0
    var home: MatchSideState
    var away: MatchSideState
    var events: [MatchEvent] = []
    var momentum: [Int] = []
    var finished = false
    var inExtraTime = false
    var wentToExtraTime = false
    var needsShootout = false
    var needsRecompute = true
    var possessionShare = 0.5

    var homeGoals: Int { home.goals }
    var awayGoals: Int { away.goals }
    var regulationLength: Int { 90 }
}

/// Resultado final de uma partida, com tudo o que precisa ser aplicado à carreira.
struct MatchOutcome: Codable, Equatable {
    var fixtureID: Int
    var homeGoals: Int
    var awayGoals: Int
    var homeScorerIDs: [Int]
    var awayScorerIDs: [Int]
    var homeAssistIDs: [Int]
    var awayAssistIDs: [Int]
    var homeShots: Int
    var awayShots: Int
    var homeOnTarget: Int
    var awayOnTarget: Int
    var homeExpectedGoals: Double
    var awayExpectedGoals: Double
    var homePossession: Int
    var homeCorners: Int
    var awayCorners: Int
    var homeFouls: Int
    var awayFouls: Int
    var homeYellow: Int
    var awayYellow: Int
    var homeRed: Int
    var awayRed: Int
    var wentToExtraTime: Bool
    var homePenalties: Int?
    var awayPenalties: Int?
    var yellowCardIDs: [Int]
    var redCardIDs: [Int]
    var injuries: [Int: Int]
    var finalCondition: [Int: Int]
    var appeared: [Int]
    var homeGoalMinutes: [Int]
    var awayGoalMinutes: [Int]
    var events: [MatchEvent]
    var momentum: [Int]
    var homeLineupStart: [Int]
    var awayLineupStart: [Int]
    var homeLineupEnd: [Int]
    var awayLineupEnd: [Int]
    var homeStyle: FootballPlayStyle
    var awayStyle: FootballPlayStyle
    var userStats: [PlayerMatchStats]
    var heat: [Int: [Int]]
}

/// Partida do usuário em andamento, salva junto com a carreira.
struct LiveMatchState: Codable, Equatable {
    static let maxSubstitutions = MatchSimulation.maxSubstitutions
    static let maxSubstitutionStops = MatchSimulation.maxSubstitutionStops

    var sim: MatchSimulation
    var matchDay: Int
    var userIsHome: Bool
    var homeStart: [Int]
    var awayStart: [Int]
    /// Demais jogos do dia, já decididos e revelados minuto a minuto.
    var others: [MatchOutcome]
    var styleAtKickoff: FootballPlayStyle

    var fixtureID: Int { sim.fixtureID }
    var userSide: MatchSideState { userIsHome ? sim.home : sim.away }
    var substitutionsUsed: Int { userSide.substitutionsUsed }
    var substitutionStops: Int { Set(userSide.substitutionMinutes.filter { $0 != 45 }).count }
    var homeGoals: Int { sim.home.goals }
    var awayGoals: Int { sim.away.goals }
    var minute: Int { sim.minute }
    var events: [MatchEvent] { sim.events }

    /// Placar de outro jogo do dia no minuto atual.
    func score(of outcome: MatchOutcome, at minute: Int) -> (home: Int, away: Int) {
        (outcome.homeGoalMinutes.filter { $0 <= minute }.count, outcome.awayGoalMinutes.filter { $0 <= minute }.count)
    }
}
