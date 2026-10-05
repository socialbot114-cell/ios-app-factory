import Foundation

extension FootballCareer {
    static let maxPrograms = 3
    static let friendlyLimit = 4

    // MARK: - Loja do clube

    var shopRevenueFactor: Double {
        [0.0, 1.0, 1.4, 1.9, 2.5][min(max(world.business.shopLevel, 1), 4)]
    }

    var collectionActive: Bool { world.business.collectionUntilWorldDay >= worldDay || activeCollection != nil }

    func shopUpgradeCost() -> Int? {
        guard world.business.shopLevel < 4, let club = selectedClub else { return nil }
        return Int(Double(club.startingBudget) * 0.08 * Double(world.business.shopLevel) / 10_000) * 10_000
    }

    @discardableResult
    mutating func upgradeShop() -> Bool {
        guard let cost = shopUpgradeCost(), transferBudget >= cost else { return false }
        book(.merchandise, -cost, "Ampliação da loja do clube")
        let previous = world.business.shopLevel
        world.business.shopLevel += 1
        openLedger(.shopUpgrade, key: Self.shopUpgradeKey(level: world.business.shopLevel), title: "Ampliação da loja (nível \(world.business.shopLevel))",
                   unit: .money, invested: cost, forecastPerDay: Double(shopUpliftToday(fromLevel: previous, toLevel: world.business.shopLevel)),
                   horizonDays: FootballSeason.matchDaysPerSeason)
        return true
    }

    func collectionCost() -> Int { 40_000 * world.business.shopLevel }

    /// Atalho com o briefing mais simples; o projeto completo fica em `launchCollection(_:)`.
    @discardableResult
    mutating func launchCollection() -> Bool {
        launchCollection(CollectionBrief(audience: .traditional, size: .capsule))
    }

    mutating func setShopPrice(_ price: ShopPrice) {
        world.business.shopPrice = price
    }

    /// Vendas da loja a cada dia de jogo.
    var merchRevenuePerMatchDay: Int {
        baseMerchRevenuePerMatchDay + (activeCollection.map { collectionExtra($0.brief) } ?? 0)
    }

    // MARK: - Naming rights

    var stadiumDisplayName: String {
        world.business.naming?.stadiumName ?? selectedClub?.stadium ?? "Estádio"
    }

    mutating func refreshNamingOffers(using random: inout FootballRandom) {
        guard world.business.naming == nil, let club = selectedClub else { world.business.namingOffers = []; return }
        let reputation = Double(fanBase) / (Double(club.capacity) * 1.15)
        var brands = Self.brands
        var offers: [NamingRightsOffer] = []
        for (index, years) in [3, 5, 2].enumerated() {
            let brand = brands.remove(at: random.int(in: 0...(brands.count - 1)))
            let perSeason = Int(Double(stadiumCapacity) * 14 * [1.0, 1.25, 0.8][index] * reputation / 10_000) * 10_000
            offers.append(NamingRightsOffer(id: world.business.nextID, sponsor: brand, stadiumName: "Arena \(brand)", perSeason: perSeason, seasons: years))
            world.business.nextID += 1
        }
        world.business.namingOffers = offers
    }

    @discardableResult
    mutating func acceptNamingOffer(_ id: Int) -> Bool {
        guard let offer = world.business.namingOffers.first(where: { $0.id == id }), world.business.naming == nil else { return false }
        world.business.naming = NamingRightsDeal(sponsor: offer.sponsor, stadiumName: offer.stadiumName, perSeason: offer.perSeason, endSeason: season + offer.seasons - 1)
        world.business.namingOffers = []
        fanMood = max(0, fanMood - 2)
        openLedger(.naming, key: "naming", title: "Naming rights \(offer.sponsor)", unit: .money,
                   forecastPerDay: Double(offer.perSeason / FootballSeason.matchDaysPerSeason),
                   horizonDays: offer.seasons * FootballSeason.matchDaysPerSeason)
        return true
    }

    // MARK: - Ações sociais

    func canToggle(_ program: CommunityProgram) -> String? {
        if world.business.programs.contains(program) { return nil }
        if world.business.programs.count >= Self.maxPrograms { return "No máximo \(Self.maxPrograms) programas ao mesmo tempo." }
        if transferBudget < program.costPerSeason / 4 { return "Caixa insuficiente." }
        return nil
    }

    @discardableResult
    mutating func toggle(_ program: CommunityProgram) -> Bool {
        if let index = world.business.programs.firstIndex(of: program) {
            world.business.programs.remove(at: index)
            closeLedger(key: program.rawValue)
            return true
        }
        guard canToggle(program) == nil else { return false }
        world.business.programs.append(program)
        let promise: (ProjectLedgerUnit, Double) = {
            switch program {
            case .schoolProject: return (.fans, Double(fanBase) * 0.0006)
            case .fanClubs: return (.fans, Double(fanBase) * 0.0012)
            case .footballAcademy: return (.talents, 0.02)
            case .hospitalVisits: return (.reputation, 0.08)
            }
        }()
        openLedger(.program, key: program.rawValue, title: program.title, unit: promise.0, forecastPerDay: promise.1)
        bump("community")
        return true
    }

