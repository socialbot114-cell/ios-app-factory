import Foundation
import XCTest
@testable import CrimeIdle

final class CrimeEconomyTests: XCTestCase {
    private func rich(_ cash: Double = 1e30, respect: Double = 1e6) -> CrimeState {
        var state = CrimeState(seed: 42, now: Date(timeIntervalSince1970: 0))
        state.cash = cash
        state.respect = respect
        return state
    }

    func testNewGameCanAffordFirstRacketOnly() {
        let state = CrimeState(seed: 1)
        XCTAssertTrue(state.canBuy(racket: 0, quantity: 1))
        XCTAssertFalse(state.canBuy(racket: 1, quantity: 1))
        XCTAssertFalse(state.canBuy(racket: 2, quantity: 1), "Porto Velho ainda não foi dominado")
    }

    func testBulkCostIsGeometricAndPurchaseIsAtomic() {
        var state = CrimeState(seed: 1)
        let racket = CrimeRacket.catalog[0]
        let expected = (0..<10).reduce(0.0) { $0 + racket.baseCost * pow(racket.growth, Double($1)) }
        XCTAssertEqual(state.cost(racket: 0, quantity: 10), expected, accuracy: 1e-9)
        XCTAssertFalse(state.buy(racket: 0, quantity: 10))
        XCTAssertEqual(state.owned[0], 0)
        XCTAssertEqual(state.cash, 5)
    }

    func testMaxAffordableNeverOverspends() {
        var state = rich(12_345)
        let count = state.maxAffordable(racket: 0)
        XCTAssertGreaterThan(count, 0)
        XCTAssertLessThanOrEqual(state.cost(racket: 0, quantity: count), state.cash)
        XCTAssertGreaterThan(state.cost(racket: 0, quantity: count + 1), state.cash)
        XCTAssertTrue(state.buy(racket: 0, quantity: count))
        XCTAssertGreaterThanOrEqual(state.cash, 0)
    }

    func testManualRacketPaysOncePerRunAndManagerAutomates() {
        var state = rich(1_000_000)
        state.buy(racket: 0, quantity: 1)
        let start = state.cash
        state.tick(10, online: false)
        XCTAssertEqual(state.cash, start, "Sem gerente, nada roda sozinho")
        XCTAssertTrue(state.run(racket: 0))
        XCTAssertFalse(state.run(racket: 0), "Não dá para iniciar dois ciclos ao mesmo tempo")
        state.tick(10, online: false)
        XCTAssertEqual(state.cash, start + state.revenuePerCycle(0), accuracy: 1e-9)

        XCTAssertTrue(state.hireManager(0))
        let afterHire = state.cash
        let cycle = state.cycleTime(0)
        state.tick(cycle * 5 + cycle / 2, online: false)
        XCTAssertEqual(state.cash, afterHire + 5 * state.revenuePerCycle(0), accuracy: 1e-6)
    }

    func testSpeedMilestonesHalveCycleTime() {
        var state = rich()
        state.buy(racket: 0, quantity: 24)
        let before = state.cycleTime(0)
        state.buy(racket: 0, quantity: 1)
        XCTAssertEqual(state.cycleTime(0), before / 2, accuracy: 1e-9)
    }

    func testDistrictGatesRacketsAndBoostsProfit() {
        var state = rich()
        XCTAssertFalse(state.buy(racket: 2, quantity: 1))
        let multiplier = state.baseGlobalMultiplier
        XCTAssertFalse(state.conquer(2), "Bairros são conquistados em ordem")
        XCTAssertTrue(state.conquer(1))
        XCTAssertEqual(state.baseGlobalMultiplier, multiplier * 1.25, accuracy: 1e-9)
        XCTAssertTrue(state.buy(racket: 2, quantity: 1))
    }

    func testConquestNeedsRespect() {
        var state = rich(1e9, respect: 0)
        XCTAssertFalse(state.canConquer(1))
        state.respect = CrimeDistrict.catalog[1].respectCost
        XCTAssertTrue(state.conquer(1))
        XCTAssertEqual(state.respect, 0)
    }

    func testHeatSettlesAtEquilibriumAndCutsIncome() {
        var state = rich()
        for index in 0..<4 {
            if !state.isRacketUnlocked(index) { state.conquer(CrimeRacket.catalog[index].district) }
            state.buy(racket: index, quantity: 1)
            state.hireManager(index)
        }
        let equilibrium = state.heatRate / state.heatDecay
        for _ in 0..<2_000 { state.tick(1, online: false) }
        XCTAssertEqual(state.heat, min(equilibrium, 100), accuracy: 0.5)

        state.heat = 100
        XCTAssertEqual(state.heatMultiplier, 0.5, accuracy: 1e-9)
        state.heat = 20
        XCTAssertEqual(state.heatMultiplier, 1)
    }

