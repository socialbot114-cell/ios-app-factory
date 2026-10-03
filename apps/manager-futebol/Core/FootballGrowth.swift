import Foundation

// MARK: - Modelos de crescimento do clube

enum TVKind: String, Codable, CaseIterable, Identifiable {
    case basic, performance, premium

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return "Cota fixa"
        case .performance: return "Cota por desempenho"
        case .premium: return "Pay-per-view"
        }
    }

    var summary: String {
        switch self {
        case .basic: return "Valor garantido por jogo, sem surpresas."
        case .performance: return "Parte menor garantida e prêmio por vitória."
        case .premium: return "Garantia baixa e prêmio alto por vitória. Só vale para quem ganha muito."
        }
    }

    var symbol: String {
        switch self {
        case .basic: return "tv.fill"
        case .performance: return "chart.line.uptrend.xyaxis"
        case .premium: return "play.tv.fill"
        }
    }
}

struct TVContract: Codable, Equatable {
    var kind: TVKind
    var baseFactor: Double
    var winBonus: Int
    var endSeason: Int
}

struct TVOffer: Codable, Equatable, Identifiable {
    let id: Int
    let kind: TVKind
    let baseFactor: Double
    let winBonus: Int
    let seasons: Int
}

enum MarketingCampaign: String, Codable, CaseIterable, Identifiable {
    case localMedia, regionalTV, influencers, stadiumFest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localMedia: return "Mídia local"
        case .regionalTV: return "TV regional"
        case .influencers: return "Influenciadores"
        case .stadiumFest: return "Festa no estádio"
        }
    }

    var summary: String {
        switch self {
        case .localMedia: return "Rádio e jornal da cidade. Barato e constante."
        case .regionalTV: return "Comercial na TV da região: cresce torcida e marca."
        case .influencers: return "Parcerias nas redes: jovens torcedores e sócios."
        case .stadiumFest: return "Programação especial nos jogos em casa: clima de festa."
        }
    }

    var symbol: String {
        switch self {
        case .localMedia: return "radio.fill"
        case .regionalTV: return "tv.and.mediabox.fill"
        case .influencers: return "person.2.wave.2.fill"
        case .stadiumFest: return "party.popper.fill"
        }
    }

    var cost: Int {
        switch self {
        case .localMedia: return 60_000
        case .regionalTV: return 180_000
        case .influencers: return 120_000
        case .stadiumFest: return 150_000
        }
    }

    var days: Int {
        switch self {
        case .localMedia: return 4
        case .regionalTV: return 6
        case .influencers: return 5
        case .stadiumFest: return 4
        }
    }

    /// Crescimento da torcida por dia de jogo, em fração.
    var fanGrowth: Double {
        switch self {
        case .localMedia: return 0.0015
        case .regionalTV: return 0.0035
        case .influencers: return 0.0030
        case .stadiumFest: return 0.0010
        }
    }

    var moodPerDay: Int {
        switch self {
        case .stadiumFest: return 2
        case .influencers: return 1
        default: return 0
        }
    }

    var brandGain: Int {
        switch self {
        case .localMedia: return 3
        case .regionalTV: return 8
        case .influencers: return 6
        case .stadiumFest: return 4
        }
    }
}

struct ActiveCampaign: Codable, Equatable {
    var kind: MarketingCampaign
    var endsWorldDay: Int
}

enum SponsorSlot: String, Codable, CaseIterable, Identifiable {
    case sleeve, stadiumBoards, trainingKit, digital

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleeve: return "Manga da camisa"
        case .stadiumBoards: return "Placas do estádio"
        case .trainingKit: return "Uniforme de treino"
        case .digital: return "Parceiro digital"
        }
    }

    var symbol: String {
        switch self {
        case .sleeve: return "tshirt.fill"
        case .stadiumBoards: return "rectangle.3.group.fill"
        case .trainingKit: return "figure.run"
        case .digital: return "iphone.gen3"
        }
    }

    /// Valor-base por temporada para um clube médio.
    var baseValue: Int {
        switch self {
        case .sleeve: return 700_000
        case .stadiumBoards: return 550_000
        case .trainingKit: return 280_000
        case .digital: return 420_000
        }
    }
}

struct SlotOffer: Codable, Equatable, Identifiable {
    let id: Int
    let slot: SponsorSlot
    let sponsor: String
    let perSeason: Int
    let seasons: Int
}

struct SlotDeal: Codable, Equatable, Identifiable {
    let slot: SponsorSlot
    let sponsor: String
    let perSeason: Int
    var endSeason: Int

    var id: String { slot.rawValue }
}

