import Foundation

struct LeagueTeam: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let city: String
    let strength: Int
    let startingBudget: Int
}

enum FootballPosition: String, CaseIterable, Codable, Hashable {
    case goalkeeper = "GOL"
    case defender = "ZAG"
    case midfielder = "MEI"
    case forward = "ATA"
}

enum FootballFormation: String, CaseIterable, Codable, Identifiable {
    case fourFourTwo = "4-4-2"
    case fourThreeThree = "4-3-3"
    case fourTwoThreeOne = "4-2-3-1"

    var id: String { rawValue }

    var requiredPlayers: [FootballPosition: Int] {
        switch self {
        case .fourFourTwo:
            return [.goalkeeper: 1, .defender: 4, .midfielder: 4, .forward: 2]
        case .fourThreeThree:
            return [.goalkeeper: 1, .defender: 4, .midfielder: 3, .forward: 3]
        case .fourTwoThreeOne:
            return [.goalkeeper: 1, .defender: 4, .midfielder: 5, .forward: 1]
        }
    }

    var attackBonus: Int {
        switch self {
        case .fourFourTwo: return 0
        case .fourThreeThree: return 4
        case .fourTwoThreeOne: return 1
        }
    }

    var midfieldBonus: Int {
        switch self {
        case .fourFourTwo: return 0
        case .fourThreeThree: return 1
        case .fourTwoThreeOne: return 4
        }
    }

    var defenseBonus: Int {
        switch self {
        case .fourFourTwo: return 0
        case .fourThreeThree: return -2
        case .fourTwoThreeOne: return 1
        }
    }
}

enum FootballPlayStyle: String, CaseIterable, Codable, Identifiable {
    case balanced = "Equilibrado"
    case attacking = "Ofensivo"
    case defensive = "Defensivo"
    case possession = "Posse de bola"
    case counter = "Contra-ataque"
    case highPress = "Pressão alta"

    var id: String { rawValue }

    var attackAdjustment: Int {
        switch self {
        case .balanced: return 0
        case .attacking: return 4
        case .defensive: return -3
        case .possession: return -1
        case .counter: return 3
        case .highPress: return 2
        }
    }

    var defenseAdjustment: Int {
        switch self {
        case .balanced: return 0
        case .attacking: return -3
        case .defensive: return 4
        case .possession: return 0
        case .counter: return 0
        case .highPress: return 1
        }
    }

    var controlAdjustment: Int {
        switch self {
        case .balanced: return 0
        case .attacking: return 0
        case .defensive: return 0
        case .possession: return 5
        case .counter: return -3
        case .highPress: return 2
        }
    }

    var fatigueCost: Int {
        switch self {
        case .balanced: return 9
        case .attacking: return 12
        case .defensive: return 7
        case .possession: return 9
        case .counter: return 9
        case .highPress: return 14
        }
    }

    var summary: String {
        switch self {
        case .balanced: return "Um plano sem grandes riscos, com energia preservada."
        case .attacking: return "Aumenta a força ofensiva, mas deixa mais espaços na defesa e consome energia."
        case .defensive: return "Protege a defesa e poupa energia, com menos presença no ataque."
        case .possession: return "Favorece o controle da bola e constrói ataques com paciência."
        case .counter: return "Busca transições rápidas e mais ataque, cedendo controle do meio-campo."
        case .highPress: return "Pressiona a saída adversária com intensidade e alto custo físico."
        }
    }
}

enum FootballTrainingFocus: String, CaseIterable, Codable, Identifiable {
    case physical = "Físico"
    case technical = "Técnico"
    case tactical = "Tático"
    case defending = "Defesa"
    case attacking = "Ataque"
    case recovery = "Recuperação"

    var id: String { rawValue }

    var developmentPositions: [FootballPosition] {
        switch self {
        case .physical: return FootballPosition.allCases
        case .recovery: return []
        case .technical: return [.midfielder, .forward]
        case .tactical: return [.defender, .midfielder]
        case .defending: return [.goalkeeper, .defender]
        case .attacking: return [.midfielder, .forward]
        }
    }

