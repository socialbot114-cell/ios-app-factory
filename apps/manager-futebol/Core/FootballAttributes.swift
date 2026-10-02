import Foundation

// MARK: - Atributos

enum AttributeGroup: String, CaseIterable, Codable {
    case technical = "Técnicos"
    case physical = "Físicos"
    case mental = "Mentais"
    case goalkeeping = "Goleiro"
    case hidden = "Ocultos"
}

/// Atributos de 1 a 20. O geral do atleta é derivado deles, com pesos próprios de cada posição.
enum AttributeKind: String, CaseIterable, Codable, Identifiable {
    case finishing, passing, dribbling, heading, marking, tackling
    case pace, stamina, strength
    case vision, decisions, positioning, leadership, determination, consistency
    case reflexes, handling, distribution
    case injuryProneness, professionalism, bigMatches

    var id: String { rawValue }

    var title: String {
        switch self {
        case .finishing: return "Finalização"
        case .passing: return "Passe"
        case .dribbling: return "Drible"
        case .heading: return "Cabeceio"
        case .marking: return "Marcação"
        case .tackling: return "Desarme"
        case .pace: return "Velocidade"
        case .stamina: return "Resistência"
        case .strength: return "Força"
        case .vision: return "Visão"
        case .decisions: return "Decisão"
        case .positioning: return "Posicionamento"
        case .leadership: return "Liderança"
        case .determination: return "Determinação"
        case .consistency: return "Consistência"
        case .reflexes: return "Reflexos"
        case .handling: return "Segurança no gol"
        case .distribution: return "Jogo com os pés"
        case .injuryProneness: return "Propensão a lesão"
        case .professionalism: return "Profissionalismo"
        case .bigMatches: return "Jogos grandes"
        }
    }

    var group: AttributeGroup {
        switch self {
        case .finishing, .passing, .dribbling, .heading, .marking, .tackling: return .technical
        case .pace, .stamina, .strength: return .physical
        case .vision, .decisions, .positioning, .leadership, .determination, .consistency: return .mental
        case .reflexes, .handling, .distribution: return .goalkeeping
        case .injuryProneness, .professionalism, .bigMatches: return .hidden
        }
    }

    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

struct PlayerAttributes: Codable, Equatable {
    private(set) var storage: [Int]

