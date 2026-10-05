import Foundation

// MARK: - Negociação de renovação em etapas (F3-03/F3-04)

enum TalkStage: String, Codable, Equatable {
    case consultation, proposal, counter, agreed, refused, expired

    var isOpen: Bool { self == .consultation || self == .proposal || self == .counter }

    var title: String {
        switch self {
        case .consultation: return "Consulta"
        case .proposal: return "Proposta enviada"
        case .counter: return "Contraproposta"
        case .agreed: return "Acordo"
        case .refused: return "Recusada"
        case .expired: return "Expirada"
        }
    }
}

struct RenewalTalk: Codable, Equatable, Identifiable {
    let id: Int
    let playerID: Int
    var stage: TalkStage
    var topInterest: PlayerInterest
    var askWage: Int
    var askYears: Int
    var askStatus: SquadStatus
    var counterWage: Int? = nil
    var rounds = 0
    let openedWorldDay: Int
    var expiresWorldDay: Int
    var commitmentID: Int? = nil
}

extension FootballCareer {
    static let talkLifetimeDays = 4
    static let counterAnswerDays = 3
    static let maxProposalRounds = 3

    func openTalk(for playerID: Int) -> RenewalTalk? {
        talks.first { $0.playerID == playerID && $0.stage.isOpen }
    }

    /// Motivo pelo qual o atleta não quer sequer conversar, se houver.
    func talkBlockReason(playerID: Int) -> String? {
        guard canRenew(playerID: playerID), let athlete = player(playerID) else { return "Este atleta não pode renovar agora." }
        if openTalk(for: playerID) != nil { return "Já existe uma conversa aberta com \(athlete.name)." }
        if trust(of: playerID) <= -60 { return "\(athlete.name) não confia mais no treinador e se recusa a conversar por enquanto." }
        if athlete.morale < 20 { return "\(athlete.name) está insatisfeito demais para renovar." }
        return nil
    }

    /// Etapa 1, consulta: o atleta mostra o que valoriza e o que espera. Nada é assinado.
    @discardableResult
    mutating func startRenewalTalk(playerID: Int) -> RenewalTalk? {
        guard talkBlockReason(playerID: playerID) == nil, let athlete = player(playerID), let ask = contractAsk(playerID: playerID) else { return nil }
        let talk = RenewalTalk(id: nextTalkID, playerID: playerID, stage: .consultation, topInterest: topInterest(of: athlete),
                               askWage: ask.wage, askYears: ask.years, askStatus: ask.status,
                               openedWorldDay: worldDay, expiresWorldDay: worldDay + Self.talkLifetimeDays)
        nextTalkID += 1
        talks.append(talk)
        let factID = "talk-\(talk.id)-open"
        recordFact(WorldFact(id: factID, source: .negotiation, worldDay: worldDay, title: "Conversa de renovação com \(athlete.name)",
                             detail: "\(athlete.name) valoriza \(talk.topInterest.label) e espera cerca de \(FootballFormat.money(ask.wage)) por temporada, por \(ask.years) ano(s), como \(ask.status.title.lowercased()).",
                             playerIDs: [playerID]))
        deliverFact(factID, inbox: .general)
        return talk
    }

    /// Etapas 2 e 3, proposta e contraproposta. Aceita, contra-ataca, recusa ou, depois de três rodadas, rompe.
    @discardableResult
    mutating func proposeInTalk(talkID: Int, wage: Int, years: Int, status: SquadStatus) -> NegotiationOutcome {
        guard let talkIndex = talks.firstIndex(where: { $0.id == talkID }), talks[talkIndex].stage.isOpen,
              talks[talkIndex].expiresWorldDay >= worldDay else { return .notAllowed("Esta conversa já foi encerrada.") }
        let playerID = talks[talkIndex].playerID
        talks[talkIndex].rounds += 1
        talks[talkIndex].stage = .proposal
        let outcome = offerRenewal(playerID: playerID, wage: wage, years: years, status: status)
        switch outcome {
        case .accepted:
            closeTalk(at: talkIndex, as: .agreed)
        case .counter(let counter):
            talks[talkIndex].stage = .counter
            talks[talkIndex].counterWage = counter
            talks[talkIndex].expiresWorldDay = worldDay + Self.counterAnswerDays
            if let old = talks[talkIndex].commitmentID { resolveCommitment(id: old, as: .cancelled) }
            let name = player(playerID)?.name ?? "o atleta"
            let commitment = openCommitment(kind: .negotiationCounter, playerID: playerID, days: Self.counterAnswerDays,
                                            title: "Responder \(name)", detail: "Contraproposta de \(FootballFormat.money(counter)) por temporada. Sem resposta, a conversa expira.")
            talks[talkIndex].commitmentID = commitment.id
        case .refused:
            if talks[talkIndex].rounds >= Self.maxProposalRounds {
                closeTalk(at: talkIndex, as: .refused)
            } else {
                talks[talkIndex].stage = .consultation
            }
        case .overWageCap, .notAllowed:
            talks[talkIndex].rounds -= 1
            talks[talkIndex].stage = talks[talkIndex].counterWage == nil ? .consultation : .counter
        }
        return outcome
    }

