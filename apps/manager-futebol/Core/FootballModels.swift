import Foundation

struct LeagueTeam: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let shortName: String
    let city: String
    let stadium: String
    let capacity: Int
    let strength: Int
    let startingBudget: Int
    let preferredStyle: FootballPlayStyle
    let preferredFormation: FootballFormation
    let initialDivision: Division

    /// Região do país: 0 Norte, 1 Nordeste, 2 Centro-Oeste, 3 Sudeste, 4 Sul.
    var region: Int {
        switch id {
        case 6, 17: return 0
        case 2, 9, 14, 15, 16: return 1
        case 0, 1, 10: return 2
        case 3, 5, 11, 12, 19: return 3
        default: return 4
        }
    }

    static let regionNames = ["Norte", "Nordeste", "Centro-Oeste", "Sudeste", "Sul"]
}

enum Division: Int, Codable, CaseIterable, Identifiable, Comparable {
    case serieA = 1
    case serieB = 2

    var id: Int { rawValue }
    var name: String { self == .serieA ? "Série A" : "Série B" }

    static func < (lhs: Division, rhs: Division) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum CupRound: Int, Codable, CaseIterable, Comparable {
    case preliminary = 0
    case roundOf16
    case quarterFinal
    case semiFinal
    case final

    var name: String {
        switch self {
        case .preliminary: return "Fase preliminar"
        case .roundOf16: return "Oitavas de final"
        case .quarterFinal: return "Quartas de final"
        case .semiFinal: return "Semifinal"
        case .final: return "Final"
        }
    }

    var next: CupRound? { CupRound(rawValue: rawValue + 1) }

    /// Nome com a preposição certa: "na semifinal", "nas oitavas de final".
    var withPreposition: String {
        switch self {
        case .roundOf16, .quarterFinal: return "nas \(name.lowercased())"
        default: return "na \(name.lowercased())"
        }
    }

    /// Bônus pago ao clube do usuário por avançar desta fase.
    var advanceBonus: Int {
        switch self {
        case .preliminary: return 150_000
        case .roundOf16: return 300_000
        case .quarterFinal: return 500_000
        case .semiFinal: return 900_000
        case .final: return 2_000_000
        }
    }

    static func < (lhs: CupRound, rhs: CupRound) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum Competition: Codable, Hashable {
    case league(Division)
    case cup(CupRound)

    var name: String {
        switch self {
        case .league(let division): return division.name
        case .cup: return "Copa Nacional"
        }
    }

    var isCup: Bool {
        if case .cup = self { return true }
        return false
    }

    var division: Division? {
        if case .league(let division) = self { return division }
        return nil
    }

    var cupRound: CupRound? {
        if case .cup(let round) = self { return round }
        return nil
    }
}

/// Um dia de jogo do calendário: rodada de liga no fim de semana ou fase da copa no meio de semana.
struct MatchDaySlot: Equatable {
    let index: Int
    let week: Int
    let isMidweek: Bool
    let leagueRound: Int?
    let cupRound: CupRound?

    var title: String {
        if let leagueRound { return "Rodada \(leagueRound)" }
        if let cupRound { return "Copa · \(cupRound.name)" }
        return "Dia de jogo"
    }

    var dayName: String { isMidweek ? "Quarta-feira" : "Domingo" }
}

enum FootballPosition: String, CaseIterable, Codable, Hashable {
    case goalkeeper = "GOL"
    case defender = "ZAG"
    case midfielder = "MEI"
    case forward = "ATA"

    var title: String {
        switch self {
        case .goalkeeper: return "Goleiros"
        case .defender: return "Defensores"
        case .midfielder: return "Meio-campistas"
        case .forward: return "Atacantes"
        }
    }

    var singularTitle: String {
        switch self {
        case .goalkeeper: return "Goleiro"
        case .defender: return "Defensor"
        case .midfielder: return "Meio-campista"
        case .forward: return "Atacante"
        }
    }

    var sortOrder: Int {
        switch self {
        case .goalkeeper: return 0
        case .defender: return 1
        case .midfielder: return 2
        case .forward: return 3
        }
    }

    /// Peso de finalização: goleiros nunca são sorteados como autores de gol.
    var scoringWeight: Int {
        switch self {
        case .goalkeeper: return 0
        case .defender: return 2
        case .midfielder: return 5
        case .forward: return 11
        }
    }

    var assistWeight: Int {
        switch self {
        case .goalkeeper: return 0
        case .defender: return 2
        case .midfielder: return 6
        case .forward: return 4
        }
    }
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

    /// Linhas do campo, do gol ao ataque, usadas pelo campinho tático.
    var pitchRows: [[FootballPosition]] {
        switch self {
        case .fourFourTwo:
            return [[.goalkeeper], Array(repeating: .defender, count: 4), Array(repeating: .midfielder, count: 4), Array(repeating: .forward, count: 2)]
        case .fourThreeThree:
            return [[.goalkeeper], Array(repeating: .defender, count: 4), Array(repeating: .midfielder, count: 3), Array(repeating: .forward, count: 3)]
        case .fourTwoThreeOne:
            return [[.goalkeeper], Array(repeating: .defender, count: 4), Array(repeating: .midfielder, count: 2), Array(repeating: .midfielder, count: 3), [.forward]]
        }
    }

    var attackBonus: Int {
        switch self {
        case .fourFourTwo: return 0
        case .fourThreeThree: return 3
        case .fourTwoThreeOne: return 0
        }
    }

    var midfieldBonus: Int {
        switch self {
        case .fourFourTwo: return 0
        case .fourThreeThree: return -1
        case .fourTwoThreeOne: return 3
        }
    }

    var defenseBonus: Int {
        switch self {
        case .fourFourTwo: return 0
        case .fourThreeThree: return -2
        case .fourTwoThreeOne: return 1
        }
    }

    var summary: String {
        switch self {
        case .fourFourTwo: return "Equilíbrio entre defesa, meio-campo e dois atacantes."
        case .fourThreeThree: return "Mais presença ofensiva com três atacantes, ao custo de proteção defensiva."
        case .fourTwoThreeOne: return "Meio-campo povoado: mais posse de bola e uma defesa mais protegida."
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
        case .possession: return 0
        case .counter: return 2
        case .highPress: return 2
        }
    }

    var defenseAdjustment: Int {
        switch self {
        case .balanced: return 0
        case .attacking: return -3
        case .defensive: return 4
        case .possession: return 0
        case .counter: return 1
        case .highPress: return -1
        }
    }

    var controlAdjustment: Int {
        switch self {
        case .balanced: return 0
        case .attacking: return 1
        case .defensive: return -3
        case .possession: return 5
        case .counter: return -4
        case .highPress: return 2
        }
    }

    var fatigueCost: Int {
        switch self {
        case .balanced: return 8
        case .attacking: return 10
        case .defensive: return 7
        case .possession: return 9
        case .counter: return 9
        case .highPress: return 11
        }
    }

    /// Vantagem tática de um estilo contra o estilo do adversário (pedra-papel-tesoura).
    func attackBonus(against opponent: FootballPlayStyle) -> Int {
        switch (self, opponent) {
        case (.counter, .possession): return 5
        case (.counter, .highPress): return 4
        case (.counter, .attacking): return 4
        case (.counter, .defensive): return -4
        case (.possession, .defensive): return 4
        case (.possession, .highPress): return -4
        case (.highPress, .possession): return 5
        case (.highPress, .balanced): return 3
        case (.highPress, .counter): return -3
        case (.attacking, .defensive): return -3
        case (.attacking, .balanced): return 1
        case (.defensive, .attacking): return 3
        default: return 0
        }
    }

    /// Saldo esperado de um estilo contra o estilo do rival: confronto tático, ajustes de ataque/defesa,
    /// controle do meio-campo e o custo físico acima do plano equilibrado.
    func edge(against opponent: FootballPlayStyle) -> Double {
        let attack = Double(attackAdjustment + attackBonus(against: opponent))
        let defense = Double(defenseAdjustment - opponent.attackBonus(against: self))
        let control = Double(controlAdjustment - opponent.controlAdjustment) * 0.2
        let fatigue = Double(fatigueCost - FootballPlayStyle.balanced.fatigueCost) * 1.0
        return attack + defense + control - fatigue
    }

    /// Estilo com melhor saldo esperado contra o estilo informado.
    static func bestAnswer(to opponent: FootballPlayStyle) -> FootballPlayStyle {
        allCases.max { lhs, rhs in
            let left = lhs.edge(against: opponent)
            let right = rhs.edge(against: opponent)
            if left != right { return left < right }
            return lhs.fatigueCost > rhs.fatigueCost
        } ?? .balanced
    }

    var summary: String {
        switch self {
        case .balanced: return "Um plano sem grandes riscos, com energia preservada."
        case .attacking: return "Aumenta a força ofensiva, mas deixa espaços na defesa. Sofre contra retrancas."
        case .defensive: return "Protege a defesa e poupa energia. Neutraliza ataques e contra-ataques."
        case .possession: return "Controla a bola e cria mais chances. Forte contra retrancas, frágil contra pressão alta."
        case .counter: return "Transições rápidas. Pune times de posse, pressão alta e ofensivos."
        case .highPress: return "Sufoca a saída adversária, com alto custo físico. Vulnerável ao contra-ataque."
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
    case setPieces = "Bola parada"

    var id: String { rawValue }

    var developmentPositions: [FootballPosition] {
        switch self {
        case .physical: return FootballPosition.allCases
        case .recovery, .setPieces: return []
        case .technical: return [.midfielder, .forward]
        case .tactical: return [.defender, .midfielder]
        case .defending: return [.goalkeeper, .defender]
        case .attacking: return [.midfielder, .forward]
        }
    }

    var summary: String {
        switch self {
        case .physical: return "Prepara o elenco inteiro; intensidade maior desenvolve mais, mas reduz a recuperação."
        case .technical: return "Meio-campistas e atacantes podem evoluir."
        case .tactical: return "Defensores e meio-campistas podem evoluir."
        case .defending: return "Goleiros e defensores podem evoluir."
        case .attacking: return "Atacantes e meio-campistas podem evoluir."
        case .recovery: return "Semana regenerativa: não há evolução técnica, mas o elenco recupera mais condição."
        case .setPieces: return "Ensaia cobranças de falta, escanteios e pênaltis: mais perigo nas bolas paradas."
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
        case .balanced: return 18
        case .intense: return 30
        }
    }

    func conditionRecovery(for focus: FootballTrainingFocus) -> Int {
        if focus == .setPieces { return 8 }
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
        case .balanced: recovery = 9
        case .intense: recovery = 6
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
    var detail: PositionDetail
    var age: Int
    var overall: Int
    var potential: Int
    var condition: Int
    var marketValue: Int
    var teamID: Int?
    var attributes: PlayerAttributes
    var traits: [PlayerTrait]
    var morale: Int
    var contract: PlayerContract
    var form: PlayerForm
    var discipline: PlayerDiscipline
    var region: Int
    var goals = 0
    var assists = 0
    var appearances = 0
    var injuryRounds = 0
    var careerGoals = 0
    /// Jogos seguidos sem entrar em campo (alimenta o moral e os pedidos).
    var benchStreak = 0
    var isYouth = false
    /// Clube dono do atleta quando ele está emprestado a outro clube.
    var parentTeamID: Int? = nil
    /// Preço fixado para comprar o atleta durante um empréstimo.
    var purchaseOption: Int? = nil
    var isListed = false
    var isLoanListed = false
    /// Dia de jogo em que o atleta está servindo a seleção e não pode ser escalado.
    var nationalDutyMatchDay: Int? = nil
    var learnedPositions: [FootballPosition] = []
    var individualFocus: AttributeKind? = nil
    /// Posição que o atleta está aprendendo no treino individual e o progresso (6 sessões para aprender).
    var learningPosition: FootballPosition? = nil
    var learningProgress = 0
    var careerAppearances = 0

    private enum CodingKeys: String, CodingKey {
        case id, name, position, detail, age, overall, potential, condition, marketValue, teamID
        case attributes, traits, morale, contract, form, discipline, region
        case goals, assists, appearances, injuryRounds, careerGoals, benchStreak, isYouth
        case parentTeamID, purchaseOption, isListed, isLoanListed, nationalDutyMatchDay, learnedPositions, individualFocus
        case learningPosition, learningProgress, careerAppearances
    }

    init(id: Int, name: String, position: FootballPosition, age: Int, overall: Int, potential: Int,
         condition: Int, marketValue: Int, teamID: Int?, detail: PositionDetail? = nil,
         attributes: PlayerAttributes? = nil, traits: [PlayerTrait] = [], region: Int? = nil) {
        self.id = id
        self.name = name
        self.position = position
        let resolvedDetail = detail ?? PositionDetail.defaults(for: position)[id % PositionDetail.defaults(for: position).count]
        self.detail = resolvedDetail
        self.age = age
        self.overall = overall
        self.potential = max(potential, overall)
        self.condition = condition
        self.marketValue = marketValue
        self.teamID = teamID
        if let attributes {
            self.attributes = attributes
        } else {
            var random = FootballRandom(seed: UInt64(bitPattern: Int64(id)) &* 0x9E3779B97F4A7C15 ^ 0xA77121B07E5)
            self.attributes = PlayerAttributes.derive(overall: overall, position: position, detail: resolvedDetail, random: &random)
        }
        self.traits = traits
        self.morale = 60
        self.contract = PlayerContract(wage: PlayerContract.wage(forValue: marketValue), endSeason: 0, status: .rotation)
        self.form = PlayerForm()
        self.discipline = PlayerDiscipline()
        self.region = region ?? (id % 5)
    }

    /// Decodificação tolerante: campos novos ganham valores coerentes em saves antigos.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Atleta"
        let decodedPosition = try container.decodeIfPresent(FootballPosition.self, forKey: .position) ?? .midfielder
        position = decodedPosition
        let defaults = PositionDetail.defaults(for: decodedPosition)
        let decodedDetail = try container.decodeIfPresent(PositionDetail.self, forKey: .detail) ?? defaults[id % defaults.count]
        detail = decodedDetail
        age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 25
        let decodedOverall = try container.decodeIfPresent(Int.self, forKey: .overall) ?? 65
        overall = decodedOverall
        potential = max(decodedOverall, try container.decodeIfPresent(Int.self, forKey: .potential) ?? decodedOverall)
        condition = try container.decodeIfPresent(Int.self, forKey: .condition) ?? 90
        let decodedValue = try container.decodeIfPresent(Int.self, forKey: .marketValue) ?? 0
        marketValue = decodedValue
        teamID = try container.decodeIfPresent(Int.self, forKey: .teamID)
        if let decodedAttributes = try container.decodeIfPresent(PlayerAttributes.self, forKey: .attributes) {
            attributes = decodedAttributes
        } else {
            var random = FootballRandom(seed: UInt64(bitPattern: Int64(id)) &* 0x9E3779B97F4A7C15 ^ 0xA77121B07E5)
            attributes = PlayerAttributes.derive(overall: decodedOverall, position: decodedPosition, detail: decodedDetail, random: &random)
        }
        traits = try container.decodeIfPresent([PlayerTrait].self, forKey: .traits) ?? []
        morale = try container.decodeIfPresent(Int.self, forKey: .morale) ?? 60
        contract = try container.decodeIfPresent(PlayerContract.self, forKey: .contract)
            ?? PlayerContract(wage: PlayerContract.wage(forValue: decodedValue), endSeason: 0, status: .rotation)
        form = try container.decodeIfPresent(PlayerForm.self, forKey: .form) ?? PlayerForm()
        discipline = try container.decodeIfPresent(PlayerDiscipline.self, forKey: .discipline) ?? PlayerDiscipline()
        region = try container.decodeIfPresent(Int.self, forKey: .region) ?? (id % 5)
        goals = try container.decodeIfPresent(Int.self, forKey: .goals) ?? 0
        assists = try container.decodeIfPresent(Int.self, forKey: .assists) ?? 0
        appearances = try container.decodeIfPresent(Int.self, forKey: .appearances) ?? 0
        injuryRounds = try container.decodeIfPresent(Int.self, forKey: .injuryRounds) ?? 0
        careerGoals = try container.decodeIfPresent(Int.self, forKey: .careerGoals) ?? goals
        benchStreak = try container.decodeIfPresent(Int.self, forKey: .benchStreak) ?? 0
        isYouth = try container.decodeIfPresent(Bool.self, forKey: .isYouth) ?? false
        parentTeamID = try container.decodeIfPresent(Int.self, forKey: .parentTeamID)
        purchaseOption = try container.decodeIfPresent(Int.self, forKey: .purchaseOption)
        isListed = try container.decodeIfPresent(Bool.self, forKey: .isListed) ?? false
        isLoanListed = try container.decodeIfPresent(Bool.self, forKey: .isLoanListed) ?? false
        nationalDutyMatchDay = try container.decodeIfPresent(Int.self, forKey: .nationalDutyMatchDay)
        learnedPositions = try container.decodeIfPresent([FootballPosition].self, forKey: .learnedPositions) ?? []
        individualFocus = try container.decodeIfPresent(AttributeKind.self, forKey: .individualFocus)
        learningPosition = try container.decodeIfPresent(FootballPosition.self, forKey: .learningPosition)
        learningProgress = try container.decodeIfPresent(Int.self, forKey: .learningProgress) ?? 0
        careerAppearances = try container.decodeIfPresent(Int.self, forKey: .careerAppearances) ?? appearances
    }

    var isInjured: Bool { injuryRounds > 0 }

    var isSuspended: Bool { discipline.suspensionGames > 0 }

    var moraleLevel: MoraleLevel { MoraleLevel(value: morale) }

    var onLoan: Bool { parentTeamID != nil }

    /// Pode ser escalado na partida do dia informado.
    func isAvailable(matchDay: Int) -> Bool {
        !isInjured && !isSuspended && nationalDutyMatchDay != matchDay
    }

    /// Força em campo: condição física e moral influenciam o geral.
    var effectiveOverall: Double {
        Double(overall) * (0.72 + 0.28 * Double(condition) / 100) * (0.96 + 0.08 * Double(morale) / 100) * (isInjured ? 0.88 : 1)
    }

    func has(_ trait: PlayerTrait) -> Bool { traits.contains(trait) }

    var lastName: String {
        name.split(separator: " ").last.map(String.init) ?? name
    }

    /// Recalcula o geral a partir dos atributos e da posição natural.
    mutating func recomputeOverall() {
        overall = attributes.overall(for: position)
        if overall > potential { potential = overall }
    }

    /// Leva o geral ao valor desejado ajustando os atributos mais importantes da posição.
    mutating func setOverall(_ target: Int) {
        let clamped = min(96, max(40, target))
        attributes.calibrate(to: clamped, position: position)
        overall = attributes.overall(for: position)
        if overall > potential { potential = overall }
    }

    /// Atributos que cada foco de treino pode melhorar para a posição do atleta.
    static func trainableAttributes(focus: FootballTrainingFocus, position: FootballPosition) -> [AttributeKind] {
        switch (focus, position) {
        case (.recovery, _), (.setPieces, _): return []
        case (.physical, _): return [.pace, .stamina, .strength]
        case (.technical, .goalkeeper): return [.distribution, .handling]
        case (.technical, _): return [.passing, .dribbling, .finishing, .vision]
        case (.tactical, .goalkeeper): return [.positioning, .decisions]
        case (.tactical, _): return [.positioning, .decisions, .marking, .vision]
        case (.defending, .goalkeeper): return [.reflexes, .handling, .positioning]
        case (.defending, _): return [.marking, .tackling, .positioning, .heading]
        case (.attacking, .goalkeeper): return [.distribution]
        case (.attacking, _): return [.finishing, .dribbling, .pace, .heading]
        }
    }

    /// Declínio com a idade: os atributos físicos caem primeiro.
    mutating func decline(by points: Int, random: inout FootballRandom) {
        guard points > 0 else { return }
        for _ in 0..<points {
            let kind = [AttributeKind.pace, .stamina, .strength, .pace, .dribbling][random.int(in: 0...4)]
            attributes[kind] -= 1
        }
        let target = max(48, overall - points)
        attributes.calibrate(to: target, position: position)
        overall = max(48, attributes.overall(for: position))
    }

    func canPlay(as target: FootballPosition) -> Bool {
        position == target || learnedPositions.contains(target)
    }
}

struct MatchEvent: Codable, Equatable {
    enum Kind: String, Codable {
        case kickoff, goal, chance, save, halfTime, tactic, substitution, fullTime, injury, extraTime, penalties
        case yellowCard, redCard, penaltyAwarded, stoppage, pressure
        case offside, tackle, dribble, cross, woodwork
    }

    let minute: Int
    let kind: Kind
    let teamID: Int?
    let text: String
    var playerID: Int? = nil
    var relatedPlayerID: Int? = nil
    var xg: Double? = nil
    /// Posição do lance em coordenadas do campo: x é a distância do gol atacado (0 a 1), y a lateral (0 a 1).
    var x: Double? = nil
    var y: Double? = nil
    /// Minutos de acréscimo em que o lance aconteceu (mostra 90+N).
    var added: Int? = nil

    var minuteLabel: String {
        if kind == .kickoff { return "0′" }
        if let added { return "90+\(added)′" }
        return "\(minute)′"
    }
}

struct LeagueFixture: Identifiable, Codable, Equatable {
    let id: Int
    let matchDay: Int
    let round: Int
    let competition: Competition
    let home: Int
    let away: Int
    var homeGoals: Int?
    var awayGoals: Int?
    var homeScorerIDs: [Int] = []
    var awayScorerIDs: [Int] = []
    var commentary: [String] = []
    var events: [MatchEvent] = []
    var homeShots: Int? = nil
    var awayShots: Int? = nil
    var homeOnTarget: Int? = nil
    var awayOnTarget: Int? = nil
    var homePossession: Int? = nil
    var awayPossession: Int? = nil
    var homeExpectedGoals: Double? = nil
    var awayExpectedGoals: Double? = nil
    var wentToExtraTime = false
    var homePenalties: Int? = nil
    var awayPenalties: Int? = nil
    /// Notas e números individuais do clube do usuário nesta partida.
    var userStats: [PlayerMatchStats] = []
    var homeCorners: Int? = nil
    var awayCorners: Int? = nil
    var homeFouls: Int? = nil
    var awayFouls: Int? = nil
    var homeYellow: Int? = nil
    var awayYellow: Int? = nil
    var homeRed: Int? = nil
    var awayRed: Int? = nil
    /// Domínio da partida minuto a minuto (positivo favorece o mandante), só nos jogos do usuário.
    var momentum: [Int] = []
    var attendance: Int? = nil
    var impact: MatchImpact? = nil
    var summary: PostMatchSummary? = nil
    /// Detalhes usados pelo fantasy game e pelas notícias.
    var assistIDs: [Int] = []
    var playedIDs: [Int] = []
    var yellowIDs: [Int] = []
    var redIDs: [Int] = []

    private enum CodingKeys: String, CodingKey {
        case id, matchDay, round, competition, home, away, homeGoals, awayGoals, homeScorerIDs, awayScorerIDs, commentary, events
        case homeShots, awayShots, homeOnTarget, awayOnTarget, homePossession, awayPossession
        case homeExpectedGoals, awayExpectedGoals, wentToExtraTime, homePenalties, awayPenalties, userStats
        case homeCorners, awayCorners, homeFouls, awayFouls, homeYellow, awayYellow, homeRed, awayRed, momentum, attendance, impact, summary
        case assistIDs, playedIDs, yellowIDs, redIDs
    }

    init(id: Int, matchDay: Int, round: Int, competition: Competition, home: Int, away: Int) {
        self.id = id
        self.matchDay = matchDay
        self.round = round
        self.competition = competition
        self.home = home
        self.away = away
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        round = try container.decode(Int.self, forKey: .round)
        matchDay = try container.decodeIfPresent(Int.self, forKey: .matchDay) ?? max(0, round - 1)
        competition = try container.decodeIfPresent(Competition.self, forKey: .competition) ?? .league(.serieA)
        home = try container.decode(Int.self, forKey: .home)
        away = try container.decode(Int.self, forKey: .away)
        homeGoals = try container.decodeIfPresent(Int.self, forKey: .homeGoals)
        awayGoals = try container.decodeIfPresent(Int.self, forKey: .awayGoals)
        homeScorerIDs = try container.decodeIfPresent([Int].self, forKey: .homeScorerIDs) ?? []
        awayScorerIDs = try container.decodeIfPresent([Int].self, forKey: .awayScorerIDs) ?? []
        commentary = try container.decodeIfPresent([String].self, forKey: .commentary) ?? []
        events = try container.decodeIfPresent([MatchEvent].self, forKey: .events) ?? []
        homeShots = try container.decodeIfPresent(Int.self, forKey: .homeShots)
        awayShots = try container.decodeIfPresent(Int.self, forKey: .awayShots)
        homeOnTarget = try container.decodeIfPresent(Int.self, forKey: .homeOnTarget)
        awayOnTarget = try container.decodeIfPresent(Int.self, forKey: .awayOnTarget)
        homePossession = try container.decodeIfPresent(Int.self, forKey: .homePossession)
        awayPossession = try container.decodeIfPresent(Int.self, forKey: .awayPossession)
        homeExpectedGoals = try container.decodeIfPresent(Double.self, forKey: .homeExpectedGoals)
        awayExpectedGoals = try container.decodeIfPresent(Double.self, forKey: .awayExpectedGoals)
        wentToExtraTime = try container.decodeIfPresent(Bool.self, forKey: .wentToExtraTime) ?? false
        homePenalties = try container.decodeIfPresent(Int.self, forKey: .homePenalties)
        awayPenalties = try container.decodeIfPresent(Int.self, forKey: .awayPenalties)
        userStats = try container.decodeIfPresent([PlayerMatchStats].self, forKey: .userStats) ?? []
        homeCorners = try container.decodeIfPresent(Int.self, forKey: .homeCorners)
        awayCorners = try container.decodeIfPresent(Int.self, forKey: .awayCorners)
        homeFouls = try container.decodeIfPresent(Int.self, forKey: .homeFouls)
        awayFouls = try container.decodeIfPresent(Int.self, forKey: .awayFouls)
        homeYellow = try container.decodeIfPresent(Int.self, forKey: .homeYellow)
        awayYellow = try container.decodeIfPresent(Int.self, forKey: .awayYellow)
        homeRed = try container.decodeIfPresent(Int.self, forKey: .homeRed)
        awayRed = try container.decodeIfPresent(Int.self, forKey: .awayRed)
        momentum = try container.decodeIfPresent([Int].self, forKey: .momentum) ?? []
        attendance = try container.decodeIfPresent(Int.self, forKey: .attendance)
        impact = try container.decodeIfPresent(MatchImpact.self, forKey: .impact)
        summary = try container.decodeIfPresent(PostMatchSummary.self, forKey: .summary)
        assistIDs = try container.decodeIfPresent([Int].self, forKey: .assistIDs) ?? []
        playedIDs = try container.decodeIfPresent([Int].self, forKey: .playedIDs) ?? []
        yellowIDs = try container.decodeIfPresent([Int].self, forKey: .yellowIDs) ?? []
        redIDs = try container.decodeIfPresent([Int].self, forKey: .redIDs) ?? []
    }

    var isPlayed: Bool { homeGoals != nil && awayGoals != nil }

    func involves(_ teamID: Int) -> Bool { home == teamID || away == teamID }

    func opponent(of teamID: Int) -> Int { home == teamID ? away : home }

    /// Vencedor considerando prorrogação e pênaltis; nil em empate de liga ou jogo não disputado.
    var winner: Int? {
        guard let homeGoals, let awayGoals else { return nil }
        if homeGoals != awayGoals { return homeGoals > awayGoals ? home : away }
        if let homePenalties, let awayPenalties, homePenalties != awayPenalties {
            return homePenalties > awayPenalties ? home : away
        }
        return nil
    }

    /// "V", "E" ou "D" do ponto de vista do clube informado (pênaltis contam como empate).
    func result(for teamID: Int) -> FootballResult? {
        guard let homeGoals, let awayGoals, involves(teamID) else { return nil }
        let own = home == teamID ? homeGoals : awayGoals
        let other = home == teamID ? awayGoals : homeGoals
        if own > other { return .win }
        if own < other { return .loss }
        return .draw
    }

    /// "Série A · Rodada 5" ou "Copa Nacional · Oitavas de final".
    var title: String {
        if let cupRound = competition.cupRound { return "Copa Nacional · \(cupRound.name)" }
        return "\(competition.name) · Rodada \(round)"
    }

    var penaltySummary: String? {
        guard let homePenalties, let awayPenalties else { return nil }
        return "\(homePenalties) × \(awayPenalties) nos pênaltis"
    }
}

enum FootballResult: String, Codable {
    case win = "V"
    case draw = "E"
    case loss = "D"
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
    var form: [FootballResult] = []

    var id: Int { team.id }
    var goalDifference: Int { goalsFor - goalsAgainst }
}

enum OfferKind: String, Codable {
    case purchase, loan
}

struct TransferOffer: Identifiable, Codable, Equatable {
    let id: Int
    let playerID: Int
    let clubID: Int
    let amount: Int
    let expiresAfterRound: Int
    var kind: OfferKind = .purchase

    init(id: Int, playerID: Int, clubID: Int, amount: Int, expiresAfterRound: Int, kind: OfferKind = .purchase) {
        self.id = id
        self.playerID = playerID
        self.clubID = clubID
        self.amount = amount
        self.expiresAfterRound = expiresAfterRound
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey { case id, playerID, clubID, amount, expiresAfterRound, kind }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        playerID = try container.decode(Int.self, forKey: .playerID)
        clubID = try container.decode(Int.self, forKey: .clubID)
        amount = try container.decode(Int.self, forKey: .amount)
        expiresAfterRound = try container.decodeIfPresent(Int.self, forKey: .expiresAfterRound) ?? 0
        kind = try container.decodeIfPresent(OfferKind.self, forKey: .kind) ?? .purchase
    }
}

struct SeasonRecord: Codable, Equatable, Identifiable {
    let season: Int
    let clubID: Int
    let championID: Int
    let position: Int
    let points: Int
    let target: Int
    let objectiveMet: Bool
    let prizeMoney: Int
    let topScorerName: String
    let topScorerTeamID: Int?
    let topScorerGoals: Int
    let retiredPlayers: Int
    let youthPromoted: Int
    let wasFired: Bool
    var division: Division = .serieA
    var cupResult: String = "—"
    var cupWinnerID: Int? = nil
    var promoted = false
    var relegated = false
    var awards: SeasonAwards? = nil
    var reputationChange = 0

    var id: Int { season }

    private enum CodingKeys: String, CodingKey {
        case season, clubID, championID, position, points, target, objectiveMet, prizeMoney, topScorerName, topScorerTeamID
        case topScorerGoals, retiredPlayers, youthPromoted, wasFired, division, cupResult, cupWinnerID, promoted, relegated
        case awards, reputationChange
    }

    init(season: Int, clubID: Int, championID: Int, position: Int, points: Int, target: Int, objectiveMet: Bool,
         prizeMoney: Int, topScorerName: String, topScorerTeamID: Int?, topScorerGoals: Int, retiredPlayers: Int,
         youthPromoted: Int, wasFired: Bool) {
        self.season = season
        self.clubID = clubID
        self.championID = championID
        self.position = position
        self.points = points
        self.target = target
        self.objectiveMet = objectiveMet
        self.prizeMoney = prizeMoney
        self.topScorerName = topScorerName
        self.topScorerTeamID = topScorerTeamID
        self.topScorerGoals = topScorerGoals
        self.retiredPlayers = retiredPlayers
        self.youthPromoted = youthPromoted
        self.wasFired = wasFired
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        season = try container.decode(Int.self, forKey: .season)
        clubID = try container.decode(Int.self, forKey: .clubID)
        championID = try container.decode(Int.self, forKey: .championID)
        position = try container.decodeIfPresent(Int.self, forKey: .position) ?? 0
        points = try container.decodeIfPresent(Int.self, forKey: .points) ?? 0
        target = try container.decodeIfPresent(Int.self, forKey: .target) ?? 4
        objectiveMet = try container.decodeIfPresent(Bool.self, forKey: .objectiveMet) ?? false
        prizeMoney = try container.decodeIfPresent(Int.self, forKey: .prizeMoney) ?? 0
        topScorerName = try container.decodeIfPresent(String.self, forKey: .topScorerName) ?? "—"
        topScorerTeamID = try container.decodeIfPresent(Int.self, forKey: .topScorerTeamID)
        topScorerGoals = try container.decodeIfPresent(Int.self, forKey: .topScorerGoals) ?? 0
        retiredPlayers = try container.decodeIfPresent(Int.self, forKey: .retiredPlayers) ?? 0
        youthPromoted = try container.decodeIfPresent(Int.self, forKey: .youthPromoted) ?? 0
        wasFired = try container.decodeIfPresent(Bool.self, forKey: .wasFired) ?? false
        division = try container.decodeIfPresent(Division.self, forKey: .division) ?? .serieA
        cupResult = try container.decodeIfPresent(String.self, forKey: .cupResult) ?? "—"
        cupWinnerID = try container.decodeIfPresent(Int.self, forKey: .cupWinnerID)
        promoted = try container.decodeIfPresent(Bool.self, forKey: .promoted) ?? false
        relegated = try container.decodeIfPresent(Bool.self, forKey: .relegated) ?? false
        awards = try container.decodeIfPresent(SeasonAwards.self, forKey: .awards)
        reputationChange = try container.decodeIfPresent(Int.self, forKey: .reputationChange) ?? 0
    }
}

struct FootballRandom: RandomNumberGenerator {
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

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }

    mutating func pick<T>(_ items: [T]) -> T? {
        guard !items.isEmpty else { return nil }
        return items[int(in: 0...(items.count - 1))]
    }

    /// Sorteio ponderado; retorna nil quando todos os pesos são zero.
    mutating func weightedIndex(_ weights: [Int]) -> Int? {
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }
        var draw = int(in: 1...total)
        for (index, weight) in weights.enumerated() {
            draw -= weight
            if draw <= 0 { return index }
        }
        return weights.indices.last
    }

    mutating func poisson(lambda: Double) -> Int {
        let draw = unit()
        var probability = exp(-lambda)
        var cumulative = probability
        if draw < cumulative { return 0 }
        for goals in 1...7 {
            probability *= lambda / Double(goals)
            cumulative += probability
            if draw < cumulative { return goals }
        }
        return 7
    }
}
