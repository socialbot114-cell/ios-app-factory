import Foundation

/// Contrato do treinador com o clube atual, vindo da proposta aceita.
struct CoachContract: Codable, Equatable {
    var clubID: Int
    var startSeason: Int
    var seasons: Int
    var salaryFactor: Double
    /// Pontos a menos no limite de demissão: positivo é diretoria mais paciente.
    var patienceBonus: Int

    var endSeason: Int { startSeason + seasons - 1 }
}

/// Uma das propostas de clubes mostradas no começo da carreira.
struct CareerOffer: Codable, Equatable, Identifiable {
    var clubID: Int
    var budget: Int
    var wageCapFactor: Double
    var boardTarget: Int
    var startingConfidence: Int
    var patienceBonus: Int
    var fanMood: Int
    var signingBonus: Int
    var contractSeasons: Int
    var salaryFactor: Double
    var pitch: String
    /// De 1 (tranquilo) a 5 (muito difícil).
    var difficulty: Int

    var id: Int { clubID }
}

extension FootballCareer {
    static let coachNameLimit = 28

    /// Valores de meta por faixa, do mais difícil ao mais fácil.
    private static func targetTiers(for division: Division) -> [Int] {
        let safety = FootballSeason.teamsPerDivision - FootballSeason.relegationSpots
        return division == .serieA ? [1, 3, 6, safety] : [2, 5, safety]
    }

    func boardTarget(forClub clubID: Int) -> Int {
        let division = division(of: clubID)
        let ranking = teamIDs(in: division)
            .map { teamID -> (Int, Double) in
                let roster = players.filter { $0.teamID == teamID }
                let teamFormation = teamID == selectedClubID ? formation : aiFormation(teamID: teamID)
                let lineup = FootballSeason.bestLineup(roster: roster, formation: teamFormation).compactMap { player($0) }
                return (teamID, lineup.map { Double($0.overall) }.reduce(0, +) / Double(max(1, lineup.count)))
            }
            .sorted { $0.1 > $1.1 }
        let rank = (ranking.firstIndex { $0.0 == clubID } ?? 5) + 1
        let safety = FootballSeason.teamsPerDivision - FootballSeason.relegationSpots
        switch (division, rank) {
        case (.serieA, 1): return 1
        case (.serieA, 2...3): return 3
        case (.serieA, 4...6): return 6
        case (.serieA, _): return safety
        case (.serieB, 1...3): return 2
        case (.serieB, 4...6): return 5
        case (.serieB, _): return safety
        }
    }

    /// Seis propostas de clubes de faixas diferentes, sempre as mesmas para a mesma semente.
    func careerOffers() -> [CareerOffer] {
        var random = FootballRandom(seed: UInt64(truncatingIfNeeded: seed) &* 0x9E3779B97F4A7C15 &+ 0xC0FFEE)
        let ranked = FootballSeason.teams.sorted { clubPrestige($0.id) > clubPrestige($1.id) }
        let bands: [ClosedRange<Int>] = [0...2, 3...5, 6...9, 10...13, 14...16, 17...19]
        var chosen: [LeagueTeam] = []
        for band in bands {
            let pool = band.compactMap { ranked.indices.contains($0) ? ranked[$0] : nil }.filter { club in !chosen.contains { $0.id == club.id } }
            if let club = random.pick(pool) { chosen.append(club) }
        }
        return chosen.map { makeOffer(for: $0, using: &random) }
    }