    /// Aceita a contraproposta do atleta pelo valor que ele pediu.
    @discardableResult
    mutating func acceptCounter(talkID: Int, years: Int? = nil, status: SquadStatus? = nil) -> Bool {
        guard let index = talks.firstIndex(where: { $0.id == talkID }), talks[index].stage == .counter, let counter = talks[index].counterWage,
              talks[index].expiresWorldDay >= worldDay, let athlete = player(talks[index].playerID) else { return false }
        guard wageCapAllows(extra: counter - athlete.contract.wage) else { return false }
        applyRenewal(playerID: athlete.id, wage: counter, years: years ?? talks[index].askYears, status: status ?? talks[index].askStatus)
        closeTalk(at: index, as: .agreed)
        return true
    }

    /// Encerra a conversa sem acordo (o treinador desiste).
    @discardableResult
    mutating func walkAwayFromTalk(talkID: Int) -> Bool {
        guard let index = talks.firstIndex(where: { $0.id == talkID }), talks[index].stage.isOpen else { return false }
        closeTalk(at: index, as: .refused)
        return true
    }

    /// Fecha conversas cujo prazo passou, em ordem de ID. Faz parte do processamento do calendário.
    @discardableResult
    mutating func expireStaleTalks() -> [Int] {
        var expired: [Int] = []
        for index in talks.indices.sorted(by: { talks[$0].id < talks[$1].id }) where talks[index].stage.isOpen && talks[index].expiresWorldDay < worldDay {
            closeTalk(at: index, as: .expired)
            expired.append(talks[index].id)
        }
        return expired
    }

    mutating func expireTalks(forCommitment commitmentID: Int) {
        guard let index = talks.firstIndex(where: { $0.commitmentID == commitmentID && $0.stage.isOpen }) else { return }
        closeTalk(at: index, as: .expired)
    }

    private mutating func closeTalk(at index: Int, as stage: TalkStage) {
        guard talks[index].stage != stage else { return }
        talks[index].stage = stage
        if let commitment = talks[index].commitmentID {
            resolveCommitment(id: commitment, as: stage == .agreed ? .fulfilled : (stage == .expired ? .expired : .cancelled))
        }
        guard let athlete = player(talks[index].playerID) else { return }
        let talk = talks[index]
        switch stage {
        case .agreed:
            recordMemory(playerID: athlete.id, kind: .renewalAgreed, id: "talk-\(talk.id)-agreed")
            let factID = "talk-\(talk.id)-agreed"
            let star = isStar(athlete)
            recordFact(WorldFact(id: factID, source: .negotiation, worldDay: worldDay, title: "\(athlete.name) renova com o clube",
                                 detail: "Depois de \(talk.rounds) rodada(s) de conversa, \(athlete.name) assinou a renovação.", playerIDs: [athlete.id], isPublic: star))
            if star { deliverFact(factID, inbox: .news, social: true) }
        case .refused, .expired:
            if stage == .refused, talk.rounds > 0 { recordMemory(playerID: athlete.id, kind: .negotiationBroke, id: "talk-\(talk.id)-broke") }
            let factID = "talk-\(talk.id)-\(stage.rawValue)"
            let star = isStar(athlete)
            recordFact(WorldFact(id: factID, source: .negotiation, worldDay: worldDay,
                                 title: stage == .refused ? "Renovação com \(athlete.name) naufraga" : "Conversa com \(athlete.name) expira",
                                 detail: "Sem acordo, \(athlete.name) pode deixar o clube quando o contrato terminar.",
                                 playerIDs: [athlete.id], reliability: star ? .rumor : .confirmed, isPublic: star))
            deliverFact(factID, inbox: .general, social: star)
        default:
            break
        }
    }
}

// MARK: - Acompanhamento de uma promessa quebrada (F3-07)

extension FootballCareer {
    static let followUpDays = 4

    /// Depois de quebrar uma promessa, o atleta pede uma conversa. Abre o compromisso uma única vez por promessa.
    @discardableResult
    mutating func openBrokenPromiseFollowUp(promiseID: Int, playerID: Int) -> Commitment? {
        let factID = "followup-promise-\(promiseID)"
        guard let athlete = player(playerID), recordFact(WorldFact(id: factID, source: .promise, worldDay: worldDay,
                                                                  title: "\(athlete.name) quer conversar", detail: "Depois da promessa quebrada, \(athlete.name) espera uma conversa franca em até \(Self.followUpDays) dias de jogo.",
                                                                  playerIDs: [playerID])) else { return nil }
        deliverFact(factID, inbox: .general)
        return openCommitment(kind: .followUp, playerID: playerID, factID: factID, days: Self.followUpDays,
                              title: "Conversar com \(athlete.name)", detail: "Promessa quebrada: ele quer ouvir você antes que o clima piore.")
    }

