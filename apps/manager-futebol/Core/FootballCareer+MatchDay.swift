import Foundation

/// Participação de uma equipe numa partida: quem começou, quem terminou e o estilo usado.
struct MatchParticipation {
    let lineupStart: [Int]
    let lineupEnd: [Int]
    let style: FootballPlayStyle
}

extension FootballCareer {
    // MARK: - Avançar no calendário

    /// Joga o próximo dia de jogo inteiro: com a partida do usuário (simulação rápida) ou sem ela.
    @discardableResult
    mutating func simulateNextMatchDay() -> Bool {
        if canPlay {
            guard beginMatchDay() else { return false }
            return finishMatchDay()
        }
        if canAdvanceWithoutPlaying { return advanceMatchDay() }
        return false
    }

    @discardableResult
    mutating func simulateNextRound() -> Bool { simulateNextMatchDay() }

    /// Treino e recuperação antes de um dia de jogo. No meio de semana todos recuperam menos.
    mutating func prepareMatchDay() {
        guard let slot = currentSlot else { return }
        applyWeeklyTraining(for: slot.index, midweek: slot.isMidweek)
        let aiRecovery = slot.isMidweek ? 4 : 8
        for index in players.indices where players[index].teamID != selectedClubID {
            players[index].condition = min(100, players[index].condition + aiRecovery)
        }
        repairLineup()
    }

    /// Dia de jogo sem o clube do usuário (ex.: fase da copa após eliminação).
    @discardableResult
    mutating func advanceMatchDay() -> Bool {
        guard canAdvanceWithoutPlaying else { return false }
        prepareMatchDay()
        var participation: [MatchParticipation] = []
        for index in fixtures.indices where fixtures[index].matchDay == matchDayIndex && !fixtures[index].isPlayed {
            participation.append(contentsOf: playFullFixture(at: index))
        }
        completeMatchDay(participation: participation, userFixtureIndex: nil)
        return true
    }

    // MARK: - Partida do usuário

    /// Aplica o treino e joga o primeiro tempo da partida do usuário. A carreira fica no intervalo.
    @discardableResult
    mutating func beginMatchDay() -> Bool {
        guard liveMatch == nil, canPlay, let fixture = nextUserFixture else { return false }
        prepareMatchDay()

        let home = side(teamID: fixture.home, opponentID: fixture.away, isHome: true, style: nil)
        let away = side(teamID: fixture.away, opponentID: fixture.home, isHome: false, style: nil)
        var random = FootballRandom(seed: matchSeed(stream: .match, id: fixture.id))
        let half = FootballMatchEngine.simulateHalf(home: home, away: away, half: 1, narrate: true, using: &random)

        let homeName = FootballSeason.teamName(fixture.home)
        let awayName = FootballSeason.teamName(fixture.away)
        let stadium = FootballSeason.team(fixture.home)?.stadium ?? "estádio"
        var kickoff = "Bola rolando no \(stadium): \(homeName) × \(awayName) pela \(fixture.competition.name)"
        if let round = fixture.competition.cupRound { kickoff += " (\(round.name.lowercased()))" }
        if FootballSeason.isDerby(fixture.home, fixture.away) { kickoff += ". É clássico!" } else { kickoff += "." }
        var events = [MatchEvent(minute: 0, kind: .kickoff, teamID: nil, text: kickoff)]
        events.append(contentsOf: half.events)
        events.append(MatchEvent(minute: 45, kind: .halfTime, teamID: nil,
                                 text: "Intervalo: \(homeName) \(half.homeGoals.count) × \(half.awayGoals.count) \(awayName)."))

        liveMatch = LiveMatchState(
            fixtureID: fixture.id,
            matchDay: matchDayIndex,
            homeGoals: half.homeGoals.count,
            awayGoals: half.awayGoals.count,
            homeScorerIDs: half.homeGoals.map(\.scorerID),
            awayScorerIDs: half.awayGoals.map(\.scorerID),
            homeAssistIDs: half.homeGoals.compactMap(\.assistID),
            awayAssistIDs: half.awayGoals.compactMap(\.assistID),
            homeShots: half.homeShots,
            awayShots: half.awayShots,
            homeOnTarget: half.homeOnTarget,
            awayOnTarget: half.awayOnTarget,
            homeExpectedGoals: half.homeExpectedGoals,
            awayExpectedGoals: half.awayExpectedGoals,
            homePossession: half.homePossession,
            events: events,
            firstHalfHomeLineup: home.lineup.map(\.id),
            firstHalfAwayLineup: away.lineup.map(\.id),
            substitutionsUsed: 0,
            styleAtKickoff: playStyle
        )
        return true
    }

