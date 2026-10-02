import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballBettingTests: XCTestCase {
    private func career(club: Int = 0, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    private func otherFixture(_ career: FootballCareer) throws -> LeagueFixture {
        try XCTUnwrap(career.bettingFixtures.first { !$0.involves(0) && $0.competition.division == .serieA })
    }

    // MARK: - Odds

    func testProbabilitiesAreCoherentAndOddsCarryTheBookmakerMargin() throws {
        let career = career()
        for fixture in career.bettingFixtures {
            let p = career.probabilities(for: fixture)
            XCTAssertEqual(p.homeWin + p.draw + p.awayWin, 1, accuracy: 0.0001)
            XCTAssertEqual(p.grid.flatMap { $0 }.reduce(0, +), 1, accuracy: 0.0001)
            XCTAssertTrue((0...1).contains(p.over25) && (0...1).contains(p.bothScore))
            XCTAssertGreaterThan(p.homeLambda, 0.2)
            XCTAssertLessThan(p.homeLambda, 4)
            let overround = 1 / FootballCareer.odds(for: p.homeWin) + 1 / FootballCareer.odds(for: p.draw) + 1 / FootballCareer.odds(for: p.awayWin)
            XCTAssertGreaterThan(overround, 1.0, "A casa sempre fica com uma margem")
            XCTAssertLessThan(overround, 1.25)
        }
        let strong = LeagueFixture(id: 7_001, matchDay: 0, round: 1, competition: .league(.serieA), home: 0, away: 9)
        let weak = LeagueFixture(id: 7_002, matchDay: 0, round: 1, competition: .league(.serieA), home: 9, away: 0)
        let favorite = career.probabilities(for: strong)
        let underdog = career.probabilities(for: weak)
        XCTAssertGreaterThan(favorite.homeWin, favorite.awayWin)
        XCTAssertGreaterThan(underdog.awayWin, underdog.homeWin)
        XCTAssertLessThan(FootballCareer.odds(for: favorite.homeWin), FootballCareer.odds(for: favorite.awayWin), "Favorito paga menos")
        XCTAssertGreaterThanOrEqual(FootballCareer.odds(for: 0.9), 1.05)
        XCTAssertLessThanOrEqual(FootballCareer.odds(for: 0.0001), 80)
        XCTAssertEqual((FootballCareer.odds(for: 0.37) * 20).rounded(), FootballCareer.odds(for: 0.37) * 20, accuracy: 0.0001, "Múltiplos de 0,05")
    }

    func testOddsMatchSimulatedFrequencies() throws {
        let career = career()
        let fixture = try otherFixture(career)
        let p = career.probabilities(for: fixture)
        let players = career.playersByID()
        let base = career.makeSimulation(fixture: fixture, detailed: false)
        var home = 0, draw = 0, away = 0, over = 0
        let runs = 600
        for seed in 1...runs {
            var sim = MatchSimulation.make(fixtureID: 1, seed: UInt64(seed) &* 2_654_435_761, isCup: false, isDerby: false, detailed: false, home: base.home, away: base.away)
            sim.runToEnd(players: players)
            if sim.home.goals > sim.away.goals { home += 1 } else if sim.home.goals == sim.away.goals { draw += 1 } else { away += 1 }
            if sim.home.goals + sim.away.goals >= 3 { over += 1 }
        }
        XCTAssertEqual(Double(home) / Double(runs), p.homeWin, accuracy: 0.09)
        XCTAssertEqual(Double(draw) / Double(runs), p.draw, accuracy: 0.08)
        XCTAssertEqual(Double(away) / Double(runs), p.awayWin, accuracy: 0.09)
        XCTAssertEqual(Double(over) / Double(runs), p.over25, accuracy: 0.09)
    }

    func testOptionsCoverMarketsAndNeverLetYouBetAgainstYourOwnClub() throws {
        let career = career()
        let own = try XCTUnwrap(career.bettingFixtures.first { $0.involves(0) })
        let options = career.options(for: own)
        let markets = Set(options.map(\.leg.market))
        XCTAssertTrue(markets.isSuperset(of: [.draw, .over25, .under25, .bothScore, .exactScore, .scorer]))
        let userIsHome = own.home == 0
        XCTAssertEqual(options.contains { $0.leg.market == .homeWin }, userIsHome)
        XCTAssertEqual(options.contains { $0.leg.market == .awayWin }, !userIsHome)
        for option in options where option.leg.market == .exactScore {
            XCTAssertTrue(userIsHome ? option.leg.a >= option.leg.b : option.leg.a <= option.leg.b, "Sem placares em que o seu clube perde")
        }
        for option in options where option.leg.market == .scorer {
            XCTAssertEqual(career.player(option.leg.a)?.teamID, 0, "Só artilheiros do seu clube")
        }
        let neutral = try otherFixture(career)
        let neutralMarkets = Set(career.options(for: neutral).map(\.leg.market))
        XCTAssertTrue(neutralMarkets.isSuperset(of: [.homeWin, .awayWin]))
        XCTAssertTrue(career.options(for: neutral).allSatisfy { $0.leg.odds >= 1.05 && $0.leg.odds <= 80 })
    }

    // MARK: - Apostas

    func testPlacingBetsDeductsStakeAndEnforcesResponsibleLimits() throws {
        var career = career()
        let fixture = try otherFixture(career)
        let leg = try XCTUnwrap(career.options(for: fixture).first { $0.leg.market == .homeWin }).leg
        XCTAssertEqual(career.world.betting.fichas, 1_000)
        XCTAssertEqual(career.maxStake, 200)
        XCTAssertNotNil(career.betBlockReason(stake: 5, legs: [leg]))
        XCTAssertNotNil(career.betBlockReason(stake: 300, legs: [leg]), "Limite de 20% das fichas")
        XCTAssertNotNil(career.betBlockReason(stake: 50, legs: []))
        XCTAssertNil(career.betBlockReason(stake: 50, legs: [leg]))
        let bet = try XCTUnwrap(career.placeBet(stake: 50, legs: [leg]))
        XCTAssertEqual(career.world.betting.fichas, 950)
        XCTAssertEqual(bet.status, .open)
        XCTAssertEqual(bet.potentialPayout, Int(50 * leg.odds))
        XCTAssertEqual(career.counters["bets"], 1)

        // Múltipla: uma seleção por jogo e no máximo cinco.
        let second = try XCTUnwrap(career.bettingFixtures.first { $0.id != fixture.id && !$0.involves(0) })
        let leg2 = try XCTUnwrap(career.options(for: second).first { $0.leg.market == .over25 }).leg
        let accumulator = try XCTUnwrap(career.placeBet(stake: 20, legs: [leg, leg2]))
        XCTAssertEqual(accumulator.totalOdds, leg.odds * leg2.odds, accuracy: 0.0001)
        XCTAssertNotNil(career.betBlockReason(stake: 20, legs: [leg, leg]), "Mesmo jogo duas vezes")
        let many = career.bettingFixtures.filter { !$0.involves(0) }.prefix(6).compactMap { career.options(for: $0).first?.leg }
        XCTAssertEqual(many.count, 6)
        XCTAssertNotNil(career.betBlockReason(stake: 20, legs: many), "No máximo cinco seleções")

        // Limite de perdas, autoexclusão e bônus.
        career.world.betting.dailyNet[career.worldDay] = -1_200
        XCTAssertNotNil(career.betBlockReason(stake: 20, legs: [leg]))
        career.world.betting.dailyNet = [:]
        career.selfExclude(days: 3)
        XCTAssertTrue(career.isSelfExcluded)
        XCTAssertNotNil(career.betBlockReason(stake: 20, legs: [leg]))
        XCTAssertNil(career.claimDailyBonus())
        career.world.betting.selfExcludedUntilWorldDay = -1
        XCTAssertTrue(career.dailyBonusAvailable)
        XCTAssertEqual(career.claimDailyBonus(), 200)
        XCTAssertNil(career.claimDailyBonus(), "Um bônus a cada quatro dias de jogo")

        career.world.betting.fichas = 3
        XCTAssertEqual(career.claimEmergencyFichas(), 300)
        career.world.betting.fichas = 3
        XCTAssertNil(career.claimEmergencyFichas(), "Uma vez por temporada")
        career.setLossLimit(10)
        XCTAssertEqual(career.world.betting.lossLimit, 100)
    }

    func testBetsSettleAgainstRealResultsAndPayCorrectly() throws {
        var career = career()
        let fixtures = career.bettingFixtures.filter { !$0.involves(0) }
        var placed: [(Bet, LeagueFixture)] = []
        for fixture in fixtures.prefix(4) {
            for option in career.options(for: fixture) where [.homeWin, .draw, .awayWin, .over25].contains(option.leg.market) {
                if let bet = career.placeBet(stake: 10, legs: [option.leg]) { placed.append((bet, fixture)) }
            }
        }
        // Uma múltipla com três jogos e uma aposta de placar exato.
        let legs = fixtures.prefix(3).compactMap { career.options(for: $0).first { $0.leg.market == .bothScore }?.leg }
        let accumulator = try XCTUnwrap(career.placeBet(stake: 10, legs: legs))
        let walletBefore = career.world.betting.fichas
        XCTAssertTrue(career.simulateNextMatchDay())

        var expected = walletBefore
        for (bet, fixture) in placed {
            let settled = try XCTUnwrap(career.world.betting.bets.first { $0.id == bet.id })
            let played = try XCTUnwrap(career.fixtures.first { $0.id == fixture.id })
            let leg = bet.legs[0]
            let home = played.homeGoals!, away = played.awayGoals!
            let won: Bool
            switch leg.market {
            case .homeWin: won = home > away
            case .draw: won = home == away
            case .awayWin: won = away > home
            default: won = home + away >= 3
            }
            XCTAssertEqual(settled.status, won ? .won : .lost)
            XCTAssertEqual(settled.payout, won ? bet.potentialPayout : 0)
            expected += settled.payout
        }
        let settledAcca = try XCTUnwrap(career.world.betting.bets.first { $0.id == accumulator.id })
        let results = settledAcca.legs.map { leg -> Bool in
            let played = career.fixtures.first { $0.id == leg.fixtureID }!
            return played.homeGoals! > 0 && played.awayGoals! > 0
        }
        XCTAssertEqual(settledAcca.status, results.allSatisfy { $0 } ? .won : .lost)
        expected += settledAcca.payout
        XCTAssertEqual(career.world.betting.fichas, expected, "A carteira fecha com as premiações")
        XCTAssertEqual(career.world.betting.wins + career.world.betting.losses, placed.count + 1)
        XCTAssertEqual(career.world.betting.lifetimeProfit, career.world.betting.fichas - 1_000, "Lucro = carteira final menos a inicial")
        let playedIDs = Set(career.fixtures.filter(\.isPlayed).map(\.id))
        XCTAssertFalse(career.world.betting.bets.contains { bet in bet.status == .open && playedIDs.contains(bet.legs[0].fixtureID) })
    }

    func testScorerAndExactScoreMarketsSettleFromTheFixtureData() throws {
        var career = career()
        let fixture = try otherFixture(career)
        let index = try XCTUnwrap(career.fixtures.firstIndex { $0.id == fixture.id })
        let scorer = try XCTUnwrap(career.players(forTeam: fixture.home).first { $0.position == .forward })
        let hitting = BetLeg(fixtureID: fixture.id, market: .scorer, a: scorer.id, b: 0, odds: 3.0, description: "x")
        let exact = BetLeg(fixtureID: fixture.id, market: .exactScore, a: 2, b: 1, odds: 9.0, description: "x")
        let missing = BetLeg(fixtureID: fixture.id, market: .exactScore, a: 0, b: 0, odds: 8.0, description: "x")
        XCTAssertNotNil(career.placeBet(stake: 20, legs: [hitting]))
        XCTAssertNotNil(career.placeBet(stake: 20, legs: [exact]))
        XCTAssertNotNil(career.placeBet(stake: 20, legs: [missing]))
        career.fixtures[index].homeGoals = 2
        career.fixtures[index].awayGoals = 1
        career.fixtures[index].homeScorerIDs = [scorer.id, 5]
        career.fixtures[index].awayScorerIDs = [9]
        career.settleBets()
        let bets = career.world.betting.bets
        XCTAssertEqual(bets.first { $0.legs[0].market == .scorer }?.status, .won)
        XCTAssertEqual(bets.first { $0.legs[0].market == .exactScore && $0.legs[0].a == 2 }?.status, .won)
        XCTAssertEqual(bets.first { $0.legs[0].market == .exactScore && $0.legs[0].a == 0 }?.status, .lost)
        XCTAssertEqual(career.world.betting.fichas, 1_000 - 60 + 60 + 180)
        XCTAssertEqual(career.world.betting.biggestWin, 160)
    }

    func testCupQualifyMarketUsesTheWinnerAfterPenalties() throws {
        var career = career()
        var cup = LeagueFixture(id: 77_001, matchDay: career.matchDayIndex, round: 1, competition: .cup(.preliminary), home: 12, away: 13)
        career.fixtures.append(cup)
        let options = career.options(for: cup)
        let qualify = options.filter { $0.leg.market == .qualify }
        XCTAssertEqual(qualify.count, 2)
        let leg = try XCTUnwrap(qualify.first { $0.leg.a == 12 }).leg
        XCTAssertNotNil(career.placeBet(stake: 20, legs: [leg]))
        let index = career.fixtures.count - 1
        cup.homeGoals = 1
        cup.awayGoals = 1
        cup.homePenalties = 5
        cup.awayPenalties = 4
        career.fixtures[index] = cup
        career.settleBets()
        XCTAssertEqual(career.world.betting.bets.first?.status, .won)
    }

    func testLossStreakTriggersAResponsibleGamingNudge() throws {
        var career = career()
        let fixture = try otherFixture(career)
        let index = try XCTUnwrap(career.fixtures.firstIndex { $0.id == fixture.id })
        let leg = BetLeg(fixtureID: fixture.id, market: .homeWin, a: 0, b: 0, odds: 2, description: "x")
        for _ in 0..<3 { XCTAssertNotNil(career.placeBet(stake: 20, legs: [leg])) }
        career.fixtures[index].homeGoals = 0
        career.fixtures[index].awayGoals = 1
        career.settleBets()
        XCTAssertEqual(career.world.betting.lossStreak, 3)
        XCTAssertTrue(career.inbox.contains { $0.title == "Que tal uma pausa?" })
        XCTAssertEqual(career.world.betting.fichas, 940)
    }

    func testOutrightBetsSettleAtSeasonEndAndTipstersRankTheUser() throws {
        var career = career(club: 3)
        for market in OutrightMarket.allCases {
            let probabilities = career.outrightProbabilities(market)
            XCTAssertFalse(probabilities.isEmpty)
            if market != .relegated { XCTAssertEqual(probabilities.values.reduce(0, +), 1, accuracy: 0.0001, market.title) }
            XCTAssertTrue(probabilities.values.allSatisfy { $0 > 0 && $0 <= 0.9 })
        }
        let champion = try XCTUnwrap(career.outrightProbabilities(.leagueWinner).max { $0.value < $1.value }?.key)
        let longshot = try XCTUnwrap(career.outrightProbabilities(.leagueWinner).min { $0.value < $1.value }?.key)
        XCTAssertLessThan(try XCTUnwrap(career.outrightOdds(.leagueWinner, clubID: champion)), try XCTUnwrap(career.outrightOdds(.leagueWinner, clubID: longshot)))
        XCTAssertNil(career.outrightOdds(.leagueWinner, clubID: 15), "Série B não disputa o título da A")
        XCTAssertNil(career.placeOutright(market: .relegated, clubID: 3, stake: 20), "Não vale apostar no rebaixamento do próprio clube")
        let bet = try XCTUnwrap(career.placeOutright(market: .leagueWinner, clubID: champion, stake: 100))
        XCTAssertEqual(career.world.betting.fichas, 900)
        XCTAssertNotNil(career.placeOutright(market: .cupWinner, clubID: 3, stake: 20))

        for _ in 0..<FootballSeason.matchDaysPerSeason { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertFalse(career.outrightsOpen)
        let tableChampion = try XCTUnwrap(career.championID)
        let seasonProfitBefore = career.world.betting.seasonProfit
        XCTAssertFalse(career.world.betting.tipsters.isEmpty)
        XCTAssertTrue((1...8).contains(career.tipsterRank))
        _ = seasonProfitBefore
        XCTAssertNotNil(career.startNextSeason())
        let settled = try XCTUnwrap(career.world.betting.outrights.first { $0.id == bet.id }) 
        _ = settled
        XCTAssertEqual(career.world.betting.seasonProfit, 0, "O lucro da temporada recomeça")
        XCTAssertTrue(career.world.betting.tipsters.allSatisfy { $0.profit == 0 })
        _ = tableChampion
    }

    func testEconomyOfBettingIsTiltedTowardTheBookmakerOverManyBets() throws {
        var career = career(seed: 31)
        career.world.betting.fichas = 1_000_000
        var staked = 0
        var returned = 0
        for _ in 0..<12 {
            career.world.betting.lossLimit = 5_000
            career.world.betting.dailyNet = [:]
            for fixture in career.bettingFixtures where !fixture.involves(0) {
                guard let leg = career.options(for: fixture).first(where: { $0.leg.market == .over25 })?.leg else { continue }
                if let bet = career.placeBet(stake: 100, legs: [leg]) { staked += bet.stake }
            }
            XCTAssertTrue(career.simulateNextMatchDay())
            if career.isSeasonComplete { break }
        }
        returned = career.world.betting.bets.filter { $0.status == .won }.reduce(0) { $0 + $1.payout }
        XCTAssertGreaterThan(staked, 0)
        XCTAssertLessThan(Double(returned) / Double(staked), 1.12, "Retorno médio não pode superar a margem esperada")
    }

    // MARK: - Rodada Mágica (fantasy)

    func testFantasyLineupRulesPricesAndSuggestions() throws {
        var career = career()
        let suggestion = career.suggestedFantasyLineup()
        XCTAssertEqual(suggestion.ids.count, 11)
        XCTAssertNil(career.fantasyBlockReason(ids: suggestion.ids, captainID: suggestion.captainID))
        XCTAssertLessThanOrEqual(career.fantasyLineupCost(suggestion.ids), FantasyState.budget)
        XCTAssertTrue(career.setFantasyLineup(ids: suggestion.ids, captainID: suggestion.captainID))
        XCTAssertEqual(career.world.fantasy.lineup, suggestion.ids)

        XCTAssertNotNil(career.fantasyBlockReason(ids: Array(suggestion.ids.dropLast()), captainID: suggestion.captainID))
        XCTAssertNotNil(career.fantasyBlockReason(ids: suggestion.ids, captainID: 99_999), "Capitão fora do time")
        let stars = career.fantasyPool.sorted { $0.overall > $1.overall }
        let expensive = stars.prefix(11).map(\.id)
        XCTAssertNotNil(career.fantasyBlockReason(ids: expensive, captainID: expensive[0]))
        let cheap = career.fantasyPool.min { career.fantasyPrice($0) < career.fantasyPrice($1) }!
        let star = career.fantasyPool.max { career.fantasyPrice($0) < career.fantasyPrice($1) }!
        XCTAssertLessThan(career.fantasyPrice(cheap), career.fantasyPrice(star))
        XCTAssertGreaterThanOrEqual(career.fantasyPrice(cheap), 3)
    }

    func testFantasyScoringFollowsGoalsAssistsCleanSheetsAndCards() throws {
        let career = career()
        let home = 3, away = 4
        let squadHome = career.players(forTeam: home)
        let striker = try XCTUnwrap(squadHome.first { $0.position == .forward })
        let keeper = try XCTUnwrap(squadHome.first { $0.position == .goalkeeper })
        let defender = try XCTUnwrap(squadHome.first { $0.position == .defender })
        let midfielder = try XCTUnwrap(squadHome.first { $0.position == .midfielder })
        var fixture = LeagueFixture(id: 88_001, matchDay: 5, round: 6, competition: .league(.serieA), home: home, away: away)
        fixture.homeGoals = 2
        fixture.awayGoals = 0
        fixture.homeScorerIDs = [striker.id, striker.id]
        fixture.assistIDs = [midfielder.id]
        fixture.playedIDs = [striker.id, keeper.id, defender.id, midfielder.id]
        fixture.yellowIDs = [defender.id]
        XCTAssertEqual(career.fantasyPoints(for: striker, in: fixture), 1 + 16 + 1)
        XCTAssertEqual(career.fantasyPoints(for: keeper, in: fixture), 1 + 5 + 0 + 1)
        XCTAssertEqual(career.fantasyPoints(for: defender, in: fixture), 1 + 4 + 1 - 2)
        XCTAssertEqual(career.fantasyPoints(for: midfielder, in: fixture), 1 + 5 + 1 + 1)
        let benched = try XCTUnwrap(squadHome.first { $0.id != striker.id && !fixture.playedIDs.contains($0.id) })
        XCTAssertEqual(career.fantasyPoints(for: benched, in: fixture), 0, "Quem não jogou não pontua")
        fixture.redIDs = [midfielder.id]
        XCTAssertEqual(career.fantasyPoints(for: midfielder, in: fixture), 1 + 5 + 1 + 1 - 5)
    }

    func testFantasyRoundsPayPrizesBuildHistoryAndCrownASeasonWinner() throws {
        var career = career()
        let suggestion = career.suggestedFantasyLineup()
        XCTAssertTrue(career.setFantasyLineup(ids: suggestion.ids, captainID: suggestion.captainID))
        let fichas = career.world.betting.fichas
        XCTAssertTrue(career.simulateNextMatchDay())
        let result = try XCTUnwrap(career.world.fantasy.history.first)
        XCTAssertEqual(result.round, 1)
        XCTAssertTrue((1...8).contains(result.rank))
        XCTAssertEqual(career.world.fantasy.seasonPoints, result.points, accuracy: 0.0001)
        XCTAssertGreaterThan(career.world.betting.fichas, fichas - 1)
        XCTAssertEqual(career.world.fantasy.managers.count, 7)
        XCTAssertEqual(career.fantasyStandings.count, 8)
        XCTAssertEqual(career.fantasyStandings.filter(\.isUser).count, 1)
        XCTAssertTrue(career.inbox.contains { $0.title.hasPrefix("Rodada Mágica 1") })
        XCTAssertEqual(career.counters["fantasyRounds"], 1)

        // Dias de copa não pontuam; a rodada 2 só pontua em dia de liga.
        for _ in 0..<FootballSeason.matchDaysPerSeason - 1 { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertEqual(career.world.fantasy.history.count, 18)
        XCTAssertEqual(Set(career.world.fantasy.history.map(\.round)).count, 18)
        let points = career.world.fantasy.seasonPoints
        XCTAssertEqual(points, career.world.fantasy.history.reduce(0) { $0 + $1.points }, accuracy: 0.01)
        XCTAssertNotNil(career.startNextSeason())
        XCTAssertEqual(career.world.fantasy.seasonPoints, 0)
        XCTAssertTrue(career.world.fantasy.managers.allSatisfy { $0.points == 0 })
    }
}
