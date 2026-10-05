import Foundation

// MARK: - Relações com contatos: assuntos, histórico, pedidos e continuidade (CON-02…06)

/// Assunto de conversa. Cada contato oferece os seus, conforme o momento da carreira.
enum ContactTopic: String, Codable, CaseIterable, Identifiable {
    case agentLunch, agentScout
    case journalistExclusive, journalistDenyRumor, journalistOffRecord
    case presidentDinner, presidentBudget, presidentReport
    case mentorAdvice, mentorCareer
    case familyDay, familyPromise
    case friendBarbecue, friendVent

    var id: String { rawValue }

    var role: ContactRole {
        switch self {
        case .agentLunch, .agentScout: return .agent
        case .journalistExclusive, .journalistDenyRumor, .journalistOffRecord: return .journalist
        case .presidentDinner, .presidentBudget, .presidentReport: return .president
        case .mentorAdvice, .mentorCareer: return .mentor
        case .familyDay, .familyPromise: return .family
        case .friendBarbecue, .friendVent: return .friend
        }
    }

    var title: String {
        switch self {
        case .agentLunch: return "Almoço de relacionamento"
        case .agentScout: return "Pedir indicação de atleta"
        case .journalistExclusive: return "Dar uma exclusiva"
        case .journalistDenyRumor: return "Desmentir um boato"
        case .journalistOffRecord: return "Conversa em off sobre a polêmica"
        case .presidentDinner: return "Jantar com o presidente"
        case .presidentBudget: return "Defender um pedido de verba"
        case .presidentReport: return "Prestar contas das finanças"
        case .mentorAdvice: return "Pedir um conselho"
        case .mentorCareer: return "Conversar sobre propostas de trabalho"
        case .familyDay: return "Passar o dia com a família"
        case .familyPromise: return "Prometer um dia de folga"
        case .friendBarbecue: return "Churrasco com o amigo"
        case .friendVent: return "Desabafar"
        }
    }

    /// O assunto genérico de cada papel, que mantém a ação antiga.
    static func social(for role: ContactRole) -> ContactTopic {
        switch role {
        case .agent: return .agentLunch
        case .journalist: return .journalistExclusive
        case .president: return .presidentDinner
        case .mentor: return .mentorAdvice
        case .family: return .familyDay
        case .friend: return .friendBarbecue
        }
    }
}

struct ContactMemoryEntry: Codable, Equatable, Identifiable {
    let id: Int
    let contactID: Int
    let worldDay: Int
    let title: String
    let summary: String
    let delta: Int
}

/// Pedido ou oportunidade trazida pelo contato (CON-04), ou promessa feita a ele.
struct ContactRequest: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case agentOpportunity, journalistInterview, presidentEvent, friendLoan, familyEvent, mentorLecture, familyPromise
    }
    enum Status: String, Codable { case open, accepted, declined, ignored, fulfilled, broken }

    let id: Int
    let contactID: Int
    let kind: Kind
    let createdWorldDay: Int
    let deadlineWorldDay: Int
    var status: Status = .open
    var playerID: Int? = nil
    var amount = 0
    /// Dia combinado (evento da família, folga prometida).
    var eventWorldDay: Int? = nil

    var isOpen: Bool { status == .open || status == .accepted }
}

struct ContactRelationsState: Codable, Equatable {
    var history: [ContactMemoryEntry] = []
    var requests: [ContactRequest] = []
    var nextID = 1

    init() {}

    private enum CodingKeys: String, CodingKey { case history, requests, nextID }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        history = try container.decodeIfPresent([ContactMemoryEntry].self, forKey: .history) ?? []
        requests = try container.decodeIfPresent([ContactRequest].self, forKey: .requests) ?? []
        nextID = try container.decodeIfPresent(Int.self, forKey: .nextID) ?? 1
    }
}

extension FootballCareer {
    static let contactHistoryLimit = 40
    static let contactRequestDays = 3

    private var relations: ContactRelationsState {
        get { world.projects.contactRelations }
        set { world.projects.contactRelations = newValue }
    }

    func contactHistory(_ contactID: Int) -> [ContactMemoryEntry] { relations.history.filter { $0.contactID == contactID } }
    func openContactRequests(_ contactID: Int? = nil) -> [ContactRequest] {
        relations.requests.filter { $0.status == .open && (contactID == nil || $0.contactID == contactID) }
    }
    func pendingContactPromises(_ contactID: Int) -> [ContactRequest] {
        relations.requests.filter { $0.contactID == contactID && $0.status == .accepted }
    }

