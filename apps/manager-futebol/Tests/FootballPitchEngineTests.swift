import Foundation
import XCTest
@testable import ManagerFutebol

/// Campo ao vivo: física dos atletas, bola fora, escanteio, lateral, tiro de meta e o relógio andando pelo campo.
final class FootballPitchEngineTests: XCTestCase {
    /// Dois times em 4-4-2, como a tela monta (colunas de profundidade e laterais).
    private static func slots() -> [PitchSlotInfo] {
        let depths: [Double] = [0.07, 0.25, 0.43, 0.62]
        let counts = [1, 4, 4, 2]
        var result: [PitchSlotInfo] = []
        for home in [true, false] {
            var id = home ? 1 : 101
            for (column, count) in counts.enumerated() {
                for index in 0..<count {
                    let lateral = Double(index + 1) / Double(count + 1)
                    result.append(PitchSlotInfo(id: id, home: home, keeper: column == 0, number: id % 100, name: "J\(id)", depth: depths[column],
                                                lateral: home ? lateral : 1 - lateral))
                    id += 1
                }
            }
        }
        return result
    }

    private final class Rig {
        let engine = PitchEngine()
        var now = 100.0
        var input: PitchInput

        init(events: [MatchEvent] = [], share: Double = 0.5) {
            input = PitchInput(slots: FootballPitchEngineTests.slots(), homeShare: share, pressure: 0, events: events, homeTeamID: 1, finished: false)
        }

        /// Roda `seconds` de relógio real a 30 quadros por segundo, com o multiplicador de velocidade da tela.
        func run(seconds: Double, speed: Double = 1, each: (PitchEngine) -> Void = { _ in }) {
            let frames = Int(seconds * 30)
            for _ in 0..<frames {
                now += 1.0 / 30
                engine.advance(now: now, speed: speed, input: input)
                each(engine)
            }
        }

        /// Roda até a condição valer ou o tempo acabar; devolve se valeu.
        @discardableResult
        func run(until seconds: Double, speed: Double = 1, _ condition: (PitchEngine) -> Bool) -> Bool {
            let frames = Int(seconds * 30)
            for _ in 0..<frames {
                now += 1.0 / 30
                engine.advance(now: now, speed: speed, input: input)
                if condition(engine) { return true }
            }
            return false
        }
    }

    private func event(_ kind: MatchEvent.Kind, team: Int = 1, x: Double? = nil, y: Double? = nil, text: String = "lance") -> MatchEvent {
        MatchEvent(minute: 10, kind: kind, teamID: team, text: text, x: x, y: y)
    }

    // MARK: - Física

    func testPlayersRespectSpeedAndAccelerationLimits() {
        let rig = Rig()
        var fastest = 0.0
        var worstJump = 0.0
        var previous: [Int: PitchVector] = [:]
        rig.run(seconds: 160) { engine in
            for body in engine.bodies {
                fastest = max(fastest, body.vel.length)
                if let before = previous[body.id], !(body.keeper && body.diveUntil > 0) {
                    worstJump = max(worstJump, (body.vel - before).length)
                }
                previous[body.id] = body.vel
            }
        }
        XCTAssertLessThanOrEqual(fastest, 9.3, "Ninguém passa de ~33 km/h")
        // 4,6 m/s² de arranque e 7,5 m/s² de freada em 1/30 s; o goleiro mergulha e fica fora da conta.
        XCTAssertLessThanOrEqual(worstJump, 0.30, "Variação de velocidade por quadro acima do possível")
    }

    func testBallStaysOnTheFieldAndOutsAreRestarted() {
        let rig = Rig()
        var wild = 0
        rig.run(seconds: 400) { engine in
            let p = engine.ballPos
            if p.x < -2 || p.x > PitchEngine.length + 2 || p.y < -2 || p.y > PitchEngine.width + 2 { wild += 1 }
        }
        XCTAssertEqual(wild, 0, "A bola não pode viajar para fora do estádio sem virar lateral, tiro de meta ou escanteio")
        let stats = rig.engine.stats
        XCTAssertGreaterThan(stats.throwIns, 6, "Faltou lateral: \(stats)")
        XCTAssertGreaterThanOrEqual(stats.goalKicks, 0)
        XCTAssertGreaterThan(stats.passes, 100)
    }

