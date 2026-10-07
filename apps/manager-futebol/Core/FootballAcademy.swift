import Foundation

// MARK: - Academia: perfil, acompanhamento e ações da base

/// Temperamento do jovem: muda a curva de crescimento e aparece na ficha aos poucos.
enum YouthTrait: String, Codable, CaseIterable, Identifiable {
    case worker, lateBloomer, earlyBloomer, temperamental, fragile, leader

    var id: String { rawValue }

    var title: String {
        switch self {
        case .worker: return "Trabalhador"
        case .lateBloomer: return "Crescimento tardio"
        case .earlyBloomer: return "Precoce"
        case .temperamental: return "Temperamental"
        case .fragile: return "Frágil"
        case .leader: return "Líder"
        }
    }

    var summary: String {
        switch self {
        case .worker: return "Treina mais do que os outros: evolui mais rápido."
        case .lateBloomer: return "Demora a aparecer, mas cresce forte depois dos 18."
        case .earlyBloomer: return "Brilha cedo, mas perde força depois dos 18."
        case .temperamental: return "Oscila: evolução um pouco mais lenta e humor instável."
        case .fragile: return "Talento com corpo delicado: risco maior de lesão."
        case .leader: return "Puxa os colegas e cresce junto com o grupo."
        }
    }

    var symbol: String {
        switch self {
        case .worker: return "hammer.fill"
        case .lateBloomer: return "hourglass"
        case .earlyBloomer: return "bolt.fill"
        case .temperamental: return "flame.fill"
        case .fragile: return "bandage.fill"
        case .leader: return "flag.fill"
        }
    }

    /// Peso do sorteio: o comum é ser trabalhador; fragilidade é rara.
    var weight: Int {
        switch self {
        case .worker: return 5
        case .lateBloomer, .earlyBloomer, .temperamental, .leader: return 3
        case .fragile: return 2
        }
    }
}

/// O que o clube "sabe" de um jovem. Derivado da semente da carreira e do id do atleta: igual em qualquer dia e temporada.
struct YouthProfile: Equatable {
    let playerID: Int
    let hometown: String
    let traits: [YouthTrait]
    /// 0,85 a 1,20: ritmo individual de crescimento (oculto).
    let growthSpeed: Double
}

/// Acompanhamento do clube sobre um jovem: só o que muda com as decisões do treinador.
struct YouthFollowUp: Codable, Equatable, Identifiable {
    let playerID: Int
    var observedWeeks = 0
    var focus: YouthProgram? = nil
    var mentorID: Int? = nil

    var id: Int { playerID }
}

struct AcademyState: Codable, Equatable {
    var followUps: [YouthFollowUp] = []
    /// Ações de formação disponíveis: voltam uma por dia de jogo, até o máximo da academia.
    var points = 3
    /// Parcerias de captação ativas (cada uma cobra manutenção a cada chegada anual).
    var partnerships: [YouthPartnership] = []
    /// Resultado do campeonato de cada categoria, por temporada.
    var leagueResults: [YouthLeagueResult] = []
    /// Minutos de jogo de cada jovem nesta temporada (zerados na chegada anual).
    var minutes: [Int: Int] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case followUps, points, partnerships, leagueResults, minutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        followUps = try container.decodeIfPresent([YouthFollowUp].self, forKey: .followUps) ?? []
        points = try container.decodeIfPresent(Int.self, forKey: .points) ?? 3
        partnerships = try container.decodeIfPresent([YouthPartnership].self, forKey: .partnerships) ?? []
        leagueResults = try container.decodeIfPresent([YouthLeagueResult].self, forKey: .leagueResults) ?? []
        minutes = try container.decodeIfPresent([Int: Int].self, forKey: .minutes) ?? [:]
    }
}

extension FootballCareer {
    static let academyObserveCost = 15_000
    static let academyMenteeLimit = 2

    /// Cidades fictícias por região (0 Norte, 1 Nordeste, 2 Centro-Oeste, 3 Sudeste, 4 Sul).
    static let academyHometowns: [[String]] = [
        ["Porto das Águas", "Vila Tucumã", "Rio Branco do Norte", "Santa Aurora"],
        ["Barra do Sol", "Serra Dourada", "Ponta do Coqueiral", "Vila Salineira"],
        ["Campo Alto", "Planalto Verde", "São Jerônimo do Cerrado", "Vila Pioneira"],
        ["Morro Azul", "Vale do Café", "Jardim das Pedras", "Cidade Operária"],
        ["Colina Gaúcha", "Vila Araucária", "Porto Serrano", "Campos do Sul"],
    ]