    /// Joga o segundo tempo do usuário (com as mudanças do intervalo), prorrogação e pênaltis se for
    /// mata-mata empatado, e depois as demais partidas do dia.
    @discardableResult
    mutating func finishMatchDay() -> Bool {
        guard let live = liveMatch, let selectedClubID,
              let userIndex = fixtures.firstIndex(where: { $0.id == live.fixtureID }) else { return false }
        repairLineup()
        let fixture = fixtures[userIndex]

        let userIsHome = fixture.home == selectedClubID
        let opponentID = fixture.opponent(of: selectedClubID)
        let opponentGoals = userIsHome ? live.awayGoals : live.homeGoals
        let ownGoals = userIsHome ? live.homeGoals : live.awayGoals
        let opponentStyle = aiSecondHalfStyle(teamID: opponentID, opponentID: selectedClubID,
                                              goalsFor: opponentGoals, goalsAgainst: ownGoals)
        let homeStyle = userIsHome ? playStyle : opponentStyle
        let awayStyle = userIsHome ? opponentStyle : playStyle
        let home = side(teamID: fixture.home, opponentID: fixture.away, isHome: true, style: homeStyle, opponentStyle: awayStyle)
        let away = side(teamID: fixture.away, opponentID: fixture.home, isHome: false, style: awayStyle, opponentStyle: homeStyle)
        var random = FootballRandom(seed: matchSeed(stream: .secondHalf, id: fixture.id))
        let second = FootballMatchEngine.simulateHalf(home: home, away: away, half: 2, narrate: true, using: &random)

        var events = live.events
        if playStyle != live.styleAtKickoff {
            events.append(MatchEvent(minute: 46, kind: .tactic, teamID: selectedClubID,
                                     text: "Mudança tática do \(FootballSeason.teamName(selectedClubID)): \(playStyle.rawValue)."))
        }
        if opponentStyle != aiStyle(teamID: opponentID, opponentID: selectedClubID) {
            events.append(MatchEvent(minute: 46, kind: .tactic, teamID: opponentID,
                                     text: "O \(FootballSeason.teamName(opponentID)) volta do intervalo em postura \(opponentStyle.rawValue.lowercased())."))
        }
        events.append(contentsOf: second.events)

        var played = fixture
        var homeScorers = live.homeScorerIDs + second.homeGoals.map(\.scorerID)
        var awayScorers = live.awayScorerIDs + second.awayGoals.map(\.scorerID)
        var assists = live.homeAssistIDs + live.awayAssistIDs + (second.homeGoals + second.awayGoals).compactMap(\.assistID)
        played.homeShots = live.homeShots + second.homeShots
        played.awayShots = live.awayShots + second.awayShots
        played.homeOnTarget = live.homeOnTarget + second.homeOnTarget
        played.awayOnTarget = live.awayOnTarget + second.awayOnTarget
        var homeXG = live.homeExpectedGoals + second.homeExpectedGoals
        var awayXG = live.awayExpectedGoals + second.awayExpectedGoals
        let possession = (live.homePossession + second.homePossession) / 2
        played.homePossession = possession
        played.awayPossession = 100 - possession

        let homeName = FootballSeason.teamName(fixture.home)
        let awayName = FootballSeason.teamName(fixture.away)
        if fixture.competition.isCup && homeScorers.count == awayScorers.count {
            events.append(MatchEvent(minute: 90, kind: .extraTime, teamID: nil,
                                     text: "Empate em \(homeScorers.count) × \(awayScorers.count) no tempo normal. Vamos para a prorrogação!"))
            var extraRandom = FootballRandom(seed: matchSeed(stream: .extraTime, id: fixture.id))
            let extra = FootballMatchEngine.simulateHalf(home: home, away: away, half: 3, narrate: true, using: &extraRandom)
            events.append(contentsOf: extra.events)
            homeScorers += extra.homeGoals.map(\.scorerID)
            awayScorers += extra.awayGoals.map(\.scorerID)
            assists += (extra.homeGoals + extra.awayGoals).compactMap(\.assistID)
            played.homeShots = (played.homeShots ?? 0) + extra.homeShots
            played.awayShots = (played.awayShots ?? 0) + extra.awayShots
            played.homeOnTarget = (played.homeOnTarget ?? 0) + extra.homeOnTarget
            played.awayOnTarget = (played.awayOnTarget ?? 0) + extra.awayOnTarget
            homeXG += extra.homeExpectedGoals
            awayXG += extra.awayExpectedGoals
            played.wentToExtraTime = true
            if homeScorers.count == awayScorers.count {
                var penaltyRandom = FootballRandom(seed: matchSeed(stream: .penalties, id: fixture.id))
                let shootout = FootballMatchEngine.penaltyShootout(home: home, away: away, using: &penaltyRandom)
                events.append(MatchEvent(minute: 120, kind: .extraTime, teamID: nil, text: "Fim da prorrogação. A vaga será decidida nos pênaltis."))
                events.append(contentsOf: shootout.events)
                played.homePenalties = shootout.homeScore
                played.awayPenalties = shootout.awayScore
            }
        }
        played.homeGoals = homeScorers.count
        played.awayGoals = awayScorers.count
        played.homeScorerIDs = homeScorers
        played.awayScorerIDs = awayScorers
        played.homeExpectedGoals = FootballMatchEngine.rounded(homeXG)
        played.awayExpectedGoals = FootballMatchEngine.rounded(awayXG)
        var finalText = "Apito final: \(homeName) \(homeScorers.count) × \(awayScorers.count) \(awayName)"
        if let summary = played.penaltySummary, let winner = played.winner {
            finalText += " (\(summary)). \(FootballSeason.teamName(winner)) avança"
        }
        events.append(MatchEvent(minute: played.wentToExtraTime ? 120 : 90, kind: .fullTime, teamID: nil, text: finalText + "."))
        played.events = events
        fixtures[userIndex] = played
        liveMatch = nil

        recordGoals(homeScorers + awayScorers)
        recordAssists(assists)
        var participation = [
            MatchParticipation(lineupStart: live.firstHalfHomeLineup, lineupEnd: home.lineup.map(\.id), style: homeStyle),
            MatchParticipation(lineupStart: live.firstHalfAwayLineup, lineupEnd: away.lineup.map(\.id), style: awayStyle)
        ]
        for index in fixtures.indices where fixtures[index].matchDay == matchDayIndex && !fixtures[index].isPlayed {
            participation.append(contentsOf: playFullFixture(at: index))
        }
        completeMatchDay(participation: participation, userFixtureIndex: userIndex)
        return true
    }