    init(storage: [Int]? = nil) {
        var values = storage ?? []
        while values.count < AttributeKind.allCases.count { values.append(10) }
        self.storage = Array(values.prefix(AttributeKind.allCases.count)).map { min(20, max(1, $0)) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(storage: try container.decode([Int].self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage)
    }

    subscript(kind: AttributeKind) -> Int {
        get { storage[kind.index] }
        set { storage[kind.index] = min(20, max(1, newValue)) }
    }

    // MARK: Pesos por posição

    static func weights(for position: FootballPosition) -> [(AttributeKind, Double)] {
        switch position {
        case .goalkeeper:
            return [(.reflexes, 0.34), (.handling, 0.22), (.positioning, 0.16), (.distribution, 0.08),
                    (.decisions, 0.08), (.determination, 0.04), (.strength, 0.04), (.consistency, 0.04)]
        case .defender:
            return [(.marking, 0.22), (.tackling, 0.22), (.heading, 0.12), (.positioning, 0.12), (.strength, 0.10),
                    (.pace, 0.07), (.decisions, 0.06), (.passing, 0.05), (.determination, 0.04)]
        case .midfielder:
            return [(.passing, 0.22), (.vision, 0.16), (.decisions, 0.12), (.dribbling, 0.10), (.stamina, 0.10),
                    (.tackling, 0.06), (.finishing, 0.06), (.positioning, 0.06), (.pace, 0.06), (.determination, 0.06)]
        case .forward:
            return [(.finishing, 0.28), (.dribbling, 0.14), (.pace, 0.14), (.positioning, 0.12), (.heading, 0.08),
                    (.passing, 0.06), (.vision, 0.06), (.strength, 0.05), (.decisions, 0.04), (.determination, 0.03)]
        }
    }

    /// Geral do atleta jogando na posição informada (escala 30–99).
    func overall(for position: FootballPosition) -> Int {
        let sum = Self.weights(for: position).reduce(0.0) { $0 + Double(self[$1.0]) * $1.1 }
        return min(99, max(30, Int((sum * 5).rounded())))
    }

    // MARK: Compostos usados pelo motor de partida (escala do geral)

    var attackComposite: Double {
        (Double(self[.finishing]) * 0.30 + Double(self[.dribbling]) * 0.20 + Double(self[.pace]) * 0.15
            + Double(self[.passing]) * 0.15 + Double(self[.vision]) * 0.10 + Double(self[.heading]) * 0.10) * 5
    }

    var defenseComposite: Double {
        (Double(self[.marking]) * 0.30 + Double(self[.tackling]) * 0.30 + Double(self[.positioning]) * 0.20
            + Double(self[.strength]) * 0.10 + Double(self[.heading]) * 0.10) * 5
    }

    var controlComposite: Double {
        (Double(self[.passing]) * 0.30 + Double(self[.vision]) * 0.25 + Double(self[.decisions]) * 0.20
            + Double(self[.dribbling]) * 0.10 + Double(self[.stamina]) * 0.15) * 5
    }

    var goalkeeperComposite: Double {
        (Double(self[.reflexes]) * 0.45 + Double(self[.handling]) * 0.30 + Double(self[.positioning]) * 0.25) * 5
    }

    // MARK: Geração

    /// Atributos coerentes com o geral desejado: ajusta até o geral calculado bater exatamente.
    static func derive(overall target: Int, position: FootballPosition, detail: PositionDetail, random: inout FootballRandom) -> PlayerAttributes {
        var attributes = PlayerAttributes()
        let weights = weights(for: position)
        let weightByKind = Dictionary(uniqueKeysWithValues: weights.map { ($0.0, $0.1) })
        let maxWeight = weights.map(\.1).max() ?? 0.2
        let base = Double(target) / 5
        let bias = detail.attributeBias

        for kind in AttributeKind.allCases {
            switch kind.group {
            case .hidden:
                attributes[kind] = random.int(in: 4...16)
            default:
                if let weight = weightByKind[kind] {
                    let relevance = (weight / maxWeight - 0.5) * 3
                    attributes[kind] = Int((base + relevance + (bias[kind] ?? 0) + Double(random.int(in: -15...15)) / 10).rounded())
                } else {
                    let floor = kind.group == .goalkeeping && position != .goalkeeper ? 3.0 : base - 3
                    attributes[kind] = Int((floor + (bias[kind] ?? 0) + Double(random.int(in: -20...20)) / 10).rounded())
                }
            }
        }
        if position == .goalkeeper {
            for kind in [AttributeKind.finishing, .dribbling, .heading, .tackling, .marking, .pace] {
                attributes[kind] = min(attributes[kind], 8)
            }
        }
        attributes.calibrate(to: target, position: position)
        return attributes
    }

    /// Soma ou subtrai pontos dos atributos de maior peso até o geral coincidir com o alvo.
    mutating func calibrate(to target: Int, position: FootballPosition) {
        let weights = Self.weights(for: position)
        for _ in 0..<120 {
            let exact = weights.reduce(0.0) { $0 + Double(self[$1.0]) * $1.1 } * 5
            let diff = Double(target) - exact
            if overall(for: position) == target || abs(diff) < 0.25 { return }
            let direction = diff > 0 ? 1 : -1
            let candidates = weights.filter { entry in
                let value = self[entry.0]
                return direction > 0 ? value < 20 : value > 1
            }
            guard let choice = candidates.min(by: {
                abs($0.1 * 5 - abs(diff)) < abs($1.1 * 5 - abs(diff))
            }) else { return }
            self[choice.0] += direction
        }
    }
}

// MARK: - Posição detalhada

enum PositionDetail: String, Codable, CaseIterable {
    case goalkeeper = "GOL"
    case rightBack = "LD"
    case leftBack = "LE"
    case centreBack = "ZAG"
    case defensiveMid = "VOL"
    case centralMid = "MC"
    case attackingMid = "MEI"
    case winger = "PON"
    case striker = "CA"

    var group: FootballPosition {
        switch self {
        case .goalkeeper: return .goalkeeper
        case .rightBack, .leftBack, .centreBack: return .defender
        case .defensiveMid, .centralMid, .attackingMid: return .midfielder
        case .winger, .striker: return .forward
        }
    }

    var title: String {
        switch self {
        case .goalkeeper: return "Goleiro"
        case .rightBack: return "Lateral-direito"
        case .leftBack: return "Lateral-esquerdo"
        case .centreBack: return "Zagueiro"
        case .defensiveMid: return "Volante"
        case .centralMid: return "Meio-campista"
        case .attackingMid: return "Meia-armador"
        case .winger: return "Ponta"
        case .striker: return "Centroavante"
        }
    }

    static func defaults(for position: FootballPosition) -> [PositionDetail] {
        allCases.filter { $0.group == position }
    }

    var attributeBias: [AttributeKind: Double] {
        switch self {
        case .goalkeeper: return [:]
        case .rightBack, .leftBack: return [.pace: 2, .stamina: 1.5, .dribbling: 1, .heading: -1]
        case .centreBack: return [.heading: 2, .strength: 1.5, .marking: 1, .pace: -1.5]
        case .defensiveMid: return [.tackling: 2, .stamina: 1, .positioning: 1, .dribbling: -1.5, .finishing: -2]
        case .centralMid: return [.passing: 1, .stamina: 1]
        case .attackingMid: return [.vision: 2, .dribbling: 1.5, .passing: 1, .tackling: -2, .marking: -2]
        case .winger: return [.pace: 2.5, .dribbling: 2, .heading: -2, .strength: -1.5]
        case .striker: return [.finishing: 1, .heading: 1.5, .strength: 1.5, .pace: -1]
        }
    }
}

// MARK: - Características

enum PlayerTrait: String, Codable, CaseIterable, Identifiable {
    case naturalFinisher, setPieceSpecialist, leader, workhorse, fragile, bigMatchPlayer, choker, prodigy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .naturalFinisher: return "Artilheiro nato"
        case .setPieceSpecialist: return "Bola parada"
        case .leader: return "Líder"
        case .workhorse: return "Raçudo"
        case .fragile: return "Frágil"
        case .bigMatchPlayer: return "Decisivo"
        case .choker: return "Treme nos jogos grandes"
        case .prodigy: return "Promessa precoce"
        }
    }

