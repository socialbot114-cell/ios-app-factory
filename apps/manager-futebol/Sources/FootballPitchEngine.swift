import SwiftUI

// MARK: - Vetor 2D (metros)

struct PitchVector: Equatable {
    var x: Double
    var y: Double

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    static let zero = PitchVector(0, 0)

    static func + (a: PitchVector, b: PitchVector) -> PitchVector { PitchVector(a.x + b.x, a.y + b.y) }
    static func - (a: PitchVector, b: PitchVector) -> PitchVector { PitchVector(a.x - b.x, a.y - b.y) }
    static func * (a: PitchVector, k: Double) -> PitchVector { PitchVector(a.x * k, a.y * k) }

    var length: Double { (x * x + y * y).squareRoot() }
    func distance(to other: PitchVector) -> Double { (self - other).length }
    var normalized: PitchVector {
        let size = length
        return size > 0.0001 ? PitchVector(x / size, y / size) : .zero
    }
}

struct PitchRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    /// Número entre 0 e 1.
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000
    }

    mutating func range(_ low: Double, _ high: Double) -> Double { low + (high - low) * next() }
}

// MARK: - Uniformes

struct PitchKit {
    enum Pattern { case solid, verticalStripes, hoops, halves, sash }

    var shirt: Color
    var trim: Color
    var shorts: Color
    var socks: Color
    var pattern: Pattern

    static func rgb(_ color: Color) -> (Double, Double, Double) {
        let resolved = color.resolve(in: EnvironmentValues())
        return (Double(resolved.red), Double(resolved.green), Double(resolved.blue))
    }

    /// Distância entre cores de 0 (iguais) a 1 (preto contra branco).
    static func contrast(_ a: Color, _ b: Color) -> Double {
        let left = rgb(a)
        let right = rgb(b)
        let dr = left.0 - right.0, dg = left.1 - right.1, db = left.2 - right.2
        return (dr * dr + dg * dg + db * db).squareRoot() / 1.732
    }

    static func patternFor(_ teamID: Int) -> Pattern {
        [Pattern.solid, .verticalStripes, .hoops, .halves, .sash][abs(teamID) % 5]
    }

    static func home(_ team: LeagueTeam?) -> PitchKit {
        let primary = team?.primaryColor ?? FootballTheme.accent
        let secondary = team?.secondaryColor ?? .white
        let dark = contrast(primary, .black) < 0.28
        return PitchKit(shirt: primary, trim: secondary, shorts: dark ? secondary : (contrast(secondary, primary) > 0.3 ? secondary : .white),
                        socks: primary, pattern: patternFor(team?.id ?? 0))
    }

    /// Camisa reserva: o visitante troca de uniforme quando as cores se confundem com as do mandante.
    static func away(_ team: LeagueTeam?, against rival: PitchKit) -> PitchKit {
        let first = home(team)
        if contrast(first.shirt, rival.shirt) >= 0.34 && contrast(first.trim, rival.shirt) >= 0.2 { return first }
        let swapped = PitchKit(shirt: first.trim, trim: first.shirt, shorts: first.shirt, socks: first.trim, pattern: first.pattern == .solid ? .hoops : .solid)
        if contrast(swapped.shirt, rival.shirt) >= 0.34 { return swapped }
        return PitchKit(shirt: .white, trim: first.shirt, shorts: first.shirt, socks: .white, pattern: .sash)
    }

    static func keeper(avoiding colors: [Color]) -> PitchKit {
        let palette: [Color] = [Color(red: 0.55, green: 0.90, blue: 0.20), Color(red: 1.0, green: 0.55, blue: 0.10),
                                Color(red: 0.95, green: 0.35, blue: 0.65), Color(red: 0.25, green: 0.80, blue: 0.95),
                                Color(red: 0.62, green: 0.40, blue: 0.95)]
        let pick = palette.first { candidate in colors.allSatisfy { contrast(candidate, $0) > 0.4 } } ?? palette[0]
        return PitchKit(shirt: pick, trim: .black.opacity(0.5), shorts: .black, socks: pick, pattern: .solid)
    }
}

// MARK: - Entradas do motor

