import SwiftUI

@main
struct CrimeIdleApp: App {
    var body: some Scene { WindowGroup { CrimeIdleHome() } }
}

struct CrimeBusiness: Identifiable, Equatable {
    let id: Int
    let name: String
    let systemImage: String
    let districtID: Int
    let baseCost: Double

    var baseIncomePerSecond: Double { Double(id + 1) * 0.35 }

    static let catalog: [CrimeBusiness] = [
        .init(id: 0, name: "Café Aurora", systemImage: "cup.and.saucer.fill", districtID: 0, baseCost: 25),
        .init(id: 1, name: "Estúdio Nocturno", systemImage: "film.fill", districtID: 0, baseCost: 80),
        .init(id: 2, name: "Táxi Estelar", systemImage: "car.fill", districtID: 1, baseCost: 220),
        .init(id: 3, name: "Clube Neblina", systemImage: "music.note.house.fill", districtID: 1, baseCost: 600),
        .init(id: 4, name: "Teatro Eclipse", systemImage: "theatermasks.fill", districtID: 2, baseCost: 1_500),
        .init(id: 5, name: "Hotel Horizonte", systemImage: "building.fill", districtID: 2, baseCost: 4_000)
    ]
}

enum CrimeMissionGoal: Equatable {
    case influence(Double)
    case totalBusinesses(Int)
    case businessOwned(index: Int, count: Int)
    case districts(Int)
    case incomePerSecond(Double)
}

struct CrimeMission: Identifiable, Equatable {
    let id: Int
    let title: String
    let goal: CrimeMissionGoal
    var reward: Double = 25

    static let catalog: [CrimeMission] = [
        .init(id: 0, title: "Alcance 150 de influência", goal: .influence(150)),
        .init(id: 1, title: "Abra dois empreendimentos", goal: .totalBusinesses(2)),
        .init(id: 2, title: "Expanda o Café Aurora", goal: .businessOwned(index: 0, count: 3)),
        .init(id: 3, title: "Alcance 500 de influência", goal: .influence(500)),
        .init(id: 4, title: "Abra cinco negócios", goal: .totalBusinesses(5)),
        .init(id: 5, title: "Compre o Hotel Horizonte", goal: .businessOwned(index: 5, count: 1)),
        .init(id: 6, title: "Abra um novo distrito", goal: .districts(2)),
        .init(id: 7, title: "Produza 5 de influência/s", goal: .incomePerSecond(5)),
        .init(id: 8, title: "Tenha 12 negócios", goal: .totalBusinesses(12)),
        .init(id: 9, title: "Alcance 2.000 de influência", goal: .influence(2_000)),
        .init(id: 10, title: "Abra todos os distritos", goal: .districts(3)),
        .init(id: 11, title: "Construa 20 negócios", goal: .totalBusinesses(20))
    ]

    func progress(in economy: CrimeEconomy) -> Double {
        switch goal {
        case let .influence(target):
            return min(economy.influence / target, 1)
        case let .totalBusinesses(target):
            return min(Double(economy.owned.reduce(0, +)) / Double(target), 1)
        case let .businessOwned(index, count):
            guard economy.owned.indices.contains(index) else { return 0 }
            return min(Double(economy.owned[index]) / Double(count), 1)
        case let .districts(target):
            guard target > 1 else { return economy.unlockedDistricts >= target ? 1 : 0 }
            return min(Double(max(economy.unlockedDistricts - 1, 0)) / Double(target - 1), 1)
        case let .incomePerSecond(target):
            return min(economy.incomePerSecond / target, 1)
        }
    }

    func isComplete(in economy: CrimeEconomy) -> Bool { progress(in: economy) >= 1 }
}

