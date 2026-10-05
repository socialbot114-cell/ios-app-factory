import Foundation

extension FootballCareer {
    // MARK: - Desafios

    /// Cria uma carreira de desafio com o clube, o elenco e as regras do cenário.
    static func challenge(_ scenario: ChallengeScenario) -> FootballCareer {
        var career = FootballCareer(seed: scenario.seed)
        _ = career.chooseClub(scenario.clubID)
        career.difficulty = scenario.difficulty
        for index in career.players.indices where career.players[index].teamID == scenario.clubID {
            if scenario.squadOverallDelta != 0 {
                career.players[index].setOverall(career.players[index].overall + scenario.squadOverallDelta)
            }
            if let maxAge = scenario.youngSquadMaxAge, career.players[index].age > maxAge {
                career.players[index].age = 18 + career.players[index].id % max(1, maxAge - 17)
                career.players[index].potential = min(95, max(career.players[index].potential, career.players[index].overall + 8))
            }
            career.refreshValue(at: index)
            career.players[index].contract.wage = PlayerContract.wage(forValue: career.players[index].marketValue)
        }
        career.transferBudget = scenario.startingCash
        career.finance = FinanceBook()
        if let factor = scenario.wageCapFactor { career.wageCap = Int(Double(career.wageBill) * factor) }
        career.startingXI = career.eligibleLineup()
        career.boardTarget = career.computeBoardTarget()
        career.challenge = ChallengeState(scenarioID: scenario.id, startSeason: career.season, seasonsAllowed: scenario.seasonsAllowed)
        career.addInbox(.board, title: "Desafio: \(scenario.title)", body: "\(scenario.summary) Metas: \(scenario.goals.map(\.text).joined(separator: "; ")).")
        return career
    }

    var challengeScenario: ChallengeScenario? {
        challenge.flatMap { ChallengeScenario.scenario(id: $0.scenarioID) }
    }

    /// Limite de idade dos titulares do desafio em andamento.
    var starterAgeLimit: Int? {
        guard let state = challenge, state.status == .active else { return nil }
        return challengeScenario?.maxStarterAge
    }

    /// Elenco que pode ser escalado respeitando as regras do desafio.
    var lineupEligibleRoster: [FootballPlayer] {
        guard let limit = starterAgeLimit else { return clubRoster }
        let young = clubRoster.filter { $0.age <= limit }
        return young.count >= 11 ? young : clubRoster
    }

    func eligibleLineup() -> [Int] {
        FootballSeason.bestLineup(roster: lineupEligibleRoster, formation: formation, matchDay: matchDayIndex)
    }

    mutating func failChallenge(_ reason: String) {
        guard var state = challenge, state.status == .active else { return }
        state.status = .failed
        state.failureReason = reason
        challenge = state
        addInbox(.board, title: "Desafio fracassado", body: reason)
    }

    /// Regras que valem a cada jogo (idade dos titulares).
    mutating func checkChallengeRules(starters: Set<Int>) {
        guard let limit = starterAgeLimit else { return }
        if let offender = starters.compactMap({ player($0) }).first(where: { $0.age > limit }) {
            failChallenge("\(offender.name) começou um jogo com \(offender.age) anos: o limite do desafio é \(limit).")
        }
    }

    /// Avalia as metas no fim de cada temporada.
    mutating func evaluateChallenge(after record: SeasonRecord) {
        guard var state = challenge, state.status == .active, let scenario = challengeScenario else { return }
        var met = true
        for goal in scenario.goals {
            switch goal.kind {
            case .avoidRelegation: met = met && !record.relegated && record.division == .serieA
            case .finishTop: met = met && record.position <= goal.value
            case .winLeague: met = met && record.position == 1
            case .promotion: met = met && record.promoted
            case .winCup: met = met && record.cupWinnerID == record.clubID
            case .cashAtLeast: met = met && transferBudget >= goal.value
            }
        }
        if met {
            state.status = .won
            state.wonInSeason = record.season
            challenge = state
            addInbox(.board, title: "Desafio vencido!", body: "Você cumpriu todas as metas de \"\(scenario.title)\".")
        } else if record.wasFired {
            challenge = state
            failChallenge("Você foi demitido antes de cumprir as metas.")
        } else if record.season - state.startSeason + 1 >= state.seasonsAllowed {
            challenge = state
            failChallenge("O prazo de \(state.seasonsAllowed) temporada(s) acabou sem as metas cumpridas.")
        } else {
            challenge = state
        }
    }

    // MARK: - Conquistas

    var unlockedAchievementCount: Int { achievements.count }

    func isUnlocked(_ achievement: Achievement) -> Bool { achievements[achievement.rawValue] != nil }

