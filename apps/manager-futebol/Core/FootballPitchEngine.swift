import Foundation

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

    mutating func chance(_ probability: Double) -> Bool { next() < probability }

    /// Erro aproximadamente normal, com desvio 1 (soma de três sorteios).
    mutating func gauss() -> Double { (next() + next() + next() - 1.5) * 2 }
}

// MARK: - Ritmo do relógio

/// Quanto tempo de campo vale cada minuto da partida. O relógio anda pelo próprio campo, não por um temporizador solto:
/// a 2× ou 4× o campo corre mais rápido e os minutos passam na mesma proporção.
enum FootballPitchPacing {
    /// Segundos de jogo no campo (a 1×) para cada minuto da partida.
    static let secondsPerMinute = 2.5

    static func realSecondsPerMinute(speed: Int) -> Double { secondsPerMinute / Double(max(1, speed)) }
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

/// Em que momento da partida o campo está: bola rolando, intervalo ou apito final.
enum PitchPhase: Equatable {
    case live, halftime, fullTime
}

struct PitchInput {
    var slots: [PitchSlotInfo]
    var homeShare: Double
    var pressure: Double
    var events: [MatchEvent]
    var homeTeamID: Int
    var finished: Bool
    var phase: PitchPhase = .live
}

/// Postura do atleta: o que o desenho do boneco precisa mostrar além da corrida.
enum PitchPose: Equatable {
    case none
    /// Bola acima da cabeça, de frente para o campo.
    case throwIn
}

/// Jogadas paradas que o campo mostra.
enum PitchRestartKind: String, Equatable {
    case kickoff, throwIn, goalKick, corner, freeKick

    var label: String {
        switch self {
        case .kickoff: return "Saída de bola"
        case .throwIn: return "Lateral"
        case .goalKick: return "Tiro de meta"
        case .corner: return "Escanteio"
        case .freeKick: return "Falta"
        }
    }
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
    /// Fôlego e arranque de cada atleta: de 0,93 a 1,06 sobre a velocidade da posição.
    var pace = 1.0
    var pose = PitchPose.none
}

struct PitchCardMark {
    var pos: PitchVector
    var red: Bool
    var until: Double
}

/// Contadores do que aconteceu no campo (para o texto "Lateral", para os testes e para conferir a calibragem).
struct PitchStats: Equatable {
    var passes = 0
    var interceptions = 0
    var tackles = 0
    var clearances = 0
    var crosses = 0
    var throwIns = 0
    var goalKicks = 0
    var corners = 0
    var freeKicks = 0
    var homePossessionSeconds = 0.0
    var awayPossessionSeconds = 0.0
}

// MARK: - Motor físico do campo

/// Simulação visual: jogadores com inércia e limite de arranque, bola com posse, passes com desaceleração, bola fora
/// (lateral, tiro de meta, escanteio), faltas com barreira, arremates e goleiro.
/// Segue o placar real da partida: gols, defesas, chances e escanteios viram jogadas completas.
final class PitchEngine {
    static let length = 105.0
    static let width = 68.0
    private static let goalHalf = 3.66

    /// Voo da bola entre dois jogadores (passe, lançamento, cruzamento, arremesso lateral).
    private struct Flight {
        var from: PitchVector
        var to: PitchVector
        /// Onde o companheiro acha que vai receber (o passe pode sair errado e a bola chegar em outro lugar).
        var intended: PitchVector
        var elapsed = 0.0
        var duration: Double
        var apex: Double
        var startZ: Double
        var targetID: Int
        var passerHome: Bool
        var aerial: Bool
        /// Cobrança longa ou de bola parada: a bola é disputada na chegada.
        var contested: Bool
        /// Passe do roteiro (gol, defesa): sempre chega e ninguém corta.
        var scripted: Bool
        var checked: Set<Int> = []
    }

    private enum BallMode {
        case carried(Int)
        case pass(Flight)
        case shot
        case loose(Double)
        case net
        case restart
        /// Bola parada numa cobrança: o jogo só recomeça quando o cobrador chega e apita.
        case placed
    }

    private enum Outcome { case goal, save, miss, post, stoppage, corner }
    private enum Phase { case approach, flight }

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
        /// Posição do lance contada na súmula (fração do comprimento até o gol e da largura), quando existir.
        var eventX: Double?
        var eventY: Double?
        /// A súmula conta um escanteio logo depois deste chute: a bola sai pela linha de fundo tocada pela defesa.
        var cornerFollows = false

        var cornerEligible: Bool { outcome == .miss || outcome == .save }
    }

    private struct SetPiece {
        var kind: PitchRestartKind
        var home: Bool
        var spot: PitchVector
        var takerID: Int
        var elapsed = 0.0
        var minWait: Double
        /// Veio da súmula (escanteio ou falta contados): o relógio espera a cobrança terminar.
        var scripted: Bool
        /// Instante (contado desde o início da jogada parada) em que o cobrador chegou à bola.
        var arrivedAt: Double?
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
    /// Câmera: 1 = campo inteiro; sobe nos lances (chute, comemoração, bola parada) e acompanha a bola.
    private(set) var cameraZoom = 1.0
    private(set) var cameraCenter = PitchVector(52.5, 34)
    private(set) var stats = PitchStats()
    /// Nome da jogada parada em andamento ("Lateral", "Escanteio"…), por alguns segundos; o desenho mostra na tela.
    private(set) var restartLabel: String?
    private(set) var restartLabelHome = true
    /// Jogada parada em andamento, para quem desenha e para os testes.
    var currentRestart: PitchRestartKind? { setPiece?.kind }
    /// Segundos de jogo do campo que ainda não viraram minuto de partida.
    private(set) var clockSeconds = 0.0

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
    private var shootoutKicks = 0
    private var lastPhase = PitchPhase.live
    private var breakSettled = false
    private var settleTimer = 0.0
    private var lastAdvanceWall: Date?
    private var random = PitchRandom(seed: 0xC0FFEE)
    private var input = PitchInput(slots: [], homeShare: 0.5, pressure: 0, events: [], homeTeamID: -1, finished: false)

    private var lastTouchHome = true
    private var setPiece: SetPiece?
    private var setPieceSlots: [Int: PitchVector] = [:]
    private var scriptedCornerUntil = 0.0
    private var restartLabelUntil = 0.0
    /// O desvio do escanteio da súmula pode passar pela boca do gol: nesse caso a bola ainda sai (não vira "gol" nem fica com o goleiro).
    private var bypassGuardOnce = false
    /// Enquanto o desvio do escanteio da súmula rola, a bola não perde velocidade nem é recolhida: ela precisa sair pela linha de fundo.
    private var deflectOutUntil = 0.0

    private var warmed = false
    private var warmClock = 0.0

    var isWarmed: Bool { warmed }