    /// Interesses estáveis de cada pessoa (CON-02): não mudam de uma conversa para outra.
    func contactInterests(_ contact: Contact) -> [String] {
        let pools: [ContactRole: [String]] = [
            .agent: ["jovens talentos", "comissões", "atletas experientes", "mercado europeu"],
            .journalist: ["exclusivas", "bastidores", "táticas", "polêmicas"],
            .president: ["finanças em dia", "títulos", "categorias de base", "estádio cheio"],
            .mentor: ["formação de treinadores", "disciplina", "jogo ofensivo"],
            .family: ["presença em casa", "datas especiais", "tranquilidade"],
            .friend: ["futebol de várzea", "churrasco", "conversa franca"]
        ]
        let pool = pools[contact.role] ?? []
        guard pool.count >= 2 else { return pool }
        let first = (contact.id &* 7 &+ contact.name.count) % pool.count
        let second = (first + 1 + contact.name.count % (pool.count - 1)) % pool.count
        return [pool[first], pool[second]]
    }

    // MARK: Conversas contextuais (CON-03)

    func availableTopics(for role: ContactRole) -> [ContactTopic] { ContactTopic.allCases.filter { $0.role == role } }

    /// Motivo para o assunto não estar disponível agora; nil quando pode conversar.
    func topicBlocker(_ topic: ContactTopic) -> String? {
        if let reason = canContact(topic.role) { return reason }
        switch topic {
        case .agentScout:
            if recruitmentBriefs.isEmpty { return "Crie um briefing no Mercado para o empresário saber o que buscar." }
            if agentSuggestion() == nil { return "O empresário não conhece ninguém para o seu briefing agora." }
        case .journalistDenyRumor:
            if latestRumor() == nil { return "Não há boato recente sobre o clube." }
        case .journalistOffRecord:
            if world.social.controversy < 30 { return "Não há polêmica para acalmar." }
        case .presidentBudget:
            if let reason = boardMeetingBlocker(.budgetBoost) { return reason }
        case .presidentReport:
            if boardConfidence >= 70 { return "A diretoria já está tranquila com as finanças." }
        case .mentorCareer:
            if invitations.isEmpty && jobOffers.isEmpty { return "Não há proposta de trabalho para discutir." }
        case .familyPromise:
            if familyPromiseDay() == nil { return "Não há dia livre nos próximos jogos para prometer folga." }
            if relations.requests.contains(where: { $0.kind == .familyPromise && $0.status == .accepted }) { return "Já há uma folga prometida." }
        case .friendVent:
            if world.coach.stress < 50 { return "Você não está precisando desabafar." }
        default:
            break
        }
        return nil
    }

