import SwiftUI

@main
struct CrimeIdleApp: App {
    var body: some Scene { WindowGroup { CrimeIdleHome() } }
}

struct CrimeEconomy: Codable, Equatable {
    static let cap: TimeInterval = 8 * 60 * 60
    static let baseCosts: [Double] = [25, 80, 220, 600, 1_500, 4_000]
    static let baseIncome: [Double] = [0.35, 1.2, 4, 14, 55, 240]
    static let upgradeBaseCosts: [Double] = [125, 400, 1_100, 3_000, 7_500, 20_000]
    static let activityDurations: [TimeInterval] = [20, 45, 90]
    static let activityRewards: [Double] = [45, 140, 350]
    private(set) var influence: Double = 100
    private(set) var owned = Array(repeating: 0, count: 6)
    private(set) var upgradeLevels = Array(repeating: 0, count: 6)
    private(set) var claimedMissions: Set<Int> = []
    private(set) var claimedAchievements: Set<Int> = []
    private(set) var unlockedDistricts = 1
    private(set) var activeActivityID: Int?
    private(set) var activityEndsAt: Date?
    private(set) var activityCooldowns = Array<Date?>(repeating: nil, count: 3)
    private(set) var lastSavedAt: Date = .now

    var districtMultiplier: Double { (unlockedDistricts >= 2 ? 1.25 : 1) }
    var activityRewardMultiplier: Double { unlockedDistricts >= 3 ? 1.2 : 1 }
    var incomePerSecond: Double {
        owned.enumerated().reduce(0) {
            $0 + Double($1.element) * Self.baseIncome[$1.offset] * pow(2, Double(upgradeLevels[$1.offset]))
        } * districtMultiplier
    }
    var totalBusinesses: Int { owned.reduce(0, +) }

    func cost(for index: Int) -> Double {
        guard owned.indices.contains(index) else { return .infinity }
        return Self.baseCosts[index] * pow(1.16, Double(owned[index]))
    }

    func upgradeCost(for index: Int) -> Double {
        guard owned.indices.contains(index), upgradeLevels[index] < 2 else { return .infinity }
        return Self.upgradeBaseCosts[index] * pow(4, Double(upgradeLevels[index]))
    }

    mutating func buyUpgrade(_ index: Int, at date: Date = .now) -> Bool {
        guard owned.indices.contains(index), owned[index] > 0 else { return false }
        let cost = upgradeCost(for: index)
        guard influence >= cost else { return false }
        influence -= cost
        upgradeLevels[index] += 1
        lastSavedAt = date
        return true
    }

