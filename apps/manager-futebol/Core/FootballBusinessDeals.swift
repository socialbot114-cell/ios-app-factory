import Foundation

// MARK: - Negócios: naming negociado (NEG-03), projeto social em etapas (NEG-04), amistoso e turnê agendados (NEG-05)

/// Negociação do nome do estádio com um patrocinador.
struct NamingTalk: Codable, Equatable, Identifiable {
    enum Status: String, Codable { case open, agreed, withdrawn }

    let id: Int
    let offer: NamingRightsOffer
    /// Teto do patrocinador por temporada (oculto do jogador).
    let reservePerSeason: Int
    var counterPerSeason: Int? = nil
    var refusals = 0
    var status: Status = .open
    var log: [String] = []
}

enum NamingOutcome: Equatable {
    case agreed(String)
    case counter(Int, String)
    case refused(String)
    case notAllowed(String)
}

/// Projeto social com planejamento, execução e balanço.
struct SocialProject: Codable, Equatable, Identifiable {
    enum Stage: Int, Codable, CaseIterable {
        case planning, execution, review, done
        var title: String {
            switch self {
            case .planning: return "Planejamento"
            case .execution: return "Execução"
            case .review: return "Balanço"
            case .done: return "Concluído"
            }
        }
        var days: Int {
            switch self {
            case .planning: return 2
            case .execution: return 6
            case .review: return 1
            case .done: return 0
            }
        }
    }

    let id: Int
    let program: CommunityProgram
    let startWorldDay: Int
    var stage: Stage = .planning
    var stageStartWorldDay: Int
    var spent = 0
    /// Resultados registrados ao longo da execução.
    var peopleReached = 0
    var fansGained = 0
    var reputationGained = 0
    var reports: [String] = []

    var isRunning: Bool { stage != .done }
}

/// Amistoso marcado com antecedência para uma data livre.
struct ScheduledFriendly: Codable, Equatable, Identifiable {
    enum Status: String, Codable { case scheduled, played, cancelled }

    let id: Int
    let opponentID: Int
    let home: Bool
    let season: Int
    let matchDay: Int
    let expectedRevenue: Int
    let expectedFatigue: Int
    var status: Status = .scheduled
    var result: String = ""
}

struct BusinessDealsState: Codable, Equatable {
    var namingTalks: [NamingTalk] = []
    var socialProjects: [SocialProject] = []
    var friendlies: [ScheduledFriendly] = []
    var tourScheduledForSeason: Int? = nil
    var nextID = 1

    init() {}

    private enum CodingKeys: String, CodingKey { case namingTalks, socialProjects, friendlies, tourScheduledForSeason, nextID }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        namingTalks = try container.decodeIfPresent([NamingTalk].self, forKey: .namingTalks) ?? []
        socialProjects = try container.decodeIfPresent([SocialProject].self, forKey: .socialProjects) ?? []
        friendlies = try container.decodeIfPresent([ScheduledFriendly].self, forKey: .friendlies) ?? []
        tourScheduledForSeason = try container.decodeIfPresent(Int.self, forKey: .tourScheduledForSeason)
        nextID = try container.decodeIfPresent(Int.self, forKey: .nextID) ?? 1
    }
}

extension FootballCareer {
    var deals: BusinessDealsState { world.projects.deals }

    // MARK: NEG-03 — naming rights negociado

    var openNamingTalk: NamingTalk? { deals.namingTalks.last { $0.status == .open } }

    @discardableResult
    mutating func startNamingTalk(offerID: Int) -> NamingTalk? {
        guard world.business.naming == nil, openNamingTalk == nil,
              let offer = world.business.namingOffers.first(where: { $0.id == offerID }) else { return nil }
        var random = FootballRandom(seed: matchSeed(stream: .business, id: 70_000 + offer.id))
        let reserve = Int(Double(offer.perSeason) * (1.08 + random.unit() * 0.2) / 10_000) * 10_000
        let talk = NamingTalk(id: deals.nextID, offer: offer, reservePerSeason: reserve, log: ["\(offer.sponsor) abre a conversa com \(FootballFormat.money(offer.perSeason))/temporada."])
        world.projects.deals.nextID += 1
        world.projects.deals.namingTalks.append(talk)
        return talk
    }