    /// Confere todas as conquistas e anuncia as novas.
    @discardableResult
    mutating func checkAchievements(fixture: LeagueFixture? = nil, record: SeasonRecord? = nil) -> [Achievement] {
        guard selectedClubID != nil else { return [] }
        var unlocked: [Achievement] = []
        for achievement in Achievement.allCases where !isUnlocked(achievement) && isAchieved(achievement, fixture: fixture, record: record) {
            achievements[achievement.rawValue] = season
            unlocked.append(achievement)
            addInbox(.general, title: "Conquista: \(achievement.title)", body: achievement.detail)
        }
        return unlocked
    }

    private func isAchieved(_ achievement: Achievement, fixture: LeagueFixture?, record: SeasonRecord?) -> Bool {
        guard let userID = selectedClubID else { return false }
        func lastThreeAreTitles() -> Bool {
            let last = history.suffix(3)
            return last.count == 3 && last.allSatisfy { $0.championID == $0.clubID || ($0.division == .serieB && $0.position == 1) }
        }
        switch achievement {
        case .firstWin: return (counters["wins"] ?? 0) >= 1
        case .winStreak5: return records.longestWinStreak >= 5
        case .unbeaten10: return records.longestUnbeaten >= 10
        case .bigWin5: return records.biggestWinMargin >= 5
        case .hatTrick: return fixture?.userStats.contains { $0.goals >= 3 } ?? false
        case .derbyWin:
            guard let fixture else { return false }
            return FootballSeason.isDerby(fixture.home, fixture.away) && fixture.winner == userID
        case .shootoutWin:
            guard let fixture else { return false }
            return fixture.homePenalties != nil && fixture.winner == userID
        case .comeback:
            guard let fixture, fixture.winner == userID else { return false }
            var difference = 0
            var worst = 0
            for event in fixture.events where event.kind == .goal {
                difference += event.teamID == userID ? 1 : -1
                worst = min(worst, difference)
            }
            return worst <= -2
        case .giantKiller:
            guard let fixture, fixture.competition.isCup, fixture.winner == userID else { return false }
            return division(of: userID) > division(of: fixture.opponent(of: userID))
        case .leagueTitle: return history.contains { $0.championID == $0.clubID || ($0.division == .serieB && $0.position == 1) }
        case .promotion: return history.contains { $0.promoted }
        case .cupTitle: return history.contains { $0.cupWinnerID == $0.clubID }
        case .doubleWinner: return history.contains { ($0.championID == $0.clubID || ($0.division == .serieB && $0.position == 1)) && $0.cupWinnerID == $0.clubID }
        case .threePeat: return lastThreeAreTitles()
        case .objectiveMet: return history.contains { $0.objectiveMet }
        case .survivor: return history.contains { $0.division == .serieA && $0.target == FootballSeason.teamsPerDivision - FootballSeason.relegationSpots && $0.objectiveMet }
        case .bestPlayerAward: return history.contains { $0.awards?.bestPlayer?.teamID == $0.clubID }
        case .topScorerAward: return history.contains { $0.awards?.topScorer?.teamID == $0.clubID }
        case .coachOfTheYear: return history.contains { $0.awards?.coachOfTheYearClubID == $0.clubID }
        case .millionaire: return transferBudget >= 25_000_000
        case .stadiumLevel3: return stadiumLevel >= 3
        case .allFacilities4: return [trainingCenterLevel, medicalLevel, youthAcademyLevel, stadiumLevel].allSatisfy { $0 >= 4 }
        case .fullStaff: return Set(staff.map(\.role)).count == StaffRole.allCases.count
        case .academyGem: return players.contains { $0.teamID == userID && $0.potential >= 90 && $0.age <= 21 }
        case .starPlayer: return clubRoster.contains { $0.overall >= 85 }
        case .bigSale: return transferLog.contains { $0.fromClubID == userID && !$0.isLoan && $0.fee >= 5_000_000 }
        case .bigSigning: return transferLog.contains { $0.toClubID == userID && !$0.isLoan && $0.fee >= 6_000_000 }
        case .fiveSeasons: return history.count >= 5
        case .tenSeasons: return history.count >= 10
        case .invitationAccepted: return (counters["invitations"] ?? 0) >= 1
        case .reputation90: return reputation >= 90
        case .legendCreated: return !legends.isEmpty
        case .veteran: return (counters["matches"] ?? 0) >= 100
        case .pressMaster: return (counters["press"] ?? 0) >= 20
        case .fansOnFire: return clubHype >= 80
        case .epicComeback: return (counters["comebacks"] ?? 0) >= 3
        case .scoutEye: return scoutReports.count >= 10
        case .youthCup: return youthCupHistory.contains { $0.userResult == "Campeão da Copinha" }
        case .challengeWon: return challenge?.status == .won
        case .betWinner: return (counters["betWins"] ?? 0) >= 1
        case .accumulatorWin: return (counters["accaWins"] ?? 0) >= 1
        case .tipsterKing: return (counters["tipsterTitles"] ?? 0) >= 1
        case .fantasyWinner: return (counters["fantasyWins"] ?? 0) >= 1
        case .viralPost: return world.social.viralPosts >= 1
        case .verifiedProfile: return world.social.verified
        case .proLicense: return world.coach.licenseLevel >= 4
        case .wealthy: return coachNetWorth >= 2_000_000
        case .bookAuthor: return world.coach.booksPublished >= 1
        case .eventsMaster: return (counters["events"] ?? 0) >= 25
        case .questsMaster: return world.quests.completedCount >= 15
        case .brandDeal: return !world.social.brandDeals.isEmpty
        }
    }

