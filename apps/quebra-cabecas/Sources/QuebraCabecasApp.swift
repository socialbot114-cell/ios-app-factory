import AudioToolbox
import PhotosUI
import SwiftUI
import UIKit

@main
struct QuebraCabecasApp: App {
    var body: some Scene { WindowGroup { PuzzleHome() } }
}

// MARK: - Engine

struct PuzzleResult: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var size: Int
    var moves: Int
    var seconds: Int
    var date: Date
    var isDaily: Bool = false
}

struct PuzzleEngine: Codable, Equatable {
    static let validSizes = [3, 4, 5, 6]
    static let historyLimit = 30
    static let undoLimit = 100

    private(set) var version = 1
    private(set) var size: Int
    private(set) var tiles: [Int]
    private(set) var initialTiles: [Int]?
    private(set) var moves = 0
    private(set) var startedAt: Date
    private(set) var solvedAt: Date?
    private(set) var bestTimes: [Int: Int] = [:]
    private(set) var bestMoves: [Int: Int] = [:]
    private(set) var gamesPlayed = 0
    private(set) var gamesWon = 0
    private(set) var currentStreak = 0
    private(set) var bestStreak = 0
    private(set) var isDaily = false
    private(set) var history: [PuzzleResult] = []
    private(set) var undoStack: [[Int]] = []
    private(set) var pausedAt: Date?
    private(set) var dailyWins: [String] = []

    init(
        size: Int = 3,
        startedAt: Date = .now,
        bestTimes: [Int: Int] = [:],
        bestMoves: [Int: Int] = [:],
        gamesPlayed: Int = 0,
        gamesWon: Int = 0,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        history: [PuzzleResult] = [],
        dailyWins: [String] = []
    ) {
        let validSize = Self.validSizes.contains(size) ? size : 3
        self.size = validSize
        self.tiles = Array(1..<(validSize * validSize)) + [0]
        self.startedAt = startedAt
        self.bestTimes = bestTimes
        self.bestMoves = bestMoves
        self.gamesPlayed = gamesPlayed
        self.gamesWon = gamesWon
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.history = history
        self.dailyWins = dailyWins
    }

    enum CodingKeys: String, CodingKey {
        case version, size, tiles, initialTiles, moves, startedAt, solvedAt
        case bestTimes, bestMoves, gamesPlayed, gamesWon
        case currentStreak, bestStreak, isDaily, history, pausedAt, dailyWins
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        let decodedSize = try c.decodeIfPresent(Int.self, forKey: .size) ?? 3
        size = Self.validSizes.contains(decodedSize) ? decodedSize : 3
        let solved = Array(1..<(size * size)) + [0]
        let decodedTiles = try c.decodeIfPresent([Int].self, forKey: .tiles) ?? solved
        // Save corrompido (tamanho ou peças inválidas) cai para o tabuleiro resolvido.
        tiles = (decodedTiles.count == solved.count && decodedTiles.sorted() == Array(0..<(size * size))) ? decodedTiles : solved
        if let decodedInitial = try c.decodeIfPresent([Int].self, forKey: .initialTiles),
           decodedInitial.count == solved.count, decodedInitial.sorted() == Array(0..<(size * size)) {
            initialTiles = decodedInitial
        } else {
            initialTiles = nil
        }
        moves = max(try c.decodeIfPresent(Int.self, forKey: .moves) ?? 0, 0)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? .now
        solvedAt = try c.decodeIfPresent(Date.self, forKey: .solvedAt)
        // undoStack não persiste mais (chave legada ignorada, economiza UserDefaults).
        undoStack = []
        bestTimes = try c.decodeIfPresent([Int: Int].self, forKey: .bestTimes) ?? [:]
        bestMoves = try c.decodeIfPresent([Int: Int].self, forKey: .bestMoves) ?? [:]
        gamesPlayed = try c.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? 0
        gamesWon = try c.decodeIfPresent(Int.self, forKey: .gamesWon) ?? 0
        currentStreak = try c.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        isDaily = try c.decodeIfPresent(Bool.self, forKey: .isDaily) ?? false
        history = try c.decodeIfPresent([PuzzleResult].self, forKey: .history) ?? []
        pausedAt = try c.decodeIfPresent(Date.self, forKey: .pausedAt)
        dailyWins = try c.decodeIfPresent([String].self, forKey: .dailyWins) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(size, forKey: .size)
        try c.encode(tiles, forKey: .tiles)
        try c.encodeIfPresent(initialTiles, forKey: .initialTiles)
        try c.encode(moves, forKey: .moves)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encodeIfPresent(solvedAt, forKey: .solvedAt)
        try c.encode(bestTimes, forKey: .bestTimes)
        try c.encode(bestMoves, forKey: .bestMoves)
        try c.encode(gamesPlayed, forKey: .gamesPlayed)
        try c.encode(gamesWon, forKey: .gamesWon)
        try c.encode(currentStreak, forKey: .currentStreak)
        try c.encode(bestStreak, forKey: .bestStreak)
        try c.encode(isDaily, forKey: .isDaily)
        try c.encode(history, forKey: .history)
        try c.encodeIfPresent(pausedAt, forKey: .pausedAt)
        try c.encode(dailyWins, forKey: .dailyWins)
    }