    var summary: String {
        switch self {
        case .physical: return "Treino físico prepara o elenco inteiro; intensidade maior desenvolve mais, mas reduz a recuperação."
        case .technical: return "Meio-campistas e atacantes podem evoluir; intensidade maior acelera o desenvolvimento."
        case .tactical: return "Defensores e meio-campistas podem evoluir; intensidade maior acelera o desenvolvimento."
        case .defending: return "Goleiros e defensores podem evoluir; intensidade maior acelera o desenvolvimento."
        case .attacking: return "Atacantes e meio-campistas podem evoluir; intensidade maior acelera o desenvolvimento."
        case .recovery: return "Semana regenerativa: não há evolução técnica, mas o elenco recupera mais condição."
        }
    }
}

enum FootballTrainingIntensity: String, CaseIterable, Codable, Identifiable {
    case light = "Leve"
    case balanced = "Equilibrada"
    case intense = "Intensa"

    var id: String { rawValue }

    var developmentChance: Int {
        switch self {
        case .light: return 8
        case .balanced: return 20
        case .intense: return 35
        }
    }

    func conditionRecovery(for focus: FootballTrainingFocus) -> Int {
        if focus == .recovery {
            switch self {
            case .light: return 18
            case .balanced: return 24
            case .intense: return 30
            }
        }
        let recovery: Int
        switch self {
        case .light: recovery = 12
        case .balanced: recovery = 8
        case .intense: recovery = 4
        }
        return focus == .physical ? max(recovery - 2, 0) : recovery
    }
}

struct FootballTrainingReport: Codable, Equatable {
    let round: Int
    let focus: FootballTrainingFocus
    let intensity: FootballTrainingIntensity
    let developedPlayers: Int
    let averageConditionGain: Int

    var summary: String {
        let development = developedPlayers == 1 ? "1 atleta evoluiu" : "\(developedPlayers) atletas evoluíram"
        return "\(development) · recuperação média de \(averageConditionGain) pontos de condição."
    }
}

struct FootballPlayer: Identifiable, Codable, Equatable {
    let id: Int
    var name: String
    var position: FootballPosition
    var age: Int
    var overall: Int
    var potential: Int
    var condition: Int
    var marketValue: Int
    var teamID: Int?
    var goals = 0
    var assists = 0
    var appearances = 0

    var effectiveOverall: Double {
        Double(overall) * (0.65 + 0.35 * Double(condition) / 100)
    }
}

struct LeagueFixture: Identifiable, Codable, Equatable {
    let id: Int
    let round: Int
    let home: Int
    let away: Int
    var homeGoals: Int?
    var awayGoals: Int?
    var homeScorerIDs: [Int] = []
    var awayScorerIDs: [Int] = []
    var commentary: [String] = []
    var homeShots: Int? = nil
    var awayShots: Int? = nil
    var homePossession: Int? = nil
    var awayPossession: Int? = nil

    var isPlayed: Bool { homeGoals != nil && awayGoals != nil }
}

struct FootballStanding: Identifiable, Equatable {
    let team: LeagueTeam
    var played = 0
    var wins = 0
    var draws = 0
    var losses = 0
    var goalsFor = 0
    var goalsAgainst = 0
    var points = 0

    var id: Int { team.id }
    var goalDifference: Int { goalsFor - goalsAgainst }
}

enum FootballSeason {
    static let teams: [LeagueTeam] = [
        .init(id: 0, name: "Aurora FC", city: "Brasília", strength: 78, startingBudget: 8_000_000),
        .init(id: 1, name: "Atlético Cerrado", city: "Goiânia", strength: 73, startingBudget: 6_200_000),
        .init(id: 2, name: "Maré Alta", city: "Salvador", strength: 75, startingBudget: 6_800_000),
        .init(id: 3, name: "União da Serra", city: "Belo Horizonte", strength: 77, startingBudget: 7_500_000),
        .init(id: 4, name: "Estrela do Sul", city: "Porto Alegre", strength: 74, startingBudget: 6_500_000),
        .init(id: 5, name: "Portuários", city: "Santos", strength: 71, startingBudget: 5_800_000),
        .init(id: 6, name: "Capital Norte", city: "Manaus", strength: 69, startingBudget: 5_000_000),
        .init(id: 7, name: "Vale Verde", city: "Curitiba", strength: 72, startingBudget: 5_600_000)
    ]

    private static let firstNames = [
        "Rafael", "Mateus", "Lucas", "André", "João", "Caio", "Bruno", "Davi",
        "Gabriel", "Pedro", "Igor", "Vinícius", "Daniel", "Marcos", "Felipe", "Renan",
        "Thiago", "Samuel", "Gustavo", "Enzo", "Luan", "Ruan", "Diego", "Alex"
    ]

