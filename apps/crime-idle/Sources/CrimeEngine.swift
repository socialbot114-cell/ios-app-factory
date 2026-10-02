import Foundation

/// Gerador SplitMix64 serializável: torna golpes, críticos e eventos reproduzíveis em teste.
struct CrimeRNG: Codable, Equatable {
    private(set) var state: UInt64

    init(seed: UInt64) { state = seed }

    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        state = UInt64(text) ?? 0x5EED
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(state))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992 }

    mutating func int(below upperBound: Int) -> Int {
        upperBound <= 1 ? 0 : Int(next() % UInt64(upperBound))
    }
}

struct CrimeActiveHeist: Codable, Equatable {
    let heistID: Int
    let plan: CrimeHeistPlan
    var remaining: Double
    let loot: Double
    let respect: Double
    let heat: Double
    let odds: Double

    var isReady: Bool { remaining <= 0 }
}

struct CrimeHeistOutcome: Equatable {
    let heistID: Int
    let plan: CrimeHeistPlan
    let success: Bool
    let perfect: Bool
    let loot: Double
    let respect: Double
    let heat: Double
}

struct CrimeTapResult: Equatable {
    let amount: Double
    let critical: Bool
}

struct CrimeOfflineReport: Equatable {
    let seconds: Double
    let cash: Double
}

/// Passos do tutorial do Padrinho, na ordem em que aparecem.
enum CrimeTutorialStep: Int, Codable, CaseIterable {
    case tapStreet, buyRacket, runRacket, growRacket, firstHeist, hireManager, done

    var title: String {
        switch self {
        case .tapStreet: return "Comece pequeno"
        case .buyRacket: return "Seu primeiro negócio"
        case .runRacket: return "Faça girar"
        case .growRacket: return "Cresça na rua"
        case .firstHeist: return "Seu primeiro golpe"
        case .hireManager: return "Quem manda, delega"
        case .done: return "Bem-vindo à família"
        }
    }

    var message: String {
        switch self {
        case .tapStreet: return "Toque 5 vezes em Golpe de rua para juntar uns trocados."
        case .buyRacket: return "Em Negócios, abra um Camelô de Relógios."
        case .runRacket: return "Toque no ícone do relógio para rodar um ciclo e faturar."
        case .growRacket: return "Tenha 5 camelôs. Cada um multiplica o lucro do ciclo."
        case .firstHeist: return "Em Golpes, execute o Bonde das Carteiras. Furtivo é mais seguro."
        case .hireManager: return "Junte $1.000 e contrate o Zé Pulseira: o camelô roda sozinho, até offline."
        case .done: return ""
        }
    }

    var symbol: String {
        switch self {
        case .tapStreet: return "hat.widebrim.fill"
        case .buyRacket, .runRacket, .growRacket: return "clock.fill"
        case .firstHeist: return "tram.fill"
        case .hireManager: return "person.badge.clock.fill"
        case .done: return "checkmark.seal.fill"
        }
    }
}

struct CrimeDailyReward: Equatable {
    let day: Int
    let cashSeconds: Double
    let respect: Double
    let boostMinutes: Double

    static let cycle: [CrimeDailyReward] = [
        .init(day: 1, cashSeconds: 300, respect: 1, boostMinutes: 0),
        .init(day: 2, cashSeconds: 600, respect: 2, boostMinutes: 0),
        .init(day: 3, cashSeconds: 900, respect: 3, boostMinutes: 0),
        .init(day: 4, cashSeconds: 1_200, respect: 4, boostMinutes: 0),
        .init(day: 5, cashSeconds: 1_800, respect: 5, boostMinutes: 0),
        .init(day: 6, cashSeconds: 2_400, respect: 6, boostMinutes: 0),
        .init(day: 7, cashSeconds: 3_600, respect: 12, boostMinutes: 15)
    ]
}

struct CrimeDailyClaim: Equatable {
    let reward: CrimeDailyReward
    let cash: Double
    let respect: Double
}

enum CrimeBuyMode: Int, CaseIterable, Identifiable {
    case one = 1, ten = 10, hundred = 100, max = 0

