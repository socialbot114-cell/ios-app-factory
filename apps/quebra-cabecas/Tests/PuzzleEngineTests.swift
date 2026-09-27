import Foundation
import XCTest
@testable import QuebraCabecas

final class PuzzleEngineTests: XCTestCase {
    func testShuffleIsDeterministicAndProducesValidBoard() {
        var first = PuzzleEngine(size: 4)
        var second = PuzzleEngine(size: 4)
        let start = Date(timeIntervalSince1970: 1_000)
        first.shuffle(seed: 42, startedAt: start)
        second.shuffle(seed: 42, startedAt: start)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.tiles.sorted(), Array(0..<16))
        XCTAssertFalse(first.isSolved)
    }

    func testOnlyAdjacentTilesCanMove() {
        var game = PuzzleEngine(size: 3)
        XCTAssertTrue(game.move(tileAt: 7))
        XCTAssertEqual(game.moves, 1)
        XCTAssertFalse(game.move(tileAt: 0))
        XCTAssertEqual(game.moves, 1)
    }

    func testLegalShuffleCanBeRestoredFromEncoding() throws {
        var game = PuzzleEngine(size: 6)
        game.shuffle(seed: 987)
        let restored = try JSONDecoder().decode(PuzzleEngine.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(game, restored)
    }

    func testSolvedBoardRecordsBestTimeOnlyOncePerSize() {
        var game = PuzzleEngine(size: 3, startedAt: Date(timeIntervalSince1970: 100))
        game.recordBest(at: Date(timeIntervalSince1970: 120))
        XCTAssertEqual(game.bestTimes[3], 20)
        game.recordBest(at: Date(timeIntervalSince1970: 125))
        XCTAssertEqual(game.bestTimes[3], 20)
        let nextGame = PuzzleEngine(size: 4, bestTimes: game.bestTimes)
        XCTAssertEqual(nextGame.bestTimes[3], 20)
    }

    func testPictureModeShuffleStaysSolvableAndPersistsOwnRecord() throws {
        var game = PuzzleEngine(size: 4, mode: .picture, startedAt: Date(timeIntervalSince1970: 1_000), bestTimes: [4: 45])
        game.shuffle(seed: 42, steps: 81, startedAt: Date(timeIntervalSince1970: 1_000))
        XCTAssertFalse(game.isSolved)
        XCTAssertEqual(game.tiles.sorted(), Array(0..<16))
        XCTAssertEqual(game.mode, .picture)

        let restored = try JSONDecoder().decode(PuzzleEngine.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(restored, game)

        var solvedImage = PuzzleEngine(size: 3, mode: .picture, startedAt: Date(timeIntervalSince1970: 100), bestTimes: [3: 30])
        solvedImage.recordBest(at: Date(timeIntervalSince1970: 125))
        XCTAssertEqual(solvedImage.bestTime, 25)
        XCTAssertEqual(solvedImage.bestTimes[3], 30)
        XCTAssertEqual(solvedImage.imageBestTimes[3], 25)
    }

    func testOlderNumericSaveDefaultsToNumberMode() throws {
        let original = PuzzleEngine(size: 3, bestTimes: [3: 18])
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        legacy.removeValue(forKey: "mode")
        legacy.removeValue(forKey: "imageBestTimes")
        let data = try JSONSerialization.data(withJSONObject: legacy)

        let restored = try JSONDecoder().decode(PuzzleEngine.self, from: data)
        XCTAssertEqual(restored.mode, .numbers)
        XCTAssertEqual(restored.bestTimes[3], 18)
        XCTAssertTrue(restored.imageBestTimes.isEmpty)
    }
}
