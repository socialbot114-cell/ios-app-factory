import Foundation

// MARK: - Conversas e anexos de Mensagens (MSG-01, MSG-05, MSG-06)

/// Mensagens agrupadas por pessoa (atleta) ou por assunto, com o que está em aberto.
struct Conversation: Identifiable, Equatable {
    let id: String
    let title: String
    let playerID: Int?
    /// Do mais novo para o mais antigo.
    let messageIDs: [Int]
    let unread: Int
    let open: Int
    let lastSeason: Int
    let lastMatchDay: Int
}

enum MessageAttachment: Equatable, Identifiable {
    case playerSheet(Int)
    case lineup(Int)
    case offer(Int)
    case contract(Int)
    case commitment(Int)
    case fact(String)
    case contact(ContactRole)

    var id: String {
        switch self {
        case .playerSheet(let id): return "sheet-\(id)"
        case .lineup(let id): return "lineup-\(id)"
        case .offer(let id): return "offer-\(id)"
        case .contract(let id): return "contract-\(id)"
        case .commitment(let id): return "commitment-\(id)"
        case .fact(let id): return "fact-\(id)"
        case .contact(let role): return "contact-\(role.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .playerSheet: return "Ficha"
        case .lineup: return "Escalação"
        case .offer: return "Proposta"
        case .contract: return "Contrato"
        case .commitment: return "Compromisso"
        case .fact: return "Origem"
        case .contact: return "Contato"
        }
    }

    var symbol: String {
        switch self {
        case .playerSheet: return "person.text.rectangle"
        case .lineup: return "list.number"
        case .offer: return "envelope.badge.fill"
        case .contract: return "signature"
        case .commitment: return "calendar.badge.clock"
        case .fact: return "doc.text.magnifyingglass"
        case .contact: return "person.crop.circle.badge.questionmark"
        }
    }
}

extension InboxKind {
    var conversationTitle: String {
        switch self {
        case .playerPlayingTime, .playerContract, .playerWantsOut: return "Atletas"
        case .offer, .transfer: return "Mercado"
        case .scouting: return "Observação"
        case .injury: return "Departamento médico"
        case .board: return "Diretoria"
        case .finance: return "Finanças"
        case .staff: return "Comissão técnica"
        case .news: return "Notícias"
        case .press: return "Imprensa"
        case .general: return "Avisos"
        case .event: return "Acontecimentos"
        case .social: return "Chuteira"
        case .agent: return "Empresário"
        case .bet: return "Palpite+"
        }
    }
}

extension FootballCareer {
    /// Agrupa as mensagens visíveis por atleta (uma conversa por pessoa) ou, sem pessoa, por assunto. Dispensadas ficam de fora.
    func conversations() -> [Conversation] {
        var groups: [String: [InboxMessage]] = [:]
        for message in inbox where message.isDismissed != true {
            let key = message.playerID.map { "player-\($0)" } ?? "kind-\(message.kind.rawValue)"
            groups[key, default: []].append(message)
        }
        return groups.map { key, messages in
            let ordered = messages.sorted { $0.id > $1.id }
            let playerID = ordered.first?.playerID
            let title = playerID.flatMap { player($0)?.name } ?? (ordered.first?.kind.conversationTitle ?? "Mensagens")
            return Conversation(id: key, title: title, playerID: playerID, messageIDs: ordered.map(\.id),
                                unread: ordered.filter { !$0.isRead }.count,
                                open: ordered.filter { $0.kind.needsResponse && !$0.isResolved }.count,
                                lastSeason: ordered[0].season, lastMatchDay: ordered[0].matchDay)
        }.sorted { ($0.messageIDs.first ?? 0) != ($1.messageIDs.first ?? 0) ? ($0.messageIDs.first ?? 0) > ($1.messageIDs.first ?? 0) : $0.id < $1.id }
    }

    /// Lê todas as mensagens da conversa, sem resolver nada.
    mutating func markConversationRead(_ conversationID: String) {
        for index in inbox.indices {
            let key = inbox[index].playerID.map { "player-\($0)" } ?? "kind-\(inbox[index].kind.rawValue)"
            if key == conversationID { inbox[index].isRead = true }
        }
    }

    /// Anexos consultáveis de uma mensagem: ficha, escalação, proposta, contrato, compromisso e o fato de origem.
    func attachments(for message: InboxMessage) -> [MessageAttachment] {
        var result: [MessageAttachment] = []
        if let id = message.playerID, let athlete = player(id) {
            result.append(.playerSheet(id))
            if athlete.teamID == selectedClubID, message.kind == .playerPlayingTime || message.sourcePromiseID != nil { result.append(.lineup(id)) }
            if athlete.teamID == selectedClubID, message.kind == .playerContract { result.append(.contract(id)) }
        }
        if let offerID = message.offerID, offers.contains(where: { $0.id == offerID }) { result.append(.offer(offerID)) }
        if let promiseID = message.sourcePromiseID, let commitment = commitments.first(where: { $0.factID == "followup-promise-\(promiseID)" }) {
            result.append(.commitment(commitment.id))
        }
        if let factID = message.sourceFactID, fact(factID) != nil { result.append(.fact(factID)) }
        if message.kind == .agent { result.append(.contact(.agent)) }
        return result
    }
}

// MARK: - Respostas contextuais e conversas marcadas (MSG-04)

extension FootballCareer {
    /// Responde a um pedido do atleta marcando uma conversa: o pedido fica respondido, a conversa entra na agenda e,
    /// se não acontecer a tempo, o atleta se irrita (mesmo desfecho de qualquer conversa prometida e esquecida).
    @discardableResult
    mutating func replyWithMeeting(playerID: Int, days: Int = 2) -> Commitment? {
        guard selectedClubID != nil, !isFired, liveMatch == nil, let index = players.firstIndex(where: { $0.id == playerID }),
              players[index].teamID == selectedClubID,
              hasOpenMessage(.playerPlayingTime, playerID: playerID) || hasOpenMessage(.playerWantsOut, playerID: playerID),
              !commitments.contains(where: { $0.kind == .followUp && $0.state == .open && $0.playerID == playerID }) else { return nil }
        let name = players[index].name
        players[index].morale = min(100, players[index].morale + 2)
        let factID = "meeting-request-\(playerID)-\(worldDay)"
        recordFact(WorldFact(id: factID, source: .request, worldDay: worldDay, title: "Conversa marcada com \(name)",
                             detail: "Você prometeu conversar com \(name) em até \(days + 1) dias de jogo. Moral +2 por ouvir o pedido.", playerIDs: [playerID],
                             effects: ["Moral +2"], nextEvents: ["Se a conversa não acontecer a tempo, o atleta se irrita."]))
        let commitment = openCommitment(kind: .followUp, playerID: playerID, factID: factID, days: days + 1,
                                        title: "Conversa prometida com \(name)", detail: "Pedido de minutos respondido com uma conversa marcada.")
        recordPlayerReply(playerID: playerID, text: "Vamos conversar em \(days) dias de jogo.", kinds: [.playerPlayingTime, .playerWantsOut])
        deliverFact(factID, inbox: .general)
        return commitment
    }

    /// Conversa marcada ainda aberta que originou a mensagem (para o botão "Ter a conversa").
    func openMeetingCommitment(for message: InboxMessage) -> Commitment? {
        guard let factID = message.sourceFactID else { return nil }
        return commitments.first { $0.kind == .followUp && $0.state == .open && $0.factID == factID }
    }
}
