import Foundation

// MARK: - Mensagens estilo chat: jogadores, comissão técnica, família e clube

enum ChatGroup: String, CaseIterable, Identifiable {
    case all, players, staff, family, club

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todas"
        case .players: return "Jogadores"
        case .staff: return "Comissão"
        case .family: return "Família"
        case .club: return "Clube"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "bubble.left.and.bubble.right.fill"
        case .players: return "figure.soccer"
        case .staff: return "person.2.fill"
        case .family: return "house.fill"
        case .club: return "building.columns.fill"
        }
    }
}

/// Mensagem livre trocada no chat (as do sistema continuam na caixa de entrada).
struct ChatLogEntry: Codable, Equatable, Identifiable {
    let id: Int
    let threadID: String
    let fromCoach: Bool
    let text: String
    let season: Int
    let matchDay: Int
    /// Mensagem recebida que ainda não foi aberta; opcional para saves antigos.
    var unread: Bool? = nil
}

struct ChatState: Codable, Equatable {
    static let logLimit = 300
    var log: [ChatLogEntry] = []
    var nextID = 1
    /// Último dia de jogo em que cada conversa recebeu uma mensagem rápida.
    var lastQuickDay: [String: Int] = [:]
}

struct ChatThread: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let group: ChatGroup
    let symbol: String
    var playerID: Int? = nil
    var contactRole: ContactRole? = nil
    var staffRole: StaffRole? = nil
    var unread = 0
    var open = 0
    var preview = ""
    /// Maior = mais recente.
    var order = 0
}

struct ChatBubble: Identifiable, Equatable {
    let id: String
    let fromCoach: Bool
    let text: String
    /// Assunto da mensagem do sistema (título), quando houver.
    var header: String? = nil
    let season: Int
    let matchDay: Int
    var messageID: Int? = nil
    var rank = 0
    var seq = 0
}

struct ChatQuickMessage: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
}

extension FootballCareer {
    private var chatState: ChatState { world.phone.chat ?? ChatState() }

