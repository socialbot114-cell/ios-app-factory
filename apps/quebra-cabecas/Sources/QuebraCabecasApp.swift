import SwiftUI

@main
struct QuebraCabecasApp: App {
    var body: some Scene { WindowGroup { PuzzleHome() } }
}

struct PuzzleEngine: Codable, Equatable {
    private(set) var size: Int
    private(set) var tiles: [Int]
    private(set) var moves = 0
    private(set) var startedAt: Date
    private(set) var bestTimes: [Int: Int] = [:]

    init(size: Int = 3, startedAt: Date = .now) {
        let validSize = [3, 4, 6].contains(size) ? size : 3
        self.size = validSize
        self.tiles = Array(1..<(validSize * validSize)) + [0]
        self.startedAt = startedAt
    }

    var isSolved: Bool { tiles == Array(1..<(size * size)) + [0] }

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
        if bestTimes[size] == nil || elapsed < bestTimes[size]! { bestTimes[size] = elapsed }
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
    private let accent = Color(red: 0.27, green: 0.62, blue: 0.56)
    private let colors: [Color] = [.orange, .pink, .purple, .indigo, .blue, .teal, .green, .mint, .yellow]
    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                FactoryHeader(eyebrow: "Desafio local", title: engine.isSolved ? "Um respiro, peça por peça." : "Encontre o seu ritmo.", subtitle: "Monte o mosaico numérico tocando nas peças vizinhas do espaço vazio.", accent: accent)
                FactoryDemoNotice(message: "Mosaico numérico demonstrativo · sem imagens licenciadas")
                FactoryPanel {
                    HStack {
                        Label("\(engine.moves) \(engine.moves == 1 ? "movimento" : "movimentos")", systemImage: "hand.tap.fill").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(engine.size) × \(engine.size)").font(.caption.bold()).foregroundStyle(.secondary)
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
                FactoryPanel(title: "Dificuldade", systemImage: "slider.horizontal.3") {
                    Picker("Tamanho", selection: $selectedSize) {
                        Text("3 × 3").tag(3); Text("4 × 4").tag(4); Text("6 × 6").tag(6)
                    }.pickerStyle(.segmented)
                    Button { newGame() } label: { Label("Nova partida", systemImage: "shuffle") }
                        .buttonStyle(FactoryPrimaryButtonStyle())
                    Text("Cada movimento é salvo automaticamente neste aparelho.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    FactoryMetric(label: "Melhor tempo", value: engine.bestTimes[engine.size].map(formatTime) ?? "—", symbol: "stopwatch.fill", tint: accent)
                    FactoryMetric(label: "Coleção", value: "1 mosaico", symbol: "square.grid.3x3.fill", tint: .orange)
                }
            }
            .factoryPage(backgroundColor: Color(red: 0.98, green: 0.97, blue: 0.94))
            .navigationTitle("Quebra-Cabeças").navigationBarTitleDisplayMode(.inline)
            .onChange(of: engine) { _, _ in engine.persist() }
            .onChange(of: engine.isSolved) { _, solved in if solved { engine.recordBest() } }
            .onAppear {
                if FactoryCapture.isUITesting {
                    FactoryCapture.resetAppDefaults()
                    selectedSize = 3
                    engine = PuzzleEngine(size: 3)
                }
                selectedSize = engine.size
                if engine.isSolved { newGame(seed: capture == "board" ? 44 : 26) }
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
                            RoundedRectangle(cornerRadius: max(7, side * 0.13), style: .continuous)
                                .fill(value == 0 ? Color.primary.opacity(0.035) : colors[(max(value, 1) - 1) % colors.count].opacity(0.88))
                            if value != 0 {
                                Text("\(value)").font(.system(size: max(13, side * 0.32), weight: .bold, design: .rounded)).foregroundStyle(.white)
                            }
                        }
                        .frame(width: side, height: side)
                    }
                    .buttonStyle(.plain)
                    .disabled(!engine.canMove(tileAt: index))
                    .accessibilityHint(engine.canMove(tileAt: index) ? "Toque para mover para o espaço vazio." : "Esta peça não pode ser movida agora.")
                    .accessibilityLabel(value == 0 ? "Espaço vazio" : "Peça \(value)")
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("puzzle-board")
    }

    private func newGame(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        engine = PuzzleEngine(size: selectedSize)
        engine.shuffle(seed: seed)
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