struct PitchSlotInfo {
    let id: Int
    let home: Bool
    let keeper: Bool
    let number: Int
    let name: String
    let depth: Double
    let lateral: Double
}

struct PitchInput {
    var slots: [PitchSlotInfo]
    var homeShare: Double
    var pressure: Double
    var events: [MatchEvent]
    var homeTeamID: Int
    var finished: Bool
}

struct PitchBody {
    let id: Int
    var home: Bool
    var keeper: Bool
    var number: Int
    var name: String
    var depth: Double
    var lateral: Double
    var pos: PitchVector
    var vel = PitchVector.zero
    var facing = 1.0
    var stride = 0.0
    var diveUntil = 0.0
    var diveSide = 0.0
}

struct PitchCardMark {
    var pos: PitchVector
    var red: Bool
    var until: Double
}

// MARK: - Motor físico do campo

/// Simulação visual: jogadores com inércia, bola com posse, passes, arremates e goleiro.
/// Segue o placar real da partida: gols, defesas e chances viram jogadas completas.
final class PitchEngine {
    static let length = 105.0
    static let width = 68.0
    private static let goalHalf = 3.66

    private enum BallMode {
        case carried(Int)
        case pass(from: PitchVector, to: PitchVector, t: Double, duration: Double, apex: Double, target: Int)
        case shot
        case loose(Double)
        case net
        case restart
    }

    private enum Outcome { case goal, save, miss }
    private enum Phase { case approach, flight, aftermath }

    private struct Plan {
        var home: Bool
        var shooterID: Int
        var outcome: Outcome
        var penalty: Bool
        var phase = Phase.approach
        var timer = 0.0
        var spot = PitchVector.zero
        var spotSet = false
        var target = PitchVector.zero
        var targetZ = 0.0
        var side = 1.0
        var resolved = false
    }

    private(set) var bodies: [PitchBody] = []
    private(set) var ballPos = PitchVector(52.5, 34)
    private(set) var ballZ = 0.0
    private(set) var trail: [PitchVector] = []
    private(set) var cardMarks: [PitchCardMark] = []
    private(set) var referee = PitchVector(60, 20)
    private(set) var carrierID: Int?
    private(set) var celebratingHome: Bool?
    private(set) var possessionHome = true

    private var mode = BallMode.restart
    private var ballVel = PitchVector.zero
    private var ballVZ = 0.0
    private var plan: Plan?
    private var queue: [Plan] = []
    private var time = 0.0
    private var lastTime: Double?
    private var decisionTimer = 1.0
    private var consumed = 0
    private var initialized = false
    private var celebrationUntil = 0.0
    private var celebrationScorer = -1
    private var restartTimer = 0.0
    private var restartHome = true
    private var random = PitchRandom(seed: 0xC0FFEE)
    private var input = PitchInput(slots: [], homeShare: 0.5, pressure: 0, events: [], homeTeamID: -1, finished: false)

    private var warmed = false
    private var warmClock = 0.0

    var isWarmed: Bool { warmed }

    /// Só para capturas de tela: adianta a animação para o print mostrar o jogo em andamento (ou o gol sendo comemorado).
    func warmUpForCapture(input base: PitchInput) {
        warmed = true
        var before = base
        let goalIndex = base.events.lastIndex { $0.kind == .goal }
        if let goalIndex { before.events = Array(base.events[..<goalIndex]) }
        run(before, seconds: 14, stopWhenCelebrating: false)
        if goalIndex != nil { run(base, seconds: 12, stopWhenCelebrating: true) }
    }

    private func run(_ source: PitchInput, seconds: Double, stopWhenCelebrating: Bool) {
        var elapsed = 0.0
        var afterCelebration = 0.0
        while elapsed < seconds {
            warmClock += 1.0 / 30
            elapsed += 1.0 / 30
            advance(now: warmClock, speed: 1, input: source)
            if stopWhenCelebrating, celebratingHome != nil {
                afterCelebration += 1.0 / 30
                if afterCelebration > 1.2 { break }
            }
        }
    }

    /// Há jogada em andamento ou evento ainda por animar.
    func isBusy(eventCount: Int) -> Bool {
        plan != nil || !queue.isEmpty || celebratingHome != nil || restartTimer > 0 || consumed != eventCount
    }

