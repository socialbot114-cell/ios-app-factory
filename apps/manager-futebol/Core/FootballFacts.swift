import Foundation

// MARK: - Fatos do mundo (F1-01)

enum FactSource: String, Codable, Equatable {
    case promise, request, match, press, market, crisis, negotiation
}

enum FactReliability: String, Codable, Equatable {
    case confirmed, rumor

    var label: String { self == .confirmed ? "confirmado" : "boato" }
}

/// Algo que aconteceu no mundo e pode aparecer em vários lugares (Mensagens, Notificações, Chuteira) com o mesmo ID.
struct WorldFact: Codable, Equatable, Identifiable {
    let id: String
    let source: FactSource
    let worldDay: Int
    var title: String
    var detail: String
    var playerIDs: [Int] = []
    var clubIDs: [Int] = []
    var reliability: FactReliability = .confirmed
    var isPublic = false
    /// Resultado de uma decisão (F1-02): o que foi aplicado, que compromissos nasceram e o que pode acontecer depois.
    var effects: [String]? = nil
    var commitmentIDs: [Int]? = nil
    var nextEvents: [String]? = nil
    /// Snapshot técnico separado das frases de efeitos exibidas ao jogador.
    var fantasySnapshot: FantasyRoundDetail? = nil
}

struct FactStore: Codable, Equatable {
    var facts: [WorldFact] = []
    /// Retenção (F1-07): os fatos mais antigos saem primeiro para o save não crescer sem fim.
    static let limit = 150
}

/// Estados de leitura que não se confundem (F1-06): lida, resolvida e dispensada são coisas diferentes.
enum MessageState: String, Equatable {
    /// `answered`: o treinador respondeu. `resolved`: encerrada sem resposta própria. `expired`: o prazo passou sem resposta.
    case unread, read, answered, resolved, expired, dismissed

    var title: String {
        switch self {
        case .unread: return "NOVA"
        case .read: return "LIDA"
        case .answered: return "RESPONDIDA"
        case .resolved: return "RESOLVIDA"
        case .expired: return "SEM RESPOSTA"
        case .dismissed: return "DISPENSADA"
        }
    }
}

extension FootballCareer {
    func fact(_ id: String) -> WorldFact? { factStore.facts.first { $0.id == id } }

    /// Registra um fato uma única vez. Repetir o mesmo comando não duplica nada.
    @discardableResult
    mutating func recordFact(_ fact: WorldFact) -> Bool {
        guard !factStore.facts.contains(where: { $0.id == fact.id }) else { return false }
        factStore.facts.append(fact)
        if factStore.facts.count > FactStore.limit { factStore.facts.removeFirst(factStore.facts.count - FactStore.limit) }
        return true
    }

    /// Leva o fato a Mensagens/Notificações (mesma mensagem) e, se pedido, à Chuteira. Cada canal recebe o fato uma única vez.
    @discardableResult
    mutating func deliverFact(_ factID: String, inbox kind: InboxKind = .news, social: Bool = false) -> (inbox: Bool, social: Bool) {
        guard let fact = fact(factID) else { return (false, false) }
        var deliveredInbox = false
        if !inbox.contains(where: { $0.sourceFactID == factID && $0.kind == kind }) {
            addInbox(kind, title: fact.title, body: fact.detail, playerID: fact.playerIDs.first)
            inbox[inbox.count - 1].sourceFactID = factID
            deliveredInbox = true
        }
        var deliveredSocial = false
        if social, !world.social.posts.contains(where: { $0.sourceFactID == factID }) {
            let names = Self.journalistNames
            let hash = factID.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 9_973 }
            let author: SocialAuthor = fact.reliability == .confirmed ? .journalist : .fan
            let name = author == .journalist ? names[hash % names.count] : "Torcedor anônimo"
            let handle = "@" + name.lowercased().folding(options: .diacriticInsensitive, locale: nil).filter { $0.isLetter || $0.isNumber }
            var post = SocialPost(id: world.social.nextPostID, season: season, matchDay: matchDayIndex, author: author, name: name, handle: handle,
                                  text: "\(fact.title) · \(fact.reliability.label). \(fact.detail)", likes: 150 + hash % 600, shares: 20 + hash % 80,
                                  replies: 10 + hash % 60, sentiment: fact.reliability == .confirmed ? -1 : 0)
            post.sourceFactID = factID
            post.profileID = profileID(forName: name)
            post.reliability = fact.reliability.rawValue
            world.social.nextPostID += 1
            world.social.posts.insert(post, at: 0)
            if world.social.posts.count > Self.socialPostLimit { world.social.posts.removeLast(world.social.posts.count - Self.socialPostLimit) }
            deliveredSocial = true
        }
        return (deliveredInbox, deliveredSocial)
    }

    // MARK: Leitura, resolução e dispensa

    func messageState(_ message: InboxMessage) -> MessageState {
        if message.isDismissed == true { return .dismissed }
        if message.isResolved { return message.coachReply != nil ? .answered : .resolved }
        if message.coachReply != nil { return .expired }
        return message.isRead ? .read : .unread
    }

    /// Dispensar esconde um aviso sem resolver nada. Mensagens que exigem resposta só podem ser dispensadas depois de resolvidas.
    @discardableResult
    mutating func dismissMessage(id: Int) -> Bool {
        guard let index = inbox.firstIndex(where: { $0.id == id }), inbox[index].isDismissed != true else { return false }
        if inbox[index].kind.needsResponse && !inbox[index].isResolved { return false }
        inbox[index].isDismissed = true
        inbox[index].isRead = true
        return true
    }
}
