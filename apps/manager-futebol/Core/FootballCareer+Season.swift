import Foundation

extension FootballCareer {
    static let freeAgentPoolSize = 18

    /// Monta o calendário da temporada: as duas divisões e a fase preliminar da copa
    /// (os 8 clubes mais fracos da Série B; os 2 mais fortes entram direto nas oitavas).
    mutating func scheduleSeason() {
        var schedule: [LeagueFixture] = []
        for division in Division.allCases {
            schedule += FootballSeason.leagueFixtures(teamIDs: teamIDs(in: division), division: division, firstID: schedule.count)
        }
        fixtures = schedule
        let serieB = teamIDs(in: .serieB).sorted {
            let left = teamRating($0)
            let right = teamRating($1)
            if left != right { return left > right }
            return $0 < $1
        }
        drawCupRound(.preliminary, entrants: Array(serieB.dropFirst(2)))
    }

    /// Encerra a temporada (premiação, acesso e rebaixamento, diretoria, envelhecimento, aposentadorias e base)
    /// e inicia a próxima.
    @discardableResult
    mutating func startNextSeason() -> SeasonRecord? {
        guard isSeasonComplete, liveMatch == nil, let selectedClubID else { return nil }
        let tableA = standings(for: .serieA)
        let tableB = standings(for: .serieB)
        guard let champion = tableA.first?.team.id else { return nil }
        champions.append(champion)
        if cupWinners.count < season, let cupWinner = cupWinnerThisSeason { cupWinners.append(cupWinner) }

        let clubDivision = division(of: selectedClubID)
        let table = clubDivision == .serieA ? tableA : tableB
        let position = (table.firstIndex { $0.team.id == selectedClubID } ?? table.count - 1) + 1
        let points = table.first { $0.team.id == selectedClubID }?.points ?? 0
        let objectiveMet = position <= boardTarget
        let relegatedIDs = tableA.suffix(FootballSeason.relegationSpots).map(\.team.id)
        let promotedIDs = tableB.prefix(FootballSeason.relegationSpots).map(\.team.id)
        let wasPromoted = promotedIDs.contains(selectedClubID)
        let wasRelegated = relegatedIDs.contains(selectedClubID)
        let cupResult = userCupStatus
        let cupWinner = cupWinnerThisSeason

        let prize = FootballSeason.prizeMoney(division: clubDivision, position: position)
            + (objectiveMet ? FootballSeason.objectiveBonus : 0)
            + (cupWinner == selectedClubID ? 1_500_000 : 0)
        book(.prize, prize, "Premiações da temporada \(season)")
        var confidenceChange = objectiveMet ? 15 : -20
        if champion == selectedClubID || (clubDivision == .serieB && position == 1) { confidenceChange += 10 }
        if wasPromoted { confidenceChange += 10 }
        if wasRelegated { confidenceChange -= 15 }
        if cupWinner == selectedClubID { confidenceChange += 8 }
        boardConfidence = min(100, max(0, boardConfidence + confidenceChange))
        let fired = !objectiveMet && boardConfidence <= 20
        let topScorer = topScorers(limit: 1, division: clubDivision).first

        for id in relegatedIDs where divisionOfTeam.indices.contains(id) { divisionOfTeam[id] = .serieB }
        for id in promotedIDs where divisionOfTeam.indices.contains(id) { divisionOfTeam[id] = .serieA }

        finance.summaries.append(finance.summary(season: season, closingCash: transferBudget))
        wageCap = Int(Double(wageCap) * (objectiveMet ? 1.05 : 0.97) * (wasPromoted ? 1.2 : 1) * (wasRelegated ? 0.8 : 1))

        var random = FootballRandom(seed: matchSeed(stream: .offseason, id: 0))
        _ = expireContracts(using: &random)
        let changes = runOffseason(using: &random)

        var record = SeasonRecord(
            season: season,
            clubID: selectedClubID,
            championID: champion,
            position: position,
            points: points,
            target: boardTarget,
            objectiveMet: objectiveMet,
            prizeMoney: prize,
            topScorerName: topScorer?.name ?? "—",
            topScorerTeamID: topScorer?.teamID,
            topScorerGoals: topScorer?.goals ?? 0,
            retiredPlayers: changes.retired,
            youthPromoted: changes.youth,
            wasFired: fired
        )
        record.division = clubDivision
        record.cupResult = cupResult
        record.cupWinnerID = cupWinner
        record.promoted = wasPromoted
        record.relegated = wasRelegated
        history.append(record)

        season += 1
        matchDayIndex = 0
        lastTrainingReport = nil
        lastRoundRevenue = 0
        offers = []
        for index in players.indices {
            players[index].goals = 0
            players[index].assists = 0
            players[index].appearances = 0
            players[index].injuryRounds = 0
            players[index].condition = min(100, players[index].condition + 30)
            players[index].form = PlayerForm()
            players[index].discipline = PlayerDiscipline()
            players[index].benchStreak = 0
            players[index].morale = players[index].teamID == selectedClubID ? (players[index].morale + 60) / 2 : players[index].morale
            refreshValue(at: index)
        }
        promises = []
        ensureMinimumRoster()
        var marketRandom = FootballRandom(seed: matchSeed(stream: .transfers, id: 1))
        refillFreeAgents(using: &marketRandom)
        if !FootballSeason.canFill(roster: clubRoster, formation: formation) { formation = .fourFourTwo }
        startingXI = FootballSeason.bestLineup(roster: clubRoster, formation: formation)
        scheduleSeason()
        boardTarget = computeBoardTarget()
        if fired {
            isFired = true
            boardConfidence = 0
        }
        return record
    }

