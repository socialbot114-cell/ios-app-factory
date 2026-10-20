import Foundation

/// Desenho da camisa de cada clube. Dez padrões e quatro variações (mangas e calção) dão 40 combinações:
/// os 20 clubes da liga nunca repetem o mesmo desenho, mesmo quando duas cores se parecem.
enum KitPattern: Int, CaseIterable {
    case solid, verticalStripes, hoops, halves, sash, pinstripes, chevron, checks, centerBand, quarters
}

struct KitDesign: Equatable {
    var pattern: KitPattern
    /// Mangas na cor de detalhe.
    var contrastSleeves: Bool
    /// Calção na cor de detalhe (e meias na principal) em vez do contrário.
    var invertedShorts: Bool

    static let combinations = KitPattern.allCases.count * 4

    static func design(forTeam id: Int) -> KitDesign {
        // Passo 7 é primo com 40: ids seguidos caem em padrões bem diferentes e nenhuma combinação repete até 40 clubes.
        let slot = (abs(id) * 7) % combinations
        let variant = slot / KitPattern.allCases.count
        return KitDesign(pattern: KitPattern.allCases[slot % KitPattern.allCases.count],
                         contrastSleeves: variant & 1 == 1,
                         invertedShorts: variant & 2 == 2)
    }
}
