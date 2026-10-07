import Foundation

// MARK: - Entre temporadas

/// Etapas do ritual de virada. As duas primeiras acontecem antes de a temporada ser encerrada; as demais, na nova temporada.
enum OffseasonStep: Int, Codable, CaseIterable {
    case endOfSeason, contracts, review, iconPack, holiday, sponsor, preseason, kickoff

    var title: String {
        switch self {
        case .endOfSeason: return "Apito final"
        case .contracts: return "Contratos que vencem"
        case .review: return "Balanço da temporada"
        case .iconPack: return "Craque eterno"
        case .holiday: return "Férias"
        case .sponsor: return "Patrocinador"
        case .preseason: return "Pré-temporada"
        case .kickoff: return "Bola rolando"
        }
    }

    /// Posição na barra de progresso (seis momentos); etapas opcionais herdam a do momento a que pertencem.
    var phase: Int {
        switch self {
        case .endOfSeason, .contracts: return 0
        case .review, .iconPack: return 1
        case .holiday: return 2
        case .sponsor: return 3
        case .preseason: return 4
        case .kickoff: return 5
        }
    }

    static let phaseTitles = ["Fim", "Balanço", "Férias", "Patrocínio", "Pré-temporada", "Estreia"]
}

/// Férias do elenco entre as temporadas: descanso contra ritmo.
enum HolidayPlan: String, Codable, CaseIterable, Identifiable {
    case fullRest, shortBreak, noBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullRest: return "Três semanas de descanso"
        case .shortBreak: return "Férias curtas"
        case .noBreak: return "Sem férias"
        }
    }

    var summary: String {
        switch self {
        case .fullRest: return "Todos desligam. O grupo volta renovado e as lesões curam, mas a apresentação é mais lenta."
        case .shortBreak: return "Duas semanas fora, com treino leve por conta própria. Equilíbrio entre descanso e ritmo."
        case .noBreak: return "A pré-temporada começa já. O grupo reclama do cansaço, e a torcida gosta da dedicação."
        }
    }

    var symbol: String {
        switch self {
        case .fullRest: return "beach.umbrella.fill"
        case .shortBreak: return "sun.max.fill"
        case .noBreak: return "figure.run"
        }
    }

    var moraleDelta: Int {
        switch self {
        case .fullRest: return 8
        case .shortBreak: return 4
        case .noBreak: return -8
        }
    }

    var conditionDelta: Int {
        switch self {
        case .fullRest: return 10
        case .shortBreak: return 5
        case .noBreak: return -6
        }
    }

    /// Rodadas de lesão que as férias curam.
    var healedInjuryRounds: Int {
        switch self {
        case .fullRest: return 99
        case .shortBreak: return 1
        case .noBreak: return 0
        }
    }

    var effects: [String] {
        var items = [moraleDelta >= 0 ? "Moral +\(moraleDelta)" : "Moral \(moraleDelta)"]
        items.append(conditionDelta >= 0 ? "Físico +\(conditionDelta)" : "Físico \(conditionDelta)")
        if healedInjuryRounds >= 99 { items.append("Cura todas as lesões") }
        else if healedInjuryRounds > 0 { items.append("Cura \(healedInjuryRounds) rodada de lesão") }
        return items
    }

    var report: String {
        switch self {
        case .fullRest: return "O elenco voltou descansado e as lesões ficaram para trás."
        case .shortBreak: return "O grupo voltou com o ritmo em dia e a cabeça no lugar."
        case .noBreak: return "Sem folga, o grupo está cansado, mas a torcida viu a dedicação."
        }
    }
}

/// Preparação da equipe antes da estreia.
enum PreseasonCamp: String, Codable, CaseIterable, Identifiable {
    case homeTraining, friendlies, overseasTour

    var id: String { rawValue }

    var title: String {
        switch self {
        case .homeTraining: return "Treino no CT"
        case .friendlies: return "Amistosos regionais"
        case .overseasTour: return "Excursão internacional"
        }
    }

    var summary: String {
        switch self {
        case .homeTraining: return "Sem viagens e sem gastos: trabalho de campo e tática em casa."
        case .friendlies: return "Jogos-treino contra times da região. Dá ritmo e renda de bilheteria, com risco de lesão."
        case .overseasTour: return "Viagem longa com jogos comerciais. Aumenta a torcida e rende dinheiro, mas desgasta o grupo."
        }
    }

