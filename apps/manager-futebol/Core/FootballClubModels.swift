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

// MARK: - Mercado

struct TransferWindow: Equatable {
    enum Kind: String { case preseason, midseason }

    let kind: Kind
    let startDay: Int
    let endDay: Int
    let currentDay: Int

    var title: String { kind == .preseason ? "Janela de pré-temporada" : "Janela do meio do ano" }
    var daysLeft: Int { endDay - currentDay + 1 }
    var isLastDay: Bool { currentDay == endDay }

    static let preseason = (start: 0, end: 1)
    static let midseason = (start: 9, end: 11)
}

struct TransferBid: Equatable {
    var playerID: Int
    var fee: Int
    var installments = 1
    var swapPlayerID: Int? = nil
    var goalBonus = 0
    var wage: Int
    var years = 3
}

enum BidResponse: Equatable {
    case accepted
    case counter(fee: Int)
    case clubRefuses(String)
    case playerRefuses(askWage: Int)
    case notAllowed(String)
}

struct TransferRecord: Codable, Equatable, Identifiable {
    var id: Int
    var season: Int
    var matchDay: Int
    var playerName: String
    var playerID: Int
    var fromClubID: Int?
    var toClubID: Int?
    var fee: Int
    var isLoan = false
}

struct PendingPayment: Codable, Equatable, Identifiable {
    let id: Int
    let amount: Int
    let dueMatchDay: Int
    let season: Int
    let note: String
}

/// Bônus devido ao clube vendedor quando o atleta atingir um número de gols na temporada.
struct GoalBonus: Codable, Equatable, Identifiable {
    let id: Int
    let playerID: Int
    let clubID: Int
    let goals: Int
    let amount: Int
    let season: Int
}

// MARK: - Observação

struct ScoutMission: Codable, Equatable, Identifiable {
    let id: Int
    var region: Int?
    var position: FootballPosition?
    var maxAge: Int
    var maxValue: Int
    let startedMatchDay: Int
    let season: Int
    var durationMatchDays: Int
    var completed = false

    var summary: String {
        var parts: [String] = []
        parts.append(position?.title ?? "Qualquer posição")
        parts.append(region.map { LeagueTeam.regionNames[$0] } ?? "Todo o país")
        parts.append("até \(maxAge) anos")
        parts.append("até \(FootballFormat.money(maxValue))")
        return parts.joined(separator: " · ")
    }
}

struct ScoutReport: Codable, Equatable, Identifiable {
    let id: Int
    let missionID: Int
    let playerID: Int
    let currentStars: Int
    let potentialStars: Int
    let note: String
    let season: Int
}

struct YouthCupResult: Codable, Equatable, Identifiable {
    let season: Int
    let winnerID: Int
    let userResult: String
    let topScorerName: String

    var id: Int { season }
}

// MARK: - Comissão técnica

enum StaffRole: String, Codable, CaseIterable, Identifiable {
    case assistant, fitnessCoach, headScout, doctor, goalkeeperCoach, youthCoach, analyst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assistant: return "Auxiliar técnico"
        case .fitnessCoach: return "Preparador físico"
        case .headScout: return "Olheiro-chefe"
        case .doctor: return "Médico"
        case .goalkeeperCoach: return "Treinador de goleiros"
        case .youthCoach: return "Técnico da base"
        case .analyst: return "Analista de desempenho"
        }
    }

    var effect: String {
        switch self {
        case .assistant: return "Define a precisão da leitura do rival e das sugestões táticas."
        case .fitnessCoach: return "Melhora a recuperação física e reduz o risco de lesões."
        case .headScout: return "Relatórios de observação mais precisos."
        case .doctor: return "Reduz o tempo de recuperação das lesões."
        case .goalkeeperCoach: return "Acelera a evolução dos goleiros."
        case .youthCoach: return "Eleva a qualidade dos jovens que chegam da base."
        case .analyst: return "Libera mapa de calor, análise do adversário e jogadores-chave do rival."
        }
    }

    var symbol: String {
        switch self {
        case .assistant: return "person.badge.shield.checkmark"
        case .fitnessCoach: return "figure.run"
        case .headScout: return "binoculars.fill"
        case .doctor: return "cross.case.fill"
        case .goalkeeperCoach: return "hand.raised.fill"
        case .youthCoach: return "figure.and.child.holdinghands"
        case .analyst: return "chart.xyaxis.line"
        }
    }
}