    func body(_ id: Int) -> PitchBody? { bodies.first { $0.id == id } }

    private func index(of id: Int) -> Int? { bodies.firstIndex { $0.id == id } }

    // MARK: Avanço

    func advance(now: Double, speed: Double, input newInput: PitchInput) {
        let elapsed = lastTime.map { now - $0 } ?? 0
        lastTime = now
        input = newInput
        sync()
        processEvents()
        let scaled = min(0.06, max(0, elapsed)) * speed
        let steps = max(1, Int((scaled / 0.03).rounded(.up)))
        for _ in 0..<steps { step(scaled / Double(steps)) }
    }

    // MARK: Sincronia com a partida

    private func sync() {
        let ids = Set(input.slots.map(\.id))
        bodies.removeAll { !ids.contains($0.id) }
        for slot in input.slots {
            if let i = index(of: slot.id) {
                bodies[i].home = slot.home
                bodies[i].keeper = slot.keeper
                bodies[i].depth = slot.depth
                bodies[i].lateral = slot.lateral
                bodies[i].number = slot.number
            } else {
                var body = PitchBody(id: slot.id, home: slot.home, keeper: slot.keeper, number: slot.number, name: slot.name,
                                     depth: slot.depth, lateral: slot.lateral, pos: .zero)
                if initialized {
                    body.pos = PitchVector(Self.length / 2 + random.range(-6, 6), Self.width + 1.5)
                } else {
                    body.pos = kickoffSpot(body, homeKicks: true)
                }
                bodies.append(body)
            }
        }
        if !initialized, !bodies.isEmpty {
            initialized = true
            startKickoff(homeKicks: true)
        }
        if case .carried(let id) = mode, index(of: id) == nil {
            if let replacement = nearestPlayer(to: ballPos, home: possessionHome, outfieldOnly: true) {
                mode = .carried(replacement)
                carrierID = replacement
            } else {
                mode = .loose(1.0)
                carrierID = nil
            }
        }
    }

    // MARK: Eventos reais da partida

    private func processEvents() {
        let events = input.events
        if consumed > events.count { consumed = 0 }
        guard consumed < events.count else { return }
        let fresh = Array(events[consumed...])
        consumed = events.count
        if fresh.count > 6 || input.finished {
            plan = nil
            queue = []
            celebratingHome = nil
            startKickoff(homeKicks: possessionHome)
            return
        }
        for event in fresh {
            let isHome = event.teamID == input.homeTeamID
            switch event.kind {
            case .goal:
                if queue.count < 3 { queue.append(Plan(home: isHome, shooterID: event.playerID ?? -1, outcome: .goal, penalty: event.text.contains("pênalti"))) }
            case .save:
                if queue.count < 2 { queue.append(Plan(home: isHome, shooterID: event.playerID ?? -1, outcome: .save, penalty: event.text.contains("pênalti"))) }
            case .chance:
                if event.x != nil, queue.count < 2 { queue.append(Plan(home: isHome, shooterID: event.playerID ?? -1, outcome: .miss, penalty: false)) }
            case .yellowCard, .redCard:
                if let id = event.playerID, let i = index(of: id) {
                    cardMarks.append(PitchCardMark(pos: bodies[i].pos, red: event.kind == .redCard, until: time + 3.2))
                }
            case .halfTime:
                startKickoff(homeKicks: false)
            default:
                break
            }
        }
    }

    // MARK: Passo de simulação

    private func step(_ dt: Double) {
        guard dt > 0 else { return }
        time += dt
        cardMarks.removeAll { $0.until < time }
        if celebratingHome != nil, time > celebrationUntil {
            celebratingHome = nil
            startKickoff(homeKicks: restartHome)
        }
        if restartTimer > 0 {
            restartTimer -= dt
            if restartTimer <= 0 { beginPlayAfterRestart() }
        }
        if plan == nil, !queue.isEmpty, celebratingHome == nil, restartTimer <= 0, !input.finished {
            beginPlan(queue.removeFirst())
        }
        updateBall(dt)
        updatePlayers(dt)
        updateReferee(dt)
        if abs(ballVel.x) + abs(ballVel.y) > 12 {
            trail.append(ballPos)
            if trail.count > 7 { trail.removeFirst() }
        } else if !trail.isEmpty {
            trail.removeFirst()
        }
    }