    /// O treinador conversa com o atleta e reconstrói parte da confiança.
    @discardableResult
    mutating func holdMeeting(commitmentID: Int) -> Bool {
        guard let commitment = commitments.first(where: { $0.id == commitmentID }), commitment.kind == .followUp, commitment.state == .open,
              let playerID = commitment.playerID, let index = players.firstIndex(where: { $0.id == playerID }),
              players[index].teamID == selectedClubID, resolveCommitment(id: commitmentID, as: .fulfilled) else { return false }
        players[index].morale = min(100, players[index].morale + 6)
        recordMemory(playerID: playerID, kind: .meetingHeld, id: "meeting-\(commitmentID)")
        let factID = "meeting-\(commitmentID)"
        recordFact(WorldFact(id: factID, source: .promise, worldDay: worldDay, title: "Conversa com \(players[index].name)",
                             detail: "O treinador ouviu \(players[index].name) e reconheceu o erro. Moral +6.", playerIDs: [playerID]))
        deliverFact(factID, inbox: .general)
        return true
    }

    /// Sem conversa a tempo: o atleta se irrita e, se já estava mal, pede para sair.
    mutating func handleFollowUpExpired(_ commitment: Commitment) {
        guard let playerID = commitment.playerID, let index = players.firstIndex(where: { $0.id == playerID }), players[index].teamID == selectedClubID else { return }
        players[index].morale = max(0, players[index].morale - 5)
        recordMemory(playerID: playerID, kind: .requestIgnored, id: "followup-ignored-\(commitment.id)")
        let name = players[index].name
        let factID = "followup-expired-\(commitment.id)"
        recordFact(WorldFact(id: factID, source: .crisis, worldDay: worldDay, title: "\(name) fica sem resposta",
                             detail: "A conversa prometida não aconteceu. Moral -5.", playerIDs: [playerID]))
        deliverFact(factID, inbox: .general)
        if players[index].morale < 40, !hasOpenMessage(.playerWantsOut, playerID: playerID) {
            addInbox(.playerWantsOut, title: "\(name) quer sair", body: "Sem retorno depois da promessa quebrada, \(name) pediu para ser negociado.", playerID: playerID)
        }
    }
}

// MARK: - Calendário

extension FootballCareer {
    /// Processa o que vence ao avançar o calendário, na ordem de `calendarProcessingOrder`.
    /// Eventos, ofertas, promessas e contratos já são tratados antes, no próprio dia de jogo; aqui entram compromissos e conversas.
    @discardableResult
    mutating func processDueItems() -> [CalendarStep] {
        cancelOrphanedCommitments()
        var ran: [CalendarStep] = []
        for step in Self.calendarProcessingOrder {
            switch step {
            case .commitments:
                advanceArcs()
                expireDueCommitments()
                maybeStartRumorArc()
                ran.append(step)
            case .negotiations:
                expireStaleTalks()
                ran.append(step)
            default:
                break
            }
        }
        return ran
    }
}

extension FootballCareer {
    /// Atleta vendido, emprestado, dispensado, aposentado ou de contrato encerrado, ou troca de clube: as conversas e os
    /// compromissos pessoais dele deixam de fazer sentido e são cancelados sem cobrança (F6: nada de compromisso órfão).
    mutating func cancelOrphanedCommitments() {
        let clubID = selectedClubID
        for index in talks.indices where talks[index].stage.isOpen && player(talks[index].playerID)?.teamID != clubID {
            talks[index].stage = .expired
            if let commitment = talks[index].commitmentID { resolveCommitment(id: commitment, as: .cancelled) }
        }
        for index in arcs.indices where arcs[index].isOpen {
            guard let id = arcs[index].playerID, player(id)?.teamID != clubID else { continue }
            arcs[index].stage = .ended
            arcs[index].outcome = "O atleta deixou o clube; o arco foi encerrado."
            arcs[index].steps.append(ArcStep(id: arcs[index].steps.count, worldDay: worldDay, kind: .outcome, text: "O atleta deixou o clube; o arco foi encerrado."))
            if let commitment = arcs[index].commitmentID { resolveCommitment(id: commitment, as: .cancelled) }
        }
        for item in commitments where item.state == .open && (item.kind == .followUp || item.kind == .negotiationCounter) {
            guard let id = item.playerID, player(id)?.teamID != clubID else { continue }
            resolveCommitment(id: item.id, as: .cancelled)
        }
    }
}