    /// Conversa sobre um assunto. Uma conversa por dia de jogo, como antes.
    @discardableResult
    mutating func talk(_ topic: ContactTopic) -> String? {
        guard topicBlocker(topic) == nil, let index = world.contacts.contacts.firstIndex(where: { $0.role == topic.role }) else { return nil }
        let contact = world.contacts.contacts[index]
        if topic == ContactTopic.social(for: topic.role) {
            guard let text = contactAction(topic.role) else { return nil }
            remember(contact, title: topic.title, summary: text, delta: topic.role == .family ? 8 : 6)
            return text
        }
        world.coach.energy = max(0, world.coach.energy - 6)
        world.contacts.lastActionWorldDay = worldDay
        world.contacts.contacts[index].lastContactWorldDay = worldDay
        var delta = 3
        var text = ""
        switch topic {
        case .agentScout:
            if let athlete = agentSuggestion() {
                if !watchlist.contains(athlete.id) { watchlist.append(athlete.id) }
                observe(athlete.id, gain: 25)
                text = "\(contact.name) indica \(athlete.name), do \(FootballSeason.teamName(athlete.teamID ?? 0)). Ele entrou na sua lista de observação."
            }
        case .journalistDenyRumor:
            if let rumor = latestRumor() {
                world.social.controversy = max(0, world.social.controversy - 10)
                let factID = "\(rumor.id)-denied"
                recordFact(WorldFact(id: factID, source: .press, worldDay: worldDay, title: "Clube desmente: \(rumor.title)",
                                     detail: "\(contact.name) publica o desmentido do treinador.", playerIDs: rumor.playerIDs, clubIDs: rumor.clubIDs,
                                     reliability: .confirmed, isPublic: true))
                deliverFact(factID, inbox: .press, social: true)
                delta = -2
                text = "\(contact.name) publica o desmentido, mas cobra: \"Da próxima vez, quero a notícia antes.\""
            }
        case .journalistOffRecord:
            world.social.controversy = max(0, world.social.controversy - 15)
            delta = -3
            text = "Em off, \(contact.name) aceita esfriar a polêmica. É um favor que ele não vai esquecer."
        case .presidentBudget:
            requestBoardMeeting(.budgetBoost)
            text = "\(contact.name) leva o seu pedido de verba à diretoria. A relação com ele pesa na decisão."
        case .presidentReport:
            let projection = cashProjection()
            if projection.firstContractedShortfall == nil {
                boardConfidence = min(100, boardConfidence + 2)
                text = "Você mostra a projeção de caixa sem falta à vista. \(contact.name) acalma a diretoria."
            } else {
                text = "A projeção mostra falta de caixa. \(contact.name) agradece a transparência, mas a diretoria fica atenta."
            }
        case .mentorCareer:
            let options = invitations.map(\.clubID) + jobOffers.map(\.id)
            if let best = options.max(by: { clubPrestige($0) < clubPrestige($1) }) {
                text = "\(contact.name) aconselha: \"O \(FootballSeason.teamName(best)) é o passo certo para a sua carreira.\""
            }
        case .familyPromise:
            if let day = familyPromiseDay(), planActivity(.rest, on: day) {
                var promise = ContactRequest(id: relations.nextID, contactID: contact.id, kind: .familyPromise, createdWorldDay: worldDay,
                                             deadlineWorldDay: day + 1)
                promise.status = .accepted
                promise.eventWorldDay = day
                world.projects.contactRelations.requests.append(promise)
                world.projects.contactRelations.nextID += 1
                delta = 4
                text = "Você promete folga no dia \(day - (season - 1) * FootballSeason.matchDaysPerSeason + 1). Está na sua agenda: não falte."
            }
        case .friendVent:
            world.coach.stress = max(0, world.coach.stress - 15)
            delta = -2
            text = "\(contact.name) escuta tudo. Você sai mais leve; ele, um pouco cansado das reclamações."
        default:
            break
        }
        world.contacts.contacts[index].relationship = min(100, max(0, world.contacts.contacts[index].relationship + delta))
        remember(contact, title: topic.title, summary: text, delta: delta)
        bump("contacts")
        return text
    }

    private mutating func remember(_ contact: Contact, title: String, summary: String, delta: Int) {
        world.projects.contactRelations.history.append(ContactMemoryEntry(id: relations.nextID, contactID: contact.id, worldDay: worldDay,
                                                                          title: title, summary: summary, delta: delta))
        world.projects.contactRelations.nextID += 1
        if relations.history.count > Self.contactHistoryLimit {
            world.projects.contactRelations.history.removeFirst(relations.history.count - Self.contactHistoryLimit)
        }
    }

    /// Melhor nome do primeiro briefing que ainda não está na lista de observação.
    func agentSuggestion() -> FootballPlayer? {
        guard let brief = recruitmentBriefs.first else { return nil }
        return players.filter { $0.position == brief.position && $0.age <= brief.maxAge && !$0.isYouth && !$0.onLoan
            && $0.teamID != nil && $0.teamID != selectedClubID && !watchlist.contains($0.id) && askingPrice(for: $0) <= brief.maxFee }
            .max { $0.overall != $1.overall ? $0.overall < $1.overall : $0.id > $1.id }
    }

    func latestRumor() -> WorldFact? {
        factStore.facts.last { $0.reliability == .rumor && $0.isPublic && worldDay - $0.worldDay <= 10 && fact("\($0.id)-denied") == nil }
    }

    /// Próximo dia livre de jogo fora e sem nada marcado na agenda pessoal.
    func familyPromiseDay() -> Int? {
        personalPlanDays.dropFirst().first { !$0.isAway && $0.planned == nil }?.worldDay
    }