    var symbol: String {
        switch self {
        case .homeTraining: return "figure.soccer"
        case .friendlies: return "sportscourt.fill"
        case .overseasTour: return "airplane.departure"
        }
    }

    /// Custo e receita como fração do orçamento-base do clube.
    var costFraction: Double {
        switch self {
        case .homeTraining: return 0
        case .friendlies: return 0.02
        case .overseasTour: return 0.08
        }
    }

    var revenueFraction: Double {
        switch self {
        case .homeTraining: return 0
        case .friendlies: return 0.015
        case .overseasTour: return 0.12
        }
    }

    var moraleDelta: Int {
        switch self {
        case .homeTraining: return 2
        case .friendlies: return 3
        case .overseasTour: return 5
        }
    }

    var conditionDelta: Int {
        switch self {
        case .homeTraining: return 4
        case .friendlies: return 6
        case .overseasTour: return -3
        }
    }

    var fanBaseGrowth: Double {
        switch self {
        case .homeTraining: return 0
        case .friendlies: return 0.005
        case .overseasTour: return 0.03
        }
    }

    var injuryChance: Double {
        switch self {
        case .homeTraining: return 0
        case .friendlies: return 0.30
        case .overseasTour: return 0.15
        }
    }

    func cost(baseBudget: Int) -> Int { Int(Double(baseBudget) * costFraction) }
    func revenue(baseBudget: Int) -> Int { Int(Double(baseBudget) * revenueFraction) }
}

struct OffseasonState: Codable, Equatable {
    var step: OffseasonStep = .endOfSeason
    var holiday: HolidayPlan? = nil
    var camp: PreseasonCamp? = nil
    /// Texto do que a pré-temporada deixou de saldo (lesões, receitas), mostrado na etapa seguinte.
    var campReport: String? = nil
}

extension FootballCareer {
    var isInOffseason: Bool { offseason != nil }

    /// Jogadores do clube cujo contrato termina com a temporada e que ainda dá para renovar.
    var expiringContractPlayers: [FootballPlayer] {
        guard let selectedClubID else { return [] }
        return players
            .filter { $0.teamID == selectedClubID && !$0.isYouth && !$0.onLoan && !$0.isIcon
                && $0.contract.endSeason != 0 && $0.contract.endSeason <= season }
            .sorted { $0.overall == $1.overall ? $0.id < $1.id : $0.overall > $1.overall }
    }

    @discardableResult
    mutating func beginOffseason() -> Bool {
        guard offseason == nil, isSeasonComplete, liveMatch == nil, selectedClubID != nil, !isFired else { return false }
        offseason = OffseasonState()
        return true
    }

    /// Passa para a próxima etapa se a atual já foi resolvida. Decisões obrigatórias não podem ser puladas.
    @discardableResult
    mutating func advanceOffseason() -> Bool {
        guard var state = offseason else { return false }
        switch state.step {
        case .endOfSeason:
            if expiringContractPlayers.isEmpty { return closeSeasonInOffseason(&state) }
            state.step = .contracts
        case .contracts:
            return closeSeasonInOffseason(&state)
        case .review:
            state.step = iconState.pendingPack != nil ? .iconPack : .holiday
        case .iconPack:
            guard iconState.pendingPack == nil else { return false }
            state.step = .holiday
        case .holiday:
            guard state.holiday != nil else { return false }
            state.step = sponsorOffers.isEmpty ? .preseason : .sponsor
        case .sponsor:
            guard sponsorOffers.isEmpty else { return false }
            state.step = .preseason
        case .preseason:
            guard state.camp != nil else { return false }
            state.step = .kickoff
        case .kickoff:
            offseason = nil
            return true
        }
        offseason = state
        return true
    }

    /// Encerra a temporada de fato; se a diretoria demitiu o treinador, o ritual termina aqui e as propostas de emprego assumem.
    private mutating func closeSeasonInOffseason(_ state: inout OffseasonState) -> Bool {
        guard startNextSeason() != nil else { return false }
        if isFired {
            offseason = nil
            return true
        }
        state.step = .review
        offseason = state
        return true
    }

