import Foundation

// MARK: - Projeto comercial: coleção da loja (F4-02 / NEG-01 / NEG-02 / NEG-06)

enum CollectionAudience: String, Codable, CaseIterable, Identifiable {
    case youth, traditional, premium

    var id: String { rawValue }

    var title: String {
        switch self {
        case .youth: return "Torcida jovem"
        case .traditional: return "Torcedor tradicional"
        case .premium: return "Linha premium"
        }
    }

    var driver: String {
        switch self {
        case .youth: return "Responde ao embalo do clube."
        case .traditional: return "Responde ao humor da torcida."
        case .premium: return "Responde à reputação e à estrutura da loja."
        }
    }
}

enum CollectionSize: String, Codable, CaseIterable, Identifiable {
    case capsule, season, flagship

    var id: String { rawValue }

    var title: String {
        switch self {
        case .capsule: return "Cápsula"
        case .season: return "Coleção da temporada"
        case .flagship: return "Coleção principal"
        }
    }

    /// Multiplicador do custo-base da coleção.
    var costFactor: Double {
        switch self {
        case .capsule: return 1
        case .season: return 2
        case .flagship: return 3.5
        }
    }

    /// Aumento das vendas da loja enquanto a coleção está à venda.
    var boost: Double {
        switch self {
        case .capsule: return 0.3
        case .season: return 0.45
        case .flagship: return 0.6
        }
    }

    var matchDays: Int {
        switch self {
        case .capsule: return 6
        case .season: return 8
        case .flagship: return 10
        }
    }
}

struct CollectionBrief: Codable, Equatable {
    var audience: CollectionAudience
    var size: CollectionSize
}

struct CollectionProject: Codable, Equatable, Identifiable {
    enum Verdict: String, Codable { case success, onTarget, below }

    let id: Int
    let clubID: Int
    let brief: CollectionBrief
    let cost: Int
    let startWorldDay: Int
    let endWorldDay: Int
    let forecast: Int
    /// Vendas extras realizadas, uma entrada por dia de jogo.
    var dailySales: [Int] = []
    var verdict: Verdict? = nil

    var realized: Int { dailySales.reduce(0, +) }
    var isActive: Bool { verdict == nil }
    var returnOnInvestment: Double { cost > 0 ? Double(realized - cost) / Double(cost) : 0 }
    var name: String { "\(brief.size.title) · \(brief.audience.title)" }
}

struct CommercialState: Codable, Equatable {
    var collections: [CollectionProject] = []
    var nextID = 1
    /// Gerente comercial que lança coleções sozinho (F4-05).
    var delegation: CommercialDelegation? = nil

    init() {}

    private enum CodingKeys: String, CodingKey { case collections, nextID, delegation }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        collections = try container.decodeIfPresent([CollectionProject].self, forKey: .collections) ?? []
        nextID = try container.decodeIfPresent(Int.self, forKey: .nextID) ?? 1
        delegation = try container.decodeIfPresent(CommercialDelegation.self, forKey: .delegation)
    }
}

extension FootballCareer {
    static let collectionCooldown = 4
    static let collectionHistoryLimit = 10

    var activeCollection: CollectionProject? {
        world.commercial.collections.last { $0.isActive && $0.clubID == selectedClubID }
    }

    /// Vendas da loja sem coleção: base para medir o efeito real do projeto.
    var baseMerchRevenuePerMatchDay: Int {
        let mood = (0.7 + 0.006 * Double(fanMood)) * hypeMerchFactor
        let base = Double(fanBase) * 0.30 * shopRevenueFactor * world.business.shopPrice.demand * world.business.shopPrice.margin * mood
        let legacyCollection = world.business.collectionUntilWorldDay >= worldDay ? 1.3 : 1.0
        return Int(base * legacyCollection / 100) * 100
    }

    /// Quanto o público escolhido responde hoje (0,5 a 1,5). Repetir o público da coleção anterior cansa.
    func audienceFit(_ audience: CollectionAudience) -> Double {
        var fit: Double
        switch audience {
        case .youth: fit = 0.6 + Double(clubHype) / 100 * 0.9
        case .traditional: fit = 0.5 + Double(fanMood) / 100 * 0.9
        case .premium: fit = 0.4 + Double(reputation) / 100 * 0.7 + Double(world.business.shopLevel - 1) * 0.1
        }
        let previous = world.commercial.collections.last { !$0.isActive && $0.clubID == selectedClubID }
        if previous?.brief.audience == audience { fit *= 0.85 }
        return min(1.5, max(0.5, fit))
    }

