import Foundation

extension FootballCareer {
    static let dutyLeagueRounds = [5, 11, 17]

    static var dutyMatchDays: [Int] {
        dutyLeagueRounds.map { FootballSeason.matchDayIndex(leagueRound: $0) }
    }

    // MARK: - Prestígio e reputação

    func clubPrestige(_ id: Int) -> Int {
        (FootballSeason.team(id)?.strength ?? 60) + (division(of: id) == .serieA ? 6 : 0)
    }

    /// Prestígio máximo dos clubes que aceitariam o treinador, pela reputação dele.
    var maxPrestige: Int { 50 + Int(Double(reputation) * 0.4) }

    func initialReputation(for club: LeagueTeam) -> Int {
        max(15, min(70, (club.strength - 55) * 2))
    }

    /// Paciência da diretoria: clubes grandes demitem mais rápido.
    func boardPatienceThreshold(for clubID: Int) -> Int {
        let prestige = clubPrestige(clubID)
        return prestige >= 80 ? 32 : (prestige >= 74 ? 26 : 20)
    }

    mutating func changeReputation(_ delta: Int) {
        reputation = min(100, max(0, reputation + delta))
    }

    // MARK: - Troca de clube

    /// Assume um novo clube (convite, demissão ou pedido de demissão).
    mutating func takeOverClub(_ clubID: Int, budgetFraction: Double, confidence: Int) {
        guard let club = FootballSeason.team(clubID) else { return }
        selectedClubID = club.id
        transferBudget = Int(Double(club.startingBudget) * budgetFraction)
        boardConfidence = confidence
        isFired = false
        offers = []
        promises = []
        inbox = []
        invitations = []
        playerRoles = [:]
        rivalMotivation = [:]
        pendingPress = nil
        scoutMissions = []
        pendingPayments = []
        goalBonuses = []
        fanMood = 55
        records = ClubRecords()
        legends = []
        if !FootballSeason.canFill(roster: clubRoster, formation: formation) { formation = .fourFourTwo }
        startingXI = FootballSeason.bestLineup(roster: clubRoster, formation: formation, matchDay: matchDayIndex)
        boardTarget = computeBoardTarget()
        wageCap = Int(Double(wageBill) * 1.25)
        setupClubInfrastructure()
    }

    @discardableResult
    mutating func acceptInvitation(_ clubID: Int) -> Bool {
        guard liveMatch == nil, !isFired, invitations.contains(where: { $0.clubID == clubID }) else { return false }
        takeOverClub(clubID, budgetFraction: 0.75, confidence: 62)
        changeReputation(2)
        addInbox(.board, title: "Bem-vindo ao \(FootballSeason.teamName(clubID))", body: "Você assumiu o novo clube. A meta da diretoria: \(objectiveText.lowercased()).")
        return true
    }

    /// Pedido de demissão: o treinador deixa o clube e escolhe uma das propostas disponíveis.
    @discardableResult
    mutating func resign() -> Bool {
        guard selectedClubID != nil, liveMatch == nil, !isFired else { return false }
        isFired = true
        invitations = []
        changeReputation(-3)
        return true
    }

    mutating func generateInvitations(using random: inout FootballRandom) {
        invitations = []
        guard let selectedClubID, !isFired else { return }
        let current = clubPrestige(selectedClubID)
        let candidates = FootballSeason.teams.filter {
            $0.id != selectedClubID && clubPrestige($0.id) > current && clubPrestige($0.id) <= maxPrestige
        }.sorted { clubPrestige($0.id) > clubPrestige($1.id) }
        let chance = reputation >= 85 ? 0.8 : 0.45
        for club in candidates.prefix(3) where invitations.count < 2 && random.chance(chance) {
            invitations.append(JobInvitation(clubID: club.id, season: season))
            addInbox(.board, title: "\(club.name) quer o seu trabalho",
                     body: "A diretoria do \(club.name) (\(club.city)) convidou você para assumir o clube. Responda até o fim da próxima temporada.")
        }
    }

    // MARK: - Histórico de confrontos

