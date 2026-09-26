import SwiftUI

@main
struct CrimeIdleApp: App {
    var body: some Scene { WindowGroup { CrimeIdleHome() } }
}

struct CrimeEconomy: Codable, Equatable {
    static let cap: TimeInterval = 8 * 60 * 60
    static let baseCosts: [Double] = [25, 80, 220, 600, 1_500, 4_000]
    private(set) var influence: Double = 100
    private(set) var owned = Array(repeating: 0, count: 6)
    private(set) var claimedMissions: Set<Int> = []
    private(set) var lastSavedAt: Date = .now

    var incomePerSecond: Double { owned.enumerated().reduce(0) { $0 + Double($1.element) * Double($1.offset + 1) * 0.35 } }

    mutating func buy(_ index: Int, at date: Date = .now) -> Bool {
        guard owned.indices.contains(index) else { return false }
        let cost = Self.baseCosts[index] * pow(1.16, Double(owned[index]))
        guard influence >= cost else { return false }
        influence -= cost
        owned[index] += 1
        lastSavedAt = date
        return true
    }

    mutating func tap(at date: Date = .now) { influence += 1; lastSavedAt = date }

    mutating func accrue(seconds: TimeInterval, at date: Date = .now) {
        if seconds > 0 { influence += incomePerSecond * min(seconds, Self.cap) }
        lastSavedAt = date
    }

    mutating func resume(at date: Date = .now) {
        accrue(seconds: date.timeIntervalSince(lastSavedAt), at: date)
    }

    mutating func claimMission(_ id: Int) -> Bool {
        guard !claimedMissions.contains(id) else { return false }
        let complete: Bool
        switch id {
        case 0: complete = influence >= 150
        case 1: complete = owned.reduce(0, +) >= 2
        case 2: complete = owned[0] >= 3
        default: complete = false
        }
        guard complete else { return false }
        claimedMissions.insert(id)
        influence += 25
        lastSavedAt = .now
        return true
    }

    static func load(defaults: UserDefaults = .standard) -> CrimeEconomy {
        guard let data = defaults.data(forKey: "crime.save"), let value = try? JSONDecoder().decode(CrimeEconomy.self, from: data) else { return CrimeEconomy() }
        return value
    }

    func persist(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "crime.save")
    }
}

