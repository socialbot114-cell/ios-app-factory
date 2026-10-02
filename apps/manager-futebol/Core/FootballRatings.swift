import Foundation

/// O que um atleta fez numa partida; as notas de 4,0 a 10,0 saem daqui.
struct PlayerMatchStats: Codable, Equatable, Identifiable {
    var playerID: Int
    var minutes = 0
    var goals = 0
    var assists = 0
    var shots = 0
    var shotsOnTarget = 0
    var saves = 0
    var tackles = 0
    var yellowCards = 0
    var redCard = false
    var rating = 6.0

    var id: Int { playerID }
}

enum FootballRatings {
    /// Nota da partida. `noiseSeed` mantém o resultado reproduzível.
    static func rating(for player: FootballPlayer, stats: PlayerMatchStats, goalsFor: Int, goalsAgainst: Int,
                       teamAverage: Double, noiseSeed: UInt64) -> Double {
        guard stats.minutes > 0 else { return 0 }
        var rating = 6.0
        if goalsFor > goalsAgainst { rating += 0.45 } else if goalsFor < goalsAgainst { rating -= 0.35 }
        rating += Double(stats.goals) * 1.1 + Double(stats.assists) * 0.7
        rating += Double(stats.tackles) * 0.08 + Double(stats.shotsOnTarget) * 0.12

        switch player.position {
        case .goalkeeper:
            if goalsAgainst == 0 { rating += 0.8 }
            rating += Double(stats.saves) * 0.18
            if goalsAgainst >= 3 { rating -= 0.6 }
        case .defender:
            if goalsAgainst == 0 { rating += 0.5 }
            if goalsAgainst >= 3 { rating -= 0.5 }
        case .midfielder:
            if goalsAgainst >= 4 { rating -= 0.3 }
        case .forward:
            if stats.goals == 0 && stats.shots >= 3 { rating -= 0.2 }
        }
        rating -= Double(stats.yellowCards) * 0.3
        if stats.redCard { rating -= 2.0 }

        rating += (player.effectiveOverall - teamAverage) * 0.03
        var random = FootballRandom(seed: noiseSeed &+ UInt64(player.id) &* 0x9E3779B97F4A7C15)
        let spread = Double(21 - player.attributes[.consistency]) / 20 * 0.8
        rating += (random.unit() * 2 - 1) * spread

        // Quem jogou pouco tem a nota puxada para o meio.
        if stats.minutes < 45 { rating = 6.0 + (rating - 6.0) * Double(stats.minutes) / 60 }
        return min(10, max(4, (rating * 10).rounded() / 10))
    }

    static func manOfTheMatch(_ stats: [PlayerMatchStats]) -> PlayerMatchStats? {
        stats.filter { $0.minutes > 0 }.max {
            if $0.rating != $1.rating { return $0.rating < $1.rating }
            return $0.goals < $1.goals
        }
    }
}