    var id: Int { rawValue }
    var title: String { self == .max ? "MÁX" : "×\(rawValue)" }
}

struct CrimeState: Codable, Equatable {
    static let baseOfflineHours = 8.0
    static let baseHeatDecay = 0.01
    static let minimumLegacyClaim = 5.0
    static let legacyBonus = 0.03

    var cash: Double = 5
    var respect: Double = 0
    var legacy: Double = 0
    var heat: Double = 0
    var owned = Array(repeating: 0, count: CrimeRacket.catalog.count)
    var managed = Array(repeating: false, count: CrimeRacket.catalog.count)
    var progress = Array(repeating: 0.0, count: CrimeRacket.catalog.count)
    var running = Array(repeating: false, count: CrimeRacket.catalog.count)
    var upgrades: Set<Int> = []
    var districts = 1
    var crewLevels = Array(repeating: 0, count: CrimeCrewMember.catalog.count)
    var activeHeist: CrimeActiveHeist?
    var heistsCompleted = 0
    var claimedContracts: Set<Int> = []
    var lifetimeRun: Double = 0
    var lifetimeTotal: Double = 0
    var prestigeCount = 0
    var boostMultiplier: Double = 1
    var boostRemaining: Double = 0
    var pendingEvent: Int?
    var nextEventIn: Double = 45
    var taps = 0
    var tutorial: CrimeTutorialStep = .tapStreet
    var manualRuns = 0
    var heistsStarted = 0
    var dailyStreak = 0
    var lastDailyDay: Int?
    var rng = CrimeRNG(seed: 0xC0FF_EE15_DEAD_BEEF)
    var lastSeen = Date()

    init(seed: UInt64 = 0xC0FF_EE15_DEAD_BEEF, now: Date = Date()) {
        rng = CrimeRNG(seed: seed)
        lastSeen = now
    }

