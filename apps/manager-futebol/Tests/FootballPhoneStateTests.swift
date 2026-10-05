import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballPhoneStateTests: XCTestCase {
    private func career() -> FootballCareer {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    func testUrgentNoticesCanNeverBeMuted() {
        var prefs = PhonePreferences()
        prefs.minimumPriority = 3
        prefs.mutedApps = ["manager", "messages"]
        XCTAssertTrue(prefs.allows(appID: "manager", priority: 3))
        XCTAssertFalse(prefs.allows(appID: "alerts", priority: 2))
        prefs.minimumPriority = 2
        XCTAssertTrue(prefs.allows(appID: "alerts", priority: 2))
        XCTAssertFalse(prefs.allows(appID: "messages", priority: 2), "App silenciado")
        XCTAssertFalse(prefs.allows(appID: "betting", priority: 1))
    }

    func testActionLogPersistsDedupesAndIsCapped() throws {
        var career = career()
        career.logActionResult("Bilhete feito!", appID: "betting")
        career.logActionResult("Bilhete feito!", appID: "betting")
        career.logActionResult("   ", appID: nil)
        XCTAssertEqual(career.world.phone.actionLog.count, 1)
        for index in 0..<60 { career.logActionResult("Ação \(index)", appID: nil) }
        XCTAssertEqual(career.world.phone.actionLog.count, PhoneState.actionLogLimit)
        XCTAssertEqual(career.world.phone.actionLog.first?.text, "Ação 59")
        let data = try JSONEncoder().encode(career.world)
        let restored = try JSONDecoder().decode(WorldState.self, from: data)
        XCTAssertEqual(restored.phone, career.world.phone, "Preferências e histórico sobrevivem à reabertura")
    }

    func testDifficultyIsLockedByActiveChallengeAndChangesAreLogged() throws {
        var career = career()
        XCTAssertTrue(career.changeDifficulty(to: .hard))
        XCTAssertFalse(career.changeDifficulty(to: .hard))
        XCTAssertEqual(career.world.phone.difficultyChanges.first?.from, .normal)
        let scenario = try XCTUnwrap(ChallengeScenario.all.first)
        career.challenge = ChallengeState(scenarioID: scenario.id, startSeason: career.season, seasonsAllowed: scenario.seasonsAllowed)
        let before = career.difficulty
        XCTAssertFalse(career.canChangeDifficulty)
        XCTAssertFalse(career.changeDifficulty(to: .easy), "Não altera silenciosamente as regras do desafio")
        XCTAssertEqual(career.difficulty, before)
        XCTAssertNotNil(career.difficultyLockReason)
        XCTAssertFalse(career.activeChallengeRules.isEmpty)
        career.challenge?.status = .won
        XCTAssertTrue(career.canChangeDifficulty)
        XCTAssertTrue(career.activeChallengeRules.isEmpty)
    }

    func testOldSavesDecodeWithDefaultPhoneState() throws {
        let data = try JSONEncoder().encode(WorldState())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "phone")
        let world = try JSONDecoder().decode(WorldState.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(world.phone, PhoneState())
        XCTAssertTrue(world.phone.preferences.pauses.decisions)
    }
}
