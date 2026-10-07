import Foundation
import XCTest
@testable import ManagerFutebol

/// HUD real da sala de espera: o resumo do save guarda energia, humor da torcida e data do jogo.
final class FootballHUDTests: XCTestCase {
    func testSlotSummaryDecodesWithoutHUDFields() throws {
        let json = Data(#"{"slot":0,"clubID":1,"season":2,"matchDay":3,"division":1,"updatedAt":0,"coachName":"Rafael"}"#.utf8)
        let summary = try JSONDecoder().decode(SaveSlotSummary.self, from: json)
        XCTAssertEqual(summary.coachName, "Rafael")
        XCTAssertNil(summary.energy)
        XCTAssertNil(summary.fanMood)
        XCTAssertNil(summary.gameDay)
        XCTAssertNil(summary.gameMoment)
    }

    func testSlotSummaryKeepsHUDFieldsInRoundTrip() throws {
        let moment = Date(timeIntervalSince1970: 1_800_000_000)
        let summary = SaveSlotSummary(slot: 0, clubID: 1, season: 2, matchDay: 3, division: .serieA,
                                      updatedAt: Date(timeIntervalSince1970: 0), coachName: "Rafael",
                                      energy: 42, fanMood: 73, gameDay: moment, gameMoment: moment)
        let decoded = try JSONDecoder().decode(SaveSlotSummary.self, from: JSONEncoder().encode(summary))
        XCTAssertEqual(decoded, summary)
        XCTAssertEqual(decoded.energy, 42)
        XCTAssertEqual(decoded.fanMood, 73)
    }

    func testStoreSummaryCopiesHUDFromCareer() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FootballHUD-\(UUID().uuidString)")
        let suiteName = "FootballHUDTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = FootballSaveStore(directory: directory, defaults: defaults)

        var career = FootballCareer(seed: 4)
        XCTAssertTrue(career.chooseClub(12))
        XCTAssertTrue(store.save(career, slot: 0))
        let summary = try XCTUnwrap(store.summary(slot: 0))
        XCTAssertEqual(summary.energy, career.world.coach.energy)
        XCTAssertEqual(summary.fanMood, career.fanMood)
        XCTAssertEqual(summary.gameDay, career.gameDay)
        XCTAssertEqual(summary.gameMoment, career.gameMoment)
    }

    func testStoreSummaryLeavesHUDEmptyWithoutClub() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FootballHUD-\(UUID().uuidString)")
        let suiteName = "FootballHUDTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = FootballSaveStore(directory: directory, defaults: defaults)

        let career = FootballCareer(seed: 4)
        XCTAssertTrue(store.save(career, slot: 0))
        let summary = try XCTUnwrap(store.summary(slot: 0))
        XCTAssertNil(summary.clubID)
        XCTAssertNil(summary.energy)
        XCTAssertNil(summary.fanMood)
        XCTAssertNil(summary.gameDay)
        XCTAssertNil(summary.gameMoment)
    }

    func testSignalBarsFollowFanMoodSteps() {
        XCTAssertEqual(PhoneSignal.litBars(nil), 0)
        XCTAssertEqual(PhoneSignal.litBars(0), 0)
        XCTAssertEqual(PhoneSignal.litBars(15), 1)
        XCTAssertEqual(PhoneSignal.litBars(60), 2)
        XCTAssertEqual(PhoneSignal.litBars(100), 4)
    }
}