struct StaffMember: Codable, Equatable, Identifiable {
    let id: Int
    var name: String
    var role: StaffRole
    var ability: Int
    var wage: Int
}

// MARK: - Estrutura do clube

enum FacilityKind: String, Codable, CaseIterable, Identifiable {
    case trainingCenter, youthAcademy, medical, stadium

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trainingCenter: return "Centro de treinamento"
        case .youthAcademy: return "Categoria de base"
        case .medical: return "Departamento médico"
        case .stadium: return "Estádio"
        }
    }

    var symbol: String {
        switch self {
        case .trainingCenter: return "dumbbell.fill"
        case .youthAcademy: return "graduationcap.fill"
        case .medical: return "cross.case.fill"
        case .stadium: return "building.columns.fill"
        }
    }

    var effect: String {
        switch self {
        case .trainingCenter: return "Mais evolução no treino: de -12% (nível 1) a +12% (nível 5)."
        case .youthAcademy: return "Mais qualidade e mais chance de joias na leva anual."
        case .medical: return "Lesões duram menos: até 14% a menos no nível 5."
        case .stadium: return "Cada nível amplia a capacidade em 8% e a bilheteria."
        }
    }
}

struct UpgradeProject: Codable, Equatable, Identifiable {
    let id: Int
    let kind: FacilityKind
    let targetLevel: Int
    let cost: Int
    let dueSeason: Int
    let dueMatchDay: Int
}

enum TicketPrice: Int, Codable, CaseIterable, Identifiable {
    case popular = 0, normal, premium, elite

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .popular: return "Popular"
        case .normal: return "Normal"
        case .premium: return "Premium"
        case .elite: return "Elite"
        }
    }

    /// Quanto cada torcedor paga em relação ao preço normal.
    var revenueMultiplier: Double {
        switch self {
        case .popular: return 0.65
        case .normal: return 1.0
        case .premium: return 1.45
        case .elite: return 2.0
        }
    }

    /// Efeito do preço na vontade de ir ao estádio.
    var demandFactor: Double {
        switch self {
        case .popular: return 1.25
        case .normal: return 1.0
        case .premium: return 0.72
        case .elite: return 0.48
        }
    }
}

struct SponsorOffer: Codable, Equatable, Identifiable {
    let id: Int
    let sponsor: String
    let fixedPerSeason: Int
    let bonusPerWin: Int
    let titleBonus: Int
    let seasons: Int
    let profile: String

    var totalIfAverage: Int { fixedPerSeason + bonusPerWin * 7 }
}

struct SponsorDeal: Codable, Equatable {
    let sponsor: String
    let fixedPerSeason: Int
    let bonusPerWin: Int
    let titleBonus: Int
    var endSeason: Int
}

struct MonthReport: Equatable, Identifiable {
    let month: Int
    let income: Int
    let expenses: Int
    let closingCash: Int

    var id: Int { month }
    var result: Int { income - expenses }
}

// MARK: - Narrativa e carreira

struct HeadToHead: Codable, Equatable {
    /// Vitórias do clube de menor id, empates e vitórias do clube de maior id.
    var lowWins = 0
    var draws = 0
    var highWins = 0
    var lowGoals = 0
    var highGoals = 0
    var lastResult = "—"

    var matches: Int { lowWins + draws + highWins }
}

struct ClubRecords: Codable, Equatable {
    var topScorerName = "—"
    var topScorerGoals = 0
    var mostAppearancesName = "—"
    var mostAppearances = 0
    var biggestWin = "—"
    var biggestWinMargin = 0
    var biggestLoss = "—"
    var biggestLossMargin = 0
    var longestUnbeaten = 0
    var currentUnbeaten = 0
    var highestAttendance = 0
    var mostPointsInSeason = 0
}

struct LegendEntry: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let position: FootballPosition
    let goals: Int
    let appearances: Int
    let lastSeason: Int
}

struct JobInvitation: Codable, Equatable, Identifiable {
    let clubID: Int
    let season: Int

    var id: Int { clubID }
}

struct AwardEntry: Codable, Equatable {
    let playerID: Int
    let name: String
    let position: FootballPosition
    let teamID: Int?
}

struct SeasonAwards: Codable, Equatable {
    var bestPlayer: AwardEntry?
    var youngPlayer: AwardEntry?
    var topScorer: AwardEntry?
    var topScorerGoals = 0
    var teamOfTheSeason: [AwardEntry] = []
    var coachOfTheYearClubID: Int?
}