    private enum CodingKeys: String, CodingKey {
        case cash, respect, legacy, heat, owned, managed, progress, running, upgrades, districts, crewLevels
        case activeHeist, heistsCompleted, claimedContracts, lifetimeRun, lifetimeTotal, prestigeCount
        case boostMultiplier, boostRemaining, pendingEvent, nextEventIn, taps, rng, lastSeen
        case tutorial, manualRuns, heistsStarted, dailyStreak, lastDailyDay
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func number(_ key: CodingKeys, _ fallback: Double) -> Double {
            guard let value = try? c.decodeIfPresent(Double.self, forKey: key), value.isFinite else { return fallback }
            return value
        }
        func sized<T: Decodable>(_ key: CodingKeys, _ fallback: T, count: Int) -> [T] {
            let decoded = (try? c.decodeIfPresent([T].self, forKey: key)) ?? []
            return (0..<count).map { $0 < decoded.count ? decoded[$0] : fallback }
        }
        let rackets = CrimeRacket.catalog.count
        cash = max(number(.cash, 5), 0)
        respect = max(number(.respect, 0), 0)
        legacy = max(number(.legacy, 0), 0)
        heat = min(max(number(.heat, 0), 0), 100)
        owned = sized(.owned, 0, count: rackets).map { max($0, 0) }
        managed = sized(.managed, false, count: rackets)
        progress = sized(.progress, 0.0, count: rackets).map { $0.isFinite ? max($0, 0) : 0 }
        running = sized(.running, false, count: rackets)
        upgrades = (try? c.decodeIfPresent(Set<Int>.self, forKey: .upgrades)) ?? []
        districts = min(max((try? c.decodeIfPresent(Int.self, forKey: .districts)) ?? 1, 1), CrimeDistrict.catalog.count)
        crewLevels = sized(.crewLevels, 0, count: CrimeCrewMember.catalog.count).map { min(max($0, 0), CrimeCrewMember.maxLevel) }
        activeHeist = try? c.decodeIfPresent(CrimeActiveHeist.self, forKey: .activeHeist)
        heistsCompleted = (try? c.decodeIfPresent(Int.self, forKey: .heistsCompleted)) ?? 0
        claimedContracts = (try? c.decodeIfPresent(Set<Int>.self, forKey: .claimedContracts)) ?? []
        lifetimeRun = max(number(.lifetimeRun, 0), 0)
        lifetimeTotal = max(number(.lifetimeTotal, 0), lifetimeRun)
        prestigeCount = (try? c.decodeIfPresent(Int.self, forKey: .prestigeCount)) ?? 0
        boostMultiplier = max(number(.boostMultiplier, 1), 1)
        boostRemaining = max(number(.boostRemaining, 0), 0)
        pendingEvent = (try? c.decodeIfPresent(Int.self, forKey: .pendingEvent)).flatMap { $0 }
        if let event = pendingEvent, !CrimeEvent.catalog.indices.contains(event) { pendingEvent = nil }
        nextEventIn = max(number(.nextEventIn, 45), 0)
        taps = (try? c.decodeIfPresent(Int.self, forKey: .taps)) ?? 0
        rng = (try? c.decodeIfPresent(CrimeRNG.self, forKey: .rng)) ?? CrimeRNG(seed: 0xC0FF_EE15_DEAD_BEEF)
        lastSeen = (try? c.decodeIfPresent(Date.self, forKey: .lastSeen)) ?? Date()
        manualRuns = (try? c.decodeIfPresent(Int.self, forKey: .manualRuns)) ?? 0
        heistsStarted = (try? c.decodeIfPresent(Int.self, forKey: .heistsStarted)) ?? heistsCompleted
        dailyStreak = min(max((try? c.decodeIfPresent(Int.self, forKey: .dailyStreak)) ?? 0, 0), CrimeDailyReward.cycle.count)
        lastDailyDay = (try? c.decodeIfPresent(Int.self, forKey: .lastDailyDay)).flatMap { $0 }
        // Saves anteriores ao tutorial: quem já tem gerente não precisa de aula.
        let savedTutorial = (try? c.decodeIfPresent(CrimeTutorialStep.self, forKey: .tutorial)).flatMap { $0 }
        tutorial = savedTutorial ?? (managed.contains(true) || prestigeCount > 0 ? .done : .tapStreet)
        // Negócios de bairros ainda fechados nunca deveriam existir; reabre o bairro em vez de apagar progresso.
        if let highest = CrimeRacket.catalog.filter({ owned[$0.id] > 0 }).map(\.district).max() {
            districts = max(districts, highest + 1)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cash, forKey: .cash)
        try c.encode(respect, forKey: .respect)
        try c.encode(legacy, forKey: .legacy)
        try c.encode(heat, forKey: .heat)
        try c.encode(owned, forKey: .owned)
        try c.encode(managed, forKey: .managed)
        try c.encode(progress, forKey: .progress)
        try c.encode(running, forKey: .running)
        try c.encode(upgrades, forKey: .upgrades)
        try c.encode(districts, forKey: .districts)
        try c.encode(crewLevels, forKey: .crewLevels)
        try c.encodeIfPresent(activeHeist, forKey: .activeHeist)
        try c.encode(heistsCompleted, forKey: .heistsCompleted)
        try c.encode(claimedContracts, forKey: .claimedContracts)
        try c.encode(lifetimeRun, forKey: .lifetimeRun)
        try c.encode(lifetimeTotal, forKey: .lifetimeTotal)
        try c.encode(prestigeCount, forKey: .prestigeCount)
        try c.encode(boostMultiplier, forKey: .boostMultiplier)
        try c.encode(boostRemaining, forKey: .boostRemaining)
        try c.encodeIfPresent(pendingEvent, forKey: .pendingEvent)
        try c.encode(nextEventIn, forKey: .nextEventIn)
        try c.encode(taps, forKey: .taps)
        try c.encode(rng, forKey: .rng)
        try c.encode(lastSeen, forKey: .lastSeen)
        try c.encode(tutorial, forKey: .tutorial)
        try c.encode(manualRuns, forKey: .manualRuns)
        try c.encode(heistsStarted, forKey: .heistsStarted)
        try c.encode(dailyStreak, forKey: .dailyStreak)
        try c.encodeIfPresent(lastDailyDay, forKey: .lastDailyDay)
    }

    // MARK: - Modificadores