    static func dayString(_ date: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    var isSolved: Bool { tiles == Array(1..<(size * size)) + [0] }

    func canMove(tileAt index: Int) -> Bool {
        guard tiles.indices.contains(index), tiles[index] != 0,
              let blank = tiles.firstIndex(of: 0) else { return false }
        return areNeighbors(index, blank)
    }

    mutating func move(tileAt index: Int) -> Bool {
        move(tileAt: index, at: .now)
    }

    mutating func move(tileAt index: Int, at date: Date) -> Bool {
        guard canMove(tileAt: index), let blank = tiles.firstIndex(of: 0) else { return false }
        undoStack.append(tiles)
        if undoStack.count > Self.undoLimit { undoStack.removeFirst() }
        tiles.swapAt(index, blank)
        moves += 1
        if isSolved, solvedAt == nil { solvedAt = date }
        return true
    }

    mutating func undo() -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        tiles = previous
        moves = max(0, moves - 1)
        if !isSolved { solvedAt = nil }
        return true
    }

    var canUndo: Bool { !undoStack.isEmpty }

    mutating func shuffle(seed: UInt64, steps: Int = 0, startedAt date: Date = .now, isDaily: Bool = false) {
        let wanted = steps > 0 ? steps : size * size * 12
        var state = seed == 0 ? 1 : seed
        var best: [Int] = Array(1..<(size * size)) + [0]
        var bestScore = -1
        // Tenta algumas chaves até achar um embaralhamento longe do resolvido.
        for _ in 0..<12 {
            var candidate = Array(1..<(size * size)) + [0]
            for _ in 0..<max(wanted, 1) {
                guard let blank = candidate.firstIndex(of: 0) else { break }
                let choices = neighborIndices(of: blank, size: size)
                state = state &* 6_364_136_223_846_793_005 &+ 1
                let pick = choices[Int(state % UInt64(choices.count))]
                candidate.swapAt(pick, blank)
            }
            let dist = Self.manhattan(of: candidate, size: size)
            let solved = candidate == Array(1..<(size * size)) + [0]
            if !solved, dist > bestScore {
                bestScore = dist
                best = candidate
            }
            if bestScore >= size * 2 { break }
        }
        tiles = best
        initialTiles = best
        moves = 0
        undoStack = []
        solvedAt = nil
        startedAt = date
        self.isDaily = isDaily
        gamesPlayed += 1
    }

    mutating func restartPosition(at date: Date = .now) {
        guard let initial = initialTiles else { return }
        tiles = initial
        undoStack = []
        moves = 0
        solvedAt = nil
        startedAt = date
    }

    func elapsedSeconds(at date: Date = .now) -> Int {
        let end = solvedAt ?? pausedAt ?? date
        return max(Int(end.timeIntervalSince(startedAt)), 0)
    }

    /// Congela o timer ao ir para o fundo; `resume` compensa o tempo fora.
    mutating func pause(at date: Date = .now) {
        guard !isSolved, pausedAt == nil else { return }
        pausedAt = date
    }

    mutating func resume(at date: Date = .now) {
        guard let paused = pausedAt else { return }
        startedAt = startedAt.addingTimeInterval(date.timeIntervalSince(paused))
        pausedAt = nil
    }

    /// Sugere a peça tocável: ótima (IDA*) no 3×3, melhor em 2 lances nos maiores.
    /// O 2-ply evita o ping-pong da dica gulosa de 1 passo.
    func suggestedMove() -> Int? {
        guard !isSolved, tiles.contains(0), let blank = tiles.firstIndex(of: 0) else { return nil }
        if size == 3, let optimal = Self.idaFirstMove(from: tiles) { return optimal }
        let options = neighbors(of: blank)
        var bestIndex: Int?
        var bestScore = Int.max
        for first in options {
            var afterFirst = tiles
            afterFirst.swapAt(first, blank)
            if afterFirst == Array(1..<(size * size)) + [0] { return first }
            guard let blank2 = afterFirst.firstIndex(of: 0) else { continue }
            // Segundo lance: o adversário (nós mesmos) minimiza; olhamos o melhor caso.
            var secondBest = Int.max
            for second in (0..<afterFirst.count).filter({ Self.isNeighbor($0, blank2, size: size) }) {
                var afterSecond = afterFirst
                afterSecond.swapAt(second, blank2)
                secondBest = min(secondBest, Self.manhattan(of: afterSecond, size: size))
            }
            if secondBest < bestScore {
                bestScore = secondBest
                bestIndex = first
            }
        }
        return bestIndex
    }

