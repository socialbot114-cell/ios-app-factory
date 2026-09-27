import SwiftUI
import CoreMotion

@main
struct DetetiveNaTestaApp: App {
    var body: some Scene { WindowGroup { DetectiveHome() } }
}

enum DetectiveCategory: String, CaseIterable, Identifiable, Codable {
    case animals = "Animais"
    case places = "Lugares"
    case objects = "Objetos e diversão"
    case nature = "Natureza e espaço"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .animals: "pawprint.fill"
        case .places: "mappin.and.ellipse"
        case .objects: "sparkles"
        case .nature: "sun.max.fill"
        }
    }
}

struct DetectiveCard: Identifiable, Hashable {
    let word: String
    let category: DetectiveCategory

    var id: String { word }
}

struct DetectiveDeck {
    let cards: [DetectiveCard] = [
        .init(word: "Capivara", category: .animals),
        .init(word: "Mico-leão", category: .animals),
        .init(word: "Tatu-bola", category: .animals),
        .init(word: "Arara-azul", category: .animals),
        .init(word: "Onça-pintada", category: .animals),
        .init(word: "Tamanduá-bandeira", category: .animals),
        .init(word: "Lobo-guará", category: .animals),
        .init(word: "Boto-cor-de-rosa", category: .animals),
        .init(word: "Tucano", category: .animals),
        .init(word: "Borboleta", category: .animals),

        .init(word: "Ponte JK", category: .places),
        .init(word: "Farol", category: .places),
        .init(word: "Biblioteca", category: .places),
        .init(word: "Cinema", category: .places),
        .init(word: "Praça", category: .places),
        .init(word: "Montanha", category: .places),
        .init(word: "Cachoeira", category: .places),
        .init(word: "Museu", category: .places),
        .init(word: "Jardim botânico", category: .places),
        .init(word: "Estação de trem", category: .places),

        .init(word: "Guarda-chuva", category: .objects),
        .init(word: "Bicicleta", category: .objects),
        .init(word: "Pipoca", category: .objects),
        .init(word: "Sorvete", category: .objects),
        .init(word: "Foguete", category: .objects),
        .init(word: "Trem", category: .objects),
        .init(word: "Bolo", category: .objects),
        .init(word: "Robô", category: .objects),
        .init(word: "Violão", category: .objects),
        .init(word: "Janela", category: .objects),
        .init(word: "Barco", category: .objects),

        .init(word: "Astronauta", category: .nature),
        .init(word: "Chuva", category: .nature),
        .init(word: "Girassol", category: .nature),
        .init(word: "Planeta", category: .nature),
        .init(word: "Nuvem", category: .nature),
        .init(word: "Arco-íris", category: .nature),
        .init(word: "Floresta", category: .nature),
        .init(word: "Onda", category: .nature),
        .init(word: "Vulcão", category: .nature),
        .init(word: "Estrela", category: .nature)
    ]

    func cards(in category: DetectiveCategory) -> [DetectiveCard] {
        cards.filter { $0.category == category }
    }

    func drawCard(excluding used: Set<String>, category: DetectiveCategory? = nil, seed: Int) -> DetectiveCard? {
        let available = cards.filter { card in
            !used.contains(card.id) && (category.map { card.category == $0 } ?? true)
        }
        guard !available.isEmpty else { return nil }
        return available[Int(seed.magnitude % UInt(available.count))]
    }

    func draw(excluding used: Set<String>, seed: Int) -> String? {
        drawCard(excluding: used, seed: seed)?.word
    }
}

@MainActor
final class DetectiveMotion: ObservableObject {
    @Published private(set) var direction: Int?
    private let manager = CMMotionManager()
    private var gate = TiltGate()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 0.12
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion,
                  let event = self.gate.sample(pitch: motion.attitude.pitch, at: .now) else { return }
            self.direction = event
        }
    }

    func stop() { if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() } }
    func consume() { direction = nil }
}

struct TiltGate {
    private(set) var isNeutral = true
    private(set) var lastEvent: Date = .distantPast
    var threshold: Double = 0.72
    var cooldown: TimeInterval = 0.8

