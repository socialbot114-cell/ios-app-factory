import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballUnlockQueueTests: XCTestCase {
    private func notice(_ number: Int) -> UnlockNotice {
        UnlockNotice(id: "meta-\(number)", title: "Meta \(number)", detail: "Detalhe \(number)", symbol: "checklist", appID: "quests")
    }

    func testQueueKeepsTenAndDropsTheOldest() {
        var queue: [UnlockNotice] = []
        for number in 1...12 { queue = FootballUnlockQueue.enqueue(notice(number), in: queue) }
        XCTAssertEqual(FootballUnlockQueue.limit, 10)
        XCTAssertEqual(queue.count, FootballUnlockQueue.limit)
        XCTAssertEqual(queue.map(\.id), (3...12).map { "meta-\($0)" }, "Saem os dois avisos mais antigos")
    }

    func testQueueIsFirstInFirstOut() {
        var queue = FootballUnlockQueue.enqueue(notice(1), in: [])
        queue = FootballUnlockQueue.enqueue(notice(2), in: queue)
        queue = FootballUnlockQueue.enqueue(notice(3), in: queue)
        XCTAssertEqual(queue.map(\.id), ["meta-1", "meta-2", "meta-3"])
        XCTAssertEqual(queue.first?.id, "meta-1", "A faixa mostra sempre o mais antigo")
    }

    func testDequeueRemovesOnlyTheFirst() {
        let remaining = FootballUnlockQueue.dequeue([notice(1), notice(2), notice(3)])
        XCTAssertEqual(remaining.map(\.id), ["meta-2", "meta-3"])
        XCTAssertTrue(FootballUnlockQueue.dequeue([]).isEmpty)
    }

    func testSaveWithoutQueueDecodesEmpty() throws {
        var career = FootballCareer(seed: 7)
        career.enqueueUnlock(notice(1))
        career.enqueueUnlock(notice(2))
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        legacy.removeValue(forKey: "unlockQueue")
        let migrated = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertTrue(migrated.unlockQueue.isEmpty)
    }

    func testFilledQueueSurvivesSaveRoundTrip() throws {
        var career = FootballCareer(seed: 7)
        for number in 1...4 { career.enqueueUnlock(notice(number)) }
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip.unlockQueue, career.unlockQueue)
        XCTAssertEqual(roundTrip, career)
    }
}