    func testBribeCoolsHeat() {
        var state = rich()
        state.heat = 60
        XCTAssertTrue(state.bribe())
        XCTAssertEqual(state.heat, 30, accuracy: 1e-9)
        state.heat = 2
        XCTAssertFalse(state.bribe())
    }

    func testOfflineEarningsAreCappedAndReported() {
        var state = rich(1_000_000)
        state.buy(racket: 0, quantity: 1)
        state.hireManager(0)
        let start = state.cash
        let rate = state.incomePerSecond
        let report = state.resume(at: Date(timeIntervalSince1970: 30 * 3_600))
        XCTAssertNotNil(report)
        XCTAssertEqual(report?.seconds, CrimeState.baseOfflineHours * 3_600)
        XCTAssertEqual(state.cash - start, rate * CrimeState.baseOfflineHours * 3_600, accuracy: rate * 2)
    }

    func testClockMovingBackwardsGivesNothing() {
        var state = rich(100)
        state.buy(racket: 0, quantity: 1)
        state.lastSeen = Date(timeIntervalSince1970: 1_000)
        XCTAssertNil(state.resume(at: Date(timeIntervalSince1970: 0)))
        XCTAssertEqual(state.cash, 100 - CrimeRacket.catalog[0].baseCost, accuracy: 1e-9)
    }

    func testOfflineDoesNotSpawnEvents() {
        var state = rich()
        state.skipTutorial()
        state.resume(at: Date(timeIntervalSince1970: 3_600))
        XCTAssertNil(state.pendingEvent)
        state.tick(60, online: true)
        XCTAssertNotNil(state.pendingEvent)
    }

    func testHeistRunsOnTimerAndResolvesOnce() {
        var state = rich(0)
        XCTAssertTrue(state.startHeist(0, plan: .stealth))
        XCTAssertFalse(state.startHeist(1, plan: .standard), "Só um golpe por vez")
        XCTAssertNil(state.resolveHeist(), "Ainda não terminou")
        state.tick(CrimeHeist.catalog[0].duration, online: false)
        let outcome = try? XCTUnwrap(state.resolveHeist())
        XCTAssertNotNil(outcome)
        XCTAssertNil(state.activeHeist)
        XCTAssertNil(state.resolveHeist())
        if outcome?.success == true {
            XCTAssertGreaterThan(state.cash, 0)
            XCTAssertEqual(state.heistsCompleted, 1)
        } else {
            XCTAssertEqual(state.cash, 0)
        }
    }

    func testHeistsAreDeterministicForSameSeed() {
        func play(seed: UInt64) -> [Bool] {
            var state = CrimeState(seed: seed)
            return (0..<20).map { _ in
                state.startHeist(1, plan: .loud)
                state.tick(1_000, online: false)
                return state.resolveHeist()?.success ?? false
            }
        }
        XCTAssertEqual(play(seed: 7), play(seed: 7))
        XCTAssertTrue(play(seed: 7).contains(true))
        XCTAssertTrue(play(seed: 7).contains(false))
    }

    func testPlanTradesOddsForLoot() {
        let state = rich()
        XCTAssertGreaterThan(state.heistOdds(0, plan: .stealth), state.heistOdds(0, plan: .loud))
        XCTAssertLessThan(state.heistLoot(0, plan: .stealth), state.heistLoot(0, plan: .loud))
    }

    func testCrewCostsRespectAndAppliesPerks() {
        var state = rich(0, respect: 0)
        XCTAssertFalse(state.upgradeCrew(0))
        state.respect = 100
        let before = state.baseGlobalMultiplier
        XCTAssertTrue(state.upgradeCrew(0))
        XCTAssertEqual(state.crewLevels[0], 1)
        XCTAssertEqual(state.baseGlobalMultiplier, before * 1.15, accuracy: 1e-9)
        XCTAssertEqual(state.respect, 100 - CrimeCrewMember.catalog[0].recruitCost)
    }

