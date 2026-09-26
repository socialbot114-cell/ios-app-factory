import XCTest
@testable import DiarioSono

final class SleepSessionTests: XCTestCase {
    func testSessionCanBeRestoredFromLocalEncoding() throws {
        var engine = SleepSessionEngine()
        let start = Date(timeIntervalSince1970: 1_000)
        engine.start(at: start)
        let restored = try JSONDecoder().decode(SleepSessionEngine.self, from: JSONEncoder().encode(engine))
        XCTAssertEqual(restored.activeStartedAt, start)
        XCTAssertTrue(restored.records.isEmpty)
    }

    func testInvalidEndTimeDoesNotSaveSession() {
        var engine = SleepSessionEngine()
        let start = Date(timeIntervalSince1970: 1_000)
        engine.start(at: start)
        XCTAssertFalse(engine.finish(at: start, rating: 5))
        XCTAssertTrue(engine.records.isEmpty)
        XCTAssertEqual(engine.activeStartedAt, start)
    }

    func testRatingIsBoundedToOneThroughFive() {
        let record = SleepRecord(startedAt: .now, endedAt: .now.addingTimeInterval(60), rating: 8)
        XCTAssertEqual(record.rating, 5)
    }

    func testSavedNoteAndClearAll() {
        var engine = SleepSessionEngine()
        let start = Date(timeIntervalSince1970: 1_000)
        engine.start(at: start)
        XCTAssertTrue(engine.finish(at: start.addingTimeInterval(8 * 60 * 60), rating: 3, note: "Demonstração"))
        XCTAssertEqual(engine.records.first?.note, "Demonstração")
        engine.clear()
        XCTAssertTrue(engine.records.isEmpty)
        XCTAssertNil(engine.activeStartedAt)
    }
}