    mutating func bump(_ counter: String, by amount: Int = 1) {
        counters[counter, default: 0] += amount
    }

    // MARK: - Tutorial

    var tutorialSteps: [TutorialStep] {
        func seen(_ key: String) -> Bool { tutorialSeen.contains(key) }
        return [
            TutorialStep(id: "scout", title: "Leia o relatório do olheiro",
                         detail: "No Painel, veja a força dos times e o estilo provável do rival antes de cada jogo.", done: seen("dashboard")),
            TutorialStep(id: "lineup", title: "Confira a escalação e a tática",
                         detail: "Na aba Elenco, escolha formação, estilo, instruções e os titulares.", done: seen("squad")),
            TutorialStep(id: "match", title: "Jogue sua primeira partida",
                         detail: "Toque em \"Jogar partida ao vivo\". Você pode pausar a qualquer minuto e fazer mudanças.", done: (counters["matches"] ?? 0) >= 1),
            TutorialStep(id: "press", title: "Responda à imprensa",
                         detail: "Depois do jogo, as respostas mexem com o moral, a torcida e o rival.", done: (counters["press"] ?? 0) >= 1),
            TutorialStep(id: "inbox", title: "Abra a caixa de entrada",
                         detail: "Atletas pedem minutos, contratos vencem e propostas chegam por lá.", done: seen("inbox")),
            TutorialStep(id: "league", title: "Acompanhe a liga e a copa",
                         detail: "Na aba Liga estão a classificação, a copa e a artilharia.", done: seen("table")),
            TutorialStep(id: "market", title: "Visite o mercado",
                         detail: "Na janela de transferências você compra, empresta e observa atletas.", done: seen("market")),
            TutorialStep(id: "club", title: "Conheça as finanças do clube",
                         detail: "Na aba Clube estão caixa, estrutura, comissão técnica e diretoria.", done: seen("club"))
        ]
    }

    var tutorialProgress: (done: Int, total: Int) {
        let steps = tutorialSteps
        return (steps.filter(\.done).count, steps.count)
    }

    var shouldShowTutorial: Bool {
        !tutorialDismissed && tutorialProgress.done < tutorialProgress.total && selectedClubID != nil && history.isEmpty
    }

    mutating func markTutorialSeen(_ key: String) {
        if !tutorialSeen.contains(key) { tutorialSeen.append(key) }
    }

    // MARK: - Simular até a próxima decisão

    /// Joga dias de jogo seguidos (sem coletiva) até acontecer algo que pede a atenção do treinador.
    @discardableResult
    mutating func simulateUntilDecision(maxDays: Int = 30) -> (days: Int, reason: String) {
        var days = 0
        let baseRequests = pendingRequestCount
        let baseOffers = offers.count
        var reason = "Limite de dias atingido."
        while days < maxDays {
            if liveMatch != nil { return (days, "Há uma partida em andamento.") }
            if isFired { return (days, "Você está sem clube.") }
            if isSeasonComplete { return (days, "A temporada terminou.") }
            guard simulateNextMatchDay() else { return (days, "Não foi possível avançar.") }
            days += 1
            skipPress()
            if isFired { reason = "Você foi demitido."; break }
            if isSeasonComplete { reason = "A temporada terminou."; break }
            if pendingRequestCount > baseRequests { reason = "Há mensagens pedindo a sua resposta."; break }
            if offers.count > baseOffers { reason = "Chegou uma proposta por um dos seus atletas."; break }
            if let window = transferWindow, window.isLastDay { reason = "Último dia da janela de transferências."; break }
            if !invitations.isEmpty { reason = "Um clube convidou você para o cargo de treinador."; break }
            if sponsorDeal == nil && !sponsorOffers.isEmpty { reason = "Escolha o patrocinador da temporada."; break }
            if let next = nextUserFixture {
                if FootballSeason.isDerby(next.home, next.away) { reason = "Clássico no próximo jogo."; break }
                if let round = next.competition.cupRound, round >= .semiFinal { reason = "Mata-mata decisivo no próximo jogo."; break }
            }
            if starters.contains(where: { !$0.isAvailable(matchDay: matchDayIndex) }) { reason = "Há titulares indisponíveis."; break }
            if isInDebt { reason = "O clube está no vermelho."; break }
        }
        return (days, reason)
    }
}