    func h2hKey(_ first: Int, _ second: Int) -> String { "\(min(first, second))-\(max(first, second))" }

    mutating func recordHeadToHead(_ fixture: LeagueFixture) {
        guard let homeGoals = fixture.homeGoals, let awayGoals = fixture.awayGoals else { return }
        let key = h2hKey(fixture.home, fixture.away)
        var record = headToHead[key] ?? HeadToHead()
        let lowIsHome = fixture.home < fixture.away
        let lowGoals = lowIsHome ? homeGoals : awayGoals
        let highGoals = lowIsHome ? awayGoals : homeGoals
        record.lowGoals += lowGoals
        record.highGoals += highGoals
        let winner = fixture.winner
        if homeGoals == awayGoals && winner == nil { record.draws += 1 }
        else if let winner { if winner == min(fixture.home, fixture.away) { record.lowWins += 1 } else { record.highWins += 1 } }
        else if lowGoals > highGoals { record.lowWins += 1 } else if lowGoals < highGoals { record.highWins += 1 } else { record.draws += 1 }
        record.lastResult = "T\(season) · \(FootballSeason.teamName(fixture.home)) \(homeGoals) × \(awayGoals) \(FootballSeason.teamName(fixture.away))"
        headToHead[key] = record
    }

    /// Retrospecto de `club` contra `rival`: vitórias, empates, derrotas, gols pró e contra.
    func retrospect(of club: Int, against rival: Int) -> (wins: Int, draws: Int, losses: Int, goalsFor: Int, goalsAgainst: Int, last: String)? {
        guard let record = headToHead[h2hKey(club, rival)] else { return nil }
        let clubIsLow = club < rival
        return (clubIsLow ? record.lowWins : record.highWins, record.draws, clubIsLow ? record.highWins : record.lowWins,
                clubIsLow ? record.lowGoals : record.highGoals, clubIsLow ? record.highGoals : record.lowGoals, record.lastResult)
    }

    // MARK: - Recordes

    mutating func updateRecords(after fixture: LeagueFixture) {
        guard let selectedClubID, let own = fixture.homeGoals.flatMap({ home in fixture.awayGoals.map { away in fixture.home == selectedClubID ? (home, away) : (away, home) } }) else { return }
        let margin = own.0 - own.1
        let opponent = FootballSeason.teamName(fixture.opponent(of: selectedClubID))
        let text = "\(own.0) × \(own.1) contra \(opponent) (T\(season))"
        if margin > records.biggestWinMargin { records.biggestWinMargin = margin; records.biggestWin = text }
        if -margin > records.biggestLossMargin { records.biggestLossMargin = -margin; records.biggestLoss = text }
        if margin >= 0 { records.currentUnbeaten += 1 } else { records.currentUnbeaten = 0 }
        records.longestUnbeaten = max(records.longestUnbeaten, records.currentUnbeaten)
        if let crowd = fixture.attendance { records.highestAttendance = max(records.highestAttendance, crowd) }
        if let points = standings.first(where: { $0.team.id == selectedClubID })?.points {
            records.mostPointsInSeason = max(records.mostPointsInSeason, points)
        }
        if let scorer = clubRoster.max(by: { $0.careerGoals < $1.careerGoals }), scorer.careerGoals > records.topScorerGoals {
            records.topScorerGoals = scorer.careerGoals
            records.topScorerName = scorer.name
        }
        if let veteran = clubRoster.max(by: { $0.careerAppearances < $1.careerAppearances }), veteran.careerAppearances > records.mostAppearances {
            records.mostAppearances = veteran.careerAppearances
            records.mostAppearancesName = veteran.name
        }
    }

    // MARK: - Notícias