    // MARK: Jogadas roteirizadas (gol, defesa, chance)

    private func beginPlan(_ new: Plan) {
        var next = new
        let candidates = bodies.filter { $0.home == next.home && !$0.keeper }
        let chosen = candidates.first { $0.id == next.shooterID } ?? candidates.max { $0.depth < $1.depth }
        guard let shooter = chosen else { return }
        next.shooterID = shooter.id
        next.side = random.next() < 0.5 ? -1 : 1
        let dir = next.home ? 1.0 : -1.0
        let goalX = next.home ? Self.length : 0
        if next.penalty {
            next.spot = PitchVector(goalX - dir * 11, Self.width / 2)
        } else {
            next.spot = PitchVector(goalX - dir * random.range(11, 23), Self.width / 2 + random.range(-9, 9))
        }
        next.spotSet = true
        plan = next
        possessionHome = next.home
        if carrierID != shooter.id {
            startPass(from: ballPos, targetID: shooter.id, long: true)
        }
    }

    private func fire(_ current: Plan) {
        guard let shooterIndex = index(of: current.shooterID) else { plan = nil; return }
        var next = current
        let shooter = bodies[shooterIndex]
        let dir = next.home ? 1.0 : -1.0
        let goalX = next.home ? Self.length : 0
        let goalY = Self.width / 2
        ballPos = shooter.pos + PitchVector(dir * 0.8, 0)
        var targetY = goalY
        var targetZ = 0.8
        switch next.outcome {
        case .goal:
            targetY = goalY + next.side * random.range(1.6, 3.2)
            targetZ = random.range(0.4, 1.9)
        case .save:
            targetY = goalY + next.side * random.range(1.0, 3.0)
            targetZ = random.range(0.3, 1.6)
        case .miss:
            if random.next() < 0.5 {
                targetY = goalY + next.side * (Self.goalHalf + random.range(0.8, 3.5))
                targetZ = random.range(0.3, 1.5)
            } else {
                targetY = goalY + next.side * random.range(0, 2.5)
                targetZ = random.range(3.1, 4.6)
            }
        }
        next.target = PitchVector(goalX, targetY)
        next.targetZ = targetZ
        let speed = next.penalty ? 22.0 : random.range(24, 31)
        let toTarget = next.target - ballPos
        let travel = max(0.2, toTarget.length / speed)
        ballVel = toTarget.normalized * speed
        ballZ = 0.3
        ballVZ = (targetZ - ballZ + 0.5 * 9.8 * travel * travel) / travel
        mode = .shot
        carrierID = nil
        next.phase = .flight
        next.timer = 0
        plan = next

        // Goleiro: acerta o lado quando defende, erra quando toma o gol.
        if let keeperIndex = bodies.firstIndex(where: { $0.keeper && $0.home != next.home }) {
            let reach: Double
            switch next.outcome {
            case .goal: reach = -next.side
            case .save: reach = next.side
            case .miss: reach = next.side * 0.3
            }
            bodies[keeperIndex].diveUntil = time + 0.9
            bodies[keeperIndex].diveSide = reach >= 0 ? 1 : -1
            bodies[keeperIndex].vel = PitchVector(-dir * 1.5, bodies[keeperIndex].diveSide * (next.outcome == .miss ? 3.5 : 8.5))
        }
    }

