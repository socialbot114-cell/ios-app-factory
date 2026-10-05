import Foundation

/// Rascunho persistido da escalação do Rodada Mágica (ROD-03).
struct FantasyDraft: Codable, Equatable {
    var lineup: [Int]
    var captainID: Int?
}

enum FantasyRisk: Int, Comparable {
    case none, doubt, out
    static func < (lhs: FantasyRisk, rhs: FantasyRisk) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .none: return "Disponível"
        case .doubt: return "Dúvida"
        case .out: return "Fora"
        }
    }
}

struct FantasyOutlook: Equatable, Identifiable {
    let playerID: Int
    let price: Double
    /// Média de pontos fantasy nas últimas rodadas disputadas (0 se não jogou).
    let form: Double
    let opponentID: Int?
    let isHome: Bool
    let opponentStrength: Int?
    let risk: FantasyRisk
    let riskReason: String?
    var id: Int { playerID }
}

struct FantasyFilter: Equatable {
    var maxPrice: Double? = nil
    var minForm: Double? = nil
    var maxRisk: FantasyRisk = .out
    /// Só adversários com força até este valor.
    var maxOpponentStrength: Int? = nil
}

extension FootballCareer {
    static let fantasyFormWindow = 3
    static let fantasyDoubtCondition = 70

    /// Próxima rodada de liga ainda não jogada: número, dia de jogo e quantos jogos faltam até lá.
    var fantasyNextRound: (round: Int, matchDay: Int, slotsAway: Int)? {
        guard matchDayIndex < calendar.count else { return nil }
        for index in matchDayIndex..<calendar.count {
            if let round = calendar[index].leagueRound { return (round, index, index - matchDayIndex) }
        }
        return nil
    }

    var fantasyDeadlineText: String? {
        guard let next = fantasyNextRound else { return nil }
        switch next.slotsAway {
        case 0: return "Fecha antes da rodada \(next.round), o próximo jogo"
        case 1: return "Fecha antes da rodada \(next.round), depois de 1 jogo"
        default: return "Fecha antes da rodada \(next.round), depois de \(next.slotsAway) jogos"
        }
    }

    func fantasyOutlook(for athlete: FootballPlayer) -> FantasyOutlook {
        let teamID = athlete.teamID ?? -1
        let league = fixtures.filter { $0.competition.division != nil && $0.involves(teamID) }
        let played = league.filter(\.isPlayed).sorted { $0.matchDay < $1.matchDay }.suffix(Self.fantasyFormWindow)
        let form = played.isEmpty ? 0 : played.map { fantasyPoints(for: athlete, in: $0) }.reduce(0, +) / Double(played.count)
        let next = fantasyNextRound.flatMap { round in league.first { $0.matchDay == round.matchDay } }
        let opponent = next.map { $0.home == teamID ? $0.away : $0.home }
        var risk = FantasyRisk.none
        var reason: String?
        if athlete.isInjured {
            risk = .out; reason = "Lesionado · \(athlete.injuryRounds) jogo(s)"
        } else if athlete.isSuspended {
            risk = .out; reason = "Suspenso"
        } else if next == nil {
            risk = .out; reason = "Sem jogo na próxima rodada"
        } else if athlete.condition < Self.fantasyDoubtCondition {
            risk = .doubt; reason = "Condição \(athlete.condition)%"
        }
        return FantasyOutlook(playerID: athlete.id, price: fantasyPrice(athlete), form: (form * 10).rounded() / 10,
                              opponentID: opponent, isHome: next.map { $0.home == teamID } ?? false,
                              opponentStrength: opponent.flatMap { FootballSeason.team($0)?.strength },
                              risk: risk, riskReason: reason)
    }

    /// Mercado filtrado por posição, preço, forma, confronto e risco de ausência (ROD-02).
    func fantasyFilteredPool(position: FootballPosition, filter: FantasyFilter, excluding: Set<Int> = []) -> [FantasyOutlook] {
        fantasyPool.filter { $0.position == position && !excluding.contains($0.id) }
            .map { fantasyOutlook(for: $0) }
            .filter { outlook in
                if let maxPrice = filter.maxPrice, outlook.price > maxPrice { return false }
                if let minForm = filter.minForm, outlook.form < minForm { return false }
                if outlook.risk > filter.maxRisk { return false }
                if let limit = filter.maxOpponentStrength, (outlook.opponentStrength ?? Int.max) > limit { return false }
                return true
            }
            .sorted { $0.form == $1.form ? $0.playerID < $1.playerID : $0.form > $1.form }
    }

    /// Titulares ordenados para comparar o capitão: sem risco primeiro, depois forma recente.
    /// Não promete pontos futuros; mostra apenas fatos (forma, adversário, disponibilidade).
    func fantasyCaptainComparison(ids: [Int]) -> [FantasyOutlook] {
        ids.compactMap { player($0) }.map { fantasyOutlook(for: $0) }.sorted {
            if $0.risk != $1.risk { return $0.risk < $1.risk }
            return $0.form == $1.form ? $0.playerID < $1.playerID : $0.form > $1.form
        }
    }

    // MARK: Rascunho

    mutating func saveFantasyDraft(ids: [Int], captainID: Int?) {
        let draft = FantasyDraft(lineup: ids, captainID: captainID)
        world.fantasy.draft = (ids.isEmpty && captainID == nil) ? nil : draft
    }

    /// Rascunho se existir; senão a escalação salva.
    var fantasyWorkingLineup: FantasyDraft {
        world.fantasy.draft ?? FantasyDraft(lineup: world.fantasy.lineup, captainID: world.fantasy.captainID)
    }
}