    func testThrowInIsTakenFromTheTouchlineWithTheBallOverTheHead() {
        let rig = Rig()
        var sawArmsUp = false
        var releasedAtLine = false
        var wasThrowIn = false
        var lastBall = PitchVector.zero
        rig.run(seconds: 500) { engine in
            if engine.currentRestart == .throwIn {
                wasThrowIn = true
                if engine.bodies.contains(where: { $0.pose == .throwIn }) {
                    sawArmsUp = true
                    XCTAssertGreaterThan(engine.ballZ, 1.5, "Na lateral a bola fica acima da cabeça")
                }
                lastBall = engine.ballPos
            } else if wasThrowIn {
                wasThrowIn = false
                if lastBall.y < 1.0 || lastBall.y > PitchEngine.width - 1.0 { releasedAtLine = true }
            }
        }
        XCTAssertTrue(sawArmsUp, "Ninguém cobrou lateral com os braços para cima")
        XCTAssertTrue(releasedAtLine, "A lateral tem que sair da linha lateral")
    }

    // MARK: - Escanteio

    func testCornerFromTheMatchLogIsTakenByAnAttackerFromTheFlagWithPlayersInTheBox() {
        let rig = Rig(events: [])
        rig.run(seconds: 12)
        rig.input.events = [event(.corner, text: "Escanteio para o Aurora")]
        var snapshots: [(taker: PitchBody?, inBox: Int, defending: Int, spot: PitchVector)] = []
        var sawCorner = false
        var finished = false
        rig.run(until: 60) { engine in
            if engine.currentRestart == .corner {
                sawCorner = true
                let ball = engine.ballPos
                let goalX = ball.x < PitchEngine.length / 2 ? 0.0 : PitchEngine.length
                let box = engine.bodies.filter { abs($0.pos.x - goalX) < 20 && abs($0.pos.y - PitchEngine.width / 2) < 20 }
                let attackers = box.filter { $0.home == engine.possessionHome && !$0.keeper }.count
                let defenders = box.filter { $0.home != engine.possessionHome && !$0.keeper }.count
                let taker = engine.bodies.filter { $0.home == engine.possessionHome && !$0.keeper }
                    .min { $0.pos.distance(to: ball) < $1.pos.distance(to: ball) }
                snapshots.append((taker, attackers, defenders, ball))
            } else if sawCorner {
                finished = true
            }
            return finished
        }
        XCTAssertTrue(sawCorner, "O escanteio da súmula tem que aparecer no campo")
        let last = try! XCTUnwrap(snapshots.last)
        XCTAssertLessThan(last.taker!.pos.distance(to: last.spot), 2.0, "O cobrador fica na bandeirinha")
        XCTAssertTrue(last.spot.y < 1 || last.spot.y > PitchEngine.width - 1, "Bola no canto do campo")
        XCTAssertGreaterThanOrEqual(last.inBox, 3, "Atacantes na área")
        XCTAssertGreaterThanOrEqual(last.defending, 3, "Defensores marcando na área")
        XCTAssertEqual(rig.engine.stats.corners, 1)
    }

    func testCornerHoldsTheClockUntilTheKickIsTaken() {
        let rig = Rig()
        rig.run(seconds: 20)
        rig.input.events = [event(.corner)]
        rig.run(seconds: 0.5)
        XCTAssertTrue(rig.engine.isShowingPlay(eventCount: 1), "Escanteio da súmula segura o relógio")
        var held = true
        rig.run(until: 40) { engine in
            if engine.currentRestart == nil, !engine.isShowingPlay(eventCount: 1) { held = false; return true }
            return false
        }
        XCTAssertFalse(held, "O relógio volta depois da cobrança")
    }

    func testSavedShotThatTheLogCallsACornerEndsInOneCornerKickNotTwo() {
        let rig = Rig()
        rig.run(seconds: 10)
        rig.input.events = [event(.save, x: 0.12, y: 0.5, text: "Cabeçada! Goleiro espalma para escanteio."), event(.corner)]
        rig.run(seconds: 45)
        XCTAssertEqual(rig.engine.stats.corners, 1, "Um escanteio só: o chute e o escanteio são a mesma jogada")
    }

