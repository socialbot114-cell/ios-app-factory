import Foundation
import XCTest
@testable import CrimeIdle

final class CrimeEconomyTests: XCTestCase {
    func testOfflineAccrualIsCappedAtEightHours() {
        var game = CrimeEconomy()
        _ = game.buy(0)
        let rate = game.incomePerSecond
        game.accrue(seconds: CrimeEconomy.cap + 10_000)
        XCTAssertEqual(game.influence, 100 - 25 + rate * CrimeEconomy.cap, accuracy: 0.001)
    }

    func testClockMovingBackwardsDoesNotAwardInfluence() {
        var game = CrimeEconomy()
        game.accrue(seconds: -60)
        XCTAssertEqual(game.influence, 100)
    }

    func testPurchaseRequiresEnoughInfluence() {
        var game = CrimeEconomy()
        XCTAssertTrue(game.buy(0, quantity: 3))
        XCTAssertFalse(game.canBuy(0))
        XCTAssertFalse(game.buy(0))
        XCTAssertEqual(game.owned[0], 3)
    }

    func testBusinessesRequireTheirDistrictAndExpansionBoostsIncome() {
        var game = CrimeEconomy()
        for _ in 0..<1_000 { game.tap() }

        XCTAssertFalse(game.canBuy(2))
        XCTAssertFalse(game.buy(2))
        XCTAssertEqual(game.owned[2], 0)
        XCTAssertTrue(game.unlockDistrict(1))
        XCTAssertEqual(game.districtMultiplier, 1.25, accuracy: 0.001)
        XCTAssertTrue(game.canBuy(2))
        XCTAssertTrue(game.buy(2))
        XCTAssertEqual(game.owned[2], 1)
        XCTAssertEqual(game.incomePerSecond, CrimeBusiness.catalog[2].baseIncomePerSecond * 1.25, accuracy: 0.001)
    }

    func testBulkPurchaseUsesCompoundedPriceAndDoesNotPartiallySpend() {
        var poorGame = CrimeEconomy()
        let bulkCost = poorGame.purchaseCost(forBusiness: 0, quantity: 10)!
        XCTAssertGreaterThan(bulkCost, poorGame.influence)
        XCTAssertFalse(poorGame.buy(0, quantity: 10))
        XCTAssertEqual(poorGame.owned[0], 0)
        XCTAssertEqual(poorGame.influence, 100)

        var fundedGame = CrimeEconomy()
        for _ in 0..<1_000 { fundedGame.tap() }
        let balance = fundedGame.influence
        let expectedCost = fundedGame.purchaseCost(forBusiness: 0, quantity: 10)!
        XCTAssertTrue(fundedGame.buy(0, quantity: 10))
        XCTAssertEqual(fundedGame.owned[0], 10)
        XCTAssertEqual(fundedGame.influence, balance - expectedCost, accuracy: 0.001)
        XCTAssertEqual(fundedGame.incomePerSecond, 3.5, accuracy: 0.001)
    }

    func testResumePersistsAndAppliesCappedOfflineEarnings() {
        var game = CrimeEconomy()
        _ = game.buy(0, at: Date(timeIntervalSince1970: 10))
        game.accrue(seconds: 0, at: Date(timeIntervalSince1970: 10))
        game.resume(at: Date(timeIntervalSince1970: 10 + 9 * 60 * 60))
        XCTAssertEqual(game.influence, 75 + 0.35 * CrimeEconomy.cap, accuracy: 0.001)
    }

    func testMissionRewardCanOnlyBeClaimedOnce() {
        var game = CrimeEconomy()
        XCTAssertLessThan(game.missionProgress(0), 1)
        for _ in 0..<50 { game.tap() }
        XCTAssertEqual(game.missionProgress(0), 1)
        XCTAssertTrue(game.canClaimMission(0))
        XCTAssertTrue(game.claimMission(0))
        let balance = game.influence
        XCTAssertFalse(game.canClaimMission(0))
        XCTAssertFalse(game.claimMission(0))
        XCTAssertEqual(game.influence, balance)
    }

    func testDistrictsUnlockInOrderAndChargeOnlyLocalInfluence() {
        var game = CrimeEconomy()
        XCTAssertFalse(game.unlockDistrict(2))
        for _ in 0..<400 { game.tap() }
        XCTAssertTrue(game.unlockDistrict(1))
        XCTAssertEqual(game.unlockedDistricts, 2)
        XCTAssertEqual(game.districtMultiplier, 1.25, accuracy: 0.001)
        XCTAssertFalse(game.unlockDistrict(1))
    }

    func testLegacySaveWithBusinessInLaterDistrictKeepsThatDistrictOpen() throws {
        let fresh = CrimeEconomy()
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(fresh)) as? [String: Any])
        legacy["owned"] = [0, 0, 0, 0, 0, 1]
        legacy["unlockedDistricts"] = 1
        let data = try JSONSerialization.data(withJSONObject: legacy)

        let restored = try JSONDecoder().decode(CrimeEconomy.self, from: data)
        XCTAssertEqual(restored.owned[5], 1)
        XCTAssertEqual(restored.unlockedDistricts, 3)
        XCTAssertGreaterThan(restored.incomePerSecond, 0)
    }
}
