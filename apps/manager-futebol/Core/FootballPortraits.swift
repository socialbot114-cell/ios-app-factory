import Foundation

// MARK: - Retratos de atletas e do treinador

/// Qual retrato (tom de pele e penteado) cada pessoa usa. A escolha só depende do id, da idade e da região:
/// o mesmo atleta tem sempre o mesmo rosto, em qualquer tela e em qualquer save.
struct PortraitSpec: Equatable {
    let skin: String
    let hair: String

    var assetName: String { "Portrait_\(skin)_\(hair)" }
    /// Máscara da camisa: o app a pinta com a cor do clube.
    var maskName: String { assetName + "_camisa" }
}

enum FootballPortraits {
    static let skins = ["clara", "morena", "parda", "negra", "bronze"]
    static let hairs = ["careca", "curto", "afro", "moicano", "longo", "coque", "grisalho"]

    /// Pesos de tom de pele por região (0 Norte, 1 Nordeste, 2 Centro-Oeste, 3 Sudeste, 4 Sul), na ordem de `skins`.
    private static let skinWeights: [[Int]] = [
        [10, 30, 30, 15, 15],   // Norte
        [10, 28, 28, 22, 12],   // Nordeste
        [18, 28, 22, 14, 18],   // Centro-Oeste
        [24, 24, 20, 14, 18],   // Sudeste
        [40, 22, 12, 6, 20]     // Sul
    ]
    /// Pesos de penteado, na ordem de `hairs`, sem o grisalho (que vale só a partir dos 33 anos).
    private static let hairWeights = [10, 38, 14, 8, 8, 6]

    static func spec(playerID: Int, age: Int, region: Int?) -> PortraitSpec {
        var random = SplitMix(seed: UInt64(truncatingIfNeeded: playerID) &* 0x9E37_79B9_7F4A_7C15 &+ 0x51ED)
        let weights = skinWeights[min(max(region ?? 3, 0), skinWeights.count - 1)]
        let skin = skins[pick(weights, random.next())]
        let hair: String
        if age >= 33, random.next() % 100 < 40 {
            hair = "grisalho"
        } else {
            hair = hairs[pick(hairWeights, random.next())]
        }
        return PortraitSpec(skin: skin, hair: hair)
    }

    /// O treinador usa o mesmo conjunto de rostos; o penteado é sempre curto, grisalho ou careca.
    static func coachSpec(seed: Int) -> PortraitSpec {
        var random = SplitMix(seed: UInt64(truncatingIfNeeded: seed) &* 0xBF58_476D_1CE4_E5B9 &+ 0x77)
        let skin = skins[Int(random.next() % UInt64(skins.count))]
        let hair = ["curto", "grisalho", "careca"][Int(random.next() % 3)]
        return PortraitSpec(skin: skin, hair: hair)
    }

    private static func pick(_ weights: [Int], _ value: UInt64) -> Int {
        let total = weights.reduce(0, +)
        var roll = Int(value % UInt64(total))
        for (index, weight) in weights.enumerated() {
            if roll < weight { return index }
            roll -= weight
        }
        return weights.count - 1
    }

    /// Sorteio simples e estável (SplitMix64), independente do gerador do jogo.
    private struct SplitMix {
        var state: UInt64

        init(seed: UInt64) { state = seed }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}