    /// Só para capturas de tela: adianta a animação para o print mostrar o jogo em andamento (ou o gol sendo comemorado).
    func warmUpForCapture(input base: PitchInput) {
        warmed = true
        var before = base
        let goalIndex = base.events.lastIndex { $0.kind == .goal }
        if let goalIndex { before.events = Array(base.events[..<goalIndex]) }
        // No intervalo o campo precisa de mais tempo para os jogadores chegarem aos bancos.
        run(before, seconds: base.phase == .live ? 14 : 30, stopWhenCelebrating: false)
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
    func isBusy(eventCount: Int, phase: PitchPhase = .live) -> Bool {
        // Mudança de fase ainda não aplicada (intervalo/apito): o campo precisa redesenhar uma vez para reagir.
        if phase != lastPhase { return true }
        if input.phase == .halftime { return !breakSettled }
        if input.phase == .fullTime { return settleTimer > 0 }
        return plan != nil || !queue.isEmpty || celebratingHome != nil || restartTimer > 0 || setPiece != nil || consumed != eventCount
    }

    /// Há uma jogada roteirizada (gol, defesa, escanteio, falta…) ainda sendo mostrada. O relógio da partida espera por ela
    /// para a narração e o campo contarem a mesma história. Lateral e tiro de meta comuns não seguram o relógio.
    func isShowingPlay(eventCount: Int) -> Bool {
        input.phase == .live && holdsClock(eventCount: eventCount)
    }

    private func holdsClock(eventCount: Int) -> Bool {
        plan != nil || !queue.isEmpty || celebratingHome != nil || restartTimer > 0 || (setPiece?.scripted ?? false)
            || time < scriptedCornerUntil || consumed != eventCount
    }

    /// O campo está sendo desenhado agora (a tela está visível); senão não há o que esperar.
    var isAnimating: Bool {
        guard let last = lastAdvanceWall else { return false }
        return Date().timeIntervalSince(last) < 0.6
    }

    /// Entrega um minuto de partida quando o campo já jogou `seconds` segundos livres. Jogadas roteirizadas seguram o relógio.
    func consumeMinute(seconds: Double, eventCount: Int) -> Bool {
        guard input.phase == .live, !holdsClock(eventCount: eventCount), clockSeconds >= seconds else { return false }
        clockSeconds -= seconds
        return true
    }

    func body(_ id: Int) -> PitchBody? { bodies.first { $0.id == id } }

    private func index(of id: Int) -> Int? { bodies.firstIndex { $0.id == id } }

    // MARK: Avanço

    /// `speed` é o multiplicador real do tempo (1, 2 ou 4): a física roda em passos pequenos e fixos, então a 4× nada atravessa nada.
    func advance(now: Double, speed: Double, input newInput: PitchInput) {
        let elapsed = lastTime.map { now - $0 } ?? 0
        lastTime = now
        lastAdvanceWall = Date()
        input = newInput
        sync()
        applyPhaseChange()
        processEvents()
        let scaled = min(0.1, max(0, elapsed)) * max(0.5, speed)
        let steps = max(1, Int((scaled / 0.025).rounded(.up)))
        for _ in 0..<steps { step(scaled / Double(steps)) }
    }

    // MARK: Câmera

    private func updateCamera(_ dt: Double) {
        var targetZoom = 1.0
        var focus = ballPos
        if let current = plan {
            targetZoom = current.phase == .approach ? 1.3 : 1.6
        } else if celebratingHome != nil {
            targetZoom = 1.3
            if let scorer = body(celebrationScorer) { focus = scorer.pos }
        } else if let piece = setPiece {
            switch piece.kind {
            case .corner:
                targetZoom = 1.5
                let goal = PitchVector(piece.spot.x < Self.length / 2 ? 0 : Self.length, Self.width / 2)
                focus = PitchVector(piece.spot.x * 0.55 + goal.x * 0.45, piece.spot.y * 0.5 + goal.y * 0.5)
            case .throwIn:
                targetZoom = 1.3
            case .goalKick:
                targetZoom = 1.15
            case .freeKick, .kickoff:
                targetZoom = 1.25
            }
        }
        let follow = min(1, 2.4 * dt)
        cameraZoom += (targetZoom - cameraZoom) * follow
        cameraCenter = cameraCenter + (focus - cameraCenter) * follow
    }

    private func relaxCamera(_ dt: Double) {
        let follow = min(1, 2.0 * dt)
        cameraZoom += (1.0 - cameraZoom) * follow
        cameraCenter = cameraCenter + (PitchVector(Self.length / 2, Self.width / 2) - cameraCenter) * follow
    }

    // MARK: Intervalo e apito final

    /// Dois centros de arremesso: o time da casa vai ao banco da esquerda e o visitante ao da direita.
    private func dugoutSpot(_ body: PitchBody) -> PitchVector {
        let side = body.home ? -1.0 : 1.0
        let spread = Double(abs(body.id) % 7) - 3
        return PitchVector(Self.length / 2 + side * 21 + spread * 1.6, Self.width + 4.2 + Double(abs(body.id) % 3) * 0.3)
    }

    private func clearSetPiece() {
        setPiece = nil
        setPieceSlots = [:]
        for i in bodies.indices { bodies[i].pose = .none }
    }

    private func applyPhaseChange() {
        guard input.phase != lastPhase else { return }
        let previous = lastPhase
        lastPhase = input.phase
        plan = nil
        queue = []
        celebratingHome = nil
        clearSetPiece()
        scriptedCornerUntil = 0
        trail = []
        restartLabel = nil
        switch input.phase {
        case .halftime:
            breakSettled = false
            mode = .restart
            carrierID = nil
            ballVel = .zero
            restartTimer = 0
        case .fullTime:
            restartTimer = 0
            settleTimer = 1.4
            if case .restart = mode { mode = .loose(0) }
            if case .placed = mode { mode = .loose(0) }
        case .live:
            // Segundo tempo: os jogadores voltam do intervalo e o visitante dá a saída.
            if previous == .halftime { startKickoff(homeKicks: false, walkBack: true) }
        }
    }

    /// Todo mundo vai para o vestiário/banco e fica parado: a bola não anda enquanto o jogo está parado.
    private func stepHalftime(_ dt: Double) {
        time += dt
        relaxCamera(dt)
        ballPos = PitchVector(Self.length / 2, Self.width / 2)
        ballZ = 0
        var allThere = true
        for i in bodies.indices {
            var body = bodies[i]
            let target = dugoutSpot(body)
            let toTarget = target - body.pos
            let distance = toTarget.length
            if distance > 0.6 {
                allThere = false
                let desired = toTarget.normalized * min(2.6, distance * 1.4)
                body.vel = body.vel + (desired - body.vel) * min(1, 3.5 * dt)
                body.pos = body.pos + body.vel * dt
                if abs(body.vel.x) > 0.3 { body.facing = body.vel.x > 0 ? 1 : -1 }
                body.stride += body.vel.length * dt * 1.6
            } else {
                body.vel = .zero
            }
            bodies[i] = body
        }
        breakSettled = allThere
        let tunnel = PitchVector(Self.length / 2, Self.width + 3.5)
        referee = referee + (tunnel - referee) * min(1, 0.8 * dt)
    }

    /// Apito final: o jogo para onde está; ninguém corre atrás da bola.
    private func stepFullTime(_ dt: Double) {
        time += dt
        relaxCamera(dt)
        settleTimer = max(0, settleTimer - dt)
        for i in bodies.indices {
            bodies[i].vel = bodies[i].vel * max(0, 1 - 3.2 * dt)
            bodies[i].pos = bodies[i].pos + bodies[i].vel * dt
        }
        ballPos = ballPos + ballVel * dt
        ballVel = ballVel * max(0, 1 - 3 * dt)
        ballZ = max(0, ballZ - 3 * dt)
    }

    // MARK: Sincronia com a partida

    private static func pace(for slot: PitchSlotInfo) -> Double {
        let hash = Double((UInt64(bitPattern: Int64(slot.id)) &* 2_654_435_761) % 1000) / 1000
        let position: Double
        if slot.keeper { position = 0.85 } else if slot.depth < 0.3 { position = 0.97 } else if slot.depth < 0.55 { position = 1.0 } else { position = 1.04 }
        return position * (0.94 + 0.10 * hash)
    }

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
                body.pace = Self.pace(for: slot)
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
        // Disputa de pênaltis: todas as cobranças entram na fila, uma a uma, sem os limites do jogo corrido.
        if input.phase == .live, fresh.contains(where: { $0.kind == .penalties }) {
            for event in fresh where event.kind == .penalties {
                let text = event.text
                let outcome: Outcome = text.contains("convertido") ? .goal : (text.contains("defende") ? .save : .miss)
                queue.append(Plan(home: event.teamID == input.homeTeamID, shooterID: -1, outcome: outcome, penalty: true))
            }
            return
        }
        if input.finished || input.phase != .live {
            plan = nil
            queue = []
            return
        }
        if fresh.count > 6 {
            plan = nil
            queue = []
            celebratingHome = nil
            clearSetPiece()
            scriptedCornerUntil = 0
            startKickoff(homeKicks: possessionHome)
            return
        }
        for event in fresh {
            let isHome = event.teamID == input.homeTeamID
            switch event.kind {
            case .goal:
                if queue.count < 5 { queue.append(shotPlan(event, home: isHome, outcome: .goal)) }
            case .save:
                if queue.count < 5 { queue.append(shotPlan(event, home: isHome, outcome: .save)) }
            case .woodwork:
                if event.x != nil, queue.count < 5 { queue.append(shotPlan(event, home: isHome, outcome: .post)) }
            case .chance:
                if event.x != nil, queue.count < 5 { queue.append(shotPlan(event, home: isHome, outcome: .miss)) }
            case .corner:
                attachCorner(event, home: isHome)
            case .yellowCard, .redCard:
                if let id = event.playerID, let i = index(of: id) {
                    cardMarks.append(PitchCardMark(pos: bodies[i].pos, red: event.kind == .redCard, until: time + 3.2))
                }
                if queue.count < 5 { queue.append(stoppagePlan(offenderHome: isHome)) }
            case .substitution:
                // Troca: o jogo para um instante e o time que mexeu continua com a bola.
                if queue.count < 5 { queue.append(stoppagePlan(offenderHome: !isHome)) }
            case .injury, .offside:
                if queue.count < 5 { queue.append(stoppagePlan(offenderHome: isHome)) }
            default:
                break
            }
        }
    }

