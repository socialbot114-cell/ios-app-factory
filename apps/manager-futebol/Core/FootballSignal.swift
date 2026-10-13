import Foundation

/// Regra das barras de sinal do celular: quantas acendem para o humor da torcida. Sem SwiftUI, para testar no Linux.
enum FootballSignal {
    /// Degraus em 15, 40, 65 e 90: quantas barras acendem para um humor.
    static func litBars(_ fanMood: Int?) -> Int {
        guard let fanMood else { return 0 }
        return (0..<4).filter { fanMood >= 25 * ($0 + 1) - 10 }.count
    }
}