    private static let lastNames = [
        "Nascimento", "Duarte", "Campos", "Ribeiro", "Nunes", "Oliveira", "Moura", "Barbosa",
        "Freitas", "Lima", "Teixeira", "Carvalho", "Mendes", "Azevedo", "Pereira", "Costa",
        "Cardoso", "Rocha", "Alves", "Farias", "Cavalcante", "Batista", "Gomes", "Monteiro"
    ]

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
        for round in 0..<14 {
            for match in 0..<4 {
                let pair = firstLeg[(round % 7) * 4 + match]
                let home = round < 7 ? pair.0 : pair.1
                let away = round < 7 ? pair.1 : pair.0
                output.append(.init(id: output.count, round: round + 1, home: home, away: away, homeGoals: nil, awayGoals: nil))
            }
        }
        return output
    }

    static func standings(results: [LeagueFixture]) -> [FootballStanding] {
        var table = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, FootballStanding(team: $0)) })
        for match in results {
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
            } else if homeGoals < awayGoals {
                away.wins += 1
                home.losses += 1
                away.points += 3
            } else {
                home.draws += 1
                away.draws += 1
                home.points += 1
                away.points += 1
            }
            table[match.home] = home
            table[match.away] = away
        }

        return table.values.sorted { lhs, rhs in
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
            if lhs.goalDifference != rhs.goalDifference { return lhs.goalDifference > rhs.goalDifference }
            if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
            return lhs.team.name < rhs.team.name
        }
    }

    static func lineUp(teamID: Int, players: [FootballPlayer], formation: FootballFormation) -> [Int] {
        let roster = players.filter { $0.teamID == teamID }
        let order: [FootballPosition] = [.goalkeeper, .defender, .midfielder, .forward]
        return order.flatMap { position in
            let required = formation.requiredPlayers[position, default: 0]
            return roster
                .filter { $0.position == position }
                .sorted { lhs, rhs in
                    if lhs.overall != rhs.overall { return lhs.overall > rhs.overall }
                    return lhs.id < rhs.id
                }
                .prefix(required)
                .map(\.id)
        }
    }

    static func canFill(teamID: Int, players: [FootballPlayer], formation: FootballFormation) -> Bool {
        let roster = players.filter { $0.teamID == teamID }
        return formation.requiredPlayers.allSatisfy { requirement in
            roster.filter { $0.position == requirement.key }.count >= requirement.value
        }
    }

    static func generatePlayers(seed: Int) -> [FootballPlayer] {
        var random = FootballRandom(seed: UInt64(bitPattern: Int64(seed)))
        let positions: [FootballPosition] = [
            .goalkeeper, .goalkeeper,
            .defender, .defender, .defender, .defender, .defender,
            .midfielder, .midfielder, .midfielder, .midfielder, .midfielder,
            .forward, .forward, .forward, .forward
        ]
        var players: [FootballPlayer] = []
        for team in teams {
            for (offset, position) in positions.enumerated() {
                let id = team.id * positions.count + offset
                let overall = min(91, max(52, team.strength + random.int(in: -10...10)))
                let age = random.int(in: 18...34)
                let agePotential = age <= 22 ? random.int(in: 8...17) : random.int(in: 1...10)
                let valueBase = max(150_000, (overall - 38) * (overall - 38) * 1_250)
                let ageFactor = age <= 23 ? 1.25 : (age >= 31 ? 0.75 : 1.0)
                let value = Int(Double(valueBase) * ageFactor)
                let player = FootballPlayer(
                    id: id,
                    name: "\(firstNames[random.int(in: 0...(firstNames.count - 1))]) \(lastNames[random.int(in: 0...(lastNames.count - 1))])",
                    position: position,
                    age: age,
                    overall: overall,
                    potential: min(96, overall + agePotential),
                    condition: random.int(in: 82...100),
                    marketValue: value,
                    teamID: team.id
                )
                players.append(player)
            }
        }

        let freeAgentPositions: [FootballPosition] = [
            .goalkeeper, .defender, .midfielder, .forward,
            .defender, .midfielder, .forward, .goalkeeper,
            .midfielder, .defender, .forward, .midfielder
        ]
        for (offset, position) in freeAgentPositions.enumerated() {
            let overall = random.int(in: 62...77)
            let age = random.int(in: 19...32)
            let value = max(180_000, (overall - 38) * (overall - 38) * 1_100)
            players.append(FootballPlayer(
                id: teams.count * positions.count + offset,
                name: "\(firstNames[random.int(in: 0...(firstNames.count - 1))]) \(lastNames[random.int(in: 0...(lastNames.count - 1))])",
                position: position,
                age: age,
                overall: overall,
                potential: min(94, overall + random.int(in: 2...14)),
                condition: random.int(in: 85...100),
                marketValue: value,
                teamID: nil
            ))
        }
        return players
    }
}