    func testCrewStopsAtMaxLevel() {
        var state = rich()
        for _ in 0..<(CrimeCrewMember.maxLevel + 3) { state.upgradeCrew(1) }
        XCTAssertEqual(state.crewLevels[1], CrimeCrewMember.maxLevel)
        XCTAssertNil(state.crewUpgradeCost(1))
    }

    func testEventChoiceAppliesEffectsAndClears() {
        var state = rich(1_000)
        state.pendingEvent = 0
        state.heat = 50
        XCTAssertTrue(state.choose(0))
        XCTAssertEqual(state.heat, 25, accuracy: 1e-9)
        XCTAssertNil(state.pendingEvent)
        XCTAssertFalse(state.choose(0))
    }

    func testBoostEventMultipliesThenExpires() {
        var state = rich()
        state.buy(racket: 0, quantity: 1)
        state.hireManager(0)
        let base = state.incomePerSecond
        state.pendingEvent = 7
        state.heat = 0
        XCTAssertTrue(state.choose(0))
        XCTAssertGreaterThan(state.incomePerSecond, base * 2)
        state.tick(61, online: false)
        XCTAssertEqual(state.boostMultiplier, 1)
    }

    func testContractsClaimOnce() {
        var state = rich()
        XCTAssertFalse(state.canClaimContract(0))
        state.buy(racket: 0, quantity: 5)
        XCTAssertTrue(state.claimContract(0))
        XCTAssertFalse(state.claimContract(0))
        XCTAssertFalse(state.openContracts.contains { $0.id == 0 })
    }

    func testTapCanCrit() {
        var state = CrimeState(seed: 99)
        let results = (0..<200).map { _ in state.tapStreet() }
        XCTAssertTrue(results.contains { $0.critical })
        XCTAssertTrue(results.contains { !$0.critical })
        XCTAssertEqual(results.first { !$0.critical }?.amount, 1)
    }

    func testPrestigeResetsRunAndKeepsLegacyAndCrew() {
        var state = rich()
        XCTAssertFalse(state.prestige())
        state.lifetimeTotal = 1e14
        state.crewLevels[0] = 3
        state.buy(racket: 0, quantity: 10)
        let claim = state.claimableLegacy
        XCTAssertEqual(claim, 100)
        XCTAssertTrue(state.prestige())
        XCTAssertEqual(state.legacy, 100)
        XCTAssertEqual(state.owned[0], 0)
        XCTAssertEqual(state.crewLevels[0], 3)
        XCTAssertEqual(state.prestigeCount, 1)
        XCTAssertEqual(state.claimableLegacy, 0)
        XCTAssertEqual(state.baseGlobalMultiplier, (1 + 0.45) * (1 + 100 * CrimeState.legacyBonus), accuracy: 1e-9)
    }