    private func updateShot(_ dt: Double) {
        guard var current = plan, current.phase == .flight else { return }
        current.timer += dt
        let dir = current.home ? 1.0 : -1.0
        let goalX = current.home ? Self.length : 0
        ballPos = ballPos + ballVel * dt
        ballZ += ballVZ * dt
        ballVZ -= 9.8 * dt
        if ballZ < 0 { ballZ = 0; ballVZ = abs(ballVZ) * 0.4 }
        let crossed = (ballPos.x - goalX) * dir >= 0
        let keeper = bodies.first { $0.keeper && $0.home != current.home }

        if current.outcome == .save, let keeper, ballPos.distance(to: keeper.pos) < 1.9, !current.resolved {
            current.resolved = true
            if random.next() < 0.5 {
                catchBall(keeper.id, defendingHome: !current.home)
                plan = nil
            } else {
                ballVel = PitchVector(-dir * 7, current.side * 7)
                ballVZ = 3.5
                mode = .loose(2.2)
                carrierID = nil
                plan = nil
            }
            return
        }
        if crossed {
            switch current.outcome {
            case .goal:
                mode = .net
                ballVel = .zero
                ballPos = PitchVector(goalX + dir * 1.1, ballPos.y)
                ballZ = 0.4
                celebratingHome = current.home
                celebrationScorer = current.shooterID
                celebrationUntil = time + 3.3
                restartHome = !current.home
                plan = nil
            case .save:
                catchBall(keeper?.id ?? -1, defendingHome: !current.home)
                plan = nil
            case .miss:
                ballVel = ballVel * 0.3
                current.phase = .aftermath
                current.timer = 0
                plan = current
            }
            return
        }
        if current.timer > 3.5 {
            plan = nil
            mode = .loose(1.0)
            return
        }
        plan = current
    }

    private func catchBall(_ keeperID: Int, defendingHome: Bool) {
        if index(of: keeperID) != nil {
            mode = .carried(keeperID)
            carrierID = keeperID
            possessionHome = defendingHome
            decisionTimer = random.range(1.0, 1.8)
        } else {
            mode = .loose(1.0)
            carrierID = nil
        }
    }

    // MARK: Bola

    private func updateBall(_ dt: Double) {
        if let current = plan {
            switch current.phase {
            case .approach:
                approachShot(current, dt)
            case .flight:
                updateShot(dt)
            case .aftermath:
                var next = current
                next.timer += dt
                ballPos = ballPos + ballVel * dt
                ballVel = ballVel * max(0, 1 - 1.8 * dt)
                ballZ = max(0, ballZ - 3 * dt)
                if next.timer > 1.3 {
                    plan = nil
                    if let keeper = bodies.first(where: { $0.keeper && $0.home != next.home }) {
                        catchBall(keeper.id, defendingHome: !next.home)
                    } else {
                        mode = .loose(1)
                    }
                } else {
                    plan = next
                }
            }
            return
        }
        switch mode {
        case .carried(let id):
            guard let i = index(of: id) else { return }
            let body = bodies[i]
            let desired = body.pos + PitchVector(body.facing * 0.9, 0.1 * sin(time * 7))
            ballPos = ballPos + (desired - ballPos) * min(1, 16 * dt)
            ballZ = abs(sin(time * 8 + Double(id))) * 0.22
            carrierID = id
            possessionHome = body.home
            decisionTimer -= dt
            if decisionTimer <= 0, restartTimer <= 0, !input.finished { decide(carrier: i) }
        case .pass(let from, let to, let t, let duration, let apex, let target):
            let progress = min(1, t + dt / duration)
            ballPos = from + (to - from) * progress
            ballZ = apex * 4 * progress * (1 - progress) + 0.2
            if progress >= 1 {
                if index(of: target) != nil {
                    mode = .carried(target)
                    carrierID = target
                    decisionTimer = random.range(0.7, 1.5)
                } else {
                    mode = .loose(1)
                }
            } else {
                mode = .pass(from: from, to: to, t: progress, duration: duration, apex: apex, target: target)
            }
        case .loose(let remaining):
            ballPos = ballPos + ballVel * dt
            ballVel = ballVel * max(0, 1 - 2.4 * dt)
            ballVZ -= 9.8 * dt
            ballZ += ballVZ * dt
            if ballZ < 0 { ballZ = 0; ballVZ = abs(ballVZ) * 0.35 }
            ballPos.x = min(Self.length + 1, max(-1, ballPos.x))
            ballPos.y = min(Self.width + 1, max(-1, ballPos.y))
            if let nearest = nearestPlayer(to: ballPos, home: nil, outfieldOnly: false),
               let i = index(of: nearest), bodies[i].pos.distance(to: ballPos) < 1.8 || remaining <= 0 {
                mode = .carried(nearest)
                carrierID = nearest
                possessionHome = bodies[i].home
                decisionTimer = random.range(0.8, 1.4)
            } else {
                mode = .loose(remaining - dt)
            }
        case .net:
            ballZ = max(0, ballZ - dt)
        case .restart:
            ballPos = PitchVector(Self.length / 2, Self.width / 2)
            ballZ = 0
        case .shot:
            break
        }
    }

