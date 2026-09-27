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
        game.recordWin(at: Date(timeIntervalSince1970: 120))
        XCTAssertEqual(game.bestTimes[3], 20)
        game.recordWin(at: Date(timeIntervalSince1970: 125))
        XCTAssertEqual(game.bestTimes[3], 20)
        let nextGame = PuzzleEngine(size: 4, bestTimes: game.bestTimes)
        XCTAssertEqual(nextGame.bestTimes[3], 20)
    }

    func testUndoRestoresPreviousBoard() {
        var game = PuzzleEngine(size: 3)
        XCTAssertFalse(game.undo())
        XCTAssertTrue(game.move(tileAt: 7))
        XCTAssertTrue(game.undo())
        XCTAssertTrue(game.isSolved)
        XCTAssertEqual(game.moves, 0)
        XCTAssertFalse(game.undo())
    }

    func testSuggestedMoveIsAlwaysLegal() {
        for seed: UInt64 in [1, 7, 42, 999] {
            var game = PuzzleEngine(size: 3)
            game.shuffle(seed: seed)
            guard let hint = game.suggestedMove() else {
                XCTFail("Seed \(seed) deveria sugerir um movimento")
                continue
            }
            XCTAssertTrue(game.canMove(tileAt: hint), "Dica \(hint) deve ser jogável (seed \(seed))")
        }
        XCTAssertNil(PuzzleEngine(size: 3).suggestedMove(), "Tabuleiro resolvido não tem dica")
    }

    func testShuffleIsNeverSolvedAndAlwaysSolvable() {
        for size in [3, 4, 5, 6] {
            for seed: UInt64 in [1, 2, 3, 17, 44, 1234] {
                var game = PuzzleEngine(size: size)
                game.shuffle(seed: seed)
                XCTAssertFalse(game.isSolved, "size \(size) seed \(seed) não pode sair resolvido")
                XCTAssertTrue(game.isSolvable(), "size \(size) seed \(seed) deve ser solucionável")
                XCTAssertEqual(game.tiles.sorted(), Array(0..<(size * size)))
                XCTAssertEqual(game.moves, 0)
            }
        }
    }

    func testLegacySaveWithoutNewFieldsStillLoads() throws {
        // Formato antigo: só size/tiles/moves/startedAt/bestTimes.
        let legacy = """
        {"size":3,"tiles":[1,2,3,4,5,6,7,0,8],"moves":4,"startedAt":1000,"bestTimes":{"3":20}}
        """.data(using: .utf8)!
        let game = try JSONDecoder().decode(PuzzleEngine.self, from: legacy)
        XCTAssertEqual(game.size, 3)
        XCTAssertEqual(game.moves, 4)
        XCTAssertEqual(game.bestTimes[3], 20)
        XCTAssertEqual(game.bestMoves, [:])
        XCTAssertEqual(game.history, [])
        XCTAssertNil(game.solvedAt)
    }

    func testWinFreezesTimerAndRecordsHistoryOnce() {
        var game = PuzzleEngine(size: 3)
        game.shuffle(seed: 17)
        XCTAssertNotNil(game.suggestedMove())
        // Vai e volta: sai do resolvido e resolve de novo com timer congelado.
        var solved = PuzzleEngine(size: 3, startedAt: Date(timeIntervalSince1970: 100))
        XCTAssertTrue(solved.move(tileAt: 7, at: Date(timeIntervalSince1970: 105)))
        XCTAssertFalse(solved.isSolved)
        XCTAssertTrue(solved.move(tileAt: 8, at: Date(timeIntervalSince1970: 106)))
        XCTAssertTrue(solved.isSolved)
        XCTAssertEqual(solved.moves, 2)
        solved.recordWin(at: Date(timeIntervalSince1970: 130))
        XCTAssertEqual(solved.elapsedSeconds(at: Date(timeIntervalSince1970: 9_999)), 6, "Timer deve congelar na vitória")
        XCTAssertEqual(solved.bestTimes[3], 6)
        XCTAssertEqual(solved.bestMoves[3], 2)
        XCTAssertEqual(solved.history.count, 1)
        XCTAssertEqual(solved.gamesWon, 1)
        solved.recordWin(at: Date(timeIntervalSince1970: 140))
        XCTAssertEqual(solved.history.count, 1, "Vitória duplicada não entra no histórico")
    }

    func testRestartRestoresInitialPosition() {
        var game = PuzzleEngine(size: 3)
        game.shuffle(seed: 17)
        let initial = game.tiles
        _ = game.move(tileAt: game.suggestedMove() ?? 7)
        XCTAssertNotEqual(game.tiles, initial)
        game.restartPosition()
        XCTAssertEqual(game.tiles, initial)
        XCTAssertEqual(game.moves, 0)
        XCTAssertFalse(game.isSolved)
    }

    func testCorruptedSaveFallsBackToSolvedBoard() throws {
        let badSizes = [
            #"{"size":3,"tiles":[1,2,3],"moves":4}"#,
            #"{"size":3,"tiles":[1,1,1,2,3,4,5,6,7],"moves":4}"#,
            #"{"size":99,"tiles":[1,2,3],"moves":-5}"#,
        ]
        for json in badSizes {
            let game = try JSONDecoder().decode(PuzzleEngine.self, from: Data(json.utf8))
            XCTAssertEqual(game.tiles.sorted(), Array(0..<(game.size * game.size)), "Save inválido deve virar tabuleiro válido: \(json)")
            XCTAssertEqual(game.moves, 0)
            XCTAssertNil(game.initialTiles)
        }
    }

    func testUndoStackIsNotPersisted() throws {
        var game = PuzzleEngine(size: 3)
        XCTAssertTrue(game.move(tileAt: 7))
        XCTAssertTrue(game.canUndo)
        let restored = try JSONDecoder().decode(PuzzleEngine.self, from: JSONEncoder().encode(game))
        XCTAssertFalse(restored.canUndo, "Undo não deve sobreviver ao relançar o app")
        XCTAssertEqual(restored.tiles, game.tiles)
        XCTAssertEqual(restored.moves, game.moves)
    }

    func testPauseFreezesAndResumeCompensates() {
        var game = PuzzleEngine(size: 3, startedAt: Date(timeIntervalSince1970: 100))
        game.pause(at: Date(timeIntervalSince1970: 130))
        XCTAssertEqual(game.elapsedSeconds(at: Date(timeIntervalSince1970: 9_999)), 30, "Pausado congela o timer")
        game.resume(at: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(game.elapsedSeconds(at: Date(timeIntervalSince1970: 210)), 40, "Resume desconta o tempo em fundo")
        // Pausar tabuleiro resolvido não faz nada.
        var solved = PuzzleEngine(size: 3, startedAt: Date(timeIntervalSince1970: 100))
        solved.pause(at: Date(timeIntervalSince1970: 130))
        XCTAssertEqual(solved.elapsedSeconds(at: Date(timeIntervalSince1970: 140)), 40)
    }

    func testDailyWinIsRememberedByDay() {
        var solved = PuzzleEngine(size: 3, startedAt: Date(timeIntervalSince1970: 100))
        _ = solved.move(tileAt: 7)
        _ = solved.move(tileAt: 8)
        XCTAssertTrue(solved.isSolved)
        solved.recordWin(at: Date(timeIntervalSince1970: 150))
        XCTAssertTrue(solved.dailyWins.isEmpty, "Só daily conta como daily")
        var daily = PuzzleEngine(size: 3, startedAt: Date(timeIntervalSince1970: 100))
        daily.shuffle(seed: 9, startedAt: Date(timeIntervalSince1970: 100), isDaily: true)
        var steps = 0
        while !daily.isSolved, steps < 40 {
            guard let hint = daily.suggestedMove() else { break }
            _ = daily.move(tileAt: hint)
            steps += 1
        }
        XCTAssertTrue(daily.isSolved)
        daily.recordWin(at: Date(timeIntervalSince1970: 150))
        XCTAssertEqual(daily.dailyWins, [PuzzleEngine.dayString(Date(timeIntervalSince1970: 150))])
    }

    func testHint3x3FindsWinningMoveOneStepAway() {
        var game = PuzzleEngine(size: 3)
        _ = game.move(tileAt: 7)
        XCTAssertFalse(game.isSolved)
        XCTAssertEqual(game.suggestedMove(), 8, "A 1 lance da vitória, a dica deve ser o lance vencedor")
    }

    func testFollowingHintsSolves3x3() {
        var game = PuzzleEngine(size: 3)
        game.shuffle(seed: 17)
        var steps = 0
        while !game.isSolved, steps < 40 {
            guard let hint = game.suggestedMove() else { break }
            XCTAssertTrue(game.move(tileAt: hint))
            steps += 1
        }
        XCTAssertTrue(game.isSolved, "Seguir as dicas deve resolver o 3×3 (ótimo IDA*)")
        XCTAssertLessThanOrEqual(steps, 35)
    }

    func testHintIsLegalOnAllSizes() {
        for size in [4, 5, 6] {
            for seed: UInt64 in [3, 17, 1234] {
                var game = PuzzleEngine(size: size)
                game.shuffle(seed: seed)
                guard let hint = game.suggestedMove() else {
                    XCTFail("size \(size) seed \(seed) deveria sugerir")
                    continue
                }
                XCTAssertTrue(game.canMove(tileAt: hint))
            }
        }
    }

    func testDifficultyStepsScaleWithSizeAndLevel() {
        XCTAssertLessThan(PuzzleDifficulty.facil.steps(for: 3), PuzzleDifficulty.normal.steps(for: 3))
        XCTAssertLessThan(PuzzleDifficulty.normal.steps(for: 3), PuzzleDifficulty.dificil.steps(for: 3))
        XCTAssertLessThan(PuzzleDifficulty.normal.steps(for: 3), PuzzleDifficulty.normal.steps(for: 6))
    }
}