    func testSaveRoundTripAndDefensiveDecoding() throws {
        var state = rich()
        state.buy(racket: 0, quantity: 3)
        state.startHeist(0, plan: .loud)
        state.pendingEvent = 2
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(CrimeState.self, from: data)
        XCTAssertEqual(restored, state)

        let legacy = Data(#"{"cash": 50, "owned": [1, 0, 0, 0, 0, 0, 0, 0, 0, 2], "heat": 900}"#.utf8)
        let repaired = try JSONDecoder().decode(CrimeState.self, from: legacy)
        XCTAssertEqual(repaired.owned.count, CrimeRacket.catalog.count)
        XCTAssertEqual(repaired.districts, CrimeDistrict.catalog.count, "Bairro com negócio é reaberto")
        XCTAssertEqual(repaired.heat, 100)
    }

    func testTutorialWalksThroughFirstSessionAndPaysRespect() {
        var state = CrimeState(seed: 5)
        XCTAssertEqual(state.tutorial, .tapStreet)
        state.tick(120, online: true)
        XCTAssertNil(state.pendingEvent, "Nada de eventos durante o tutorial")
        for _ in 0..<5 { state.tapStreet() }
        state.advanceTutorial()
        XCTAssertEqual(state.tutorial, .buyRacket)
        state.buy(racket: 0, quantity: 1)
        state.advanceTutorial()
        XCTAssertEqual(state.tutorial, .runRacket)
        state.run(racket: 0)
        state.cash = 1e6
        state.buy(racket: 0, quantity: 4)
        state.advanceTutorial()
        XCTAssertEqual(state.tutorial, .firstHeist, "Pula passos já cumpridos")
        state.startHeist(0, plan: .stealth)
        state.advanceTutorial()
        XCTAssertEqual(state.tutorial, .hireManager)
        let respect = state.respect
        state.hireManager(0)
        XCTAssertTrue(state.advanceTutorial())
        XCTAssertEqual(state.tutorial, .done)
        XCTAssertEqual(state.respect, respect + CrimeState.tutorialRewardRespect)
        XCTAssertFalse(state.advanceTutorial(), "Recompensa só uma vez")
    }

    func testDailyEnvelopeStreakGrowsAndBreaks() {
        var state = CrimeState(seed: 8)
        XCTAssertTrue(state.isDailyAvailable(today: 100))
        XCTAssertEqual(state.claimDaily(today: 100)?.reward.day, 1)
        XCTAssertNil(state.claimDaily(today: 100), "Uma vez por dia")
        XCTAssertEqual(state.claimDaily(today: 101)?.reward.day, 2)
        XCTAssertEqual(state.claimDaily(today: 102)?.reward.day, 3)
        XCTAssertEqual(state.nextDailyReward(today: 104).day, 1, "Pular um dia zera a sequência")
        for day in 103...105 { state.claimDaily(today: day) }
        let seventh = state.claimDaily(today: 106)
        XCTAssertEqual(seventh?.reward.day, 7)
        XCTAssertGreaterThan(state.boostRemaining, 0)
        XCTAssertEqual(state.claimDaily(today: 107)?.reward.day, 1, "Depois do sétimo dia o ciclo recomeça")
    }

    func testDailyCashScalesWithIncome() {
        var poor = CrimeState(seed: 1)
        let small = poor.claimDaily(today: 1)!.cash
        var rich = rich()
        rich.buy(racket: 0, quantity: 100)
        rich.hireManager(0)
        let big = rich.claimDaily(today: 1)!.cash
        XCTAssertEqual(small, 600)
        XCTAssertGreaterThan(big, small * 100)
    }

    func testSavesFromBeforeTheTutorialSkipIt() throws {
        let veteran = Data(#"{"cash": 50, "owned": [10], "managed": [true]}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(CrimeState.self, from: veteran).tutorial, .done)
        let rookie = Data(#"{"cash": 5}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(CrimeState.self, from: rookie).tutorial, .tapStreet)
    }

    func testFormatting() {
        XCTAssertEqual(CrimeFormat.short(950), "950")
        XCTAssertEqual(CrimeFormat.short(1_500), "1,50K")
        XCTAssertEqual(CrimeFormat.short(12_399), "12,3K")
        XCTAssertEqual(CrimeFormat.short(3_070_000_000), "3,07B")
        XCTAssertEqual(CrimeFormat.short(999_999), "999K")
        XCTAssertEqual(CrimeFormat.duration(75), "1min 15s")
        XCTAssertEqual(CrimeFormat.duration(7_200), "2h")
    }

    func testFullCampaignIsReachable() {
        // Bot simples: compra o melhor custo-benefício, contrata gerentes, conquista bairros e faz golpes.
        var state = CrimeState(seed: 3)
        var seconds = 0.0
        while state.districts < CrimeDistrict.catalog.count && seconds < 7 * 24 * 3_600 {
            for _ in 0..<20 { state.tapStreet() }
            if let ready = state.activeHeist, ready.isReady { _ = state.resolveHeist() }
            if state.activeHeist == nil {
                let best = CrimeHeist.catalog.filter { state.isHeistUnlocked($0.id) }.last!
                state.startHeist(best.id, plan: .stealth)
            }
            for member in CrimeCrewMember.catalog { state.upgradeCrew(member.id) }
            state.conquer(state.districts)
            for index in CrimeRacket.catalog.indices.reversed() { state.hireManager(index) }
            for upgrade in CrimeUpgrade.catalog { state.buyUpgrade(upgrade.id) }
            for index in CrimeRacket.catalog.indices.reversed() where state.isRacketUnlocked(index) {
                let count = state.maxAffordable(racket: index)
                if count > 0 { state.buy(racket: index, quantity: count) }
            }
            for index in CrimeRacket.catalog.indices { state.run(racket: index) }
            if state.heat > 70 { state.bribe() }
            state.tick(60, online: false)
            seconds += 60
        }
        XCTAssertEqual(state.districts, CrimeDistrict.catalog.count, "Campanha travou com \(state.districts) bairros")
        XCTAssertLessThan(seconds, 7 * 24 * 3_600)
        print("Campanha completa em \(seconds / 3_600)h de jogo ativo, rank \(CrimeRank.ladder[state.rankIndex].title)")
    }
}