    private func approachShot(_ current: Plan, _ dt: Double) {
        var next = current
        next.timer += dt
        guard let shooterIndex = index(of: next.shooterID) else { plan = nil; return }
        let shooter = bodies[shooterIndex]
        if carrierID == shooter.id, case .carried = mode {
            ballPos = ballPos + (shooter.pos + PitchVector(shooter.facing * 0.9, 0) - ballPos) * min(1, 16 * dt)
            ballZ = 0.1
            if shooter.pos.distance(to: next.spot) < 3.5 || next.timer > 2.6 {
                fire(next)
                return
            }
        } else if case .pass = mode {
            advancePassForPlan(dt)
            if next.timer > 3.2 { forceCarrier(shooter.id) }
        } else if next.timer > 3.2 {
            forceCarrier(shooter.id)
        }
        plan = next
    }

    private func advancePassForPlan(_ dt: Double) {
        guard case .pass(let from, let to, let t, let duration, let apex, let target) = mode else { return }
        let progress = min(1, t + dt / duration)
        ballPos = from + (to - from) * progress
        ballZ = apex * 4 * progress * (1 - progress) + 0.2
        if progress >= 1 {
            mode = .carried(target)
            carrierID = target
        } else {
            mode = .pass(from: from, to: to, t: progress, duration: duration, apex: apex, target: target)
        }
    }

    private func forceCarrier(_ id: Int) {
        mode = .carried(id)
        carrierID = id
        if let i = index(of: id) { ballPos = bodies[i].pos }
    }

    private func startPass(from origin: PitchVector, targetID: Int, long: Bool) {
        guard let i = index(of: targetID) else { return }
        let target = bodies[i]
        let distance0 = max(2, origin.distance(to: target.pos))
        let speed = 13 + distance0 * 0.3
        let duration = distance0 / speed
        let aim = target.pos + target.vel * (duration * 0.8)
        let apex = distance0 > 22 ? min(5, distance0 * 0.12) : distance0 * 0.02
        mode = .pass(from: origin, to: aim, t: 0, duration: max(0.25, duration), apex: apex, target: targetID)
        carrierID = nil
    }

    // MARK: Decisões de quem está com a bola

    private func decide(carrier i: Int) {
        let carrier = bodies[i]
        let share = carrier.home ? input.homeShare : 1 - input.homeShare
        let tackle = max(0.08, min(0.5, 0.30 * (1 - share) / 0.5))
        decisionTimer = random.range(0.9, 1.8)
        if random.next() < tackle,
           let thief = nearestPlayer(to: carrier.pos, home: !carrier.home, outfieldOnly: true) {
            mode = .carried(thief)
            carrierID = thief
            possessionHome = !carrier.home
            decisionTimer = random.range(0.8, 1.4)
            return
        }
        let dir = carrier.home ? 1.0 : -1.0
        let attackBias = carrier.home ? max(0, input.pressure) : max(0, -input.pressure)
        var options: [(Int, Double)] = []
        for mate in bodies where mate.home == carrier.home && mate.id != carrier.id {
            let distance = mate.pos.distance(to: carrier.pos)
            guard distance > 5, distance < 34 else { continue }
            let forward = (mate.pos.x - carrier.pos.x) * dir
            var weight = exp(-pow(distance - 15, 2) / 180)
            weight *= max(0.15, 1 + (forward / 25) * (0.6 + attackBias))
            if mate.keeper { weight *= distanceToOwnGoal(carrier) < 25 ? 0.5 : 0.04 }
            let nearestRival = bodies.filter { $0.home != carrier.home }.map { $0.pos.distance(to: mate.pos) }.min() ?? 10
            weight *= min(1.4, 0.5 + nearestRival / 10)
            options.append((mate.id, max(0.02, weight)))
        }
        guard !options.isEmpty else { return }
        var pick = random.next() * options.reduce(0) { $0 + $1.1 }
        var chosen = options[0].0
        for option in options {
            pick -= option.1
            if pick <= 0 { chosen = option.0; break }
        }
        startPass(from: ballPos, targetID: chosen, long: false)
    }