    /// IDA* com heurística de Manhattan: primeiro lance do caminho ótimo no 3×3.
    private static func idaFirstMove(from start: [Int]) -> Int? {
        let solved = Array(1..<9) + [0]
        guard start != solved, let blank = start.firstIndex(of: 0) else { return nil }
        var threshold = manhattan(of: start, size: 3)
        var budget = 400_000
        while threshold <= 60, budget > 0 {
            var minNext = Int.max
            var answer: Int?
            func dfs(_ state: [Int], _ blank: Int, _ g: Int, _ prevBlank: Int, _ first: Int?) -> Bool {
                if budget <= 0 { return false }
                budget -= 1
                let f = g + manhattan(of: state, size: 3)
                if f > threshold { minNext = min(minNext, f); return false }
                if state == solved { answer = first; return true }
                let r = blank / 3, c = blank % 3
                var nexts: [Int] = []
                if r > 0 { nexts.append(blank - 3) }
                if r < 2 { nexts.append(blank + 3) }
                if c > 0 { nexts.append(blank - 1) }
                if c < 2 { nexts.append(blank + 1) }
                // Tenta primeiro quem mais reduz Manhattan (acelera muito).
                nexts.sort { manhattanAfterSwap(state, $0, blank) < manhattanAfterSwap(state, $1, blank) }
                for n in nexts where n != prevBlank {
                    var child = state
                    child.swapAt(n, blank)
                    if dfs(child, n, g + 1, blank, first ?? n) { return true }
                    if budget <= 0 { return false }
                }
                return false
            }
            if dfs(start, blank, 0, -1, nil) { return answer }
            if minNext == Int.max { return nil }
            threshold = minNext
        }
        return nil
    }

    private static func manhattanAfterSwap(_ tiles: [Int], _ a: Int, _ b: Int) -> Int {
        var copy = tiles
        copy.swapAt(a, b)
        return manhattan(of: copy, size: 3)
    }

    func manhattanDistance() -> Int { Self.manhattan(of: tiles, size: size) }

    func isSolvable() -> Bool {
        var inversions = 0
        let flat = tiles.filter { $0 != 0 }
        for i in 0..<flat.count {
            for j in (i + 1)..<flat.count where flat[i] > flat[j] { inversions += 1 }
        }
        if size % 2 == 1 { return inversions % 2 == 0 }
        guard let blank = tiles.firstIndex(of: 0) else { return false }
        let blankRowFromBottom = size - (blank / size)
        return (inversions + blankRowFromBottom) % 2 == 1
    }

    mutating func recordWin(at date: Date = .now) {
        guard isSolved else { return }
        if solvedAt == nil { solvedAt = date }
        let elapsed = elapsedSeconds(at: date)
        if bestTimes[size] == nil || elapsed < bestTimes[size]! { bestTimes[size] = elapsed }
        if bestMoves[size] == nil || moves < bestMoves[size]! { bestMoves[size] = moves }
        // Evita duplicar a mesma vitória (onChange pode disparar de novo).
        if let last = history.last, last.size == size, last.moves == moves, last.seconds == elapsed { return }
        gamesWon += 1
        currentStreak += 1
        bestStreak = max(bestStreak, currentStreak)
        history.append(PuzzleResult(size: size, moves: moves, seconds: elapsed, date: date, isDaily: isDaily))
        if history.count > Self.historyLimit { history.removeFirst(history.count - Self.historyLimit) }
        if isDaily {
            let day = Self.dayString(date)
            if !dailyWins.contains(day) { dailyWins.append(day) }
        }
    }

    mutating func registerAbandonedGame() {
        // Trocar de partida sem vencer zera a sequência (só se a anterior não estava resolvida).
        if !isSolved, gamesPlayed > 0 { currentStreak = 0 }
    }

    mutating func clearHistory() { history = [] }

    private func areNeighbors(_ lhs: Int, _ rhs: Int) -> Bool {
        abs(lhs / size - rhs / size) + abs(lhs % size - rhs % size) == 1
    }

    private func neighbors(of index: Int) -> [Int] {
        (0..<tiles.count).filter { areNeighbors(index, $0) }
    }

    private static func manhattan(of tiles: [Int], size: Int) -> Int {
        var total = 0
        for (idx, value) in tiles.enumerated() where value != 0 {
            let goal = value - 1
            total += abs(idx / size - goal / size) + abs(idx % size - goal % size)
        }
        return total
    }
}

private func neighborIndices(of index: Int, size: Int) -> [Int] {
    let r = index / size, c = index % size
    var out: [Int] = []
    if r > 0 { out.append(index - size) }
    if r < size - 1 { out.append(index + size) }
    if c > 0 { out.append(index - 1) }
    if c < size - 1 { out.append(index + 1) }
    return out
}

extension PuzzleEngine {
    static func isNeighbor(_ lhs: Int, _ rhs: Int, size: Int) -> Bool {
        abs(lhs / size - rhs / size) + abs(lhs % size - rhs % size) == 1
    }
}

// MARK: - Feedback (som + haptics, sem assets externos)