    // MARK: Pedidos dos contatos (CON-04)

    /// Um contato por vez traz uma oportunidade ou pede ajuda. Chamado uma vez por dia de jogo.
    mutating func progressContactRequests() {
        settleContactRequests()
        guard selectedClubID != nil, !isFired, openContactRequests().count < 2 else { return }
        var random = FootballRandom(seed: matchSeed(stream: .world, id: 80_000 + worldDay))
        guard random.chance(0.18) else { return }
        let candidates = world.contacts.contacts.filter { contact in
            !relations.requests.contains { $0.contactID == contact.id && ($0.isOpen || worldDay - $0.createdWorldDay < 8) }
        }
        guard let contact = random.pick(candidates) else { return }
        var request = ContactRequest(id: relations.nextID, contactID: contact.id, kind: .presidentEvent, createdWorldDay: worldDay,
                                     deadlineWorldDay: worldDay + Self.contactRequestDays)
        let body: String
        switch contact.role {
        case .agent:
            guard contact.relationship >= 50, let athlete = agentOpportunityPlayer() else { return }
            request = ContactRequest(id: request.id, contactID: contact.id, kind: .agentOpportunity, createdWorldDay: worldDay,
                                     deadlineWorldDay: request.deadlineWorldDay, playerID: athlete.id)
            body = "\(contact.name) tem uma dica: \(athlete.name), do \(FootballSeason.teamName(athlete.teamID ?? 0)), está insatisfeito e pode sair. Quer que ele abra a porta?"
        case .journalist:
            guard contact.relationship >= 45 else { return }
            request = ContactRequest(id: request.id, contactID: contact.id, kind: .journalistInterview, createdWorldDay: worldDay, deadlineWorldDay: request.deadlineWorldDay)
            body = "\(contact.name) quer uma entrevista longa para o fim de semana. Custa energia, rende seguidores."
        case .president:
            request = ContactRequest(id: request.id, contactID: contact.id, kind: .presidentEvent, createdWorldDay: worldDay, deadlineWorldDay: request.deadlineWorldDay)
            body = "\(contact.name) pede que você vá a um evento com patrocinadores. Cansa, mas a diretoria gosta."
        case .mentor:
            guard contact.relationship >= 50 else { return }
            request = ContactRequest(id: request.id, contactID: contact.id, kind: .mentorLecture, createdWorldDay: worldDay, deadlineWorldDay: request.deadlineWorldDay)
            body = "\(contact.name) pede que você dê uma aula no curso de treinadores dele."
        case .friend:
            guard contact.relationship >= 40 else { return }
            let amount = 50_000
            request = ContactRequest(id: request.id, contactID: contact.id, kind: .friendLoan, createdWorldDay: worldDay,
                                     deadlineWorldDay: request.deadlineWorldDay, amount: amount)
            body = "\(contact.name) está apertado e pede \(FootballFormat.money(amount)) emprestados. Promete devolver em 10 dias de jogo."
        case .family:
            guard let day = familyPromiseDay() else { return }
            request = ContactRequest(id: request.id, contactID: contact.id, kind: .familyEvent, createdWorldDay: worldDay,
                                     deadlineWorldDay: request.deadlineWorldDay, eventWorldDay: day)
            body = "\(contact.name) lembra do aniversário no dia \(day - (season - 1) * FootballSeason.matchDaysPerSeason + 1). Dá para estar em casa?"
        }
        world.projects.contactRelations.requests.append(request)
        world.projects.contactRelations.nextID += 1
        addInbox(.general, title: "\(contact.role.title): \(contact.name)", body: body)
    }

    func agentOpportunityPlayer() -> FootballPlayer? {
        players.filter { $0.teamID != nil && $0.teamID != selectedClubID && !$0.isYouth && !$0.onLoan && $0.morale < 50 && !watchlist.contains($0.id) }
            .max { $0.overall != $1.overall ? $0.overall < $1.overall : $0.id > $1.id }
    }

