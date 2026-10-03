import SwiftUI

@main
struct CrimeIdleApp: App {
    var body: some Scene { WindowGroup { CrimeIdleHome() } }
}

struct CrimeStoryOption: Equatable {
    let title: String
    let description: String
    let cashCost: Double
    let cashReward: Double
    let reputationReward: Double
}

struct CrimeStoryChapter: Equatable {
    let title: String
    let scene: String
    let requirement: String
    let options: [CrimeStoryOption]
}

enum CrimeCampaign {
    static let chapters = [
        CrimeStoryChapter(
            title: "A primeira luz",
            scene: "A chuva parou, mas o Café Aurora ainda está vazio. Sua sócia Lia sugere uma inauguração que faça a cidade olhar para esta esquina.",
            requirement: "Abra o Café Aurora para começar.",
            options: [
                CrimeStoryOption(title: "Festival das Lanternas", description: "Invista 30 de caixa. O Café Aurora ganha +35% de renda.", cashCost: 30, cashReward: 0, reputationReward: 40),
                CrimeStoryOption(title: "Noite intimista", description: "Ganhe 100 de caixa e 30 de reputação. O Estúdio Nocturno ganha +35% de renda.", cashCost: 0, cashReward: 100, reputationReward: 30)
            ]
        ),
        CrimeStoryChapter(
            title: "A cidade comenta",
            scene: "A jornalista Maia oferece uma matéria de capa, mas quer saber que tipo de lugar sua rede vai se tornar: um palco para a cidade ou uma coleção de endereços exclusivos?",
            requirement: "Abra 3 negócios e a Rua da Neblina.",
            options: [
                CrimeStoryOption(title: "Temporada cultural", description: "Invista 120 de caixa, ganhe 55 de reputação e aumente toda a renda em 15%.", cashCost: 120, cashReward: 0, reputationReward: 55),
                CrimeStoryOption(title: "Rede independente", description: "Invista 40, receba 80 de caixa e 40 de reputação. As próximas compras custam 15% menos.", cashCost: 40, cashReward: 80, reputationReward: 40)
            ]
        ),
        CrimeStoryChapter(
            title: "Luzes no alto",
            scene: "Com a cidade prestando atenção, chega a hora de escolher o próximo capítulo: um grande salão no norte ou um circuito de festivais que percorra os bairros.",
            requirement: "Expanda para a Rua da Neblina e tenha 5 negócios.",
            options: [
                CrimeStoryOption(title: "Abrir o salão do norte", description: "Invista 350 de caixa, ganhe 100 de reputação e dê +50% de renda ao Hotel Horizonte.", cashCost: 350, cashReward: 0, reputationReward: 100),
                CrimeStoryOption(title: "Circuito de festivais", description: "Invista 200, receba 100 de caixa e 75 de reputação; os projetos futuros rendem +25% de caixa.", cashCost: 200, cashReward: 100, reputationReward: 75)
            ]
        )
    ]
}

struct CrimeEconomy: Codable, Equatable {
    static let cap: TimeInterval = 8 * 60 * 60
    static let baseCosts: [Double] = [25, 80, 220, 600, 1_500, 4_000]
    static let baseIncome: [Double] = [0.35, 1.2, 4, 14, 55, 240]
    static let upgradeBaseCosts: [Double] = [125, 400, 1_100, 3_000, 7_500, 20_000]
    static let projectCosts: [Double] = [35, 125, 300]
    static let projectCashRewards: [Double] = [90, 260, 650]
    static let projectReputationRewards: [Double] = [8, 20, 45]
    static let missionCashRewards: [Double] = [25, 75, 200, 500]
    static let missionReputationRewards: [Double] = [5, 10, 20, 35]
    static let achievementRewards: [Double] = [40, 120, 200, 250, 750]
    private static let districtCashCosts: [Double] = [0, 180, 800]
    private static let districtReputationCosts: [Double] = [0, 25, 100]

    private(set) var cash: Double = 100
    private(set) var reputation: Double = 0
    private(set) var owned = Array(repeating: 0, count: 6)
    private(set) var upgradeLevels = Array(repeating: 0, count: 6)
    private(set) var claimedMissions: Set<Int> = []
    private(set) var claimedAchievements: Set<Int> = []
    private(set) var completedProjects: Set<Int> = []
    private(set) var storyChoices: [Int: Int] = [:]
    private(set) var unlockedDistricts = 1
    private(set) var lastSavedAt: Date = .now

