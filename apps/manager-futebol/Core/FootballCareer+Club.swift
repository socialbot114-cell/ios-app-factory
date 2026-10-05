import Foundation

extension FootballCareer {
    static let maxFacilityLevel = 5
    static let individualProgramLimit = 3
    static let perFanRevenue = 3.2

    // MARK: - Início de carreira

    /// Define estrutura, torcida, patrocínio e comissão técnica iniciais do clube escolhido.
    mutating func setupClubInfrastructure() {
        guard let selectedClubID, let club = selectedClub else { return }
        // Contratos iniciais do elenco principal duram de 2 a 4 temporadas, para a primeira temporada ser estável.
        for index in players.indices where players[index].teamID == selectedClubID && !players[index].isYouth {
            players[index].contract.endSeason = max(players[index].contract.endSeason, season + 1 + (players[index].id % 3))
        }
        let top = division(of: selectedClubID) == .serieA
        trainingCenterLevel = top ? 3 : 2
        medicalLevel = top ? 3 : 2
        youthAcademyLevel = top ? 3 : 2
        stadiumLevel = 1
        upgradeProject = nil
        ticketPrice = .normal
        fanBase = Int(Double(club.capacity) * 1.15)
        redMatchDays = 0
        opponentPrep = false
        secondaryTrainingFocus = nil
        var random = FootballRandom(seed: matchSeed(stream: .offseason, id: 31_000 + selectedClubID))
        staff = []
        staffMarket = []
        for (role, ability) in [(StaffRole.assistant, top ? 9 : 8), (.fitnessCoach, top ? 8 : 7), (.doctor, top ? 8 : 7)] {
            staff.append(makeStaffMember(role: role, ability: ability, using: &random))
        }
        refreshStaffMarket(using: &random)
        sponsorOffers = makeSponsorOffers(using: &random)
        if let balanced = sponsorOffers.first(where: { $0.profile == "Equilibrado" }) { signSponsor(balanced) }
        setupSocial()
        ensureTipsters()
        world.growth = GrowthState()
        ensureGrowthOffers(using: &random)
        ensureContacts()
    }

    // MARK: - Estádio e bilheteria

    var stadiumCapacity: Int {
        guard let club = selectedClub else { return 0 }
        return Int(Double(club.capacity) * (1 + 0.08 * Double(stadiumLevel - 1)))
    }

    func attendance(for fixture: LeagueFixture) -> Int {
        guard let club = selectedClub else { return 0 }
        var demand = 0.62 + 0.0045 * Double(fanMood)
        if let opponent = FootballSeason.team(fixture.opponent(of: club.id)) {
            demand *= 0.92 + Double(opponent.strength - 65) * 0.006
        }
        if FootballSeason.isDerby(fixture.home, fixture.away) { demand *= 1.15 }
        if fixture.competition.isCup { demand *= 1.08 }
        demand *= ticketPrice.demandFactor * hypeAttendanceFactor
        let potential = Int(Double(fanBase) * demand)
        let floor = Int(Double(stadiumCapacity) * 0.18)
        return min(stadiumCapacity, max(floor, potential))
    }

    func gateRevenue(attendance: Int) -> Int {
        Int(Double(attendance) * Self.perFanRevenue * ticketPrice.revenueMultiplier / 100) * 100
    }

    var members: Int {
        Int(Double(fanBase) * 0.2 * (0.6 + 0.006 * Double(fanMood)))
    }

    // MARK: - Receitas e despesas de cada dia de jogo

    /// Receitas de todo dia de jogo: TV, sócios e patrocínio (a bilheteria é lançada com a partida em casa).
    mutating func collectMatchDayIncome() {
        guard let selectedClubID, let club = selectedClub else { return }
        book(.tv, tvIncomePerMatchDay, "Cotas de TV")
        book(.members, Int(Double(members) * 1.4 / 100) * 100, "Mensalidades dos sócios-torcedores")
        if let deal = sponsorDeal {
            book(.sponsor, deal.fixedPerSeason / FootballSeason.matchDaysPerSeason, "Patrocínio \(deal.sponsor)")
        }
    }

    /// Salários da comissão, manutenção da estrutura e juros da dívida.
    mutating func chargeOperatingCosts() {
        guard let club = selectedClub else { return }
        let staffShare = staff.reduce(0) { $0 + $1.wage } / FootballSeason.matchDaysPerSeason
        book(.staff, -staffShare, "Salários da comissão técnica")
        let levels = trainingCenterLevel + medicalLevel + youthAcademyLevel + stadiumLevel
        let upkeep = Int(Double(club.startingBudget) * 0.004 * Double(levels) / Double(FootballSeason.matchDaysPerSeason) / 100) * 100
        book(.facilities, -upkeep, "Manutenção da estrutura")
        if transferBudget < 0 {
            book(.interest, -Int(Double(-transferBudget) * 0.02), "Juros da dívida")
            redMatchDays += 1
            boardConfidence = max(0, boardConfidence - 2)
        } else {
            redMatchDays = 0
        }
    }

