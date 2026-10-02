import SwiftUI

@main
struct QuebraCabecasApp: App {
    var body: some Scene { WindowGroup { PuzzleHome() } }
}

enum PuzzleMode: String, CaseIterable, Codable, Identifiable {
    case numbers = "Números"
    case picture = "Imagem"

    var id: String { rawValue }
}

private enum PuzzleReplacement: Equatable {
    case mode(PuzzleMode)
    case size(Int)
    case newGame
}

struct PuzzleEngine: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case size
        case tiles
        case moves
        case startedAt
        case bestTimes
        case mode
        case imageBestTimes
    }

    private(set) var size: Int
    private(set) var tiles: [Int]
    private(set) var moves = 0
    private(set) var startedAt: Date
    private(set) var bestTimes: [Int: Int] = [:]
    private(set) var mode: PuzzleMode
    private(set) var imageBestTimes: [Int: Int] = [:]

    init(
        size: Int = 3,
        mode: PuzzleMode = .numbers,
        startedAt: Date = .now,
        bestTimes: [Int: Int] = [:],
        imageBestTimes: [Int: Int] = [:]
    ) {
        let validSize = [3, 4, 6].contains(size) ? size : 3
        self.size = validSize
        self.tiles = Array(1..<(validSize * validSize)) + [0]
        self.startedAt = startedAt
        self.bestTimes = bestTimes
        self.mode = mode
        self.imageBestTimes = imageBestTimes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSize = try container.decodeIfPresent(Int.self, forKey: .size) ?? 3
        let validSize = [3, 4, 6].contains(decodedSize) ? decodedSize : 3
        let solvedTiles = Array(1..<(validSize * validSize)) + [0]
        let decodedTiles = try container.decodeIfPresent([Int].self, forKey: .tiles) ?? solvedTiles

        size = validSize
        tiles = decodedTiles.count == validSize * validSize && decodedTiles.sorted() == Array(0..<(validSize * validSize))
            ? decodedTiles
            : solvedTiles
        moves = max(try container.decodeIfPresent(Int.self, forKey: .moves) ?? 0, 0)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? .now
        bestTimes = try container.decodeIfPresent([Int: Int].self, forKey: .bestTimes) ?? [:]
        mode = try container.decodeIfPresent(PuzzleMode.self, forKey: .mode) ?? .numbers
        imageBestTimes = try container.decodeIfPresent([Int: Int].self, forKey: .imageBestTimes) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(size, forKey: .size)
        try container.encode(tiles, forKey: .tiles)
        try container.encode(moves, forKey: .moves)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(bestTimes, forKey: .bestTimes)
        try container.encode(mode, forKey: .mode)
        try container.encode(imageBestTimes, forKey: .imageBestTimes)
    }

    var isSolved: Bool { tiles == Array(1..<(size * size)) + [0] }

    var bestTime: Int? {
        mode == .numbers ? bestTimes[size] : imageBestTimes[size]
    }

    func canMove(tileAt index: Int) -> Bool {
        guard tiles.indices.contains(index), tiles[index] != 0,
              let blank = tiles.firstIndex(of: 0) else { return false }
        return areNeighbors(index, blank)
    }

    mutating func move(tileAt index: Int) -> Bool {
        guard canMove(tileAt: index), let blank = tiles.firstIndex(of: 0) else { return false }
        tiles.swapAt(index, blank)
        moves += 1
        return true
    }

    mutating func shuffle(seed: UInt64, steps: Int = 80, startedAt: Date = .now) {
        tiles = Array(1..<(size * size)) + [0]
        moves = 0
        self.startedAt = startedAt
        var state = seed == 0 ? 1 : seed
        for _ in 0..<max(steps, 1) {
            guard let blank = tiles.firstIndex(of: 0) else { break }
            let choices = neighbors(of: blank)
            state = state &* 6_364_136_223_846_793_005 &+ 1
            _ = move(tileAt: choices[Int(state % UInt64(choices.count))])
        }
        moves = 0
    }

    func elapsedSeconds(at date: Date = .now) -> Int { max(Int(date.timeIntervalSince(startedAt)), 0) }

    mutating func recordBest(at date: Date = .now) {
        guard isSolved else { return }
        let elapsed = elapsedSeconds(at: date)
        if mode == .numbers {
            if bestTimes[size] == nil || elapsed < bestTimes[size]! { bestTimes[size] = elapsed }
        } else if imageBestTimes[size] == nil || elapsed < imageBestTimes[size]! {
            imageBestTimes[size] = elapsed
        }
    }

    private func areNeighbors(_ lhs: Int, _ rhs: Int) -> Bool {
        abs(lhs / size - rhs / size) + abs(lhs % size - rhs % size) == 1
    }

    private func neighbors(of index: Int) -> [Int] {
        (0..<tiles.count).filter { areNeighbors(index, $0) }
    }
}