    var businessDistrictMultiplier: Double { unlockedDistricts >= 2 ? 1.25 : 1 }
    var projectRewardMultiplier: Double {
        (unlockedDistricts >= 3 ? 1.2 : 1) * (storyChoices[2] == 1 ? 1.25 : 1)
    }
    var businessCostMultiplier: Double { storyChoices[1] == 1 ? 0.85 : 1 }
    var incomePerSecond: Double {
        owned.indices.reduce(0.0) { result, index in
            result + Double(owned[index]) * Self.baseIncome[index] * pow(2, Double(upgradeLevels[index])) * storyIncomeMultiplier(for: index)
        } * businessDistrictMultiplier * (storyChoices[1] == 0 ? 1.15 : 1)
    }
    var totalBusinesses: Int { owned.reduce(0, +) }
    var currentStoryChapter: Int { (0..<CrimeCampaign.chapters.count).first(where: { storyChoices[$0] == nil }) ?? CrimeCampaign.chapters.count }

    func businessIncome(for index: Int) -> Double {
        guard owned.indices.contains(index) else { return 0 }
        return Double(owned[index]) * Self.baseIncome[index] * pow(2, Double(upgradeLevels[index])) *
            storyIncomeMultiplier(for: index) * businessDistrictMultiplier * (storyChoices[1] == 0 ? 1.15 : 1)
    }

    func storyIncomeMultiplier(for business: Int) -> Double {
        (storyChoices[0] == 0 && business == 0 ? 1.35 : 1) *
        (storyChoices[0] == 1 && business == 1 ? 1.35 : 1) *
        (storyChoices[2] == 0 && business == 5 ? 1.5 : 1)
    }

    func cost(for index: Int) -> Double {
        guard owned.indices.contains(index) else { return .infinity }
        return Self.baseCosts[index] * pow(1.16, Double(owned[index])) * businessCostMultiplier
    }

    func upgradeCost(for index: Int) -> Double {
        guard owned.indices.contains(index), upgradeLevels[index] < 2 else { return .infinity }
        return Self.upgradeBaseCosts[index] * pow(4, Double(upgradeLevels[index])) * businessCostMultiplier
    }

    func districtCashCost(_ index: Int) -> Double {
        Self.districtCashCosts.indices.contains(index) ? Self.districtCashCosts[index] : .infinity
    }

    func districtReputationCost(_ index: Int) -> Double {
        Self.districtReputationCosts.indices.contains(index) ? Self.districtReputationCosts[index] : .infinity
    }

    func missionProgress(_ id: Int) -> Double {
        switch id {
        case 0: return min(cash / 150, 1)
        case 1: return min(Double(totalBusinesses) / 2, 1)
        case 2: return min(Double(owned[0]) / 3, 1)
        case 3: return min(cash / 500, 1)
        case 4: return min(Double(totalBusinesses) / 5, 1)
        case 5: return min(Double(owned[5]), 1)
        case 6: return min(Double(unlockedDistricts - 1), 1)
        case 7: return min(incomePerSecond / 5, 1)
        case 8: return min(Double(totalBusinesses) / 12, 1)
        case 9: return min(cash / 2_000, 1)
        case 10: return min(Double(unlockedDistricts - 1) / 2, 1)
        case 11: return min(Double(totalBusinesses) / 20, 1)
        default: return 0
        }
    }

    mutating func buyUpgrade(_ index: Int, at date: Date = .now) -> Bool {
        guard owned.indices.contains(index), owned[index] > 0 else { return false }
        let price = upgradeCost(for: index)
        guard cash >= price else { return false }
        cash -= price
        upgradeLevels[index] += 1
        lastSavedAt = date
        return true
    }

    mutating func buy(_ index: Int, at date: Date = .now) -> Bool {
        guard owned.indices.contains(index) else { return false }
        let price = cost(for: index)
        guard cash >= price else { return false }
        cash -= price
        owned[index] += 1
        lastSavedAt = date
        return true
    }

    mutating func tap(at date: Date = .now) { cash += 1; lastSavedAt = date }

    mutating func accrue(seconds: TimeInterval, at date: Date = .now) {
        if seconds > 0 { cash += incomePerSecond * min(seconds, Self.cap) }
        lastSavedAt = date
    }