    // MARK: Decisões

    @discardableResult
    mutating func chooseHoliday(_ plan: HolidayPlan) -> Bool {
        guard var state = offseason, state.step == .holiday, state.holiday == nil, let clubID = selectedClubID else { return false }
        for index in players.indices where players[index].teamID == clubID {
            players[index].morale = min(100, max(0, players[index].morale + plan.moraleDelta))
            players[index].condition = min(100, max(40, players[index].condition + plan.conditionDelta))
            if plan.healedInjuryRounds > 0 {
                players[index].injuryRounds = max(0, players[index].injuryRounds - plan.healedInjuryRounds)
            }
        }
        state.holiday = plan
        offseason = state
        addInbox(.general, title: "Férias: \(plan.title)", body: plan.report)
        return true
    }

    func canAffordCamp(_ camp: PreseasonCamp) -> Bool {
        guard let club = selectedClub else { return false }
        return transferBudget >= camp.cost(baseBudget: club.startingBudget)
    }

    @discardableResult
    mutating func chooseCamp(_ camp: PreseasonCamp) -> Bool {
        guard var state = offseason, state.step == .preseason, state.camp == nil,
              let clubID = selectedClubID, let club = selectedClub, canAffordCamp(camp) else { return false }
        let cost = camp.cost(baseBudget: club.startingBudget)
        let revenue = camp.revenue(baseBudget: club.startingBudget)
        if cost > 0 { book(.other, -cost, "Pré-temporada: \(camp.title)") }
        if revenue > 0 { book(.marketing, revenue, "Receitas da pré-temporada: \(camp.title)") }
        for index in players.indices where players[index].teamID == clubID {
            players[index].morale = min(100, max(0, players[index].morale + camp.moraleDelta))
            players[index].condition = min(100, max(40, players[index].condition + camp.conditionDelta))
        }
        fanBase = Int(Double(fanBase) * (1 + camp.fanBaseGrowth))

        var lines = ["Saldo: \(FootballFormat.money(revenue - cost))."]
        var random = FootballRandom(seed: matchSeed(stream: .offseason, id: 5_000 + season))
        if camp.injuryChance > 0, random.chance(camp.injuryChance) {
            let candidates = players.indices.filter { players[$0].teamID == clubID && !players[$0].isYouth && !players[$0].isIcon }
            if let victim = random.pick(candidates) {
                players[victim].injuryRounds = max(players[victim].injuryRounds, 2)
                lines.append("\(players[victim].name) se machucou e desfalca as duas primeiras rodadas.")
            }
        } else if camp.injuryChance > 0 {
            lines.append("Ninguém se machucou.")
        }
        if camp.fanBaseGrowth > 0 { lines.append("A torcida cresceu.") }
        state.camp = camp
        state.campReport = lines.joined(separator: " ")
        offseason = state
        return true
    }

    /// Escolhe a decisão padrão da etapa atual. Usado em capturas de tela e testes para chegar a uma etapa específica.
    mutating func applyDefaultOffseasonDecision() {
        guard let step = offseason?.step else { return }
        switch step {
        case .iconPack: openIconPack()
        case .holiday: chooseHoliday(.shortBreak)
        case .sponsor:
            if let offer = sponsorOffers.first(where: { $0.profile == "Equilibrado" }) ?? sponsorOffers.first { acceptSponsorOffer(offer.id) }
        case .preseason: chooseCamp(.homeTraining)
        default: break
        }
    }

    /// Carreira de demonstração parada na etapa pedida do ritual.
    static func offseasonPreview(at target: OffseasonStep) -> FootballCareer {
        var career = FootballCareer(seed: 26)
        _ = career.chooseClub(0)
        var days = 0
        while !career.isSeasonComplete, days < FootballSeason.matchDaysPerSeason + 5 {
            career.boardConfidence = 100
            if !career.simulateNextMatchDay() { break }
            days += 1
        }
        career.boardConfidence = 100
        career.beginOffseason()
        var guardCount = 0
        while let step = career.offseason?.step, step != target, guardCount < 24 {
            career.applyDefaultOffseasonDecision()
            if !career.advanceOffseason() { break }
            guardCount += 1
        }
        return career
    }
}