    func collectionCost(_ brief: CollectionBrief) -> Int {
        Int(Double(collectionCost()) * brief.size.costFactor / 10_000) * 10_000
    }

    /// Vendas extras de um dia com o briefing e o momento atuais.
    func collectionExtra(_ brief: CollectionBrief) -> Int {
        Int(Double(baseMerchRevenuePerMatchDay) * brief.size.boost * audienceFit(brief.audience) / 100) * 100
    }

    /// Previsão no lançamento: o momento de hoje mantido por toda a duração.
    func collectionForecast(_ brief: CollectionBrief) -> Int { collectionExtra(brief) * brief.size.matchDays }

    func collectionBlocker(_ brief: CollectionBrief) -> String? {
        guard let selectedClubID, !isFired else { return "Você está sem clube." }
        if activeCollection != nil || world.business.collectionUntilWorldDay >= worldDay { return "Já existe uma coleção à venda." }
        if let last = world.commercial.collections.last(where: { $0.clubID == selectedClubID }),
           worldDay - last.endWorldDay < Self.collectionCooldown {
            return "A loja precisa de \(Self.collectionCooldown) dias de jogo entre coleções."
        }
        if transferBudget < collectionCost(brief) { return "Caixa insuficiente para o investimento." }
        return nil
    }

    @discardableResult
    mutating func launchCollection(_ brief: CollectionBrief) -> Bool {
        guard collectionBlocker(brief) == nil, let selectedClubID else { return false }
        let cost = collectionCost(brief)
        let project = CollectionProject(id: world.commercial.nextID, clubID: selectedClubID, brief: brief, cost: cost,
                                        startWorldDay: worldDay, endWorldDay: worldDay + brief.size.matchDays,
                                        forecast: collectionForecast(brief))
        world.commercial.nextID += 1
        world.commercial.collections.append(project)
        book(.merchandise, -cost, "Lançamento: \(project.name)")
        return true
    }

    /// Vendas extras da coleção ativa: lançadas a cada dia de jogo, com relatório na metade e avaliação no fim.
    mutating func progressCollections() {
        guard let index = world.commercial.collections.lastIndex(where: { $0.isActive }) else { return }
        let project = world.commercial.collections[index]
        guard project.clubID == selectedClubID, !isFired else {
            world.commercial.collections[index].verdict = .below
            return
        }
        let extra = collectionExtra(project.brief)
        world.commercial.collections[index].dailySales.append(extra)
        book(.merchandise, extra, "Vendas extras: \(project.name)")
        let sold = world.commercial.collections[index]
        if sold.dailySales.count == project.brief.size.matchDays / 2 {
            addInbox(.finance, title: "Relatório de vendas: \(project.name)",
                     body: "Metade do período: \(FootballFormat.money(sold.realized)) em vendas extras, previsão total de \(FootballFormat.money(project.forecast)).")
        }
        if sold.dailySales.count >= project.brief.size.matchDays { evaluateCollection(at: index) }
        if world.commercial.collections.count > Self.collectionHistoryLimit {
            world.commercial.collections.removeFirst(world.commercial.collections.count - Self.collectionHistoryLimit)
        }
    }

    private mutating func evaluateCollection(at index: Int) {
        let project = world.commercial.collections[index]
        let ratio = project.forecast > 0 ? Double(project.realized) / Double(project.forecast) : 0
        let verdict: CollectionProject.Verdict = ratio >= 1.1 ? .success : (ratio >= 0.85 ? .onTarget : .below)
        world.commercial.collections[index].verdict = verdict
        let roi = Int((project.returnOnInvestment * 100).rounded())
        var body = "Previsto \(FootballFormat.money(project.forecast)), realizado \(FootballFormat.money(project.realized)) para um investimento de \(FootballFormat.money(project.cost)) (retorno \(roi)%)."
        switch verdict {
        case .success:
            world.growth.brand = min(100, world.growth.brand + 2)
            fanMood = min(100, fanMood + 2)
            body += " Sucesso de vendas: marca +2 e torcida mais animada."
        case .onTarget:
            body += " Resultado dentro do esperado."
        case .below:
            fanMood = max(0, fanMood - 1)
            body += " Encalhe: a torcida não comprou a ideia."
        }
        addInbox(.finance, title: "Avaliação da coleção: \(project.name)", body: body)
    }
}