enum YouthProgram: String, Codable, CaseIterable, Identifiable {
    case balanced, technical, physical, mental

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: return "Equilibrado"
        case .technical: return "Técnica"
        case .physical: return "Físico"
        case .mental: return "Mental"
        }
    }

    var summary: String {
        switch self {
        case .balanced: return "Desenvolvimento geral dos jovens."
        case .technical: return "Foco em passe, drible e finalização."
        case .physical: return "Foco em velocidade, resistência e força."
        case .mental: return "Foco em visão, decisão e posicionamento."
        }
    }

    var attributes: [AttributeKind] {
        switch self {
        case .balanced: return []
        case .technical: return [.passing, .dribbling, .finishing, .tackling]
        case .physical: return [.pace, .stamina, .strength]
        case .mental: return [.vision, .decisions, .positioning]
        }
    }
}

enum YouthCategory: String, CaseIterable, Identifiable {
    case under17, under20

    var id: String { rawValue }
    var title: String { self == .under17 ? "Sub-17" : "Sub-20" }
}

struct GrowthState: Codable, Equatable {
    var brand = 20
    var tv: TVContract? = nil
    var tvOffers: [TVOffer] = []
    var campaign: ActiveCampaign? = nil
    var campaignsDone = 0
    var slotOffers: [SlotOffer] = []
    var slotDeals: [SlotDeal] = []
    var youthProgram = YouthProgram.balanced
    var tryoutSeason = 0
    var lastPressureWarningDay = -10
    var nextID = 1
}

// MARK: - Regras

extension FootballCareer {
    static let tryoutBaseCost = 60_000

    // MARK: TV

    /// Cota de TV por dia de jogo antes do contrato escolhido.
    var baseTVPerMatchDay: Int {
        guard let selectedClubID, let club = selectedClub else { return 0 }
        return Int(Double(club.startingBudget) * (division(of: selectedClubID) == .serieA ? 0.012 : 0.006) / 10_000) * 10_000
    }

    var tvIncomePerMatchDay: Int {
        Int(Double(baseTVPerMatchDay) * (world.growth.tv?.baseFactor ?? 1.0) / 10_000) * 10_000
    }

    mutating func makeTVOffers() {
        let base = baseTVPerMatchDay
        func bonus(_ factor: Double) -> Int { max(10_000, Int(Double(base) * factor / 10_000) * 10_000) }
        let id = world.growth.nextID
        world.growth.nextID += 3
        world.growth.tvOffers = [
            TVOffer(id: id, kind: .basic, baseFactor: 1.05, winBonus: 0, seasons: 2),
            TVOffer(id: id + 1, kind: .performance, baseFactor: 0.80, winBonus: bonus(1.5), seasons: 1),
            TVOffer(id: id + 2, kind: .premium, baseFactor: 0.65, winBonus: bonus(2.8), seasons: 2)
        ]
    }

    @discardableResult
    mutating func signTV(offerID: Int) -> Bool {
        guard let offer = world.growth.tvOffers.first(where: { $0.id == offerID }), selectedClubID != nil else { return false }
        world.growth.tv = TVContract(kind: offer.kind, baseFactor: offer.baseFactor, winBonus: offer.winBonus, endSeason: season + offer.seasons - 1)
        world.growth.tvOffers = []
        return true
    }

    mutating func autoSignTVIfNeeded() {
        guard world.growth.tv == nil else { return }
        if world.growth.tvOffers.isEmpty { makeTVOffers() }
        if let basic = world.growth.tvOffers.first(where: { $0.kind == .basic }) { signTV(offerID: basic.id) }
    }

    mutating func settleTVWin() {
        guard let tv = world.growth.tv, tv.winBonus > 0 else { return }
        book(.tv, tv.winBonus, "Prêmio de TV por vitória")
    }

    // MARK: Marketing

    func canStartCampaign(_ kind: MarketingCampaign) -> String? {
        guard selectedClubID != nil, !isFired else { return "Sem clube." }
        if world.growth.campaign != nil { return "Já existe uma campanha em andamento." }
        if transferBudget < kind.cost { return "Caixa insuficiente: faltam \(FootballFormat.money(kind.cost - transferBudget))." }
        return nil
    }

    @discardableResult
    mutating func startCampaign(_ kind: MarketingCampaign) -> Bool {
        guard canStartCampaign(kind) == nil else { return false }
        book(.marketing, -kind.cost, "Campanha: \(kind.title)")
        world.growth.campaign = ActiveCampaign(kind: kind, endsWorldDay: worldDay + kind.days)
        bump("campaigns")
        return true
    }

    // MARK: Cotas de patrocínio

