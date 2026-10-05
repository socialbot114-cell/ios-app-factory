import Foundation

// MARK: - Veredito de uma promessa de minutos

/// O que aconteceu com uma promessa ao vencer o prazo: cumprida, quase cumprida, quebrada ou justificada.
struct PromiseVerdict: Equatable {
    enum Kind: String, Equatable { case fulfilled, partial, broken, excused }

    var kind: Kind
    var moraleChange: Int
    var boardChange: Int
    var agentRelationChange: Int
    /// Só vira notícia pública quando o caso é relevante (craque que se sente enganado).
    var isPublic: Bool
    var quote: String
}

extension FootballCareer {
    /// Os cinco atletas mais fortes do elenco: o que acontece com eles chega à imprensa.
    func isStar(_ athlete: FootballPlayer) -> Bool {
        let top = clubRoster.sorted { $0.overall != $1.overall ? $0.overall > $1.overall : $0.id < $1.id }.prefix(5)
        return top.contains { $0.id == athlete.id }
    }

    /// Avalia a promessa sem alterar nada. `deadlinePassed` indica que o prazo venceu sem a meta batida.
    func promiseVerdict(_ promise: PlayerPromise, athlete: FootballPlayer, deadlinePassed: Bool) -> PromiseVerdict? {
        let professionalism = athlete.attributes[.professionalism]
        if promise.startsDone >= promise.requiredStarts {
            return PromiseVerdict(kind: .fulfilled, moraleChange: 8, boardChange: 0, agentRelationChange: 3, isPublic: false,
                                  quote: professionalism >= 12 ? "Obrigado pela confiança, professor. Vou retribuir em campo."
                                                               : "Era o mínimo, mas fico satisfeito. Vamos ver se continua assim.")
        }
        guard deadlinePassed else { return nil }
        // Quem estava machucado, suspenso ou convocado não tinha como começar: o prazo não pesa contra o treinador.
        if !athlete.isAvailable(matchDay: matchDayIndex) {
            return PromiseVerdict(kind: .excused, moraleChange: -3, boardChange: 0, agentRelationChange: 0, isPublic: false,
                                  quote: "Entendo que não deu por causa da minha situação. Quando eu voltar, quero a chance prometida.")
        }
        if promise.startsDone * 2 >= promise.requiredStarts {
            return PromiseVerdict(kind: .partial, moraleChange: -8, boardChange: 0, agentRelationChange: -2, isPublic: false,
                                  quote: "Você cumpriu parte do que combinamos. Esperava mais de você, professor.")
        }
        var morale = -18
        if professionalism <= 6 { morale = -22 } else if professionalism >= 14 { morale = -12 }
        let star = isStar(athlete)
        return PromiseVerdict(kind: .broken, moraleChange: morale, boardChange: -1, agentRelationChange: -6, isPublic: star && morale <= -18,
                              quote: professionalism >= 14 ? "Vou continuar treinando, mas a confiança ficou abalada."
                                                           : "Você me prometeu e não cumpriu. Meu empresário vai saber disso.")
    }

