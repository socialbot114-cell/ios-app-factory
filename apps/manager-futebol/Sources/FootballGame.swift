import Foundation

enum FootballPosition: String, CaseIterable, Codable, Identifiable {
    case goalkeeper = "GOL"
    case defender = "ZAG"
    case midfielder = "MEI"
    case forward = "ATA"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .goalkeeper: return "Goleiros"
        case .defender: return "Defensores"
        case .midfielder: return "Meio-campistas"
        case .forward: return "Atacantes"
        }
    }
}

struct FootballPlayer: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var position: FootballPosition
    var age: Int
    var attack: Int
    var defense: Int
    var passing: Int
    var stamina: Int
    var condition: Int

    var overall: Int {
        let value: Int
        switch position {
        case .goalkeeper: value = (defense * 2 + passing + stamina) / 4
        case .defender: value = (defense * 2 + passing + stamina) / 4
        case .midfielder: value = (attack + defense + passing * 2 + stamina) / 5
        case .forward: value = (attack * 2 + passing + stamina) / 4
        }
        return value
    }
}

struct FootballTeam: Codable, Equatable, Identifiable {
    let id: Int
    var name: String
    var city: String
    var strength: Int
    var players: [FootballPlayer]
}

enum FootballFormation: String, CaseIterable, Codable, Identifiable {
    case fourThreeThree = "4-3-3"
    case fourFourTwo = "4-4-2"
    case threeFiveTwo = "3-5-2"

    var id: String { rawValue }

    var requirements: [FootballPosition: Int] {
        switch self {
        case .fourThreeThree: return [.goalkeeper: 1, .defender: 4, .midfielder: 3, .forward: 3]
        case .fourFourTwo: return [.goalkeeper: 1, .defender: 4, .midfielder: 4, .forward: 2]
        case .threeFiveTwo: return [.goalkeeper: 1, .defender: 3, .midfielder: 5, .forward: 2]
        }
    }

    var attackingModifier: Int {
        switch self {
        case .fourThreeThree: return 3
        case .fourFourTwo: return 0
        case .threeFiveTwo: return 2
        }
    }

    var defensiveModifier: Int {
        switch self {
        case .fourThreeThree: return 0
        case .fourFourTwo: return 2
        case .threeFiveTwo: return -2
        }
    }
}

enum FootballApproach: String, CaseIterable, Codable, Identifiable {
    case balanced = "Equilibrada"
    case attacking = "Ofensiva"
    case defensive = "Defensiva"

    var id: String { rawValue }

    var attackingModifier: Int {
        switch self {
        case .balanced: return 0
        case .attacking: return 8
        case .defensive: return -6
        }
    }

    var defensiveModifier: Int {
        switch self {
        case .balanced: return 0
        case .attacking: return -7
        case .defensive: return 8
        }
    }
}

struct FootballMatchResult: Codable, Equatable {
    var homeGoals: Int
    var awayGoals: Int
    var goalEvents: [FootballGoalEvent]
    var homeShots: Int = 0
    var awayShots: Int = 0
    var homePossession: Int = 50
}

struct FootballGoalEvent: Codable, Equatable, Identifiable {
    var minute: Int
    var teamID: Int
    var playerID: String

    var id: String { "\(minute)-\(teamID)-\(playerID)" }
}

struct FootballFixture: Codable, Equatable, Identifiable {
    let id: Int
    let round: Int
    let homeTeamID: Int
    let awayTeamID: Int
    var result: FootballMatchResult? = nil
}

struct FootballStanding: Codable, Equatable, Identifiable {
    let teamID: Int
    let teamName: String
    let city: String
    var played = 0
    var wins = 0
    var draws = 0
    var losses = 0
    var goalsFor = 0
    var goalsAgainst = 0
    var points = 0

    var id: Int { teamID }
    var goalDifference: Int { goalsFor - goalsAgainst }
}

struct FootballSeasonSummary: Codable, Equatable, Identifiable {
    let seasonNumber: Int
    let championName: String
    let userPosition: Int
    let userPoints: Int

    var id: Int { seasonNumber }
}

struct FootballCareer: Codable, Equatable {
    static let currentSaveVersion = 2

    var saveVersion = currentSaveVersion
    var seed: Int
    var seasonNumber: Int
    var completedRounds: Int
    var userTeamID: Int
    var budget: Int
    var teams: [FootballTeam]
    var fixtures: [FootballFixture]
    var formation: FootballFormation
    var approach: FootballApproach
    var startingLineup: [String]
    var marketPlayers: [FootballPlayer]
    var history: [FootballSeasonSummary]
}