    // MARK: - Amistosos e excursão

    func canPlayFriendly() -> String? {
        guard selectedClubID != nil, !isFired, liveMatch == nil, !isSeasonComplete else { return "Indisponível agora." }
        guard world.business.friendliesThisSeason < Self.friendlyLimit else { return "Limite de \(Self.friendlyLimit) amistosos por temporada." }
        guard matchDayIndex == 0 || canAdvanceWithoutPlaying else { return "Amistosos só em pré-temporada ou em datas livres do calendário." }
        return nil
    }

    @discardableResult
    mutating func playFriendly(opponentID: Int, home: Bool) -> FriendlyRecord? {
        guard canPlayFriendly() == nil, let selectedClubID, opponentID != selectedClubID, FootballSeason.team(opponentID) != nil else { return nil }
        let savedPrep = opponentPrep
        opponentPrep = false
        defer { opponentPrep = savedPrep }
        let fixture = LeagueFixture(id: 900_000 + world.business.nextID, matchDay: matchDayIndex, round: 0, competition: .league(division(of: selectedClubID)),
                                    home: home ? selectedClubID : opponentID, away: home ? opponentID : selectedClubID)
        let homeSide = makeSideState(teamID: fixture.home, rivalID: fixture.away, isUser: fixture.home == selectedClubID)
        let awaySide = makeSideState(teamID: fixture.away, rivalID: fixture.home, isUser: fixture.away == selectedClubID)
        var sim = MatchSimulation.make(fixtureID: fixture.id, seed: matchSeed(stream: .business, id: fixture.id), isCup: false, isDerby: false,
                                       detailed: false, home: homeSide, away: awaySide)
        let allPlayers = playersByID()
        sim.runToEnd(players: allPlayers)
        let ownGoals = home ? sim.home.goals : sim.away.goals
        let otherGoals = home ? sim.away.goals : sim.home.goals
        var random = FootballRandom(seed: matchSeed(stream: .business, id: fixture.id + 7))
        // Desgaste menor que o de um jogo oficial; lesões menos frequentes.
        let ownState = home ? sim.home : sim.away
        for id in ownState.appeared {
            guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
            let final = Int(ownState.matchCondition[id] ?? Double(players[index].condition))
            players[index].condition = max(40, players[index].condition - max(0, (players[index].condition - final) / 2))
            if ownGoals > otherGoals { players[index].morale = min(100, players[index].morale + 1) }
        }
        for (id, rounds) in ownState.injuries where random.chance(0.5) {
            if let index = players.firstIndex(where: { $0.id == id }) { players[index].injuryRounds = max(players[index].injuryRounds, max(1, rounds / 2)) }
        }
        var revenue = 0
        if home { revenue = Int(Double(gateRevenue(attendance: Int(Double(stadiumCapacity) * 0.55))) * 0.7) } else { revenue = 25_000 }
        book(.other, revenue, "Amistoso contra \(FootballSeason.teamName(opponentID))")
        let record = FriendlyRecord(id: world.business.nextID, season: season, opponentID: opponentID, home: home, goalsFor: ownGoals, goalsAgainst: otherGoals, revenue: revenue)
        world.business.nextID += 1
        world.business.friendlies.insert(record, at: 0)
        if world.business.friendlies.count > 20 { world.business.friendlies.removeLast() }
        world.business.friendliesThisSeason += 1
        repairLineup()
        bump("friendlies")
        return record
    }

    func canDoTour() -> String? {
        guard matchDayIndex == 0, world.business.tourDoneSeason != season else { return "A excursão só acontece na pré-temporada, uma vez por temporada." }
        guard let club = selectedClub, transferBudget >= club.startingBudget / 40 else { return "Caixa insuficiente." }
        return nil
    }

    @discardableResult
    mutating func doPreseasonTour() -> Bool {
        guard canDoTour() == nil, let club = selectedClub else { return false }
        book(.other, -(club.startingBudget / 40), "Excursão de pré-temporada")
        world.business.tourDoneSeason = season
        fanBase = Int(Double(fanBase) * 1.03)
        world.social.clubFollowers = Int(Double(world.social.clubFollowers) * 1.05)
        for index in players.indices where players[index].teamID == selectedClubID && !players[index].isYouth {
            players[index].condition = max(40, players[index].condition - 6)
            players[index].morale = min(100, players[index].morale + 2)
        }
        bump("tours")
        return true
    }

    // MARK: - Agentes

    static let agentNames = ["Fábio Agenciador", "Marta Representações", "Sports Brasil Mgmt", "Duda Intermediações", "Grupo Craque 10"]