enum PuzzleFeedback {
    static func moveTick(sound: Bool, haptics: Bool) {
        if sound { AudioServicesPlaySystemSound(1104) }
        if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    static func win(sound: Bool, haptics: Bool) {
        if sound { AudioServicesPlaySystemSound(1016) }
        if haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }
}

// MARK: - UI

enum TileMode: String, CaseIterable {
    case numero, mosaico, foto
    var title: String {
        switch self {
        case .numero: return "Números"
        case .mosaico: return "Mosaico"
        case .foto: return "Minha foto"
        }
    }
}

enum PuzzleDifficulty: String, CaseIterable {
    case facil, normal, dificil
    var title: String {
        switch self {
        case .facil: return "Fácil"
        case .normal: return "Normal"
        case .dificil: return "Difícil"
        }
    }

    /// Passos de embaralhamento por tamanho: mais passos = mais longe do objetivo.
    func steps(for size: Int) -> Int {
        switch self {
        case .facil: return size * size * 4
        case .normal: return size * size * 12
        case .dificil: return size * size * 24
        }
    }
}

struct PuzzleHome: View {
    @State private var engine = PuzzleEngine.load()
    @State private var selectedSize = 3
    @State private var hintIndex: Int?
    @State private var showGoal = false
    @State private var showConfetti = false
    @State private var confirmClearHistory = false
    @State private var photoItem: PhotosPickerItem?
    @State private var userImage: UIImage?
    @State private var sliced: [UIImage] = []
    @State private var confirmNewGame = false
    @State private var confirmDailyGame = false
    @Namespace private var tileNamespace
    @FocusState private var boardFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("puzzle.soundEnabled") private var soundEnabled = true
    @AppStorage("puzzle.hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("puzzle.tileMode") private var tileModeRaw = TileMode.numero.rawValue
    @AppStorage("puzzle.difficulty") private var difficultyRaw = PuzzleDifficulty.normal.rawValue

    private var difficulty: PuzzleDifficulty { PuzzleDifficulty(rawValue: difficultyRaw) ?? .normal }
    private var todayString: String { PuzzleEngine.dayString() }
    private var dailyDone: Bool { engine.dailyWins.contains(todayString) }
    private var misplacedCount: Int {
        let goal = Array(1..<(engine.size * engine.size)) + [0]
        return zip(engine.tiles, goal).filter { $0.0 != $0.1 && $0.0 != 0 }.count
    }

    private let accent = Color(red: 0.27, green: 0.62, blue: 0.56)
    private var tileMode: TileMode { TileMode(rawValue: tileModeRaw) ?? .numero }
    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                FactoryHeader(eyebrow: "Desafio local", title: engine.isSolved ? "Um respiro, peça por peça." : "Encontre o seu ritmo.", subtitle: "Monte o mosaico tocando nas peças vizinhas do espaço vazio.", accent: accent)
                FactoryDemoNotice(message: "Mosaico demonstrativo · imagens geradas no aparelho")
                FactoryPanel {
                    HStack {
                        Label("\(engine.moves) \(engine.moves == 1 ? "movimento" : "movimentos")", systemImage: "hand.tap.fill").font(.subheadline.weight(.semibold))
                            .accessibilityLabel("\(engine.moves) \(engine.moves == 1 ? "movimento" : "movimentos"), \(misplacedCount) \(misplacedCount == 1 ? "peça fora do lugar" : "peças fora do lugar")")
                        Spacer()
                        Text("\(engine.size) × \(engine.size)").font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    board
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        HStack {
                            if engine.isDaily {
                                Label("Desafio de hoje", systemImage: "calendar.badge.checkmark").font(.caption.bold()).foregroundStyle(accent)
                            }
                            Text("Tempo: \(formatTime(engine.elapsedSeconds(at: context.date)))")
                                .font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    actionRow
                    if engine.isSolved {
                        solvedBox
                    }
                }
                FactoryPanel(title: "Dificuldade", systemImage: "slider.horizontal.3") {
                    Picker("Tamanho", selection: $selectedSize) {
                        Text("3 × 3").tag(3); Text("4 × 4").tag(4); Text("5 × 5").tag(5); Text("6 × 6").tag(6)
                    }.pickerStyle(.segmented)
                    Picker("Embaralhamento", selection: $difficultyRaw) {
                        ForEach(PuzzleDifficulty.allCases, id: \.rawValue) { level in Text(level.title).tag(level.rawValue) }
                    }.pickerStyle(.segmented)
                    .accessibilityIdentifier("difficulty-picker")
                    Text("Mistura atual: \(engine.manhattanDistance()) pontos de distância do objetivo.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button { requestNewGame() } label: { Label("Nova partida", systemImage: "shuffle") }
                        .buttonStyle(FactoryPrimaryButtonStyle())
                        .confirmationDialog("Descartar partida atual?", isPresented: $confirmNewGame, titleVisibility: .visible) {
                            Button("Começar nova partida", role: .destructive) { newGame() }
                            Button("Continuar atual", role: .cancel) {}
                        }
                    HStack(spacing: 10) {
                        Button { requestDailyGame() } label: {
                            Label(dailyDone ? "Desafio de hoje ✓" : "Desafio de hoje", systemImage: "calendar")
                        }
                            .buttonStyle(.bordered).tint(accent)
                            .accessibilityIdentifier("daily-button")
                            .confirmationDialog("Descartar partida atual?", isPresented: $confirmDailyGame, titleVisibility: .visible) {
                                Button("Começar desafio", role: .destructive) { dailyGame() }
                                Button("Continuar atual", role: .cancel) {}
                            }
                        Button { restart() } label: { Label("Reiniciar", systemImage: "arrow.counterclockwise") }
                            .buttonStyle(.bordered)
                            .disabled(engine.initialTiles == nil)
                            .accessibilityIdentifier("restart-button")
                    }
                    Text("Cada movimento é salvo automaticamente neste aparelho.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                FactoryPanel(title: "Como jogar", systemImage: "questionmark.circle") {
                    Text("Toque numa peça vizinha do espaço vazio para deslizá-la. Ordene do 1 ao \(engine.size * engine.size - 1). Use Dica quando travar, Desfazer para voltar e Reiniciar para tentar a mesma mistura de novo.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                FactoryPanel(title: "Visual das peças", systemImage: "photo.on.rectangle") {
                    Picker("Visual", selection: $tileModeRaw) {
                        ForEach(TileMode.allCases, id: \.rawValue) { mode in Text(mode.title).tag(mode.rawValue) }
                    }.pickerStyle(.segmented)
                    if tileMode == .foto {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(userImage == nil ? "Escolher foto" : "Trocar foto", systemImage: "photo.badge.plus")
                        }
                        .buttonStyle(.bordered).tint(accent)
                        if userImage == nil {
                            Text("Sem foto ainda: mostramos números até você escolher uma imagem da biblioteca.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if tileMode != .numero {
                        goalPreview
                    }
                }
                HStack(spacing: 12) {
                    FactoryMetric(label: "Melhor tempo", value: engine.bestTimes[engine.size].map(formatTime) ?? "—", symbol: "stopwatch.fill", tint: accent)
                    FactoryMetric(label: "Menos movimentos", value: engine.bestMoves[engine.size].map { "\($0)" } ?? "—", symbol: "figure.walk", tint: .orange)
                    FactoryMetric(label: "Sequência", value: "\(engine.currentStreak)", symbol: "flame.fill", tint: .red)
                }
                FactoryPanel(title: "Histórico", systemImage: "clock.arrow.circlepath") {
                    if engine.history.isEmpty {
                        ContentUnavailableView("Sem vitórias ainda", systemImage: "trophy", description: Text("Resolva um mosaico e ele aparece aqui."))
                    } else {
                        ForEach(Array(engine.history.suffix(10).reversed())) { result in
                            HStack {
                                Text("\(result.size)×\(result.size)").font(.subheadline.bold().monospacedDigit()).frame(width: 52, alignment: .leading)
                                Text("\(formatTime(result.seconds)) · \(result.moves) mov.").font(.subheadline.monospacedDigit())
                                if result.isDaily { Image(systemName: "calendar.badge.checkmark").foregroundStyle(accent).accessibilityLabel("Desafio diário") }
                                Spacer()
                                Text(result.date, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        Button(role: .destructive) { confirmClearHistory = true } label: {
                            Label("Limpar histórico", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("clear-history-button")
                        .confirmationDialog("Apagar histórico?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
                            Button("Apagar", role: .destructive) { engine.clearHistory() }
                            Button("Cancelar", role: .cancel) {}
                        }
                    }
                    HStack {
                        FactoryMetric(label: "Partidas", value: "\(engine.gamesPlayed)", symbol: "gamecontroller.fill", tint: .blue)
                        FactoryMetric(label: "Vitórias", value: "\(engine.gamesWon)", symbol: "trophy.fill", tint: .green)
                        FactoryMetric(label: "Recorde streak", value: "\(engine.bestStreak)", symbol: "star.fill", tint: .purple)
                    }
                }
                FactoryPanel(title: "Ajustes", systemImage: "gearshape") {
                    Toggle(isOn: $soundEnabled) { Label("Efeitos sonoros", systemImage: "speaker.wave.2.fill") }
                    Toggle(isOn: $hapticsEnabled) { Label("Vibração tátil", systemImage: "iphone.radiowaves.left.and.right") }
                }
            }
            .factoryPage()
            .navigationTitle("Quebra-Cabeças").navigationBarTitleDisplayMode(.inline)
            .onChange(of: engine) { _, _ in engine.persist() }
            .onChange(of: engine.isSolved) { _, solved in
                if solved {
                    engine.recordWin()
                    PuzzleFeedback.win(sound: soundEnabled, haptics: hapticsEnabled)
                    withAnimation { showConfetti = true }
                } else {
                    showConfetti = false
                }
            }
            .onChange(of: photoItem) { _, item in Task { await loadPhoto(item) } }
            .onChange(of: selectedSize) { _, _ in reslice() }
            .onChange(of: tileModeRaw) { _, _ in reslice() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { engine.pause() }
                else if phase == .active { engine.resume() }
            }
            .sheet(isPresented: $showGoal) { goalSheet }
            .onAppear {
                if FactoryCapture.isUITesting {
                    FactoryCapture.resetAppDefaults()
                    removePhotoFromDisk()
                    soundEnabled = false
                    hapticsEnabled = false
                    tileModeRaw = TileMode.numero.rawValue
                    difficultyRaw = PuzzleDifficulty.normal.rawValue
                    selectedSize = 3
                    engine = PuzzleEngine(size: 3)
                    userImage = nil
                    sliced = []
                } else if userImage == nil {
                    // Restaura a foto salva (modo foto sobrevive ao reiniciar o app).
                    if let saved = loadPhotoFromDisk() {
                        userImage = saved
                    } else if tileMode == .foto {
                        tileModeRaw = TileMode.numero.rawValue
                    }
                }
                engine.resume()
                selectedSize = engine.size
                reslice()
                if UIDevice.current.userInterfaceIdiom == .pad { boardFocused = true }
                if engine.isSolved { newGame(seed: capture == "board" ? 44 : 17) }
            }
        }
        .tint(accent)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button { undoMove() } label: { Label("Desfazer", systemImage: "arrow.uturn.backward") }
                .buttonStyle(.bordered)
                .disabled(!engine.canUndo || engine.isSolved)
                .accessibilityIdentifier("undo-button")
            Button { showHint() } label: { Label("Dica", systemImage: "lightbulb") }
                .buttonStyle(.bordered)
                .disabled(engine.isSolved)
                .accessibilityIdentifier("hint-button")
            Button { showGoal = true } label: { Label("Objetivo", systemImage: "eye") }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("goal-button")
        }
        .tint(accent)
    }

    private var solvedBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Quebra-cabeça completo!", systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundStyle(.green)
            Text("Tempo \(formatTime(engine.elapsedSeconds())) · \(engine.moves) \(engine.moves == 1 ? "movimento" : "movimentos")")
                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                if engine.bestTimes[engine.size] == engine.elapsedSeconds() {
                    Label("Recorde de tempo", systemImage: "stopwatch.fill")
                        .font(.caption.bold()).foregroundStyle(accent)
                        .accessibilityIdentifier("record-time-badge")
                }
                if engine.bestMoves[engine.size] == engine.moves {
                    Label("Recorde de movimentos", systemImage: "figure.walk")
                        .font(.caption.bold()).foregroundStyle(.orange)
                        .accessibilityIdentifier("record-moves-badge")
                }
            }
            HStack(spacing: 10) {
                ShareLink(item: shareText) {
                    Label("Compartilhar", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered).tint(accent)
                Button { newGame() } label: { Label("Jogar de novo", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(.bordered).tint(accent)
                    .accessibilityIdentifier("play-again-button")
            }
        }
        .overlay { if showConfetti { ConfettiOverlay() } }
    }

    private var shareText: String {
        "🧩 Quebra-Cabeças \(engine.size)×\(engine.size): \(formatTime(engine.elapsedSeconds())) em \(engine.moves) movimentos!"
    }

    private var board: some View {
        GeometryReader { geometry in
            let gap: CGFloat = 5
            let side = (geometry.size.width - CGFloat(engine.size - 1) * gap) / CGFloat(engine.size)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: gap), count: engine.size), spacing: gap) {
                ForEach(engine.tiles.indices, id: \.self) { index in
                    let value = engine.tiles[index]
                    Button { tapTile(at: index) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: max(7, side * 0.13), style: .continuous)
                                .fill(tileBackground(value: value))
                                .overlay {
                                    if hintIndex == index {
                                        RoundedRectangle(cornerRadius: max(7, side * 0.13), style: .continuous)
                                            .strokeBorder(Color.yellow, lineWidth: 3)
                                    }
                                }
                            if value != 0 {
                                if tileMode == .foto, let img = sliceImage(for: value) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: side, height: side)
                                        .clipShape(RoundedRectangle(cornerRadius: max(7, side * 0.13), style: .continuous))
                                        .overlay {
                                            Text("\(value)").font(.system(size: max(10, side * 0.18), weight: .bold, design: .rounded))
                                                .foregroundStyle(.white).shadow(radius: 3)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                                .padding(4)
                                        }
                                } else {
                                    VStack(spacing: 0) {
                                        Text("\(value)").font(.system(size: max(13, side * 0.3), weight: .bold, design: .rounded)).foregroundStyle(.white)
                                        if tileMode == .mosaico {
                                            Image(systemName: mosaicSymbol(for: value))
                                                .font(.system(size: max(8, side * 0.16), weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.85))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: side, height: side)
                        .scaleEffect(hintIndex == index ? 1.06 : 1.0)
                        .matchedGeometryEffect(id: "tile-\(value)", in: tileNamespace)
                    }
                    .buttonStyle(.plain)
                    .disabled(!engine.canMove(tileAt: index))
                    .accessibilityHint(engine.canMove(tileAt: index) ? "Toque para mover para o espaço vazio." : "Esta peça não pode ser movida agora.")
                    .accessibilityLabel(value == 0 ? "Espaço vazio" : "Peça \(value)")
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: engine.tiles)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("puzzle-board")
        .focusable()
        .focused($boardFocused)
        .onKeyPress(.leftArrow) { moveBlank(dx: -1, dy: 0); return .handled }
        .onKeyPress(.rightArrow) { moveBlank(dx: 1, dy: 0); return .handled }
        .onKeyPress(.upArrow) { moveBlank(dx: 0, dy: -1); return .handled }
        .onKeyPress(.downArrow) { moveBlank(dx: 0, dy: 1); return .handled }
    }

    /// Move o espaço vazio com o teclado (iPad): a seta indica para onde o vazio vai.
    private func moveBlank(dx: Int, dy: Int) {
        guard let blank = engine.tiles.firstIndex(of: 0) else { return }
        let r = blank / engine.size, c = blank % engine.size
        let nr = r + dy, nc = c + dx
        guard nr >= 0, nr < engine.size, nc >= 0, nc < engine.size else { return }
        tapTile(at: nr * engine.size + nc)
    }

    private var goalPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Objetivo").font(.caption.bold()).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 3), count: engine.size), spacing: 3) {
                ForEach(0..<(engine.size * engine.size), id: \.self) { i in
                    let value = i + 1 <= engine.size * engine.size - 1 ? i + 1 : 0
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(value == 0 ? Color.primary.opacity(0.06) : tileBackground(value: value))
                        .frame(width: 34, height: 34)
                        .overlay {
                            if value != 0, let img = sliceImage(for: value), tileMode == .foto {
                                Image(uiImage: img).resizable().scaledToFill().frame(width: 34, height: 34)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            } else if value != 0 {
                                Text("\(value)").font(.caption2.bold()).foregroundStyle(.white)
                            }
                        }
                }
            }
        }
    }

    private var goalSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Monte nesta ordem, do 1 até o \(engine.size * engine.size - 1).").font(.subheadline).foregroundStyle(.secondary)
                goalPreviewBig
                Button("Fechar") { showGoal = false }.buttonStyle(FactoryPrimaryButtonStyle()).padding(.top, 8)
                Spacer()
            }
            .padding(20)
            .navigationTitle("Objetivo").navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private var goalPreviewBig: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: engine.size), spacing: 5) {
            ForEach(0..<(engine.size * engine.size), id: \.self) { i in
                let value = i + 1 <= engine.size * engine.size - 1 ? i + 1 : 0
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(value == 0 ? Color.primary.opacity(0.06) : tileBackground(value: value))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if value != 0, let img = sliceImage(for: value), tileMode == .foto {
                            Image(uiImage: img).resizable().scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else if value != 0 {
                            Text("\(value)").font(.title3.bold()).foregroundStyle(.white)
                        }
                    }
            }
        }
        .frame(maxWidth: 320)
    }

