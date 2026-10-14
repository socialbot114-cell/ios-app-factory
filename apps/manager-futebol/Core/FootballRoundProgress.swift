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

/// Foto do clube antes ou depois de uma rodada. Quem chama tira a foto antes de jogar e compara depois (PIL-05 v2).
struct FootballRoundSnapshot: Equatable {
    /// Posição na tabela da divisão do usuário (1 é a liderança).
    var position: Int
    /// Caixa do clube, em reais.
    var cash: Int
    /// Progresso da meta da diretoria, de 0 a 1; nil enquanto o app não mede a meta.
    var objectiveProgress: Double?
}

extension FootballRoundProgress {
    /// Monta a faixa a partir da foto de antes e da de depois da rodada.
    init(before: FootballRoundSnapshot, after: FootballRoundSnapshot) {
        self.init(positionBefore: before.position, positionAfter: after.position,
                  cashChange: after.cash - before.cash, objectiveProgress: after.objectiveProgress)
    }
}

extension FootballCareer {
    /// Foto do clube para a faixa; nil quando o clube não está na tabela da divisão.
    func captureRoundSnapshot() -> FootballRoundSnapshot? {
        guard let position = userPosition else { return nil }
        return FootballRoundSnapshot(position: position, cash: transferBudget, objectiveProgress: nil)
    }
}
