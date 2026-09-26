import XCTest
@testable import DetetiveNaTesta

final class DetectiveDeckTests: XCTestCase {
    func testRoundDoesNotRepeatCards() {
        let deck = DetectiveDeck()
        var used = Set<String>()
        for index in 0..<deck.cards.count {
            let next = deck.draw(excluding: used, seed: index)
            XCTAssertNotNil(next)
            if let next { XCTAssertTrue(used.insert(next).inserted) }
        }
        XCTAssertNil(deck.draw(excluding: used, seed: 4))
    }

    func testTiltRequiresNeutralStateBetweenEvents() {
        var gate = TiltGate()
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(gate.sample(pitch: 0.9, at: now), 1)
        XCTAssertNil(gate.sample(pitch: 0.9, at: now.addingTimeInterval(2)))
        XCTAssertNil(gate.sample(pitch: 0.05, at: now.addingTimeInterval(3)))
        XCTAssertEqual(gate.sample(pitch: -0.9, at: now.addingTimeInterval(4)), -1)
    }
}
