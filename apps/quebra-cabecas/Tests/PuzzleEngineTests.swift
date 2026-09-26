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
}