    /// Semente estável do jovem: não muda com a temporada.
    private func academySeed(for playerID: Int) -> UInt64 {
        UInt64(bitPattern: Int64(seed)) &+ UInt64(playerID + 1) &* 0xBF58476D1CE4E5B9 &+ 0x5A17
    }

    // MARK: Perfil

    func academyProfile(for player: FootballPlayer) -> YouthProfile {
        var random = FootballRandom(seed: academySeed(for: player.id))
        let towns = Self.academyHometowns[min(max(player.region, 0), Self.academyHometowns.count - 1)]
        let hometown = random.pick(towns) ?? towns[0]
        var pool = YouthTrait.allCases
        var traits: [YouthTrait] = []
        let count = random.chance(0.35) ? 2 : 1
        for _ in 0..<count {
            guard let index = random.weightedIndex(pool.map(\.weight)) else { break }
            let picked = pool.remove(at: index)
            traits.append(picked)
            // Precoce e tardio se excluem.
            if picked == .lateBloomer { pool.removeAll { $0 == .earlyBloomer } }
            if picked == .earlyBloomer { pool.removeAll { $0 == .lateBloomer } }
        }
        let speed = 0.85 + Double(random.int(in: 0...35)) / 100
        return YouthProfile(playerID: player.id, hometown: hometown, traits: traits, growthSpeed: speed)
    }

    // MARK: Acompanhamento

    func academyFollowUp(for playerID: Int) -> YouthFollowUp? {
        academy.followUps.first { $0.playerID == playerID }
    }

    func observedWeeks(for playerID: Int) -> Int {
        academyFollowUp(for: playerID)?.observedWeeks ?? 0
    }

    /// Jovens com o perfil inteiro revelado (todos os traços e pelo menos uma semana de observação).
    /// São os que já dá para decidir: promover, manter, emprestar ou dispensar. O atalho do Gestor usa esta lista.
    var youthReadyForDecision: [FootballPlayer] {
        youthRoster.filter { player in
            guard observedWeeks(for: player.id) > 0 else { return false }
            return revealedTraits(for: player).count >= academyProfile(for: player).traits.count
        }
    }

    private mutating func updateFollowUp(_ playerID: Int, _ change: (inout YouthFollowUp) -> Void) {
        if let index = academy.followUps.firstIndex(where: { $0.playerID == playerID }) {
            change(&academy.followUps[index])
        } else {
            var item = YouthFollowUp(playerID: playerID)
            change(&item)
            academy.followUps.append(item)
        }
    }

    /// Traços já descobertos: o primeiro aparece com 6 semanas de observação, o segundo com 12.
    func revealedTraits(for player: FootballPlayer) -> [YouthTrait] {
        Array(academyProfile(for: player).traits.prefix(observedWeeks(for: player.id) / 6))
    }

    // MARK: Potencial estimado

    /// Incerteza da estimativa, em pontos: cai com as semanas de observação, o olheiro-chefe e o técnico da base.
    func potentialMargin(for player: FootballPlayer) -> Int {
        let scout = (staffAbility(.headScout) ?? 6) / 4
        let coach = (staffAbility(.youthCoach) ?? 6) / 5
        return max(1, 12 - observedWeeks(for: player.id) / 2 - scout - coach)
    }

    /// Faixa em que o potencial verdadeiro (oculto) está. Sempre contém o valor real.
    func potentialEstimate(for player: FootballPlayer) -> ClosedRange<Int> {
        let margin = potentialMargin(for: player)
        var random = FootballRandom(seed: academySeed(for: player.id) &+ 7)
        let half = margin / 2
        let offset = half >= 1 ? random.int(in: -half...half) : 0
        let center = player.potential + offset
        let low = max(player.overall, center - margin)
        let high = min(99, max(low, center + margin))
        return low...high
    }

    // MARK: Crescimento

    func isValidMentor(_ id: Int) -> Bool {
        mentorCandidates.contains { $0.id == id }
    }

    /// Veteranos do elenco principal que podem orientar um jovem.
    var mentorCandidates: [FootballPlayer] {
        clubRoster.filter { !$0.isYouth && $0.age >= 27 }.sorted { $0.overall > $1.overall }
    }

