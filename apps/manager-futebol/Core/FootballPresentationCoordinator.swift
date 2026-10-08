import Foundation

// MARK: - Fila única de apresentação (FLX-01)

/// Apresentações que disputam a tela do Gestor. Entram na ordem da declaração: coletiva, resumo, mensagem, alerta e guia.
enum FootballPresentation: Int, CaseIterable, Comparable {
    case press, summary, message, alert, guide

    static func < (lhs: FootballPresentation, rhs: FootballPresentation) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Decide o que está na tela agora. Uma apresentação por vez; as outras esperam na fila, em ordem, sem se perder.
struct FootballPresentationCoordinator: Equatable {
    /// A apresentação que está na tela, se houver.
    private(set) var current: FootballPresentation?
    /// As que esperam a vez, sempre em ordem.
    private(set) var waiting: [FootballPresentation] = []

    /// Pede uma apresentação. Se a tela está livre, ela entra na hora; senão, espera na fila.
    /// Um pedido que já está na tela ou na fila é ignorado, para não abrir a mesma coisa duas vezes.
    mutating func request(_ presentation: FootballPresentation) {
        guard presentation != current, !waiting.contains(presentation) else { return }
        guard current != nil else {
            current = presentation
            return
        }
        waiting.append(presentation)
        waiting.sort()
    }

    /// Fecha a apresentação atual e abre a próxima da fila, pela ordem.
    mutating func finishCurrent() {
        current = waiting.isEmpty ? nil : waiting.removeFirst()
    }
}