    func crewValue(_ perk: CrimeCrewPerk) -> Double {
        CrimeCrewMember.catalog.reduce(0) { total, member in
            member.perk == perk ? total + member.perLevel * Double(crewLevels[member.id]) : total
        }
    }

    private func upgradeCount(_ matches: (CrimeUpgradeEffect) -> Bool) -> Int {
        CrimeUpgrade.catalog.filter { upgrades.contains($0.id) && matches($0.effect) }.count
    }

    var heatMultiplier: Double {
        heat <= 40 ? 1 : 1 - (min(heat, 100) - 40) / 60 * 0.5
    }

    /// Multiplicador permanente (sem calor nem bônus temporário).
    var baseGlobalMultiplier: Double {
        let crew = 1 + crewValue(.profit)
        let upgrades = pow(3, Double(upgradeCount { $0 == .allProfit }))
        let legacyBonus = 1 + legacy * Self.legacyBonus
        let territory = 1 + Double(districts - 1) * CrimeDistrict.profitBonusPerDistrict
        return crew * upgrades * legacyBonus * territory
    }

    var globalMultiplier: Double {
        baseGlobalMultiplier * heatMultiplier * (boostRemaining > 0 ? boostMultiplier : 1)
    }

    func racketMultiplier(_ index: Int) -> Double {
        var value = pow(3, Double(upgradeCount { $0 == .racketProfit(index) }))
        for milestone in CrimeRacket.profitMilestones where owned[index] >= milestone.count {
            value *= milestone.multiplier
        }
        return value
    }

    func cycleTime(_ index: Int) -> Double {
        let racket = CrimeRacket.catalog[index]
        let doublings = CrimeRacket.speedMilestones.filter { owned[index] >= $0 }.count
        return max(racket.cycle / pow(2, Double(doublings)) / (1 + crewValue(.speed)), 0.05)
    }

    func revenuePerCycle(_ index: Int) -> Double {
        Double(owned[index]) * CrimeRacket.catalog[index].revenue * racketMultiplier(index) * globalMultiplier
    }

    func incomePerSecond(_ index: Int) -> Double {
        guard owned[index] > 0 else { return 0 }
        return revenuePerCycle(index) / cycleTime(index)
    }

    /// Renda automática por segundo (só negócios com gerente).
    var incomePerSecond: Double {
        CrimeRacket.catalog.indices.reduce(0) { $0 + (managed[$1] ? incomePerSecond($1) : 0) }
    }

    var heatRate: Double {
        let raw = CrimeRacket.catalog.reduce(0.0) { total, racket in
            managed[racket.id] && owned[racket.id] > 0 ? total + racket.heat : total
        }
        return raw > 0 ? raw * max(1 - crewValue(.heatShield), 0.2) : raw
    }

    var heatDecay: Double {
        Self.baseHeatDecay * (1 + 0.5 * Double(upgradeCount { $0 == .heatDecay }))
    }

    var offlineCapSeconds: Double {
        (Self.baseOfflineHours + 4 * Double(upgradeCount { $0 == .offlineHours }) + crewValue(.offlineHours)) * 3_600
    }

    var tapMultiplier: Double {
        (1 + crewValue(.tapPower)) * pow(5, Double(upgradeCount { $0 == .tapPower }))
    }

    var tapValue: Double { (1 + incomePerSecond * 0.08) * tapMultiplier }

    var respectMultiplier: Double { 1 + crewValue(.respectGain) }

    var heistLootMultiplier: Double {
        (1 + crewValue(.heistLoot)) * pow(2, Double(upgradeCount { $0 == .heistLoot }))
    }

    var totalOwned: Int { owned.reduce(0, +) }
    var managerCount: Int { managed.filter { $0 }.count }
    var crewCount: Int { crewLevels.filter { $0 > 0 }.count }

    var rankIndex: Int {
        CrimeRank.ladder.lastIndex { lifetimeTotal >= $0.threshold } ?? 0
    }

    // MARK: - Ganhos

    private mutating func earn(_ amount: Double) {
        guard amount.isFinite, amount > 0 else { return }
        cash += amount
        lifetimeRun += amount
        lifetimeTotal += amount
    }

