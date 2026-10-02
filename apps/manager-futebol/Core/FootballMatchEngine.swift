import Foundation

// MARK: - Motor de partida

struct GoalRecord: Equatable {
    let minute: Int
    let scorerID: Int
    let assistID: Int?
}

struct MatchSide {
    let teamID: Int
    let lineup: [FootballPlayer]
    let formation: FootballFormation
    let style: FootballPlayStyle
    let opponentStyle: FootballPlayStyle
    let isHome: Bool

    /// Deslocamentos médios dos compostos de setor em relação ao geral (medidos em simulação), para calibrar o motor.
    static let attackOffset = -2.2
    static let defenseOffset = -1.4
    static let controlOffset = -1.8

    var rating: Double { FootballSeason.rating(of: lineup, formation: formation) }

    private func composite(weights: [FootballPosition: Double], value: (FootballPlayer) -> Double) -> Double {
        let assignments = FootballSeason.assignSlots(lineup: lineup, formation: formation)
        var numerator = 0.0
        var denominator = 0.0
        for assignment in assignments {
            let weight = weights[assignment.slot, default: 0]
            guard weight > 0 else { continue }
            numerator += weight * (value(assignment.player) * assignment.player.effectiveOverall / Double(max(1, assignment.player.overall)) - assignment.fit.penalty)
            denominator += weight
        }
        return denominator > 0 ? numerator / denominator : rating
    }

    private func delta(_ composite: Double, offset: Double) -> Double {
        min(6, max(-6, (composite - rating - offset) * 0.6))
    }

    /// Diferença bruta (composto menos geral) de cada setor, usada para calibrar os deslocamentos.
    var rawSectorDifferences: (attack: Double, defense: Double, control: Double) {
        let a = composite(weights: [.forward: 3, .midfielder: 1.5, .defender: 0.3]) { $0.attributes.attackComposite } - rating
        let d = composite(weights: [.goalkeeper: 2.5, .defender: 2, .midfielder: 0.8, .forward: 0.2]) { player in
            player.position == .goalkeeper ? player.attributes.goalkeeperComposite : player.attributes.defenseComposite
        } - rating
        let c = composite(weights: [.midfielder: 2, .defender: 0.6, .forward: 0.6, .goalkeeper: 0.3]) { $0.attributes.controlComposite } - rating
        return (a, d, c)
    }

    var attackSector: Double {
        delta(composite(weights: [.forward: 3, .midfielder: 1.5, .defender: 0.3]) { $0.attributes.attackComposite }, offset: Self.attackOffset)
    }

    var defenseSector: Double {
        delta(composite(weights: [.goalkeeper: 2.5, .defender: 2, .midfielder: 0.8, .forward: 0.2]) { player in
            player.position == .goalkeeper ? player.attributes.goalkeeperComposite : player.attributes.defenseComposite
        }, offset: Self.defenseOffset)
    }

    var controlSector: Double {
        delta(composite(weights: [.midfielder: 2, .defender: 0.6, .forward: 0.6, .goalkeeper: 0.3]) { $0.attributes.controlComposite }, offset: Self.controlOffset)
    }

    var attack: Double {
        rating + attackSector + Double(formation.attackBonus + style.attackAdjustment + style.attackBonus(against: opponentStyle)) + (isHome ? 1.5 : 0)
    }

    var defense: Double {
        rating + defenseSector + Double(formation.defenseBonus + style.defenseAdjustment) + (isHome ? 1 : 0)
    }

    var control: Double {
        rating + controlSector + Double(formation.midfieldBonus + style.controlAdjustment) + (isHome ? 1 : 0)
    }
}

struct HalfResult {
    var homeGoals: [GoalRecord] = []
    var awayGoals: [GoalRecord] = []
    var homeShots = 0
    var awayShots = 0
    var homeOnTarget = 0
    var awayOnTarget = 0
    var homeExpectedGoals = 0.0
    var awayExpectedGoals = 0.0
    var homePossession = 50
    var events: [MatchEvent] = []
}

enum FootballMatchEngine {
    /// Gols esperados em um tempo. Diferença de 20 pontos entre ataque e defesa multiplica as chances por e.
    static func expectedGoals(attack: Double, defense: Double, possessionShare: Double) -> Double {
        let value = 0.62 * exp((attack - defense) / 20) * pow(possessionShare / 0.5, 0.35)
        return min(1.9, max(0.04, value))
    }

    /// Arredonda para duas casas, mantendo o save estável e legível.
    static func rounded(_ value: Double) -> Double {
        (max(0.04, value) * 100).rounded() / 100
    }