struct CrimeIdleHome: View {
    @State private var game = CrimeEconomy.load()
    @State private var activeTab = 0
    @Environment(\.scenePhase) private var scenePhase
    private let accent = Color(red: 0.82, green: 0.64, blue: 0.31)
    private let businesses = ["Café Aurora", "Estúdio Nocturno", "Táxi Estelar", "Clube Neblina", "Teatro Eclipse", "Hotel Horizonte"]
    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack {
            Group {
                if capture == "businesses" || activeTab == 1 { businessView }
                else if capture == "missions" || activeTab == 2 { missionView }
                else { headquarters }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) { Image(systemName: "moon.stars.fill"); Text("CIDADE NEBLINA") }
                        .font(.caption.weight(.bold)).tracking(1.3).foregroundStyle(accent)
                }
            }
            .safeAreaInset(edge: .bottom) { navigationBar }
        }
        .tint(accent)
        .task {
            game.resume()
            game.persist()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                game.accrue(seconds: 1)
            }
        }
        .onChange(of: game) { _, updated in updated.persist() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { game.resume(); game.persist() }
        }
    }

    private var headquarters: some View {
        VStack(alignment: .leading, spacing: 22) {
            FactoryHeader(eyebrow: "Uma cidade fictícia", title: "A noite é sua.", subtitle: "Construa um império de entretenimento em uma história noir leve e inventada.", accent: accent)
            FactoryDemoNotice(message: "Ficção demonstrativa · sem atividades reais")
            FactoryPanel {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("INFLUÊNCIA").font(.caption.bold()).tracking(1.4).foregroundStyle(.secondary)
                        Text(game.influence.formatted(.number.precision(.fractionLength(0))))
                            .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                        Text("+\(game.incomePerSecond, specifier: "%.1f") por segundo")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 44)).foregroundStyle(accent.opacity(0.9))
                }
                Button { game.tap() } label: { Label("Expandir influência", systemImage: "plus.circle.fill") }
                    .buttonStyle(FactoryPrimaryButtonStyle())
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FactoryMetric(label: "Empreendimentos", value: "\(game.owned.reduce(0, +))/6", symbol: "building.2.fill", tint: accent)
                FactoryMetric(label: "Bairros", value: "1/3", symbol: "map.fill", tint: .red)
            }
            FactoryPanel(title: "Próximo objetivo", systemImage: "target") {
                Text("Alcance 150 de influência para abrir o próximo distrito.").foregroundStyle(.secondary)
                ProgressView(value: min(game.influence / 150, 1)).tint(accent)
            }
        }
        .factoryPage().navigationTitle("Quartel-general").navigationBarTitleDisplayMode(.inline)
    }

    private var businessView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Expansão", title: "Negócios da cidade", subtitle: "Empreendimentos totalmente fictícios. Compras usam apenas o saldo local.", accent: accent)
            FactoryDemoNotice()
            ForEach(businesses.indices, id: \.self) { index in
                FactoryPanel {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: ["cup.and.saucer.fill", "film.fill", "car.fill", "music.note.house.fill", "theatermasks.fill", "building.fill"][index])
                            .font(.title2).foregroundStyle(accent).frame(width: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(businesses[index]).font(.headline)
                            Text("Nível \(game.owned[index]) · renda demonstrativa")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("\(CrimeEconomy.baseCosts[index] * pow(1.16, Double(game.owned[index])), specifier: "%.0f")") {
                            _ = game.buy(index)
                        }
                        .buttonStyle(.borderedProminent).tint(accent)
                        .disabled(game.influence < CrimeEconomy.baseCosts[index] * pow(1.16, Double(game.owned[index])))
                        .accessibilityLabel("Comprar \(businesses[index])")
                    }
                }
            }
        }
        .factoryPage().navigationTitle("Empreendimentos").navigationBarTitleDisplayMode(.inline)
    }

    private var missionView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Pequenas vitórias", title: "Missões", subtitle: "Objetivos simples para orientar a sua carreira fictícia.", accent: accent)
            FactoryDemoNotice()
            ForEach(Array(["Alcance 150 de influência", "Abra dois empreendimentos", "Expanda o Café Aurora"].enumerated()), id: \.offset) { index, title in
                FactoryPanel {
                    Label(title, systemImage: game.claimedMissions.contains(index) ? "checkmark.seal.fill" : "target").font(.headline)
                    ProgressView(value: missionProgress(index)).tint(accent)
                    Button(game.claimedMissions.contains(index) ? "Recompensa resgatada" : "Resgatar 25 de influência") {
                        _ = game.claimMission(index)
                    }
                    .buttonStyle(.bordered).disabled(game.claimedMissions.contains(index) || missionProgress(index) < 1)
                }
            }
        }
        .factoryPage().navigationTitle("Missões").navigationBarTitleDisplayMode(.inline)
    }

    private var navigationBar: some View {
        HStack(spacing: 10) {
            navButton("Cidade", symbol: "building.2.fill", index: 0)
            navButton("Negócios", symbol: "briefcase.fill", index: 1)
            navButton("Missões", symbol: "flag.fill", index: 2)
        }
        .padding(10)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, 22).padding(.bottom, 8)
    }

    private func navButton(_ title: String, symbol: String, index: Int) -> some View {
        Button { activeTab = index } label: {
            Label(title, systemImage: symbol).font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(activeTab == index ? accent : .secondary)
        }.buttonStyle(.plain)
    }

    private func missionProgress(_ index: Int) -> Double {
        switch index {
        case 0: min(game.influence / 150, 1)
        case 1: min(Double(game.owned.reduce(0, +)) / 2, 1)
        default: min(Double(game.owned[0]) / 3, 1)
        }
    }
}
