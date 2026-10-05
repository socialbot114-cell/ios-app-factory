import Foundation

// MARK: - Balanceamento de ações sem custo (F4-06)

extension CoachActivity {
    /// Estresse de cada atividade: trabalho cansa a cabeça, descanso e comunidade aliviam.
    var stressCost: Int {
        switch self {
        case .rest: return 0 // o descanso já reduz 25
        case .study: return 2
        case .tvPunditry: return 4
        case .lecture: return 3
        case .writeBook: return 2
        case .schoolVisit: return -2
        case .podcast: return 2
        case .sponsorShoot: return 4
        }
    }
}

extension ShopPrice {
    /// Efeito do preço no humor da torcida, aplicado a cada dia de jogo.
    var moodNote: String {
        switch self {
        case .low: return "Promoção vende menos por peça, mas agrada a torcida."
        case .normal: return "Preço neutro para a torcida."
        case .high: return "Premium rende mais por peça, mas irrita a torcida quando o humor está alto."
        }
    }
}

extension FootballCareer {
    /// Aporte mínimo, em relação à dívida, para a diretoria reconhecer o gesto.
    static let loanBonusDebtShare = 0.05

    /// Um aporte só acalma a diretoria uma vez por dia de jogo e se cobrir parte relevante da dívida.
    func loanEarnsBoardBonus(amount: Int) -> Bool {
        guard isInDebt, world.projects.lastLoanBonusWorldDay != worldDay else { return false }
        return Double(amount) >= Double(-transferBudget) * Self.loanBonusDebtShare
    }

    /// Humor da torcida pelo preço da loja. Fluxo próprio de sorteio para não alterar os demais sistemas do dia.
    mutating func applyShopPriceMood() {
        var random = FootballRandom(seed: matchSeed(stream: .world, id: 70_000 + worldDay))
        switch world.business.shopPrice {
        case .low:
            if random.chance(0.2) { fanMood = min(100, fanMood + 1) }
        case .normal:
            break
        case .high:
            if fanMood > 40, random.chance(0.15) { fanMood = max(0, fanMood - 1) }
        }
    }
}