struct FootballTeamRatings: Equatable {
    let attack: Int
    let defense: Int
}

struct FootballRoundReport: Identifiable {
    let seasonNumber: Int
    let round: Int
    let userTeamID: Int
    let fixtures: [FootballFixture]
    let userFixture: FootballFixture

    var id: String { "\(seasonNumber)-\(round)" }
}

enum FootballGame {
    static let numberOfRounds = 14
    static let matchesPerRound = 4

    private static let clubData: [(name: String, city: String, strength: Int)] = [
        ("Aurora FC", "Brasília", 78),
        ("Atlético Cerrado", "Goiânia", 73),
        ("Maré Alta", "Salvador", 75),
        ("União da Serra", "Belo Horizonte", 77),
        ("Estrela do Sul", "Porto Alegre", 74),
        ("Portuários", "Santos", 71),
        ("Capital Norte", "Manaus", 69),
        ("Vale Verde", "Curitiba", 72)
    ]

    private static let firstNames = [
        "Rafael", "Mateus", "Lucas", "André", "João", "Caio", "Bruno", "Davi",
        "Pedro", "Thiago", "Gabriel", "Enzo", "Vitor", "Samuel", "Murilo", "Nicolas"
    ]

    private static let lastNames = [
        "Nascimento", "Duarte", "Campos", "Ribeiro", "Nunes", "Mendes", "Barbosa", "Lima",
        "Teixeira", "Oliveira", "Freitas", "Cardoso", "Azevedo", "Pereira", "Silva", "Rocha"
    ]

    private static let rosterPositions: [FootballPosition] = [
        .goalkeeper, .goalkeeper,
        .defender, .defender, .defender, .defender, .defender,
        .midfielder, .midfielder, .midfielder, .midfielder, .midfielder,
        .forward, .forward, .forward, .forward
    ]
    private static let marketPositions: [FootballPosition] = [
        .goalkeeper, .defender, .defender, .midfielder, .midfielder, .midfielder, .forward, .forward
    ]

    static func newCareer(seed: Int = 26, userTeamID: Int = 0, seasonNumber: Int = 1, history: [FootballSeasonSummary] = []) -> FootballCareer {
        let teams = clubData.enumerated().map { teamID, club in
            FootballTeam(
                id: teamID,
                name: club.name,
                city: club.city,
                strength: club.strength,
                players: makePlayers(teamID: teamID, strength: club.strength, seed: seed)
            )
        }
        let formation = FootballFormation.fourThreeThree
        let selectedTeam = teams.first(where: { $0.id == userTeamID }) ?? teams[0]
        return FootballCareer(
            seed: seed,
            seasonNumber: seasonNumber,
            completedRounds: 0,
            userTeamID: selectedTeam.id,
            budget: 24_000_000,
            teams: teams,
            fixtures: makeFixtures(),
            formation: formation,
            approach: .balanced,
            startingLineup: suggestedLineup(team: selectedTeam, formation: formation),
            marketPlayers: makeMarketPlayers(seed: seed, seasonNumber: seasonNumber),
            history: history
        )
    }

    static func makeFixtures() -> [FootballFixture] {
        let ids = clubData.indices.map { $0 }
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

        return (0..<numberOfRounds).flatMap { round in
            (0..<matchesPerRound).map { match in
                let pair = firstLeg[(round % 7) * matchesPerRound + match]
                let home = round < 7 ? pair.0 : pair.1
                let away = round < 7 ? pair.1 : pair.0
                return FootballFixture(id: round * matchesPerRound + match, round: round + 1, homeTeamID: home, awayTeamID: away)
            }
        }
    }

    static func suggestedLineup(team: FootballTeam, formation: FootballFormation) -> [String] {
        FootballPosition.allCases.flatMap { position in
            let required = formation.requirements[position, default: 0]
            return team.players
                .filter { $0.position == position }
                .sorted { lhs, rhs in
                    let leftReadiness = lhs.overall + (lhs.condition - 80) / 5
                    let rightReadiness = rhs.overall + (rhs.condition - 80) / 5
                    return leftReadiness == rightReadiness ? lhs.id < rhs.id : leftReadiness > rightReadiness
                }
                .prefix(required)
                .map(\.id)
        }
    }