    /// Multiplicador da chance diária de evolução do jovem.
    func academyGrowthFactor(for player: FootballPlayer) -> Double {
        let profile = academyProfile(for: player)
        var factor = profile.growthSpeed
        for trait in profile.traits {
            switch trait {
            case .worker: factor *= 1.2
            case .lateBloomer: factor *= player.age <= 18 ? 0.8 : 1.35
            case .earlyBloomer: factor *= player.age <= 18 ? 1.3 : 0.8
            case .temperamental: factor *= 0.95
            case .fragile: break
            case .leader: factor *= 1.05
            }
        }
        if player.has(.prodigy) { factor *= 1.15 }
        // Jogar importa: até +25% com 3000 minutos (o teto impede que a base dependa só de minutos).
        factor *= 1 + min(0.25, Double(academy.minutes[player.id, default: 0]) / 3000)
        if let mentorID = academyFollowUp(for: player.id)?.mentorID, isValidMentor(mentorID) { factor *= 1.15 }
        return factor
    }

    // MARK: Ações

    var academyPointsMax: Int {
        3 + max(0, (staffAbility(.youthCoach) ?? 6) - 6) / 3
    }

    func canObserve(playerID: Int) -> String? {
        guard youthRoster.contains(where: { $0.id == playerID }) else { return "Este jovem não está na base." }
        if isFired { return "Sem clube." }
        if academy.points < 1 { return "Sem ações disponíveis: elas voltam a cada dia de jogo." }
        if transferBudget < Self.academyObserveCost { return "Caixa insuficiente." }
        return nil
    }

    /// Gasta uma ação e dinheiro para acompanhar o jovem de perto: a estimativa de potencial fica mais precisa.
    @discardableResult
    mutating func observeYouth(playerID: Int) -> Bool {
        guard canObserve(playerID: playerID) == nil else { return false }
        academy.points -= 1
        book(.academy, -Self.academyObserveCost, "Observação de jovem da base")
        updateFollowUp(playerID) { $0.observedWeeks += 6 }
        return true
    }

    @discardableResult
    mutating func setYouthFocus(playerID: Int, focus: YouthProgram?) -> Bool {
        guard youthRoster.contains(where: { $0.id == playerID }) else { return false }
        updateFollowUp(playerID) { $0.focus = focus }
        return true
    }

    func canAssignMentor(playerID: Int, mentorID: Int) -> String? {
        guard youthRoster.contains(where: { $0.id == playerID }) else { return "Este jovem não está na base." }
        if academy.points < 1 { return "Sem ações disponíveis: elas voltam a cada dia de jogo." }
        guard isValidMentor(mentorID) else { return "O mentor precisa ser um veterano do elenco principal (27 anos ou mais)." }
        let others = academy.followUps.filter { $0.mentorID == mentorID && $0.playerID != playerID }.count
        if others >= Self.academyMenteeLimit { return "Este veterano já orienta dois jovens." }
        return nil
    }

    @discardableResult
    mutating func assignMentor(playerID: Int, mentorID: Int) -> Bool {
        guard canAssignMentor(playerID: playerID, mentorID: mentorID) == nil else { return false }
        academy.points -= 1
        updateFollowUp(playerID) { $0.mentorID = mentorID }
        return true
    }

    @discardableResult
    mutating func clearMentor(playerID: Int) -> Bool {
        guard academyFollowUp(for: playerID)?.mentorID != nil else { return false }
        updateFollowUp(playerID) { $0.mentorID = nil }
        return true
    }

    // MARK: Ritmo diário

    /// Um dia de jogo: todos os jovens ganham uma semana de observação passiva e uma ação volta.
    mutating func tickAcademy() {
        let ids = youthRoster.map(\.id)
        academy.followUps.removeAll { followUp in !ids.contains(followUp.playerID) }
        for id in ids where !academy.followUps.contains(where: { $0.playerID == id }) {
            academy.followUps.append(YouthFollowUp(playerID: id))
        }
        for index in academy.followUps.indices {
            academy.followUps[index].observedWeeks += 1
            if let mentorID = academy.followUps[index].mentorID, !isValidMentor(mentorID) {
                academy.followUps[index].mentorID = nil
            }
        }
        academy.points = min(academyPointsMax, academy.points + 1)
    }
}