    // MARK: - Partidas da IA

    /// Simula uma partida inteira entre clubes da IA, com prorrogação e pênaltis no mata-mata.
    mutating func playFullFixture(at index: Int) -> [MatchParticipation] {
        let fixture = fixtures[index]
        let homeStyle = aiStyle(teamID: fixture.home, opponentID: fixture.away)
        let awayStyle = aiStyle(teamID: fixture.away, opponentID: fixture.home)
        let home = side(teamID: fixture.home, opponentID: fixture.away, isHome: true, style: homeStyle, opponentStyle: awayStyle)
        let away = side(teamID: fixture.away, opponentID: fixture.home, isHome: false, style: awayStyle, opponentStyle: homeStyle)
        var random = FootballRandom(seed: matchSeed(stream: .match, id: fixture.id))
        var halves = [
            FootballMatchEngine.simulateHalf(home: home, away: away, half: 1, narrate: false, using: &random),
            FootballMatchEngine.simulateHalf(home: home, away: away, half: 2, narrate: false, using: &random)
        ]
        var played = fixture
        func goals(_ side: KeyPath<HalfResult, [GoalRecord]>) -> [GoalRecord] { halves.flatMap { $0[keyPath: side] } }
        if fixture.competition.isCup && goals(\.homeGoals).count == goals(\.awayGoals).count {
            halves.append(FootballMatchEngine.simulateHalf(home: home, away: away, half: 3, narrate: false, using: &random))
            played.wentToExtraTime = true
            if goals(\.homeGoals).count == goals(\.awayGoals).count {
                let shootout = FootballMatchEngine.penaltyShootout(home: home, away: away, using: &random)
                played.homePenalties = shootout.homeScore
                played.awayPenalties = shootout.awayScore
            }
        }
        let homeGoals = goals(\.homeGoals)
        let awayGoals = goals(\.awayGoals)
        played.homeGoals = homeGoals.count
        played.awayGoals = awayGoals.count
        played.homeScorerIDs = homeGoals.map(\.scorerID)
        played.awayScorerIDs = awayGoals.map(\.scorerID)
        played.homeShots = halves.reduce(0) { $0 + $1.homeShots }
        played.awayShots = halves.reduce(0) { $0 + $1.awayShots }
        played.homeOnTarget = halves.reduce(0) { $0 + $1.homeOnTarget }
        played.awayOnTarget = halves.reduce(0) { $0 + $1.awayOnTarget }
        played.homeExpectedGoals = FootballMatchEngine.rounded(halves.reduce(0) { $0 + $1.homeExpectedGoals })
        played.awayExpectedGoals = FootballMatchEngine.rounded(halves.reduce(0) { $0 + $1.awayExpectedGoals })
        let possession = halves.reduce(0) { $0 + $1.homePossession } / halves.count
        played.homePossession = possession
        played.awayPossession = 100 - possession
        fixtures[index] = played

        recordGoals(played.homeScorerIDs + played.awayScorerIDs)
        recordAssists((homeGoals + awayGoals).compactMap(\.assistID))
        let homeLineup = home.lineup.map(\.id)
        let awayLineup = away.lineup.map(\.id)
        return [
            MatchParticipation(lineupStart: homeLineup, lineupEnd: homeLineup, style: homeStyle),
            MatchParticipation(lineupStart: awayLineup, lineupEnd: awayLineup, style: awayStyle)
        ]
    }

