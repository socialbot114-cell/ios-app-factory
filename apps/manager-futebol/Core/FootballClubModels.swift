import Foundation

// MARK: - Finanças

enum FinanceCategory: String, Codable, CaseIterable, Identifiable {
    case gate, members, tv, sponsor, prize, playerSales, playerPurchases, loans
    case wages, staff, facilities, interest, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gate: return "Bilheteria"
        case .members: return "Sócio-torcedor"
        case .tv: return "TV"
        case .sponsor: return "Patrocínio"
        case .prize: return "Premiações"
        case .playerSales: return "Vendas de atletas"
        case .playerPurchases: return "Compras de atletas"
        case .loans: return "Empréstimos"
        case .wages: return "Salários"
        case .staff: return "Comissão técnica"
        case .facilities: return "Estrutura"
        case .interest: return "Juros"
        case .other: return "Outros"
        }
    }

    var symbol: String {
        switch self {
        case .gate: return "ticket.fill"
        case .members: return "person.crop.circle.badge.checkmark"
        case .tv: return "tv.fill"
        case .sponsor: return "megaphone.fill"
        case .prize: return "trophy.fill"
        case .playerSales: return "arrow.up.right.circle.fill"
        case .playerPurchases: return "arrow.down.left.circle.fill"
        case .loans: return "arrow.left.arrow.right.circle.fill"
        case .wages: return "banknote.fill"
        case .staff: return "person.2.fill"
        case .facilities: return "building.2.fill"
        case .interest: return "percent"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

struct FinanceEntry: Codable, Equatable {
    let season: Int
    let matchDay: Int
    let category: FinanceCategory
    let amount: Int
    let note: String
}

struct FinanceSeasonSummary: Codable, Equatable, Identifiable {
    let season: Int
    let income: Int
    let expenses: Int
    /// Total por categoria, indexado pelo nome da categoria.
    let byCategory: [String: Int]
    let closingCash: Int

    var id: Int { season }
    var result: Int { income - expenses }
}

struct FinanceBook: Codable, Equatable {
    static let entryLimit = 700

    var entries: [FinanceEntry] = []
    var summaries: [FinanceSeasonSummary] = []

    mutating func add(_ entry: FinanceEntry) {
        entries.append(entry)
        if entries.count > Self.entryLimit { entries.removeFirst(entries.count - Self.entryLimit) }
    }

    func entries(season: Int) -> [FinanceEntry] { entries.filter { $0.season == season } }

    func total(season: Int, category: FinanceCategory) -> Int {
        entries.filter { $0.season == season && $0.category == category }.reduce(0) { $0 + $1.amount }
    }

    func income(season: Int) -> Int { entries.filter { $0.season == season && $0.amount > 0 }.reduce(0) { $0 + $1.amount } }

    func expenses(season: Int) -> Int { -entries.filter { $0.season == season && $0.amount < 0 }.reduce(0) { $0 + $1.amount } }

    func summary(season: Int, closingCash: Int) -> FinanceSeasonSummary {
        var byCategory: [String: Int] = [:]
        for entry in entries where entry.season == season {
            byCategory[entry.category.rawValue, default: 0] += entry.amount
        }
        return FinanceSeasonSummary(season: season, income: income(season: season), expenses: expenses(season: season),
                                    byCategory: byCategory, closingCash: closingCash)
    }
}

// MARK: - Caixa de entrada

enum InboxKind: String, Codable {
    case playerPlayingTime, playerContract, playerWantsOut
    case offer, transfer, scouting, injury, board, finance, staff, news, press, general

    var symbol: String {
        switch self {
        case .playerPlayingTime: return "figure.soccer"
        case .playerContract: return "doc.text.fill"
        case .playerWantsOut: return "door.left.hand.open"
        case .offer: return "envelope.badge.fill"
        case .transfer: return "arrow.left.arrow.right"
        case .scouting: return "binoculars.fill"
        case .injury: return "cross.case.fill"
        case .board: return "building.columns.fill"
        case .finance: return "banknote.fill"
        case .staff: return "person.2.fill"
        case .news: return "newspaper.fill"
        case .press: return "mic.fill"
        case .general: return "info.circle.fill"
        }
    }

    /// Mensagens que pedem uma resposta do treinador.
    var needsResponse: Bool {
        switch self {
        case .playerPlayingTime, .playerContract, .playerWantsOut, .offer: return true
        default: return false
        }
    }
}

struct InboxMessage: Codable, Equatable, Identifiable {
    let id: Int
    let season: Int
    let matchDay: Int
    let kind: InboxKind
    var title: String
    var body: String
    var playerID: Int? = nil
    var offerID: Int? = nil
    var isRead = false
    var isResolved = false
}

/// Promessa feita a um atleta: começar um número de jogos antes de um prazo.
struct PlayerPromise: Codable, Equatable, Identifiable {
    let id: Int
    let playerID: Int
    let requiredStarts: Int
    var startsDone: Int
    let deadlineMatchDay: Int
    let season: Int
}

// MARK: - Negociação

enum NegotiationOutcome: Equatable {
    case accepted
    case counter(wage: Int)
    case refused(String)
    case overWageCap
    case notAllowed(String)
}

struct ContractAsk: Equatable {
    let wage: Int
    let years: Int
    let status: SquadStatus
}

// MARK: - Coletiva de imprensa

enum PressTone: String, Codable, CaseIterable, Identifiable {
    case calm, confident, provocative

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: return "Calmo"
        case .confident: return "Confiante"
        case .provocative: return "Provocador"
        }
    }

    var summary: String {
        switch self {
        case .calm: return "Sem riscos: acalma a torcida e a diretoria."
        case .confident: return "Eleva o moral se o time estiver bem, mas cobra caro se o resultado vier ruim."
        case .provocative: return "Anima a torcida, mas motiva o rival no próximo confronto."
        }
    }
}

struct PressQuestion: Codable, Equatable, Identifiable {
    let id: Int
    let prompt: String
    var answered: PressTone? = nil
}

struct PressConference: Codable, Equatable {
    let matchDay: Int
    let fixtureID: Int
    let opponentID: Int
    let result: FootballResult?
    let isDerby: Bool
    var questions: [PressQuestion]

    var isComplete: Bool { questions.allSatisfy { $0.answered != nil } }
}
