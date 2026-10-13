import SwiftUI

/// Converte o nome da cor do aviso (definido no Core) na cor da tela.
extension AmbientTint {
    var color: Color {
        switch self {
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        case .indigo: return .indigo
        case .forest: return Color(red: 0.20, green: 0.62, blue: 0.30)
        case .teal: return Color(red: 0.10, green: 0.50, blue: 0.40)
        case .blue: return .blue
        case .yellow: return .yellow
        case .gray: return .gray
        }
    }
}