    /// Reação da torcida (queda de humor) à troca de nome: menor com o nome tradicional mantido e com torcida feliz.
    func namingBacklash(keepTraditionalName: Bool) -> Int {
        let base = keepTraditionalName ? 1 : 4
        return fanMood >= 70 ? max(0, base - 1) : (fanMood < 40 ? base + 2 : base)
    }

    /// Proposta do clube: valor por temporada, duração e se o nome tradicional fica junto (15% a menos).
    @discardableResult
    mutating func proposeNaming(talkID: Int, perSeason: Int, seasons: Int, keepTraditionalName: Bool) -> NamingOutcome {
        guard let index = deals.namingTalks.firstIndex(where: { $0.id == talkID && $0.status == .open }) else {
            return .notAllowed("Negociação encerrada.")
        }
        let talk = deals.namingTalks[index]
        let years = max(1, min(6, seasons))
        // Contrato mais longo vale mais para o patrocinador; nome híbrido vale menos.
        var ceiling = Double(talk.reservePerSeason) * (1 + 0.03 * Double(years - talk.offer.seasons))
        if keepTraditionalName { ceiling *= 0.85 }
        let ceilingValue = Int(ceiling / 10_000) * 10_000
        if perSeason <= ceilingValue {
            closeNaming(index: index, perSeason: perSeason, seasons: years, keepTraditionalName: keepTraditionalName)
            return .agreed("\(talk.offer.sponsor) aceitou \(FootballFormat.money(perSeason))/temporada por \(years) temporada(s).")
        }
        if Double(perSeason) <= Double(ceilingValue) * 1.15 {
            world.projects.deals.namingTalks[index].counterPerSeason = ceilingValue
            world.projects.deals.namingTalks[index].log.append("Clube pediu \(FootballFormat.money(perSeason)); \(talk.offer.sponsor) chegou a \(FootballFormat.money(ceilingValue)).")
            return .counter(ceilingValue, "\(talk.offer.sponsor) chega a \(FootballFormat.money(ceilingValue))/temporada nessas condições.")
        }
        world.projects.deals.namingTalks[index].refusals += 1
        world.projects.deals.namingTalks[index].log.append("\(talk.offer.sponsor) recusou \(FootballFormat.money(perSeason)).")
        if deals.namingTalks[index].refusals >= 2 {
            world.projects.deals.namingTalks[index].status = .withdrawn
            world.business.namingOffers.removeAll { $0.id == talk.offer.id }
            return .refused("\(talk.offer.sponsor) desistiu: os pedidos ficaram acima do que a marca aceita pagar.")
        }
        return .refused("\(talk.offer.sponsor) recusou: muito acima do orçamento da marca.")
    }

    private mutating func closeNaming(index: Int, perSeason: Int, seasons: Int, keepTraditionalName: Bool) {
        let talk = deals.namingTalks[index]
        let traditional = selectedClub?.stadium ?? "Estádio"
        let name = keepTraditionalName ? "\(traditional) · Arena \(talk.offer.sponsor)" : talk.offer.stadiumName
        let backlash = namingBacklash(keepTraditionalName: keepTraditionalName)
        world.business.naming = NamingRightsDeal(sponsor: talk.offer.sponsor, stadiumName: name, perSeason: perSeason, endSeason: season + seasons - 1)
        world.business.namingOffers = []
        fanMood = max(0, fanMood - backlash)
        world.projects.deals.namingTalks[index].status = .agreed
        world.projects.deals.namingTalks[index].log.append("Acordo: \(FootballFormat.money(perSeason))/temporada por \(seasons) temporada(s).")
        openLedger(.naming, key: "naming", title: "Naming rights \(talk.offer.sponsor)", unit: .money,
                   forecastPerDay: Double(perSeason / FootballSeason.matchDaysPerSeason), horizonDays: seasons * FootballSeason.matchDaysPerSeason)
        let factID = "naming-\(talk.id)"
        recordFact(WorldFact(id: factID, source: .market, worldDay: worldDay, title: "Estádio passa a se chamar \(name)",
                             detail: "Acordo de \(FootballFormat.money(perSeason)) por temporada com \(talk.offer.sponsor). Reação da torcida: humor -\(backlash)\(keepTraditionalName ? ", amenizada por manter o nome tradicional" : "").",
                             clubIDs: selectedClubID.map { [$0] } ?? [], reliability: .confirmed, isPublic: true))
        deliverFact(factID, inbox: .general, social: true)
    }