struct CrimeEconomy: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case influence
        case owned
        case claimedMissions
        case unlockedDistricts
        case lastSavedAt
    }

    static let cap: TimeInterval = 8 * 60 * 60
    static let businesses = CrimeBusiness.catalog
    static let districtNames = ["Centro das Lanternas", "Rua da Neblina", "Colinas do Norte"]
    static let districtSymbols = ["sun.max.fill", "cloud.fog.fill", "mountain.2.fill"]
    static let districtUnlockCosts: [Double] = [0, 500, 2_000]
    static var baseCosts: [Double] { businesses.map(\.baseCost) }

    private(set) var influence: Double = 100
    private(set) var owned = Array(repeating: 0, count: CrimeBusiness.catalog.count)
    private(set) var claimedMissions: Set<Int> = []
    private(set) var unlockedDistricts = 1
    private(set) var lastSavedAt: Date = .now

    init() { }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedInfluence = try container.decodeIfPresent(Double.self, forKey: .influence) ?? 100
        let decodedOwned = try container.decodeIfPresent([Int].self, forKey: .owned) ?? []
        var normalizedOwned = Array(repeating: 0, count: Self.businesses.count)
        for index in 0..<min(decodedOwned.count, normalizedOwned.count) {
            normalizedOwned[index] = max(decodedOwned[index], 0)
        }
        let highestOwnedDistrict = Self.businesses.indices
            .filter { normalizedOwned[$0] > 0 }
            .map { Self.businesses[$0].districtID + 1 }
            .max() ?? 1
        let decodedDistricts = try container.decodeIfPresent(Int.self, forKey: .unlockedDistricts) ?? 1

        influence = decodedInfluence.isFinite ? max(decodedInfluence, 0) : 100
        owned = normalizedOwned
        claimedMissions = try container.decodeIfPresent(Set<Int>.self, forKey: .claimedMissions) ?? []
        unlockedDistricts = min(Self.districtNames.count, max(1, max(decodedDistricts, highestOwnedDistrict)))
        lastSavedAt = try container.decodeIfPresent(Date.self, forKey: .lastSavedAt) ?? .now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(influence, forKey: .influence)
        try container.encode(owned, forKey: .owned)
        try container.encode(claimedMissions, forKey: .claimedMissions)
        try container.encode(unlockedDistricts, forKey: .unlockedDistricts)
        try container.encode(lastSavedAt, forKey: .lastSavedAt)
    }

    var districtMultiplier: Double { 1 + Double(max(unlockedDistricts - 1, 0)) * 0.25 }

    var incomePerSecond: Double {
        Self.businesses.reduce(0) { $0 + incomeFromBusinessPerSecond($1.id) }
    }

    func incomeFromBusinessPerSecond(_ index: Int) -> Double {
        guard owned.indices.contains(index) else { return 0 }
        return Double(owned[index]) * Self.businesses[index].baseIncomePerSecond * districtMultiplier
    }

    static func requiredDistrict(forBusiness index: Int) -> Int? {
        guard businesses.indices.contains(index) else { return nil }
        return businesses[index].districtID + 1
    }

    func purchaseCost(forBusiness index: Int, quantity: Int = 1) -> Double? {
        guard owned.indices.contains(index), (1...10).contains(quantity) else { return nil }
        let baseCost = Self.businesses[index].baseCost
        return (0..<quantity).reduce(0) { total, offset in
            total + baseCost * pow(1.16, Double(owned[index] + offset))
        }
    }

    func canBuy(_ index: Int, quantity: Int = 1) -> Bool {
        guard let requiredDistrict = Self.requiredDistrict(forBusiness: index),
              requiredDistrict <= unlockedDistricts,
              let cost = purchaseCost(forBusiness: index, quantity: quantity) else { return false }
        return influence >= cost
    }

    mutating func buy(_ index: Int, quantity: Int = 1, at date: Date = .now) -> Bool {
        guard canBuy(index, quantity: quantity),
              let cost = purchaseCost(forBusiness: index, quantity: quantity) else { return false }
        influence -= cost
        owned[index] += quantity
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

    func missionProgress(_ id: Int) -> Double {
        CrimeMission.catalog.first(where: { $0.id == id })?.progress(in: self) ?? 0
    }

    func canClaimMission(_ id: Int) -> Bool {
        guard !claimedMissions.contains(id), let mission = CrimeMission.catalog.first(where: { $0.id == id }) else { return false }
        return mission.isComplete(in: self)
    }

    mutating func claimMission(_ id: Int, at date: Date = .now) -> Bool {
        guard canClaimMission(id), let mission = CrimeMission.catalog.first(where: { $0.id == id }) else { return false }
        claimedMissions.insert(id)
        influence += mission.reward
        lastSavedAt = date
        return true
    }

    mutating func unlockDistrict(_ index: Int, at date: Date = .now) -> Bool {
        guard Self.districtUnlockCosts.indices.contains(index), index == unlockedDistricts,
              influence >= Self.districtUnlockCosts[index] else { return false }
        influence -= Self.districtUnlockCosts[index]
        unlockedDistricts += 1
        lastSavedAt = date
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
    @State private var buyQuantity = 1
    @Environment(\.scenePhase) private var scenePhase
    private let accent = Color(red: 0.82, green: 0.64, blue: 0.31)
    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack {
            Group {
                if capture == "businesses" || activeTab == 1 { businessView }
                else if capture == "missions" || activeTab == 2 { missionView }
                else if capture == "districts" || activeTab == 3 { districtsView }
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
        .preferredColorScheme(.dark)
        .task {
            if FactoryCapture.isUITesting {
                FactoryCapture.resetAppDefaults()
                game = CrimeEconomy()
            } else if let capture, ["businesses", "missions", "districts"].contains(capture) {
                game = capturePreview(for: capture)
                buyQuantity = capture == "businesses" ? 10 : 1
            }
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
                FactoryMetric(label: "Bairros", value: "\(game.unlockedDistricts)/3", symbol: "map.fill", tint: .red)
                FactoryMetric(label: "Multiplicador", value: "×\(String(format: "%.2f", game.districtMultiplier))", symbol: "arrow.up.right", tint: .green)
            }
            FactoryPanel(title: "Próximo objetivo", systemImage: "target") {
                if game.unlockedDistricts < CrimeEconomy.districtNames.count {
                    let nextDistrict = game.unlockedDistricts
                    let cost = CrimeEconomy.districtUnlockCosts[nextDistrict]
                    Text("Abra \(CrimeEconomy.districtNames[nextDistrict]) com \(cost.formatted(.number.precision(.fractionLength(0)))) de influência.")
                        .foregroundStyle(.secondary)
                    ProgressView(value: min(game.influence / cost, 1)).tint(accent)
                } else {
                    Text("Todos os bairros estão abertos. Alcance 12 negócios para a próxima missão.")
                        .foregroundStyle(.secondary)
                    ProgressView(value: min(Double(game.owned.reduce(0, +)) / 12, 1)).tint(accent)
                }
            }
        }
        .factoryPage().navigationTitle("Quartel-general").navigationBarTitleDisplayMode(.inline)
    }

    private func capturePreview(for screen: String) -> CrimeEconomy {
        var preview = CrimeEconomy()
        let captureDate = Date.now
        for _ in 0..<10_000 { preview.tap(at: captureDate) }
        _ = preview.unlockDistrict(1, at: captureDate)

        if screen == "districts" {
            _ = preview.unlockDistrict(2, at: captureDate)
            _ = preview.buy(0, quantity: 3, at: captureDate)
            _ = preview.buy(1, quantity: 2, at: captureDate)
            _ = preview.buy(2, quantity: 1, at: captureDate)
            _ = preview.buy(3, quantity: 1, at: captureDate)
        } else {
            _ = preview.buy(0, quantity: 3, at: captureDate)
            _ = preview.buy(1, quantity: 2, at: captureDate)
            if screen == "businesses" { _ = preview.buy(2, quantity: 1, at: captureDate) }
            if screen == "missions" {
                _ = preview.claimMission(0, at: captureDate)
                _ = preview.buy(2, quantity: 1, at: captureDate)
            }
        }
        preview.accrue(seconds: 0, at: .now)
        return preview
    }

    private var businessView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Expansão", title: "Negócios da cidade", subtitle: "Empreendimentos totalmente fictícios. Compras usam apenas o saldo local.", accent: accent)
            FactoryDemoNotice()
            FactoryPanel(title: "Compra rápida", systemImage: "cart.fill") {
                Picker("Quantidade", selection: $buyQuantity) {
                    Text("×1").tag(1)
                    Text("×10").tag(10)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("business-buy-quantity")
                Text("A compra em lote é atômica: o saldo precisa cobrir todas as unidades selecionadas.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(CrimeEconomy.businesses) { business in
                let requiredDistrict = business.districtID + 1
                let districtIsOpen = requiredDistrict <= game.unlockedDistricts
                let purchaseCost = game.purchaseCost(forBusiness: business.id, quantity: buyQuantity)
                FactoryPanel {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: business.systemImage)
                            .font(.title2).foregroundStyle(accent).frame(width: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(business.name).font(.headline)
                            Text("Nível \(game.owned[business.id]) · \(CrimeEconomy.districtNames[business.districtID])")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("\(game.incomeFromBusinessPerSecond(business.id), specifier: "%.2f") influência/s · cidade ×\(game.districtMultiplier, specifier: "%.2f")")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            _ = game.buy(business.id, quantity: buyQuantity)
                        } label: {
                            VStack(spacing: 2) {
                                Text(purchaseCost?.formatted(.number.precision(.fractionLength(0))) ?? "—")
                                Text("Comprar ×\(buyQuantity)").font(.caption2)
                            }
                        }
                        .buttonStyle(.borderedProminent).tint(accent)
                        .disabled(!game.canBuy(business.id, quantity: buyQuantity))
                        .accessibilityLabel("Comprar \(business.name), quantidade \(buyQuantity)")
                        .accessibilityIdentifier("buy-business-\(business.id)")
                    }
                    if !districtIsOpen {
                        Label("Desbloqueie \(CrimeEconomy.districtNames[business.districtID]) no mapa", systemImage: "lock.fill")
                            .font(.caption).foregroundStyle(.orange)
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
            ForEach(CrimeMission.catalog) { mission in
                let progress = game.missionProgress(mission.id)
                FactoryPanel {
                    Label(mission.title, systemImage: game.claimedMissions.contains(mission.id) ? "checkmark.seal.fill" : "target").font(.headline)
                    ProgressView(value: progress).tint(accent)
                    Button(game.claimedMissions.contains(mission.id) ? "Recompensa resgatada" : "Resgatar \(mission.reward.formatted(.number.precision(.fractionLength(0)))) de influência") {
                        _ = game.claimMission(mission.id)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!game.canClaimMission(mission.id))
                    .accessibilityIdentifier("claim-mission-\(mission.id)")
                }
            }
        }
        .factoryPage().navigationTitle("Missões").navigationBarTitleDisplayMode(.inline)
    }

    private var districtsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Mapa fictício", title: "Distritos", subtitle: "Expanda a cidade ao atingir os requisitos de influência.", accent: accent)
            FactoryDemoNotice(message: "Cidade inventada · progresso salvo localmente")
            FactoryPanel(title: "Efeito da expansão", systemImage: "arrow.up.right") {
                Text("Bairros abertos: \(game.unlockedDistricts)/\(CrimeEconomy.districtNames.count)")
                Text("Multiplicador da cidade: ×\(game.districtMultiplier, specifier: "%.2f")")
                    .font(.title3.bold()).foregroundStyle(accent)
                Text("Cada novo bairro aumenta a renda de todos os negócios.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(CrimeEconomy.districtNames.indices, id: \.self) { index in
                let districtName = CrimeEconomy.districtNames[index]
                let cost = CrimeEconomy.districtUnlockCosts[index]
                let isOpen = index < game.unlockedDistricts
                FactoryPanel {
                    HStack(spacing: 14) {
                        Image(systemName: CrimeEconomy.districtSymbols[index]).font(.title2).foregroundStyle(accent).frame(width: 42)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(districtName).font(.headline)
                            Text(isOpen ? "Aberto · produção da cidade ×\(game.districtMultiplier, specifier: "%.2f")" : "Requisito: \(cost.formatted(.number.precision(.fractionLength(0)))) de influência")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if isOpen { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        else {
                            Button("Abrir") { _ = game.unlockDistrict(index) }
                                .buttonStyle(.borderedProminent).tint(accent)
                                .disabled(index != game.unlockedDistricts || game.influence < cost)
                        }
                    }
                }
            }
            Text("Desbloqueios são compras fictícias do progresso do jogo, sem pagamento ou compra no app.")
                .font(.footnote).foregroundStyle(.secondary)
        }.factoryPage().navigationTitle("Mapa da cidade").navigationBarTitleDisplayMode(.inline)
    }

    private var navigationBar: some View {
        HStack(spacing: 4) {
            navButton("Cidade", symbol: "building.2.fill", index: 0)
            navButton("Negócios", symbol: "briefcase.fill", index: 1)
            navButton("Missões", symbol: "flag.fill", index: 2)
            navButton("Mapa", symbol: "map.fill", index: 3)
        }
        .padding(10)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, 10).padding(.bottom, 8)
    }

    private func navButton(_ title: String, symbol: String, index: Int) -> some View {
        Button { activeTab = index } label: {
            Label(title, systemImage: symbol).font(.caption2.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(activeTab == index ? accent : .secondary)
        }
        .accessibilityLabel(title)
        .accessibilityValue(activeTab == index ? "Selecionado" : "")
        .buttonStyle(.plain)
    }

}
