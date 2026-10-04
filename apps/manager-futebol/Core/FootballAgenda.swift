import Foundation

/// Destinos de gameplay; a interface decide como abrir cada um.
enum FootballAgendaDestination: String, Equatable {
    case squad, market, alerts, contracts
}

struct FootballAgendaItem: Identifiable, Equatable {
    enum Kind: Int { case promise, offer, event, contract }
    let id: String
    let kind: Kind
    let title: String
    let detail: String
    let destination: FootballAgendaDestination
    /// Limite absoluto no calendário, contado desde a primeira temporada.
    let deadlineWorldDay: Int
    let daysRemaining: Int
    /// Contratos só são processados ao encerrar a temporada explicitamente.
    let expiresOnCalendarAdvance: Bool

    var expiresOnNextAdvance: Bool { expiresOnCalendarAdvance && daysRemaining <= 1 }
    var deadlineText: String {
        if kind == .contract { return "Ao encerrar a temporada · \(daysRemaining) dia(s) de calendário" }
        if daysRemaining <= 0 { return "Prazo atingido" }
        if daysRemaining == 1 { return "Último dia · vence ao avançar" }
        return "\(daysRemaining) dias de calendário restantes"
    }
}

extension FootballCareer {
    /// Consulta pura: não lê mensagens, resolve eventos nem altera compromissos.
    var agenda: [FootballAgendaItem] {
        guard let clubID = selectedClubID, !isFired else { return [] }
        let seasonStart = (season - 1) * FootballSeason.matchDaysPerSeason
        var items: [FootballAgendaItem] = []
        for promise in promises where promise.startsDone < promise.requiredStarts {
            guard let athlete = player(promise.playerID), athlete.teamID == clubID else { continue }
            let deadline = (promise.season - 1) * FootballSeason.matchDaysPerSeason + promise.deadlineMatchDay
            items.append(FootballAgendaItem(id: "promise-\(promise.id)", kind: .promise,
                title: "Promessa a \(athlete.name)",
                detail: "\(promise.startsDone)/\(promise.requiredStarts) titularidades. A última partida ainda conta; sem cumprir, moral -18 e confiança -1.",
                destination: .squad, deadlineWorldDay: deadline, daysRemaining: max(0, deadline - worldDay), expiresOnCalendarAdvance: true))
        }
        for offer in offers {
            let deadline = seasonStart + offer.expiresAfterRound
            items.append(FootballAgendaItem(id: "offer-\(offer.id)", kind: .offer,
                title: "Oferta por \(player(offer.playerID)?.name ?? "atleta")",
                detail: "\(FootballSeason.teamName(offer.clubID)) · \(FootballFormat.money(offer.amount)). Sem resposta, a proposta é retirada.",
                destination: .market, deadlineWorldDay: deadline, daysRemaining: max(0, deadline - worldDay), expiresOnCalendarAdvance: true))
        }
        for event in pendingEvents {
            items.append(FootballAgendaItem(id: "event-\(event.id)", kind: .event, title: event.title,
                detail: "Sem decisão, será aplicada a resposta automática do acontecimento.",
                destination: .alerts, deadlineWorldDay: event.expiresWorldDay,
                daysRemaining: max(0, event.expiresWorldDay - worldDay), expiresOnCalendarAdvance: true))
        }
        for athlete in clubRoster where athlete.contract.endSeason > 0 && athlete.contract.endSeason <= season && !athlete.onLoan {
            let deadline = athlete.contract.endSeason * FootballSeason.matchDaysPerSeason
            items.append(FootballAgendaItem(id: "contract-\(athlete.id)", kind: .contract,
                title: "Renovar com \(athlete.name)", detail: "Contrato até a temporada \(athlete.contract.endSeason). Renove antes de encerrar para evitar a saída sem transferência.",
                destination: .contracts, deadlineWorldDay: deadline, daysRemaining: max(0, deadline - worldDay), expiresOnCalendarAdvance: false))
        }
        return items.sorted {
            if $0.deadlineWorldDay != $1.deadlineWorldDay { return $0.deadlineWorldDay < $1.deadlineWorldDay }
            if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
            return $0.id < $1.id
        }
    }

    var agendaExpiringOnNextAdvance: [FootballAgendaItem] { agenda.filter(\.expiresOnNextAdvance) }

    /// Retorna ao Gestor antes de consumir uma decisão ou atravessar um prazo.
    @discardableResult
    mutating func simulateUntilAgendaDecision(maxDays: Int = 30) -> (days: Int, reason: String) {
        var days = 0
        while days < maxDays {
            if let priority = agenda.first(where: { $0.expiresOnNextAdvance || $0.kind == .offer || $0.kind == .event }) {
                return (days, "Prioridade na agenda: \(priority.title). \(priority.deadlineText).")
            }
            let result = simulateUntilDecision(maxDays: 1)
            days += result.days
            if result.days == 0 || result.reason != "Limite de dias atingido." { return (days, result.reason) }
        }
        return (days, "Limite de dias atingido. Confira a agenda antes de continuar.")
    }
}