    private mutating func gainRespect(_ amount: Double) {
        guard amount > 0 else { respect = max(respect + amount, 0); return }
        respect += amount * respectMultiplier
    }

    private mutating func addHeat(_ amount: Double) {
        heat = min(max(heat + amount, 0), 100)
    }

    /// Avança o mundo. Online também sorteia eventos; offline não.
    mutating func tick(_ seconds: Double, online: Bool = true) {
        guard seconds > 0, seconds.isFinite else { return }
        addHeat((heatRate - heatDecay * heat) * seconds)

        for index in CrimeRacket.catalog.indices where owned[index] > 0 && (managed[index] || running[index]) {
            progress[index] += seconds
            let cycle = cycleTime(index)
            guard progress[index] >= cycle else { continue }
            if managed[index] {
                let completions = (progress[index] / cycle).rounded(.down)
                progress[index] -= completions * cycle
                earn(completions * revenuePerCycle(index))
            } else {
                progress[index] = 0
                running[index] = false
                earn(revenuePerCycle(index))
            }
        }

        if boostRemaining > 0 {
            boostRemaining = max(boostRemaining - seconds, 0)
            if boostRemaining == 0 { boostMultiplier = 1 }
        }
        if activeHeist != nil { activeHeist!.remaining = max(activeHeist!.remaining - seconds, 0) }

        if online && pendingEvent == nil && tutorial == .done {
            nextEventIn -= seconds
            if nextEventIn <= 0 {
                pendingEvent = rng.int(below: CrimeEvent.catalog.count)
                nextEventIn = 150 + rng.unit() * 150
            }
        }
    }

    /// Aplica o tempo fora do app em passos, respeitando o limite offline.
    @discardableResult
    mutating func resume(at now: Date = Date()) -> CrimeOfflineReport? {
        let elapsed = min(max(now.timeIntervalSince(lastSeen), 0), offlineCapSeconds)
        lastSeen = now
        guard elapsed > 0 else { return nil }
        let before = cash
        var remaining = elapsed
        while remaining > 0 {
            let step = min(remaining, 5)
            tick(step, online: false)
            remaining -= step
        }
        let earned = cash - before
        return elapsed >= 60 && earned > 0 ? CrimeOfflineReport(seconds: elapsed, cash: earned) : nil
    }

    // MARK: - Ações

    @discardableResult
    mutating func tapStreet() -> CrimeTapResult {
        taps += 1
        let critical = rng.unit() < 0.1
        let amount = tapValue * (critical ? 10 : 1)
        earn(amount)
        return CrimeTapResult(amount: amount, critical: critical)
    }

    func isRacketUnlocked(_ index: Int) -> Bool {
        CrimeRacket.catalog.indices.contains(index) && CrimeRacket.catalog[index].district < districts
    }

    func cost(racket index: Int, quantity: Int) -> Double {
        let racket = CrimeRacket.catalog[index]
        guard quantity > 0 else { return 0 }
        let first = racket.baseCost * pow(racket.growth, Double(owned[index]))
        return first * (pow(racket.growth, Double(quantity)) - 1) / (racket.growth - 1)
    }

    func maxAffordable(racket index: Int) -> Int {
        let racket = CrimeRacket.catalog[index]
        let first = racket.baseCost * pow(racket.growth, Double(owned[index]))
        guard cash >= first else { return 0 }
        var count = Int((log(cash * (racket.growth - 1) / first + 1) / log(racket.growth)).rounded(.down))
        // Corrige erros de ponto flutuante na borda.
        while count > 0 && cost(racket: index, quantity: count) > cash { count -= 1 }
        return min(count, 10_000)
    }

    func quantity(for mode: CrimeBuyMode, racket index: Int) -> Int {
        mode == .max ? max(maxAffordable(racket: index), 1) : mode.rawValue
    }

    func canBuy(racket index: Int, quantity: Int) -> Bool {
        isRacketUnlocked(index) && quantity > 0 && cash >= cost(racket: index, quantity: quantity)
    }

    @discardableResult
    mutating func buy(racket index: Int, quantity: Int) -> Bool {
        guard canBuy(racket: index, quantity: quantity) else { return false }
        cash -= cost(racket: index, quantity: quantity)
        owned[index] += quantity
        return true
    }