    var summary: String {
        switch self {
        case .naturalFinisher: return "Mais chances de ser o autor do gol."
        case .setPieceSpecialist: return "Cobra pênaltis e faltas com mais precisão."
        case .leader: return "Eleva o moral do elenco."
        case .workhorse: return "Cansa menos durante a partida."
        case .fragile: return "Lesiona-se com mais frequência."
        case .bigMatchPlayer: return "Rende mais em clássicos, finais e mata-matas."
        case .choker: return "Rende menos em clássicos, finais e mata-matas."
        case .prodigy: return "Evolui mais rápido nos primeiros anos."
        }
    }

    var isPositive: Bool { self != .fragile && self != .choker }
}

// MARK: - Status, moral, contrato

enum SquadStatus: Int, Codable, CaseIterable, Comparable {
    case prospect = 0, backup, rotation, starter, key

    var title: String {
        switch self {
        case .key: return "Titular-chave"
        case .starter: return "Titular"
        case .rotation: return "Rotação"
        case .backup: return "Reserva"
        case .prospect: return "Promessa"
        }
    }

    /// Fração das partidas em que o atleta espera jogar.
    var expectedShare: Double {
        switch self {
        case .key: return 0.9
        case .starter: return 0.75
        case .rotation: return 0.4
        case .backup: return 0.15
        case .prospect: return 0.1
        }
    }

    /// Multiplicador no salário pedido: quem espera mais pede mais.
    var wageFactor: Double {
        switch self {
        case .key: return 1.25
        case .starter: return 1.1
        case .rotation: return 1.0
        case .backup: return 0.9
        case .prospect: return 0.8
        }
    }

    static func < (lhs: SquadStatus, rhs: SquadStatus) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum MoraleLevel: Int, CaseIterable {
    case furious = 0, unhappy, normal, good, excellent

    init(value: Int) {
        switch value {
        case ..<30: self = .furious
        case 30..<45: self = .unhappy
        case 45..<65: self = .normal
        case 65..<80: self = .good
        default: self = .excellent
        }
    }

    var title: String {
        switch self {
        case .furious: return "Insatisfeito"
        case .unhappy: return "Descontente"
        case .normal: return "Normal"
        case .good: return "Bom"
        case .excellent: return "Excelente"
        }
    }
}

struct PlayerContract: Codable, Equatable {
    /// Salário por temporada.
    var wage: Int
    /// Última temporada coberta pelo contrato. Zero significa "ainda não definido" (save antigo).
    var endSeason: Int
    var status: SquadStatus

    static func wage(forValue value: Int) -> Int {
        max(40_000, Int((Double(value) * 0.11) / 5_000) * 5_000)
    }
}

struct PlayerForm: Codable, Equatable {
    var recent: [Double] = []
    var seasonSum = 0.0
    var seasonGames = 0

    mutating func add(_ rating: Double) {
        recent.append(rating)
        if recent.count > 5 { recent.removeFirst(recent.count - 5) }
        seasonSum += rating
        seasonGames += 1
    }

    var recentAverage: Double? {
        recent.isEmpty ? nil : recent.reduce(0, +) / Double(recent.count)
    }

    var seasonAverage: Double? {
        seasonGames == 0 ? nil : seasonSum / Double(seasonGames)
    }
}

struct PlayerDiscipline: Codable, Equatable {
    var yellowCards = 0
    var redCards = 0
    var suspensionGames = 0
}
