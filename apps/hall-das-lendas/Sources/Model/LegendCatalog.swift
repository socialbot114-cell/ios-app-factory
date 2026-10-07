import SwiftUI

// MARK: - Raridade

enum LegendRarity: Int, CaseIterable, Comparable {
    case gold = 0, legendary, eternal

    static func < (lhs: LegendRarity, rhs: LegendRarity) -> Bool { lhs.rawValue < rhs.rawValue }

    /// A raridade vem do geral impresso na carta: quanto maior, mais rara.
    init(overall: Int) {
        switch overall {
        case 94...: self = .eternal
        case 92...: self = .legendary
        default: self = .gold
        }
    }

    var title: String {
        switch self {
        case .gold: return "Ouro raro"
        case .legendary: return "Lendária"
        case .eternal: return "Eterna"
        }
    }

    var stars: Int { rawValue + 3 }

    var tint: Color {
        switch self {
        case .gold: return Color(red: 0.90, green: 0.69, blue: 0.22)
        case .legendary: return Color(red: 0.96, green: 0.58, blue: 0.20)
        case .eternal: return Color(red: 0.42, green: 0.95, blue: 0.72)
        }
    }

    var glow: [Color] {
        switch self {
        case .gold: return [Color(red: 1.00, green: 0.86, blue: 0.45), Color(red: 0.70, green: 0.48, blue: 0.10)]
        case .legendary: return [Color(red: 1.00, green: 0.74, blue: 0.36), Color(red: 0.80, green: 0.32, blue: 0.10)]
        case .eternal: return [Color(red: 0.66, green: 1.00, blue: 0.84), Color(red: 0.12, green: 0.62, blue: 0.42)]
        }
    }
}

// MARK: - Carta

struct LegendStat: Hashable {
    let label: String
    let value: Int
}

struct LegendCard: Identifiable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let country: String
    let flag: String
    let positionCode: String
    let positionTitle: String
    let overall: Int
    let assetName: String
    let blurb: String
    let stats: [LegendStat]

    var rarity: LegendRarity { LegendRarity(overall: overall) }

    var accessibilityText: String {
        "\(name), \(positionTitle), \(country), geral \(overall), carta \(rarity.title.lowercased())"
    }
}

enum LegendCatalog {
    static let all: [LegendCard] = [
        LegendCard(
            id: "yashin", name: "Lev Yashin", shortName: "Yashin", country: "Rússia", flag: "🇷🇺",
            positionCode: "GOL", positionTitle: "Goleiro", overall: 94, assetName: "LegendYashin",
            blurb: "A Aranha Negra do Dínamo de Moscou. É o único goleiro que ganhou a Bola de Ouro, em 1963, e foi campeão olímpico em 1956 e da Eurocopa de 1960.",
            stats: [LegendStat(label: "DEF", value: 95), LegendStat(label: "REF", value: 92), LegendStat(label: "POS", value: 90),
                    LegendStat(label: "SAÍ", value: 91), LegendStat(label: "COM", value: 88), LegendStat(label: "LID", value: 93)]),
        LegendCard(
            id: "garrincha", name: "Mané Garrincha", shortName: "Garrincha", country: "Brasil", flag: "🇧🇷",
            positionCode: "PD", positionTitle: "Ponta-direita", overall: 95, assetName: "LegendGarrincha",
            blurb: "A Alegria do Povo. Driblador do Botafogo, foi bicampeão mundial em 1958 e 1962 e o craque da Copa do Chile.",
            stats: [LegendStat(label: "VEL", value: 96), LegendStat(label: "DRI", value: 92), LegendStat(label: "FIN", value: 90),
                    LegendStat(label: "PAS", value: 88), LegendStat(label: "DEF", value: 54), LegendStat(label: "FÍS", value: 82)]),
        LegendCard(
            id: "zagallo", name: "Mário Jorge Lobo Zagallo", shortName: "Zagallo", country: "Brasil", flag: "🇧🇷",
            positionCode: "MEI", positionTitle: "Meia", overall: 91, assetName: "LegendZagallo",
            blurb: "Bicampeão mundial como jogador em 1958 e 1962, campeão em 1970 como técnico e em 1994 como coordenador técnico.",
            stats: [LegendStat(label: "VEL", value: 88), LegendStat(label: "FIN", value: 87), LegendStat(label: "PAS", value: 92),
                    LegendStat(label: "DRI", value: 90), LegendStat(label: "DEF", value: 86), LegendStat(label: "FÍS", value: 89)]),
        LegendCard(
            id: "beckenbauer", name: "Franz Beckenbauer", shortName: "Beckenbauer", country: "Alemanha", flag: "🇩🇪",
            positionCode: "ZAG", positionTitle: "Zagueiro", overall: 93, assetName: "LegendBeckenbauer",
            blurb: "O Kaiser. Inventou o líbero moderno no Bayern, foi campeão mundial como capitão em 1974 e como técnico em 1990, e ganhou duas Bolas de Ouro.",
            stats: [LegendStat(label: "DEF", value: 92), LegendStat(label: "FÍS", value: 88), LegendStat(label: "PAS", value: 91),
                    LegendStat(label: "CON", value: 90), LegendStat(label: "VEL", value: 87), LegendStat(label: "LID", value: 92)]),
        LegendCard(
            id: "charlton", name: "Sir Bobby Charlton", shortName: "Charlton", country: "Inglaterra", flag: "\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}",
            positionCode: "MC", positionTitle: "Meio-campista", overall: 92, assetName: "LegendCharlton",
            blurb: "Campeão mundial em 1966 e Bola de Ouro no mesmo ano. Ídolo do Manchester United, sobreviveu ao desastre aéreo de Munique e reconstruiu o time.",
            stats: [LegendStat(label: "FIN", value: 88), LegendStat(label: "PAS", value: 91), LegendStat(label: "CON", value: 87),
                    LegendStat(label: "DEF", value: 85), LegendStat(label: "FÍS", value: 86), LegendStat(label: "LID", value: 90)]),
        LegendCard(
            id: "eusebio", name: "Eusébio", shortName: "Eusébio", country: "Portugal", flag: "🇵🇹",
            positionCode: "ATA", positionTitle: "Atacante", overall: 94, assetName: "LegendEusebio",
            blurb: "A Pantera Negra do Benfica. Bola de Ouro em 1965 e artilheiro da Copa de 1966, com nove gols.",
            stats: [LegendStat(label: "FIN", value: 95), LegendStat(label: "VEL", value: 92), LegendStat(label: "DRI", value: 88),
                    LegendStat(label: "PAS", value: 87), LegendStat(label: "DEF", value: 53), LegendStat(label: "FÍS", value: 89)]),
    ]

    static func card(id: String) -> LegendCard? {
        all.first { $0.id == id }
    }
}