    static func isValidLineup(_ playerIDs: [String], team: FootballTeam, formation: FootballFormation) -> Bool {
        guard playerIDs.count == 11, Set(playerIDs).count == 11 else { return false }
        let playersByID = Dictionary(team.players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard playerIDs.allSatisfy({ playersByID[$0] != nil }) else { return false }
        let selected = playerIDs.compactMap { playersByID[$0] }
        return FootballPosition.allCases.allSatisfy { position in
            selected.filter { $0.position == position }.count == formation.requirements[position, default: 0]
        }
    }

    static func teamRatings(team: FootballTeam, lineup: [String], formation: FootballFormation, approach: FootballApproach) -> FootballTeamRatings {
        let playersByID = Dictionary(team.players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let players = lineup.compactMap { playersByID[$0] }
        guard !players.isEmpty else { return FootballTeamRatings(attack: team.strength, defense: team.strength) }

        let attack = players.reduce(0.0) { total, player in
            let skill = Double(player.attack) * 0.55 + Double(player.passing) * 0.30 + Double(player.stamina) * 0.15
            let fitness = Double(player.condition - 80) * 0.12
            let roleBonus: Double
            switch player.position {
            case .goalkeeper: roleBonus = -10
            case .defender: roleBonus = -3
            case .midfielder: roleBonus = 2
            case .forward: roleBonus = 7
            }
            return total + skill + fitness + roleBonus
        } / Double(players.count)

        let outfieldPlayers = players.filter { $0.position != .goalkeeper }
        let defensiveGroup = outfieldPlayers.isEmpty ? players : outfieldPlayers
        let fieldDefense = defensiveGroup.reduce(0.0) { total, player in
            total + Double(player.defense) * 0.60 + Double(player.passing) * 0.10 + Double(player.stamina) * 0.30
                + Double(player.condition - 80) * 0.12
        } / Double(defensiveGroup.count)
        let goalkeeperBonus = players.first(where: { $0.position == .goalkeeper }).map {
            Double($0.defense - 70) * 0.25 + Double($0.condition - 80) * 0.10
        } ?? 0

        return FootballTeamRatings(
            attack: Int((attack + Double(formation.attackingModifier + approach.attackingModifier)).rounded()),
            defense: Int((fieldDefense + goalkeeperBonus + Double(formation.defensiveModifier + approach.defensiveModifier)).rounded())
        )
    }

    static func standings(for career: FootballCareer) -> [FootballStanding] {
        var rows = Dictionary(uniqueKeysWithValues: career.teams.map { team in
            (team.id, FootballStanding(teamID: team.id, teamName: team.name, city: team.city))
        })

        for fixture in career.fixtures {
            guard let result = fixture.result,
                  var home = rows[fixture.homeTeamID],
                  var away = rows[fixture.awayTeamID] else { continue }

            home.played += 1
            away.played += 1
            home.goalsFor += result.homeGoals
            home.goalsAgainst += result.awayGoals
            away.goalsFor += result.awayGoals
            away.goalsAgainst += result.homeGoals

            if result.homeGoals > result.awayGoals {
                home.wins += 1
                home.points += 3
                away.losses += 1
            } else if result.homeGoals < result.awayGoals {
                away.wins += 1
                away.points += 3
                home.losses += 1
            } else {
                home.draws += 1
                away.draws += 1
                home.points += 1
                away.points += 1
            }

            rows[fixture.homeTeamID] = home
            rows[fixture.awayTeamID] = away
        }

        return rows.values.sorted { lhs, rhs in
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
            if lhs.goalDifference != rhs.goalDifference { return lhs.goalDifference > rhs.goalDifference }
            if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
            return lhs.teamName < rhs.teamName
        }
    }

    static func transferFee(for player: FootballPlayer) -> Int {
        let ageBonus = max(0, 23 - player.age) * 200_000
        let ageDiscount = max(0, player.age - 29) * 250_000
        return max(1_000_000, (player.overall - 45) * 350_000 + ageBonus - ageDiscount)
    }

    static func saleValue(for player: FootballPlayer) -> Int {
        transferFee(for: player) * 65 / 100
    }

    @discardableResult
    static func signPlayer(playerID: String, career: inout FootballCareer) -> Bool {
        guard career.completedRounds == 0,
              let marketIndex = career.marketPlayers.firstIndex(where: { $0.id == playerID }),
              let teamIndex = career.teams.firstIndex(where: { $0.id == career.userTeamID }),
              career.teams[teamIndex].players.count < 18 else { return false }

        let player = career.marketPlayers[marketIndex]
        let fee = transferFee(for: player)
        guard fee <= career.budget,
              !career.teams[teamIndex].players.contains(where: { $0.id == player.id }) else { return false }

        career.budget -= fee
        career.teams[teamIndex].players.append(player)
        career.marketPlayers.remove(at: marketIndex)
        return true
    }

    @discardableResult
    static func sellPlayer(playerID: String, career: inout FootballCareer) -> Bool {
        guard career.completedRounds == 0,
              let teamIndex = career.teams.firstIndex(where: { $0.id == career.userTeamID }),
              career.teams[teamIndex].players.count > 16,
              playerID.hasPrefix("FA-"),
              let playerIndex = career.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }),
              !career.startingLineup.contains(playerID) else { return false }

        let player = career.teams[teamIndex].players[playerIndex]
        let remainingPlayers = career.teams[teamIndex].players.filter { $0.id != playerID }
        let minimumByPosition: [FootballPosition: Int] = [.goalkeeper: 1, .defender: 4, .midfielder: 5, .forward: 3]
        guard FootballPosition.allCases.allSatisfy({ position in
            remainingPlayers.filter { $0.position == position }.count >= minimumByPosition[position, default: 0]
        }) else { return false }

        career.teams[teamIndex].players.remove(at: playerIndex)
        career.budget = min(40_000_000, career.budget + saleValue(for: player))
        career.marketPlayers.append(player)
        return true
    }