    /// Notícias da liga a partir dos jogos do dia que acabou de ser disputado.
    mutating func generateLeagueNews(forMatchDay day: Int) {
        guard selectedClubID != nil else { return }
        var count = 0
        func name(_ id: Int) -> String { FootballSeason.teamName(id) }
        for fixture in fixtures where fixture.matchDay == day && fixture.isPlayed {
            guard count < 3, let home = fixture.homeGoals, let away = fixture.awayGoals else { continue }
            if abs(home - away) >= 4 {
                addInbox(.news, title: "Goleada na \(fixture.competition.name)", body: "\(name(fixture.home)) \(home) × \(away) \(name(fixture.away)).")
                count += 1
                continue
            }
            let scorers = Dictionary(grouping: fixture.homeScorerIDs + fixture.awayScorerIDs, by: { $0 })
            if let hatTrick = scorers.first(where: { $0.value.count >= 3 }), let athlete = player(hatTrick.key) {
                addInbox(.news, title: "Hat-trick de \(athlete.name)", body: "\(athlete.name) marcou \(hatTrick.value.count) vezes em \(name(fixture.home)) \(home) × \(away) \(name(fixture.away)).", playerID: athlete.id)
                count += 1
                continue
            }
            if fixture.competition.isCup, let winner = fixture.winner, division(of: winner) > division(of: fixture.opponent(of: winner)) {
                addInbox(.news, title: "Zebra na copa", body: "\(name(winner)) (\(division(of: winner).name)) eliminou \(name(fixture.opponent(of: winner))) na \(fixture.competition.cupRound?.name.lowercased() ?? "copa").")
                count += 1
            }
        }
        if let userDivision, day >= 3 {
            let leader = standings(for: userDivision).first?.team.id
            if let leader, let previous = leaderID, previous != leader {
                addInbox(.news, title: "\(name(leader)) é o novo líder da \(userDivision.name)", body: "Depois da rodada, o \(name(leader)) assumiu a liderança.")
            }
            leaderID = leader
        }
        if let selectedClubID {
            let recent = form(teamID: selectedClubID)
            if recent.count >= 5, recent.suffix(5).allSatisfy({ $0 == .win }), !inbox.contains(where: { $0.title == "Sequência de vitórias" && $0.matchDay >= day - 5 }) {
                addInbox(.news, title: "Sequência de vitórias", body: "O time venceu os últimos cinco jogos pela liga. A torcida está empolgada.")
            }
        }
    }

    /// Torcida e diretoria reagem ao momento do clube.
    mutating func checkFanReactions() {
        if fanMood < 25 && matchDayIndex - lastProtestMatchDay >= 4 {
            lastProtestMatchDay = matchDayIndex
            boardConfidence = max(0, boardConfidence - 3)
            addInbox(.board, title: "Protesto da torcida", body: "Torcedores fizeram protestos na saída do treino. A diretoria acompanha a situação com preocupação.")
        }
        if fanMood > 85 && matchDayIndex % 6 == 0 {
            addInbox(.news, title: "Festa na arquibancada", body: "A torcida lotou os arredores do estádio para apoiar o time.")
        }
    }

    // MARK: - Demissão durante a temporada

    mutating func checkMidSeasonSacking() {
        guard !isFired, matchDayIndex >= 8, boardConfidence <= 6, selectedClubID != nil else { return }
        isFired = true
        changeReputation(-8)
        addInbox(.board, title: "Você foi demitido", body: "A diretoria perdeu a paciência com a sequência de resultados e encerrou seu contrato no meio da temporada.")
    }

    // MARK: - Seleção nacional