    func contactRequestBlocker(_ id: Int) -> String? {
        guard let request = relations.requests.first(where: { $0.id == id && $0.status == .open }) else { return "Pedido indisponível." }
        switch request.kind {
        case .journalistInterview, .presidentEvent:
            if world.coach.energy < 10 { return "Energia insuficiente." }
        case .mentorLecture:
            if world.coach.lastActivityWorldDay == worldDay { return "A aula conta como a atividade do dia, e você já fez uma hoje." }
            if world.coach.energy < CoachActivity.lecture.energyCost { return "Energia insuficiente." }
        case .friendLoan:
            if world.coach.personalCash < request.amount { return "Seu bolso não cobre o empréstimo." }
        case .familyEvent:
            if let day = request.eventWorldDay, planConflicts(.rest, on: day).contains(where: { $0.severity == .blocking }) {
                return "O dia combinado já passou ou não cabe na agenda."
            }
        default:
            break
        }
        return nil
    }

    /// Responde ao pedido. Aceitar cumpre na hora ou vira compromisso com data; recusar custa pouco.
    @discardableResult
    mutating func answerContactRequest(_ id: Int, accept: Bool) -> String? {
        guard let index = relations.requests.firstIndex(where: { $0.id == id && $0.status == .open }),
              let contactIndex = world.contacts.contacts.firstIndex(where: { $0.id == relations.requests[index].contactID }) else { return nil }
        let request = relations.requests[index]
        let contact = world.contacts.contacts[contactIndex]
        guard accept else {
            world.projects.contactRelations.requests[index].status = .declined
            let cost = request.kind == .familyEvent ? 6 : 2
            world.contacts.contacts[contactIndex].relationship = max(0, contact.relationship - cost)
            remember(contact, title: "Recusou um pedido", summary: "Você disse não.", delta: -cost)
            return "\(contact.name) entende, mas fica um pouco chateado."
        }
        guard contactRequestBlocker(id) == nil else { return nil }
        var delta = 5
        var text = ""
        world.projects.contactRelations.requests[index].status = .fulfilled
        switch request.kind {
        case .agentOpportunity:
            if let playerID = request.playerID, let athlete = player(playerID) {
                if !watchlist.contains(playerID) { watchlist.append(playerID) }
                observe(playerID, gain: 35)
                text = "\(athlete.name) entrou na sua lista, com relatório do empresário."
            }
        case .journalistInterview:
            world.coach.energy -= 10
            world.social.coachFollowers += 1_500
            text = "A entrevista saiu no fim de semana: +1.500 seguidores."
        case .presidentEvent:
            world.coach.energy -= 10
            world.coach.stress = min(100, world.coach.stress + 3)
            boardConfidence = min(100, boardConfidence + 2)
            text = "Você foi ao evento. A diretoria anotou a presença."
        case .mentorLecture:
            let result = performActivity(.lecture, onWorldDay: worldDay)
            text = "Aula dada no curso do mentor. \(result.text)"
        case .friendLoan:
            world.coach.personalCash -= request.amount
            world.projects.contactRelations.requests[index].status = .accepted
            world.projects.contactRelations.requests[index].eventWorldDay = worldDay + 10
            delta = 6
            text = "Você emprestou \(FootballFormat.money(request.amount)). Ele promete devolver em 10 dias de jogo."
        case .familyEvent:
            if let day = request.eventWorldDay, planActivity(.rest, on: day) {
                world.projects.contactRelations.requests[index].status = .accepted
                text = "Combinado: o dia está na sua agenda como folga. Não falte."
            }
        case .familyPromise:
            break
        }
        world.contacts.contacts[contactIndex].relationship = min(100, contact.relationship + delta)
        remember(contact, title: "Atendeu a um pedido", summary: text, delta: delta)
        return text
    }

