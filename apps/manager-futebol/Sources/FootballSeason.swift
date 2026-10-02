import Foundation

enum FootballSeason {
    static let roundsPerSeason = 14
    static let matchesPerRound = 4

    static let teams: [LeagueTeam] = [
        .init(id: 0, name: "Aurora FC", shortName: "AUR", city: "Brasília", strength: 78, startingBudget: 8_000_000,
              preferredStyle: .possession, preferredFormation: .fourThreeThree),
        .init(id: 1, name: "Atlético Cerrado", shortName: "ACE", city: "Goiânia", strength: 73, startingBudget: 6_200_000,
              preferredStyle: .highPress, preferredFormation: .fourFourTwo),
        .init(id: 2, name: "Maré Alta", shortName: "MAR", city: "Salvador", strength: 75, startingBudget: 6_800_000,
              preferredStyle: .attacking, preferredFormation: .fourThreeThree),
        .init(id: 3, name: "União da Serra", shortName: "UNI", city: "Belo Horizonte", strength: 77, startingBudget: 7_500_000,
              preferredStyle: .balanced, preferredFormation: .fourTwoThreeOne),
        .init(id: 4, name: "Estrela do Sul", shortName: "EST", city: "Porto Alegre", strength: 74, startingBudget: 6_500_000,
              preferredStyle: .defensive, preferredFormation: .fourFourTwo),
        .init(id: 5, name: "Portuários", shortName: "POR", city: "Santos", strength: 71, startingBudget: 5_800_000,
              preferredStyle: .counter, preferredFormation: .fourFourTwo),
        .init(id: 6, name: "Capital Norte", shortName: "CAP", city: "Manaus", strength: 69, startingBudget: 5_000_000,
              preferredStyle: .counter, preferredFormation: .fourTwoThreeOne),
        .init(id: 7, name: "Vale Verde", shortName: "VAL", city: "Curitiba", strength: 72, startingBudget: 5_600_000,
              preferredStyle: .possession, preferredFormation: .fourTwoThreeOne)
    ]

    /// Premiação por posição final (1º ao 8º).
    static let prizeMoney: [Int] = [3_000_000, 2_200_000, 1_700_000, 1_300_000, 1_000_000, 800_000, 650_000, 500_000]
    static let objectiveBonus = 500_000

    private static let firstNames = [
        "Rafael", "Mateus", "Lucas", "André", "João", "Caio", "Bruno", "Davi",
        "Gabriel", "Pedro", "Igor", "Vinícius", "Daniel", "Marcos", "Felipe", "Renan",
        "Thiago", "Samuel", "Gustavo", "Enzo", "Luan", "Ruan", "Diego", "Alex",
        "Heitor", "Otávio", "Murilo", "Kauã", "Wesley", "Emerson", "Leandro", "Fábio",
        "Ítalo", "Breno", "Yuri", "Jonas", "Ramon", "Nícolas", "Arthur", "Cauê",
        "Edson", "Hugo", "Wallace", "Douglas", "Everton", "Jefferson", "Rodrigo", "Saulo"
    ]

    private static let lastNames = [
        "Nascimento", "Duarte", "Campos", "Ribeiro", "Nunes", "Oliveira", "Moura", "Barbosa",
        "Freitas", "Lima", "Teixeira", "Carvalho", "Mendes", "Azevedo", "Pereira", "Costa",
        "Cardoso", "Rocha", "Alves", "Farias", "Cavalcante", "Batista", "Gomes", "Monteiro",
        "Siqueira", "Pacheco", "Brandão", "Vasconcelos", "Peixoto", "Magalhães", "Sampaio", "Queiroz",
        "Tavares", "Bezerra", "Coutinho", "Assunção", "Prado", "Viana", "Leite", "Aragão",
        "Fontes", "Matos", "Rezende", "Xavier", "Barros", "Damasceno", "Guedes", "Lacerda"
    ]

    static func team(_ id: Int) -> LeagueTeam? {
        teams.first { $0.id == id }
    }

    static func teamName(_ id: Int) -> String {
        team(id)?.name ?? "Clube"
    }

    // MARK: - Calendário

    static func fixtures() -> [LeagueFixture] {
        let ids = teams.map(\.id)
        var firstLeg: [(Int, Int)] = []
        var rotating = ids
        for round in 0..<7 {
            for index in 0..<4 {
                let first = rotating[index]
                let second = rotating[7 - index]
                firstLeg.append(round.isMultiple(of: 2) ? (first, second) : (second, first))
            }
            let fixed = rotating[0]
            var rest = Array(rotating.dropFirst())
            let last = rest.removeLast()
            rest.insert(last, at: 0)
            rotating = [fixed] + rest
        }

        var output: [LeagueFixture] = []
        for round in 0..<roundsPerSeason {
            for match in 0..<matchesPerRound {
                let pair = firstLeg[(round % 7) * 4 + match]
                let home = round < 7 ? pair.0 : pair.1
                let away = round < 7 ? pair.1 : pair.0
                output.append(LeagueFixture(id: output.count, round: round + 1, home: home, away: away))
            }
        }
        return output
    }

