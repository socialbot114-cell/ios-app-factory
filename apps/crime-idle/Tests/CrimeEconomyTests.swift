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
}
