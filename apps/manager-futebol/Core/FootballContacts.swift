import Foundation

// MARK: - Contatos do celular: personagens recorrentes

enum ContactRole: String, Codable, CaseIterable, Identifiable {
    case agent, journalist, president, mentor, family, friend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .agent: return "Empresário"
        case .journalist: return "Jornalista"
        case .president: return "Presidente"
        case .mentor: return "Mentor"
        case .family: return "Família"
        case .friend: return "Amigo"
        }
    }

    var symbol: String {
        switch self {
        case .agent: return "briefcase.fill"
        case .journalist: return "newspaper.fill"
        case .president: return "building.columns.fill"
        case .mentor: return "graduationcap.fill"
        case .family: return "house.fill"
        case .friend: return "person.2.fill"
        }
    }

    var action: String {
        switch self {
        case .agent: return "Almoçar com o empresário"
        case .journalist: return "Dar uma exclusiva"
        case .president: return "Jantar com o presidente"
        case .mentor: return "Pedir um conselho"
        case .family: return "Passar o dia com a família"
        case .friend: return "Churrasco com o amigo"
        }
    }

    var perk: String {
        switch self {
        case .agent: return "Com relação alta, atletas de outros clubes saem até 6% mais baratos."
        case .journalist: return "Com relação alta, suas respostas na coletiva rendem mais com a torcida."
        case .president: return "Com relação alta, a diretoria tem mais paciência com você."
        case .mentor: return "Com relação alta, as aulas da licença rendem mais."
        case .family: return "Sem atenção, o estresse sobe. Com atenção, você recupera energia."
        case .friend: return "Descanso leve e boas histórias: reduz o estresse e dá energia."
        }
    }
}

struct Contact: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let role: ContactRole
    var relationship: Int
    var lastContactWorldDay: Int
}

struct ContactsState: Codable, Equatable {
    var contacts: [Contact] = []
    var lastActionWorldDay = -1
}

extension FootballCareer {
    static let contactFirstNames = ["Rogério", "Marta", "Cláudio", "Ivone", "Paulo", "Sônia", "Alexandre", "Beatriz", "Fábio", "Regina", "Tadeu", "Helena"]
    static let contactLastNames = ["Albuquerque", "Brandão", "Cavalcanti", "Duarte", "Esteves", "Figueiredo", "Guimarães", "Tavares"]

    func contact(_ role: ContactRole) -> Contact? { world.contacts.contacts.first { $0.role == role } }

    func relationship(_ role: ContactRole) -> Int { contact(role)?.relationship ?? 0 }

    mutating func ensureContacts() {
        guard world.contacts.contacts.isEmpty else { return }
        var random = FootballRandom(seed: UInt64(truncatingIfNeeded: seed) &* 31 &+ 4_242)
        for (index, role) in ContactRole.allCases.enumerated() {
            let name = "\(random.pick(Self.contactFirstNames) ?? "Paulo") \(random.pick(Self.contactLastNames) ?? "Duarte")"
            let start = role == .family ? 70 : (role == .president ? 45 : 30 + random.int(in: 0...15))
            world.contacts.contacts.append(Contact(id: index + 1, name: name, role: role, relationship: start, lastContactWorldDay: worldDay))
        }
    }

    func canContact(_ role: ContactRole) -> String? {
        guard selectedClubID != nil, liveMatch == nil, contact(role) != nil else { return "Indisponível agora." }
        if isFired && role == .president { return "Sem clube, não há presidente para conversar." }
        if world.contacts.lastActionWorldDay == worldDay { return "Uma conversa por dia de jogo." }
        if world.coach.energy < 8 { return "Energia insuficiente: descanse primeiro." }
        return nil
    }

    @discardableResult
    mutating func contactAction(_ role: ContactRole) -> String? {
        guard canContact(role) == nil, let index = world.contacts.contacts.firstIndex(where: { $0.role == role }) else { return nil }
        let name = world.contacts.contacts[index].name
        world.coach.energy = max(0, world.coach.energy - 6)
        world.contacts.lastActionWorldDay = worldDay
        world.contacts.contacts[index].lastContactWorldDay = worldDay
        var gain = 6
        var text: String
        switch role {
        case .agent:
            text = "Almoço produtivo com \(name): ele passa a olhar o mercado por você."
        case .journalist:
            fanMood = min(100, fanMood + 1)
            world.social.coachFollowers += 400
            text = "\(name) publica sua exclusiva e a torcida comenta."
        case .president:
            boardConfidence = min(100, boardConfidence + 2)
            text = "O presidente \(name) sai do jantar confiante no seu trabalho."
        case .mentor:
            text = "\(name) compartilha uma lição de bastidores que você anota."
        case .family:
            world.coach.stress = max(0, world.coach.stress - 12)
            world.coach.energy = min(100, world.coach.energy + 14)
            gain = 8
            text = "Um dia em casa com \(name) recarrega as baterias."
        case .friend:
            world.coach.stress = max(0, world.coach.stress - 6)
            world.coach.energy = min(100, world.coach.energy + 6)
            text = "Churrasco com \(name): boas risadas e cabeça leve."
        }
        world.contacts.contacts[index].relationship = min(100, world.contacts.contacts[index].relationship + gain)
        bump("contacts")
        return text
    }

    /// Desconto nas pedidas de atletas de outros clubes pela relação com o empresário.
    var agentDiscount: Double { Double(max(0, relationship(.agent) - 40)) / 60 * 0.06 }

    /// Pontos a menos no limite de demissão pela relação com o presidente.
    var presidentPatience: Int { max(0, relationship(.president) - 40) / 15 }

    /// Chance de a aula da licença valer em dobro, pela relação com o mentor.
    var mentorStudyBonusChance: Double { relationship(.mentor) >= 50 ? 0.4 : 0 }

    mutating func tickContacts() {
        for index in world.contacts.contacts.indices {
            let idle = worldDay - world.contacts.contacts[index].lastContactWorldDay
            guard idle >= 6, idle % 3 == 0 else { continue }
            world.contacts.contacts[index].relationship = max(0, world.contacts.contacts[index].relationship - 2)
        }
        if relationship(.family) < 30 { world.coach.stress = min(100, world.coach.stress + 1) }
    }
}