    /// Inicia um ciclo manual (negócio sem gerente).
    @discardableResult
    mutating func run(racket index: Int) -> Bool {
        guard owned.indices.contains(index), owned[index] > 0, !managed[index], !running[index] else { return false }
        running[index] = true
        progress[index] = 0
        manualRuns += 1
        return true
    }

    func canHireManager(_ index: Int) -> Bool {
        isRacketUnlocked(index) && owned[index] > 0 && !managed[index] && cash >= CrimeRacket.catalog[index].managerCost
    }

    @discardableResult
    mutating func hireManager(_ index: Int) -> Bool {
        guard canHireManager(index) else { return false }
        cash -= CrimeRacket.catalog[index].managerCost
        managed[index] = true
        running[index] = false
        return true
    }

    func canBuyUpgrade(_ id: Int) -> Bool {
        guard let upgrade = CrimeUpgrade.catalog.first(where: { $0.id == id }), !upgrades.contains(id) else { return false }
        if case let .racketProfit(index) = upgrade.effect, owned[index] == 0 { return false }
        return cash >= upgrade.cost
    }

    @discardableResult
    mutating func buyUpgrade(_ id: Int) -> Bool {
        guard canBuyUpgrade(id), let upgrade = CrimeUpgrade.catalog.first(where: { $0.id == id }) else { return false }
        cash -= upgrade.cost
        upgrades.insert(id)
        return true
    }

    var bribeCost: Double { max(incomePerSecond * 300, 50) }

    @discardableResult
    mutating func bribe() -> Bool {
        guard heat >= 5, cash >= bribeCost else { return false }
        cash -= bribeCost
        addHeat(-30)
        return true
    }

    // MARK: - Família

    func crewUpgradeCost(_ id: Int) -> Double? {
        guard CrimeCrewMember.catalog.indices.contains(id), crewLevels[id] < CrimeCrewMember.maxLevel else { return nil }
        return CrimeCrewMember.catalog[id].cost(fromLevel: crewLevels[id])
    }

    func canUpgradeCrew(_ id: Int) -> Bool {
        guard let cost = crewUpgradeCost(id) else { return false }
        return respect >= cost
    }

    @discardableResult
    mutating func upgradeCrew(_ id: Int) -> Bool {
        guard canUpgradeCrew(id), let cost = crewUpgradeCost(id) else { return false }
        respect -= cost
        crewLevels[id] += 1
        return true
    }

    // MARK: - Território

    func canConquer(_ id: Int) -> Bool {
        guard CrimeDistrict.catalog.indices.contains(id), id == districts else { return false }
        let district = CrimeDistrict.catalog[id]
        return cash >= district.cashCost && respect >= district.respectCost
    }

    @discardableResult
    mutating func conquer(_ id: Int) -> Bool {
        guard canConquer(id) else { return false }
        let district = CrimeDistrict.catalog[id]
        cash -= district.cashCost
        respect -= district.respectCost
        districts += 1
        return true
    }

    // MARK: - Golpes

    func isHeistUnlocked(_ id: Int) -> Bool {
        CrimeHeist.catalog.indices.contains(id) && CrimeHeist.catalog[id].district < districts
    }

    func heistOdds(_ id: Int, plan: CrimeHeistPlan) -> Double {
        let heist = CrimeHeist.catalog[id]
        let heatPenalty = max(heat - 50, 0) * 0.004
        return min(max(heist.baseOdds + plan.oddsDelta + crewValue(.heistOdds) - heatPenalty, 0.05), 0.95)
    }

    func heistLoot(_ id: Int, plan: CrimeHeistPlan) -> Double {
        let heist = CrimeHeist.catalog[id]
        return max(incomePerSecond * heist.lootSeconds, heist.minLoot) * plan.lootMultiplier * heistLootMultiplier
    }

    func canStartHeist(_ id: Int) -> Bool { activeHeist == nil && isHeistUnlocked(id) }