    private func tileBackground(value: Int) -> Color {
        guard value != 0 else { return Color.primary.opacity(0.035) }
        if tileMode == .foto, userImage != nil { return Color.primary.opacity(0.1) }
        if tileMode == .mosaico {
            let hue = Double((value - 1) % max(engine.size * engine.size - 1, 1)) / Double(max(engine.size * engine.size, 1))
            return Color(hue: hue, saturation: 0.62, brightness: 0.82)
        }
        let colors: [Color] = [.orange, .pink, .purple, .indigo, .blue, .teal, .green, .mint, .yellow]
        return colors[(max(value, 1) - 1) % colors.count].opacity(0.88)
    }

    private func mosaicSymbol(for value: Int) -> String {
        ["star.fill", "heart.fill", "leaf.fill", "fish.fill", "bird.fill", "car.fill", "moon.fill", "sun.max.fill", "bolt.fill"][((value - 1) % 9 + 9) % 9]
    }

    private func sliceImage(for value: Int) -> UIImage? {
        guard tileMode == .foto, value > 0, sliced.count == engine.size * engine.size else { return nil }
        return sliced[value - 1]
    }

    private func tapTile(at index: Int) {
        hintIndex = nil
        var next = engine
        guard next.move(tileAt: index) else { return }
        engine = next
        PuzzleFeedback.moveTick(sound: soundEnabled, haptics: hapticsEnabled)
    }

