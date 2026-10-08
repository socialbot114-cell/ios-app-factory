import Foundation

// MARK: - Loja Aplicativo: módulos Pro (item 45 do roadmap)

/// Módulos pagos vendidos na Loja. Cada um é comprado uma vez (compra única).
/// Os preços são propostas, a confirmar antes da venda. Esta camada não fala com a App Store: só descreve o produto.
enum FootballProModule: String, CaseIterable, Identifiable {
    case scout, analytics, market, academy, medical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scout: return "Scout Pro"
        case .analytics: return "Analytics Pro"
        case .market: return "Market Pro"
        case .academy: return "Academy Pro"
        case .medical: return "Medical Pro"
        }
    }

    /// Preço proposto em centavos (R$ 4,90 = 490). A faixa combinada vai de 490 a 1490.
    var priceCents: Int {
        switch self {
        case .scout: return 490
        case .medical: return 690
        case .analytics, .academy: return 990
        case .market: return 1490
        }
    }

    /// Identificador do produto no App Store Connect, para a fatia de compra com StoreKit.
    var productID: String { "futos.pro.\(rawValue)" }

    /// Frase de mistério mostrada antes da compra. Muda só a apresentação: o que o módulo entrega está em `highlights`.
    var teaser: String {
        switch self {
        case .scout: return "Olhos que enxergam além da tabela."
        case .analytics: return "Por que o time ganha, em números."
        case .market: return "Sinais do mercado antes de todo mundo."
        case .academy: return "A base que ninguém mais enxerga."
        case .medical: return "O corpo avisa antes do técnico."
        }
    }

    /// O que o módulo vai entregar, em linguagem simples. Fica visível antes da compra: o conteúdo nunca é escondido.
    var highlights: [String] {
        switch self {
        case .scout:
            return ["Ratings exatos de atletas de outros clubes, sem esperar o olheiro", "Comparação lado a lado de dois atletas"]
        case .analytics:
            return ["Desempenho por temporada em gráficos", "Motivos de cada vitória e derrota na rodada"]
        case .market:
            return ["Em alta, Subvalorizados, Em queda, Fim de contrato, Jovens promessas e Oportunidades",
                    "Em alta e Em queda entram quando houver histórico de temporadas"]
        case .academy:
            return ["Relatório completo de traços e potencial de cada jovem", "Calendário de peneiras e parcerias por região"]
        case .medical:
            return ["Risco de lesão por atleta, pela carga de jogos", "Plano de recuperação com prazo estimado"]
        }
    }

    /// Símbolo do SF Symbols do módulo.
    var symbol: String {
        switch self {
        case .scout: return "binoculars.fill"
        case .analytics: return "chart.xyaxis.line"
        case .market: return "chart.line.uptrend.xyaxis"
        case .academy: return "graduationcap.fill"
        case .medical: return "cross.case.fill"
        }
    }
}