struct FootballCareer: Codable, Equatable {
    static let saveKey = "football.career"

    private enum CodingKeys: String, CodingKey {
        case seed
        case season
        case currentRound
        case selectedClubID
        case transferBudget
        case formation
        case playStyle
        case trainingFocus
        case trainingIntensity
        case lastTrainingReport
        case startingXI
        case players
        case fixtures
        case champions
    }

    var seed: Int
    var season: Int
    var currentRound: Int
    var selectedClubID: Int?
    var transferBudget: Int
    var formation: FootballFormation
    var playStyle: FootballPlayStyle
    var trainingFocus: FootballTrainingFocus
    var trainingIntensity: FootballTrainingIntensity
    var lastTrainingReport: FootballTrainingReport?
    var startingXI: [Int]
    var players: [FootballPlayer]
    var fixtures: [LeagueFixture]
    var champions: [Int]

    init(seed: Int = 26) {
        self.seed = seed
        self.season = 1
        self.currentRound = 0
        self.selectedClubID = nil
        self.transferBudget = 0
        self.formation = .fourFourTwo
        self.playStyle = .balanced
        self.trainingFocus = .tactical
        self.trainingIntensity = .balanced
        self.lastTrainingReport = nil
        self.startingXI = []
        self.players = FootballSeason.generatePlayers(seed: seed)
        self.fixtures = FootballSeason.fixtures()
        self.champions = []
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSeed = try container.decodeIfPresent(Int.self, forKey: .seed) ?? 26
        let decodedSeason = try container.decodeIfPresent(Int.self, forKey: .season) ?? 1
        let decodedRound = try container.decodeIfPresent(Int.self, forKey: .currentRound) ?? 0
        let decodedClubID = try container.decodeIfPresent(Int.self, forKey: .selectedClubID)
        let decodedBudget = try container.decodeIfPresent(Int.self, forKey: .transferBudget) ?? 0
        let decodedFormation = try container.decodeIfPresent(FootballFormation.self, forKey: .formation) ?? .fourFourTwo
        let decodedStyle = try container.decodeIfPresent(FootballPlayStyle.self, forKey: .playStyle) ?? .balanced
        let decodedTrainingFocus = try container.decodeIfPresent(FootballTrainingFocus.self, forKey: .trainingFocus) ?? .tactical
        let decodedTrainingIntensity = try container.decodeIfPresent(FootballTrainingIntensity.self, forKey: .trainingIntensity) ?? .balanced
        let decodedTrainingReport = try container.decodeIfPresent(FootballTrainingReport.self, forKey: .lastTrainingReport)
        let decodedPlayers = try container.decodeIfPresent([FootballPlayer].self, forKey: .players)
            ?? FootballSeason.generatePlayers(seed: decodedSeed)
        let decodedLineup = try container.decodeIfPresent([Int].self, forKey: .startingXI)
            ?? decodedClubID.map { FootballSeason.lineUp(teamID: $0, players: decodedPlayers, formation: decodedFormation) }
            ?? []
        seed = decodedSeed
        season = decodedSeason
        currentRound = decodedRound
        selectedClubID = decodedClubID
        transferBudget = decodedBudget
        formation = decodedFormation
        playStyle = decodedStyle
        trainingFocus = decodedTrainingFocus
        trainingIntensity = decodedTrainingIntensity
        lastTrainingReport = decodedTrainingReport
        players = decodedPlayers
        startingXI = decodedLineup
        fixtures = try container.decodeIfPresent([LeagueFixture].self, forKey: .fixtures) ?? FootballSeason.fixtures()
        champions = try container.decodeIfPresent([Int].self, forKey: .champions) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(seed, forKey: .seed)
        try container.encode(season, forKey: .season)
        try container.encode(currentRound, forKey: .currentRound)
        try container.encodeIfPresent(selectedClubID, forKey: .selectedClubID)
        try container.encode(transferBudget, forKey: .transferBudget)
        try container.encode(formation, forKey: .formation)
        try container.encode(playStyle, forKey: .playStyle)
        try container.encode(trainingFocus, forKey: .trainingFocus)
        try container.encode(trainingIntensity, forKey: .trainingIntensity)
        try container.encodeIfPresent(lastTrainingReport, forKey: .lastTrainingReport)
        try container.encode(startingXI, forKey: .startingXI)
        try container.encode(players, forKey: .players)
        try container.encode(fixtures, forKey: .fixtures)
        try container.encode(champions, forKey: .champions)
    }

