import Foundation

// MARK: - Prévia do efeito de cada tom na coletiva

/// Uma consequência do tom escolhido, para mostrar antes de responder. `delta` nil é um efeito sem número (o rival).
struct PressEffectPreview: Equatable, Identifiable {
    let label: String
    let delta: Int?
    let note: String?

    var id: String { label }
}

extension PressTone {
    /// O que o tom faz sozinho, sem contar o tema da pergunta (que pode somar ou tirar um pouco).
    /// Espelha `answerPress`; um teste confere os números contra o motor.
    func baseEffects(result: FootballResult, isDerby: Bool) -> [PressEffectPreview] {
        switch self {
        case .calm:
            var list = [PressEffectPreview(label: "Diretoria", delta: result == .loss ? 2 : 1, note: nil)]
            if result != .loss { list.append(PressEffectPreview(label: "Torcida", delta: 1, note: nil)) }
            return list
        case .confident:
            if result == .loss {
                return [PressEffectPreview(label: "Moral do elenco", delta: -2, note: nil),
                        PressEffectPreview(label: "Torcida", delta: -3, note: nil),
                        PressEffectPreview(label: "Diretoria", delta: -1, note: nil)]
            }
            return [PressEffectPreview(label: "Moral do elenco", delta: 2, note: nil),
                    PressEffectPreview(label: "Torcida", delta: 2, note: nil)]
        case .provocative:
            let rival = PressEffectPreview(label: "Rival", delta: nil, note: isDerby ? "muito motivado" : "motivado")
            if result == .win { return [PressEffectPreview(label: "Torcida", delta: 3, note: nil), rival] }
            return [PressEffectPreview(label: "Torcida", delta: -4, note: nil),
                    PressEffectPreview(label: "Diretoria", delta: -2, note: nil), rival]
        }
    }
}