    func testMissedShotEndsInAGoalKickTakenByTheKeeper() {
        let rig = Rig()
        rig.run(seconds: 10)
        rig.input.events = [event(.chance, x: 0.15, y: 0.4, text: "Chuta por cima")]
        var keeperTook = false
        rig.run(until: 40) { engine in
            if engine.currentRestart == .goalKick {
                let ball = engine.ballPos
                let nearest = engine.bodies.min { $0.pos.distance(to: ball) < $1.pos.distance(to: ball) }
                keeperTook = nearest?.keeper == true
                return true
            }
            return false
        }
        XCTAssertTrue(keeperTook, "Tiro de meta é cobrado pelo goleiro")
    }

    // MARK: - Relógio

    func testClockFollowsThePitchAtEverySpeed() {
        var minutes: [Double: Int] = [:]
        for speed in [1.0, 2.0, 4.0] {
            let rig = Rig()
            var counted = 0
            rig.run(seconds: 150 / speed, speed: speed) { engine in
                if engine.consumeMinute(seconds: FootballPitchPacing.secondsPerMinute, eventCount: 0) { counted += 1 }
            }
            minutes[speed] = counted
        }
        // 150 s de jogo no campo valem cerca de 60 minutos; 1x, 2x e 4x chegam ao mesmo ponto com 1x, 1/2 e 1/4 do tempo real.
        for (speed, counted) in minutes {
            XCTAssertEqual(Double(counted), 59, accuracy: 6, "A \(speed)x contou \(counted) minutos")
        }
    }

    func testScriptedGoalHoldsTheClockWhileTheCelebrationRuns() {
        let rig = Rig()
        rig.run(seconds: 15)
        rig.input.events = [event(.goal, x: 0.12, y: 0.5, text: "GOL!")]
        var consumedDuringPlay = 0
        var sawGoal = false
        rig.run(seconds: 25) { engine in
            if engine.celebratingHome != nil { sawGoal = true }
            if engine.isShowingPlay(eventCount: 1), engine.consumeMinute(seconds: 0.1, eventCount: 1) { consumedDuringPlay += 1 }
        }
        XCTAssertTrue(sawGoal)
        XCTAssertEqual(consumedDuringPlay, 0, "Minuto não passa no meio do lance da súmula")
    }

    // MARK: - Impedimento e pênalti no jogo corrido

    func testOffsideShowsTheLineAndTheRivalTakesTheFreeKick() {
        let rig = Rig()
        rig.run(seconds: 15)
        // Time 1 (mandante) é o do impedimento; o visitante cobra.
        rig.input.events = [MatchEvent(minute: 10, kind: .offside, teamID: 1, text: "Impedimento", playerID: 9)]
        var sawLine = false
        var sawLabel = false
        var kicker: Bool?
        rig.run(seconds: 20) { engine in
            if engine.offsideMark != nil { sawLine = true }
            if engine.restartLabel == "Impedimento" { sawLabel = true }
            if engine.currentRestart == .freeKick, kicker == nil { kicker = engine.restartLabelHome }
        }
        XCTAssertTrue(sawLine, "A linha do impedimento aparece")
        XCTAssertTrue(sawLabel, "O nome do lance aparece")
        XCTAssertEqual(kicker, false, "O rival do impedido cobra")
    }