    @discardableResult
    static func simulateNextRound(career: inout FootballCareer) -> FootballRoundReport? {
        guard career.completedRounds < numberOfRounds,
              let userTeam = career.teams.first(where: { $0.id == career.userTeamID }),
              isValidLineup(career.startingLineup, team: userTeam, formation: career.formation) else { return nil }

        let round = career.completedRounds + 1
        let fixtureIndices = career.fixtures.indices.filter { career.fixtures[$0].round == round }
        guard fixtureIndices.count == matchesPerRound else { return nil }
        recoverBetweenRounds(career: &career)

        for fixtureIndex in fixtureIndices {
            var fixture = career.fixtures[fixtureIndex]
            guard let homeTeam = career.teams.first(where: { $0.id == fixture.homeTeamID }),
                  let awayTeam = career.teams.first(where: { $0.id == fixture.awayTeamID }) else { return nil }

            let homeIsUser = homeTeam.id == career.userTeamID
            let awayIsUser = awayTeam.id == career.userTeamID
            let homeFormation = homeIsUser ? career.formation : aiFormation(teamID: homeTeam.id, round: round)
            let awayFormation = awayIsUser ? career.formation : aiFormation(teamID: awayTeam.id, round: round)
            let homeLineup = homeIsUser ? career.startingLineup : suggestedLineup(team: homeTeam, formation: homeFormation)
            let awayLineup = awayIsUser ? career.startingLineup : suggestedLineup(team: awayTeam, formation: awayFormation)
            let homeApproach = homeIsUser ? career.approach : aiApproach(teamID: homeTeam.id, round: round)
            let awayApproach = awayIsUser ? career.approach : aiApproach(teamID: awayTeam.id, round: round)

            fixture.result = simulateMatch(
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                fixture: fixture,
                homeLineup: homeLineup,
                awayLineup: awayLineup,
                homeFormation: homeFormation,
                awayFormation: awayFormation,
                homeApproach: homeApproach,
                awayApproach: awayApproach,
                seed: career.seed
            )
            career.fixtures[fixtureIndex] = fixture
            recoverAndRest(teamID: homeTeam.id, lineup: homeLineup, approach: homeApproach, career: &career)
            recoverAndRest(teamID: awayTeam.id, lineup: awayLineup, approach: awayApproach, career: &career)
        }

        career.completedRounds = round
        let playedFixtures = fixtureIndices.map { career.fixtures[$0] }
        guard let userFixture = playedFixtures.first(where: {
            $0.homeTeamID == career.userTeamID || $0.awayTeamID == career.userTeamID
        }) else { return nil }

        return FootballRoundReport(seasonNumber: career.seasonNumber, round: round, userTeamID: career.userTeamID, fixtures: playedFixtures, userFixture: userFixture)
    }

