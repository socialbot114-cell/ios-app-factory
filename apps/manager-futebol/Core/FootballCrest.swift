import Foundation

// MARK: - Escudo de cada clube

/// Forma e desenho do escudo. As 20 combinações são todas diferentes, então nenhum clube tem o mesmo escudo de outro.
struct CrestStyle: Equatable {
    /// 0 escudo clássico, 1 redondo, 2 hexágono, 3 quadrado arredondado.
    let shape: Int
    /// 0 liso, 1 faixa vertical, 2 faixa diagonal, 3 chevron, 4 faixa horizontal.
    let pattern: Int

    static let shapeCount = 4
    static let patternCount = 5
}

extension LeagueTeam {
    var crestStyle: CrestStyle {
        CrestStyle(shape: id % CrestStyle.shapeCount, pattern: (id / CrestStyle.shapeCount) % CrestStyle.patternCount)
    }
}