    static func possessionShare(home: MatchSide, away: MatchSide, noise: Double) -> Double {
        min(0.7, max(0.3, 0.5 + (home.control - away.control) * 0.015 + noise))
    }

    /// Simula um período. `half` 1 e 2 são os tempos normais; 3 é a prorrogação (91–120, ritmo menor).
    static func simulateHalf(home: MatchSide, away: MatchSide, half: Int, narrate: Bool,
                             using random: inout FootballRandom) -> HalfResult {
        var result = HalfResult()
        let share = possessionShare(home: home, away: away, noise: Double(random.int(in: -3...3)) / 100)
        let periodFactor = half == 3 ? 0.55 : 1.0
        result.homePossession = Int((share * 100).rounded())
        result.homeExpectedGoals = rounded(expectedGoals(attack: home.attack, defense: away.defense, possessionShare: share) * periodFactor)
        result.awayExpectedGoals = rounded(expectedGoals(attack: away.attack, defense: home.defense, possessionShare: 1 - share) * periodFactor)

        let minutes: ClosedRange<Int>
        switch half {
        case 1: minutes = 1...45
        case 2: minutes = 46...90
        default: minutes = 91...120
        }
        let homeGoalCount = random.poisson(lambda: result.homeExpectedGoals)
        let awayGoalCount = random.poisson(lambda: result.awayExpectedGoals)
        result.homeGoals = (0..<homeGoalCount).map { _ in goal(for: home.lineup, minutes: minutes, using: &random) }
        result.awayGoals = (0..<awayGoalCount).map { _ in goal(for: away.lineup, minutes: minutes, using: &random) }
        result.homeGoals.sort { $0.minute < $1.minute }
        result.awayGoals.sort { $0.minute < $1.minute }

        result.homeShots = homeGoalCount + Int((result.homeExpectedGoals * 7).rounded()) + random.int(in: 0...3)
        result.awayShots = awayGoalCount + Int((result.awayExpectedGoals * 7).rounded()) + random.int(in: 0...3)
        result.homeOnTarget = homeGoalCount + random.int(in: 0...max(0, (result.homeShots - homeGoalCount) / 2))
        result.awayOnTarget = awayGoalCount + random.int(in: 0...max(0, (result.awayShots - awayGoalCount) / 2))

        if narrate {
            result.events = narration(home: home, away: away, result: result, minutes: minutes, using: &random)
        }
        return result
    }

    private static func goal(for lineup: [FootballPlayer], minutes: ClosedRange<Int>, using random: inout FootballRandom) -> GoalRecord {
        let scoringWeights = lineup.map { Int(Double($0.position.scoringWeight * max(1, $0.attributes[.finishing] * 3 + $0.overall - 60)) * ($0.has(.naturalFinisher) ? 1.35 : 1.0)) }
        let scorer: FootballPlayer? = random.weightedIndex(scoringWeights).map { lineup[$0] }
            ?? lineup.first(where: { $0.position != .goalkeeper })
            ?? lineup.first
        let scorerID = scorer?.id ?? -1
        var assistID: Int?
        if random.chance(0.72) {
            let mates = lineup.filter { $0.id != scorerID }
            let assistWeights = mates.map { $0.position.assistWeight * max(1, $0.attributes[.passing] * 3 + $0.attributes[.vision] * 2 + $0.overall / 2 - 40) }
            if let index = random.weightedIndex(assistWeights) { assistID = mates[index].id }
        }
        return GoalRecord(minute: random.int(in: minutes), scorerID: scorerID, assistID: assistID)
    }