    // MARK: NEG-04 — projeto social em etapas

    var activeSocialProject: SocialProject? { deals.socialProjects.last(where: \.isRunning) }

    /// Custo de cada etapa: 10% do custo anual do programa no planejamento, 25% na execução.
    func socialStageCost(_ program: CommunityProgram, stage: SocialProject.Stage) -> Int {
        switch stage {
        case .planning: return program.costPerSeason / 10
        case .execution: return program.costPerSeason / 4
        default: return 0
        }
    }

    func socialProjectBlocker(_ program: CommunityProgram) -> String? {
        guard selectedClubID != nil, !isFired else { return "Sem clube." }
        if activeSocialProject != nil { return "Já existe um projeto social em andamento." }
        let cost = socialStageCost(program, stage: .planning)
        if transferBudget < cost { return "Caixa insuficiente para o planejamento (\(FootballFormat.money(cost)))." }
        return nil
    }

    @discardableResult
    mutating func startSocialProject(_ program: CommunityProgram) -> Bool {
        guard socialProjectBlocker(program) == nil else { return false }
        let cost = socialStageCost(program, stage: .planning)
        book(.community, -cost, "Projeto social: \(program.title) · planejamento")
        var project = SocialProject(id: deals.nextID, program: program, startWorldDay: worldDay, stageStartWorldDay: worldDay, spent: cost)
        project.reports.append("Planejamento iniciado com \(FootballFormat.money(cost)).")
        world.projects.deals.nextID += 1
        world.projects.deals.socialProjects.append(project)
        return true
    }

    /// Avança etapas e registra resultados. Uma vez por dia de jogo.
    mutating func progressSocialProject() {
        guard let index = deals.socialProjects.lastIndex(where: \.isRunning) else { return }
        var project = deals.socialProjects[index]
        var random = FootballRandom(seed: matchSeed(stream: .business, id: 71_000 + project.id * 50 + worldDay))
        if project.stage == .execution {
            // Resultado do dia: pessoas atendidas, torcedores e, às vezes, reputação.
            let people = 20 + random.int(in: 0...40)
            let fans = Int(Double(fanBase) * 0.0008 * (0.5 + random.unit()))
            project.peopleReached += people
            project.fansGained += fans
            fanBase += fans
            if random.chance(0.15) { project.reputationGained += 1; changeReputation(1) }
        }
        guard worldDay - project.stageStartWorldDay >= project.stage.days else {
            world.projects.deals.socialProjects[index] = project
            return
        }
        switch project.stage {
        case .planning:
            let cost = socialStageCost(project.program, stage: .execution)
            guard transferBudget >= cost else {
                project.reports.append("Execução adiada: falta \(FootballFormat.money(cost - transferBudget)) em caixa.")
                world.projects.deals.socialProjects[index] = project
                return
            }
            book(.community, -cost, "Projeto social: \(project.program.title) · execução")
            project.spent += cost
            project.stage = .execution
            project.reports.append("Execução começou: \(FootballFormat.money(cost)) liberados.")
        case .execution:
            project.stage = .review
            project.reports.append("Execução encerrada: \(project.peopleReached) pessoas atendidas, \(project.fansGained) novos torcedores.")
        case .review:
            project.stage = .done
            fanMood = min(100, fanMood + 2)
            let summary = "\(project.program.title): \(project.peopleReached) pessoas atendidas, \(project.fansGained) torcedores, reputação +\(project.reputationGained), investimento de \(FootballFormat.money(project.spent))."
            project.reports.append("Balanço: \(summary)")
            let factID = "social-\(project.id)"
            recordFact(WorldFact(id: factID, source: .press, worldDay: worldDay, title: "Projeto social do clube presta contas",
                                 detail: summary, clubIDs: selectedClubID.map { [$0] } ?? [], reliability: .confirmed, isPublic: true))
            deliverFact(factID, inbox: .general, social: true)
        case .done:
            break
        }
        project.stageStartWorldDay = worldDay
        world.projects.deals.socialProjects[index] = project
    }

    // MARK: NEG-05 — amistoso e turnê agendados