    /// Convoca os melhores da liga nas datas FIFA e libera quem voltou.
    mutating func manageNationalDuty() {
        for index in players.indices {
            guard let duty = players[index].nationalDutyMatchDay, duty < matchDayIndex else { continue }
            players[index].nationalDutyMatchDay = nil
            if players[index].teamID == selectedClubID {
                players[index].morale = min(100, players[index].morale + 4)
                players[index].marketValue = Int(Double(players[index].marketValue) * 1.03 / 10_000) * 10_000
            }
        }
        guard Self.dutyMatchDays.contains(matchDayIndex) else { return }
        var called: [FootballPlayer] = []
        for (position, quota) in [(FootballPosition.goalkeeper, 2), (.defender, 4), (.midfielder, 5), (.forward, 4)] {
            let picks = players.filter { $0.teamID != nil && !$0.isYouth && !$0.isInjured && $0.position == position }
                .sorted { $0.overall != $1.overall ? $0.overall > $1.overall : $0.id < $1.id }
                .prefix(quota)
            called.append(contentsOf: picks)
        }
        for athlete in called {
            if let index = players.firstIndex(where: { $0.id == athlete.id }) { players[index].nationalDutyMatchDay = matchDayIndex }
        }
        let mine = called.filter { $0.teamID == selectedClubID }
        if !mine.isEmpty {
            addInbox(.news, title: "\(mine.count) convocado(s) para a seleção",
                     body: "\(mine.map(\.name).joined(separator: ", ")) servem à seleção e ficam fora do próximo jogo, mas voltam valorizados.")
        }
        if let rivalSelectionNote = called.first(where: { $0.teamID != selectedClubID && $0.overall >= 80 }) {
            addInbox(.news, title: "Craque convocado", body: "\(rivalSelectionNote.name) (\(FootballSeason.teamName(rivalSelectionNote.teamID ?? 0))) foi convocado e desfalca o clube na rodada.")
        }
    }

    // MARK: - Prêmios de fim de ano

    mutating func computeAwards() -> SeasonAwards {
        let tableA = standings(for: .serieA)
        let points = Dictionary(uniqueKeysWithValues: tableA.map { ($0.team.id, $0.points) })
        let eligible = players.filter { player in player.teamID.map { division(of: $0) == .serieA } ?? false }
        func score(_ player: FootballPlayer) -> Double {
            Double(player.goals) * 2.0 + Double(player.assists) * 1.2 + Double(player.overall - 60) / 3 + Double(points[player.teamID ?? -1] ?? 0) / 8
        }
        func entry(_ player: FootballPlayer) -> AwardEntry { AwardEntry(playerID: player.id, name: player.name, position: player.position, teamID: player.teamID) }
        var awards = SeasonAwards()
        awards.bestPlayer = eligible.max { score($0) < score($1) }.map(entry)
        awards.youngPlayer = eligible.filter { $0.age <= 21 && $0.appearances >= 5 }.max { score($0) < score($1) }.map(entry)
        if let scorer = eligible.max(by: { $0.goals != $1.goals ? $0.goals < $1.goals : $0.assists < $1.assists }), scorer.goals > 0 {
            awards.topScorer = entry(scorer)
            awards.topScorerGoals = scorer.goals
        }
        for (position, quota) in [(FootballPosition.goalkeeper, 1), (.defender, 4), (.midfielder, 3), (.forward, 3)] {
            awards.teamOfTheSeason += eligible.filter { $0.position == position }.sorted { score($0) > score($1) }.prefix(quota).map(entry)
        }
        let byStrength = tableA.sorted { ($0.team.strength) > ($1.team.strength) }.map(\.team.id)
        var bestGain = Int.min
        for (finalIndex, row) in tableA.enumerated() {
            let expected = byStrength.firstIndex(of: row.team.id) ?? finalIndex
            let gain = expected - finalIndex
            if gain > bestGain || (gain == bestGain && row.points > (points[awards.coachOfTheYearClubID ?? -1] ?? 0)) {
                bestGain = gain
                awards.coachOfTheYearClubID = row.team.id
            }
        }
        return awards
    }

    // MARK: - Lendas do clube

    mutating func recordLegendIfDeserved(_ player: FootballPlayer) {
        guard player.teamID == selectedClubID, player.careerGoals >= 45 || player.careerAppearances >= 110 else { return }
        guard !legends.contains(where: { $0.id == player.id }) else { return }
        legends.append(LegendEntry(id: player.id, name: player.name, position: player.position, goals: player.careerGoals,
                                   appearances: player.careerAppearances, lastSeason: season))
        addInbox(.news, title: "\(player.name) vira lenda do clube", body: "\(player.name) se aposenta com \(player.careerAppearances) jogos e \(player.careerGoals) gols pelo clube.", playerID: player.id)
    }
}