    @discardableResult
    mutating func startHeist(_ id: Int, plan: CrimeHeistPlan) -> Bool {
        guard canStartHeist(id) else { return false }
        let heist = CrimeHeist.catalog[id]
        activeHeist = CrimeActiveHeist(heistID: id, plan: plan, remaining: heist.duration,
                                       loot: heistLoot(id, plan: plan), respect: heist.respect * plan.lootMultiplier,
                                       heat: heist.heat * plan.heatMultiplier, odds: heistOdds(id, plan: plan))
        heistsStarted += 1
        return true
    }

    /// Revela o golpe pronto. O sorteio acontece aqui, para o momento da revelação ter suspense de verdade.
    mutating func resolveHeist() -> CrimeHeistOutcome? {
        guard let heist = activeHeist, heist.isReady else { return nil }
        activeHeist = nil
        let success = rng.unit() < heist.odds
        let perfect = success && rng.unit() < 0.12
        let bonus = perfect ? 2.0 : 1.0
        let loot = success ? heist.loot * bonus : 0
        let respectGain = success ? (heist.respect * bonus).rounded(.up) : 0
        let heatGain = success ? heist.heat : heist.heat * 2
        earn(loot)
        gainRespect(respectGain)
        addHeat(heatGain)
        if success { heistsCompleted += 1 }
        return CrimeHeistOutcome(heistID: heist.heistID, plan: heist.plan, success: success, perfect: perfect,
                                 loot: loot, respect: respectGain * (success ? respectMultiplier : 0), heat: heatGain)
    }

    // MARK: - Eventos

    func eventCost(_ choice: CrimeEventChoice) -> Double {
        choice.costSeconds * max(incomePerSecond, 1)
    }

    func canChoose(_ choiceIndex: Int) -> Bool {
        guard let event = pendingEvent, CrimeEvent.catalog[event].choices.indices.contains(choiceIndex) else { return false }
        return cash >= eventCost(CrimeEvent.catalog[event].choices[choiceIndex])
    }

    @discardableResult
    mutating func choose(_ choiceIndex: Int) -> Bool {
        guard canChoose(choiceIndex), let event = pendingEvent else { return false }
        let choice = CrimeEvent.catalog[event].choices[choiceIndex]
        cash -= eventCost(choice)
        earn(choice.cashSeconds * max(incomePerSecond, 2))
        gainRespect(choice.respect)
        addHeat(choice.heat)
        if choice.boostSeconds > 0 {
            boostMultiplier = max(choice.boost, boostRemaining > 0 ? boostMultiplier : 1)
            boostRemaining = max(boostRemaining, choice.boostSeconds)
        }
        pendingEvent = nil
        return true
    }

    // MARK: - Contratos

    func contractProgress(_ id: Int) -> Double {
        guard let contract = CrimeContract.catalog.first(where: { $0.id == id }) else { return 0 }
        func ratio(_ value: Double, _ target: Double) -> Double { min(value / target, 1) }
        switch contract.goal {
        case let .owned(racket, count): return ratio(Double(owned[racket]), Double(count))
        case let .totalOwned(count): return ratio(Double(totalOwned), Double(count))
        case let .managers(count): return ratio(Double(managerCount), Double(count))
        case let .lifetime(target): return ratio(lifetimeTotal, target)
        case let .districts(count): return ratio(Double(districts), Double(count))
        case let .heists(count): return ratio(Double(heistsCompleted), Double(count))
        case let .crew(count): return ratio(Double(crewCount), Double(count))
        case let .prestige(count): return ratio(Double(prestigeCount), Double(count))
        }
    }

    func canClaimContract(_ id: Int) -> Bool {
        !claimedContracts.contains(id) && contractProgress(id) >= 1
    }

    @discardableResult
    mutating func claimContract(_ id: Int) -> Bool {
        guard canClaimContract(id), let contract = CrimeContract.catalog.first(where: { $0.id == id }) else { return false }
        claimedContracts.insert(id)
        gainRespect(contract.respect)
        earn(contract.cashSeconds * max(incomePerSecond, 1))
        return true
    }