    static func startNextSeason(career: inout FootballCareer) -> Bool {
        guard career.completedRounds == numberOfRounds else { return false }
        let table = standings(for: career)
        guard let champion = table.first,
              let userPosition = table.firstIndex(where: { $0.teamID == career.userTeamID }) else { return false }

        career.history.append(FootballSeasonSummary(
            seasonNumber: career.seasonNumber,
            championName: champion.teamName,
            userPosition: userPosition + 1,
            userPoints: table[userPosition].points
        ))
        career.seasonNumber &+= 1
        career.seed &+= 1
        career.budget = min(40_000_000, career.budget + max(3_000_000, 9_000_000 - userPosition * 500_000))
        career.completedRounds = 0
        career.teams = career.teams.map { team in
            var developedTeam = team
            developedTeam.players = team.players.map { player in
                var developed = player
                developed.age = min(120, developed.age + 1)
                developed.condition = 100
                let growth: Int
                if developed.age <= 23 { growth = 1 }
                else if developed.age >= 32 { growth = -1 }
                else { growth = 0 }

                switch developed.position {
                case .goalkeeper, .defender:
                    developed.defense = bounded(developed.defense + growth, 35...95)
                case .midfielder:
                    developed.passing = bounded(developed.passing + growth, 35...95)
                case .forward:
                    developed.attack = bounded(developed.attack + growth, 35...95)
                }
                return developed
            }
            developedTeam.strength = bounded(developedTeam.players.map(\.overall).reduce(0, +) / max(developedTeam.players.count, 1), 40...95)
            return developedTeam
        }
        career.fixtures = makeFixtures()
        career.marketPlayers = makeMarketPlayers(seed: career.seed, seasonNumber: career.seasonNumber)
        if let userTeam = career.teams.first(where: { $0.id == career.userTeamID }) {
            career.startingLineup = suggestedLineup(team: userTeam, formation: career.formation)
        }
        return true
    }

    private static func simulateMatch(
        homeTeam: FootballTeam,
        awayTeam: FootballTeam,
        fixture: FootballFixture,
        homeLineup: [String],
        awayLineup: [String],
        homeFormation: FootballFormation,
        awayFormation: FootballFormation,
        homeApproach: FootballApproach,
        awayApproach: FootballApproach,
        seed: Int
    ) -> FootballMatchResult {
        let homeRatings = teamRatings(team: homeTeam, lineup: homeLineup, formation: homeFormation, approach: homeApproach)
        let awayRatings = teamRatings(team: awayTeam, lineup: awayLineup, formation: awayFormation, approach: awayApproach)
        let homeChance = goalChance(attack: homeRatings.attack + 3, defense: awayRatings.defense)
        let awayChance = goalChance(attack: awayRatings.attack, defense: homeRatings.defense)
        let lineupContribution = (homeLineup + awayLineup).compactMap { Int($0.split(separator: "-").last ?? "0") }.reduce(0, +)
        let approachContribution = approachCode(homeApproach) * 101 + approachCode(awayApproach) * 307
        var random = FootballRandom(seed: seed &+ fixture.round &* 997 &+ fixture.id &* 53 &+ lineupContribution &+ approachContribution)
        var events: [FootballGoalEvent] = []

        for chanceIndex in 0..<8 {
            let minute = min(90, 4 + chanceIndex * 11 + random.nextInt(8))
            if random.nextInt(100) < Int(homeChance * 100) {
                if let scorer = scorer(in: homeTeam, lineup: homeLineup, random: &random) {
                    events.append(FootballGoalEvent(minute: minute, teamID: homeTeam.id, playerID: scorer.id))
                }
            }
            if random.nextInt(100) < Int(awayChance * 100) {
                if let scorer = scorer(in: awayTeam, lineup: awayLineup, random: &random) {
                    events.append(FootballGoalEvent(minute: minute, teamID: awayTeam.id, playerID: scorer.id))
                }
            }
        }

        events.sort { lhs, rhs in
            lhs.minute == rhs.minute ? lhs.teamID < rhs.teamID : lhs.minute < rhs.minute
        }
        // Fase 1: estatísticas derivadas do rating + seed (comentário roadmap).
        // Finalizações e posse nascem do mesmo gerador da partida para manter determinismo.
        let homeEdge = Double(homeRatings.attack - awayRatings.defense + 3)
        let awayEdge = Double(awayRatings.attack - homeRatings.defense)
        let homeShots = min(22, max(2, 9 + Int(homeEdge / 6) + random.nextInt(5) - 2))
        let awayShots = min(22, max(2, 8 + Int(awayEdge / 6) + random.nextInt(5) - 2))
        let homePossession = min(72, max(28, 50 + Int((homeEdge - awayEdge) / 2) + random.nextInt(7) - 3))
        return FootballMatchResult(
            homeGoals: events.filter { $0.teamID == homeTeam.id }.count,
            awayGoals: events.filter { $0.teamID == awayTeam.id }.count,
            goalEvents: events,
            homeShots: homeShots,
            awayShots: awayShots,
            homePossession: homePossession
        )
    }

