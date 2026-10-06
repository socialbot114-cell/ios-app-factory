import Foundation

extension FootballCareer {
    static let fantasyFormation: [FootballPosition: Int] = [.goalkeeper: 1, .defender: 4, .midfielder: 3, .forward: 3]
    static let fantasyManagerNames = ["Paulão Cartola", "Dani Estrategista", "Tio Beto", "Mari Capitã", "Gui do Mercado", "Vera 11", "Nando Mágico"]

    // MARK: - Preços e elenco disponível

    func fantasyPrice(_ player: FootballPlayer) -> Double {
        let base = max(3.0, Double(player.overall - 55) * 0.62)
        return (base * 10).rounded() / 10
    }

    /// Todos os atletas das duas divisões que podem ser escalados no fantasy.
    var fantasyPool: [FootballPlayer] {
        players.filter { $0.teamID != nil && !$0.isYouth && !$0.onLoan }
    }

    func fantasyLineupCost(_ ids: [Int]) -> Double {
        ids.compactMap { player($0) }.reduce(0) { $0 + fantasyPrice($1) }
    }

    func fantasyBlockReason(ids: [Int], captainID: Int?) -> String? {
        guard ids.count == 11, Set(ids).count == 11 else { return "Escolha 11 atletas diferentes." }
        let chosen = ids.compactMap { player($0) }
        guard chosen.count == 11, chosen.allSatisfy({ $0.teamID != nil }) else { return "Há atleta indisponível na escalação." }
        for (position, required) in Self.fantasyFormation where chosen.filter({ $0.position == position }).count != required {
            return "O esquema é 4-3-3: 1 goleiro, 4 defensores, 3 meias e 3 atacantes."
        }
        if fantasyLineupCost(ids) > FantasyState.budget { return "Orçamento estourado: \(String(format: "%.1f", fantasyLineupCost(ids))) de \(Int(FantasyState.budget))." }
        guard let captainID, ids.contains(captainID) else { return "Escolha um capitão entre os titulares." }
        return nil
    }

    @discardableResult
    mutating func setFantasyLineup(ids: [Int], captainID: Int?) -> Bool {
        guard fantasyBlockReason(ids: ids, captainID: captainID) == nil else { return false }
        world.fantasy.lineup = ids
        world.fantasy.captainID = captainID
        world.fantasy.draft = nil
        bump("fantasyLineups")
        return true
    }

    /// Escalação sugerida: os melhores de cada posição que cabem no orçamento.
    func suggestedFantasyLineup() -> (ids: [Int], captainID: Int?) {
        var chosen: [FootballPlayer] = []
        var remaining = FantasyState.budget
        let minimumPerSlot = 3.0
        var slotsLeft = 11
        for (position, count) in [(FootballPosition.goalkeeper, 1), (.defender, 4), (.midfielder, 3), (.forward, 3)] {
            let pool = fantasyPool.filter { $0.position == position && !$0.isInjured }.sorted { $0.effectiveOverall / fantasyPrice($0) > $1.effectiveOverall / fantasyPrice($1) }
            var picked = 0
            for athlete in pool {
                guard picked < count else { break }
                let afterPick = remaining - fantasyPrice(athlete)
                let needed = Double(slotsLeft - 1) * minimumPerSlot
                if afterPick >= needed { chosen.append(athlete); remaining = afterPick; slotsLeft -= 1; picked += 1 }
            }
        }
        let captain = chosen.filter { $0.position == .forward }.max { $0.overall < $1.overall }?.id
        return (chosen.map(\.id), captain)
    }

    // MARK: - Pontuação

    func fantasyPoints(for athlete: FootballPlayer, in fixture: LeagueFixture) -> Double {
        fantasyComponents(for: athlete, in: fixture).reduce(0) { $0 + $1.points }
    }

    /// Pontuação da escalação do usuário numa rodada da liga.
    func fantasyRoundPoints(matchDay: Int) -> Double {
        var total = 0.0
        for id in world.fantasy.lineup {
            guard let athlete = player(id), let fixture = fixtures.first(where: {
                $0.matchDay == matchDay && $0.competition.division != nil && $0.involves(athlete.teamID ?? -1)
            }) else { continue }
            let points = fantasyPoints(for: athlete, in: fixture)
            total += id == world.fantasy.captainID ? points * 1.5 : points
        }
        return (total * 10).rounded() / 10
    }