    private func shotPlan(_ event: MatchEvent, home: Bool, outcome: Outcome) -> Plan {
        var plan = Plan(home: home, shooterID: event.playerID ?? -1, outcome: outcome, penalty: event.text.contains("pênalti"))
        plan.eventX = event.x
        plan.eventY = event.y
        return plan
    }

    /// Falta, cartão, lesão ou impedimento: o time do infrator perde a bola e o rival cobra.
    private func stoppagePlan(offenderHome: Bool) -> Plan {
        Plan(home: !offenderHome, shooterID: -1, outcome: .stoppage, penalty: false)
    }

    /// O escanteio da súmula costuma vir logo depois do chute que a defesa desviou: a mesma jogada termina na linha de fundo.
    /// Sem chute antes (bola desviada que a súmula não mostrou), o campo cobra o escanteio por conta própria.
    private func attachCorner(_ event: MatchEvent, home: Bool) {
        if var current = plan, current.home == home, current.cornerEligible, !current.resolved, !current.cornerFollows {
            current.cornerFollows = true
            plan = current
            return
        }
        if let last = queue.indices.last, queue[last].home == home, queue[last].cornerEligible, !queue[last].cornerFollows {
            queue[last].cornerFollows = true
            return
        }
        if queue.count < 6 {
            queue.append(Plan(home: home, shooterID: event.playerID ?? -1, outcome: .corner, penalty: false))
        }
    }

    // MARK: Passo de simulação

    private func step(_ dt: Double) {
        guard dt > 0 else { return }
        switch input.phase {
        case .halftime:
            stepHalftime(dt)
            return
        case .fullTime:
            stepFullTime(dt)
            return
        case .live:
            break
        }
        time += dt
        cardMarks.removeAll { $0.until < time }
        if restartLabel != nil, time > restartLabelUntil { restartLabel = nil }
        if celebratingHome != nil, time > celebrationUntil {
            celebratingHome = nil
            startKickoff(homeKicks: restartHome)
        }
        if restartTimer > 0 {
            restartTimer -= dt
            if restartTimer <= 0 { beginPlayAfterRestart() }
        }
        if plan == nil, !queue.isEmpty, celebratingHome == nil, restartTimer <= 0, setPiece == nil, time >= scriptedCornerUntil, !input.finished {
            let next = queue.removeFirst()
            switch next.outcome {
            case .stoppage: beginStoppage(next)
            case .corner: beginStandaloneCorner(next)
            default: beginPlan(next)
            }
        }
        updateBall(dt)
        updateSetPiece(dt)
        updatePlayers(dt)
        updateReferee(dt)
        updateCamera(dt)
        if abs(ballVel.x) + abs(ballVel.y) > 12 {
            trail.append(ballPos)
            if trail.count > 7 { trail.removeFirst() }
        } else if !trail.isEmpty {
            trail.removeFirst()
        }
        if setPiece == nil, restartTimer <= 0 {
            if possessionHome { stats.homePossessionSeconds += dt } else { stats.awayPossessionSeconds += dt }
        }
        if !holdsClock(eventCount: input.events.count) { clockSeconds = min(clockSeconds + dt, FootballPitchPacing.secondsPerMinute * 3) }
    }

    // MARK: Jogadas roteirizadas (gol, defesa, chance)

