import Foundation

// MARK: - Faixa de resumo ao voltar ao Gestor (PIL-05)

/// O que mudou para o clube numa rodada, em frases curtas para a faixa que aparece ao voltar ao Gestor.
struct FootballRoundProgress: Equatable {
    /// Posição na tabela antes e depois da rodada (1 é a liderança).
    var positionBefore: Int
    var positionAfter: Int
    /// Variação do caixa na rodada, em reais.
    var cashChange: Int
    /// Progresso da meta da diretoria, de 0 a 1; nil quando o clube não tem meta.
    var objectiveProgress: Double?

    /// Frases na ordem: posição, caixa e meta. Vazio quando a rodada não mexeu em nada.
    var lines: [String] {
        var phrases: [String] = []
        let moved = positionBefore - positionAfter
        if moved == 1 { phrases.append("subiu uma posição") }
        if moved > 1 { phrases.append("subiu \(moved) posições") }
        if moved == -1 { phrases.append("caiu uma posição") }
        if moved < -1 { phrases.append("caiu \(-moved) posições") }
        if cashChange != 0 {
            phrases.append("caixa \(cashChange > 0 ? "+" : "")\(FootballFormat.money(cashChange))")
        }
        if let objectiveProgress {
            let percent = Int((min(max(objectiveProgress, 0), 1) * 100).rounded())
            phrases.append("meta da diretoria em \(percent)%")
        }
        return phrases
    }
}