    mutating func resume(at date: Date = .now) {
        accrue(seconds: date.timeIntervalSince(lastSavedAt), at: date)
    }

    mutating func chooseStory(_ chapter: Int, option: Int, at date: Date = .now) -> Bool {
        guard chapter == currentStoryChapter, CrimeCampaign.chapters.indices.contains(chapter),
              CrimeCampaign.chapters[chapter].options.indices.contains(option), isStoryChapterAvailable(chapter) else { return false }
        let choice = CrimeCampaign.chapters[chapter].options[option]
        guard cash >= choice.cashCost else { return false }
        cash -= choice.cashCost
        cash += choice.cashReward
        reputation += choice.reputationReward
        storyChoices[chapter] = option
        lastSavedAt = date
        return true
    }

    func isStoryChapterAvailable(_ chapter: Int) -> Bool {
        switch chapter {
        case 0: return owned[0] >= 1
        case 1: return unlockedDistricts >= 2 && totalBusinesses >= 3
        case 2: return unlockedDistricts >= 2 && totalBusinesses >= 5
        default: return false
        }
    }

    func canCompleteProject(_ id: Int) -> Bool {
        guard Self.projectCosts.indices.contains(id), !completedProjects.contains(id), cash >= Self.projectCosts[id] else { return false }
        switch id {
        case 0: return owned[0] >= 1
        case 1: return totalBusinesses >= 3 && owned[1] >= 1
        case 2: return unlockedDistricts >= 2 && totalBusinesses >= 5
        default: return false
        }
    }

    mutating func completeProject(_ id: Int, at date: Date = .now) -> Bool {
        guard canCompleteProject(id) else { return false }
        completedProjects.insert(id)
        cash -= Self.projectCosts[id]
        cash += Self.projectCashRewards[id] * projectRewardMultiplier
        reputation += Self.projectReputationRewards[id] * (unlockedDistricts >= 3 ? 1.2 : 1)
        lastSavedAt = date
        return true
    }

    mutating func claimAchievement(_ id: Int, at date: Date = .now) -> Bool {
        guard (0..<5).contains(id), !claimedAchievements.contains(id), isAchievementComplete(id) else { return false }
        claimedAchievements.insert(id)
        cash += Self.achievementRewards[id]
        lastSavedAt = date
        return true
    }

    func isAchievementComplete(_ id: Int) -> Bool {
        switch id {
        case 0: return totalBusinesses >= 1
        case 1: return totalBusinesses >= 5
        case 2: return incomePerSecond >= 5
        case 3: return unlockedDistricts >= 2
        case 4: return incomePerSecond >= 100
        default: return false
        }
    }

    func achievementProgress(_ id: Int) -> Double {
        switch id {
        case 0: return min(Double(totalBusinesses), 1)
        case 1: return min(Double(totalBusinesses) / 5, 1)
        case 2: return min(incomePerSecond / 5, 1)
        case 3: return min(Double(unlockedDistricts - 1), 1)
        case 4: return min(incomePerSecond / 100, 1)
        default: return 0
        }
    }

    mutating func claimMission(_ id: Int, at date: Date = .now) -> Bool {
        guard (0..<12).contains(id), !claimedMissions.contains(id), isMissionComplete(id) else { return false }
        claimedMissions.insert(id)
        let tier = min(id / 3, Self.missionCashRewards.count - 1)
        cash += Self.missionCashRewards[tier]
        reputation += Self.missionReputationRewards[tier]
        lastSavedAt = date
        return true
    }

    func isMissionUnlocked(_ id: Int) -> Bool {
        (0..<12).contains(id)
    }

    func isMissionComplete(_ id: Int) -> Bool {
        switch id {
        case 0: return cash >= 150
        case 1: return totalBusinesses >= 2
        case 2: return owned[0] >= 3
        case 3: return cash >= 500
        case 4: return totalBusinesses >= 5
        case 5: return owned[5] >= 1
        case 6: return unlockedDistricts >= 2
        case 7: return incomePerSecond >= 5
        case 8: return totalBusinesses >= 12
        case 9: return cash >= 2_000
        case 10: return unlockedDistricts >= 3
        case 11: return totalBusinesses >= 20
        default: return false
        }
    }

    func missionCashReward(_ id: Int) -> Double {
        guard (0..<12).contains(id) else { return 0 }
        return Self.missionCashRewards[min(id / 3, Self.missionCashRewards.count - 1)]
    }

