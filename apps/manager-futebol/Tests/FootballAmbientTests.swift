import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballAmbientTests: XCTestCase {
    func testBatchHasDistinctKinds() {
        for offset in 0..<40 {
            let date = Date(timeIntervalSince1970: Double(offset) * 90)
            let batch = AmbientFeed.batch(at: date)
            XCTAssertEqual(batch.count, 5)
            XCTAssertEqual(Set(batch.map(\.kind)).count, batch.count)
        }
    }

    func testBatchWithoutContextNeverShowsReactiveNotices() {
        for offset in 0..<40 {
            let batch = AmbientFeed.batch(at: Date(timeIntervalSince1970: Double(offset) * 90))
            XCTAssertTrue(batch.allSatisfy { $0.mood == nil })
        }
    }

    func testBatchReactsToTheLastResult() {
        let context = AmbientContext(lastResult: .win, lowCash: false)
        for offset in 0..<40 {
            let batch = AmbientFeed.batch(at: Date(timeIntervalSince1970: Double(offset) * 90), context: context)
            XCTAssertEqual(batch.count, 5)
            XCTAssertTrue(batch.contains { $0.mood == .win })
            XCTAssertTrue(batch.allSatisfy { $0.mood == nil || $0.mood == .win })
        }
    }

    func testBatchCanReactToLowCashAndLoss() {
        let context = AmbientContext(lastResult: .loss, lowCash: true)
        let batch = AmbientFeed.batch(at: Date(timeIntervalSince1970: 9_000), context: context)
        let moods = batch.compactMap(\.mood)
        XCTAssertFalse(moods.isEmpty)
        XCTAssertTrue(moods.allSatisfy { $0 == .loss || $0 == .lowCash })
    }

    func testPoolHasUniqueIDs() {
        XCTAssertEqual(Set(AmbientFeed.pool.map(\.id)).count, AmbientFeed.pool.count)
    }

    func testStreakRule() {
        XCTAssertEqual(FootballVisitStreak.next(streak: 0, lastDay: nil, today: "b", yesterday: "a"), 1)
        XCTAssertEqual(FootballVisitStreak.next(streak: 3, lastDay: "b", today: "b", yesterday: "a"), 3)
        XCTAssertEqual(FootballVisitStreak.next(streak: 3, lastDay: "a", today: "b", yesterday: "a"), 4)
        XCTAssertEqual(FootballVisitStreak.next(streak: 5, lastDay: "x", today: "b", yesterday: "a"), 1)
    }

    func testCareerContextStartsNeutral() {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertNil(career.ambientContext.lastResult)
    }

    func testSlotSummaryDecodesWithoutCoachName() throws {
        let json = Data(#"{"slot":0,"clubID":1,"season":2,"matchDay":3,"division":1,"updatedAt":0}"#.utf8)
        let summary = try JSONDecoder().decode(SaveSlotSummary.self, from: json)
        XCTAssertNil(summary.coachName)
        XCTAssertEqual(summary.season, 2)
    }

    func testSlotSummaryKeepsCoachNameInRoundTrip() throws {
        let summary = SaveSlotSummary(slot: 1, clubID: 3, season: 1, matchDay: 0, division: .serieB, updatedAt: Date(timeIntervalSince1970: 0), coachName: "Marina")
        let decoded = try JSONDecoder().decode(SaveSlotSummary.self, from: JSONEncoder().encode(summary))
        XCTAssertEqual(decoded, summary)
        XCTAssertEqual(decoded.coachName, "Marina")
    }
}
