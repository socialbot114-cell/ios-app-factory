import XCTest
@testable import AtelieColorir

final class ColoringEngineTests: XCTestCase {
    func testFillAndUndoRestorePreviousRegionState() {
        var engine = ColoringEngine()
        engine.fill(region: 2, color: 4)
        XCTAssertEqual(engine.fills[2], 4)
        engine.fill(region: 2, color: 1)
        engine.undo()
        XCTAssertEqual(engine.fills[2], 4)
    }

    func testInvalidRegionDoesNotChangeArtwork() {
        var engine = ColoringEngine()
        engine.fill(region: 10, color: 2)
        XCTAssertTrue(engine.fills.isEmpty)
    }

    func testRepeatedColorIsNoOpAndEngineCanBeRestored() throws {
        var engine = ColoringEngine()
        engine.fill(region: 1, color: 2)
        engine.fill(region: 1, color: 2)
        engine.fill(region: 1, color: 4)
        engine.undo()
        XCTAssertEqual(engine.fills[1], 2)
        let restored = try JSONDecoder().decode(ColoringEngine.self, from: JSONEncoder().encode(engine))
        XCTAssertEqual(restored, engine)
    }
}
