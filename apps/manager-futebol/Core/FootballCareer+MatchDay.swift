import Foundation

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
        let allPlayers = playersByID()
        var outcomes: [(Int, MatchOutcome)] = []
        for index in fixtures.indices where fixtures[index].matchDay == matchDayIndex && !fixtures[index].isPlayed {
            outcomes.append((index, simulateFixture(at: index, players: allPlayers)))
        }
        tickRecovery()
        for (index, outcome) in outcomes { applyOutcome(outcome, fixtureIndex: index, isUser: false) }
        completeMatchDay(userFixtureIndex: nil)
        return true
    }

    // MARK: - Montagem das partidas

    func playersByID() -> [Int: FootballPlayer] {
        Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
    }

    /// Instruções que a IA usa conforme o estilo escolhido.
    func aiInstructions(for style: FootballPlayStyle) -> TeamInstructions {
        var instructions = TeamInstructions()
        switch style {
        case .highPress: instructions.pressing = .high; instructions.lineHeight = .high
        case .defensive: instructions.lineHeight = .low; instructions.pressing = .low
        case .counter: instructions.lineHeight = .low; instructions.tempo = .high
        case .possession: instructions.tempo = .low
        case .attacking: instructions.lineHeight = .high; instructions.width = .high
        case .balanced: break
        }
        return instructions
    }

    func makeSideState(teamID: Int, rivalID: Int, isUser: Bool, styleOverride: FootballPlayStyle? = nil) -> MatchSideState {
        let lineupIDs = lineup(for: teamID)
        let available = players.filter { $0.teamID == teamID && !$0.isYouth && $0.isAvailable(matchDay: matchDayIndex) }
        let bench = available.filter { !lineupIDs.contains($0.id) }.sorted(by: FootballSeason.strongerFirst).prefix(7).map(\.id)
        let style = styleOverride ?? (isUser ? playStyle : aiStyle(teamID: teamID, opponentID: rivalID))
        var conditions: [Int: Double] = [:]
        for id in lineupIDs + bench { conditions[id] = Double(player(id)?.condition ?? 80) }
        var state = MatchSideState(teamID: teamID, formation: formation(for: teamID), style: style,
                                   onPitch: lineupIDs, bench: bench, matchCondition: conditions)
        state.instructions = isUser ? teamInstructions : aiInstructions(for: style)
        state.isUserControlled = isUser
        if isUser {
            state.roles = playerRoles.filter { lineupIDs.contains($0.key) }
            state.penaltyTakerID = penaltyTakerID
        } else if rivalID == selectedClubID {
            state.attackBoost = rivalMotivation[teamID] ?? 0
        }
        return state
    }

    func makeSimulation(fixture: LeagueFixture, detailed: Bool) -> MatchSimulation {
        let userID = selectedClubID
        let home = makeSideState(teamID: fixture.home, rivalID: fixture.away, isUser: detailed && fixture.home == userID)
        let away = makeSideState(teamID: fixture.away, rivalID: fixture.home, isUser: detailed && fixture.away == userID)
        return MatchSimulation.make(fixtureID: fixture.id, seed: matchSeed(stream: .match, id: fixture.id),
                                    isCup: fixture.competition.isCup, isDerby: FootballSeason.isDerby(fixture.home, fixture.away),
                                    detailed: detailed, home: home, away: away)
    }

    func simulateFixture(at index: Int, players allPlayers: [Int: FootballPlayer]) -> MatchOutcome {
        var sim = makeSimulation(fixture: fixtures[index], detailed: false)
        let startHome = sim.home.onPitch
        let startAway = sim.away.onPitch
        sim.runToEnd(players: allPlayers)
        return sim.makeOutcome(players: allPlayers, startHome: startHome, startAway: startAway)
    }

    // MARK: - Partida do usuário

    /// Aplica o treino e cria a partida do usuário no minuto zero. Os demais jogos do dia já são decididos.
    @discardableResult
    mutating func beginMatchDay() -> Bool {
        guard liveMatch == nil, canPlay, let selectedClubID, let fixture = nextUserFixture,
              let fixtureIndex = fixtures.firstIndex(where: { $0.id == fixture.id }) else { return false }
        prepareMatchDay()
        let allPlayers = playersByID()
        var sim = makeSimulation(fixture: fixtures[fixtureIndex], detailed: true)

        var others: [MatchOutcome] = []
        for index in fixtures.indices where fixtures[index].matchDay == matchDayIndex && !fixtures[index].isPlayed && fixtures[index].id != fixture.id {
            others.append(simulateFixture(at: index, players: allPlayers))
        }
        let stadium = FootballSeason.team(fixture.home)?.stadium ?? "estádio"
        var kickoff = "Bola rolando no \(stadium): \(FootballSeason.teamName(fixture.home)) × \(FootballSeason.teamName(fixture.away)) pela \(fixture.competition.name)"
        if let round = fixture.competition.cupRound { kickoff += " (\(round.name.lowercased()))" }
        kickoff += FootballSeason.isDerby(fixture.home, fixture.away) ? ". É clássico!" : "."
        sim.events.append(MatchEvent(minute: 0, kind: .kickoff, teamID: nil, text: kickoff))

        liveMatch = LiveMatchState(sim: sim, matchDay: matchDayIndex, userIsHome: fixture.home == selectedClubID,
                                   homeStart: sim.home.onPitch, awayStart: sim.away.onPitch, others: others,
                                   styleAtKickoff: playStyle)
        return true
    }

    var liveUserSide: MatchTeamSide? {
        liveMatch.map { $0.userIsHome ? .home : .away }
    }

    /// Simula alguns minutos da partida ao vivo.
    mutating func liveAdvance(minutes: Int = 1) {
        guard var live = liveMatch, !live.sim.finished else { return }
        live.sim.advance(to: live.sim.minute + max(1, minutes), players: playersByID())
        liveMatch = live
    }

    mutating func liveAdvance(to minute: Int) {
        guard var live = liveMatch, !live.sim.finished else { return }
        live.sim.advance(to: minute, players: playersByID())
        liveMatch = live
    }

    var liveIsFinished: Bool { liveMatch?.sim.finished ?? false }

    mutating func liveSetStyle(_ style: FootballPlayStyle) {
        guard var live = liveMatch else { return }
        live.sim.setStyle(side: live.userIsHome ? .home : .away, style)
        liveMatch = live
    }

    mutating func liveSetInstructions(_ instructions: TeamInstructions) {
        guard var live = liveMatch else { return }
        live.sim.setInstructions(side: live.userIsHome ? .home : .away, instructions)
        liveMatch = live
    }

    @discardableResult
    mutating func liveSetFormation(_ newFormation: FootballFormation) -> Bool {
        guard var live = liveMatch else { return false }
        live.sim.setFormation(side: live.userIsHome ? .home : .away, newFormation)
        liveMatch = live
        return true
    }

    mutating func liveSetRole(playerID: Int, role: PlayerRole) {
        guard var live = liveMatch else { return }
        let side: MatchTeamSide = live.userIsHome ? .home : .away
        live.sim[side].roles[playerID] = role == .balanced ? nil : role
        live.sim.needsRecompute = true
        liveMatch = live
    }

    mutating func liveSetMarking(targetID: Int?) {
        guard var live = liveMatch else { return }
        let side: MatchTeamSide = live.userIsHome ? .home : .away
        live.sim[side].markTargetID = targetID
        live.sim.needsRecompute = true
        liveMatch = live
    }

    /// Atletas do rival em campo, para a marcação individual.
    var liveRivalOnPitch: [FootballPlayer] {
        guard let live = liveMatch else { return [] }
        let side: MatchTeamSide = live.userIsHome ? .away : .home
        return live.sim[side].onPitch.compactMap { player($0) }
    }

    // MARK: - Substituições (antes e durante a partida)

    func canSubstitute(outgoingID: Int, incomingID: Int) -> Bool {
        if let live = liveMatch {
            return live.sim.canSubstitute(side: live.userIsHome ? .home : .away, out: outgoingID, in: incomingID)
        }
        guard let selectedClubID,
              startingXI.contains(outgoingID), !startingXI.contains(incomingID),
              let incoming = player(incomingID), incoming.teamID == selectedClubID,
              incoming.isAvailable(matchDay: matchDayIndex), !incoming.isYouth else { return false }
        return true
    }

    @discardableResult
    mutating func substitute(outgoingID: Int, incomingID: Int) -> Bool {
        if var live = liveMatch {
            let side: MatchTeamSide = live.userIsHome ? .home : .away
            guard live.sim.substitute(side: side, out: outgoingID, in: incomingID, players: playersByID()) else { return false }
            liveMatch = live
            return true
        }
        guard canSubstitute(outgoingID: outgoingID, incomingID: incomingID),
              let index = startingXI.firstIndex(of: outgoingID) else { return false }
        startingXI[index] = incomingID
        return true
    }

    /// Termina a partida (simulando o que falta), aplica todos os resultados do dia e fecha o dia de jogo.
    @discardableResult
    mutating func finishMatchDay() -> Bool {
        guard var live = liveMatch, let userIndex = fixtures.firstIndex(where: { $0.id == live.fixtureID }) else { return false }
        let allPlayers = playersByID()
        live.sim.runToEnd(players: allPlayers)
        let outcome = live.sim.makeOutcome(players: allPlayers, startHome: live.homeStart, startAway: live.awayStart)
        liveMatch = nil
        tickRecovery()
        applyOutcome(outcome, fixtureIndex: userIndex, isUser: true)
        for other in live.others {
            if let index = fixtures.firstIndex(where: { $0.id == other.fixtureID }) {
                applyOutcome(other, fixtureIndex: index, isUser: false)
            }
        }
        completeMatchDay(userFixtureIndex: userIndex)
        return true
    }

    // MARK: - Aplicação dos resultados

    /// Lesões e suspensões avançam um dia de jogo, só para quem jogou neste dia.
    mutating func tickRecovery() {
        let playing = Set(fixtures.filter { $0.matchDay == matchDayIndex }.flatMap { [$0.home, $0.away] })
        for index in players.indices {
            if players[index].injuryRounds > 0 { players[index].injuryRounds -= 1 }
            if players[index].discipline.suspensionGames > 0, let teamID = players[index].teamID, playing.contains(teamID) {
                players[index].discipline.suspensionGames -= 1
            }
        }
    }

    mutating func applyOutcome(_ outcome: MatchOutcome, fixtureIndex: Int, isUser: Bool) {
        var fixture = fixtures[fixtureIndex]
        fixture.homeGoals = outcome.homeGoals
        fixture.awayGoals = outcome.awayGoals
        fixture.homeScorerIDs = outcome.homeScorerIDs
        fixture.awayScorerIDs = outcome.awayScorerIDs
        fixture.homeShots = outcome.homeShots
        fixture.awayShots = outcome.awayShots
        fixture.homeOnTarget = outcome.homeOnTarget
        fixture.awayOnTarget = outcome.awayOnTarget
        fixture.homeExpectedGoals = outcome.homeExpectedGoals
        fixture.awayExpectedGoals = outcome.awayExpectedGoals
        fixture.homePossession = outcome.homePossession
        fixture.awayPossession = 100 - outcome.homePossession
        fixture.homeCorners = outcome.homeCorners
        fixture.awayCorners = outcome.awayCorners
        fixture.homeFouls = outcome.homeFouls
        fixture.awayFouls = outcome.awayFouls
        fixture.homeYellow = outcome.homeYellow
        fixture.awayYellow = outcome.awayYellow
        fixture.homeRed = outcome.homeRed
        fixture.awayRed = outcome.awayRed
        fixture.wentToExtraTime = outcome.wentToExtraTime
        fixture.homePenalties = outcome.homePenalties
        fixture.awayPenalties = outcome.awayPenalties

        recordGoals(outcome.homeScorerIDs + outcome.awayScorerIDs)
        recordAssists(outcome.homeAssistIDs + outcome.awayAssistIDs)

        // Presença, condição física, lesões e cartões.
        for id in Set(outcome.appeared) {
            guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
            players[index].appearances += 1
            playedThisMatchDay.insert(id)
        }
        for (id, condition) in outcome.finalCondition where outcome.appeared.contains(id) {
            if let index = players.firstIndex(where: { $0.id == id }) { players[index].condition = min(players[index].condition, max(40, condition)) }
        }
        for (id, rounds) in outcome.injuries.sorted(by: { $0.key < $1.key }) {
            guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
            players[index].injuryRounds = max(players[index].injuryRounds, rounds)
            if players[index].teamID == selectedClubID {
                addInbox(.injury, title: "\(players[index].name) se lesionou",
                         body: "Fora por \(rounds) jogo(s) depois da partida contra \(FootballSeason.teamName(fixture.opponent(of: selectedClubID ?? -1))).",
                         playerID: id)
            }
        }
        for id in outcome.yellowCardIDs {
            guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
            players[index].discipline.yellowCards += 1
            if players[index].discipline.yellowCards >= 3 {
                players[index].discipline.yellowCards = 0
                players[index].discipline.suspensionGames = max(players[index].discipline.suspensionGames, 1)
            }
        }
        for id in Set(outcome.redCardIDs) {
            guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
            players[index].discipline.redCards += 1
            let secondYellow = outcome.yellowCardIDs.filter { $0 == id }.count >= 2
            players[index].discipline.suspensionGames = max(players[index].discipline.suspensionGames, secondYellow ? 1 : 2)
        }

        if isUser, let selectedClubID {
            fixture.events = outcome.events
            fixture.momentum = outcome.momentum
            let userIsHome = fixture.home == selectedClubID
            let goalsFor = userIsHome ? outcome.homeGoals : outcome.awayGoals
            let goalsAgainst = userIsHome ? outcome.awayGoals : outcome.homeGoals
            let lineupEnd = (userIsHome ? outcome.homeLineupEnd : outcome.awayLineupEnd).compactMap { player($0) }
            let average = lineupEnd.isEmpty ? 65 : lineupEnd.map(\.effectiveOverall).reduce(0, +) / Double(lineupEnd.count)
            var stats: [PlayerMatchStats] = []
            for var entry in outcome.userStats {
                guard let athlete = player(entry.playerID), athlete.teamID == selectedClubID else { continue }
                entry.rating = FootballRatings.rating(for: athlete, stats: entry, goalsFor: goalsFor, goalsAgainst: goalsAgainst,
                                                      teamAverage: average, noiseSeed: matchSeed(stream: .postMatch, id: 70_000 + fixture.id))
                stats.append(entry)
            }
            fixture.userStats = stats.sorted { $0.playerID < $1.playerID }
            startingXIAtKickoff = Set(userIsHome ? outcome.homeLineupStart : outcome.awayLineupStart)
        }
        fixtures[fixtureIndex] = fixture
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

    /// Evolução da IA, finanças, copa, moral, propostas e coletiva depois de todas as partidas do dia.
    mutating func completeMatchDay(userFixtureIndex: Int?) {
        let slot = currentSlot
        var postRandom = FootballRandom(seed: matchSeed(stream: .postMatch, id: matchDayIndex))
        for index in players.indices where players[index].teamID != nil && !playedThisMatchDay.contains(players[index].id) {
            players[index].condition = min(100, players[index].condition + 6)
        }
        playedThisMatchDay = []

        developAIPlayers(using: &postRandom)
        matchDayIndex += 1
        if let userFixtureIndex {
            let fixture = fixtures[userFixtureIndex]
            settleUserMatch(fixture: fixture)
            if let selectedClubID {
                processUserPlayers(stats: fixture.userStats, result: fixture.result(for: selectedClubID),
                                   derby: FootballSeason.isDerby(fixture.home, fixture.away), started: startingXIAtKickoff)
                rivalMotivation[fixture.opponent(of: selectedClubID)] = nil
                pendingPress = makePressConference(fixture: fixture)
            }
            startingXIAtKickoff = []
        } else {
            lastRoundRevenue = 0
            if selectedClubID != nil { processUserPlayers(stats: [], result: nil, derby: false, started: [], teamPlayed: false) }
        }
        collectMatchDayIncome()
        chargeMatchDayWages()
        generatePlayerRequests()
        if let cupRound = slot?.cupRound { progressCup(after: cupRound) }
        offers.removeAll { $0.expiresAfterRound <= matchDayIndex }
        generateOffers(using: &postRandom)
        for index in players.indices { refreshValue(at: index) }
        repairLineup()
    }

    /// Receitas de todo dia de jogo (a bilheteria é lançada junto com a partida em casa).
    mutating func collectMatchDayIncome() {
        guard let selectedClubID, let club = selectedClub else { return }
        let tv = Int(Double(club.startingBudget) * (division(of: selectedClubID) == .serieA ? 0.012 : 0.006) / 10_000) * 10_000
        book(.tv, tv, "Cotas de TV")
    }

    mutating func developAIPlayers(using random: inout FootballRandom) {
        for index in players.indices {
            guard let teamID = players[index].teamID, teamID != selectedClubID,
                  players[index].overall < players[index].potential else { continue }
            if random.chance(0.025 * ageMultiplier(players[index].age)) { players[index].setOverall(players[index].overall + 1) }
        }
    }

    /// Bilheteria, bônus da copa, torcida e confiança da diretoria após a partida do usuário.
    mutating func settleUserMatch(fixture: LeagueFixture) {
        guard let selectedClubID, let club = selectedClub, let result = fixture.result(for: selectedClubID) else { return }
        let isHome = fixture.home == selectedClubID
        if isHome {
            let formBonus = form(teamID: selectedClubID).filter { $0 == .win }.count * 8_000
            let derbyBonus = FootballSeason.isDerby(fixture.home, fixture.away) ? 1.3 : 1.0
            lastRoundRevenue = Int(Double(club.startingBudget) * 0.018 * derbyBonus) + formBonus
            book(.gate, lastRoundRevenue, "Bilheteria contra \(FootballSeason.teamName(fixture.away))")
        } else {
            lastRoundRevenue = 0
        }
        if let round = fixture.competition.cupRound, fixture.winner == selectedClubID {
            book(.prize, round.advanceBonus, "Classificação na \(round.name)")
        }

        let expectation = teamRating(selectedClubID) - teamRating(fixture.opponent(of: selectedClubID)) + (isHome ? 1.5 : -1.5)
        var delta: Int
        switch result {
        case .win: delta = expectation < -2 ? 6 : 4
        case .draw: delta = expectation > 3 ? -2 : 1
        case .loss: delta = expectation > 0 ? -6 : -3
        }
        let derby = FootballSeason.isDerby(fixture.home, fixture.away)
        if derby { delta = delta * 3 / 2 }
        if fixture.competition.isCup, let winner = fixture.winner {
            delta += winner == selectedClubID ? 2 : -2
        }
        boardConfidence = min(100, max(0, boardConfidence + delta))
        let fanDelta = (result == .win ? 2 : (result == .loss ? -2 : 0)) * (derby ? 2 : 1)
        fanMood = min(100, max(0, fanMood + fanDelta))
    }

    mutating func generateOffers(using random: inout FootballRandom) {
        guard let selectedClubID, offers.count < 2, !isSeasonComplete, random.chance(0.3) else { return }
        let candidates = clubRoster
            .filter { candidate in !offers.contains { $0.playerID == candidate.id } && !candidate.onLoan }
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

    // MARK: - Coletiva de imprensa

    func makePressConference(fixture: LeagueFixture) -> PressConference? {
        guard let selectedClubID else { return nil }
        let result = fixture.result(for: selectedClubID)
        let opponent = FootballSeason.teamName(fixture.opponent(of: selectedClubID))
        let derby = FootballSeason.isDerby(fixture.home, fixture.away)
        var prompts: [String]
        switch result {
        case .win?:
            prompts = ["A vitória sobre o \(opponent) foi merecida? O que o time mostrou hoje?",
                       "A torcida já sonha alto. Qual é o objetivo do clube daqui para a frente?"]
        case .draw?:
            prompts = ["Ficou a sensação de que o time poderia ter vencido o \(opponent)?",
                       "Como o senhor avalia o desempenho do time?"]
        default:
            prompts = ["O resultado aumenta a pressão sobre o seu trabalho. O que o senhor responde?",
                       "O que deu errado diante do \(opponent)?"]
        }
        if derby { prompts.append("Foi um clássico. Que recado o senhor deixa para o rival?") }
        let questions = prompts.enumerated().map { PressQuestion(id: $0.offset + 1, prompt: $0.element) }
        return PressConference(matchDay: matchDayIndex, fixtureID: fixture.id, opponentID: fixture.opponent(of: selectedClubID),
                               result: result, isDerby: derby, questions: questions)
    }

    mutating func answerPress(questionID: Int, tone: PressTone) {
        guard var press = pendingPress, let index = press.questions.firstIndex(where: { $0.id == questionID }),
              press.questions[index].answered == nil, let selectedClubID else { return }
        press.questions[index].answered = tone
        let result = press.result ?? .draw
        func shiftSquadMorale(_ delta: Int) {
            for playerIndex in players.indices where players[playerIndex].teamID == selectedClubID && !players[playerIndex].isYouth {
                players[playerIndex].morale = min(100, max(0, players[playerIndex].morale + delta))
            }
        }
        switch tone {
        case .calm:
            boardConfidence += result == .loss ? 2 : 1
            if result != .loss { fanMood += 1 }
        case .confident:
            if result == .loss {
                shiftSquadMorale(-2)
                fanMood -= 3
                boardConfidence -= 1
            } else {
                shiftSquadMorale(2)
                fanMood += 2
            }
        case .provocative:
            rivalMotivation[press.opponentID] = press.isDerby ? 2.5 : 1.5
            if result == .win { fanMood += 3 } else { fanMood -= 4; boardConfidence -= 2 }
        }
        boardConfidence = min(100, max(0, boardConfidence))
        fanMood = min(100, max(0, fanMood))
        pendingPress = press.isComplete ? nil : press
    }

    mutating func skipPress() {
        pendingPress = nil
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