    private func undoMove() {
        var next = engine
        guard next.undo() else { return }
        engine = next
        hintIndex = nil
    }

    private func showHint() {
        hintIndex = engine.suggestedMove()
        if hintIndex != nil { PuzzleFeedback.moveTick(sound: false, haptics: hapticsEnabled) }
    }

    private var hasProgressToLose: Bool { !engine.isSolved && engine.moves > 0 }

    private func requestNewGame() {
        if hasProgressToLose { confirmNewGame = true } else { newGame() }
    }

    private func requestDailyGame() {
        if hasProgressToLose { confirmDailyGame = true } else { dailyGame() }
    }

    private func newGame(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        var old = engine
        old.registerAbandonedGame()
        var working = PuzzleEngine(size: selectedSize, bestTimes: old.bestTimes, bestMoves: old.bestMoves, gamesPlayed: old.gamesPlayed, gamesWon: old.gamesWon, currentStreak: old.currentStreak, bestStreak: old.bestStreak, history: old.history, dailyWins: old.dailyWins)
        working.shuffle(seed: seed, steps: difficulty.steps(for: selectedSize))
        engine = working
        hintIndex = nil
        showConfetti = false
        reslice()
    }

    private func dailyGame() {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        let seed = UInt64(comps.year ?? 2026) * 10_000 + UInt64(comps.month ?? 1) * 100 + UInt64(comps.day ?? 1)
        var old = engine
        old.registerAbandonedGame()
        var working = PuzzleEngine(size: selectedSize, bestTimes: old.bestTimes, bestMoves: old.bestMoves, gamesPlayed: old.gamesPlayed, gamesWon: old.gamesWon, currentStreak: old.currentStreak, bestStreak: old.bestStreak, history: old.history, dailyWins: old.dailyWins)
        working.shuffle(seed: seed == 0 ? 1 : seed, steps: difficulty.steps(for: selectedSize), isDaily: true)
        engine = working
        hintIndex = nil
        showConfetti = false
        reslice()
    }