    // MARK: - Fase 1: calendário, forma e artilharia (ver docs/roadmap.md)

    /// Jogos de uma rodada, ordenados por id. Base para a futura tela de Calendário.
    static func fixturesForRound(_ round: Int, in career: FootballCareer) -> [FootballFixture] {
        career.fixtures.filter { $0.round == round }.sorted { $0.id < $1.id }
    }

    /// Próximos jogos do clube do usuário a partir da rodada atual.
    static func upcomingFixtures(for career: FootballCareer, limit: Int = 5) -> [FootballFixture] {
        career.fixtures
            .filter { $0.round > career.completedRounds && ($0.homeTeamID == career.userTeamID || $0.awayTeamID == career.userTeamID) }
            .sorted { $0.round < $1.round }
            .prefix(limit)
            .map { $0 }
    }

    /// Forma recente: últimos resultados do clube (V/E/D), do mais recente ao mais antigo.
    static func recentForm(teamID: Int, in career: FootballCareer, last: Int = 5) -> [String] {
        let played = career.fixtures
            .filter { $0.round <= career.completedRounds && $0.result != nil && ($0.homeTeamID == teamID || $0.awayTeamID == teamID) }
            .sorted { $0.round > $1.round }
            .prefix(last)
        return played.map { fixture in
            guard let result = fixture.result else { return "-" }
            let scored = fixture.homeTeamID == teamID ? result.homeGoals : result.awayGoals
            let conceded = fixture.homeTeamID == teamID ? result.awayGoals : result.homeGoals
            if scored > conceded { return "V" }
            if scored == conceded { return "E" }
            return "D"
        }
    }

