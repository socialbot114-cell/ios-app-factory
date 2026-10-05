import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballSetPieceTests: XCTestCase {
    private func base() throws -> (FootballCareer, MatchSimulation, [Int: FootballPlayer]) {
        var career = FootballCareer(seed: 5)
        XCTAssertTrue(career.chooseClub(0))
        career.setSetPieceRoutine(SetPieceRoutine())
        let fixture = try XCTUnwrap(career.fixtures.first { $0.home == 0 && $0.competition.division != nil })
        return (career, career.makeSimulation(fixture: fixture, detailed: true), career.playersByID())
    }

    private func run(_ base: MatchSimulation, seed: UInt64, routine: SetPieceRoutine?, players: [Int: FootballPlayer]) -> MatchSimulation {
        var sim = MatchSimulation.make(fixtureID: 1, seed: seed, isCup: false, isDerby: false, detailed: true, home: base.home, away: base.away)
        sim.home.setPieceRoutine = routine
        sim.runToEnd(players: players)
        return sim
    }

    private func shots(_ sim: MatchSimulation, position: FootballPosition, players: [Int: FootballPlayer]) -> Int {
        sim.home.stats.values.filter { players[$0.playerID]?.position == position }.reduce(0) { $0 + $1.shots }
    }

    func testRoutineShiftsWhoFinishesSetPieces() throws {
        let (_, base, players) = try base()
        XCTAssertTrue(base.home.isUserControlled)
        XCTAssertNotNil(base.home.setPieceRoutine, "A rotina vai para o lado do usuário")
        XCTAssertNil(base.away.setPieceRoutine, "IA sem rotina")
        var far = (defenders: 0, midfielders: 0)
        var short = (defenders: 0, midfielders: 0)
        for seed in 1...300 {
            let farSim = run(base, seed: UInt64(seed) &* 7_919, routine: SetPieceRoutine(corner: .farPost, freeKick: .cross), players: players)
            let shortSim = run(base, seed: UInt64(seed) &* 7_919, routine: SetPieceRoutine(corner: .short, freeKick: .cross), players: players)
            far.defenders += shots(farSim, position: .defender, players: players)
            far.midfielders += shots(farSim, position: .midfielder, players: players)
            short.defenders += shots(shortSim, position: .defender, players: players)
            short.midfielders += shots(shortSim, position: .midfielder, players: players)
        }
        XCTAssertGreaterThan(far.defenders, short.defenders, "Segundo pau: mais finalizações de zagueiros")
        XCTAssertGreaterThan(short.midfielders, far.midfielders, "Escanteio curto: mais finalizações de meias")
    }

    func testRoutineKeepsTheGoalAverage() throws {
        let (career, base, players) = try base()
        let routine = try XCTUnwrap(career.matchSetPieceRoutine(lineup: base.home.onPitch))
        var with = 0, without = 0
        for seed in 1...300 {
            with += run(base, seed: UInt64(seed) &* 31, routine: routine, players: players).home.goals
            without += run(base, seed: UInt64(seed) &* 31, routine: nil, players: players).home.goals
        }
        XCTAssertEqual(Double(with) / 300, Double(without) / 300, accuracy: 0.15, "Encaixe com média ~1 não muda o placar médio")
    }

    func testFitRangeAndTakersMustBeInTheLineup() throws {
        var (career, base, _) = try base()
        let outsider = try XCTUnwrap(career.clubRoster.first { !base.home.onPitch.contains($0.id) })
        let insider = try XCTUnwrap(base.home.onPitch.first)
        career.setSetPieceRoutine(SetPieceRoutine(corner: .nearPost, freeKick: .direct, cornerTakerID: insider, freeKickTakerID: outsider.id))
        let routine = try XCTUnwrap(career.matchSetPieceRoutine(lineup: base.home.onPitch))
        XCTAssertEqual(routine.cornerTakerID, insider)
        XCTAssertNil(routine.freeKickTakerID, "Cobrador fora da escalação não vale")
        XCTAssertTrue((0.9...1.12).contains(routine.cornerFit))
        let scores = career.setPieceScores(lineup: base.home.onPitch.compactMap { career.player($0) })
        let best = try XCTUnwrap(scores.corner.max { $0.value < $1.value }?.key)
        career.setSetPieceRoutine(SetPieceRoutine(corner: best))
        XCTAssertEqual(try XCTUnwrap(career.matchSetPieceRoutine(lineup: base.home.onPitch)).cornerFit, 1.12, accuracy: 0.031)
        XCTAssertFalse(career.setPieceAdvice().isEmpty)
    }

    func testSaveMidMatchKeepsTheRoutineAndTheResult() throws {
        let (_, base, players) = try base()
        let routine = SetPieceRoutine(corner: .short, freeKick: .direct, cornerFit: 1.1, freeKickFit: 0.95)
        var full = MatchSimulation.make(fixtureID: 1, seed: 77, isCup: false, isDerby: false, detailed: true, home: base.home, away: base.away)
        full.home.setPieceRoutine = routine
        var paused = full
        full.runToEnd(players: players)
        paused.advance(to: 37, players: players)
        let restored = try JSONDecoder().decode(MatchSimulation.self, from: JSONEncoder().encode(paused))
        XCTAssertEqual(restored.home.setPieceRoutine, routine)
        var resumed = restored
        resumed.runToEnd(players: players)
        XCTAssertEqual(resumed, full, "Salvar no meio não muda o jogo")
    }

    func testOldSavedMatchWithoutRoutineLoads() throws {
        let (_, base, _) = try base()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as? [String: Any])
        var home = try XCTUnwrap(json["home"] as? [String: Any])
        home.removeValue(forKey: "setPieceRoutine")
        json["home"] = home
        let decoded = try JSONDecoder().decode(MatchSimulation.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.home.setPieceRoutine)
    }
}
