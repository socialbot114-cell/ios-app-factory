import Foundation

struct MatchProbabilities: Equatable {
    var homeWin: Double
    var draw: Double
    var awayWin: Double
    var over25: Double
    var bothScore: Double
    var homeLambda: Double
    var awayLambda: Double
    /// Probabilidade de cada placar (mandante × visitante) de 0 a 6 gols.
    var grid: [[Double]]

    var under25: Double { 1 - over25 }
}

struct BetOption: Equatable, Identifiable {
    let leg: BetLeg
    var id: String { leg.id }
}

extension FootballCareer {
    static let bookmakerMargin = 1.08
    static let betMinimum = 10
    static let betMaximum = 500
    static let betMaxLegs = 5

    // MARK: - Probabilidades a partir do motor

    private static func poisson(_ lambda: Double, _ k: Int) -> Double {
        var result = exp(-lambda)
        if k > 0 { for index in 1...k { result *= lambda / Double(index) } }
        return result
    }

    func probabilities(for fixture: LeagueFixture) -> MatchProbabilities {
        func side(_ teamID: Int, _ rival: Int, home: Bool) -> MatchSide {
            let lineupPlayers = lineup(for: teamID).compactMap { player($0) }
            return MatchSide(teamID: teamID, lineup: lineupPlayers, formation: formation(for: teamID),
                             style: style(for: teamID, against: rival), opponentStyle: style(for: rival, against: teamID), isHome: home)
        }
        let homeSide = side(fixture.home, fixture.away, home: true)
        let awaySide = side(fixture.away, fixture.home, home: false)
        let share = min(0.7, max(0.3, 0.5 + (homeSide.control - awaySide.control) * 0.015))
        let homeLambda = FootballMatchEngine.expectedGoals(attack: homeSide.attack, defense: awaySide.defense, possessionShare: share) * 2 * MatchSimulation.goalCalibration * 1.12
        let awayLambda = FootballMatchEngine.expectedGoals(attack: awaySide.attack, defense: homeSide.defense, possessionShare: 1 - share) * 2 * MatchSimulation.goalCalibration * 1.12
        let size = 9
        var grid = Array(repeating: Array(repeating: 0.0, count: size), count: size)
        var total = 0.0
        for home in 0..<size {
            for away in 0..<size {
                let value = Self.poisson(homeLambda, home) * Self.poisson(awayLambda, away)
                grid[home][away] = value
                total += value
            }
        }
        var homeWin = 0.0, draw = 0.0, awayWin = 0.0, over = 0.0, both = 0.0
        for home in 0..<size {
            for away in 0..<size {
                grid[home][away] /= total
                let value = grid[home][away]
                if home > away { homeWin += value } else if home == away { draw += value } else { awayWin += value }
                if home + away >= 3 { over += value }
                if home > 0 && away > 0 { both += value }
            }
        }
        return MatchProbabilities(homeWin: homeWin, draw: draw, awayWin: awayWin, over25: over, bothScore: both,
                                  homeLambda: homeLambda, awayLambda: awayLambda, grid: grid)
    }

    /// Odd decimal a partir da probabilidade, com a margem da casa, arredondada de 0,05 em 0,05.
    static func odds(for probability: Double, margin: Double = bookmakerMargin) -> Double {
        let raw = 1 / max(0.0005, probability * margin)
        let rounded = (raw * 20).rounded() / 20
        return min(80, max(1.05, rounded))
    }

    // MARK: - Mercados

    /// Jogos que ainda vão acontecer no dia de jogo atual.
    var bettingFixtures: [LeagueFixture] {
        guard !isSeasonComplete else { return [] }
        return fixtures.filter { $0.matchDay == matchDayIndex && !$0.isPlayed }
    }

    func isIntegrityViolation(market: BetMarket, a: Int, b: Int = 0, fixture: LeagueFixture) -> Bool {
        guard let selectedClubID, fixture.involves(selectedClubID) else { return false }
        let userIsHome = fixture.home == selectedClubID
        switch market {
        case .homeWin: return !userIsHome
        case .awayWin: return userIsHome
        case .draw: return false
        case .exactScore:
            // Placar em que o adversário vence é uma aposta contra o próprio clube.
            return userIsHome ? a < b : a > b
        case .scorer: return player(a)?.teamID == fixture.opponent(of: selectedClubID)
        case .qualify: return a != selectedClubID
        default: return false
        }
    }

