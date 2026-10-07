import Foundation

// MARK: - Lista do Mercado (busca, ordenação e paginação)

/// Ordenações das abas Livres e Clubes (MER-01).
/// Direções: Geral, Potencial e Valor do maior para o menor; Idade do mais novo para o mais velho;
/// Fim de contrato do que vence antes. Quem não tem data de contrato (zero) fica por último.
enum FootballMarketSort: String, CaseIterable, Identifiable {
    case overall = "Geral"
    case potential = "Potencial"
    case age = "Idade"
    case value = "Valor"
    case contractEnd = "Fim de contrato"

    var id: String { rawValue }
}

/// Uma página da lista do Mercado: os atletas mostrados e o total que passa na busca.
struct FootballMarketPage {
    /// Atletas da página, já filtrados e ordenados.
    let players: [FootballPlayer]
    /// Total de atletas que passam na busca, antes do corte da página.
    let total: Int

    /// Atletas que ainda não cabem na tela (o botão "Mostrar mais" usa este número).
    var remaining: Int { total - players.count }
}

/// Estado da lista do Mercado: busca por nome, ordenação e quantos atletas estão à vista.
/// Mudar a busca ou a ordenação volta para a primeira página. Fica fora da view para ser testado sem a interface.
struct FootballMarketList {
    /// Atletas por página.
    static let pageSize = 30

    /// Texto digitado na busca por nome.
    var query = "" {
        didSet { if query != oldValue { limit = FootballMarketList.pageSize } }
    }
    /// Ordenação escolhida.
    var sort: FootballMarketSort = .overall {
        didSet { if sort != oldValue { limit = FootballMarketList.pageSize } }
    }
    /// Quantos atletas a lista mostra agora (30, 60, 90...).
    var limit = FootballMarketList.pageSize

    /// Há texto útil na busca? Espaços sozinhos não contam.
    var isSearching: Bool { !Self.normalized(query).isEmpty }

    /// Soma mais uma página ao que está à vista.
    mutating func showMore() {
        limit += FootballMarketList.pageSize
    }

    /// Volta para a primeira página (usado quando outro filtro da aba muda).
    mutating func resetPage() {
        limit = FootballMarketList.pageSize
    }

    /// Aplica busca, ordenação e corte de página sobre a lista recebida.
    func page(of players: [FootballPlayer]) -> FootballMarketPage {
        let terms = Self.normalized(query).split(separator: " ")
        let matching = players.filter { Self.matches($0, terms: terms) }
        let ordered = Self.sorted(matching, by: sort)
        return FootballMarketPage(players: Array(ordered.prefix(max(0, limit))), total: ordered.count)
    }

    /// Minúsculas, sem acento e com espaços normalizados (mesma regra da busca do Spotlight).
    static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// Cada palavra da busca precisa aparecer no nome, sem diferenciar acento nem maiúscula.
    private static func matches(_ player: FootballPlayer, terms: [Substring]) -> Bool {
        guard !terms.isEmpty else { return true }
        let name = normalized(player.name)
        return terms.allSatisfy { name.contains($0) }
    }

    /// Ordena pelo critério escolhido. Empates: geral, nome e id, para a ordem não mudar entre telas.
    static func sorted(_ players: [FootballPlayer], by sort: FootballMarketSort) -> [FootballPlayer] {
        players.sorted { lhs, rhs in
            switch sort {
            case .overall:
                if lhs.overall != rhs.overall { return lhs.overall > rhs.overall }
            case .potential:
                if lhs.potential != rhs.potential { return lhs.potential > rhs.potential }
            case .age:
                if lhs.age != rhs.age { return lhs.age < rhs.age }
            case .value:
                if lhs.marketValue != rhs.marketValue { return lhs.marketValue > rhs.marketValue }
            case .contractEnd:
                let lhsEnd = contractKey(lhs)
                let rhsEnd = contractKey(rhs)
                if lhsEnd != rhsEnd { return lhsEnd < rhsEnd }
            }
            if lhs.overall != rhs.overall { return lhs.overall > rhs.overall }
            if lhs.name != rhs.name { return lhs.name < rhs.name }
            return lhs.id < rhs.id
        }
    }

    /// Fim de contrato para ordenar: zero (sem contrato ou save antigo) vai para o fim.
    private static func contractKey(_ player: FootballPlayer) -> Int {
        player.contract.endSeason == 0 ? Int.max : player.contract.endSeason
    }
}