    func missionReputationReward(_ id: Int) -> Double {
        guard (0..<12).contains(id) else { return 0 }
        return Self.missionReputationRewards[min(id / 3, Self.missionReputationRewards.count - 1)]
    }

    mutating func unlockDistrict(_ index: Int, at date: Date = .now) -> Bool {
        guard Self.districtCashCosts.indices.contains(index), index == unlockedDistricts,
              cash >= Self.districtCashCosts[index], reputation >= Self.districtReputationCosts[index] else { return false }
        cash -= Self.districtCashCosts[index]
        reputation -= Self.districtReputationCosts[index]
        unlockedDistricts += 1
        lastSavedAt = date
        return true
    }

    private enum CodingKeys: String, CodingKey {
        case cash, influence, reputation, owned, upgradeLevels, claimedMissions, claimedAchievements
        case completedProjects, storyChoices, unlockedDistricts, lastSavedAt
    }

    init() { }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = CrimeEconomy()
        owned = try values.decodeIfPresent([Int].self, forKey: .owned) ?? defaults.owned
        upgradeLevels = try values.decodeIfPresent([Int].self, forKey: .upgradeLevels) ?? defaults.upgradeLevels
        unlockedDistricts = min(max(try values.decodeIfPresent(Int.self, forKey: .unlockedDistricts) ?? 1, 1), 3)
        let legacyInfluence = try values.decodeIfPresent(Double.self, forKey: .influence)
        cash = try values.decodeIfPresent(Double.self, forKey: .cash) ?? legacyInfluence ?? defaults.cash
        reputation = try values.decodeIfPresent(Double.self, forKey: .reputation)
            ?? (unlockedDistricts >= 3 ? 100 : (unlockedDistricts >= 2 ? 25 : 0))
        claimedMissions = try values.decodeIfPresent(Set<Int>.self, forKey: .claimedMissions) ?? []
        claimedAchievements = try values.decodeIfPresent(Set<Int>.self, forKey: .claimedAchievements) ?? []
        completedProjects = try values.decodeIfPresent(Set<Int>.self, forKey: .completedProjects) ?? []
        storyChoices = try values.decodeIfPresent([Int: Int].self, forKey: .storyChoices) ?? [:]
        lastSavedAt = try values.decodeIfPresent(Date.self, forKey: .lastSavedAt) ?? defaults.lastSavedAt
        if owned.count != Self.baseCosts.count { owned = defaults.owned }
        if upgradeLevels.count != Self.baseCosts.count { upgradeLevels = defaults.upgradeLevels }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(cash, forKey: .cash)
        try values.encode(reputation, forKey: .reputation)
        try values.encode(owned, forKey: .owned)
        try values.encode(upgradeLevels, forKey: .upgradeLevels)
        try values.encode(claimedMissions, forKey: .claimedMissions)
        try values.encode(claimedAchievements, forKey: .claimedAchievements)
        try values.encode(completedProjects, forKey: .completedProjects)
        try values.encode(storyChoices, forKey: .storyChoices)
        try values.encode(unlockedDistricts, forKey: .unlockedDistricts)
        try values.encode(lastSavedAt, forKey: .lastSavedAt)
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
    @State private var offlineEarnings: Double = 0
    @State private var showingOfflineSummary = false
    private let accent = Color(red: 0.82, green: 0.64, blue: 0.31)
    private let businesses = ["Café Aurora", "Estúdio Nocturno", "Táxi Estelar", "Clube Neblina", "Teatro Eclipse", "Hotel Horizonte"]
    private var capture: String? { FactoryCapture.screen }
    private var selectedTab: Int {
        switch capture {
        case "businesses": return 1
        case "story", "missions": return 2
        case "districts": return 3
        case "projects", "activities", "achievements": return 4
        default: return activeTab
        }
    }