    func side(teamID: Int, opponentID: Int, isHome: Bool, style: FootballPlayStyle?,
              opponentStyle: FootballPlayStyle? = nil) -> MatchSide {
        let ownStyle = style ?? self.style(for: teamID, against: opponentID)
        let rivalStyle = opponentStyle ?? self.style(for: opponentID, against: teamID)
        return MatchSide(
            teamID: teamID,
            lineup: lineup(for: teamID).compactMap { player($0) },
            formation: formation(for: teamID),
            style: ownStyle,
            opponentStyle: rivalStyle,
            isHome: isHome
        )
    }

    mutating func recordGoals(_ scorerIDs: [Int]) {
        for id in scorerIDs {
            guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
            players[index].goals += 1
            players[index].careerGoals += 1
        }
    }

    mutating func recordAssists(_ assistIDs: [Int]) {
        for id in assistIDs {
            guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
            players[index].assists += 1
        }
    }

    // MARK: - Pós-jogo

    /// Desgaste, lesões, evolução da IA, finanças, copa e propostas após todas as partidas do dia.
    mutating func completeMatchDay(participation: [MatchParticipation], userFixtureIndex: Int?) {
        let slot = currentSlot

        // Lesões anteriores avançam um dia de jogo antes de novas lesões serem sorteadas.
        for index in players.indices where players[index].injuryRounds > 0 {
            players[index].injuryRounds -= 1
        }

        var postRandom = FootballRandom(seed: matchSeed(stream: .postMatch, id: matchDayIndex))
        var userInjuries: [String] = []
        var playedIDs = Set<Int>()
        for entry in participation {
            let starters = Set(entry.lineupStart)
            let finishers = Set(entry.lineupEnd)
            for id in starters.union(finishers).sorted() {
                guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
                playedIDs.insert(id)
                players[index].appearances += 1
                let fullMatch = starters.contains(id) && finishers.contains(id)
                let cost = fullMatch ? entry.style.fatigueCost : (entry.style.fatigueCost + 1) / 2
                players[index].condition = max(40, players[index].condition - cost)

                var injuryChance = 0.012
                if players[index].condition < 55 { injuryChance += 0.03 } else if players[index].condition < 70 { injuryChance += 0.012 }
                if entry.style == .highPress { injuryChance += 0.006 }
                if postRandom.chance(injuryChance) {
                    let days = postRandom.int(in: 1...4)
                    players[index].injuryRounds = days
                    if players[index].teamID == selectedClubID {
                        userInjuries.append("\(players[index].name) sofreu uma lesão e ficará fora por \(days) jogo(s).")
                    }
                }
            }
        }
        for index in players.indices where players[index].teamID != nil && !playedIDs.contains(players[index].id) {
            players[index].condition = min(100, players[index].condition + 6)
        }
        if let userFixtureIndex, !userInjuries.isEmpty {
            fixtures[userFixtureIndex].events.append(contentsOf: userInjuries.map {
                MatchEvent(minute: fixtures[userFixtureIndex].wentToExtraTime ? 120 : 90, kind: .injury,
                           teamID: selectedClubID, text: "Departamento médico: \($0)")
            })
        }

        developAIPlayers(using: &postRandom)
        matchDayIndex += 1
        if let userFixtureIndex {
            settleUserMatch(fixture: fixtures[userFixtureIndex])
        } else {
            lastRoundRevenue = 0
        }
        if let cupRound = slot?.cupRound { progressCup(after: cupRound) }
        offers.removeAll { $0.expiresAfterRound <= matchDayIndex }
        generateOffers(using: &postRandom)
        for index in players.indices { refreshValue(at: index) }
        repairLineup()
    }

    mutating func developAIPlayers(using random: inout FootballRandom) {
        for index in players.indices {
            guard let teamID = players[index].teamID, teamID != selectedClubID,
                  players[index].overall < players[index].potential else { continue }
            if random.chance(0.025 * ageMultiplier(players[index].age)) { players[index].overall += 1 }
        }
    }

