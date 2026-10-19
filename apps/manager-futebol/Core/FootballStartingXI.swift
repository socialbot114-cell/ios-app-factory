import Foundation

// MARK: - Escolha manual dos titulares

extension FootballCareer {
    /// Motivo pelo qual a escalação não pode ser salva agora; nil quando ela é válida para a formação atual.
    func lineupProblem(_ ids: [Int]) -> String? {
        guard selectedClubID != nil, !isFired else { return "Sem clube." }
        if liveMatch != nil { return "Não dá para trocar titulares durante a partida." }
        if ids.count != 11 { return "A escalação precisa de 11 titulares; hoje são \(ids.count)." }
        if Set(ids).count != ids.count { return "Um atleta não pode ocupar duas vagas." }
        let picked = ids.compactMap { player($0) }
        guard picked.count == ids.count else { return "Algum atleta escolhido não está mais no clube." }
        if picked.contains(where: { $0.isYouth || $0.teamID != selectedClubID }) {
            return "Só atletas do elenco principal podem ser titulares."
        }
        if let out = picked.first(where: { !$0.isAvailable(matchDay: matchDayIndex) }) {
            return "\(out.name) não pode jogar agora (lesão, suspensão ou convocação)."
        }
        // Cada vaga da formação precisa de alguém que saiba ocupá-la. Quem joga na posição natural entra primeiro.
        var remaining = picked
        for position in FootballPosition.allCases {
            let required = formation.requiredPlayers[position, default: 0]
            let fitting = remaining
                .filter { $0.canPlay(as: position) }
                .sorted { ($0.position == position ? 0 : 1) < ($1.position == position ? 0 : 1) }
                .prefix(required)
            if fitting.count < required {
                let missing = required - fitting.count
                return "Faltam \(missing) \(position.title.lowercased()) para o \(formation.rawValue)."
            }
            let used = Set(fitting.map(\.id))
            remaining.removeAll { used.contains($0.id) }
        }
        return nil
    }

    /// Salva a escalação escolhida pelo treinador. Devolve o motivo quando ela não serve.
    @discardableResult
    mutating func saveStartingXI(_ ids: [Int]) -> String? {
        if let problem = lineupProblem(ids) { return problem }
        startingXI = ids
        if let taker = penaltyTakerID, !ids.contains(taker) { penaltyTakerID = nil }
        return nil
    }
}

// MARK: - Rodízio

/// Troca sugerida: um titular cansado sai e um reserva descansado da mesma função entra.
struct RotationSwap: Equatable {
    let outgoingID: Int
    let incomingID: Int
}

extension FootballCareer {
    /// Abaixo desta condição o titular rende bem menos e vale poupar (mesmo limite do aviso de rodízio da preparação).
    static let tiredCondition = 60
    /// O reserva só entra se não for muito pior, já descontada a condição de cada um.
    static let rotationMaxDrop = 3.0

    /// Sugestões de rodízio para uma escalação: um reserva por titular cansado, sempre com a escalação ainda válida.
    func rotationSwaps(for ids: [Int]) -> [RotationSwap] {
        guard selectedClubID != nil, liveMatch == nil else { return [] }
        let tired = ids.compactMap { player($0) }
            .filter { $0.condition < Self.tiredCondition }
            .sorted { $0.condition < $1.condition }
        var lineup = ids
        var swaps: [RotationSwap] = []
        for starter in tired {
            let candidates = clubRoster.filter { reserve in
                !reserve.isYouth && !lineup.contains(reserve.id) && reserve.isAvailable(matchDay: matchDayIndex)
                    && reserve.condition >= Self.tiredCondition && reserve.canPlay(as: starter.position)
                    && reserve.effectiveOverall >= starter.effectiveOverall - Self.rotationMaxDrop
            }
            for reserve in candidates.sorted(by: { $0.effectiveOverall > $1.effectiveOverall }) {
                var trial = lineup
                guard let index = trial.firstIndex(of: starter.id) else { break }
                trial[index] = reserve.id
                if lineupProblem(trial) == nil {
                    lineup = trial
                    swaps.append(RotationSwap(outgoingID: starter.id, incomingID: reserve.id))
                    break
                }
            }
        }
        return swaps
    }
}