    /// Datas futuras desta temporada em que o clube não joga.
    var freeFriendlyDates: [Int] {
        guard let clubID = selectedClubID else { return [] }
        let busy = Set(fixtures.filter { $0.involves(clubID) }.map(\.matchDay))
        let taken = Set(deals.friendlies.filter { $0.status == .scheduled && $0.season == season }.map(\.matchDay))
        // Só datas futuras: o amistoso é jogado quando a data chega.
        return ((matchDayIndex + 1)..<max(matchDayIndex + 1, FootballSeason.matchDaysPerSeason)).filter { !busy.contains($0) && !taken.contains($0) }
    }

    func friendlyEstimate(opponentID: Int, home: Bool) -> (revenue: Int, fatigue: Int) {
        let revenue = home ? Int(Double(gateRevenue(attendance: Int(Double(effectiveStadiumCapacity) * 0.55))) * 0.7) : 25_000
        let strength = FootballSeason.team(opponentID)?.strength ?? 65
        return (revenue, 5 + max(0, strength - 60) / 5)
    }

    func friendlyBlocker(matchDay: Int) -> String? {
        guard selectedClubID != nil, !isFired else { return "Sem clube." }
        if world.business.friendliesThisSeason + deals.friendlies.filter({ $0.status == .scheduled && $0.season == season }).count >= Self.friendlyLimit {
            return "Limite de \(Self.friendlyLimit) amistosos por temporada."
        }
        if !freeFriendlyDates.contains(matchDay) { return "O clube já tem jogo nessa data." }
        return nil
    }

    @discardableResult
    mutating func scheduleFriendly(opponentID: Int, home: Bool, matchDay: Int) -> ScheduledFriendly? {
        guard friendlyBlocker(matchDay: matchDay) == nil, opponentID != selectedClubID, FootballSeason.team(opponentID) != nil else { return nil }
        let estimate = friendlyEstimate(opponentID: opponentID, home: home)
        let friendly = ScheduledFriendly(id: deals.nextID, opponentID: opponentID, home: home, season: season, matchDay: matchDay,
                                         expectedRevenue: estimate.revenue, expectedFatigue: estimate.fatigue)
        world.projects.deals.nextID += 1
        world.projects.deals.friendlies.append(friendly)
        return friendly
    }

    mutating func cancelFriendly(_ id: Int) {
        guard let index = deals.friendlies.firstIndex(where: { $0.id == id && $0.status == .scheduled }) else { return }
        world.projects.deals.friendlies[index].status = .cancelled
        world.projects.deals.friendlies[index].result = "Cancelado pelo clube."
    }

    /// Joga o amistoso marcado para o dia que começa agora; se não der, cancela explicando.
    mutating func runScheduledFriendlies() {
        for index in deals.friendlies.indices where deals.friendlies[index].status == .scheduled {
            let friendly = deals.friendlies[index]
            if friendly.season != season || friendly.matchDay < matchDayIndex {
                world.projects.deals.friendlies[index].status = .cancelled
                world.projects.deals.friendlies[index].result = "A data passou sem o jogo."
                continue
            }
            guard friendly.matchDay == matchDayIndex else { continue }
            if let record = playFriendly(opponentID: friendly.opponentID, home: friendly.home) {
                world.projects.deals.friendlies[index].status = .played
                world.projects.deals.friendlies[index].result = "\(record.goalsFor) × \(record.goalsAgainst) contra o \(FootballSeason.teamName(friendly.opponentID)); receita de \(FootballFormat.money(record.revenue)) (previsto \(FootballFormat.money(friendly.expectedRevenue)))."
            } else {
                world.projects.deals.friendlies[index].status = .cancelled
                world.projects.deals.friendlies[index].result = canPlayFriendly() ?? "Não foi possível jogar."
            }
        }
    }

    /// Agenda a excursão para a próxima pré-temporada.
    @discardableResult
    mutating func scheduleTour() -> Bool {
        guard selectedClubID != nil, !isFired, deals.tourScheduledForSeason == nil else { return false }
        world.projects.deals.tourScheduledForSeason = season + 1
        return true
    }

    /// Na pré-temporada agendada, a excursão acontece se houver caixa.
    mutating func runScheduledTour() {
        guard let target = deals.tourScheduledForSeason, season >= target else { return }
        world.projects.deals.tourScheduledForSeason = nil
        if season == target, canDoTour() == nil {
            doPreseasonTour()
        } else {
            addInbox(.general, title: "Excursão cancelada", body: canDoTour() ?? "A data da excursão passou.")
        }
    }
}