    private static func narration(home: MatchSide, away: MatchSide, result: HalfResult, minutes: ClosedRange<Int>,
                                  using random: inout FootballRandom) -> [MatchEvent] {
        var events: [MatchEvent] = []
        let sides: [(MatchSide, MatchSide, [GoalRecord], Int, Int)] = [
            (home, away, result.homeGoals, result.homeShots, result.homeOnTarget),
            (away, home, result.awayGoals, result.awayShots, result.awayOnTarget)
        ]
        for (side, rival, goals, shots, onTarget) in sides {
            let teamName = FootballSeason.teamName(side.teamID)
            for goal in goals {
                let scorer = side.lineup.first { $0.id == goal.scorerID }?.name ?? "Atleta"
                var text = "GOL! \(scorer) marca para o \(teamName)"
                if let assistID = goal.assistID, let assist = side.lineup.first(where: { $0.id == assistID }) {
                    text += ", após passe de \(assist.name)."
                } else {
                    text += "."
                }
                events.append(MatchEvent(minute: goal.minute, kind: .goal, teamID: side.teamID, text: text))
            }
            let saves = min(2, max(0, onTarget - goals.count))
            let keeper = rival.lineup.first { $0.position == .goalkeeper }?.name ?? "o goleiro"
            for _ in 0..<saves {
                let shooter = shooterName(side.lineup, using: &random)
                let text = random.chance(0.5)
                    ? "\(keeper) faz grande defesa em chute de \(shooter)."
                    : "\(shooter) arrisca de fora da área e \(keeper) espalma."
                events.append(MatchEvent(minute: random.int(in: minutes), kind: .save, teamID: side.teamID, text: text))
            }
            let misses = min(1, max(0, shots - onTarget))
            for _ in 0..<misses {
                let shooter = shooterName(side.lineup, using: &random)
                let text = random.chance(0.5)
                    ? "\(shooter) finaliza por cima do travessão."
                    : "Chance do \(teamName): \(shooter) cabeceia rente à trave."
                events.append(MatchEvent(minute: random.int(in: minutes), kind: .chance, teamID: side.teamID, text: text))
            }
        }
        return events.sorted { $0.minute < $1.minute }
    }

    private static func shooterName(_ lineup: [FootballPlayer], using random: inout FootballRandom) -> String {
        let weights = lineup.map { $0.position.scoringWeight }
        guard let index = random.weightedIndex(weights) else { return "Atleta" }
        return lineup[index].name
    }

    // MARK: - Pênaltis

    struct ShootoutResult {
        let homeScore: Int
        let awayScore: Int
        let events: [MatchEvent]
    }

    /// Disputa de pênaltis: cinco cobranças alternadas e depois morte súbita.
    static func penaltyShootout(home: MatchSide, away: MatchSide, using random: inout FootballRandom) -> ShootoutResult {
        func takers(_ lineup: [FootballPlayer]) -> [FootballPlayer] {
            let ordered = lineup.sorted {
                let left = $0.position.scoringWeight * $0.overall
                let right = $1.position.scoringWeight * $1.overall
                if left != right { return left > right }
                return $0.id < $1.id
            }
            return ordered.isEmpty ? lineup : ordered
        }
        let homeTakers = takers(home.lineup)
        let awayTakers = takers(away.lineup)
        let homeKeeper = home.lineup.first { $0.position == .goalkeeper }
        let awayKeeper = away.lineup.first { $0.position == .goalkeeper }
        var homeScore = 0
        var awayScore = 0
        var events: [MatchEvent] = []

        func kick(taker: FootballPlayer?, keeper: FootballPlayer?, teamID: Int) -> Bool {
            let quality = Double((taker?.overall ?? 65) - (keeper?.overall ?? 65))
            let probability = min(0.88, max(0.55, 0.74 + quality * 0.004))
            let scored = random.chance(probability)
            let name = taker?.name ?? "Atleta"
            let keeperName = keeper?.name ?? "o goleiro"
            let text = scored ? "Pênalti convertido por \(name)." : (random.chance(0.6) ? "\(keeperName) defende a cobrança de \(name)!" : "\(name) manda para fora!")
            events.append(MatchEvent(minute: 120, kind: .penalties, teamID: teamID, text: text))
            return scored
        }

        for index in 0..<5 {
            if kick(taker: homeTakers.isEmpty ? nil : homeTakers[index % homeTakers.count], keeper: awayKeeper, teamID: home.teamID) { homeScore += 1 }
            if homeScore > awayScore + (5 - index) { break }
            if kick(taker: awayTakers.isEmpty ? nil : awayTakers[index % awayTakers.count], keeper: homeKeeper, teamID: away.teamID) { awayScore += 1 }
            let remaining = 4 - index
            if homeScore > awayScore + remaining || awayScore > homeScore + remaining { break }
        }
        var round = 5
        while homeScore == awayScore && round < 30 {
            let homeScored = kick(taker: homeTakers.isEmpty ? nil : homeTakers[round % homeTakers.count], keeper: awayKeeper, teamID: home.teamID)
            let awayScored = kick(taker: awayTakers.isEmpty ? nil : awayTakers[round % awayTakers.count], keeper: homeKeeper, teamID: away.teamID)
            if homeScored { homeScore += 1 }
            if awayScored { awayScore += 1 }
            round += 1
        }
        if homeScore == awayScore { homeScore += 1 }
        return ShootoutResult(homeScore: homeScore, awayScore: awayScore, events: events)
    }
}