    private static func chatHash(_ text: String) -> Int {
        text.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) % 1_000_003 }
    }

    private func chatPick(_ options: [String], salt: String) -> String {
        options[(abs(worldDay) &+ Self.chatHash(salt)) % options.count]
    }

    private func chatOrder(season: Int, matchDay: Int, rank: Int = 0) -> Int { season * 100_000 + matchDay * 100 + rank }

    private func chatGroup(for kind: InboxKind, playerID: Int?) -> ChatGroup {
        if let playerID, let athlete = player(playerID), athlete.teamID == selectedClubID { return .players }
        switch kind {
        case .playerPlayingTime, .playerContract, .playerWantsOut: return .players
        case .injury, .staff: return .staff
        default: return .club
        }
    }

    // MARK: Conversas

    func chatThreads() -> [ChatThread] {
        var threads: [String: ChatThread] = [:]

        for conversation in conversations() {
            let newest = conversation.messageIDs.first.flatMap { id in inbox.first { $0.id == id } }
            let kind = newest?.kind ?? .general
            var thread = ChatThread(id: conversation.id, title: conversation.title,
                                    subtitle: conversation.playerID.flatMap { player($0)?.position.title } ?? "Aviso do sistema",
                                    group: chatGroup(for: kind, playerID: conversation.playerID),
                                    symbol: conversation.playerID == nil ? kind.symbol : "figure.soccer",
                                    playerID: conversation.playerID)
            thread.unread = kind.isPassive ? 0 : conversation.unread
            thread.open = conversation.open
            thread.preview = newest?.title ?? ""
            thread.order = chatOrder(season: conversation.lastSeason, matchDay: conversation.lastMatchDay)
            threads[thread.id] = thread
        }

        for contact in world.contacts.contacts {
            let id = "contact-\(contact.role.rawValue)"
            var thread = ChatThread(id: id, title: contact.name, subtitle: contact.role.title,
                                    group: contact.role == .family || contact.role == .friend ? .family : .club,
                                    symbol: contact.role.symbol, contactRole: contact.role)
            thread.open = openContactRequests(contact.id).count
            thread.preview = thread.open > 0 ? "Pediu sua atenção" : contact.role.perk
            thread.order = chatOrder(season: season, matchDay: matchDayIndex, rank: -1)
            threads[id] = thread
        }

        for member in staff {
            let id = "staff-\(member.role.rawValue)"
            var thread = ChatThread(id: id, title: member.name, subtitle: member.role.title, group: .staff,
                                    symbol: member.role.symbol, staffRole: member.role)
            thread.preview = "Toque para conversar"
            thread.order = chatOrder(season: season, matchDay: matchDayIndex, rank: -2)
            threads[id] = thread
        }

        // Quem só tem mensagens livres (ex.: um atleta que você procurou) também aparece.
        for entry in chatState.log where threads[entry.threadID] == nil && entry.threadID.hasPrefix("player-") {
            guard let id = Int(entry.threadID.dropFirst("player-".count)), let athlete = player(id) else { continue }
            threads[entry.threadID] = ChatThread(id: entry.threadID, title: athlete.name, subtitle: athlete.position.title, group: .players,
                                                 symbol: "figure.soccer", playerID: id)
        }

        // Última mensagem livre de cada conversa define a prévia e a ordem.
        for entry in chatState.log {
            guard var thread = threads[entry.threadID] else { continue }
            if entry.unread == true { thread.unread += 1; threads[entry.threadID] = thread }
            let order = chatOrder(season: entry.season, matchDay: entry.matchDay, rank: 50 + entry.id % 40)
            if order >= thread.order {
                thread.order = order
                thread.preview = (entry.fromCoach ? "Você: " : "") + entry.text
                threads[entry.threadID] = thread
            }
        }

        return threads.values.sorted { $0.order != $1.order ? $0.order > $1.order : $0.id < $1.id }
    }

    /// Conversa pelo id; um atleta sem mensagens ainda tem conversa (a lista só mostra quem já trocou mensagens).
    func chatThread(_ id: String) -> ChatThread? {
        if let found = chatThreads().first(where: { $0.id == id }) { return found }
        guard id.hasPrefix("player-"), let playerID = Int(id.dropFirst("player-".count)), let athlete = player(playerID) else { return nil }
        return ChatThread(id: id, title: athlete.name, subtitle: athlete.position.title,
                          group: athlete.teamID == selectedClubID ? .players : .club, symbol: "figure.soccer", playerID: playerID)
    }

    /// Thread que contém uma mensagem do sistema (para abrir direto pela notificação).
    func chatThreadID(forMessage id: Int) -> String? {
        guard let message = inbox.first(where: { $0.id == id }) else { return nil }
        return message.playerID.map { "player-\($0)" } ?? "kind-\(message.kind.rawValue)"
    }

    var chatUnreadCount: Int { chatThreads().reduce(0) { $0 + $1.unread } }

    /// Mensagens novas no app Mensagens: avisos do sistema que importam mais as mensagens livres de pessoas.
    var unreadMessageBadge: Int { unreadCount + (chatState.log.filter { $0.unread == true }.count) }

    /// Abre a conversa: as mensagens livres dela passam a lidas.
    mutating func markChatRead(_ threadID: String) {
        guard var state = world.phone.chat, state.log.contains(where: { $0.threadID == threadID && $0.unread == true }) else { return }
        for index in state.log.indices where state.log[index].threadID == threadID { state.log[index].unread = nil }
        world.phone.chat = state
    }

    /// "Marcar tudo como lido": caixa de entrada e mensagens livres.
    mutating func markAllChatsRead() {
        markInboxRead()
        guard var state = world.phone.chat else { return }
        for index in state.log.indices { state.log[index].unread = nil }
        world.phone.chat = state
    }

    // MARK: Balões

    func chatBubbles(threadID: String) -> [ChatBubble] {
        var bubbles: [ChatBubble] = []
        for message in inbox where message.isDismissed != true {
            let key = message.playerID.map { "player-\($0)" } ?? "kind-\(message.kind.rawValue)"
            guard key == threadID else { continue }
            bubbles.append(ChatBubble(id: "msg-\(message.id)", fromCoach: false, text: message.body, header: message.title,
                                      season: message.season, matchDay: message.matchDay, messageID: message.id, rank: 0, seq: message.id))
            if let reply = message.coachReply {
                bubbles.append(ChatBubble(id: "reply-\(message.id)", fromCoach: true, text: reply, season: message.season,
                                          matchDay: message.matchDay, rank: 1, seq: message.id))
            }
        }
        for entry in chatState.log where entry.threadID == threadID {
            bubbles.append(ChatBubble(id: "log-\(entry.id)", fromCoach: entry.fromCoach, text: entry.text, season: entry.season,
                                      matchDay: entry.matchDay, rank: 2, seq: entry.id))
        }
        return bubbles.sorted {
            if $0.season != $1.season { return $0.season < $1.season }
            if $0.matchDay != $1.matchDay { return $0.matchDay < $1.matchDay }
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.seq < $1.seq
        }
    }

    // MARK: Mensagens rápidas

    func chatQuickMessages(for thread: ChatThread) -> [ChatQuickMessage] {
        if thread.staffRole != nil {
            return [ChatQuickMessage(id: "report", title: "Pedir relatório", symbol: "doc.text.fill"),
                    ChatQuickMessage(id: "advice", title: "O que fazer agora?", symbol: "sparkles")]
        }
        if let role = thread.contactRole {
            switch role {
            case .family: return [ChatQuickMessage(id: "care", title: "Mandar carinho", symbol: "heart.fill"),
                                  ChatQuickMessage(id: "news", title: "Contar do jogo", symbol: "sportscourt.fill")]
            case .friend: return [ChatQuickMessage(id: "care", title: "Chamar pra conversar", symbol: "face.smiling.fill")]
            default: return [ChatQuickMessage(id: "greet", title: "Mandar um oi", symbol: "hand.wave.fill")]
            }
        }
        if let playerID = thread.playerID, let athlete = player(playerID), athlete.teamID == selectedClubID {
            return [ChatQuickMessage(id: "praise", title: "Elogiar", symbol: "hand.thumbsup.fill"),
                    ChatQuickMessage(id: "push", title: "Cobrar mais", symbol: "flame.fill"),
                    ChatQuickMessage(id: "check", title: "Como você está?", symbol: "heart.text.square.fill")]
        }
        return []
    }

    func chatQuickBlocker(_ thread: ChatThread) -> String? {
        guard liveMatch == nil else { return "Com a partida em andamento, o celular fica no bolso." }
        if chatState.lastQuickDay[thread.id] == worldDay { return "Uma mensagem por dia de jogo nesta conversa." }
        if world.coach.energy < 2 { return "Sem energia para conversar. Descanse." }
        return nil
    }

    mutating func appendChat(_ threadID: String, fromCoach: Bool, _ text: String, unread: Bool = false) {
        var state = chatState
        state.log.append(ChatLogEntry(id: state.nextID, threadID: threadID, fromCoach: fromCoach, text: text, season: season, matchDay: matchDayIndex,
                                      unread: unread ? true : nil))
        state.nextID += 1
        if state.log.count > ChatState.logLimit { state.log.removeFirst(state.log.count - ChatState.logLimit) }
        world.phone.chat = state
    }

    /// Envia uma mensagem rápida e devolve a resposta (já registrada no chat). nil se não puder.
    @discardableResult
    mutating func sendChatQuick(threadID: String, quickID: String) -> String? {
        guard let thread = chatThread(threadID), chatQuickBlocker(thread) == nil,
              let quick = chatQuickMessages(for: thread).first(where: { $0.id == quickID }) else { return nil }
        var sent = quick.title
        var reply: String

        if let role = thread.staffRole {
            sent = quickID == "advice" ? "O que eu devo fazer agora?" : "Pode me passar um relatório?"
            reply = quickID == "advice" ? staffAdvice() : staffReport(role)
        } else if let role = thread.contactRole, let index = world.contacts.contacts.firstIndex(where: { $0.role == role }) {
            var gain = 1
            switch (role, quickID) {
            case (.family, "care"):
                sent = "Saudade de vocês. Já já passo em casa."
                gain = 2
                world.coach.stress = max(0, world.coach.stress - 3)
                reply = chatPick(["Estamos orgulhosos de você! Se cuida.", "A casa está te esperando. Come direito!", "Boa sorte no próximo jogo, filho(a)."], salt: thread.id)
            case (.family, _):
                sent = "Ganhamos? Perdemos? Deixa eu contar como foi o jogo."
                reply = latestUserFixture.map { "Vimos o resultado de \($0.title). Seja qual for, a gente está contigo." } ?? "Ainda nem começou, mas a torcida aqui é a maior!"
            case (.friend, _):
                sent = "E aí, bora marcar um churrasco?"
                world.coach.stress = max(0, world.coach.stress - 2)
                reply = chatPick(["Bora! Leva o carvão que eu levo a cerveja (sem álcool, treinador!).", "Só avisa o dia. Tô dentro."], salt: thread.id)
            default:
                sent = "Oi! Passando para dar um alô."
                reply = chatPick(["Bom ouvir você. Qualquer coisa, é só chamar.", "Sempre à disposição, treinador."], salt: thread.id)
            }
            world.contacts.contacts[index].relationship = min(100, world.contacts.contacts[index].relationship + gain)
            world.contacts.contacts[index].lastContactWorldDay = worldDay
        } else if let playerID = thread.playerID, let index = players.firstIndex(where: { $0.id == playerID }) {
            let name = players[index].name.split(separator: " ").first.map(String.init) ?? players[index].name
            switch quickID {
            case "praise":
                players[index].morale = min(100, players[index].morale + 3)
                sent = "\(name), seu trabalho nos treinos está muito bom. Continue assim."
                reply = chatPick(["Valeu, professor! Isso me dá confiança.", "Obrigado, mister. Vou dar o sangue.", "Fico feliz em ouvir isso. Pode contar comigo."], salt: thread.id)
            case "push":
                players[index].morale = max(0, players[index].morale - 2)
                sent = "\(name), preciso de mais intensidade. Você pode muito mais."
                reply = chatPick(["Entendido, professor. Vou render mais.", "Tá certo, mister. Vou mostrar em campo.", "Recebi o recado. Vou me cobrar mais."], salt: thread.id)
            default:
                sent = "Como você está, \(name)?"
                let athlete = players[index]
                var text = "Estou com \(athlete.condition)% de condição"
                text += athlete.morale >= 70 ? " e muito motivado." : (athlete.morale >= 45 ? " e tranquilo." : " mas meio desanimado.")
                if !athlete.isAvailable(matchDay: matchDayIndex) { text += " O departamento médico ainda me segura." }
                reply = text
            }
        } else {
            return nil
        }

        world.coach.energy = max(0, world.coach.energy - 1)
        var state = chatState
        state.lastQuickDay[thread.id] = worldDay
        world.phone.chat = state
        appendChat(thread.id, fromCoach: true, sent)
        appendChat(thread.id, fromCoach: false, reply)
        bump("chat")
        return reply
    }

    // MARK: Respostas da comissão

    private func staffAdvice() -> String {
        if let top = suggestions().first { return "\(top.title). \(top.detail)" }
        return "Está tudo em ordem. Foque no próximo jogo."
    }

    private func staffReport(_ role: StaffRole) -> String {
        let senior = clubRoster.filter { !$0.isYouth }
        switch role {
        case .doctor:
            let out = senior.filter { !$0.isAvailable(matchDay: matchDayIndex) }
            if out.isEmpty { return "Nenhum atleta no departamento médico. Elenco 100% disponível." }
            return "\(out.count) no departamento médico: \(out.prefix(3).map(\.name).joined(separator: ", "))."
        case .fitnessCoach:
            let average = senior.isEmpty ? 0 : senior.map(\.condition).reduce(0, +) / senior.count
            let tired = senior.filter { $0.condition < 60 }.count
            return "Condição média do elenco: \(average)%. \(tired == 0 ? "Ninguém no vermelho." : "\(tired) atleta(s) abaixo de 60%.")"
        case .assistant:
            if let fixture = nextUserFixture, let id = selectedClubID {
                return "Próximo jogo: \(FootballSeason.teamName(fixture.opponent(of: id))). Já preparei o material do rival."
            }
            return "Sem jogo do nosso clube hoje. Bom dia para treinar."
        case .headScout:
            return "Sigo de olho em \(runningStaffTasks.count) tarefa(s) e no mercado. Abra Transfer para ver os alvos."
        case .goalkeeperCoach:
            if let keeper = senior.filter({ $0.position == .goalkeeper }).max(by: { $0.overall < $1.overall }) {
                return "\(keeper.name) é nosso goleiro de maior nota (\(keeper.overall)), com \(keeper.condition)% de condição."
            }
            return "Estamos sem goleiros no elenco. Precisamos contratar."
        case .youthCoach:
            let youth = players.filter { $0.teamID == selectedClubID && $0.isYouth }.count
            return "Temos \(youth) jovem(ns) na base. Os melhores já pedem passagem."
        case .analyst:
            return "Estamos no \(formation.rawValue). Os números mostram que dá para crescer na posse de bola."
        }
    }
}

extension InboxKind {
    /// Notícias e palpites informam, não pedem nada: não contam como "não lidas" no ícone do app.
    var isPassive: Bool { self == .news || self == .bet }
}