    func options(for fixture: LeagueFixture) -> [BetOption] {
        let p = probabilities(for: fixture)
        let home = FootballSeason.teamName(fixture.home)
        let away = FootballSeason.teamName(fixture.away)
        var output: [BetOption] = []
        func add(_ market: BetMarket, _ a: Int, _ b: Int, _ probability: Double, _ text: String, margin: Double = Self.bookmakerMargin) {
            let leg = BetLeg(fixtureID: fixture.id, market: market, a: a, b: b, odds: Self.odds(for: probability, margin: margin), description: text)
            guard !isIntegrityViolation(market: market, a: a, b: b, fixture: fixture) else { return }
            output.append(BetOption(leg: leg))
        }
        add(.homeWin, 0, 0, p.homeWin, "\(home) vence")
        add(.draw, 0, 0, p.draw, "Empate")
        add(.awayWin, 0, 0, p.awayWin, "\(away) vence")
        add(.over25, 0, 0, p.over25, "Mais de 2,5 gols")
        add(.under25, 0, 0, p.under25, "Menos de 2,5 gols")
        add(.bothScore, 0, 0, p.bothScore, "Ambos marcam")
        if fixture.competition.isCup {
            let homeQualify = p.homeWin + p.draw * (0.5 + (p.homeWin - p.awayWin) * 0.25)
            add(.qualify, fixture.home, 0, homeQualify, "\(home) se classifica")
            add(.qualify, fixture.away, 0, 1 - homeQualify, "\(away) se classifica")
        }
        var scores: [(Int, Int, Double)] = []
        for h in 0..<5 { for a in 0..<5 { scores.append((h, a, p.grid[h][a])) } }
        for score in scores.sorted(by: { $0.2 > $1.2 }).prefix(6) {
            add(.exactScore, score.0, score.1, score.2, "Placar exato \(score.0) × \(score.1)", margin: 1.15)
        }
        // Quem marca: os candidatos mais prováveis de cada lado.
        for (teamID, lambda) in [(fixture.home, p.homeLambda), (fixture.away, p.awayLambda)] {
            let lineupPlayers = lineup(for: teamID).compactMap { player($0) }.filter { $0.position != .goalkeeper }
            let weights = lineupPlayers.map { Double($0.position.scoringWeight * max(1, $0.attributes[.finishing] * 3 + $0.overall - 60)) * ($0.has(.naturalFinisher) ? 1.35 : 1.0) }
            let total = max(1, weights.reduce(0, +))
            let ranked = zip(lineupPlayers, weights).sorted { $0.1 > $1.1 }.prefix(3)
            for (athlete, weight) in ranked {
                let probability = 1 - exp(-lambda * weight / total)
                add(.scorer, athlete.id, 0, probability, "\(athlete.name) marca", margin: 1.12)
            }
        }
        return output
    }

    // MARK: - Regras de jogo responsável

    var bettingWallet: Int { world.betting.fichas }

    var isSelfExcluded: Bool { world.betting.selfExcludedUntilWorldDay >= worldDay }

    var maxStake: Int { min(Self.betMaximum, max(Self.betMinimum, world.betting.fichas / 5)) }

    /// Perdas líquidas nos últimos quatro dias de jogo.
    var recentBettingLoss: Int {
        let net = (0..<4).reduce(0) { $0 + (world.betting.dailyNet[worldDay - $1] ?? 0) }
        return max(0, -net)
    }

    func stakeBlockReason(_ stake: Int) -> String? {
        guard selectedClubID != nil, !isFired else { return "Sem clube." }
        if isSelfExcluded { return "Autoexclusão ativa: você pediu uma pausa nas apostas." }
        if stake < Self.betMinimum { return "Aposta mínima: \(Self.betMinimum) fichas." }
        if stake > maxStake { return "Aposta máxima agora: \(maxStake) fichas." }
        if stake > world.betting.fichas { return "Fichas insuficientes." }
        if recentBettingLoss >= world.betting.lossLimit { return "Limite de perdas atingido. Volte em alguns dias de jogo." }
        return nil
    }

    func betBlockReason(stake: Int, legs: [BetLeg]) -> String? {
        if let reason = stakeBlockReason(stake) { return reason }
        if legs.isEmpty { return "Escolha ao menos uma seleção." }
        if legs.count > Self.betMaxLegs { return "No máximo \(Self.betMaxLegs) seleções por bilhete." }
        if Set(legs.map(\.fixtureID)).count != legs.count { return "Uma seleção por jogo na múltipla." }
        let fixtureIDs = Set(bettingFixtures.map(\.id))
        if !legs.allSatisfy({ fixtureIDs.contains($0.fixtureID) }) { return "O jogo selecionado já começou." }
        return nil
    }