    var isTransferBanned: Bool { redMatchDays >= 6 }

    var isInDebt: Bool { transferBudget < 0 }

    // MARK: - Relatórios

    func monthReports(season targetSeason: Int) -> [MonthReport] {
        let entries = finance.entries(season: targetSeason)
        guard !entries.isEmpty else { return [] }
        func month(_ entry: FinanceEntry) -> Int { max(0, entry.matchDay - 1) / 4 + 1 }
        let months = Set(entries.map(month)).sorted()
        var reports: [MonthReport] = []
        for value in months {
            let inMonth = entries.filter { month($0) == value }
            let after = entries.filter { month($0) > value }.reduce(0) { $0 + $1.amount }
            reports.append(MonthReport(month: value,
                                       income: inMonth.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount },
                                       expenses: -inMonth.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount },
                                       closingCash: transferBudget - after))
        }
        return reports
    }

    /// Caixa estimado no fim da temporada, com base no fluxo recorrente dos dias de jogo já disputados.
    var projectedSeasonEndCash: Int {
        let recurring: Set<FinanceCategory> = [.gate, .members, .tv, .sponsor, .wages, .staff, .facilities, .interest]
        let played = max(1, matchDayIndex)
        let net = finance.entries(season: season).filter { recurring.contains($0.category) }.reduce(0) { $0 + $1.amount }
        let remaining = max(0, FootballSeason.matchDaysPerSeason - matchDayIndex)
        return transferBudget + net / played * remaining
    }

    // MARK: - Patrocínio

    static let sponsorNames = ["Bancorte", "Aço Brasil", "Via Rápida", "Cervejaria Sol", "TelNova", "Boa Compra Supermercados",
                               "Energia Sul", "Construtora Horizonte", "Seguros Aliança", "Mineração Serra Dourada"]

    func makeSponsorOffers(using random: inout FootballRandom) -> [SponsorOffer] {
        guard let club = selectedClub, let selectedClubID else { return [] }
        let reputation = Double(fanBase) / (Double(club.capacity) * 1.15)
        let scale = Double(club.startingBudget) * reputation * (division(of: selectedClubID) == .serieA ? 1.0 : 0.75)
        var names = Self.sponsorNames
        func nextName() -> String {
            let index = random.int(in: 0...(names.count - 1))
            return names.remove(at: index)
        }
        func round(_ value: Double) -> Int { Int(value / 10_000) * 10_000 }
        return [
            SponsorOffer(id: season * 10 + 1, sponsor: nextName(), fixedPerSeason: round(scale * 0.13), bonusPerWin: 0, titleBonus: 0, seasons: 1, profile: "Seguro"),
            SponsorOffer(id: season * 10 + 2, sponsor: nextName(), fixedPerSeason: round(scale * 0.09), bonusPerWin: round(scale * 0.004), titleBonus: round(scale * 0.05), seasons: 2, profile: "Equilibrado"),
            SponsorOffer(id: season * 10 + 3, sponsor: nextName(), fixedPerSeason: round(scale * 0.05), bonusPerWin: round(scale * 0.009), titleBonus: round(scale * 0.12), seasons: 1, profile: "Arriscado")
        ]
    }

    @discardableResult
    mutating func signSponsor(_ offer: SponsorOffer) -> Bool {
        sponsorDeal = SponsorDeal(sponsor: offer.sponsor, fixedPerSeason: offer.fixedPerSeason, bonusPerWin: offer.bonusPerWin,
                                  titleBonus: offer.titleBonus, endSeason: season + offer.seasons - 1)
        sponsorOffers = []
        return true
    }

    @discardableResult
    mutating func acceptSponsorOffer(_ offerID: Int) -> Bool {
        guard let offer = sponsorOffers.first(where: { $0.id == offerID }) else { return false }
        return signSponsor(offer)
    }

    // MARK: - Estrutura

    func facilityLevel(_ kind: FacilityKind) -> Int {
        switch kind {
        case .trainingCenter: return trainingCenterLevel
        case .youthAcademy: return youthAcademyLevel
        case .medical: return medicalLevel
        case .stadium: return stadiumLevel
        }
    }

    func upgradeCost(for kind: FacilityKind) -> Int? {
        let level = facilityLevel(kind)
        guard level < Self.maxFacilityLevel, let club = selectedClub else { return nil }
        let factor = (0.10 + 0.06 * Double(level)) * (kind == .stadium ? 1.6 : 1.0)
        return Int(Double(club.startingBudget) * factor / 10_000) * 10_000
    }

    func upgradeDuration(for kind: FacilityKind) -> Int { 4 + 2 * facilityLevel(kind) }

    func canStartUpgrade(_ kind: FacilityKind) -> String? {
        guard selectedClubID != nil, !isFired else { return "Sem clube." }
        guard let cost = upgradeCost(for: kind) else { return "Nível máximo." }
        guard upgradeProject == nil else { return "Já há uma obra em andamento." }
        guard transferBudget >= cost else { return "Caixa insuficiente: a obra custa \(FootballFormat.money(cost))." }
        return nil
    }

    @discardableResult
    mutating func startUpgrade(_ kind: FacilityKind) -> Bool {
        guard canStartUpgrade(kind) == nil, let cost = upgradeCost(for: kind) else { return false }
        let target = facilityLevel(kind) + 1
        var dueDay = matchDayIndex + upgradeDuration(for: kind)
        var dueSeason = season
        if dueDay >= FootballSeason.matchDaysPerSeason { dueDay -= FootballSeason.matchDaysPerSeason; dueSeason += 1 }
        book(.facilities, -cost, "Obra: \(kind.title) nível \(target)")
        upgradeProject = UpgradeProject(id: nextProjectID, kind: kind, targetLevel: target, cost: cost, dueSeason: dueSeason, dueMatchDay: dueDay)
        nextProjectID += 1
        return true
    }

    /// Conclui a obra quando o prazo chega.
    mutating func progressUpgrades() {
        guard let project = upgradeProject else { return }
        guard season > project.dueSeason || (season == project.dueSeason && matchDayIndex >= project.dueMatchDay) else { return }
        switch project.kind {
        case .trainingCenter: trainingCenterLevel = project.targetLevel
        case .youthAcademy: youthAcademyLevel = project.targetLevel
        case .medical: medicalLevel = project.targetLevel
        case .stadium: stadiumLevel = project.targetLevel
        }
        upgradeProject = nil
        addInbox(.finance, title: "Obra concluída", body: "\(project.kind.title) agora está no nível \(project.targetLevel).")
    }

    var trainingFacilityFactor: Double { 0.88 + 0.06 * Double(trainingCenterLevel - 1) }

    // MARK: - Comissão técnica

    static let staffFirstNames = ["Wagner", "Cláudio", "Sérgio", "Marcelo", "Ricardo", "Fernando", "Alberto", "Paulo", "Roberto", "Luciano", "Eduardo", "Henrique"]
    static let staffLastNames = ["Moreira", "Santana", "Pires", "Cunha", "Barreto", "Camargo", "Dias", "Ferraz", "Lopes", "Medeiros", "Nogueira", "Tavares"]

    mutating func makeStaffMember(role: StaffRole, ability: Int, using random: inout FootballRandom) -> StaffMember {
        let first = Self.staffFirstNames[random.int(in: 0...(Self.staffFirstNames.count - 1))]
        let last = Self.staffLastNames[random.int(in: 0...(Self.staffLastNames.count - 1))]
        let wage = Int((40_000 + Double(ability) * 14_000) / 5_000) * 5_000
        let member = StaffMember(id: nextStaffID, name: "\(first) \(last)", role: role, ability: ability, wage: wage)
        nextStaffID += 1
        return member
    }

    mutating func refreshStaffMarket(using random: inout FootballRandom) {
        guard selectedClubID != nil else { return }
        let top = userDivision == .serieA
        staffMarket = []
        for role in StaffRole.allCases {
            for _ in 0..<3 {
                let ability = top ? random.int(in: 8...18) : random.int(in: 6...15)
                staffMarket.append(makeStaffMember(role: role, ability: ability, using: &random))
            }
        }
    }

    func staffCandidates(for role: StaffRole) -> [StaffMember] {
        staffMarket.filter { $0.role == role }.sorted { $0.ability > $1.ability }
    }

    @discardableResult
    mutating func hireStaff(candidateID: Int) -> Bool {
        guard let index = staffMarket.firstIndex(where: { $0.id == candidateID }), !isFired else { return false }
        let candidate = staffMarket[index]
        if let current = staffMember(candidate.role) { fireStaff(id: current.id) }
        staff.append(candidate)
        staffMarket.remove(at: index)
        return true
    }

    @discardableResult
    mutating func fireStaff(id: Int) -> Bool {
        guard let index = staff.firstIndex(where: { $0.id == id }) else { return false }
        let member = staff.remove(at: index)
        book(.staff, -Int(Double(member.wage) * 0.4 / 5_000) * 5_000, "Rescisão de \(member.name)")
        return true
    }

    // MARK: - Efeitos da comissão e da estrutura

    var assistantAbilityValue: Int { staffAbility(.assistant) ?? 6 }
    var fitnessAbilityValue: Int { staffAbility(.fitnessCoach) ?? 6 }
    var doctorAbilityValue: Int { staffAbility(.doctor) ?? 6 }
    var hasAnalyst: Bool { staffAbility(.analyst) != nil }

    /// Duração das lesões: depende do departamento médico e do médico contratado.
    var injuryDurationFactor: Double {
        let facility = 1 - 0.035 * Double(medicalLevel - 3)
        let doctor = 1 - 0.025 * Double(doctorAbilityValue - 10)
        return min(1.25, max(0.6, facility * doctor))
    }

    /// Risco de lesão nas partidas: o preparador físico reduz.
    var injuryRiskFactor: Double { min(1.15, max(0.75, 1 - 0.02 * Double(fitnessAbilityValue - 10))) }

    /// Chance de o auxiliar ler o estilo do rival de forma errada.
    var assistantMisreadProbability: Double { max(0, min(0.5, (14 - Double(assistantAbilityValue)) / 28)) }

    /// Estilo que o rival realmente usará (usado pelo motor).
    func trueOpponentStyle(for fixture: LeagueFixture) -> FootballPlayStyle {
        guard let selectedClubID else { return .balanced }
        return aiStyle(teamID: fixture.opponent(of: selectedClubID), opponentID: selectedClubID)
    }

    /// Leitura do auxiliar: pode errar conforme a habilidade dele. O erro é fixo para cada jogo.
    func scoutedOpponentStyle(for fixture: LeagueFixture) -> (style: FootballPlayStyle, isCorrect: Bool) {
        let truth = trueOpponentStyle(for: fixture)
        var random = FootballRandom(seed: matchSeed(stream: .match, id: fixture.id) ^ 0xA5515)
        guard random.chance(assistantMisreadProbability) else { return (truth, true) }
        let others = FootballPlayStyle.allCases.filter { $0 != truth }
        return (random.pick(others) ?? truth, false)
    }

    // MARK: - Treino 2.0

    mutating func setSecondaryTrainingFocus(_ focus: FootballTrainingFocus?) {
        secondaryTrainingFocus = focus == trainingFocus ? nil : focus
    }

    mutating func setOpponentPrep(_ enabled: Bool) {
        opponentPrep = enabled
    }

    var individualProgramCount: Int {
        clubRoster.filter { $0.individualFocus != nil || $0.learningPosition != nil }.count
    }

    @discardableResult
    mutating func setIndividualFocus(playerID: Int, kind: AttributeKind?) -> Bool {
        guard let index = players.firstIndex(where: { $0.id == playerID }), players[index].teamID == selectedClubID else { return false }
        if kind != nil && players[index].individualFocus == nil && players[index].learningPosition == nil
            && individualProgramCount >= Self.individualProgramLimit { return false }
        guard kind == nil || (kind?.group != .hidden) else { return false }
        players[index].individualFocus = kind
        return true
    }

    @discardableResult
    mutating func startLearning(playerID: Int, position: FootballPosition) -> Bool {
        guard let index = players.firstIndex(where: { $0.id == playerID }), players[index].teamID == selectedClubID,
              players[index].position != position, !players[index].learnedPositions.contains(position) else { return false }
        if players[index].individualFocus == nil && players[index].learningPosition == nil
            && individualProgramCount >= Self.individualProgramLimit { return false }
        players[index].learningPosition = position
        players[index].learningProgress = 0
        return true
    }

    // MARK: - Fim de temporada da estrutura

    /// Torcida, patrocínio, obras e mercado de comissão técnica no fim da temporada.
    mutating func closeSeasonClub(objectiveMet: Bool, champion: Bool, using random: inout FootballRandom) {
        let change = (objectiveMet ? 0.03 : -0.02) + (champion ? 0.04 : 0)
        fanBase = max(5_000, Int(Double(fanBase) * (1 + change)))
        if let deal = sponsorDeal, champion, deal.titleBonus > 0 {
            book(.sponsor, deal.titleBonus, "Bônus de título do patrocinador \(deal.sponsor)")
        }
        if let deal = sponsorDeal, deal.endSeason <= season { sponsorDeal = nil }
        refreshStaffMarket(using: &random)
        closeGrowthSeason()
    }

    /// Ofertas de patrocínio para a nova temporada, quando o contrato terminou.
    mutating func prepareNewSeasonClub(using random: inout FootballRandom) {
        prepareGrowthSeason(using: &random)
        guard selectedClubID != nil, sponsorDeal == nil else { return }
        sponsorOffers = makeSponsorOffers(using: &random)
    }

    /// Fecha automaticamente o patrocínio equilibrado se o usuário não escolheu até o primeiro jogo.
    mutating func autoSignSponsorIfNeeded() {
        guard sponsorDeal == nil, let balanced = sponsorOffers.first(where: { $0.profile == "Equilibrado" }) ?? sponsorOffers.first else { return }
        signSponsor(balanced)
    }
}
