import Foundation

// MARK: - Gestor: pendências organizadas e preparação do próximo jogo (GES-01, GES-02, GES-03)

enum AgendaSort: String, CaseIterable, Identifiable, Equatable {
    case deadline, importance, owner

    var id: String { rawValue }
    var title: String {
        switch self {
        case .deadline: return "Prazo"
        case .importance: return "Importância"
        case .owner: return "Responsável"
        }
    }
}

struct PreparationItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let done: Bool
    let destination: FootballAgendaDestination
}

extension FootballCareer {
    /// A mesma agenda, ordenada pelo critério escolhido. Empates sempre se resolvem por prazo e depois por ID.
    func sortedAgenda(by sort: AgendaSort) -> [FootballAgendaItem] {
        let base = agenda
        switch sort {
        case .deadline:
            return base
        case .importance:
            return base.sorted {
                if $0.importance != $1.importance { return $0.importance > $1.importance }
                if $0.deadlineWorldDay != $1.deadlineWorldDay { return $0.deadlineWorldDay < $1.deadlineWorldDay }
                return $0.id < $1.id
            }
        case .owner:
            return base.sorted {
                if $0.owner != $1.owner { return $0.owner.rawValue < $1.owner.rawValue }
                if $0.deadlineWorldDay != $1.deadlineWorldDay { return $0.deadlineWorldDay < $1.deadlineWorldDay }
                return $0.id < $1.id
            }
        }
    }

    /// O que vence antes do próximo avanço de calendário, do mais importante para o menos (GES-03).
    var dueBeforeNextAdvance: [FootballAgendaItem] {
        agendaExpiringOnNextAdvance.sorted {
            if $0.importance != $1.importance { return $0.importance > $1.importance }
            return $0.id < $1.id
        }
    }

    /// Lista de preparação para a próxima partida do usuário, com o que já está pronto e o que falta.
    func matchPreparation() -> [PreparationItem] {
        guard selectedClubID != nil, !isFired, liveMatch == nil, nextUserFixture != nil else { return [] }
        var items: [PreparationItem] = []
        items.append(PreparationItem(id: "scout", title: "Relatório do rival", detail: opponentPrep ? "Preparação feita: bônus pequeno no jogo." : "Ainda sem preparação específica para este adversário.",
                                     done: opponentPrep, destination: .squad))
        let warnings = lineupWarnings
        items.append(PreparationItem(id: "lineup", title: "Escalação", detail: warnings.first ?? "Sem alertas na escalação.", done: warnings.isEmpty, destination: .squad))
        let starters = self.starters
        let average = starters.isEmpty ? 0 : starters.map(\.condition).reduce(0, +) / starters.count
        items.append(PreparationItem(id: "condition", title: "Condição física", detail: "Condição média dos titulares: \(average)%.", done: average >= 80, destination: .squad))
        if let opponent = predictedOpponentStyle {
            let suggested = FootballPlayStyle.bestAnswer(to: opponent)
            items.append(PreparationItem(id: "style", title: "Estilo de jogo", detail: playStyle == suggested ? "Seu estilo é o que o auxiliar sugere (\(suggested.rawValue))." : "O auxiliar sugere \(suggested.rawValue); você está com \(playStyle.rawValue).",
                                         done: playStyle == suggested, destination: .squad))
        }
        let benchedPromises = promises.filter { promise in promise.startsDone < promise.requiredStarts && !startingXI.contains(promise.playerID) }
        items.append(PreparationItem(id: "promises", title: "Promessas de minutos", detail: benchedPromises.isEmpty ? "Ninguém com promessa pendente fora do time." : "\(benchedPromises.count) atleta(s) com promessa pendente fora da escalação.",
                                     done: benchedPromises.isEmpty, destination: .squad))
        items.append(PreparationItem(id: "press", title: "Coletiva", detail: pendingPress == nil ? "Sem coletiva pendente." : "Há coletiva aguardando resposta.", done: pendingPress == nil, destination: .alerts))
        return items
    }
}