    private var resourceBar: some View {
        HStack {
            Label("\(Int(game.cash)) caixa", systemImage: "banknote")
            Spacer()
            Label("\(Int(game.reputation)) reputação", systemImage: "star.fill")
        }
        .font(.caption.weight(.semibold)).monospacedDigit()
        .foregroundStyle(accent)
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    var body: some View {
        NavigationStack {
            Group {
                if capture == "businesses" || activeTab == 1 { businessView }
                else if capture == "missions" || capture == "story" || activeTab == 2 { campaignView }
                else if capture == "districts" || activeTab == 3 { districtsView }
                else if capture == "achievements" { achievementsView }
                else if capture == "projects" || capture == "activities" || activeTab == 4 { projectsView }
                else { headquarters }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) { Image(systemName: "moon.stars.fill"); Text("CIDADE NEBLINA") }
                        .font(.caption.weight(.bold)).tracking(1.3).foregroundStyle(accent)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if selectedTab != 0 { resourceBar }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { navigationBar }
        }
        .tint(accent)
        .preferredColorScheme(.dark)
        .task {
            if FactoryCapture.isUITesting {
                FactoryCapture.resetAppDefaults()
                game = CrimeEconomy()
            }
            let beforeResume = game.cash
            game.resume()
            offlineEarnings = game.cash - beforeResume
            showingOfflineSummary = offlineEarnings >= 1
            game.persist()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                game.accrue(seconds: 1)
            }
        }
        .onChange(of: game) { _, updated in updated.persist() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                let beforeResume = game.cash
                game.resume()
                offlineEarnings = game.cash - beforeResume
                showingOfflineSummary = offlineEarnings >= 1
                game.persist()
            }
        }
        .alert("A cidade continuou trabalhando", isPresented: $showingOfflineSummary) {
            Button("Continuar", role: .cancel) { }
        } message: {
            Text("Seus negócios renderam +\(offlineEarnings.formatted(.number.precision(.fractionLength(0)))) de caixa enquanto você estava fora.")
        }
    }

    private var headquarters: some View {
        VStack(alignment: .leading, spacing: 22) {
            FactoryHeader(eyebrow: "Cidade Neblina · Capítulo \(min(game.currentStoryChapter + 1, CrimeCampaign.chapters.count))", title: "A noite é sua.", subtitle: "Comece com uma porta acesa. Cada escolha muda o rumo do seu império de entretenimento.", accent: accent)
            FactoryDemoNotice(message: "Uma história fictícia sobre negócios, cultura e escolhas")
            FactoryPanel {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("CAIXA").font(.caption.bold()).tracking(1.4).foregroundStyle(.secondary)
                        Text(game.cash.formatted(.number.precision(.fractionLength(0))))
                            .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                        Text("+\(game.incomePerSecond, specifier: "%.1f") caixa/s · renda dos negócios")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 44)).foregroundStyle(accent.opacity(0.9))
                }
                Button { game.tap() } label: { Label("Atrair público · +1 caixa", systemImage: "plus.circle.fill") }
                    .buttonStyle(FactoryPrimaryButtonStyle())
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FactoryMetric(label: "Reputação", value: "\(game.reputation.formatted(.number.precision(.fractionLength(0))))", symbol: "star.fill", tint: accent)
                FactoryMetric(label: "Negócios", value: "\(game.totalBusinesses)", symbol: "building.2.fill", tint: .red)
            }
            FactoryPanel(title: "Seu próximo passo", systemImage: "target") {
                if game.totalBusinesses == 0 {
                    Text("Abra o Café Aurora por 25 de caixa. Isso inicia a história e abre as primeiras escolhas.").foregroundStyle(.secondary)
                    ProgressView(value: min(game.cash / 25, 1)).tint(accent)
                } else if game.currentStoryChapter < CrimeCampaign.chapters.count {
                    let chapter = CrimeCampaign.chapters[game.currentStoryChapter]
                    Text("Capítulo: \(chapter.title). \(game.isStoryChapterAvailable(game.currentStoryChapter) ? "Sua decisão já está disponível em História." : chapter.requirement)").foregroundStyle(.secondary)
                } else {
                    Text("A campanha principal foi concluída. Amplie sua rede, abra os distritos restantes e conclua projetos.").foregroundStyle(.secondary)
                }
                Button(game.totalBusinesses == 0 ? "Abrir Negócios" : "Continuar a história") {
                    activeTab = game.totalBusinesses == 0 ? 1 : 2
                }
                .buttonStyle(.borderedProminent).tint(accent)
            }
        }
        .factoryPage().navigationTitle("Quartel-general").navigationBarTitleDisplayMode(.inline)
    }

    private var businessView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Gestão", title: "Negócios da cidade", subtitle: "Cada negócio traz uma fonte de renda e algumas decisões da campanha podem especializá-lo.", accent: accent)
            FactoryDemoNotice()
            ForEach(businesses.indices, id: \.self) { index in
                FactoryPanel {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: ["cup.and.saucer.fill", "film.fill", "car.fill", "music.note.house.fill", "theatermasks.fill", "building.fill"][index])
                            .font(.title2).foregroundStyle(accent).frame(width: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(businesses[index]).font(.headline)
                            Text("Nível \(game.owned[index]) · +\(game.businessIncome(for: index), specifier: "%.2f") caixa/s")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("\(game.cost(for: index), specifier: "%.0f")") {
                            _ = game.buy(index)
                        }
                        .buttonStyle(.borderedProminent).tint(accent)
                        .disabled(game.cash < game.cost(for: index))
                        .accessibilityLabel("Comprar \(businesses[index])")
                    }
                    if game.owned[index] > 0 {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.upgradeLevels[index] >= 2 ? "Melhoria máxima" : "Melhoria de renda · nível \(game.upgradeLevels[index])/2")
                                    .font(.subheadline.weight(.semibold))
                                Text("Cada melhoria dobra a renda deste negócio.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if game.upgradeLevels[index] >= 2 {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                            } else {
                                Button("\(game.upgradeCost(for: index), specifier: "%.0f")") {
                                    _ = game.buyUpgrade(index)
                                }
                                .buttonStyle(.bordered).tint(accent)
                                .disabled(game.cash < game.upgradeCost(for: index))
                                .accessibilityLabel("Melhorar \(businesses[index])")
                            }
                        }
                    }
                }
            }
        }
        .factoryPage().navigationTitle("Empreendimentos").navigationBarTitleDisplayMode(.inline)
    }

    private var campaignView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Campanha narrativa", title: "História", subtitle: "As suas decisões definem que tipo de império cultural a cidade vai conhecer.", accent: accent)
            FactoryDemoNotice(message: "Personagens e lugares fictícios · suas escolhas ficam salvas")
            if game.currentStoryChapter < CrimeCampaign.chapters.count {
                let chapterIndex = game.currentStoryChapter
                let chapter = CrimeCampaign.chapters[chapterIndex]
                FactoryPanel(systemImage: "book.closed.fill") {
                    Text("Capítulo \(chapterIndex + 1) · \(chapter.title)")
                        .font(.headline).accessibilityIdentifier("story.chapter.\(chapterIndex)")
                    Text(chapter.scene).foregroundStyle(.secondary)
                    if game.isStoryChapterAvailable(chapterIndex) {
                        Text("Escolha um rumo. A decisão é permanente e muda bônus futuros.")
                            .font(.subheadline.weight(.semibold))
                        ForEach(chapter.options.indices, id: \.self) { optionIndex in
                            let option = chapter.options[optionIndex]
                            VStack(alignment: .leading, spacing: 8) {
                                Text(option.title).font(.headline)
                                    .accessibilityIdentifier("story.option.\(chapterIndex).\(optionIndex)")
                                Text(option.description).font(.subheadline).foregroundStyle(.secondary)
                                Button("Escolher · custo \(option.cashCost.formatted(.number.precision(.fractionLength(0)))) caixa") {
                                    _ = game.chooseStory(chapterIndex, option: optionIndex)
                                }
                                .buttonStyle(.borderedProminent).tint(accent)
                                .accessibilityIdentifier("story.choose.\(chapterIndex).\(optionIndex)")
                                .disabled(game.cash < option.cashCost)
                                if optionIndex < chapter.options.count - 1 { Divider() }
                            }
                        }
                    } else {
                        Label(chapter.requirement, systemImage: "lock.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(accent)
                    }
                }
            } else {
                FactoryPanel(title: "Uma cidade em movimento", systemImage: "sparkles") {
                    Text("A sua rede já faz parte da história da Neblina. Os bairros ainda guardam espaço para novos projetos.").foregroundStyle(.secondary)
                    Text("Campanha concluída · \(game.storyChoices.count)/\(CrimeCampaign.chapters.count) decisões tomadas")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(accent)
                }
            }

            FactoryPanel(title: "Objetivos paralelos", systemImage: "list.bullet.rectangle") {
                Text("Pequenas metas rendem caixa e reputação para financiar o próximo passo.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(Array(missionNames.enumerated()), id: \.offset) { index, title in
                FactoryPanel {
                    Label(title, systemImage: game.claimedMissions.contains(index) ? "checkmark.seal.fill" : (game.isMissionUnlocked(index) ? "target" : "lock.fill")).font(.headline)
                    ProgressView(value: game.missionProgress(index)).tint(accent)
                    Button(game.claimedMissions.contains(index) ? "Recompensa resgatada" : "Resgatar +\(Int(game.missionCashReward(index))) caixa · +\(Int(game.missionReputationReward(index))) reputação") {
                        _ = game.claimMission(index)
                    }
                    .buttonStyle(.bordered).disabled(!game.isMissionUnlocked(index) || game.claimedMissions.contains(index) || !game.isMissionComplete(index))
                }
            }
        }
        .factoryPage().navigationTitle("História").navigationBarTitleDisplayMode(.inline)
    }

    private var districtsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Mapa da cidade", title: "Distritos", subtitle: "A reputação abre portas; o caixa financia a expansão. Cada bairro muda sua estratégia.", accent: accent)
            FactoryDemoNotice(message: "Cidade inventada · expansão com caixa e reputação")
            ForEach(Array([("Centro das Lanternas", "sun.max.fill", "+1 de caixa por toque."), ("Rua da Neblina", "cloud.fog.fill", "+25% de renda para todos os negócios."), ("Colinas do Norte", "mountain.2.fill", "+20% de recompensa em projetos.")].enumerated()), id: \.offset) { index, district in
                FactoryPanel {
                    HStack(spacing: 14) {
                        Image(systemName: district.1).font(.title2).foregroundStyle(accent).frame(width: 42)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(district.0).font(.headline)
                            Text(index < game.unlockedDistricts ? "Aberto · \(district.2)" : "Custo: \(game.districtCashCost(index).formatted(.number.precision(.fractionLength(0)))) caixa + \(game.districtReputationCost(index).formatted(.number.precision(.fractionLength(0)))) reputação · \(district.2)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if index < game.unlockedDistricts { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        else {
                            Button("Abrir") { _ = game.unlockDistrict(index) }
                                .buttonStyle(.borderedProminent).tint(accent)
                                .disabled(index != game.unlockedDistricts || game.cash < game.districtCashCost(index) || game.reputation < game.districtReputationCost(index))
                        }
                    }
                }
            }
            Text("Caixa cresce com os negócios. Reputação vem da campanha, projetos e objetivos.")
                .font(.footnote).foregroundStyle(.secondary)
        }.factoryPage().navigationTitle("Mapa da cidade").navigationBarTitleDisplayMode(.inline)
    }

    private var navigationBar: some View {
        HStack(spacing: 4) {
            navButton("Cidade", symbol: "building.2.fill", index: 0)
            navButton("Negócios", symbol: "briefcase.fill", index: 1)
            navButton("História", symbol: "book.fill", index: 2)
            navButton("Mapa", symbol: "map.fill", index: 3)
            navButton("Projetos", symbol: "sparkles", index: 4)
        }
        .padding(.horizontal, 8).padding(.vertical, 8)
        .background(Color(uiColor: .systemGroupedBackground))
        .overlay(alignment: .top) { Divider() }
    }

    private var projectsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Decisões da cidade", title: "Projetos", subtitle: "Invista no que a cidade precisa. Cada projeto entrega caixa e reputação na hora.", accent: accent)
            FactoryDemoNotice(message: "Projetos e eventos fictícios · sem espera por cronômetros")
            ForEach(projectNames.indices, id: \.self) { index in
                FactoryPanel(title: projectNames[index], systemImage: ["sun.max.fill", "music.note.house.fill", "sparkles"][index]) {
                    Text(projectDescriptions[index]).foregroundStyle(.secondary)
                    if !game.completedProjects.contains(index) {
                        Label(projectRequirements[index], systemImage: game.canCompleteProject(index) ? "checkmark.circle" : "lock")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    Text("Investimento: \(CrimeEconomy.projectCosts[index].formatted(.number.precision(.fractionLength(0)))) caixa · Retorno: +\(Int(CrimeEconomy.projectCashRewards[index] * game.projectRewardMultiplier)) caixa e +\(Int(CrimeEconomy.projectReputationRewards[index] * (game.unlockedDistricts >= 3 ? 1.2 : 1))) reputação")
                        .font(.caption.weight(.semibold)).foregroundStyle(accent)
                    Button(game.completedProjects.contains(index) ? "Projeto concluído" : "Investir e realizar") {
                        _ = game.completeProject(index)
                    }
                    .buttonStyle(.borderedProminent).tint(accent)
                    .disabled(game.completedProjects.contains(index) || !game.canCompleteProject(index))
                }
            }

            FactoryPanel(title: "Conquistas", systemImage: "rosette") {
                ForEach(achievementNames.indices, id: \.self) { index in
                    HStack(spacing: 12) {
                        Image(systemName: game.claimedAchievements.contains(index) ? "checkmark.seal.fill" : "medal.fill")
                            .foregroundStyle(game.claimedAchievements.contains(index) ? .green : accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(achievementNames[index]).font(.subheadline.weight(.semibold))
                            ProgressView(value: game.achievementProgress(index)).tint(accent)
                        }
                        Spacer(minLength: 4)
                        Button(game.claimedAchievements.contains(index) ? "Resgatada" : "+\(Int(CrimeEconomy.achievementRewards[index]))") {
                            _ = game.claimAchievement(index)
                        }
                        .buttonStyle(.bordered).disabled(game.claimedAchievements.contains(index) || !game.isAchievementComplete(index))
                    }
                    if index < achievementNames.count - 1 { Divider() }
                }
            }
        }
        .factoryPage().navigationTitle("Projetos").navigationBarTitleDisplayMode(.inline)
    }

    private var achievementsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Progresso", title: "Conquistas", subtitle: "Marcos da sua trajetória pela cidade, com recompensas locais.", accent: accent)
            FactoryDemoNotice(message: "Conquistas demonstrativas · progresso salvo neste aparelho")
            FactoryPanel(title: "Marcos da cidade", systemImage: "rosette") {
                ForEach(achievementNames.indices, id: \.self) { index in
                    HStack(spacing: 12) {
                        Image(systemName: game.claimedAchievements.contains(index) ? "checkmark.seal.fill" : "medal.fill")
                            .foregroundStyle(game.claimedAchievements.contains(index) ? .green : accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(achievementNames[index]).font(.subheadline.weight(.semibold))
                            ProgressView(value: game.achievementProgress(index)).tint(accent)
                        }
                        Spacer(minLength: 4)
                        Button(game.claimedAchievements.contains(index) ? "Resgatada" : "+\(Int(CrimeEconomy.achievementRewards[index]))") {
                            _ = game.claimAchievement(index)
                        }
                        .buttonStyle(.bordered).disabled(game.claimedAchievements.contains(index) || !game.isAchievementComplete(index))
                    }
                    if index < achievementNames.count - 1 { Divider() }
                }
            }
        }
        .factoryPage().navigationTitle("Conquistas").navigationBarTitleDisplayMode(.inline)
    }

    private func navButton(_ title: String, symbol: String, index: Int) -> some View {
        Button { activeTab = index } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                Text(title).font(.caption2.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(selectedTab == index ? accent : .secondary)
        }
        .accessibilityLabel(title)
        .accessibilityValue(selectedTab == index ? "Selecionado" : "")
        .buttonStyle(.plain)
    }

    private var missionNames: [String] {
        ["Guarde 150 de caixa", "Abra dois negócios", "Expanda o Café Aurora", "Guarde 500 de caixa", "Abra cinco negócios", "Compre o Hotel Horizonte", "Abra a Rua da Neblina", "Produza 5 de caixa/s", "Tenha 12 negócios", "Guarde 2.000 de caixa", "Abra todos os distritos", "Construa 20 negócios"]
    }

    private let projectNames = ["Noite das Lanternas", "Temporada cultural", "Circuito de festivais"]
    private let projectRequirements = [
        "Requer Café Aurora e 35 de caixa",
        "Requer Estúdio Nocturno, 3 negócios e 125 de caixa",
        "Requer Rua da Neblina, 5 negócios e 300 de caixa"
    ]
    private let projectDescriptions = [
        "Lia propõe transformar a inauguração do Café Aurora em um evento para todo o bairro.",
        "Com o Estúdio Nocturno aberto e três negócios na rede, a cidade quer um calendário de atrações.",
        "Depois de abrir a Rua da Neblina e alcançar cinco negócios, leve a programação a novos bairros."
    ]
    private let achievementNames = ["Primeiro empreendimento", "Pequeno império · 5 negócios", "Renda de 5 por segundo", "Expandir para a Neblina", "Magnata · renda de 100/s"]
}