    mutating func makeSlotOffers(using random: inout FootballRandom) {
        guard let club = selectedClub else { return }
        let owned = Set(world.growth.slotDeals.map(\.slot))
        let fans = Double(fanBase) / (Double(club.capacity) * 1.15)
        let brandFactor = 0.7 + Double(world.growth.brand) / 100 * 0.6
        let division = selectedClubID.map { self.division(of: $0) } ?? .serieA
        var names = Self.sponsorNames
        var offers: [SlotOffer] = []
        for slot in SponsorSlot.allCases where !owned.contains(slot) {
            guard !names.isEmpty else { break }
            let name = names.remove(at: random.int(in: 0...(names.count - 1)))
            let value = Double(slot.baseValue) * fans * brandFactor * (division == .serieA ? 1.0 : 0.6) * (0.85 + random.unit() * 0.35)
            offers.append(SlotOffer(id: world.growth.nextID, slot: slot, sponsor: name, perSeason: Int(value / 5_000) * 5_000, seasons: random.int(in: 1...3)))
            world.growth.nextID += 1
        }
        world.growth.slotOffers = offers
    }

    @discardableResult
    mutating func acceptSlotOffer(_ id: Int) -> Bool {
        guard let offer = world.growth.slotOffers.first(where: { $0.id == id }),
              !world.growth.slotDeals.contains(where: { $0.slot == offer.slot }) else { return false }
        world.growth.slotDeals.append(SlotDeal(slot: offer.slot, sponsor: offer.sponsor, perSeason: offer.perSeason, endSeason: season + offer.seasons - 1))
        world.growth.slotOffers.removeAll { $0.id == id }
        return true
    }

    var slotIncomePerSeason: Int { world.growth.slotDeals.reduce(0) { $0 + $1.perSeason } }

    // MARK: Pressão da torcida

    /// De 0 a 100: o quanto torcida, diretoria e imprensa cobram o treinador agora.
    var fanPressure: Int {
        guard let selectedClubID else { return 0 }
        var pressure = 30.0
        if matchDayIndex >= 4, let position = userPosition {
            pressure += Double(max(-2, min(5, position - boardTarget))) * 6
        }
        pressure += Double(50 - fanMood) / 2
        let recent = form(teamID: selectedClubID).suffix(3)
        pressure += Double(recent.filter { $0 == .loss }.count) * 8 - Double(recent.filter { $0 == .win }.count) * 6
        pressure += Double(clubPrestige(selectedClubID) - 70) * 0.8
        if boardConfidence < 35 { pressure += 10 }
        return Int(max(0, min(100, pressure.rounded())))
    }

    var pressureLabel: String {
        switch fanPressure {
        case ..<30: return "Tranquila"
        case 30..<55: return "Moderada"
        case 55..<75: return "Alta"
        default: return "Sufocante"
        }
    }

    /// Efeito do estádio nos jogos em casa: lotado e feliz empurra o time, vazio e irritado pesa.
    var stadiumAtmosphere: Double {
        guard stadiumCapacity > 0, let fixture = nextUserFixture, let selectedClubID, fixture.home == selectedClubID else { return 0 }
        let fill = Double(attendance(for: fixture)) / Double(stadiumCapacity)
        return max(-0.4, min(0.6, (Double(fanMood) - 50) / 100 * 1.2 + (fill - 0.7) * 0.8))
    }

    mutating func tickPressure() {
        guard selectedClubID != nil, !isFired else { return }
        let pressure = fanPressure
        if pressure >= 75 {
            world.coach.stress = min(100, world.coach.stress + 3)
            for index in players.indices where players[index].teamID == selectedClubID && !players[index].isYouth && players[index].attributes[.determination] <= 9 {
                players[index].morale = max(0, players[index].morale - 1)
            }
            if worldDay - world.growth.lastPressureWarningDay >= 4 {
                world.growth.lastPressureWarningDay = worldDay
                addInbox(.board, title: "Pressão sufocante", body: "Torcida e imprensa cobram resultado. Atletas menos determinados sentem o peso. Uma boa vitória ou uma campanha de marketing pode aliviar o clima.")
            }
        } else if pressure <= 25 {
            fanMood = min(100, fanMood + 1)
        }
    }

    // MARK: Categorias de base

    func youthCategory(of player: FootballPlayer) -> YouthCategory { player.age <= 17 ? .under17 : .under20 }

    func youth(in category: YouthCategory) -> [FootballPlayer] {
        youthRoster.filter { youthCategory(of: $0) == category }
    }

    mutating func setYouthProgram(_ program: YouthProgram) { world.growth.youthProgram = program }