    private func restart() {
        var next = engine
        next.restartPosition()
        engine = next
        hintIndex = nil
        showConfetti = false
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) else { return }
        let downsized = downscale(image: img, maxSide: 1024)
        await MainActor.run {
            userImage = downsized
            tileModeRaw = TileMode.foto.rawValue
            savePhotoToDisk(downsized)
            reslice()
        }
    }

    private static var savedPhotoURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("puzzle.photo.jpg")
    }

    private func savePhotoToDisk(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: Self.savedPhotoURL, options: .atomic)
    }

    private func loadPhotoFromDisk() -> UIImage? {
        guard let data = try? Data(contentsOf: Self.savedPhotoURL) else { return nil }
        return UIImage(data: data)
    }

    private func removePhotoFromDisk() {
        try? FileManager.default.removeItem(at: Self.savedPhotoURL)
    }

    private func downscale(image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }

    private func reslice() {
        guard tileMode == .foto, let img = userImage else { sliced = []; return }
        sliced = slice(image: img, size: engine.size)
    }

    private func slice(image: UIImage, size: Int) -> [UIImage] {
        guard let cg = image.cgImage else { return [] }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let side = min(w, h)
        let ox = (w - side) / 2, oy = (h - side) / 2
        let piece = side / CGFloat(size)
        var out: [UIImage] = []
        for r in 0..<size {
            for c in 0..<size {
                let rect = CGRect(x: ox + CGFloat(c) * piece, y: oy + CGFloat(r) * piece, width: piece, height: piece)
                if let cut = cg.cropping(to: rect) {
                    // Fatias em resolução de tela (~256px): 36 peças full-size estouravam memória no 6×6.
                    let raw = UIImage(cgImage: cut, scale: image.scale, orientation: .up)
                    out.append(downscale(image: raw, maxSide: 256))
                }
            }
        }
        return out
    }

    private func formatTime(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
}

struct ConfettiOverlay: View {
    private struct Piece: Hashable {
        var x: Double
        var phase: Double
        var speed: Double
        var size: Double
        var color: Color
    }

    private let pieces: [Piece] = (0..<48).map { i in
        Piece(
            x: Double(i) / 48.0,
            phase: Double((i * 37) % 100) / 100.0,
            speed: 0.12 + Double(i % 5) * 0.03,
            size: 5 + Double(i % 3) * 2,
            color: [.red, .orange, .yellow, .green, .blue, .purple, .pink][i % 7]
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ForEach(pieces, id: \.self) { piece in
                    Circle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size)
                        .position(
                            x: piece.x * geo.size.width,
                            y: ((piece.phase + t * piece.speed).truncatingRemainder(dividingBy: 1.0)) * geo.size.height
                        )
                        .opacity(0.85)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

extension PuzzleEngine {
    static func load(defaults: UserDefaults = .standard) -> PuzzleEngine {
        guard let data = defaults.data(forKey: "puzzle.engine"), let value = try? JSONDecoder().decode(PuzzleEngine.self, from: data) else { return PuzzleEngine() }
        return value
    }

    func persist(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "puzzle.engine")
    }
}