    static func standings(results: [LeagueFixture]) -> [FootballStanding] {
        var table = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, FootballStanding(team: $0)) })
        for match in results.sorted(by: { $0.round < $1.round }) {
            guard let homeGoals = match.homeGoals, let awayGoals = match.awayGoals else { continue }
            guard var home = table[match.home], var away = table[match.away] else { continue }
            home.played += 1
            away.played += 1
            home.goalsFor += homeGoals
            home.goalsAgainst += awayGoals
            away.goalsFor += awayGoals
            away.goalsAgainst += homeGoals
            if homeGoals > awayGoals {
                home.wins += 1
                away.losses += 1
                home.points += 3
                home.form.append(.win)
                away.form.append(.loss)
            } else if homeGoals < awayGoals {
                away.wins += 1
                home.losses += 1
                away.points += 3
                home.form.append(.loss)
                away.form.append(.win)
            } else {
                home.draws += 1
                away.draws += 1
                home.points += 1
                away.points += 1
                home.form.append(.draw)
                away.form.append(.draw)
            }
            table[match.home] = home
            table[match.away] = away
        }

        return table.values.map { standing in
            var trimmed = standing
            trimmed.form = Array(standing.form.suffix(5))
            return trimmed
        }.sorted { lhs, rhs in
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
            if lhs.goalDifference != rhs.goalDifference { return lhs.goalDifference > rhs.goalDifference }
            if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
            return lhs.team.name < rhs.team.name
        }
    }

    // MARK: - Escalação e força

    /// Melhor escalação disponível (sem lesionados), considerando a condição física.
    /// Se faltar atleta de alguma posição, completa com os melhores restantes fora de posição.
    static func bestLineup(roster: [FootballPlayer], formation: FootballFormation) -> [Int] {
        let available = roster.filter { !$0.isInjured }
        var chosen: [Int] = []
        for position in FootballPosition.allCases {
            let required = formation.requiredPlayers[position, default: 0]
            let picks = available
                .filter { $0.position == position }
                .sorted(by: strongerFirst)
                .prefix(required)
                .map(\.id)
            chosen.append(contentsOf: picks)
        }
        if chosen.count < 11 {
            let extras = available
                .filter { !chosen.contains($0.id) }
                .sorted(by: strongerFirst)
                .prefix(11 - chosen.count)
                .map(\.id)
            chosen.append(contentsOf: extras)
        }
        return chosen
    }

    static func strongerFirst(_ lhs: FootballPlayer, _ rhs: FootballPlayer) -> Bool {
        if lhs.effectiveOverall != rhs.effectiveOverall { return lhs.effectiveOverall > rhs.effectiveOverall }
        return lhs.id < rhs.id
    }

    static func canFill(roster: [FootballPlayer], formation: FootballFormation) -> Bool {
        formation.requiredPlayers.allSatisfy { requirement in
            roster.filter { $0.position == requirement.key && !$0.isInjured }.count >= requirement.value
        }
    }

    /// Quantas vagas da formação estão ocupadas por atletas fora de posição.
    static func outOfPositionCount(lineup: [FootballPlayer], formation: FootballFormation) -> Int {
        formation.requiredPlayers.reduce(0) { total, requirement in
            let natural = lineup.filter { $0.position == requirement.key }.count
            return total + max(0, requirement.value - natural)
        }
    }

    /// Força média da escalação, com penalidade para improvisos e para ausência de goleiro.
    static func rating(of lineup: [FootballPlayer], formation: FootballFormation) -> Double {
        guard !lineup.isEmpty else { return 55 }
        var rating = lineup.map(\.effectiveOverall).reduce(0, +) / Double(lineup.count)
        rating -= Double(outOfPositionCount(lineup: lineup, formation: formation)) * 1.6
        if !lineup.contains(where: { $0.position == .goalkeeper }) { rating -= 6 }
        if lineup.count < 11 { rating -= Double(11 - lineup.count) * 4 }
        return rating
    }

    // MARK: - Valores e geração de atletas

    static func marketValue(overall: Int, age: Int, potential: Int) -> Int {
        let base = Double(max(150_000, (overall - 38) * (overall - 38) * 1_250))
        let ageFactor: Double
        switch age {
        case ...21: ageFactor = 1.4
        case 22...24: ageFactor = 1.2
        case 25...29: ageFactor = 1.0
        case 30...31: ageFactor = 0.8
        default: ageFactor = 0.55
        }
        let growth = age <= 24 ? 1 + Double(max(0, potential - overall)) * 0.02 : 1
        let value = base * ageFactor * growth
        return Int((value / 10_000).rounded()) * 10_000
    }

    static func randomName(using random: inout FootballRandom) -> String {
        let first = random.pick(firstNames) ?? "Atleta"
        let last = random.pick(lastNames) ?? "Silva"
        return "\(first) \(last)"
    }

    static func makePlayer(id: Int, position: FootballPosition, age: Int, overall: Int, potential: Int,
                           teamID: Int?, using random: inout FootballRandom) -> FootballPlayer {
        let clampedOverall = min(94, max(48, overall))
        let clampedPotential = min(96, max(clampedOverall, potential))
        return FootballPlayer(
            id: id,
            name: randomName(using: &random),
            position: position,
            age: age,
            overall: clampedOverall,
            potential: clampedPotential,
            condition: random.int(in: 84...100),
            marketValue: marketValue(overall: clampedOverall, age: age, potential: clampedPotential),
            teamID: teamID
        )
    }

    static func makeYouth(id: Int, position: FootballPosition, teamStrength: Int, teamID: Int?,
                          using random: inout FootballRandom) -> FootballPlayer {
        let overall = teamStrength - 15 + random.int(in: -4...5)
        return makePlayer(id: id, position: position, age: random.int(in: 17...19), overall: overall,
                          potential: overall + random.int(in: 10...22), teamID: teamID, using: &random)
    }

    static func makeFreeAgent(id: Int, position: FootballPosition, using random: inout FootballRandom) -> FootballPlayer {
        let overall = random.int(in: 61...77)
        let age = random.int(in: 19...32)
        let growth = age <= 23 ? random.int(in: 4...14) : random.int(in: 0...5)
        return makePlayer(id: id, position: position, age: age, overall: overall, potential: overall + growth,
                          teamID: nil, using: &random)
    }

    static let squadTemplate: [FootballPosition] = [
        .goalkeeper, .goalkeeper,
        .defender, .defender, .defender, .defender, .defender,
        .midfielder, .midfielder, .midfielder, .midfielder, .midfielder,
        .forward, .forward, .forward, .forward
    ]

    static let freeAgentTemplate: [FootballPosition] = [
        .goalkeeper, .defender, .midfielder, .forward,
        .defender, .midfielder, .forward, .goalkeeper,
        .midfielder, .defender, .forward, .midfielder
    ]

    static func generatePlayers(seed: Int) -> [FootballPlayer] {
        var random = FootballRandom(seed: UInt64(bitPattern: Int64(seed)))
        var players: [FootballPlayer] = []
        for team in teams {
            for (offset, position) in squadTemplate.enumerated() {
                let id = team.id * squadTemplate.count + offset
                let overall = team.strength + random.int(in: -9...9)
                let age = random.int(in: 18...34)
                let growth = age <= 22 ? random.int(in: 8...17) : (age <= 27 ? random.int(in: 1...8) : random.int(in: 0...3))
                players.append(makePlayer(id: id, position: position, age: age, overall: overall,
                                          potential: overall + growth, teamID: team.id, using: &random))
            }
        }
        for (offset, position) in freeAgentTemplate.enumerated() {
            players.append(makeFreeAgent(id: teams.count * squadTemplate.count + offset, position: position, using: &random))
        }
        return players
    }
}

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

    var rating: Double { FootballSeason.rating(of: lineup, formation: formation) }

    var attack: Double {
        rating + Double(formation.attackBonus + style.attackAdjustment + style.attackBonus(against: opponentStyle)) + (isHome ? 1.5 : 0)
    }

    var defense: Double {
        rating + Double(formation.defenseBonus + style.defenseAdjustment) + (isHome ? 1 : 0)
    }

    var control: Double {
        rating + Double(formation.midfieldBonus + style.controlAdjustment) + (isHome ? 1 : 0)
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

    static func simulateHalf(home: MatchSide, away: MatchSide, half: Int, narrate: Bool,
                             using random: inout FootballRandom) -> HalfResult {
        var result = HalfResult()
        let share = possessionShare(home: home, away: away, noise: Double(random.int(in: -3...3)) / 100)
        result.homePossession = Int((share * 100).rounded())
        result.homeExpectedGoals = rounded(expectedGoals(attack: home.attack, defense: away.defense, possessionShare: share))
        result.awayExpectedGoals = rounded(expectedGoals(attack: away.attack, defense: home.defense, possessionShare: 1 - share))

        let minutes = half == 1 ? 1...45 : 46...90
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
        let scoringWeights = lineup.map { $0.position.scoringWeight * max(1, $0.overall - 40) }
        let scorer: FootballPlayer? = random.weightedIndex(scoringWeights).map { lineup[$0] }
            ?? lineup.first(where: { $0.position != .goalkeeper })
            ?? lineup.first
        let scorerID = scorer?.id ?? -1
        var assistID: Int?
        if random.chance(0.72) {
            let mates = lineup.filter { $0.id != scorerID }
            let assistWeights = mates.map { $0.position.assistWeight * max(1, $0.overall - 40) }
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
}