    private func distanceToOwnGoal(_ body: PitchBody) -> Double {
        body.pos.distance(to: PitchVector(body.home ? 0 : Self.length, Self.width / 2))
    }

    private func nearestPlayer(to point: PitchVector, home: Bool?, outfieldOnly: Bool) -> Int? {
        bodies.filter { (home == nil || $0.home == home) && (!outfieldOnly || !$0.keeper) }
            .min { $0.pos.distance(to: point) < $1.pos.distance(to: point) }?.id
    }

    // MARK: Reinício

    private func kickoffSpot(_ body: PitchBody, homeKicks: Bool) -> PitchVector {
        var depth = min(0.46, body.depth * 0.8)
        if body.keeper { depth = body.depth }
        let kicker = body.depth >= 0.6 && abs(body.lateral - 0.5) < 0.2 && body.home == homeKicks
        if kicker { return PitchVector(Self.length / 2 + (body.home ? -0.8 : 0.8), Self.width / 2) }
        let fraction = body.home ? depth : 1 - depth
        return PitchVector(fraction * Self.length, body.lateral * Self.width)
    }

    private func startKickoff(homeKicks: Bool) {
        mode = .restart
        carrierID = nil
        restartHome = homeKicks
        restartTimer = 1.6
        ballVel = .zero
        trail = []
    }

    private func beginPlayAfterRestart() {
        let candidates = bodies.filter { $0.home == restartHome && !$0.keeper }
        guard let kicker = candidates.max(by: { $0.depth < $1.depth }) else { return }
        mode = .carried(kicker.id)
        carrierID = kicker.id
        possessionHome = restartHome
        ballPos = PitchVector(Self.length / 2, Self.width / 2)
        decisionTimer = 0.8
    }

    // MARK: Jogadores

    private func formationTarget(_ body: PitchBody) -> PitchVector {
        let length = Self.length
        let width = Self.width
        if body.keeper {
            let goal = PitchVector(body.home ? 0 : length, width / 2)
            let proximity = max(0, min(1, 1 - ballPos.distance(to: goal) / 45))
            let dir = body.home ? 1.0 : -1.0
            let x = goal.x + dir * (2.0 + 6.0 * (1 - proximity))
            return PitchVector(x, width / 2 + max(-4, min(4, (ballPos.y - width / 2) * 0.22)))
        }
        let hasBall = body.home == possessionHome
        var depth = body.depth
        let ballFraction = ballPos.x / length
        let teamBall = body.home ? ballFraction : 1 - ballFraction
        depth += (teamBall - 0.5) * 0.34
        depth += hasBall ? (0.04 + (body.depth > 0.5 ? 0.07 : 0)) : -0.03
        depth = max(0.04, min(0.95, depth))
        let fraction = body.home ? depth : 1 - depth
        var y = body.lateral * width
        y += (ballPos.y - y) * (hasBall ? 0.18 : 0.30)
        let wobble = PitchVector(sin(time * 0.9 + Double(body.id)) * 0.8, cos(time * 0.7 + Double(body.id) * 1.3) * 0.8)
        return PitchVector(max(1, min(length - 1, fraction * length + wobble.x)), max(2, min(width - 2, y + wobble.y)))
    }