    static func load(defaults: UserDefaults = .standard) -> FootballCareer {
        guard let data = defaults.data(forKey: saveKey),
              let career = try? JSONDecoder().decode(FootballCareer.self, from: data) else {
            return FootballCareer()
        }
        return career
    }

    func persist(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.saveKey)
    }

    var selectedClub: LeagueTeam? {
        guard let selectedClubID else { return nil }
        return FootballSeason.teams.first { $0.id == selectedClubID }
    }

    var clubRoster: [FootballPlayer] {
        guard let selectedClubID else { return [] }
        return players(forTeam: selectedClubID)
    }

    var marketPlayers: [FootballPlayer] {
        players.filter { $0.teamID == nil }.sorted {
            if $0.overall != $1.overall { return $0.overall > $1.overall }
            return $0.name < $1.name
        }
    }

    var isSeasonComplete: Bool { currentRound >= 14 }

    var nextUserFixture: LeagueFixture? {
        guard let selectedClubID, !isSeasonComplete else { return nil }
        return fixtures.first {
            $0.round == currentRound + 1 && !$0.isPlayed && ($0.home == selectedClubID || $0.away == selectedClubID)
        }
    }

    var latestUserFixture: LeagueFixture? {
        guard let selectedClubID else { return nil }
        return fixtures
            .filter { $0.isPlayed && ($0.home == selectedClubID || $0.away == selectedClubID) }
            .max { $0.round < $1.round }
    }

    var championID: Int? {
        guard isSeasonComplete else { return nil }
        return FootballSeason.standings(results: fixtures).first?.team.id
    }

    func players(forTeam teamID: Int) -> [FootballPlayer] {
        let order: [FootballPosition: Int] = [.goalkeeper: 0, .defender: 1, .midfielder: 2, .forward: 3]
        return players.filter { $0.teamID == teamID }.sorted {
            let leftOrder = order[$0.position, default: 4]
            let rightOrder = order[$1.position, default: 4]
            if leftOrder != rightOrder { return leftOrder < rightOrder }
            if $0.overall != $1.overall { return $0.overall > $1.overall }
            return $0.name < $1.name
        }
    }

    mutating func chooseClub(_ clubID: Int) -> Bool {
        guard selectedClubID == nil,
              let club = FootballSeason.teams.first(where: { $0.id == clubID }) else { return false }
        selectedClubID = club.id
        transferBudget = club.startingBudget
        startingXI = FootballSeason.lineUp(teamID: club.id, players: players, formation: formation)
        return startingXI.count == 11
    }

    mutating func setFormation(_ newFormation: FootballFormation) {
        guard let selectedClubID, FootballSeason.canFill(teamID: selectedClubID, players: players, formation: newFormation) else { return }
        formation = newFormation
        startingXI = FootballSeason.lineUp(teamID: selectedClubID, players: players, formation: newFormation)
    }

    mutating func setPlayStyle(_ newStyle: FootballPlayStyle) {
        playStyle = newStyle
    }

    mutating func setTrainingFocus(_ newFocus: FootballTrainingFocus) {
        trainingFocus = newFocus
    }

    mutating func setTrainingIntensity(_ newIntensity: FootballTrainingIntensity) {
        trainingIntensity = newIntensity
    }

    @discardableResult
    mutating func applyWeeklyTraining(for round: Int) -> FootballTrainingReport {
        guard let selectedClubID else {
            let emptyReport = FootballTrainingReport(
                round: round,
                focus: trainingFocus,
                intensity: trainingIntensity,
                developedPlayers: 0,
                averageConditionGain: 0
            )
            lastTrainingReport = emptyReport
            return emptyReport
        }

        var random = FootballRandom(seed: matchSeed(fixtureID: 10_000 + round) ^ 0xD1B54A32D192ED03)
        let rosterIndices = players.indices.filter { players[$0].teamID == selectedClubID }
        var developedPlayers = 0
        var totalConditionGain = 0

        for index in rosterIndices {
            let player = players[index]
            let conditionBefore = player.condition
            players[index].condition = min(100, conditionBefore + trainingIntensity.conditionRecovery(for: trainingFocus))
            totalConditionGain += players[index].condition - conditionBefore

            guard trainingFocus.developmentPositions.contains(player.position), player.overall < player.potential else { continue }
            let ageMultiplier: Double
            if player.age <= 21 { ageMultiplier = 1.35 }
            else if player.age <= 25 { ageMultiplier = 1.15 }
            else if player.age >= 30 { ageMultiplier = 0.65 }
            else { ageMultiplier = 1.0 }
            let developmentChance = min(75, Int(Double(trainingIntensity.developmentChance) * ageMultiplier))
            guard random.int(in: 0...99) < developmentChance else { continue }

            var developedPlayer = players[index]
            developedPlayer.overall += 1
            developedPlayer.marketValue = marketValue(for: developedPlayer, overall: developedPlayer.overall)
            players[index] = developedPlayer
            developedPlayers += 1
        }

        let averageConditionGain = rosterIndices.isEmpty ? 0 : totalConditionGain / rosterIndices.count
        let report = FootballTrainingReport(
            round: round,
            focus: trainingFocus,
            intensity: trainingIntensity,
            developedPlayers: developedPlayers,
            averageConditionGain: averageConditionGain
        )
        lastTrainingReport = report
        return report
    }

    @discardableResult
    mutating func swapWithStarter(playerID: Int) -> Bool {
        guard let selectedClubID,
              let incoming = players.first(where: { $0.id == playerID && $0.teamID == selectedClubID }),
              !startingXI.contains(playerID) else { return false }
        let replaceable = startingXI.compactMap { id in players.first(where: { $0.id == id }) }
            .filter { $0.position == incoming.position }
            .sorted { lhs, rhs in
                if lhs.overall != rhs.overall { return lhs.overall < rhs.overall }
                return lhs.id < rhs.id
            }
        guard let outgoing = replaceable.first else { return false }
        startingXI.removeAll { $0 == outgoing.id }
        startingXI.append(incoming.id)
        return true
    }

    func canSell(playerID: Int) -> Bool {
        guard let selectedClubID,
              let player = players.first(where: { $0.id == playerID && $0.teamID == selectedClubID }),
              !startingXI.contains(playerID),
              clubRoster.count > 11 else { return false }
        var remaining = players
        remaining.removeAll { $0.id == playerID }
        return FootballSeason.canFill(teamID: selectedClubID, players: remaining, formation: formation)
    }

    @discardableResult
    mutating func sellPlayer(playerID: Int) -> Bool {
        guard canSell(playerID: playerID),
              let index = players.firstIndex(where: { $0.id == playerID }) else { return false }
        let saleValue = players[index].marketValue
        players[index].teamID = nil
        transferBudget += saleValue
        return true
    }

    func canSign(playerID: Int) -> Bool {
        guard let selectedClubID,
              let player = players.first(where: { $0.id == playerID && $0.teamID == nil }) else { return false }
        return clubRoster.count < 16 && transferBudget >= player.marketValue
    }

    @discardableResult
    mutating func signPlayer(playerID: Int) -> Bool {
        guard canSign(playerID: playerID),
              let selectedClubID,
              let index = players.firstIndex(where: { $0.id == playerID && $0.teamID == nil }) else { return false }
        transferBudget -= players[index].marketValue
        players[index].teamID = selectedClubID
        if players[index].position == .goalkeeper && !startingXI.contains(where: { id in
            players.first(where: { $0.id == id })?.position == .goalkeeper
        }) {
            startingXI.append(playerID)
        }
        return true
    }

    @discardableResult
    mutating func simulateNextRound() -> Bool {
        guard let selectedClubID, !isSeasonComplete else { return false }
        let round = currentRound + 1
        let matchIndices = fixtures.indices.filter { fixtures[$0].round == round && !fixtures[$0].isPlayed }
        guard matchIndices.count == 4 else { return false }
        _ = applyWeeklyTraining(for: round)

        for fixtureIndex in matchIndices {
            var fixture = fixtures[fixtureIndex]
            var random = FootballRandom(seed: matchSeed(fixtureID: fixture.id))
            let homeFormation = fixture.home == selectedClubID ? formation : .fourFourTwo
            let awayFormation = fixture.away == selectedClubID ? formation : .fourFourTwo
            let homeStyle = matchPlayStyle(for: fixture.home)
            let awayStyle = matchPlayStyle(for: fixture.away)
            let homeBase = teamPower(teamID: fixture.home, formation: homeFormation)
            let awayBase = teamPower(teamID: fixture.away, formation: awayFormation)
            let homeAttack = homeBase + homeFormation.attackBonus + homeStyle.attackAdjustment + homeStyle.controlAdjustment / 2 + 2
            let homeDefense = homeBase + homeFormation.defenseBonus + homeStyle.defenseAdjustment
            let awayAttack = awayBase + awayFormation.attackBonus + awayStyle.attackAdjustment + awayStyle.controlAdjustment / 2
            let awayDefense = awayBase + awayFormation.defenseBonus + awayStyle.defenseAdjustment
            let homeExpectedGoals = min(2.5, max(0.35, 1.12 + Double(homeAttack - awayDefense) / 28))
            let awayExpectedGoals = min(2.5, max(0.35, 1.08 + Double(awayAttack - homeDefense) / 29))
            let homeGoals = FootballRandom.poisson(lambda: homeExpectedGoals, using: &random)
            let awayGoals = FootballRandom.poisson(lambda: awayExpectedGoals, using: &random)
            let homeShots = homeGoals + random.int(in: 2...7)
            let awayShots = awayGoals + random.int(in: 2...7)
            let homeControl = homeBase + homeFormation.midfieldBonus + homeStyle.controlAdjustment + 2
            let awayControl = awayBase + awayFormation.midfieldBonus + awayStyle.controlAdjustment
            let homePossession = min(68, max(32, 50 + (homeControl - awayControl) * 2 + random.int(in: -5...5)))
            let homeLineup = lineUp(teamID: fixture.home, formation: homeFormation)
            let awayLineup = lineUp(teamID: fixture.away, formation: awayFormation)
            let homeScorers = chooseScorers(goals: homeGoals, from: homeLineup, using: &random)
            let awayScorers = chooseScorers(goals: awayGoals, from: awayLineup, using: &random)

            recordAppearances(for: homeLineup)
            recordAppearances(for: awayLineup)
            recordGoals(homeScorers, from: homeLineup, using: &random)
            recordGoals(awayScorers, from: awayLineup, using: &random)

            fixture.homeGoals = homeGoals
            fixture.awayGoals = awayGoals
            fixture.homeScorerIDs = homeScorers
            fixture.awayScorerIDs = awayScorers
            fixture.homeShots = homeShots
            fixture.awayShots = awayShots
            fixture.homePossession = homePossession
            fixture.awayPossession = 100 - homePossession
            if fixture.home == selectedClubID || fixture.away == selectedClubID {
                fixture.commentary = makeCommentary(
                    home: fixture.home,
                    away: fixture.away,
                    homeGoals: homeGoals,
                    awayGoals: awayGoals,
                    homeScorers: homeScorers,
                    awayScorers: awayScorers,
                    using: &random
                )
            }
            fixtures[fixtureIndex] = fixture
        }

        currentRound = round
        for index in players.indices where players[index].teamID == selectedClubID {
            if startingXI.contains(players[index].id) {
                players[index].condition = max(42, players[index].condition - playStyle.fatigueCost)
            } else {
                players[index].condition = min(100, players[index].condition + 7)
            }
        }
        return true
    }

    mutating func startNextSeason() {
        guard isSeasonComplete else { return }
        let previousChampion = championID
        if let previousChampion { champions.append(previousChampion) }
        if previousChampion == selectedClubID { transferBudget += 750_000 }
        else { transferBudget += 250_000 }
        season += 1
        currentRound = 0
        fixtures = FootballSeason.fixtures()
        lastTrainingReport = nil
        for index in players.indices {
            players[index].goals = 0
            players[index].assists = 0
            players[index].appearances = 0
            players[index].condition = min(100, players[index].condition + 18)
        }
        if let selectedClubID {
            startingXI = FootballSeason.lineUp(teamID: selectedClubID, players: players, formation: formation)
        }
    }

    private func lineUp(teamID: Int, formation: FootballFormation) -> [Int] {
        if teamID == selectedClubID, startingXI.count == 11 { return startingXI }
        return FootballSeason.lineUp(teamID: teamID, players: players, formation: formation)
    }

    private func teamPower(teamID: Int, formation: FootballFormation) -> Int {
        let ids = lineUp(teamID: teamID, formation: formation)
        let selectedPlayers = ids.compactMap { id in players.first(where: { $0.id == id }) }
        guard !selectedPlayers.isEmpty else {
            return FootballSeason.teams.first(where: { $0.id == teamID })?.strength ?? 65
        }
        let rating = selectedPlayers.map(\.effectiveOverall).reduce(0, +) / Double(selectedPlayers.count)
        return Int(rating.rounded())
    }

    private func marketValue(for player: FootballPlayer, overall: Int) -> Int {
        let valueBase = max(150_000, (overall - 38) * (overall - 38) * 1_250)
        let ageFactor = player.age <= 23 ? 1.25 : (player.age >= 31 ? 0.75 : 1.0)
        return Int(Double(valueBase) * ageFactor)
    }

    private func matchPlayStyle(for teamID: Int) -> FootballPlayStyle {
        guard teamID == selectedClubID else {
            let index = (teamID + season - 1) % FootballPlayStyle.allCases.count
            return FootballPlayStyle.allCases[index]
        }
        return playStyle
    }

    private func matchSeed(fixtureID: Int) -> UInt64 {
        UInt64(bitPattern: Int64(seed))
            &+ UInt64(season) &* 0x9E3779B97F4A7C15
            &+ UInt64(fixtureID + 1) &* 0xBF58476D1CE4E5B9
    }

    private func chooseScorers(goals: Int, from lineUp: [Int], using random: inout FootballRandom) -> [Int] {
        let candidates = lineUp.compactMap { id in players.first(where: { $0.id == id }) }
        guard !candidates.isEmpty else { return [] }
        return (0..<goals).compactMap { _ in
            let weights = candidates.map { player -> Int in
                switch player.position {
                case .goalkeeper: return 1
                case .defender: return 2
                case .midfielder: return 4
                case .forward: return 7
                }
            }
            let total = weights.reduce(0, +)
            var draw = random.int(in: 1...total)
            for (index, weight) in weights.enumerated() {
                draw -= weight
                if draw <= 0 { return candidates[index].id }
            }
            return candidates.last?.id
        }
    }

    private mutating func recordAppearances(for lineUp: [Int]) {
        for id in lineUp {
            guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
            players[index].appearances += 1
        }
    }

    private mutating func recordGoals(_ scorers: [Int], from lineUp: [Int], using random: inout FootballRandom) {
        for scorerID in scorers {
            guard let scorerIndex = players.firstIndex(where: { $0.id == scorerID }) else { continue }
            players[scorerIndex].goals += 1
            let potentialAssists = lineUp.filter { $0 != scorerID }
            guard !potentialAssists.isEmpty, random.int(in: 0...99) < 66,
                  let assistID = potentialAssists.randomElement(using: &random),
                  let assistIndex = players.firstIndex(where: { $0.id == assistID }) else { continue }
            players[assistIndex].assists += 1
        }
    }

    private func makeCommentary(
        home: Int,
        away: Int,
        homeGoals: Int,
        awayGoals: Int,
        homeScorers: [Int],
        awayScorers: [Int],
        using random: inout FootballRandom
    ) -> [String] {
        let homeName = FootballSeason.teams.first(where: { $0.id == home })?.name ?? "Mandante"
        let awayName = FootballSeason.teams.first(where: { $0.id == away })?.name ?? "Visitante"
        var events: [(minute: Int, text: String)] = []
        for (teamID, scorers) in [(home, homeScorers), (away, awayScorers)] {
            let teamName = teamID == home ? homeName : awayName
            for scorerID in scorers {
                let name = players.first(where: { $0.id == scorerID })?.name ?? "Atleta"
                events.append((random.int(in: 4...89), "\(name) marca para \(teamName)."))
            }
        }
        events.sort { $0.minute < $1.minute }
        var lines = events.map { "\($0.minute)′ — \($0.text)" }
        if lines.isEmpty { lines.append("As defesas levaram a melhor e o placar não saiu do zero.") }
        lines.append("Apito final: \(homeName) \(homeGoals) × \(awayGoals) \(awayName).")
        return lines
    }
}

private struct FootballRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % width)
    }

    static func poisson(lambda: Double, using random: inout FootballRandom) -> Int {
        let draw = Double(random.next() >> 11) / Double(1 << 53)
        var probability = exp(-lambda)
        var cumulative = probability
        if draw < cumulative { return 0 }
        for goals in 1...6 {
            probability *= lambda / Double(goals)
            cumulative += probability
            if draw < cumulative { return goals }
        }
        return 6
    }
}
