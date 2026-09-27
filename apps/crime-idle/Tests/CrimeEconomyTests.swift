import XCTest
@testable import CrimeIdle

final class CrimeEconomyTests: XCTestCase {
    func testBusinessRevenueAccruesCashAndRespectsOfflineCap() {
        var game = CrimeEconomy()
        XCTAssertTrue(game.buy(0))
        let rate = game.incomePerSecond
        game.accrue(seconds: CrimeEconomy.cap + 10_000)
        XCTAssertEqual(game.cash, 75 + rate * CrimeEconomy.cap, accuracy: 0.001)
        XCTAssertEqual(game.reputation, 0)
    }

    func testClockMovingBackwardsDoesNotAwardCash() {
        var game = CrimeEconomy()
        game.accrue(seconds: -60)
        XCTAssertEqual(game.cash, 100)
    }

    func testPurchaseRequiresEnoughCash() {
        var game = CrimeEconomy()
        XCTAssertFalse(game.buy(5))
        XCTAssertEqual(game.owned[5], 0)
    }

    func testResumeAppliesCappedOfflineCash() {
        var game = CrimeEconomy()
        _ = game.buy(0, at: Date(timeIntervalSince1970: 10))
        game.accrue(seconds: 0, at: Date(timeIntervalSince1970: 10))
        game.resume(at: Date(timeIntervalSince1970: 10 + 9 * 60 * 60))
        XCTAssertEqual(game.cash, 75 + 0.35 * CrimeEconomy.cap, accuracy: 0.001)
    }

    func testStoryChoicePermanentlySpecializesBusinessAndAwardsReputation() {
        var game = CrimeEconomy()
        XCTAssertFalse(game.chooseStory(0, option: 0))
        XCTAssertTrue(game.buy(0))
        XCTAssertTrue(game.chooseStory(0, option: 0))
        XCTAssertEqual(game.reputation, 40)
        XCTAssertEqual(game.businessIncome(for: 0), 0.35 * 1.35, accuracy: 0.001)
        XCTAssertFalse(game.chooseStory(0, option: 1))
    }

    func testDifferentStoryChoiceSpecializesFutureStudioPurchase() {
        var game = CrimeEconomy()
        _ = game.buy(0)
        XCTAssertTrue(game.chooseStory(0, option: 1))
        XCTAssertEqual(game.cash, 175)
        XCTAssertEqual(game.reputation, 30)
        XCTAssertTrue(game.buy(1))
        XCTAssertEqual(game.businessIncome(for: 1), 1.2 * 1.35, accuracy: 0.001)
    }

    func testDistrictRequiresBothCashAndReputationAndBoostsBusinessRevenue() {
        var game = CrimeEconomy()
        XCTAssertFalse(game.unlockDistrict(1))
        XCTAssertTrue(game.buy(0))
        XCTAssertTrue(game.chooseStory(0, option: 0))
        for _ in 0..<135 { game.tap() }
        XCTAssertEqual(game.cash, 180, accuracy: 0.001)
        let initialIncome = game.incomePerSecond
        XCTAssertTrue(game.unlockDistrict(1))
        XCTAssertEqual(game.incomePerSecond, initialIncome * 1.25, accuracy: 0.001)
        XCTAssertEqual(game.reputation, 15)
        XCTAssertFalse(game.unlockDistrict(1))
    }

    func testProjectIsAnImmediateInvestmentAndCanOnlyBeCompletedOnce() {
        var game = CrimeEconomy()
        XCTAssertFalse(game.completeProject(0))
        _ = game.buy(0)
        XCTAssertTrue(game.completeProject(0))
        XCTAssertEqual(game.cash, 130, accuracy: 0.001)
        XCTAssertEqual(game.reputation, 8, accuracy: 0.001)
        XCTAssertFalse(game.completeProject(0))
    }

    func testMissionRewardsCashAndReputationOnlyOnce() {
        var game = CrimeEconomy()
        XCTAssertFalse(game.claimMission(1))
        for _ in 0..<50 { game.tap() }
        XCTAssertTrue(game.claimMission(0, at: Date(timeIntervalSince1970: 42)))
        XCTAssertEqual(game.cash, 175, accuracy: 0.001)
        XCTAssertEqual(game.reputation, 5, accuracy: 0.001)
        let balance = game.cash
        XCTAssertFalse(game.claimMission(0))
        XCTAssertEqual(game.cash, balance)
        XCTAssertEqual(game.lastSavedAt, Date(timeIntervalSince1970: 42))
    }

    func testBusinessUpgradeDoublesRevenueForThatBusiness() {
        var game = CrimeEconomy()
        _ = game.buy(0)
        for _ in 0..<100 { game.tap() }
        let originalIncome = game.incomePerSecond
        XCTAssertTrue(game.buyUpgrade(0))
        XCTAssertEqual(game.incomePerSecond, originalIncome * 2, accuracy: 0.001)
        XCTAssertFalse(game.buyUpgrade(2))
    }

    func testAchievementRewardCanBeClaimedOnlyAfterUnlocking() {
        var game = CrimeEconomy()
        XCTAssertFalse(game.claimAchievement(0))
        _ = game.buy(0)
        XCTAssertTrue(game.claimAchievement(0))
        XCTAssertEqual(game.cash, 115, accuracy: 0.001)
        XCTAssertFalse(game.claimAchievement(0))
    }

    func testStoryRequirementsAdvanceCampaignInOrder() {
        var game = CrimeEconomy()
        _ = game.buy(0)
        XCTAssertTrue(game.chooseStory(0, option: 0))
        XCTAssertFalse(game.chooseStory(1, option: 0))
        XCTAssertEqual(game.currentStoryChapter, 1)
        XCTAssertFalse(game.isStoryChapterAvailable(1))
    }

    func testLegacySaveMigratesInfluenceToCashAndPreservesUnlockedDistricts() throws {
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
        XCTAssertEqual(game.cash, 345)
        XCTAssertEqual(game.reputation, 25)
        XCTAssertEqual(game.owned[1], 2)
        XCTAssertEqual(game.upgradeLevels, Array(repeating: 0, count: 6))
        XCTAssertEqual(game.storyChoices, [:])
    }

    func testNewSaveRoundTripsStoryAndProjectProgress() throws {
        var game = CrimeEconomy()
        _ = game.buy(0)
        _ = game.chooseStory(0, option: 1)
        _ = game.completeProject(0)
        let data = try JSONEncoder().encode(game)
        let loaded = try JSONDecoder().decode(CrimeEconomy.self, from: data)
        XCTAssertEqual(loaded, game)
    }
}