    func testPenaltyClearsTheAreaAndTheKeeperWaitsOnTheLine() {
        let rig = Rig()
        rig.run(seconds: 15)
        rig.input.events = [
            MatchEvent(minute: 10, kind: .penaltyAwarded, teamID: 1, text: "Pênalti para o time", playerID: 9),
            MatchEvent(minute: 10, kind: .goal, teamID: 1, text: "GOL de pênalti!", playerID: 9, xg: 0.76, x: 0.11, y: 0.5)
        ]
        var sawLabel = false
        var inBoxWhenKicked = Int.max
        var sawKick = false
        rig.run(seconds: 30) { engine in
            if engine.restartLabel == "Pênalti" { sawLabel = true }
            if !sawKick, engine.ballZ > 0.25 || engine.ballPos.distance(to: PitchVector(PitchEngine.length - 11, PitchEngine.width / 2)) > 2.5,
               sawLabel, engine.celebratingHome == nil {
                // Primeiro instante com a bola se movendo depois do rótulo: conta quantos estão na grande área.
                let moving = engine.trail.count > 1
                if moving {
                    sawKick = true
                    inBoxWhenKicked = engine.bodies.filter { body in
                        !body.keeper && body.id != 9 && body.pos.x > PitchEngine.length - 16.5 && abs(body.pos.y - PitchEngine.width / 2) < 20.15
                    }.count
                }
            }
        }
        XCTAssertTrue(sawLabel, "Pênalti aparece escrito")
        XCTAssertTrue(sawKick)
        XCTAssertLessThanOrEqual(inBoxWhenKicked, 1, "Ninguém dentro da área no chute (tolerância de um atrasado)")
    }

    func testPenaltyThatTheLogCallsAMissIsNotAGoal() {
        let rig = Rig()
        rig.run(seconds: 15)
        rig.input.events = [
            MatchEvent(minute: 10, kind: .penaltyAwarded, teamID: 1, text: "Pênalti", playerID: 9),
            MatchEvent(minute: 10, kind: .save, teamID: 1, text: "J9 isola a cobrança!", playerID: 9, xg: 0.76, x: 0.11, y: 0.5)
        ]
        var celebrated = false
        rig.run(seconds: 30) { engine in
            if engine.celebratingHome != nil { celebrated = true }
        }
        XCTAssertFalse(celebrated, "Pênalti para fora não vira gol")
    }

    // MARK: - Resultado coerente

    func testPossessionFollowsTheMatchShare() {
        for (share, range) in [(0.65, 0.5...0.85), (0.35, 0.15...0.5)] {
            let rig = Rig(share: share)
            rig.run(seconds: 600)
            let s = rig.engine.stats
            let fraction = s.homePossessionSeconds / max(1, s.homePossessionSeconds + s.awayPossessionSeconds)
            XCTAssertTrue(range.contains(fraction), "Posse \(fraction) para \(share)")
        }
    }

    func testSameInputsGiveTheSamePlay() {
        let a = Rig(), b = Rig()
        a.run(seconds: 90)
        b.run(seconds: 90)
        XCTAssertEqual(a.engine.ballPos, b.engine.ballPos)
        XCTAssertEqual(a.engine.stats, b.engine.stats)
    }

    func testFreeKicksAreNeverTakenOnTheGoalLine() {
        let rig = Rig()
        var spots: [PitchVector] = []
        var wallSeen = false
        for round in 0..<14 {
            rig.run(seconds: 18)
            rig.input.events.append(MatchEvent(minute: 5 + round, kind: .yellowCard, teamID: round % 2 == 0 ? 1 : 101, text: "Cartão", playerID: nil))
            rig.run(until: 25) { engine in
                if engine.currentRestart == .freeKick {
                    spots.append(engine.ballPos)
                    return false
                }
                return !spots.isEmpty && engine.currentRestart == nil
            }
            _ = wallSeen
            wallSeen = true
        }
        XCTAssertGreaterThan(spots.count, 5, "Cartões viram faltas cobradas")
        for spot in spots {
            XCTAssertGreaterThanOrEqual(spot.x, 11.9, "Falta na linha de fundo")
            XCTAssertLessThanOrEqual(spot.x, PitchEngine.length - 11.9, "Falta na linha de fundo")
        }
    }

    func testPrintCalibration() {
        var lines: [String] = []
        for (speed, share) in [(1.0, 0.5), (2.0, 0.65), (4.0, 0.35)] {
            let rig = Rig(share: share)
            rig.run(seconds: 225 / speed, speed: speed)
            lines.append("speed \(speed) share \(share): \(rig.engine.stats)")
        }
        print("CALIB>>>\n" + lines.joined(separator: "\n") + "\n<<<CALIB")
    }
}