    private func beginPlan(_ new: Plan) {
        var next = new
        let candidates = bodies.filter { $0.home == next.home && !$0.keeper }
        let chosen: PitchBody?
        if next.shooterID == -1, next.penalty {
            // Pênaltis da disputa: cada cobrança sai de um atleta diferente, dos mais avançados para os mais recuados.
            let ordered = candidates.sorted { $0.depth != $1.depth ? $0.depth > $1.depth : $0.id < $1.id }
            shootoutKicks += 1
            chosen = ordered.isEmpty ? nil : ordered[((shootoutKicks - 1) / 2) % ordered.count]
        } else {
            chosen = candidates.first { $0.id == next.shooterID } ?? candidates.max { $0.depth < $1.depth }
        }
        guard let shooter = chosen else { return }
        next.shooterID = shooter.id
        next.side = random.next() < 0.5 ? -1 : 1
        let dir = next.home ? 1.0 : -1.0
        let goalX = next.home ? Self.length : 0
        if next.penalty {
            next.spot = PitchVector(goalX - dir * 11, Self.width / 2)
        } else if let eventX = next.eventX {
            // A súmula diz de onde saiu o chute: o jogador chega lá antes de finalizar.
            let distance = max(7, min(40, eventX * Self.length))
            let lateral = (next.eventY ?? 0.5) * Self.width
            next.spot = PitchVector(goalX - dir * distance, max(6, min(Self.width - 6, lateral)))
        } else {
            next.spot = PitchVector(goalX - dir * random.range(11, 23), Self.width / 2 + random.range(-9, 9))
        }
        next.spotSet = true
        plan = next
        possessionHome = next.home
        if carrierID != shooter.id {
            startPass(from: ballPos, targetID: shooter.id, scripted: true)
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
        lastTouchHome = shooter.home
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
        case .post:
            // Na trave: ou no poste, ou no travessão (2,44 m).
            if random.next() < 0.6 {
                targetY = goalY + next.side * Self.goalHalf
                targetZ = random.range(0.6, 1.7)
            } else {
                targetY = goalY + next.side * random.range(0.5, 2.5)
                targetZ = 2.4
            }
        case .stoppage, .corner:
            break
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
            case .post: reach = -next.side * 0.6
            case .stoppage, .corner: reach = 0
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
            if current.cornerFollows {
                // Desvio por cima da linha de fundo: a súmula conta escanteio.
                deflectForCorner(dir: dir, side: current.side, defendingHome: !current.home)
                plan = nil
            } else if random.next() < 0.5 {
                catchBall(keeper.id, defendingHome: !current.home)
                plan = nil
            } else {
                ballVel = PitchVector(-dir * 7, current.side * 7)
                ballVZ = 3.5
                lastTouchHome = !current.home
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
                if current.cornerFollows {
                    deflectForCorner(dir: dir, side: current.side, defendingHome: !current.home)
                } else {
                    catchBall(keeper?.id ?? -1, defendingHome: !current.home)
                }
                plan = nil
            case .miss:
                // Bola para fora: tiro de meta, ou escanteio quando a súmula conta que a defesa desviou.
                plan = nil
                carrierID = nil
                ballVel = .zero
                ballPos = PitchVector(goalX + dir * 0.3, ballPos.y)
                ballZ = 0
                if current.cornerFollows {
                    scriptedCornerUntil = time + 4
                    lastTouchHome = !current.home
                } else {
                    lastTouchHome = current.home
                }
                handleOut(bypassGoalGuard: true)
            case .post:
                // Bate e volta: a bola sai quicando para a frente da área.
                ballVel = PitchVector(-dir * 9, current.side * 4.5)
                ballVZ = 3.2
                lastTouchHome = !current.home
                mode = .loose(1.6)
                carrierID = nil
                plan = nil
            case .stoppage, .corner:
                plan = nil
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

    /// A defesa toca na bola e ela sai pela linha de fundo: o escanteio da súmula.
    private func deflectForCorner(dir: Double, side: Double, defendingHome: Bool) {
        ballVel = PitchVector(dir * 9, side * 3.5)
        ballVZ = 3.0
        deflectOutUntil = time + 2.5
        lastTouchHome = defendingHome
        scriptedCornerUntil = time + 4
        bypassGuardOnce = true
        mode = .loose(3)
        carrierID = nil
    }

    private func catchBall(_ keeperID: Int, defendingHome: Bool) {
        if let i = index(of: keeperID) {
            mode = .carried(keeperID)
            carrierID = keeperID
            possessionHome = defendingHome
            lastTouchHome = defendingHome
            ballPos = bodies[i].pos
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
            }
            return
        }
        switch mode {
        case .carried(let id):
            guard let i = index(of: id) else { return }
            let body = bodies[i]
            // Condução: a bola é tocada à frente na direção da corrida e a cada passo volta para perto do pé.
            let heading = body.vel.length > 0.8 ? body.vel.normalized : PitchVector(body.facing, 0)
            let touch = 0.5 + 0.9 * max(0, sin(time * 5.2 + Double(id)))
            let desired = body.pos + heading * touch
            ballPos = ballPos + (desired - ballPos) * min(1, 12 * dt)
            ballZ = abs(sin(time * 8 + Double(id))) * 0.16
            carrierID = id
            possessionHome = body.home
            lastTouchHome = body.home
            decisionTimer -= dt
            if decisionTimer <= 0, restartTimer <= 0, !input.finished { decide(carrier: i) }
        case .pass(let flight):
            advanceFlight(flight, dt)
        case .loose(let remaining):
            let deflecting = time < deflectOutUntil
            ballPos = ballPos + ballVel * dt
            if !deflecting { ballVel = ballVel * max(0, 1 - 1.5 * dt) }
            ballVZ -= 9.8 * dt
            ballZ += ballVZ * dt
            if ballZ < 0 { ballZ = 0; ballVZ = abs(ballVZ) * 0.35 }
            if deflecting, !isOutside(ballPos) {
                mode = .loose(remaining)
                break
            }
            if isOutside(ballPos) {
                deflectOutUntil = 0
                let bypass = bypassGuardOnce
                bypassGuardOnce = false
                handleOut(bypassGoalGuard: bypass)
                break
            }
            if let nearest = nearestPlayer(to: ballPos, home: nil, outfieldOnly: false),
               let i = index(of: nearest), (bodies[i].pos.distance(to: ballPos) < 1.8 && ballZ < 1.6) || remaining <= 0 {
                mode = .carried(nearest)
                carrierID = nearest
                possessionHome = bodies[i].home
                lastTouchHome = bodies[i].home
                decisionTimer = random.range(0.5, 1.0)
            } else {
                mode = .loose(remaining - dt)
            }
        case .placed:
            break
        case .net:
            ballZ = max(0, ballZ - dt)
        case .restart:
            ballPos = PitchVector(Self.length / 2, Self.width / 2)
            ballZ = 0
        case .shot:
            mode = .loose(0.8)
        }
    }

    private func isOutside(_ point: PitchVector) -> Bool {
        point.x < 0 || point.x > Self.length || point.y < 0 || point.y > Self.width
    }

    // MARK: Bola fora

    /// A bola saiu: lateral pela linha lateral; pela linha de fundo, tiro de meta (atacante tocou por último) ou
    /// escanteio (defensor tocou por último). Bola que entraria no gol sem o roteiro da súmula fica com o goleiro.
    private func handleOut(bypassGoalGuard: Bool = false) {
        let length = Self.length
        let width = Self.width
        ballVel = .zero
        if ballPos.y < 0 || ballPos.y > width {
            let spot = PitchVector(min(length - 2, max(2, ballPos.x)), ballPos.y < 0 ? 0 : width)
            beginSetPiece(.throwIn, home: !lastTouchHome, spot: spot, scripted: false)
            return
        }
        let atHomeEnd = ballPos.x < 0
        let defendingHome = atHomeEnd
        let throughMouth = abs(ballPos.y - width / 2) < Self.goalHalf && ballZ < 2.44
        if throughMouth, !bypassGoalGuard,
           let keeper = bodies.first(where: { $0.keeper && $0.home == defendingHome }) {
            catchBall(keeper.id, defendingHome: defendingHome)
            return
        }
        if lastTouchHome == defendingHome {
            let spot = PitchVector(atHomeEnd ? 0.3 : length - 0.3, ballPos.y < width / 2 ? 0.3 : width - 0.3)
            let scripted = time < scriptedCornerUntil
            scriptedCornerUntil = 0
            beginSetPiece(.corner, home: !defendingHome, spot: spot, scripted: scripted)
        } else {
            let spot = PitchVector(atHomeEnd ? 5.5 : length - 5.5, width / 2 + (ballPos.y - width / 2) * 0.15)
            beginSetPiece(.goalKick, home: defendingHome, spot: spot, scripted: false)
        }
    }

    // MARK: Voo da bola

    private func groundProfile(_ elapsed: Double, duration: Double) -> Double {
        // Passe rasteiro: sai forte e perde velocidade no gramado (atrito), mas chega ao ponto no tempo combinado.
        let k = 0.55
        return (1 - exp(-k * elapsed)) / (1 - exp(-k * duration))
    }

    private func advanceFlight(_ start: Flight, _ dt: Double) {
        var f = start
        f.elapsed += dt
        let t = min(1, f.elapsed / f.duration)
        let p = f.aerial ? t : groundProfile(min(f.elapsed, f.duration), duration: f.duration)
        ballPos = f.from + (f.to - f.from) * p
        ballZ = f.aerial ? 4 * f.apex * t * (1 - t) + f.startZ * (1 - t) + 0.2 * t : 0.11
        if !f.scripted {
            if isOutside(ballPos) {
                lastTouchHome = f.passerHome
                handleOut()
                return
            }
            if intercept(&f) { return }
        }
        if t >= 1 {
            completeFlight(f)
        } else {
            mode = .pass(f)
        }
    }

    /// Adversário no caminho da bola: pode cortar o passe ou desviar.
    private func intercept(_ f: inout Flight) -> Bool {
        guard f.elapsed > 0.12 else { return false }
        for rival in bodies where rival.home != f.passerHome && !f.checked.contains(rival.id) {
            guard rival.pos.distance(to: ballPos) < 1.1, ballZ < 2.2 else { continue }
            f.checked.insert(rival.id)
            let chance = f.aerial ? (f.contested ? 0.0 : 0.22) : 0.5
            guard random.chance(chance) else { continue }
            stats.interceptions += 1
            lastTouchHome = rival.home
            if random.chance(0.7) {
                mode = .carried(rival.id)
                carrierID = rival.id
                possessionHome = rival.home
                decisionTimer = random.range(0.8, 1.3)
            } else {
                let angle = random.range(0, 2 * Double.pi)
                ballVel = PitchVector(cos(angle), sin(angle)) * 6
                ballVZ = 1.5
                possessionHome = rival.home
                mode = .loose(1.4)
                carrierID = nil
            }
            return true
        }
        return false
    }

    /// A bola chegou ao ponto do passe: quem estiver perto fica com ela. Passe errado vira bola solta.
    private func completeFlight(_ f: Flight) {
        if f.scripted {
            if index(of: f.targetID) != nil {
                mode = .carried(f.targetID)
                carrierID = f.targetID
                decisionTimer = random.range(0.7, 1.5)
            } else {
                mode = .loose(1)
            }
            return
        }
        let radius = f.contested ? 3.4 : 2.1
        let heading = (f.to - f.from).normalized
        var options: [(Int, Double)] = []
        for body in bodies {
            let d = body.pos.distance(to: ballPos)
            guard d < radius else { continue }
            var weight = 1 / (0.6 + d)
            if body.home == f.passerHome {
                weight *= body.id == f.targetID ? 2.6 : 1.1
            } else {
                weight *= f.contested ? 1.0 : 0.55
            }
            options.append((body.id, weight))
        }
        guard !options.isEmpty else {
            ballVel = heading * 3
            ballVZ = 0
            mode = .loose(1.6)
            carrierID = nil
            return
        }
        var pick = random.next() * options.reduce(0) { $0 + $1.1 }
        var winner = options[0].0
        for option in options {
            pick -= option.1
            if pick <= 0 { winner = option.0; break }
        }
        guard let i = index(of: winner) else { mode = .loose(1); return }
        if bodies[i].home != f.passerHome {
            stats.interceptions += 1
            if f.contested, !bodies[i].keeper { stats.clearances += 1 }
        }
        lastTouchHome = bodies[i].home
        possessionHome = bodies[i].home
        if f.contested, bodies[i].home != f.passerHome, !bodies[i].keeper, random.chance(0.6) {
            clear(from: i)
            return
        }
        mode = .carried(winner)
        carrierID = winner
        decisionTimer = random.range(0.5, 1.0)
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
        } else if case .pass(let flight) = mode {
            advanceFlight(flight, dt)
            if next.timer > 3.2 { forceCarrier(shooter.id) }
        } else if next.timer > 3.2 {
            forceCarrier(shooter.id)
        }
        plan = next
    }

    private func forceCarrier(_ id: Int) {
        mode = .carried(id)
        carrierID = id
        if let i = index(of: id) { ballPos = bodies[i].pos }
    }

    /// Passe de roteiro (leva a bola ao autor do chute da súmula): sempre chega.
    private func startPass(from origin: PitchVector, targetID: Int, scripted: Bool) {
        guard let i = index(of: targetID) else { return }
        let target = bodies[i]
        let distance0 = max(2, origin.distance(to: target.pos))
        let speed = 13 + distance0 * 0.3
        let duration = max(0.25, distance0 / speed)
        let aim = target.pos + target.vel * (duration * 0.8)
        startFlight(from: origin, aim: aim, intended: aim, receiver: targetID, aerial: distance0 > 22, speed: speed,
                    contested: false, passerHome: possessionHome, scripted: scripted)
    }

    private func startFlight(from origin: PitchVector, aim: PitchVector, intended: PitchVector, receiver: Int, aerial: Bool, speed: Double,
                             contested: Bool, passerHome: Bool, scripted: Bool = false, startZ: Double = 0.2) {
        let distance0 = max(2, origin.distance(to: aim))
        let duration = max(0.25, distance0 / speed)
        let apex = aerial ? min(9, 9.8 * duration * duration / 8) : 0
        mode = .pass(Flight(from: origin, to: aim, intended: intended, duration: duration, apex: apex, startZ: startZ, targetID: receiver,
                            passerHome: passerHome, aerial: aerial, contested: contested, scripted: scripted))
        carrierID = nil
        lastTouchHome = passerHome
        if !scripted { stats.passes += 1 }
    }

    // MARK: Decisões de quem está com a bola

    private func decide(carrier i: Int) {
        let carrier = bodies[i]
        let share = carrier.home ? input.homeShare : 1 - input.homeShare
        decisionTimer = random.range(0.6, 1.3)

        // Duelo: só há desarme com adversário colado. Metade das vezes a bola sobra para a disputa.
        let rivalClose = bodies.filter { $0.home != carrier.home && !$0.keeper && $0.pos.distance(to: carrier.pos) < 2.4 }
            .min { $0.pos.distance(to: carrier.pos) < $1.pos.distance(to: carrier.pos) }
        if let rival = rivalClose, !carrier.keeper {
            let tackle = max(0.1, min(0.8, 0.45 * (1 - share) / 0.5))
            if random.chance(tackle) {
                stats.tackles += 1
                lastTouchHome = rival.home
                possessionHome = rival.home
                if random.chance(0.55) {
                    mode = .carried(rival.id)
                    carrierID = rival.id
                    decisionTimer = random.range(0.5, 1.0)
                } else {
                    // Bola sobra na disputa; na beirada do campo ela tende a ir para a linha lateral.
                    let toLine = carrier.pos.y < Self.width / 2 ? -1.0 : 1.0
                    let nearLine = min(carrier.pos.y, Self.width - carrier.pos.y) < 9
                    if nearLine, random.chance(0.6) {
                        ballVel = PitchVector(random.range(-3, 3), toLine * random.range(6, 9))
                    } else {
                        let angle = random.range(0, 2 * Double.pi)
                        ballVel = PitchVector(cos(angle), sin(angle)) * 5
                    }
                    ballVZ = 1.4
                    mode = .loose(1.2)
                    carrierID = nil
                }
                return
            }
        }

        // Ponta no ataque pela beirada: levanta a bola na área.
        let wide = min(carrier.pos.y, Self.width - carrier.pos.y) < 11
        let advanced = carrier.home ? carrier.pos.x > Self.length * 0.62 : carrier.pos.x < Self.length * 0.38
        if wide, advanced, !carrier.keeper, random.chance(0.7), cross(from: i) { return }

        // Pressionado perto do próprio gol: bico para frente em vez de arriscar o passe.
        if let rival = rivalClose, !carrier.keeper, rival.pos.distance(to: carrier.pos) < 4.5 {
            let deep = distanceToOwnGoal(carrier) < 30
            if random.chance(deep ? 0.45 : (carrier.depth < 0.3 ? 0.25 : 0.06)) {
                clear(from: i)
                return
            }
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
        passTo(chosen, from: carrier, pressured: rivalClose != nil)
    }

    /// Passe de jogo corrido: sai com erro de precisão (maior com a distância e com adversário em cima) e pode ir para fora.
    private func passTo(_ targetID: Int, from carrier: PitchBody, pressured: Bool) {
        guard let i = index(of: targetID) else { return }
        let target = bodies[i]
        let distance0 = max(2, ballPos.distance(to: target.pos))
        let speed = 13 + distance0 * 0.3
        let duration = max(0.25, distance0 / speed)
        let intended = target.pos + target.vel * (duration * 0.8)
        // Imprecisão cresce com a distância, com marcação em cima e perto da linha lateral (pé na linha, toque mais forte).
        let lineGap = min(target.pos.y, Self.width - target.pos.y)
        let nearLine = lineGap < 6
        var sigma = 0.5 + 0.07 * distance0 + (pressured ? 0.9 : 0) + (nearLine ? 1.0 : 0)
        if random.chance(0.05 + distance0 / 500) { sigma += 3.8 }
        var aim = PitchVector(intended.x + random.gauss() * sigma, intended.y + random.gauss() * sigma)
        // Passe para quem joga colado na linha: o primeiro toque costuma ir um pouco para fora.
        if nearLine { aim.y += (target.pos.y < Self.width / 2 ? -1 : 1) * random.range(0, 3.0) }
        startFlight(from: ballPos, aim: aim, intended: intended, receiver: targetID, aerial: distance0 > 22, speed: speed,
                    contested: false, passerHome: carrier.home)
    }

    /// Cruzamento da beirada para um atacante dentro da área. Pode ser cortado, sair pela linha de fundo ou ser afastado para a lateral.
    private func cross(from i: Int) -> Bool {
        let carrier = bodies[i]
        let goal = PitchVector(carrier.home ? Self.length : 0, Self.width / 2)
        let targets = bodies.filter { $0.home == carrier.home && !$0.keeper && $0.id != carrier.id && $0.pos.distance(to: goal) < 20 }
        guard let target = targets.min(by: { $0.pos.distance(to: goal) < $1.pos.distance(to: goal) }) else { return false }
        let intended = target.pos + target.vel * 0.8
        let aim = PitchVector(intended.x + random.gauss() * 2.6, intended.y + random.gauss() * 2.6)
        stats.crosses += 1
        startFlight(from: ballPos, aim: aim, intended: intended, receiver: target.id, aerial: true, speed: 17, contested: true, passerHome: carrier.home)
        return true
    }

    /// Bico para frente: a bola vai alta para o campo de ataque, em geral para as laterais, e a disputa é na chegada.
    private func clear(from i: Int) {
        let carrier = bodies[i]
        let dir = carrier.home ? 1.0 : -1.0
        let side = random.chance(0.5) ? 1.0 : -1.0
        let distance = random.range(28, 46)
        let target = PitchVector(min(Self.length - 1, max(1, carrier.pos.x + dir * distance)),
                                 Self.width / 2 + side * random.range(14, 36))
        let aim = PitchVector(target.x + random.gauss() * 3.5, target.y + random.gauss() * 3.5)
        stats.clearances += 1
        let attackers = bodies.filter { $0.home == carrier.home && !$0.keeper && $0.id != carrier.id }
        let receiver = attackers.min { $0.pos.distance(to: target) < $1.pos.distance(to: target) }?.id ?? -1
        startFlight(from: ballPos, aim: aim, intended: target, receiver: receiver, aerial: true, speed: 21, contested: true, passerHome: carrier.home)
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

    private func startKickoff(homeKicks: Bool, walkBack: Bool = false) {
        clearSetPiece()
        restartLabel = nil
        mode = .restart
        carrierID = nil
        restartHome = homeKicks
        restartTimer = walkBack ? 5.0 : 1.6
        ballVel = .zero
        trail = []
    }

    private func beginPlayAfterRestart() {
        let candidates = bodies.filter { $0.home == restartHome && !$0.keeper }
        guard let kicker = candidates.max(by: { $0.depth < $1.depth }) else { return }
        mode = .carried(kicker.id)
        carrierID = kicker.id
        possessionHome = restartHome
        lastTouchHome = restartHome
        ballPos = PitchVector(Self.length / 2, Self.width / 2)
        decisionTimer = 0.8
    }

    // MARK: Jogadas paradas

    /// Falta, cartão, lesão ou impedimento da súmula: o rival cobra onde a bola está, com barreira quando perto da área.
    private func beginStoppage(_ stop: Plan) {
        // Falta dentro da área seria pênalti (a súmula conta à parte): a cobrança da jogada corrida nunca fica na linha de fundo.
        let spot = PitchVector(min(Self.length - 12, max(12, ballPos.x)), min(Self.width - 2, max(2, ballPos.y)))
        beginSetPiece(.freeKick, home: stop.home, spot: spot, scripted: true)
    }

    /// Escanteio da súmula sem chute antes: a bola vai ao canto do lado do ataque e a cobrança acontece.
    private func beginStandaloneCorner(_ corner: Plan) {
        let atHomeEnd = !corner.home
        let side = random.chance(0.5) ? 0.3 : Self.width - 0.3
        let spot = PitchVector(atHomeEnd ? 0.3 : Self.length - 0.3, side)
        beginSetPiece(.corner, home: corner.home, spot: spot, scripted: true, preferredTaker: corner.shooterID)
    }

    private func beginSetPiece(_ kind: PitchRestartKind, home: Bool, spot: PitchVector, scripted: Bool, preferredTaker: Int? = nil) {
        guard !input.finished, input.phase == .live else { mode = .loose(0.5); return }
        clearSetPiece()
        mode = .placed
        ballPos = spot
        ballVel = .zero
        ballZ = 0
        carrierID = nil
        trail = []
        possessionHome = home
        lastTouchHome = !home
        guard let taker = chooseTaker(kind, home: home, spot: spot, preferred: preferredTaker) else {
            mode = .loose(0.5)
            return
        }
        let wait: Double
        switch kind {
        case .throwIn: wait = 1.0
        case .goalKick: wait = 1.6
        case .corner: wait = 2.4
        case .freeKick: wait = 2.2
        case .kickoff: wait = 1.0
        }
        setPiece = SetPiece(kind: kind, home: home, spot: spot, takerID: taker, minWait: wait, scripted: scripted)
        assignSlots(kind, home: home, spot: spot, taker: taker)
        restartLabel = kind.label
        restartLabelHome = home
        restartLabelUntil = time + 2.6
        switch kind {
        case .throwIn: stats.throwIns += 1
        case .goalKick: stats.goalKicks += 1
        case .corner: stats.corners += 1
        case .freeKick: stats.freeKicks += 1
        case .kickoff: break
        }
    }

    private func chooseTaker(_ kind: PitchRestartKind, home: Bool, spot: PitchVector, preferred: Int?) -> Int? {
        let team = bodies.filter { $0.home == home }
        let outfield = team.filter { !$0.keeper }
        switch kind {
        case .goalKick:
            return team.first { $0.keeper }?.id ?? outfield.min { $0.pos.distance(to: spot) < $1.pos.distance(to: spot) }?.id
        case .corner:
            if let preferred, let found = outfield.first(where: { $0.id == preferred }) { return found.id }
            let wide = outfield.filter { $0.depth < 0.75 }
            return (wide.isEmpty ? outfield : wide).min { $0.pos.distance(to: spot) < $1.pos.distance(to: spot) }?.id
        case .throwIn, .freeKick, .kickoff:
            return outfield.min { $0.pos.distance(to: spot) < $1.pos.distance(to: spot) }?.id
        }
    }

    /// Onde cada jogador se coloca na cobrança. Quem não está na lista segue a formação.
    private func assignSlots(_ kind: PitchRestartKind, home: Bool, spot: PitchVector, taker: Int) {
        let length = Self.length
        let width = Self.width
        let attackDir = home ? 1.0 : -1.0
        let mates = bodies.filter { $0.home == home && !$0.keeper && $0.id != taker }
        let rivals = bodies.filter { $0.home != home && !$0.keeper }
        switch kind {
        case .throwIn:
            let infield = spot.y < width / 2 ? 1.0 : -1.0
            let offsets = [PitchVector(-attackDir * 5, infield * 7), PitchVector(attackDir * 8, infield * 4), PitchVector(attackDir * 14, infield * 10)]
            var free = mates
            for offset in offsets {
                let slot = clamp(spot + offset)
                guard let near = free.min(by: { $0.pos.distance(to: slot) < $1.pos.distance(to: slot) }) else { break }
                free.removeAll { $0.id == near.id }
                setPieceSlots[near.id] = slot
                // Marcação: o adversário mais próximo fica do lado do próprio gol.
                if let marker = rivals.filter({ setPieceSlots[$0.id] == nil }).min(by: { $0.pos.distance(to: slot) < $1.pos.distance(to: slot) }) {
                    setPieceSlots[marker.id] = clamp(slot + PitchVector(attackDir * 1.6, 0))
                }
            }
        case .goalKick:
            // Adversários ficam fora da área até a bola sair.
            break
        case .corner:
            let goalX = home ? length : 0
            let inward = home ? -1.0 : 1.0
            let cornerSide = spot.y < width / 2 ? -1.0 : 1.0
            let attackSlots = [
                PitchVector(goalX + inward * 5.5, width / 2 + cornerSide * 4),
                PitchVector(goalX + inward * 10.5, width / 2 + cornerSide * 1),
                PitchVector(goalX + inward * 6, width / 2 - cornerSide * 5),
                PitchVector(goalX + inward * 17, width / 2 - cornerSide * 3),
                PitchVector(goalX + inward * 20, width / 2 + cornerSide * 10)
            ]
            let attackers = mates.sorted { $0.depth != $1.depth ? $0.depth > $1.depth : $0.id < $1.id }.prefix(attackSlots.count)
            for (i, body) in attackers.enumerated() { setPieceSlots[body.id] = attackSlots[i] }
            let defenders = rivals.sorted { $0.depth != $1.depth ? $0.depth < $1.depth : $0.id < $1.id }.prefix(attackSlots.count)
            for (i, body) in defenders.enumerated() {
                let slot = attackSlots[i]
                setPieceSlots[body.id] = PitchVector(slot.x - inward * 1.2, slot.y - cornerSide * 0.6)
            }
            if let keeper = bodies.first(where: { $0.keeper && $0.home != home }) {
                setPieceSlots[keeper.id] = PitchVector(goalX + inward * 2.5, width / 2 + cornerSide * 1.2)
            }
        case .freeKick:
            let goalX = home ? length : 0
            let goal = PitchVector(goalX, width / 2)
            let distance = spot.distance(to: goal)
            let inward = home ? -1.0 : 1.0
            if distance < 32 {
                let count = distance < 22 ? 5 : 4
                let center = spot + (goal - spot).normalized * 9.15
                let along = (goal - spot).normalized
                let perpendicular = PitchVector(-along.y, along.x)
                var free = rivals
                for i in 0..<count {
                    let slot = center + perpendicular * ((Double(i) - Double(count - 1) / 2) * 0.85)
                    guard let near = free.min(by: { $0.pos.distance(to: slot) < $1.pos.distance(to: slot) }) else { break }
                    free.removeAll { $0.id == near.id }
                    setPieceSlots[near.id] = clamp(slot)
                }
                let attackers = mates.sorted { $0.depth != $1.depth ? $0.depth > $1.depth : $0.id < $1.id }.prefix(3)
                for (i, body) in attackers.enumerated() {
                    setPieceSlots[body.id] = PitchVector(goalX + inward * 9, width / 2 + (Double(i) - 1) * 5)
                }
            }
        case .kickoff:
            break
        }
    }

    private func clamp(_ point: PitchVector) -> PitchVector {
        PitchVector(min(Self.length - 1, max(1, point.x)), min(Self.width - 1, max(1, point.y)))
    }

    private func updateSetPiece(_ dt: Double) {
        guard var piece = setPiece else { return }
        piece.elapsed += dt
        guard let ti = index(of: piece.takerID) else {
            // O cobrador saiu (troca ou expulsão): outro assume.
            if let other = chooseTaker(piece.kind, home: piece.home, spot: piece.spot, preferred: nil) {
                piece.takerID = other
                setPiece = piece
            } else {
                clearSetPiece()
                mode = .loose(0.5)
            }
            return
        }
        let taker = bodies[ti]
        let atSpot = taker.pos.distance(to: piece.spot) < 1.6
        if atSpot, piece.arrivedAt == nil { piece.arrivedAt = piece.elapsed }
        // O cobrador chega, ajeita a bola e só então bate: dá tempo de ver a pose.
        let hold: Double
        switch piece.kind {
        case .throwIn: hold = 0.7
        case .goalKick: hold = 0.8
        case .corner: hold = 1.0
        case .freeKick: hold = 0.9
        case .kickoff: hold = 0.5
        }
        let settled = piece.arrivedAt.map { piece.elapsed - $0 >= hold } ?? false
        ballPos = piece.spot
        ballZ = 0
        bodies[ti].pose = .none
        if piece.kind == .throwIn, atSpot {
            bodies[ti].pose = .throwIn
            ballPos = taker.pos
            ballZ = 2.0
        }
        let timeout = piece.minWait + (piece.kind == .corner ? 7 : 3.5)
        let slotsFilled = setPieceSlots.allSatisfy { entry in
            bodies.first { $0.id == entry.key }.map { $0.pos.distance(to: entry.value) < 2.6 } ?? true
        }
        let needsSlots = piece.kind == .corner || piece.kind == .freeKick
        if atSpot, settled, piece.elapsed >= piece.minWait, !needsSlots || slotsFilled || piece.elapsed > timeout {
            release(piece, takerIndex: ti)
            return
        }
        setPiece = piece
    }

    private func openness(of mate: PitchBody) -> Double {
        let d = bodies.filter { $0.home != mate.home }.map { $0.pos.distance(to: mate.pos) }.min() ?? 10
        return min(1.5, 0.4 + d / 8)
    }

    private func pickWeighted(_ options: [(PitchBody, Double)]) -> PitchBody? {
        let total = options.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return options.first?.0 }
        var pick = random.next() * total
        for option in options {
            pick -= option.1
            if pick <= 0 { return option.0 }
        }
        return options.last?.0
    }

    private func release(_ piece: SetPiece, takerIndex ti: Int) {
        let taker = bodies[ti]
        let home = piece.home
        let slots = setPieceSlots
        clearSetPiece()
        possessionHome = home
        lastTouchHome = home
        let mates = bodies.filter { $0.home == home && !$0.keeper && $0.id != taker.id }
        let origin = piece.kind == .throwIn ? taker.pos : piece.spot
        switch piece.kind {
        case .throwIn:
            let options = mates.compactMap { mate -> (PitchBody, Double)? in
                let d = mate.pos.distance(to: piece.spot)
                guard d > 4, d < 20 else { return nil }
                return (mate, openness(of: mate) * exp(-pow(d - 10, 2) / 90))
            }
            guard let receiver = pickWeighted(options) ?? mates.min(by: { $0.pos.distance(to: piece.spot) < $1.pos.distance(to: piece.spot) }) else {
                mode = .carried(taker.id); carrierID = taker.id; return
            }
            let intended = receiver.pos + receiver.vel * 0.5
            let aim = PitchVector(intended.x + random.gauss() * 0.8, intended.y + random.gauss() * 0.8)
            startFlight(from: origin, aim: aim, intended: intended, receiver: receiver.id, aerial: true, speed: 11, contested: false,
                        passerHome: home, startZ: 2.0)
        case .goalKick:
            let short = random.chance(0.35)
            let options = mates.compactMap { mate -> (PitchBody, Double)? in
                let d = mate.pos.distance(to: piece.spot)
                if short { return d > 10 && d < 26 && mate.depth < 0.45 ? (mate, openness(of: mate)) : nil }
                return d > 26 && d < 60 ? (mate, openness(of: mate) * (mate.depth > 0.4 ? 1.3 : 0.6)) : nil
            }
            guard let receiver = pickWeighted(options) ?? mates.max(by: { $0.pos.distance(to: piece.spot) < $1.pos.distance(to: piece.spot) }) else {
                mode = .carried(taker.id); carrierID = taker.id; return
            }
            let intended = receiver.pos + receiver.vel * 0.8
            let sigma = short ? 1.0 : 3.5
            let aim = clamp(PitchVector(intended.x + random.gauss() * sigma, intended.y + random.gauss() * sigma))
            startFlight(from: origin, aim: aim, intended: intended, receiver: receiver.id, aerial: !short, speed: short ? 14 : 22,
                        contested: !short, passerHome: home)
        case .corner:
            let boxSlots = slots.filter { entry in bodies.first { $0.id == entry.key }?.home == home }
            let candidates = mates.filter { boxSlots[$0.id] != nil }
            let receiver = candidates.isEmpty ? mates.max { $0.depth < $1.depth } : candidates[Int(random.next() * Double(candidates.count)) % candidates.count]
            let intended = receiver.flatMap { boxSlots[$0.id] } ?? PitchVector(home ? Self.length - 10 : 10, Self.width / 2)
            let aim = clamp(PitchVector(intended.x + random.gauss() * 1.6, intended.y + random.gauss() * 1.6))
            startFlight(from: origin, aim: aim, intended: intended, receiver: receiver?.id ?? -1, aerial: true, speed: 17, contested: true, passerHome: home)
        case .freeKick:
            let goal = PitchVector(home ? Self.length : 0, Self.width / 2)
            if piece.spot.distance(to: goal) < 38 {
                let boxSlots = slots.filter { entry in bodies.first { $0.id == entry.key }?.home == home }
                let candidates = mates.filter { boxSlots[$0.id] != nil }
                let receiver = candidates.isEmpty ? mates.max { $0.depth < $1.depth } : candidates[Int(random.next() * Double(candidates.count)) % candidates.count]
                let intended = receiver.flatMap { boxSlots[$0.id] } ?? PitchVector(goal.x + (home ? -9 : 9), goal.y)
                let aim = clamp(PitchVector(intended.x + random.gauss() * 1.8, intended.y + random.gauss() * 1.8))
                startFlight(from: origin, aim: aim, intended: intended, receiver: receiver?.id ?? -1, aerial: true, speed: 19, contested: true, passerHome: home)
            } else {
                let dir = home ? 1.0 : -1.0
                let options = mates.compactMap { mate -> (PitchBody, Double)? in
                    let d = mate.pos.distance(to: piece.spot)
                    guard d > 6, d < 30 else { return nil }
                    return (mate, openness(of: mate) * max(0.2, 1 + (mate.pos.x - piece.spot.x) * dir / 30))
                }
                guard let receiver = pickWeighted(options) ?? mates.min(by: { $0.pos.distance(to: piece.spot) < $1.pos.distance(to: piece.spot) }) else {
                    mode = .carried(taker.id); carrierID = taker.id; return
                }
                let distance = piece.spot.distance(to: receiver.pos)
                let intended = receiver.pos + receiver.vel * 0.6
                let sigma = 0.5 + 0.04 * distance
                let aim = clamp(PitchVector(intended.x + random.gauss() * sigma, intended.y + random.gauss() * sigma))
                startFlight(from: origin, aim: aim, intended: intended, receiver: receiver.id, aerial: distance > 22, speed: 13 + distance * 0.3,
                            contested: false, passerHome: home)
            }
        case .kickoff:
            mode = .carried(taker.id)
            carrierID = taker.id
        }
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
        // Abertura em campo: pontas e laterais jogam perto da linha lateral, como no futebol de verdade.
        var y = width / 2 + (body.lateral - 0.5) * width * 1.7
        y += (ballPos.y - y) * (hasBall ? 0.14 : 0.26)
        let wobble = PitchVector(sin(time * 0.9 + Double(body.id)) * 0.8, cos(time * 0.7 + Double(body.id) * 1.3) * 0.8)
        var base = PitchVector(max(1, min(length - 1, fraction * length + wobble.x)), max(2.6, min(width - 2.6, y + wobble.y)))
        if !hasBall {
            // Marcação: gruda no atacante rival mais próximo do seu posto, do lado do próprio gol.
            var best: PitchBody?
            var bestDistance = 11.0
            for rival in bodies where rival.home != body.home && !rival.keeper {
                let d = rival.pos.distance(to: base)
                if d < bestDistance { best = rival; bestDistance = d }
            }
            if let rival = best {
                let ownGoalDir = body.home ? -1.0 : 1.0
                let mark = PitchVector(rival.pos.x + ownGoalDir * 1.6, rival.pos.y)
                base = base + (mark - base) * (0.1 + 0.45 * (1 - bestDistance / 11))
            }
        }
        return base
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
            if let piece = setPiece {
                if body.id == piece.takerID {
                    target = piece.spot
                    topSpeed = 6.6
                } else if let slot = setPieceSlots[body.id] {
                    target = slot
                    topSpeed = 7.4
                } else {
                    topSpeed = 4.2
                    if piece.kind == .goalKick, body.home != piece.home {
                        // Adversários esperam fora da área até o goleiro chutar.
                        let line = piece.spot.x < length / 2 ? 0.0 : length
                        let depthInside = abs(target.x - line)
                        if depthInside < 21 { target.x = line + (piece.spot.x < length / 2 ? 21 : -21) }
                    }
                }
            } else if restartTimer > 0 {
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
                topSpeed = 6.2
            } else if case .pass(let flight) = mode, flight.targetID == body.id {
                target = flight.intended
                topSpeed = 7.6
            } else if chasers.contains(body.id) {
                target = ballPos
                topSpeed = 8.0
            } else if supporter == body.id, let carrier = carrierID.flatMap({ self.body($0) }) {
                let dir = body.home ? 1.0 : -1.0
                target = carrier.pos + PitchVector(dir * 7, body.pos.y < carrier.pos.y ? -8 : 8)
                topSpeed = 6.4
            }
            let maxSpeed = min(9.2, topSpeed * body.pace)
            let toTarget = target - body.pos
            let distance = toTarget.length
            let arriveSpeed = min(maxSpeed, distance * 1.8)
            let desired = toTarget.normalized * arriveSpeed
            // Arranque e freada têm limite: ninguém vai de zero a sprint nem inverte a corrida de graça.
            let delta = desired - body.vel
            let speedingUp = desired.length > body.vel.length
            let limit = (speedingUp ? 4.6 : 7.5) * dt
            body.vel = delta.length <= limit ? desired : body.vel + delta.normalized * limit
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
            bodies[a].pos.y = min(width + 5, max(-2, bodies[a].pos.y))
        }
    }

    /// Os dois marcadores mais próximos da bola correm para pressionar (e, com a bola solta, os dois mais próximos de cada time).
    private func chaserIDs() -> [Int] {
        guard celebratingHome == nil, restartTimer <= 0, setPiece == nil else { return [] }
        if case .loose = mode {
            let near = bodies.filter { !$0.keeper }
            let home = near.filter { $0.home }.sorted { $0.pos.distance(to: ballPos) < $1.pos.distance(to: ballPos) }.prefix(2)
            let away = near.filter { !$0.home }.sorted { $0.pos.distance(to: ballPos) < $1.pos.distance(to: ballPos) }.prefix(2)
            return (home + away).map(\.id)
        }
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
        var target = PitchVector(ballPos.x - 6, max(4, min(Self.width - 4, ballPos.y + side)))
        if setPiece != nil { target = PitchVector(ballPos.x - 2.5, max(2, min(Self.width - 2, ballPos.y + (side > 0 ? 2.5 : -2.5)))) }
        referee = referee + (target - referee) * min(1, 1.1 * dt)
    }
}