    private func updatePlayers(_ dt: Double) {
        let length = Self.length
        let width = Self.width
        let chasers = Set(chaserIDs())
        let supporter = supporterID()
        for i in bodies.indices {
            var body = bodies[i]
            if time < body.diveUntil {
                body.pos = body.pos + body.vel * dt
                body.vel = body.vel * max(0, 1 - 1.6 * dt)
                bodies[i] = body
                continue
            }
            var target = formationTarget(body)
            var topSpeed = 5.0
            if restartTimer > 0 {
                target = kickoffSpot(body, homeKicks: restartHome)
                topSpeed = 9
            } else if let celebrating = celebratingHome {
                if body.id == celebrationScorer {
                    target = PitchVector(celebrating ? length - 3 : 3, body.pos.y < width / 2 ? 4 : width - 4)
                    topSpeed = 7.5
                } else if body.home == celebrating, !body.keeper, let scorer = self.body(celebrationScorer),
                          scorer.pos.distance(to: body.pos) < 45 {
                    target = scorer.pos + PitchVector(Double(body.id % 5) - 2, Double(body.id % 3) - 1)
                    topSpeed = 7.0
                } else {
                    target = body.pos
                }
            } else if let current = plan, current.shooterID == body.id, current.spotSet {
                target = current.spot
                topSpeed = 8.5
            } else if carrierID == body.id {
                let dir = body.home ? 1.0 : -1.0
                let goalX = body.home ? length : 0
                var driftY = body.pos.y
                if abs(goalX - body.pos.x) < 35 { driftY = width / 2 + (body.pos.y - width / 2) * 0.6 }
                target = PitchVector(max(3, min(length - 3, body.pos.x + dir * 10)), driftY)
                if body.keeper { target = body.pos }
                topSpeed = 5.8
            } else if case .pass(_, let to, _, _, _, let receiver) = mode, receiver == body.id {
                target = to
                topSpeed = 7
            } else if chasers.contains(body.id) {
                target = ballPos
                topSpeed = 7.6
            } else if supporter == body.id, let carrier = carrierID.flatMap({ self.body($0) }) {
                let dir = body.home ? 1.0 : -1.0
                target = carrier.pos + PitchVector(dir * 7, body.pos.y < carrier.pos.y ? -8 : 8)
                topSpeed = 6.2
            }
            let toTarget = target - body.pos
            let distance = toTarget.length
            let speed = min(topSpeed, distance * 1.8)
            let desired = toTarget.normalized * speed
            body.vel = body.vel + (desired - body.vel) * min(1, 4.5 * dt)
            body.pos = body.pos + body.vel * dt
            if abs(body.vel.x) > 0.4 { body.facing = body.vel.x > 0 ? 1 : -1 }
            body.stride += body.vel.length * dt * 1.6
            bodies[i] = body
        }
        // Separação: ninguém atravessa o outro.
        for a in bodies.indices {
            for b in bodies.indices where b > a {
                let delta = bodies[a].pos - bodies[b].pos
                let distance = delta.length
                guard distance < 2.0, distance > 0.001 else { continue }
                let push = delta.normalized * ((2.0 - distance) * 0.5)
                bodies[a].pos = bodies[a].pos + push
                bodies[b].pos = bodies[b].pos - push
            }
            bodies[a].pos.x = min(length + 2, max(-2, bodies[a].pos.x))
            bodies[a].pos.y = min(width + 2, max(-2, bodies[a].pos.y))
        }
    }

    /// Os dois marcadores mais próximos da bola correm para pressionar.
    private func chaserIDs() -> [Int] {
        guard celebratingHome == nil, restartTimer <= 0 else { return [] }
        return bodies.filter { $0.home != possessionHome && !$0.keeper }
            .sorted { $0.pos.distance(to: ballPos) < $1.pos.distance(to: ballPos) }
            .prefix(2).map(\.id)
    }

    /// Um companheiro se oferece perto de quem conduz a bola.
    private func supporterID() -> Int? {
        guard let carrier = carrierID, let carrierBody = body(carrier) else { return nil }
        return bodies.filter { $0.home == carrierBody.home && $0.id != carrier && !$0.keeper }
            .min { $0.pos.distance(to: carrierBody.pos) < $1.pos.distance(to: carrierBody.pos) }?.id
    }

    private func updateReferee(_ dt: Double) {
        let side = ballPos.y < Self.width / 2 ? 11.0 : -11.0
        let target = PitchVector(ballPos.x - 6, max(4, min(Self.width - 4, ballPos.y + side)))
        referee = referee + (target - referee) * min(1, 1.1 * dt)
    }
}