    @discardableResult
    mutating func placeBet(stake: Int, legs: [BetLeg]) -> Bet? {
        guard betBlockReason(stake: stake, legs: legs) == nil else { return nil }
        let bet = Bet(id: world.betting.nextBetID, season: season, placedMatchDay: matchDayIndex, stake: stake, legs: legs)
        world.betting.nextBetID += 1
        world.betting.fichas -= stake
        world.betting.bets.insert(bet, at: 0)
        if world.betting.bets.count > 80 { world.betting.bets.removeLast(world.betting.bets.count - 80) }
        bump("bets")
        return bet
    }

    var dailyBonusAvailable: Bool { worldDay - world.betting.lastDailyBonusWorldDay >= 4 }

    @discardableResult
    mutating func claimDailyBonus() -> Int? {
        guard dailyBonusAvailable, !isSelfExcluded else { return nil }
        world.betting.lastDailyBonusWorldDay = worldDay
        world.betting.fichas += 200
        return 200
    }

    /// Fichas de emergência: uma vez por temporada, para ninguém ficar travado sem fichas.
    @discardableResult
    mutating func claimEmergencyFichas() -> Int? {
        guard world.betting.fichas < Self.betMinimum, world.betting.emergencyUsedSeason != season else { return nil }
        world.betting.emergencyUsedSeason = season
        world.betting.fichas += 300
        return 300
    }

    mutating func selfExclude(days: Int) {
        world.betting.selfExcludedUntilWorldDay = worldDay + max(1, days)
    }

    mutating func setLossLimit(_ limit: Int) {
        world.betting.lossLimit = min(5_000, max(100, limit))
    }

    // MARK: - Liquidação

    private func outcome(of leg: BetLeg, in fixture: LeagueFixture) -> Bool? {
        guard let homeGoals = fixture.homeGoals, let awayGoals = fixture.awayGoals else { return nil }
        switch leg.market {
        case .homeWin: return homeGoals > awayGoals
        case .draw: return homeGoals == awayGoals
        case .awayWin: return awayGoals > homeGoals
        case .over25: return homeGoals + awayGoals >= 3
        case .under25: return homeGoals + awayGoals <= 2
        case .bothScore: return homeGoals > 0 && awayGoals > 0
        case .exactScore: return homeGoals == leg.a && awayGoals == leg.b
        case .scorer: return fixture.homeScorerIDs.contains(leg.a) || fixture.awayScorerIDs.contains(leg.a)
        case .qualify: return fixture.winner == leg.a
        }
    }

    /// Resolve os bilhetes cujos jogos terminaram e paga os vencedores.
    mutating func settleBets() {
        var changed = false
        for index in world.betting.bets.indices where world.betting.bets[index].status == .open {
            var bet = world.betting.bets[index]
            for legIndex in bet.legs.indices where bet.legs[legIndex].won == nil {
                guard let fixture = fixtures.first(where: { $0.id == bet.legs[legIndex].fixtureID }), fixture.isPlayed else { continue }
                bet.legs[legIndex].won = outcome(of: bet.legs[legIndex], in: fixture)
            }
            if bet.legs.contains(where: { $0.won == false }) {
                bet.status = .lost
            } else if bet.legs.allSatisfy({ $0.won == true }) {
                bet.status = .won
                bet.payout = bet.potentialPayout
            }
            guard bet.status != .open else { world.betting.bets[index] = bet; continue }
            world.betting.bets[index] = bet
            changed = true
            let net = bet.payout - bet.stake
            world.betting.fichas += bet.payout
            world.betting.dailyNet[worldDay, default: 0] += net
            world.betting.lifetimeProfit += net
            world.betting.seasonProfit += net
            if bet.status == .won {
                world.betting.wins += 1
                world.betting.lossStreak = 0
                world.betting.biggestWin = max(world.betting.biggestWin, net)
                if bet.legs.count >= 4 { bump("accaWins") }
                bump("betWins")
            } else {
                world.betting.losses += 1
                world.betting.lossStreak += 1
            }
        }
        for key in world.betting.dailyNet.keys where key < worldDay - 12 { world.betting.dailyNet[key] = nil }
        if changed, world.betting.lossStreak >= 3, !inbox.contains(where: { $0.title == "Que tal uma pausa?" && $0.matchDay == matchDayIndex }) {
            addInbox(.bet, title: "Que tal uma pausa?", body: "Você perdeu \(world.betting.lossStreak) bilhetes seguidos. As apostas são só um jogo com fichas fictícias: nas configurações do Palpite+ você pode definir um limite de perdas ou pedir autoexclusão.")
        }
        if changed, let settled = world.betting.bets.first(where: { $0.status == .won && $0.placedMatchDay == matchDayIndex - 1 }) {
            addInbox(.bet, title: "Bilhete premiado!", body: "Você ganhou \(settled.payout) fichas com odd \(String(format: "%.2f", settled.totalOdds)).")
        }
    }