    /// Bilheteria, bônus da copa e confiança da diretoria após a partida do usuário.
    mutating func settleUserMatch(fixture: LeagueFixture) {
        guard let selectedClubID, let club = selectedClub, let result = fixture.result(for: selectedClubID) else { return }
        let isHome = fixture.home == selectedClubID
        if isHome {
            let formBonus = form(teamID: selectedClubID).filter { $0 == .win }.count * 8_000
            let derbyBonus = FootballSeason.isDerby(fixture.home, fixture.away) ? 1.3 : 1.0
            lastRoundRevenue = Int(Double(club.startingBudget) * 0.018 * derbyBonus) + formBonus
            transferBudget += lastRoundRevenue
        } else {
            lastRoundRevenue = 0
        }
        if let round = fixture.competition.cupRound, fixture.winner == selectedClubID {
            transferBudget += round.advanceBonus
        }

        let expectation = teamRating(selectedClubID) - teamRating(fixture.opponent(of: selectedClubID)) + (isHome ? 1.5 : -1.5)
        var delta: Int
        switch result {
        case .win: delta = expectation < -2 ? 6 : 4
        case .draw: delta = expectation > 3 ? -2 : 1
        case .loss: delta = expectation > 0 ? -6 : -3
        }
        if FootballSeason.isDerby(fixture.home, fixture.away) { delta = delta * 3 / 2 }
        if fixture.competition.isCup, let winner = fixture.winner {
            delta += winner == selectedClubID ? 2 : -2
        }
        boardConfidence = min(100, max(0, boardConfidence + delta))
    }

    mutating func generateOffers(using random: inout FootballRandom) {
        guard let selectedClubID, offers.count < 2, !isSeasonComplete, random.chance(0.3) else { return }
        let candidates = clubRoster
            .filter { candidate in !offers.contains { $0.playerID == candidate.id } }
            .sorted { $0.marketValue > $1.marketValue }
            .prefix(8)
        guard let target = random.pick(Array(candidates)) else { return }
        let buyers = FootballSeason.teams.filter { $0.id != selectedClubID && $0.startingBudget >= target.marketValue / 2 }
        guard let buyer = random.pick(buyers) else { return }
        let amount = Int(Double(target.marketValue) * Double(random.int(in: 95...125)) / 100 / 10_000) * 10_000
        offers.append(TransferOffer(id: nextOfferID, playerID: target.id, clubID: buyer.id,
                                    amount: max(amount, 100_000), expiresAfterRound: matchDayIndex + 2))
        nextOfferID += 1
    }

    // MARK: - Copa

    /// Sorteia uma fase da copa. O clube de divisão inferior joga em casa; na final, o primeiro sorteado.
    mutating func drawCupRound(_ round: CupRound, entrants: [Int]) {
        guard entrants.count >= 2, !fixtures.contains(where: { $0.competition == .cup(round) }) else { return }
        var random = FootballRandom(seed: matchSeed(stream: .cupDraw, id: round.rawValue))
        var pool = entrants.sorted()
        if pool.count > 1 {
            for index in stride(from: pool.count - 1, to: 0, by: -1) {
                pool.swapAt(index, random.int(in: 0...index))
            }
        }
        let matchDay = FootballSeason.matchDayIndex(cupRound: round)
        var nextID = (fixtures.map(\.id).max() ?? -1) + 1
        var index = 0
        while index + 1 < pool.count {
            var home = pool[index]
            var away = pool[index + 1]
            if round != .final, division(of: away) > division(of: home) { swap(&home, &away) }
            fixtures.append(LeagueFixture(id: nextID, matchDay: matchDay, round: round.rawValue,
                                          competition: .cup(round), home: home, away: away))
            nextID += 1
            index += 2
        }
    }

    mutating func progressCup(after round: CupRound) {
        let roundFixtures = fixtures.filter { $0.competition == .cup(round) }
        guard !roundFixtures.isEmpty, roundFixtures.allSatisfy(\.isPlayed) else { return }
        if round == .final {
            if let winner = roundFixtures.first?.winner { cupWinners.append(winner) }
            return
        }
        guard let next = round.next else { return }
        var entrants = roundFixtures.compactMap(\.winner)
        if round == .preliminary {
            let preliminaryTeams = Set(roundFixtures.flatMap { [$0.home, $0.away] })
            entrants += FootballSeason.teams.map(\.id).filter { !preliminaryTeams.contains($0) }
        }
        drawCupRound(next, entrants: entrants)
    }
}