struct PuzzleHome: View {
    @State private var engine = PuzzleEngine.load()
    @State private var selectedSize = 3
    @State private var pendingReplacement: PuzzleReplacement?
    @State private var showReplacementConfirmation = false
    private let accent = Color(red: 0.27, green: 0.62, blue: 0.56)
    private let colors: [Color] = [.orange, .pink, .purple, .indigo, .blue, .teal, .green, .mint, .yellow]
    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                FactoryHeader(
                    eyebrow: "Desafio local",
                    title: engine.isSolved ? "Um respiro, peça por peça." : (engine.mode == .picture ? "Revele a paisagem." : "Encontre o seu ritmo."),
                    subtitle: engine.mode == .picture
                        ? "Reconstrua a ilustração original movendo as peças vizinhas ao espaço vazio."
                        : "Monte o mosaico numérico tocando nas peças vizinhas do espaço vazio.",
                    accent: accent
                )
                FactoryDemoNotice(message: engine.mode == .picture
                    ? "Ilustração original em SwiftUI · conteúdo local"
                    : "Mosaico numérico demonstrativo · conteúdo local")
                FactoryPanel {
                    HStack {
                        Label("\(engine.moves) \(engine.moves == 1 ? "movimento" : "movimentos")", systemImage: "hand.tap.fill").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(engine.size) × \(engine.size)").font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    if engine.mode == .picture {
                        HStack(spacing: 12) {
                            PuzzleIllustration()
                                .frame(width: 68, height: 68)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Serra ao amanhecer").font(.subheadline.weight(.semibold))
                                Text("Prévia da imagem para orientar a montagem.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    board
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("Tempo: \(formatTime(engine.elapsedSeconds(at: context.date)))")
                            .font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    if engine.isSolved {
                        Label("Quebra-cabeça completo!", systemImage: "checkmark.seal.fill")
                            .font(.headline).foregroundStyle(.green)
                    }
                }
                FactoryPanel(title: "Modo e dificuldade", systemImage: "slider.horizontal.3") {
                    Picker("Modo", selection: Binding(
                        get: { engine.mode },
                        set: { requestReplacement(.mode($0)) }
                    )) {
                        ForEach(PuzzleMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("puzzle-mode-picker")
                    Picker("Tamanho", selection: Binding(
                        get: { selectedSize },
                        set: { requestReplacement(.size($0)) }
                    )) {
                        Text("3 × 3").tag(3); Text("4 × 4").tag(4); Text("6 × 6").tag(6)
                    }.pickerStyle(.segmented)
                    Button { requestReplacement(.newGame) } label: { Label("Nova partida", systemImage: "shuffle") }
                        .buttonStyle(FactoryPrimaryButtonStyle())
                    Text(engine.mode == .picture
                         ? "Imagem original: Serra ao amanhecer. Cada movimento é salvo automaticamente neste aparelho."
                         : "Cada movimento é salvo automaticamente neste aparelho.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    FactoryMetric(label: "Melhor tempo", value: engine.bestTime.map(formatTime) ?? "—", symbol: "stopwatch.fill", tint: accent)
                    FactoryMetric(label: engine.mode == .picture ? "Ilustração" : "Coleção", value: engine.mode == .picture ? "1 imagem" : "1 mosaico", symbol: engine.mode == .picture ? "photo.artframe" : "square.grid.3x3.fill", tint: .orange)
                }
            }
            .factoryPage(backgroundColor: Color(red: 0.98, green: 0.97, blue: 0.94))
            .navigationTitle("Quebra-Cabeças").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Descartar a partida atual?", isPresented: $showReplacementConfirmation, titleVisibility: .visible) {
                Button("Descartar e iniciar", role: .destructive) {
                    if let pendingReplacement { apply(pendingReplacement) }
                }
                Button("Continuar partida", role: .cancel) { pendingReplacement = nil }
            } message: {
                Text(engine.moves == 1
                     ? "Você já fez 1 movimento. Se continuar, ele será descartado."
                     : "Você já fez \(engine.moves) movimentos. Se continuar, eles serão descartados.")
            }
            .onChange(of: engine) { _, _ in engine.persist() }
            .onChange(of: engine.isSolved) { _, solved in if solved { engine.recordBest() } }
            .onAppear {
                if FactoryCapture.isUITesting {
                    FactoryCapture.resetAppDefaults()
                    selectedSize = 3
                    engine = PuzzleEngine(size: 3)
                }
                if capture == "board" {
                    selectedSize = 3
                    var preview = PuzzleEngine(
                        size: 3,
                        mode: .picture,
                        bestTimes: engine.bestTimes,
                        imageBestTimes: engine.imageBestTimes
                    )
                    preview.shuffle(seed: 44, steps: 81)
                    engine = preview
                } else {
                    selectedSize = engine.size
                    if engine.isSolved { newGame(seed: 17) }
                }
            }
        }
        .tint(accent)
    }

    private var board: some View {
        GeometryReader { geometry in
            let gap: CGFloat = 5
            let side = (geometry.size.width - CGFloat(engine.size - 1) * gap) / CGFloat(engine.size)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: gap), count: engine.size), spacing: gap) {
                ForEach(engine.tiles.indices, id: \.self) { index in
                    let value = engine.tiles[index]
                    Button {
                        _ = engine.move(tileAt: index)
                    } label: {
                        ZStack {
                            if engine.mode == .picture {
                                if value == 0 {
                                    if engine.isSolved {
                                        PuzzleIllustrationTile(sourceIndex: engine.size * engine.size - 1, size: engine.size)
                                    } else {
                                        RoundedRectangle(cornerRadius: max(7, side * 0.13), style: .continuous)
                                            .fill(Color.primary.opacity(0.055))
                                            .overlay(Image(systemName: "square.dashed").font(.caption).foregroundStyle(.secondary))
                                    }
                                } else {
                                    PuzzleIllustrationTile(sourceIndex: value - 1, size: engine.size)
                                }
                            } else {
                                RoundedRectangle(cornerRadius: max(7, side * 0.13), style: .continuous)
                                    .fill(value == 0 ? Color.primary.opacity(0.035) : colors[(max(value, 1) - 1) % colors.count].opacity(0.88))
                                if value != 0 {
                                    Text("\(value)").font(.system(size: max(13, side * 0.32), weight: .bold, design: .rounded)).foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: max(7, side * 0.13), style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: max(7, side * 0.13), style: .continuous).strokeBorder(.white.opacity(0.62), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!engine.canMove(tileAt: index))
                    .accessibilityHint(engine.canMove(tileAt: index) ? "Toque para mover para o espaço vazio." : "Esta peça não pode ser movida agora.")
                    .accessibilityLabel(tileAccessibilityLabel(value: value))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("puzzle-board")
    }

    private func newGame(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        var next = PuzzleEngine(
            size: selectedSize,
            mode: engine.mode,
            bestTimes: engine.bestTimes,
            imageBestTimes: engine.imageBestTimes
        )
        next.shuffle(seed: seed, steps: 81)
        engine = next
    }

    private func requestReplacement(_ replacement: PuzzleReplacement) {
        if case let .mode(mode) = replacement, mode == engine.mode { return }
        if case let .size(size) = replacement, size == selectedSize { return }
        guard engine.moves > 0 && !engine.isSolved else {
            apply(replacement)
            return
        }
        pendingReplacement = replacement
        showReplacementConfirmation = true
    }

    private func apply(_ replacement: PuzzleReplacement) {
        pendingReplacement = nil
        switch replacement {
        case let .mode(mode):
            replaceMode(mode)
        case let .size(size):
            selectedSize = size
            newGame()
        case .newGame:
            newGame()
        }
    }

    private func replaceMode(_ mode: PuzzleMode) {
        guard mode != engine.mode else { return }
        var next = PuzzleEngine(
            size: selectedSize,
            mode: mode,
            bestTimes: engine.bestTimes,
            imageBestTimes: engine.imageBestTimes
        )
        next.shuffle(seed: UInt64.random(in: 1...UInt64.max), steps: 81)
        engine = next
    }

    private func tileAccessibilityLabel(value: Int) -> String {
        if value == 0 {
            return engine.mode == .picture && engine.isSolved ? "Ilustração concluída" : "Espaço vazio"
        }
        guard engine.mode == .picture else { return "Peça \(value)" }
        let row = (value - 1) / engine.size + 1
        let column = (value - 1) % engine.size + 1
        return "Peça de imagem, linha \(row), coluna \(column)"
    }

    private func formatTime(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
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