    /// Artilharia da temporada a partir dos eventos de gol registrados.
    static func topScorers(in career: FootballCareer, limit: Int = 5) -> [(player: FootballPlayer, teamName: String, goals: Int)] {
        var counts: [String: Int] = [:]
        for fixture in career.fixtures {
            guard let result = fixture.result else { continue }
            for event in result.goalEvents {
                counts[event.playerID, default: 0] += 1
            }
        }
        var rows: [(player: FootballPlayer, teamName: String, goals: Int)] = []
        for team in career.teams {
            for player in team.players where counts[player.id] != nil {
                rows.append((player: player, teamName: team.name, goals: counts[player.id] ?? 0))
            }
        }
        return rows
            .sorted {
                if $0.goals != $1.goals { return $0.goals > $1.goals }
                if $0.player.overall != $1.player.overall { return $0.player.overall > $1.player.overall }
                return $0.player.name < $1.player.name
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func goalChance(attack: Int, defense: Int) -> Double {
        min(0.42, max(0.04, 0.14 + Double(attack - defense) / 125))
    }

    private static func scorer(in team: FootballTeam, lineup: [String], random: inout FootballRandom) -> FootballPlayer? {
        let playersByID = Dictionary(uniqueKeysWithValues: team.players.map { ($0.id, $0) })
        let attackers = lineup.compactMap { playersByID[$0] }
            .filter { $0.position == .forward || $0.position == .midfielder }
            .sorted { $0.attack == $1.attack ? $0.id < $1.id : $0.attack > $1.attack }
        let candidates = attackers.isEmpty ? lineup.compactMap { playersByID[$0] } : attackers
        guard !candidates.isEmpty else { return nil }
        let topCandidates = Array(candidates.prefix(min(4, candidates.count)))
        return topCandidates[random.nextInt(topCandidates.count)]
    }

    private static func recoverAndRest(teamID: Int, lineup: [String], approach: FootballApproach, career: inout FootballCareer) {
        guard let teamIndex = career.teams.firstIndex(where: { $0.id == teamID }) else { return }
        let starters = Set(lineup)
        for playerIndex in career.teams[teamIndex].players.indices {
            let player = career.teams[teamIndex].players[playerIndex]
            if starters.contains(player.id) {
                let intensity = approach == .attacking ? 19 : (approach == .defensive ? 11 : 14)
                let staminaRecovery = max(0, (player.stamina - 60) / 10)
                career.teams[teamIndex].players[playerIndex].condition = max(45, player.condition - intensity + staminaRecovery)
            } else {
                career.teams[teamIndex].players[playerIndex].condition = min(100, player.condition + 9)
            }
        }
    }

    private static func recoverBetweenRounds(career: inout FootballCareer) {
        for teamIndex in career.teams.indices {
            for playerIndex in career.teams[teamIndex].players.indices {
                career.teams[teamIndex].players[playerIndex].condition = min(100, career.teams[teamIndex].players[playerIndex].condition + 12)
            }
        }
    }

    private static func makePlayers(teamID: Int, strength: Int, seed: Int) -> [FootballPlayer] {
        rosterPositions.enumerated().map { index, position in
            let localSeed = seed &+ teamID &* 211 &+ index &* 43
            let variation = Int(UInt64(bitPattern: Int64(truncatingIfNeeded: localSeed)) % 11) - 5
            let base = strength + variation
            let skills: (attack: Int, defense: Int, passing: Int, stamina: Int)
            switch position {
            case .goalkeeper: skills = (base - 25, base + 10, base - 5, base)
            case .defender: skills = (base - 7, base + 5, base - 2, base + 2)
            case .midfielder: skills = (base, base - 3, base + 6, base + 1)
            case .forward: skills = (base + 8, base - 12, base + 1, base - 2)
            }
            let nameIndex = (index + teamID * 3) % firstNames.count
            let surnameIndex = (index * 5 + teamID * 7) % lastNames.count
            return FootballPlayer(
                id: "\(teamID)-\(index)",
                name: "\(firstNames[nameIndex]) \(lastNames[surnameIndex])",
                position: position,
                age: 18 + ((index * 3 + teamID * 2) % 16),
                attack: bounded(skills.attack, 35...95),
                defense: bounded(skills.defense, 35...95),
                passing: bounded(skills.passing, 35...95),
                stamina: bounded(skills.stamina, 35...95),
                condition: 100
            )
        }
    }

    private static func makeMarketPlayers(seed: Int, seasonNumber: Int) -> [FootballPlayer] {
        marketPositions.enumerated().map { index, position in
            let localSeed = seed &+ seasonNumber &* 313 &+ index &* 71
            let variation = Int(UInt64(bitPattern: Int64(truncatingIfNeeded: localSeed)) % 15) - 7
            let base = 72 + variation
            let skills: (attack: Int, defense: Int, passing: Int, stamina: Int)
            switch position {
            case .goalkeeper: skills = (base - 25, base + 10, base - 5, base)
            case .defender: skills = (base - 7, base + 5, base - 2, base + 2)
            case .midfielder: skills = (base, base - 3, base + 6, base + 1)
            case .forward: skills = (base + 8, base - 12, base + 1, base - 2)
            }
            let nameIndex = (index + seasonNumber * 5 + 2) % firstNames.count
            let surnameIndex = (index * 7 + seasonNumber * 3 + 1) % lastNames.count
            return FootballPlayer(
                id: "FA-\(seasonNumber)-\(index)",
                name: "\(firstNames[nameIndex]) \(lastNames[surnameIndex])",
                position: position,
                age: 18 + ((index * 5 + seasonNumber * 3) % 16),
                attack: bounded(skills.attack, 35...95),
                defense: bounded(skills.defense, 35...95),
                passing: bounded(skills.passing, 35...95),
                stamina: bounded(skills.stamina, 35...95),
                condition: 100
            )
        }
    }

    private static func aiFormation(teamID: Int, round: Int) -> FootballFormation {
        FootballFormation.allCases[(teamID + round) % FootballFormation.allCases.count]
    }

    private static func aiApproach(teamID: Int, round: Int) -> FootballApproach {
        FootballApproach.allCases[(teamID * 2 + round) % FootballApproach.allCases.count]
    }

    private static func approachCode(_ approach: FootballApproach) -> Int {
        switch approach {
        case .balanced: return 1
        case .attacking: return 2
        case .defensive: return 3
        }
    }

    private static func bounded(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }
}

private struct FootballRandom {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(truncatingIfNeeded: seed))
    }

    mutating func nextInt(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 32) % UInt64(upperBound))
    }
}