    mutating func buy(_ index: Int, at date: Date = .now) -> Bool {
        guard owned.indices.contains(index) else { return false }
        let cost = cost(for: index)
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

    mutating func startActivity(_ id: Int, at date: Date = .now) -> Bool {
        guard Self.activityDurations.indices.contains(id), activeActivityID == nil else { return false }
        if let cooldown = activityCooldowns[id], cooldown > date { return false }
        activeActivityID = id
        activityEndsAt = date.addingTimeInterval(Self.activityDurations[id])
        lastSavedAt = date
        return true
    }

    mutating func claimActivity(at date: Date = .now) -> Bool {
        guard let id = activeActivityID, let end = activityEndsAt, date >= end else { return false }
        influence += Self.activityRewards[id] * activityRewardMultiplier
        activityCooldowns[id] = date.addingTimeInterval(Self.activityDurations[id] * 4)
        activeActivityID = nil
        activityEndsAt = nil
        lastSavedAt = date
        return true
    }

    func activityRemaining(at date: Date = .now) -> TimeInterval {
        guard let end = activityEndsAt else { return 0 }
        return max(0, end.timeIntervalSince(date))
    }

    mutating func claimAchievement(_ id: Int, at date: Date = .now) -> Bool {
        guard (0..<5).contains(id), !claimedAchievements.contains(id), isAchievementComplete(id) else { return false }
        claimedAchievements.insert(id)
        influence += Self.achievementRewards[id]
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

    static let achievementRewards: [Double] = [40, 120, 200, 250, 750]

    private enum CodingKeys: String, CodingKey {
        case influence, owned, upgradeLevels, claimedMissions, claimedAchievements
        case unlockedDistricts, activeActivityID, activityEndsAt, activityCooldowns, lastSavedAt
    }

    init() { }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = CrimeEconomy()
        influence = try values.decodeIfPresent(Double.self, forKey: .influence) ?? defaults.influence
        owned = try values.decodeIfPresent([Int].self, forKey: .owned) ?? defaults.owned
        upgradeLevels = try values.decodeIfPresent([Int].self, forKey: .upgradeLevels) ?? defaults.upgradeLevels
        claimedMissions = try values.decodeIfPresent(Set<Int>.self, forKey: .claimedMissions) ?? []
        claimedAchievements = try values.decodeIfPresent(Set<Int>.self, forKey: .claimedAchievements) ?? []
        unlockedDistricts = try values.decodeIfPresent(Int.self, forKey: .unlockedDistricts) ?? defaults.unlockedDistricts
        activeActivityID = try values.decodeIfPresent(Int.self, forKey: .activeActivityID)
        activityEndsAt = try values.decodeIfPresent(Date.self, forKey: .activityEndsAt)
        activityCooldowns = try values.decodeIfPresent([Date?].self, forKey: .activityCooldowns) ?? defaults.activityCooldowns
        lastSavedAt = try values.decodeIfPresent(Date.self, forKey: .lastSavedAt) ?? defaults.lastSavedAt
        if owned.count != Self.baseCosts.count { owned = defaults.owned }
        if upgradeLevels.count != Self.baseCosts.count { upgradeLevels = defaults.upgradeLevels }
        if activityCooldowns.count != Self.activityDurations.count { activityCooldowns = defaults.activityCooldowns }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(influence, forKey: .influence)
        try values.encode(owned, forKey: .owned)
        try values.encode(upgradeLevels, forKey: .upgradeLevels)
        try values.encode(claimedMissions, forKey: .claimedMissions)
        try values.encode(claimedAchievements, forKey: .claimedAchievements)
        try values.encode(unlockedDistricts, forKey: .unlockedDistricts)
        try values.encodeIfPresent(activeActivityID, forKey: .activeActivityID)
        try values.encodeIfPresent(activityEndsAt, forKey: .activityEndsAt)
        try values.encode(activityCooldowns, forKey: .activityCooldowns)
        try values.encode(lastSavedAt, forKey: .lastSavedAt)
    }

    mutating func claimMission(_ id: Int, at date: Date = .now) -> Bool {
        guard (0..<12).contains(id), !claimedMissions.contains(id), isMissionUnlocked(id) else { return false }
        let complete: Bool
        switch id {
        case 0: complete = influence >= 150
        case 1: complete = owned.reduce(0, +) >= 2
        case 2: complete = owned[0] >= 3
        case 3: complete = influence >= 500
        case 4: complete = owned.reduce(0, +) >= 5
        case 5: complete = owned[5] >= 1
        case 6: complete = unlockedDistricts >= 2
        case 7: complete = incomePerSecond >= 5
        case 8: complete = owned.reduce(0, +) >= 12
        case 9: complete = influence >= 2_000
        case 10: complete = unlockedDistricts >= 3
        case 11: complete = owned.reduce(0, +) >= 20
        default: complete = false
        }
        guard complete else { return false }
        claimedMissions.insert(id)
        influence += Self.missionReward(for: id)
        lastSavedAt = date
        return true
    }

    func isMissionUnlocked(_ id: Int) -> Bool {
        id == 0 || claimedMissions.contains(id - 1)
    }

    static func missionReward(for id: Int) -> Double {
        switch id {
        case 0...2: return 25
        case 3...5: return 75
        case 6...8: return 200
        case 9...11: return 500
        default: return 0
        }
    }

    mutating func unlockDistrict(_ index: Int, at date: Date = .now) -> Bool {
        let costs: [Double] = [0, 500, 2_000]
        guard (0..<costs.count).contains(index), index == unlockedDistricts, influence >= costs[index] else { return false }
        influence -= costs[index]
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var offlineEarnings: Double = 0
    @State private var showingOfflineSummary = false
    private let accent = Color(red: 0.82, green: 0.64, blue: 0.31)
    private let businesses = ["Café Aurora", "Estúdio Nocturno", "Táxi Estelar", "Clube Neblina", "Teatro Eclipse", "Hotel Horizonte"]
    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack {
            Group {
                if capture == "businesses" || activeTab == 1 { businessView }
                else if capture == "missions" || activeTab == 2 { missionView }
                else if capture == "districts" || activeTab == 3 { districtsView }
                else if capture == "achievements" { achievementsView }
                else if capture == "activities" || activeTab == 4 { activitiesView }
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
            }
            let beforeResume = game.influence
            game.resume()
            offlineEarnings = game.influence - beforeResume
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
                let beforeResume = game.influence
                game.resume()
                offlineEarnings = game.influence - beforeResume
                showingOfflineSummary = offlineEarnings >= 1
                game.persist()
            }
        }
        .alert("A cidade continuou trabalhando", isPresented: $showingOfflineSummary) {
            Button("Continuar", role: .cancel) { }
        } message: {
            Text("Seus negócios renderam +\(offlineEarnings.formatted(.number.precision(.fractionLength(0)))) de influência enquanto você estava fora.")
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
                FactoryMetric(label: "Negócios", value: "\(game.totalBusinesses)", symbol: "building.2.fill", tint: accent)
                FactoryMetric(label: "Bônus distrital", value: "+\(Int((game.districtMultiplier - 1) * 100))%", symbol: "map.fill", tint: .red)
            }
            FactoryPanel(title: "Próximo objetivo", systemImage: "target") {
                let nextDistrictCost = game.unlockedDistricts == 1 ? 500.0 : (game.unlockedDistricts == 2 ? 2_000.0 : nil)
                if let target = nextDistrictCost {
                    let bonus = game.unlockedDistricts == 1 ? "aumentar a renda dos negócios em 25%" : "aumentar as recompensas das atividades em 20%"
                    Text("Alcance \(target.formatted(.number.precision(.fractionLength(0)))) de influência para abrir um distrito e \(bonus).").foregroundStyle(.secondary)
                    ProgressView(value: min(game.influence / target, 1)).tint(accent)
                } else {
                    Text("Todos os distritos estão sob sua influência. Sua renda recebe bônus de +\(Int((game.districtMultiplier - 1) * 100))%.").foregroundStyle(.secondary)
                }
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
                        Button("\(game.cost(for: index), specifier: "%.0f")") {
                            _ = game.buy(index)
                        }
                        .buttonStyle(.borderedProminent).tint(accent)
                        .disabled(game.influence < game.cost(for: index))
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
                                .disabled(game.influence < game.upgradeCost(for: index))
                                .accessibilityLabel("Melhorar \(businesses[index])")
                            }
                        }
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
            ForEach(Array(missionNames.enumerated()), id: \.offset) { index, title in
                FactoryPanel {
                    Label(title, systemImage: game.claimedMissions.contains(index) ? "checkmark.seal.fill" : (game.isMissionUnlocked(index) ? "target" : "lock.fill")).font(.headline)
                    if !game.isMissionUnlocked(index) {
                        Text("Conclua a missão anterior para desbloquear.").font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: missionProgress(index)).tint(accent)
                    Button(game.claimedMissions.contains(index) ? "Recompensa resgatada" : "Resgatar +\(Int(CrimeEconomy.missionReward(for: index))) de influência") {
                        _ = game.claimMission(index)
                    }
                    .buttonStyle(.bordered).disabled(!game.isMissionUnlocked(index) || game.claimedMissions.contains(index) || missionProgress(index) < 1)
                }
            }
        }
        .factoryPage().navigationTitle("Missões").navigationBarTitleDisplayMode(.inline)
    }

    private var districtsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Mapa fictício", title: "Distritos", subtitle: "Expanda a cidade ao atingir os requisitos de influência.", accent: accent)
            FactoryDemoNotice(message: "Cidade inventada · progresso salvo localmente")
            ForEach(Array([("Centro das Lanternas", "sun.max.fill", 0.0, "Ponto de partida da cidade."), ("Rua da Neblina", "cloud.fog.fill", 500.0, "+25% de renda para todos os negócios."), ("Colinas do Norte", "mountain.2.fill", 2_000.0, "+20% de recompensa nas atividades.")].enumerated()), id: \.offset) { index, district in
                FactoryPanel {
                    HStack(spacing: 14) {
                        Image(systemName: district.1).font(.title2).foregroundStyle(accent).frame(width: 42)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(district.0).font(.headline)
                            Text(index < game.unlockedDistricts ? district.3 : "Requisito: \(district.2.formatted(.number.precision(.fractionLength(0)))) · \(district.3)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if index < game.unlockedDistricts { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        else {
                            Button("Abrir") { _ = game.unlockDistrict(index) }
                                .buttonStyle(.borderedProminent).tint(accent)
                                .disabled(index != game.unlockedDistricts || game.influence < district.2)
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
            navButton("Ações", symbol: "sparkles", index: 4)
        }
        .padding(10)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, 10).padding(.bottom, 8)
    }

    private var activitiesView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Vida da cidade", title: "Atividades", subtitle: "Organize eventos e projetos fictícios para ganhar influência extra.", accent: accent)
            FactoryDemoNotice(message: "Atividades narrativas · sem ações reais")

            FactoryPanel(title: "Projetos da cidade", systemImage: "clock.fill") {
                ForEach(activityNames.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activityNames[index]).font(.headline)
                                Text("\(Int(CrimeEconomy.activityDurations[index])) s · recompensa +\(Int(CrimeEconomy.activityRewards[index] * game.activityRewardMultiplier)) influência")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            activityButton(index)
                        }
                        if game.activeActivityID == index {
                            ProgressView(value: 1 - game.activityRemaining() / CrimeEconomy.activityDurations[index]).tint(accent)
                        }
                        if index < activityNames.count - 1 { Divider() }
                    }
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
        .factoryPage().navigationTitle("Atividades").navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private func activityButton(_ index: Int) -> some View {
        if game.activeActivityID == index {
            if game.activityRemaining() == 0 {
                Button("Resgatar") { _ = game.claimActivity() }
                    .buttonStyle(.borderedProminent).tint(accent)
            } else {
                Text("\(Int(ceil(game.activityRemaining())))s")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        } else if let active = game.activeActivityID {
            Text(activeActivityMessage(active)).font(.caption).foregroundStyle(.secondary)
        } else if let cooldown = game.activityCooldowns[index], cooldown > .now {
            Text("\(Int(ceil(cooldown.timeIntervalSinceNow)))s")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        } else {
            Button("Iniciar") { _ = game.startActivity(index) }
                .buttonStyle(.borderedProminent).tint(accent)
        }
    }

    private func activeActivityMessage(_ id: Int) -> String {
        "\(activityNames[id]) em andamento"
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

    private func missionProgress(_ index: Int) -> Double {
        switch index {
        case 0: min(game.influence / 150, 1)
        case 1: min(Double(game.owned.reduce(0, +)) / 2, 1)
        case 2: min(Double(game.owned[0]) / 3, 1)
        case 3: min(game.influence / 500, 1)
        case 4: min(Double(game.owned.reduce(0, +)) / 5, 1)
        case 5: min(Double(game.owned[5]), 1)
        case 6: min(Double(game.unlockedDistricts - 1), 1)
        case 7: min(game.incomePerSecond / 5, 1)
        case 8: min(Double(game.owned.reduce(0, +)) / 12, 1)
        case 9: min(game.influence / 2_000, 1)
        case 10: min(Double(game.unlockedDistricts - 1) / 2, 1)
        default: min(Double(game.owned.reduce(0, +)) / 20, 1)
        }
    }

    private var missionNames: [String] {
        ["Alcance 150 de influência", "Abra dois empreendimentos", "Expanda o Café Aurora", "Alcance 500 de influência", "Abra cinco negócios", "Compre o Hotel Horizonte", "Abra um novo distrito", "Produza 5 de influência/s", "Tenha 12 negócios", "Alcance 2.000 de influência", "Abra todos os distritos", "Construa 20 negócios"]
    }

    private let activityNames = ["Preparar a Noite das Lanternas", "Negociar um festival de bairro", "Inaugurar o Hotel Horizonte"]
    private let achievementNames = ["Primeiro empreendimento", "Pequeno império · 5 negócios", "Renda de 5 por segundo", "Expandir para a Neblina", "Magnata · renda de 100/s"]
}