    mutating func ensureFantasyManagers() {
        guard world.fantasy.managers.isEmpty else { return }
        world.fantasy.managers = Self.fantasyManagerNames.enumerated().map { FantasyManager(id: $0.offset + 1, name: $0.element, points: 0) }
    }

    /// Pontua a rodada que acabou de ser jogada, paga prêmios em fichas e atualiza o ranking.
    mutating func scoreFantasyRound(matchDay: Int) {
        guard let slot = calendar.indices.contains(matchDay) ? calendar[matchDay] : nil, let round = slot.leagueRound else { return }
        guard round > world.fantasy.lastScoredRound,
              !world.fantasy.history.contains(where: { $0.season == season && $0.round == round }) else { return }
        let roundFixtures = fixtures.filter { $0.matchDay == matchDay && $0.competition.division != nil }
        guard !roundFixtures.isEmpty, roundFixtures.allSatisfy({ $0.isPlayed }) else { return }
        ensureFantasyManagers()
        guard world.fantasy.lineup.count == 11 else { return }
        let points = fantasyRoundPoints(matchDay: matchDay)
        let scores = fantasyRivalScores(matchDay: matchDay)
        for index in world.fantasy.managers.indices {
            world.fantasy.managers[index].points += scores[index]
        }
        let rank = scores.filter { $0 > points }.count + 1
        world.fantasy.seasonPoints += points
        world.fantasy.lastScoredRound = round
        let captainName = world.fantasy.captainID.flatMap { player($0)?.name } ?? "—"
        world.fantasy.history.insert(FantasyRoundResult(round: round, season: season, points: points, captainName: captainName, rank: rank), at: 0)
        let detail = makeFantasyDetail(matchDay: matchDay, round: round)
        // Mantém somente o snapshot mais recente, sem misturar JSON técnico com efeitos narrativos.
        for index in factStore.facts.indices where factStore.facts[index].id.hasPrefix("fantasy-result-") {
            factStore.facts[index].fantasySnapshot = nil
        }
        recordFact(WorldFact(id: "fantasy-result-\(season)-\(round)", source: .match, worldDay: worldDay,
                             title: "Rodada Mágica \(round)", detail: "\(points) pontos · capitão \(captainName)",
                             playerIDs: world.fantasy.lineup, effects: ["Pontuação da rodada: \(points)"], fantasySnapshot: detail))
        if world.fantasy.history.count > 40 { world.fantasy.history.removeLast(world.fantasy.history.count - 40) }
        let prize = rank == 1 ? 300 : (rank == 2 ? 150 : (rank == 3 ? 80 : max(0, Int(points / 2))))
        world.betting.fichas += prize
        bump("fantasyRounds")
        if rank == 1 { bump("fantasyWins") }
        addInbox(.bet, title: "Rodada Mágica \(round): \(String(format: "%.1f", points)) pontos",
                 body: "Você ficou em \(rank)º entre 8 gestores e ganhou \(prize) fichas. Capitão: \(captainName).")
    }

    var fantasyStandings: [(name: String, points: Double, isUser: Bool)] {
        var rows = world.fantasy.managers.map { (name: $0.name, points: $0.points, isUser: false) }
        rows.append((world.coach.name, world.fantasy.seasonPoints, true))
        return rows.sorted { $0.points > $1.points }
    }

    mutating func closeFantasySeason() {
        guard !world.fantasy.managers.isEmpty else { return }
        if let first = fantasyStandings.first, first.isUser, world.fantasy.seasonPoints > 0 {
            world.fantasy.titles += 1
            world.betting.fichas += 500
            bump("fantasyTitles")
        }
        world.fantasy.seasonPoints = 0
        world.fantasy.lastScoredRound = 0
        for index in world.fantasy.managers.indices { world.fantasy.managers[index].points = 0 }
    }
}