    /// Vence pedidos ignorados e confere promessas com data: folga cumprida, empréstimo devolvido.
    mutating func settleContactRequests() {
        for index in relations.requests.indices {
            let request = relations.requests[index]
            guard let contactIndex = world.contacts.contacts.firstIndex(where: { $0.id == request.contactID }) else { continue }
            let contact = world.contacts.contacts[contactIndex]
            switch request.status {
            case .open where worldDay >= request.deadlineWorldDay:
                world.projects.contactRelations.requests[index].status = .ignored
                let cost = request.kind == .familyEvent ? 6 : 3
                world.contacts.contacts[contactIndex].relationship = max(0, contact.relationship - cost)
                remember(contact, title: "Pedido sem resposta", summary: "Você não respondeu a tempo.", delta: -cost)
            case .accepted:
                if request.kind == .friendLoan, let day = request.eventWorldDay, worldDay >= day {
                    world.coach.personalCash += Int(Double(request.amount) * 1.05)
                    world.projects.contactRelations.requests[index].status = .fulfilled
                    remember(contact, title: "Devolveu o empréstimo", summary: "Com 5% de agradecimento.", delta: 0)
                } else if [.familyEvent, .familyPromise].contains(request.kind), let day = request.eventWorldDay, worldDay > day {
                    // Cumpriu se o descanso marcado para o dia aconteceu.
                    let kept = world.projects.personalPlan.contains { $0.worldDay == day && $0.activity == .rest && $0.status == .done }
                    world.projects.contactRelations.requests[index].status = kept ? .fulfilled : .broken
                    let delta = kept ? 8 : -12
                    world.contacts.contacts[contactIndex].relationship = min(100, max(0, contact.relationship + delta))
                    remember(contact, title: kept ? "Cumpriu a folga prometida" : "Faltou à folga prometida",
                             summary: kept ? "O dia em casa fez diferença." : "A família esperou e você não apareceu.", delta: delta)
                    if !kept { world.coach.stress = min(100, world.coach.stress + 6) }
                }
            default:
                break
            }
        }
        let closed = relations.requests.filter { !$0.isOpen }
        if closed.count > 20 {
            let keep = Set(closed.suffix(20).map(\.id))
            world.projects.contactRelations.requests.removeAll { !$0.isOpen && !keep.contains($0.id) }
        }
    }

    // MARK: Efeitos explicados (CON-05)

    /// O que a relação com cada contato muda hoje, em frases verificáveis.
    func relationshipEffects(_ role: ContactRole) -> [String] {
        switch role {
        case .agent:
            let percent = Int((agentDiscount * 100).rounded())
            return [percent > 0 ? "Atletas de outros clubes pedem \(percent)% menos (relação acima de 40)." : "Sem desconto: a relação precisa passar de 40."]
        case .president:
            var lines = ["Limite de demissão \(presidentPatience) ponto(s) mais tolerante."]
            lines.append("Reunião de diretoria: \(presidentBoardWeight >= 0 ? "+" : "")\(presidentBoardWeight) na decisão.")
            return lines
        case .mentor:
            return [mentorStudyBonusChance > 0 ? "40% de chance de cada aula da licença valer em dobro." : "Sem bônus nas aulas: a relação precisa chegar a 50."]
        case .journalist:
            return ["Desmentidos e conversas em off gastam a boa vontade dele."]
        case .family:
            return [relationship(.family) < 30 ? "Relação baixa: o estresse sobe 1 por dia de jogo." : "Relação estável: sem estresse extra."]
        case .friend:
            return ["Desabafar alivia 15 de estresse, mas cansa a amizade."]
        }
    }

    /// Peso do presidente na reunião de diretoria: −5 a +5.
    var presidentBoardWeight: Int { (relationship(.president) - 50) / 10 }

    // MARK: Troca de clube (CON-06)

    /// Novo clube, novo presidente; empresário só fica se a relação for boa; família, amigo, mentor e jornalista seguem.
    mutating func transitionContactsToNewClub() {
        var random = FootballRandom(seed: matchSeed(stream: .world, id: 81_000 + worldDay))
        for index in world.contacts.contacts.indices {
            let contact = world.contacts.contacts[index]
            let replace = contact.role == .president || (contact.role == .agent && contact.relationship < 45)
            guard replace else { continue }
            let name = "\(random.pick(Self.contactFirstNames) ?? "Paulo") \(random.pick(Self.contactLastNames) ?? "Duarte")"
            world.contacts.contacts[index] = Contact(id: contact.id, name: name, role: contact.role, relationship: contact.role == .president ? 45 : 35,
                                                     lastContactWorldDay: worldDay)
            remember(world.contacts.contacts[index], title: contact.role == .president ? "Novo presidente" : "Novo empresário",
                     summary: "\(name) substitui \(contact.name).", delta: 0)
        }
        for index in world.projects.contactRelations.requests.indices where world.projects.contactRelations.requests[index].status == .open {
            let role = world.contacts.contacts.first { $0.id == world.projects.contactRelations.requests[index].contactID }?.role
            if role == .president || role == .agent { world.projects.contactRelations.requests[index].status = .declined }
        }
    }
}