    /// Aplica o veredito uma única vez: moral, diretoria, relação com o empresário, resposta do atleta e, se justificar, notícia.
    mutating func applyPromiseVerdict(_ verdict: PromiseVerdict, promise: PlayerPromise, athleteIndex: Int) {
        let name = players[athleteIndex].name
        players[athleteIndex].morale = min(100, max(0, players[athleteIndex].morale + verdict.moraleChange))
        if verdict.boardChange != 0 { boardConfidence = min(100, max(0, boardConfidence + verdict.boardChange)) }
        if verdict.agentRelationChange != 0 { adjustRelationship(.agent, by: verdict.agentRelationChange) }

        let title: String
        var summary: String
        switch verdict.kind {
        case .fulfilled:
            title = "Promessa cumprida"
            summary = "\(name) começou \(promise.startsDone) jogo(s), como combinado. Moral +\(verdict.moraleChange)."
        case .partial:
            title = "Promessa cumprida pela metade"
            summary = "\(name) começou \(promise.startsDone) de \(promise.requiredStarts) jogos combinados. Moral \(verdict.moraleChange)."
        case .excused:
            title = "Prazo vencido sem culpa"
            summary = "\(name) não pôde começar os \(promise.requiredStarts) jogos por estar indisponível. Moral \(verdict.moraleChange); a diretoria não cobra."
        case .broken:
            title = "Promessa quebrada"
            summary = "\(name) começou \(promise.startsDone) de \(promise.requiredStarts) jogos combinados. Moral \(verdict.moraleChange); confiança da diretoria \(verdict.boardChange); relação com o empresário \(verdict.agentRelationChange)."
        }
        let memoryKind: MemoryKind?
        switch verdict.kind {
        case .fulfilled: memoryKind = .promiseKept
        case .partial: memoryKind = .promisePartial
        case .broken: memoryKind = .promiseBroken
        case .excused: memoryKind = nil
        }
        if let memoryKind { recordMemory(playerID: promise.playerID, kind: memoryKind, id: "promise-\(promise.id)") }
        if verdict.isPublic {
            fanMood = min(100, max(0, fanMood - 1))
            let leakID = "promise-\(promise.id)-leak"
            recordFact(WorldFact(id: leakID, source: .promise, worldDay: worldDay, title: "Bastidores: \(name) reclama de promessa",
                                 detail: "Fontes ligadas ao jogador dizem que o treinador não cumpriu a palavra sobre minutos. A torcida comenta o caso.",
                                 playerIDs: [promise.playerID], reliability: .confirmed, isPublic: true))
            deliverFact(leakID, inbox: .news, social: true)
            inbox[inbox.count - 1].sourcePromiseID = promise.id
        }
        summary += "\n\n“\(verdict.quote)”"
        let factID = "promise-\(promise.id)"
        var effects = ["Moral \(verdict.moraleChange)"]
        if verdict.boardChange != 0 { effects.append("Diretoria \(verdict.boardChange)") }
        if verdict.agentRelationChange != 0 { effects.append("Empresário \(verdict.agentRelationChange)") }
        var commitmentIDs: [Int] = []
        var nextEvents: [String] = []
        if verdict.kind == .broken, let followUp = openBrokenPromiseFollowUp(promiseID: promise.id, playerID: promise.playerID) {
            commitmentIDs.append(followUp.id)
            nextEvents.append("\(name) espera uma conversa em até \(Self.followUpDays) dias de jogo; sem ela, o clima piora.")
        }
        if verdict.isPublic { nextEvents.append("A imprensa já comenta o caso.") }
        recordFact(WorldFact(id: factID, source: .promise, worldDay: worldDay, title: title, detail: summary, playerIDs: [promise.playerID], isPublic: false,
                             effects: effects, commitmentIDs: commitmentIDs.isEmpty ? nil : commitmentIDs, nextEvents: nextEvents.isEmpty ? nil : nextEvents))
        addInbox(.general, title: title, body: summary, playerID: promise.playerID)
        inbox[inbox.count - 1].sourcePromiseID = promise.id
        inbox[inbox.count - 1].sourceFactID = factID
    }

    mutating func adjustRelationship(_ role: ContactRole, by delta: Int) {
        guard let index = world.contacts.contacts.firstIndex(where: { $0.role == role }) else { return }
        world.contacts.contacts[index].relationship = min(100, max(0, world.contacts.contacts[index].relationship + delta))
    }

    // MARK: - Pedido ignorado

    /// Pedidos de minutos sem resposta por 3 dias de jogo irritam o atleta. Acontece uma única vez por mensagem.
    mutating func escalateIgnoredRequests() {
        guard let selectedClubID else { return }
        for index in inbox.indices {
            let message = inbox[index]
            guard message.kind == .playerPlayingTime, !message.isResolved, message.coachReply == nil,
                  let playerID = message.playerID, let athleteIndex = players.firstIndex(where: { $0.id == playerID }),
                  players[athleteIndex].teamID == selectedClubID,
                  (season - message.season) * FootballSeason.matchDaysPerSeason + matchDayIndex - message.matchDay >= 3 else { continue }
            players[athleteIndex].morale = max(0, players[athleteIndex].morale - 4)
            adjustRelationship(.agent, by: -1)
            recordMemory(playerID: playerID, kind: .requestIgnored, id: "ignored-\(message.id)")
            inbox[index].coachReply = "Sem resposta do treinador: \(players[athleteIndex].name) ficou sem retorno por 3 dias de jogo. Moral -4."
        }
    }
}