    mutating func generateAgentOffers(using random: inout FootballRandom) {
        let today = worldDay
        world.business.agentOffers.removeAll { $0.expiresWorldDay < today }
        guard transferWindow != nil, world.business.agentOffers.count < 2, random.chance(0.35) else { return }
        let offeredIDs = Set(world.business.agentOffers.map(\.playerID))
        let candidates = marketPlayers.filter { $0.overall >= 68 && !offeredIDs.contains($0.id) }
        guard let target = random.pick(candidates) else { return }
        let agent = Self.agentNames[random.int(in: 0...(Self.agentNames.count - 1))]
        world.business.agentOffers.append(AgentOffer(id: world.business.nextID, playerID: target.id, agentName: agent,
                                                     discountedWage: Int(Double(target.contract.wage) * 0.88 / 5_000) * 5_000,
                                                     agentFee: Int(Double(target.marketValue) * 0.06 / 10_000) * 10_000, expiresWorldDay: worldDay + 3))
        world.business.nextID += 1
        addInbox(.agent, title: "\(agent) oferece \(target.name)", body: "O agente apresenta \(target.name) (\(target.position.rawValue), geral \(target.overall)) com salário reduzido, mediante comissão.",
                 playerID: target.id, offerID: world.business.nextID - 1)
    }

    @discardableResult
    mutating func acceptAgentOffer(_ id: Int) -> Bool {
        guard let offerIndex = world.business.agentOffers.firstIndex(where: { $0.id == id }) else { return false }
        let offer = world.business.agentOffers[offerIndex]
        guard let player = player(offer.playerID), player.teamID == nil, canSign(playerID: offer.playerID), transferBudget >= player.marketValue + offer.agentFee else { return false }
        guard signPlayer(playerID: offer.playerID) else { return false }
        if let index = players.firstIndex(where: { $0.id == offer.playerID }) {
            players[index].contract.wage = offer.discountedWage
            var random = FootballRandom(seed: matchSeed(stream: .business, id: offer.playerID))
            if random.chance(0.3) {
                players[index].attributes[.professionalism] = 4
                addInbox(.general, title: "Relatos sobre \(players[index].name)", body: "Depois da assinatura, surgiram relatos de indisciplina em clubes anteriores.", playerID: offer.playerID)
            }
        }
        book(.other, -offer.agentFee, "Comissão do agente \(offer.agentName)")
        world.business.agentOffers.remove(at: offerIndex)
        for index in inbox.indices where inbox[index].kind == .agent && inbox[index].offerID == id { inbox[index].isResolved = true }
        return true
    }

    // MARK: - Dia a dia dos negócios

    mutating func tickBusiness(using random: inout FootballRandom) {
        guard selectedClubID != nil, !isFired else { return }
        book(.merchandise, baseMerchRevenuePerMatchDay, "Vendas da loja do clube")
        applyShopPriceMood()
        progressCollections()
        runCommercialDelegation()
        if let deal = world.business.naming {
            book(.naming, deal.perSeason / FootballSeason.matchDaysPerSeason, "Naming rights \(deal.sponsor)")
            recordLedger(key: "naming", Double(deal.perSeason / FootballSeason.matchDaysPerSeason))
        }
        for entry in world.commercial.ledger where entry.kind == .shopUpgrade && !entry.closed && entry.clubID == selectedClubID {
            let level = Int(entry.key.dropFirst("shop-".count)) ?? world.business.shopLevel
            recordLedger(key: entry.key, Double(shopUpliftToday(fromLevel: level - 1, toLevel: level)))
        }
        for program in world.business.programs {
            book(.community, -(program.costPerSeason / FootballSeason.matchDaysPerSeason), program.title)
            switch program {
            case .schoolProject:
                let gained = Int(Double(fanBase) * 0.0006)
                fanBase += gained
                recordLedger(key: program.rawValue, Double(gained))
                if random.chance(0.2) { fanMood = min(100, fanMood + 1) }
            case .footballAcademy:
                if random.chance(0.02) {
                    apply(.discoverYouth, playerID: nil, using: &random)
                    recordLedger(key: program.rawValue, 1)
                }
            case .hospitalVisits:
                if random.chance(0.08) {
                    changeReputation(1)
                    recordLedger(key: program.rawValue, 1)
                }
                if random.chance(0.15) { fanMood = min(100, fanMood + 1) }
            case .fanClubs:
                let gained = Int(Double(fanBase) * 0.0012)
                fanBase += gained
                recordLedger(key: program.rawValue, Double(gained))
            }
        }
        advanceLedgerDay()
        generateAgentOffers(using: &random)
        progressBoardMeetings()
        runPersonalPlan()
    }

    mutating func closeBusinessSeason(using random: inout FootballRandom) {
        closeBoardSeason()
        closePersonalPlanSeason()
        world.business.friendliesThisSeason = 0
        if let deal = world.business.naming, deal.endSeason <= season {
            world.business.naming = nil
            closeLedger(key: "naming")
        }
        refreshNamingOffers(using: &random)
        world.business.agentOffers = []
    }
}