    /// Evolução diária dos jovens da base, mais forte com academia e técnico da base melhores.
    mutating func tickYouthDevelopment(using random: inout FootballRandom) {
        guard let selectedClubID else { return }
        let chance = 0.03 + 0.01 * Double(youthAcademyLevel) + 0.005 * Double(max(0, (staffAbility(.youthCoach) ?? 6) - 6))
        let program = world.growth.youthProgram
        for index in players.indices where players[index].isYouth && players[index].teamID == selectedClubID {
            guard players[index].overall < players[index].potential, random.chance(chance) else { continue }
            if program != .balanced, let kind = random.pick(program.attributes), players[index].attributes[kind] < 20 {
                players[index].attributes[kind] += 1
                players[index].overall = players[index].attributes.overall(for: players[index].position)
            } else {
                players[index].setOverall(players[index].overall + 1)
            }
        }
    }

    var tryoutCost: Int { Self.tryoutBaseCost + 20_000 * youthAcademyLevel }

    func canHoldTryout() -> String? {
        guard selectedClubID != nil, !isFired else { return "Sem clube." }
        if world.growth.tryoutSeason == season { return "A peneira já foi realizada nesta temporada." }
        if youthRoster.count + 2 > Self.youthRosterLimit { return "A base está cheia: dispense ou promova jovens." }
        if transferBudget < tryoutCost { return "Caixa insuficiente." }
        return nil
    }

    @discardableResult
    mutating func holdTryout(region: Int?) -> [FootballPlayer] {
        guard canHoldTryout() == nil, let selectedClubID else { return [] }
        var random = FootballRandom(seed: matchSeed(stream: .offseason, id: 61_000 + season * 13 + (region ?? 9)))
        book(.academy, -tryoutCost, "Peneira de novos talentos")
        world.growth.tryoutSeason = season
        let strength = (selectedClub?.strength ?? 65) + (division(of: selectedClubID) == .serieA ? 2 : -2)
        let positions: [FootballPosition] = [.goalkeeper, .defender, .midfielder, .forward]
        var found: [FootballPlayer] = []
        for _ in 0..<2 {
            let position = random.pick(positions) ?? .midfielder
            var youth = FootballSeason.makeYouth(id: nextPlayerID, position: position, teamStrength: strength, teamID: selectedClubID,
                                                 season: season, quality: youthAcademyLevel + 1 + staffBonus(.youthCoach), using: &random)
            if let region { youth.region = region }
            youth.isYouth = true
            players.append(youth)
            nextPlayerID += 1
            found.append(youth)
        }
        addInbox(.general, title: "Peneira concluída", body: "\(found.map(\.name).joined(separator: " e ")) entraram na base.")
        bump("tryouts")
        return found
    }

    // MARK: Ritmo diário e de temporada

    mutating func ensureGrowthOffers(using random: inout FootballRandom) {
        if world.growth.tv == nil && world.growth.tvOffers.isEmpty { makeTVOffers() }
        if world.growth.slotOffers.isEmpty { makeSlotOffers(using: &random) }
    }

    mutating func tickGrowth(using random: inout FootballRandom) {
        guard selectedClubID != nil, !isFired else { return }
        let days = FootballSeason.matchDaysPerSeason
        for deal in world.growth.slotDeals {
            book(.sponsor, deal.perSeason / days, "Cota \(deal.slot.title): \(deal.sponsor)")
        }
        if let campaign = world.growth.campaign {
            fanBase += Int(Double(fanBase) * campaign.kind.fanGrowth)
            if campaign.kind.moodPerDay > 0 { fanMood = min(100, fanMood + campaign.kind.moodPerDay) }
            if worldDay >= campaign.endsWorldDay {
                world.growth.brand = min(100, world.growth.brand + campaign.kind.brandGain)
                world.growth.campaign = nil
                world.growth.campaignsDone += 1
                addInbox(.general, title: "Campanha encerrada", body: "\(campaign.kind.title) terminou: marca do clube em \(world.growth.brand).")
            }
        } else if matchDayIndex % 6 == 0 {
            world.growth.brand = max(0, world.growth.brand - 1)
        }
        tickYouthDevelopment(using: &random)
        tickPressure()
    }

    mutating func closeGrowthSeason() {
        if let tv = world.growth.tv, tv.endSeason <= season { world.growth.tv = nil }
        world.growth.slotDeals.removeAll { $0.endSeason <= season }
        fanBase += Int(Double(fanBase) * Double(world.growth.brand) / 4_000)
    }

    mutating func prepareGrowthSeason(using random: inout FootballRandom) {
        guard selectedClubID != nil else { return }
        if world.growth.tv == nil { makeTVOffers() }
        makeSlotOffers(using: &random)
    }
}
