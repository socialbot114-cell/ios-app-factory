import Foundation

// MARK: - Porte da cidade do clube

/// Porte da cidade, para escolher a ilustração do horizonte no app Clube.
/// Por enquanto é só apresentação: não muda torcida, receita nem nenhuma regra do jogo.
enum CityScale: String, Codable, CaseIterable {
    case small, medium, large

    var title: String {
        switch self {
        case .small: return "Cidade pequena"
        case .medium: return "Cidade média"
        case .large: return "Cidade grande"
        }
    }

    var imageName: String {
        switch self {
        case .small: return "CityPequena"
        case .medium: return "CityMedia"
        case .large: return "CityGrande"
        }
    }
}

extension LeagueTeam {
    /// Porte por clube: capitais e grandes centros, cidades médias e cidades do interior.
    var cityScale: CityScale {
        switch id {
        case 0, 2, 3, 4, 6, 7, 15: return .large
        case 1, 5, 8, 10, 11, 12, 14, 16: return .medium
        default: return .small
        }
    }
}