    // MARK: - Apostas de longo prazo

    var outrightsOpen: Bool { matchDayIndex <= 8 && !isSeasonComplete }

    /// Probabilidade de cada clube em cada mercado de longo prazo, pela força das escalações.
    func outrightProbabilities(_ market: OutrightMarket) -> [Int: Double] {
        let teams = market == .cupWinner ? FootballSeason.teams.map(\.id) : teamIDs(in: .serieA)
        let ratings = teams.map { teamRating($0) }
        let sign: Double = market == .relegated ? -1 : 1
        var weights = ratings.map { exp(sign * $0 / 3.2) }
        if market == .cupWinner {
            for (index, team) in teams.enumerated() where division(of: team) == .serieB { weights[index] *= 0.7 }
        }
        let total = weights.reduce(0, +)
        var result: [Int: Double] = [:]
        for (index, team) in teams.enumerated() {
            var probability = weights[index] / total
            if market == .relegated { probability = min(0.9, probability * Double(FootballSeason.relegationSpots)) }
            result[team] = probability
        }
        return result
    }

    func outrightOdds(_ market: OutrightMarket, clubID: Int) -> Double? {
        guard let probability = outrightProbabilities(market)[clubID] else { return nil }
        return Self.odds(for: probability, margin: 1.15)
    }

    @discardableResult
    mutating func placeOutright(market: OutrightMarket, clubID: Int, stake: Int) -> OutrightBet? {
        guard outrightsOpen, stakeBlockReason(stake) == nil,
              let odds = outrightOdds(market, clubID: clubID), clubID != selectedClubID || market != .relegated else { return nil }
        let bet = OutrightBet(id: world.betting.nextBetID, season: season, market: market, clubID: clubID, stake: stake, odds: odds)
        world.betting.nextBetID += 1
        world.betting.fichas -= stake
        world.betting.outrights.insert(bet, at: 0)
        bump("bets")
        return bet
    }

    mutating func settleOutrights(champion: Int, relegated: [Int], cupWinner: Int?) {
        for index in world.betting.outrights.indices where world.betting.outrights[index].status == .open && world.betting.outrights[index].season == season {
            var bet = world.betting.outrights[index]
            let won: Bool
            switch bet.market {
            case .leagueWinner: won = bet.clubID == champion
            case .relegated: won = relegated.contains(bet.clubID)
            case .cupWinner: won = bet.clubID == cupWinner
            }
            bet.status = won ? .won : .lost
            if won {
                bet.payout = Int(Double(bet.stake) * bet.odds)
                world.betting.fichas += bet.payout
                world.betting.wins += 1
                bump("betWins")
            } else {
                world.betting.losses += 1
            }
            let net = bet.payout - bet.stake
            world.betting.lifetimeProfit += net
            world.betting.seasonProfit += net
            world.betting.biggestWin = max(world.betting.biggestWin, net)
            world.betting.outrights[index] = bet
        }
    }

    // MARK: - Ranking de palpiteiros

    mutating func ensureTipsters() {
        guard world.betting.tipsters.isEmpty else { return }
        let names = ["Zeca do Palpite", "Dona Marta Analista", "Professor Odds", "Chico Placar", "Tati Estatística", "Mestre Dados", "Zé Sorte"]
        var random = FootballRandom(seed: matchSeed(stream: .betting, id: 1))
        world.betting.tipsters = names.enumerated().map { Tipster(id: $0.offset + 1, name: $0.element, skill: 0.4 + random.unit() * 0.3, profit: 0) }
    }

    mutating func updateTipsters(using random: inout FootballRandom) {
        ensureTipsters()
        for index in world.betting.tipsters.indices {
            let tipster = world.betting.tipsters[index]
            let swing = (tipster.skill - 0.52) * 260 + (random.unit() - 0.5) * 420
            world.betting.tipsters[index].profit += Int(swing)
        }
        recordTipsterPicks()
    }

    /// Posição do usuário no ranking de lucro da temporada (1 é o melhor).
    var tipsterRank: Int {
        let better = world.betting.tipsters.filter { $0.profit > world.betting.seasonProfit }.count
        return better + 1
    }

    mutating func closeBettingSeason() {
        if tipsterRank == 1 && !world.betting.tipsters.isEmpty { bump("tipsterTitles") }
        world.betting.seasonProfit = 0
        for index in world.betting.tipsters.indices { world.betting.tipsters[index].profit = 0 }
        world.betting.outrights.removeAll { $0.status != .open }
    }
}