    mutating func sample(pitch: Double, at date: Date) -> Int? {
        if abs(pitch) < threshold * 0.45 { isNeutral = true; return nil }
        guard isNeutral, date.timeIntervalSince(lastEvent) >= cooldown, abs(pitch) >= threshold else { return nil }
        isNeutral = false
        lastEvent = date
        return pitch > 0 ? 1 : -1
    }
}

struct DetectiveHome: View {
    @State private var playing = false
    @State private var used: Set<String> = []
    @State private var currentCard = DetectiveCard(word: "Capivara", category: .animals)
    @State private var selectedCategory: DetectiveCategory?
    @State private var score = 0
    @State private var passed = 0
    @State private var roundStartedAt = Date.now
    @State private var gameFinished = false
    @StateObject private var motion = DetectiveMotion()
    private let deck = DetectiveDeck()
    private let accent = Color(red: 0.96, green: 0.75, blue: 0.22)
    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack {
            Group {
                if capture == "result" || gameFinished { resultView }
                else if capture == "game" || playing { gameView }
                else { homeView }
            }
            .toolbar {
                if playing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Sair", systemImage: "xmark") { playing = false }
                    }
                }
            }
        }
        .tint(Color(red: 0.18, green: 0.28, blue: 0.52))
        .onAppear {
            if capture == "game" && !playing { startRound() }
            if capture == "result" { score = 8; passed = 2; gameFinished = true }
        }
        .onChange(of: playing) { _, active in
            if active { motion.start() } else { motion.stop() }
        }
        .onChange(of: motion.direction) { _, direction in
            guard let direction else { return }
            motion.consume()
            advance(correct: direction == 1)
        }
        .task(id: playing) {
            guard playing else { return }
            motion.start()
            while !Task.isCancelled {
                if Date.now.timeIntervalSince(roundStartedAt) >= 60 { finishRound(); break }
                do { try await Task.sleep(for: .milliseconds(180)) } catch { break }
            }
            motion.stop()
        }
    }

    private var homeView: some View {
        VStack(alignment: .leading, spacing: 22) {
            FactoryHeader(eyebrow: "Jogo de grupo", title: "O que está na minha testa?", subtitle: "Descubra a palavra com as pistas da turma. Incline ou use os botões — sem cadastro e sem internet.", accent: accent)
            FactoryDemoNotice(message: "Baralho demonstrativo · \(deck.cards.count) palavras · conteúdo local")
            FactoryPanel {
                ZStack {
                    RoundedRectangle(cornerRadius: 22).fill(Color(red: 0.10, green: 0.16, blue: 0.30))
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles").font(.system(size: 34)).foregroundStyle(accent)
                        Text("CAPIVARA").font(.system(size: 31, weight: .black, design: .rounded)).foregroundStyle(.white)
                        Text("Dê pistas sem falar a palavra") .font(.subheadline).foregroundStyle(.white.opacity(0.76))
                    }
                }.frame(height: 190)
                HStack(spacing: 12) {
                    FactoryMetric(label: "Categorias", value: "\(DetectiveCategory.allCases.count)", symbol: "square.grid.2x2.fill", tint: accent)
                    FactoryMetric(label: "Tempo", value: "60 s", symbol: "timer", tint: .blue)
                }
                Button { startRound() } label: { Label("Jogar agora", systemImage: "play.fill") }
                    .buttonStyle(FactoryPrimaryButtonStyle())
            }
            FactoryPanel(title: "Tema da rodada", systemImage: "square.grid.2x2.fill") {
                Menu {
                    Button("Misturado · \(deck.cards.count) palavras") { selectedCategory = nil }
                    ForEach(DetectiveCategory.allCases) { category in
                        Button("\(category.rawValue) · \(deck.cards(in: category).count) palavras") {
                            selectedCategory = category
                        }
                    }
                } label: {
                    Label(selectedCategory?.rawValue ?? "Misturado · \(deck.cards.count) palavras", systemImage: selectedCategory?.symbol ?? "shuffle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("detective-category-menu")
                Text("Misturado usa o baralho todo. Um tema específico encerra a rodada quando as palavras daquele tema acabam.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            FactoryPanel(title: "Como funciona", systemImage: "lightbulb.fill") {
                Text("Incline para baixo para acertar e para cima para passar. Também é possível jogar no iPad apoiado sobre a mesa usando os controles grandes.")
                    .foregroundStyle(.secondary)
            }
        }
        .factoryPage().navigationTitle("Detetive na Testa").navigationBarTitleDisplayMode(.inline)
    }

    private var gameView: some View {
        VStack(spacing: 22) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack {
                    Label("\(max(60 - Int(context.date.timeIntervalSince(roundStartedAt)), 0))s", systemImage: "timer").font(.headline.monospacedDigit())
                    Spacer()
                    Text("\(score) acertos  ·  \(passed) pulos").font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 20).padding(.top, 16)
            Spacer(minLength: 10)
            FactoryDemoNotice(message: "DEMONSTRAÇÃO · palavra local")
            Label(currentCard.category.rawValue.uppercased(), systemImage: currentCard.category.symbol)
                .font(.caption.bold()).tracking(1.2).foregroundStyle(.secondary)
            Text(currentCard.word.uppercased())
                .font(.system(size: 44, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.55)
                .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.30))
                .frame(maxWidth: 720, minHeight: 230)
                .frame(maxWidth: .infinity)
                .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
                .padding(.horizontal, 20)
                .accessibilityIdentifier("current-card")
            Text("Incline para baixo para acertar ou para cima para passar. Os botões funcionam em qualquer posição.")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 10)
            HStack(spacing: 14) {
                Button { advance(correct: false) } label: { Label("Passar", systemImage: "arrow.up") }
                    .buttonStyle(.bordered).tint(.secondary).frame(maxWidth: .infinity).frame(height: 58)
                Button { advance(correct: true) } label: { Label("Acertou", systemImage: "checkmark") }
                    .buttonStyle(FactoryPrimaryButtonStyle()).tint(Color(red: 0.16, green: 0.48, blue: 0.37))
            }
            .padding(.horizontal, 20).padding(.bottom, 18)
        }
        .background(Color(red: 0.96, green: 0.95, blue: 0.91).ignoresSafeArea())
        .navigationTitle("Rodada")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 20) {
            FactoryHeader(eyebrow: "Fim da rodada", title: "Boa diversão!", subtitle: "Confira o resultado da sua sessão demonstrativa.", accent: accent)
            FactoryDemoNotice()
            HStack(spacing: 12) {
                FactoryMetric(label: "Acertos", value: "\(score)", symbol: "checkmark.circle.fill", tint: .green)
                FactoryMetric(label: "Passes", value: "\(passed)", symbol: "arrowshape.turn.up.right.fill", tint: .orange)
            }
            FactoryPanel(title: "Resumo da rodada", systemImage: "list.bullet.rectangle") {
                Text("Tema: \(selectedCategory?.rawValue ?? "Misturado") · \(used.count) palavras vistas")
                    .font(.subheadline.weight(.semibold))
                Text("As palavras e pontuações são dados de demonstração, mantidos apenas nesta sessão.")
                    .foregroundStyle(.secondary)
            }
            Button { startRound() } label: { Label("Jogar outra rodada", systemImage: "arrow.clockwise") }
                .buttonStyle(FactoryPrimaryButtonStyle())
        }.factoryPage().navigationTitle("Resultado").navigationBarTitleDisplayMode(.inline)
    }

    private func startRound() {
        used = []; score = 0; passed = 0; gameFinished = false; roundStartedAt = .now
        guard let firstCard = deck.drawCard(excluding: used, category: selectedCategory, seed: 0) else {
            finishRound()
            return
        }
        currentCard = firstCard
        used.insert(firstCard.id)
        playing = true
    }

    private func advance(correct: Bool) {
        if correct { score += 1 } else { passed += 1 }
        if let next = deck.drawCard(excluding: used, category: selectedCategory, seed: score + passed + used.count * 3) {
            currentCard = next
            used.insert(next.id)
        } else { finishRound() }
    }

    private func finishRound() { playing = false; gameFinished = true; motion.stop() }
}