    private func makeOffer(for club: LeagueTeam, using random: inout FootballRandom) -> CareerOffer {
        let division = division(of: club.id)
        let tiers = Self.targetTiers(for: division)
        let baseTarget = boardTarget(forClub: club.id)
        let baseIndex = tiers.firstIndex(of: baseTarget) ?? (tiers.count - 1)
        // Diretoria ambiciosa pede uma faixa acima, conservadora uma abaixo.
        let shift = random.pick([-1, 0, 0, 1]) ?? 0
        let tierIndex = min(tiers.count - 1, max(0, baseIndex + shift))
        let target = tiers[tierIndex]

        let budgetFactor = 0.75 + random.unit() * 0.65
        let budget = Int(Double(club.startingBudget) * budgetFactor / 100_000) * 100_000
        let wageFactor = (1.10 + random.unit() * 0.30 + (budgetFactor - 1) * 0.15)
        let patience = random.int(in: -4...8)
        let confidence = random.int(in: 50...70)
        let prestige = clubPrestige(club.id)
        let pressure = max(0, min(100, (prestige - 60) * 3 + (3 - tierIndex) * 6 + random.int(in: -8...8)))
        let fanMood = max(35, min(75, 78 - pressure / 2))
        let bonus = Int(Double(max(1, prestige - 55)) * 6_000 * (0.6 + random.unit() * 0.8) / 5_000) * 5_000
        let seasons = random.int(in: 1...3)
        let salaryFactor = (0.9 + random.unit() * 0.4 * 100).rounded() / 100

        var points = 3 - tierIndex
        if division == .serieB { points += 1 }
        if budgetFactor < 0.95 { points += 1 }
        if patience < 0 { points += 1 }
        if confidence < 56 { points += 1 }
        if pressure > 70 { points += 1 }
        let difficulty = max(1, min(5, (points + 1) / 2 + 1))

        return CareerOffer(clubID: club.id, budget: budget, wageCapFactor: (wageFactor * 100).rounded() / 100, boardTarget: target,
                           startingConfidence: confidence, patienceBonus: patience, fanMood: fanMood, signingBonus: bonus,
                           contractSeasons: seasons, salaryFactor: salaryFactor, pitch: pitch(club: club, target: target, division: division,
                                                                                         budgetFactor: budgetFactor, patience: patience, pressure: pressure),
                           difficulty: difficulty)
    }

    private func pitch(club: LeagueTeam, target: Int, division: Division, budgetFactor: Double, patience: Int, pressure: Int) -> String {
        var parts: [String] = []
        switch (division, target) {
        case (.serieA, 1): parts.append("A diretoria só aceita o título.")
        case (.serieA, 2...3): parts.append("A meta é o pódio da Série A.")
        case (.serieA, 4...6): parts.append("Querem o clube na parte de cima da tabela.")
        case (.serieA, _): parts.append("O objetivo é fugir do rebaixamento.")
        case (.serieB, 1...2): parts.append("Querem o acesso à Série A já.")
        case (.serieB, _): parts.append("Projeto de reconstrução na Série B.")
        }
        if budgetFactor >= 1.15 { parts.append("Caixa generoso para reforçar o elenco.") } else if budgetFactor < 0.9 { parts.append("Caixa apertado: vai ter que escolher bem.") }
        if patience >= 5 { parts.append("Diretoria paciente.") } else if patience < 0 { parts.append("Diretoria impaciente.") }
        if pressure >= 70 { parts.append("A torcida cobra forte desde o primeiro jogo.") } else if pressure <= 30 { parts.append("Torcida tranquila e apoiando.") }
        return parts.joined(separator: " ")
    }

    // MARK: - Aceitar a proposta

    @discardableResult
    mutating func acceptCareerOffer(clubID: Int, coachName: String) -> Bool {
        guard selectedClubID == nil, let offer = careerOffers().first(where: { $0.clubID == clubID }), chooseClub(clubID) else { return false }
        let trimmed = coachName.trimmingCharacters(in: .whitespacesAndNewlines)
        world.coach.name = trimmed.isEmpty ? "Treinador" : String(trimmed.prefix(Self.coachNameLimit))
        transferBudget = offer.budget
        boardTarget = offer.boardTarget
        boardConfidence = offer.startingConfidence
        wageCap = Int(Double(wageBill) * offer.wageCapFactor)
        fanMood = offer.fanMood
        world.coach.personalCash += offer.signingBonus
        world.coach.contract = CoachContract(clubID: clubID, startSeason: season, seasons: offer.contractSeasons,
                                             salaryFactor: offer.salaryFactor, patienceBonus: offer.patienceBonus)
        addInbox(.board, title: "Bem-vindo, \(world.coach.name)", body: "Contrato de \(offer.contractSeasons) temporada(s) com o \(FootballSeason.teamName(clubID)). \(objectiveText).")
        return true
    }

    /// Indenização paga quando a diretoria demite antes do fim do contrato.
    mutating func payContractSeverance() {
        guard let contract = world.coach.contract, contract.endSeason >= season else { return }
        let remaining = max(1, contract.endSeason - season + 1)
        let amount = coachSalaryPerSeason * remaining / 2
        guard amount > 0 else { return }
        world.coach.personalCash += amount
        world.coach.contract = nil
        addInbox(.finance, title: "Multa rescisória", body: "O clube pagou \(FootballFormat.money(amount)) pela rescisão do seu contrato.")
    }
}
