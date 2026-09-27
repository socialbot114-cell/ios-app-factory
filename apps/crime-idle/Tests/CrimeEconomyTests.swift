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
        XCTAssertFalse(game.buy(5))
        XCTAssertEqual(game.owned[5], 0)
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
        for _ in 0..<50 { game.tap() }
        XCTAssertTrue(game.claimMission(0))
        let balance = game.influence
        XCTAssertFalse(game.claimMission(0))
        XCTAssertEqual(game.influence, balance)
    }

    func testDistrictsUnlockInOrderAndChargeOnlyLocalInfluence() {
        var game = CrimeEconomy()
        XCTAssertFalse(game.unlockDistrict(2))
        for _ in 0..<400 { game.tap() }
        XCTAssertTrue(game.unlockDistrict(1))
        XCTAssertEqual(game.unlockedDistricts, 2)
        XCTAssertFalse(game.unlockDistrict(1))
    }

    func testDistrictUnlockIncreasesBusinessIncomeByTwentyFivePercent() {
        var game = CrimeEconomy()
        _ = game.buy(0)
        let initialIncome = game.incomePerSecond
        for _ in 0..<425 { game.tap() }
        XCTAssertTrue(game.unlockDistrict(1))
        XCTAssertEqual(game.incomePerSecond, initialIncome * 1.25, accuracy: 0.001)
    }

    func testMissionRewardsScaleWithProgressionAndUseProvidedDate() {
        var game = CrimeEconomy()
        XCTAssertFalse(game.claimMission(1))
        for _ in 0..<50 { game.tap() }
        XCTAssertTrue(game.claimMission(0, at: Date(timeIntervalSince1970: 42)))
        XCTAssertEqual(game.influence, 175, accuracy: 0.001)
        XCTAssertEqual(game.lastSavedAt, Date(timeIntervalSince1970: 42))
        XCTAssertEqual(CrimeEconomy.missionReward(for: 11), 500)
    }

    func testBusinessCostReturnsInfinityForInvalidIndex() {
        let game = CrimeEconomy()
        XCTAssertEqual(game.cost(for: -1), .infinity)
        XCTAssertEqual(game.cost(for: 0), 25, accuracy: 0.001)
    }

    func testBusinessUpgradeDoublesOnlyThatBusinessIncome() {
        var game = CrimeEconomy()
        _ = game.buy(0)
        for _ in 0..<200 { game.tap() }
        let originalIncome = game.incomePerSecond
        XCTAssertTrue(game.buyUpgrade(0))
        XCTAssertEqual(game.incomePerSecond, originalIncome + CrimeEconomy.baseIncome[0], accuracy: 0.001)
        XCTAssertFalse(game.buyUpgrade(2))
    }

    func testActivityCompletesWithRewardAndCooldown() {
        let start = Date(timeIntervalSince1970: 100)
        var game = CrimeEconomy()
        XCTAssertTrue(game.startActivity(0, at: start))
        XCTAssertFalse(game.startActivity(1, at: start))
        XCTAssertFalse(game.claimActivity(at: start.addingTimeInterval(10)))
        XCTAssertTrue(game.claimActivity(at: start.addingTimeInterval(20)))
        XCTAssertEqual(game.influence, 145, accuracy: 0.001)
        XCTAssertFalse(game.startActivity(0, at: start.addingTimeInterval(30)))
        XCTAssertTrue(game.startActivity(0, at: start.addingTimeInterval(100)))
    }

    func testAchievementRewardIsClaimedOnceAfterUnlocking() {
        var game = CrimeEconomy()
        XCTAssertFalse(game.claimAchievement(0))
        _ = game.buy(0)
        XCTAssertTrue(game.claimAchievement(0))
        XCTAssertEqual(game.influence, 115, accuracy: 0.001)
        XCTAssertFalse(game.claimAchievement(0))
    }

    func testThirdDistrictIncreasesActivityRewardNotBusinessIncome() {
        var game = CrimeEconomy()
        _ = game.buy(0)
        let baseIncome = game.incomePerSecond
        for _ in 0..<2_400 { game.tap() }
        XCTAssertTrue(game.unlockDistrict(1))
        for _ in 0..<2_000 { game.tap() }
        XCTAssertTrue(game.unlockDistrict(2))
        XCTAssertEqual(game.incomePerSecond, baseIncome * 1.25, accuracy: 0.001)
        XCTAssertEqual(game.activityRewardMultiplier, 1.2, accuracy: 0.001)
    }

    func testOldSaveLoadsWithDefaultsForNewFeatures() throws {
        let suiteName = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let oldSave: [String: Any] = [
            "influence": 345.0,
            "owned": [1, 2, 0, 0, 0, 0],
            "claimedMissions": [0],
            "unlockedDistricts": 2,
            "lastSavedAt": Date(timeIntervalSince1970: 500).timeIntervalSince1970
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: oldSave), forKey: "crime.save")
        let game = CrimeEconomy.load(defaults: defaults)
        XCTAssertEqual(game.influence, 345)
        XCTAssertEqual(game.owned[1], 2)
        XCTAssertEqual(game.upgradeLevels, Array(repeating: 0, count: 6))
        XCTAssertEqual(game.claimedAchievements, [])
    }
}