    /// Próximos contratos em aberto, prontos para resgate primeiro.
    var openContracts: [CrimeContract] {
        CrimeContract.catalog
            .filter { !claimedContracts.contains($0.id) }
            .sorted { lhs, rhs in
                let left = canClaimContract(lhs.id), right = canClaimContract(rhs.id)
                return left != right ? left : lhs.id < rhs.id
            }
    }

    // MARK: - Tutorial

    static let tutorialRewardRespect = 3.0

    func isTutorialStepComplete(_ step: CrimeTutorialStep) -> Bool {
        switch step {
        case .tapStreet: return taps >= 5
        case .buyRacket: return owned[0] >= 1
        case .runRacket: return manualRuns >= 1 || managed[0]
        case .growRacket: return owned[0] >= 5
        case .firstHeist: return heistsStarted >= 1
        case .hireManager: return managerCount >= 1
        case .done: return true
        }
    }

    /// Avança quantos passos já estiverem cumpridos. Devolve true quando o tutorial termina agora.
    @discardableResult
    mutating func advanceTutorial() -> Bool {
        guard tutorial != .done else { return false }
        while tutorial != .done && isTutorialStepComplete(tutorial) {
            tutorial = CrimeTutorialStep(rawValue: tutorial.rawValue + 1) ?? .done
        }
        guard tutorial == .done else { return false }
        gainRespect(Self.tutorialRewardRespect)
        nextEventIn = min(nextEventIn, 45)
        return true
    }

    mutating func skipTutorial() {
        tutorial = .done
    }

    // MARK: - Envelope diário

    static func dayNumber(_ date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        return Int((start.timeIntervalSince1970 + Double(calendar.timeZone.secondsFromGMT(for: start))) / 86_400)
    }

    func isDailyAvailable(today: Int) -> Bool { lastDailyDay != today }

    /// Recompensa que seria entregue hoje (a sequência quebra se pular um dia).
    func nextDailyReward(today: Int) -> CrimeDailyReward {
        let continues = lastDailyDay == today - 1
        let streak = continues ? dailyStreak % CrimeDailyReward.cycle.count + 1 : 1
        return CrimeDailyReward.cycle[streak - 1]
    }

    @discardableResult
    mutating func claimDaily(today: Int) -> CrimeDailyClaim? {
        guard isDailyAvailable(today: today) else { return nil }
        let reward = nextDailyReward(today: today)
        let cash = reward.cashSeconds * max(incomePerSecond, 2)
        let respectBefore = respect
        earn(cash)
        gainRespect(reward.respect)
        if reward.boostMinutes > 0 {
            boostMultiplier = max(boostMultiplier, 2)
            boostRemaining = max(boostRemaining, reward.boostMinutes * 60)
        }
        dailyStreak = reward.day
        lastDailyDay = today
        return CrimeDailyClaim(reward: reward, cash: cash, respect: respect - respectBefore)
    }

    // MARK: - Nova identidade (prestígio)

    static func legacyEarned(lifetime: Double) -> Double {
        (max(lifetime, 0) / 1e10).squareRoot().rounded(.down)
    }

    var claimableLegacy: Double {
        max(Self.legacyEarned(lifetime: lifetimeTotal) - legacy, 0)
    }

    var canPrestige: Bool { claimableLegacy >= Self.minimumLegacyClaim && activeHeist == nil }

    /// Recomeça a carreira mantendo família, contratos, lenda e histórico.
    @discardableResult
    mutating func prestige() -> Bool {
        guard canPrestige else { return false }
        var fresh = CrimeState(seed: rng.next(), now: lastSeen)
        fresh.legacy = legacy + claimableLegacy
        fresh.crewLevels = crewLevels
        fresh.claimedContracts = claimedContracts
        fresh.lifetimeTotal = lifetimeTotal
        fresh.heistsCompleted = heistsCompleted
        fresh.prestigeCount = prestigeCount + 1
        fresh.taps = taps
        fresh.tutorial = .done
        fresh.manualRuns = manualRuns
        fresh.heistsStarted = heistsStarted
        fresh.dailyStreak = dailyStreak
        fresh.lastDailyDay = lastDailyDay
        fresh.cash = 5 + 100 * fresh.legacy
        self = fresh
        return true
    }
}
