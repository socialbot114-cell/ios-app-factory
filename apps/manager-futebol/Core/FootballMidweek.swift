import Foundation

/// Abertura do meio da semana de uma rodada. Cada semana tem uma ou duas aberturas do celular: a de sempre,
/// depois da rodada, e, quando há decisões importantes pendentes, uma no meio da semana, antes do jogo.
/// Nela dá para descansar o time (recupera a condição do elenco e a energia do treinador).
struct MidweekState: Codable, Equatable {
    /// Temporada * 1000 + rodada: a abertura de uma rodada não vale para outra.
    var key: Int
    var opened = false
    var restUsed = false
    var closed = false
}

extension FootballCareer {
    /// Decisões importantes (pontuação 50 ou mais) que tornam a semana de duas aberturas.
    /// Calibrado pela temporada inteira: com 4 decisões importantes, cerca de metade das semanas ganha a segunda abertura.
    static let midweekDecisionThreshold = 4
    static let midweekImportantScore = 50
    static let midweekRestCondition = 15
    static let midweekRestEnergy = 20

    var midweekKey: Int { season * 1000 + matchDayIndex }

    /// A semana tem decisões importantes pendentes, então ganha a abertura do meio da semana.
    var midweekNeeded: Bool {
        guard selectedClubID != nil, !isSeasonComplete, !isFired, offseason == nil else { return false }
        return suggestions().filter { $0.score >= Self.midweekImportantScore }.count >= Self.midweekDecisionThreshold
    }

    /// A abertura do meio da semana já foi feita nesta rodada (aberta ou já fechada). Não muda ao fechar.
    var midweekOpenedThisRound: Bool { midweek?.key == midweekKey && midweek?.opened == true }

    /// Há uma abertura do meio da semana a fazer antes do jogo: a rodada espera por ela.
    var midweekWaiting: Bool {
        nextUserFixture != nil && midweekNeeded && !midweekOpenedThisRound
    }

    /// A abertura do meio da semana está aberta agora: é quando se descansa e se ajusta o treino.
    var midweekOpen: Bool {
        midweek?.key == midweekKey && midweek?.opened == true && midweek?.closed == false
    }

    /// O time já descansou nesta abertura do meio da semana.
    var midweekRestUsed: Bool { midweek?.key == midweekKey && midweek?.restUsed == true }

    /// Abre o meio da semana. O celular trava e destrava com ela, como em qualquer abertura.
    @discardableResult
    mutating func openMidweek() -> Bool {
        guard midweekWaiting else { return false }
        midweek = MidweekState(key: midweekKey, opened: true)
        return true
    }

    /// Fecha o meio da semana para ir ao jogo.
    mutating func closeMidweek() {
        guard midweekOpen, var state = midweek else { return }
        state.closed = true
        midweek = state
    }

    /// Descanso do time no meio da semana: condição de todo o elenco e energia do treinador. Uma vez por abertura.
    @discardableResult
    mutating func restTeam() -> Bool {
        guard midweekOpen, midweek?.restUsed == false, let selectedClubID else { return false }
        for index in players.indices where players[index].teamID == selectedClubID {
            players[index].condition = min(100, players[index].condition + Self.midweekRestCondition)
        }
        world.coach.energy = min(100, world.coach.energy + Self.midweekRestEnergy)
        midweek?.restUsed = true
        return true
    }
}