    /// Envelhecimento, evolução e declínio, aposentadorias com reposição pela base e renovação do mercado.
    mutating func runOffseason(using random: inout FootballRandom) -> (retired: Int, youth: Int) {
        var retired = 0
        var youth = 0
        var survivors: [FootballPlayer] = []
        var replacements: [FootballPlayer] = []

        for var player in players {
            player.age += 1
            if player.age <= 23, player.overall < player.potential {
                player.setOverall(min(player.potential, player.overall + random.int(in: 0...2) + (player.has(.prodigy) ? 1 : 0)))
            } else if player.age <= 28, player.overall < player.potential, random.chance(0.4) {
                player.setOverall(player.overall + 1)
            } else if player.age >= 33 {
                player.decline(by: random.int(in: 1...3), random: &random)
            } else if player.age >= 31 {
                player.decline(by: random.int(in: 0...2), random: &random)
            }
            player.potential = max(player.overall, player.age >= 30 ? player.overall : player.potential)

            let retires = player.age >= 36 || (player.age >= 33 && random.chance(0.3))
            if retires {
                if player.teamID == selectedClubID { retired += 1 }
                if let teamID = player.teamID {
                    let baseStrength = (FootballSeason.team(teamID)?.strength ?? 65) + (division(of: teamID) == .serieA ? 2 : -2)
                    replacements.append(FootballSeason.makeYouth(id: nextPlayerID, position: player.position,
                                                                 teamStrength: baseStrength, teamID: teamID, using: &random))
                    nextPlayerID += 1
                    if teamID == selectedClubID { youth += 1 }
                }
                continue
            }
            survivors.append(player)
        }
        players = survivors + replacements

        refillFreeAgents(using: &random)
        return (retired, youth)
    }

    /// Mantém o mercado de agentes livres com um mínimo de atletas.
    mutating func refillFreeAgents(using random: inout FootballRandom) {
        let marketCount = players.filter { $0.teamID == nil }.count
        guard marketCount < Self.freeAgentPoolSize else { return }
        for offset in 0..<(Self.freeAgentPoolSize - marketCount) {
            let position = FootballSeason.freeAgentTemplate[offset % FootballSeason.freeAgentTemplate.count]
            players.append(FootballSeason.makeFreeAgent(id: nextPlayerID, position: position, season: season, using: &random))
            nextPlayerID += 1
        }
    }
}
