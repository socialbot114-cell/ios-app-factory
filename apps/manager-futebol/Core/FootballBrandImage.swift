import Foundation

// MARK: - Marca: indicadores separados, campanha com briefing, contrato de imagem e evolução explicada (MAR-01…05)

/// Os três números que a torcida e o mercado enxergam, cada um com a sua origem (MAR-01).
struct BrandIndicators: Equatable {
    /// Imagem do treinador: reputação, menos polêmica, mais alcance nas redes.
    let coachImage: Int
    /// Força da marca do clube: campanhas, coleções e títulos; esfria sem investimento.
    let clubBrand: Int
    /// Humor da torcida: resultados, preço da loja, ações e promessas.
    let fanMood: Int

    static let definitions = [
        "Imagem do treinador": "Reputação menos polêmica nas redes, mais alcance. Muda com títulos, coletivas e crises.",
        "Marca do clube": "Cresce com campanhas e coleções de sucesso; cai 1 ponto a cada 6 jogos sem campanha.",
        "Humor da torcida": "Sobe com vitórias, festa no estádio e promoções; cai com derrotas e preços altos."
    ]
}

enum CampaignObjective: String, Codable, CaseIterable, Identifiable {
    case fans, brand, mood
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fans: return "Novos torcedores"
        case .brand: return "Força da marca"
        case .mood: return "Humor da torcida"
        }
    }
}

enum CampaignAudience: String, Codable, CaseIterable, Identifiable {
    case local, young, families
    var id: String { rawValue }
    var title: String {
        switch self {
        case .local: return "Cidade"
        case .young: return "Jovens"
        case .families: return "Famílias"
        }
    }
}

enum CampaignBudget: String, Codable, CaseIterable, Identifiable {
    case lean, standard, heavy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lean: return "Enxuto"
        case .standard: return "Padrão"
        case .heavy: return "Reforçado"
        }
    }
    var costFactor: Double { self == .lean ? 0.7 : (self == .standard ? 1.0 : 1.6) }
    var effect: Double { self == .lean ? 0.6 : (self == .standard ? 1.0 : 1.5) }
}

struct CampaignBrief: Codable, Equatable {
    var channel: MarketingCampaign
    var objective: CampaignObjective
    var audience: CampaignAudience
    var budget: CampaignBudget
}

/// Campanha com previsão no lançamento e avaliação no fim (MAR-02 / MAR-05).
struct CampaignRecord: Codable, Equatable, Identifiable {
    enum Verdict: String, Codable { case success, onTarget, below }

    let id: Int
    let brief: CampaignBrief
    let cost: Int
    let startWorldDay: Int
    let endWorldDay: Int
    let forecast: Double
    var realized = 0.0
    var verdict: Verdict? = nil

    var isRunning: Bool { verdict == nil }
}

/// Contrato de imagem do treinador com obrigações verificáveis (MAR-03).
struct ImageContract: Codable, Equatable, Identifiable {
    enum Status: String, Codable { case active, fulfilled, breached }

    let id: Int
    let brand: String
    let payment: Int
    let startWorldDay: Int
    let deadlineWorldDay: Int
    let shootsRequired: Int
    let minimumImage: Int
    var shootsDone = 0
    var hadCrisis = false
    var status: Status = .active
    var failures: [String] = []
}

struct BrandSnapshot: Codable, Equatable, Identifiable {
    let worldDay: Int
    let coachImage: Int
    let clubBrand: Int
    let fanMood: Int
    var id: Int { worldDay }
}

/// Uma mudança de indicador e o que a explica (MAR-04).
struct BrandMovement: Codable, Equatable, Identifiable {
    let id: Int
    let worldDay: Int
    let indicator: String
    let delta: Int
    let causes: [String]
}

struct BrandState: Codable, Equatable {
    var campaigns: [CampaignRecord] = []
    var contracts: [ImageContract] = []
    var snapshots: [BrandSnapshot] = []
    var movements: [BrandMovement] = []
    var nextID = 1

    init() {}

    private enum CodingKeys: String, CodingKey { case campaigns, contracts, snapshots, movements, nextID }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        campaigns = try container.decodeIfPresent([CampaignRecord].self, forKey: .campaigns) ?? []
        contracts = try container.decodeIfPresent([ImageContract].self, forKey: .contracts) ?? []
        snapshots = try container.decodeIfPresent([BrandSnapshot].self, forKey: .snapshots) ?? []
        movements = try container.decodeIfPresent([BrandMovement].self, forKey: .movements) ?? []
        nextID = try container.decodeIfPresent(Int.self, forKey: .nextID) ?? 1
    }
}

extension FootballCareer {
    static let brandHistoryLimit = 40

    var brandState: BrandState { world.projects.brand }

    // MARK: MAR-01

    var coachImage: Int {
        let reach = min(10, world.social.coachFollowers / 50_000)
        return min(100, max(0, reputation - world.social.controversy / 4 + reach))
    }

    var brandIndicators: BrandIndicators {
        BrandIndicators(coachImage: coachImage, clubBrand: world.growth.brand, fanMood: fanMood)
    }

    // MARK: MAR-02 — campanha com briefing

    /// Quanto o canal combina com o público (0,7 a 1,4).
    static func audienceFit(_ channel: MarketingCampaign, _ audience: CampaignAudience) -> Double {
        switch (channel, audience) {
        case (.localMedia, .local): return 1.2
        case (.localMedia, .young): return 0.7
        case (.regionalTV, .families): return 1.2
        case (.regionalTV, .young): return 0.8
        case (.influencers, .young): return 1.4
        case (.influencers, .local): return 0.7
        case (.influencers, .families): return 0.8
        case (.stadiumFest, .families): return 1.3
        case (.stadiumFest, .young): return 0.9
        default: return 1.0
        }
    }

    func campaignCost(_ brief: CampaignBrief) -> Int {
        Int(Double(brief.channel.cost) * brief.budget.costFactor / 1_000) * 1_000
    }

    /// Ganho diário extra no objetivo, sem sorte: base para a previsão.
    private func campaignDailyExtra(_ brief: CampaignBrief) -> Double {
        let intensity = 0.5 * Self.audienceFit(brief.channel, brief.audience) * brief.budget.effect
        switch brief.objective {
        case .fans: return Double(fanBase) * brief.channel.fanGrowth * intensity
        case .mood: return max(0.3, Double(brief.channel.moodPerDay)) * intensity
        case .brand: return Double(brief.channel.brandGain) * intensity / Double(brief.channel.days)
        }
    }

    /// Previsão no objetivo escolhido: o efeito normal do canal mais o reforço do briefing.
    func campaignForecast(_ brief: CampaignBrief) -> Double {
        let days = Double(brief.channel.days)
        let base: Double
        switch brief.objective {
        case .fans: base = Double(fanBase) * brief.channel.fanGrowth * days
        case .mood: base = Double(brief.channel.moodPerDay) * days
        case .brand: base = Double(brief.channel.brandGain)
        }
        return base + campaignDailyExtra(brief) * days
    }

    func campaignBlocker(_ brief: CampaignBrief) -> String? {
        guard selectedClubID != nil, !isFired else { return "Sem clube." }
        if world.growth.campaign != nil { return "Já existe uma campanha em andamento." }
        let cost = campaignCost(brief)
        if transferBudget < cost { return "Caixa insuficiente: faltam \(FootballFormat.money(cost - transferBudget))." }
        return nil
    }

    @discardableResult
    mutating func launchCampaign(_ brief: CampaignBrief) -> Bool {
        guard campaignBlocker(brief) == nil else { return false }
        let cost = campaignCost(brief)
        book(.marketing, -cost, "Campanha: \(brief.channel.title) · \(brief.objective.title.lowercased())")
        linkLastFinanceEntry(note: "Campanha: \(brief.channel.title) · \(brief.objective.title.lowercased())",
                             FinanceLink(kind: .campaign, id: "\(brandState.nextID)", title: brief.channel.title))
        world.growth.campaign = ActiveCampaign(kind: brief.channel, endsWorldDay: worldDay + brief.channel.days)
        world.projects.brand.campaigns.append(CampaignRecord(id: brandState.nextID, brief: brief, cost: cost, startWorldDay: worldDay,
                                                             endWorldDay: worldDay + brief.channel.days, forecast: campaignForecast(brief)))
        world.projects.brand.nextID += 1
        bump("campaigns")
        return true
    }

    /// Efeito diário do briefing e avaliação quando a campanha acaba. Chamado antes de `tickGrowth` no dia.
    mutating func progressBrandCampaign() {
        guard let index = brandState.campaigns.lastIndex(where: \.isRunning) else { return }
        let record = brandState.campaigns[index]
        guard world.growth.campaign != nil else {
            evaluateCampaign(at: index)
            return
        }
        var random = FootballRandom(seed: matchSeed(stream: .world, id: 83_000 + worldDay))
        let response = 0.6 + random.unit() * 0.8
        let extra = campaignDailyExtra(record.brief) * response
        let brief = record.brief
        // O efeito normal do canal (aplicado pelo tickGrowth) também conta no realizado do objetivo.
        switch brief.objective {
        case .fans:
            let base = Double(fanBase) * brief.channel.fanGrowth
            fanBase += Int(extra)
            world.projects.brand.campaigns[index].realized += base + Double(Int(extra))
        case .mood:
            let gained = Int(extra.rounded())
            fanMood = min(100, fanMood + gained)
            world.projects.brand.campaigns[index].realized += Double(brief.channel.moodPerDay + gained)
        case .brand:
            world.projects.brand.campaigns[index].realized += extra
            if worldDay >= record.endWorldDay { world.projects.brand.campaigns[index].realized += Double(brief.channel.brandGain) }
        }
    }

    private mutating func evaluateCampaign(at index: Int) {
        let record = brandState.campaigns[index]
        if record.brief.objective == .brand {
            let extra = Int(record.realized.rounded()) - record.brief.channel.brandGain
            if extra > 0 { world.growth.brand = min(100, world.growth.brand + extra) }
        }
        let ratio = record.forecast > 0 ? record.realized / record.forecast : 0
        let verdict: CampaignRecord.Verdict = ratio >= 1.1 ? .success : (ratio >= 0.85 ? .onTarget : .below)
        world.projects.brand.campaigns[index].verdict = verdict
        var body = "\(record.brief.channel.title) para \(record.brief.audience.title.lowercased()), objetivo \(record.brief.objective.title.lowercased()): previsto \(Self.formatObjective(record.forecast, record.brief.objective)), realizado \(Self.formatObjective(record.realized, record.brief.objective))."
        // Resultado reflete em demanda e propostas futuras (MAR-05).
        switch verdict {
        case .success:
            fanMood = min(100, fanMood + 2)
            var random = FootballRandom(seed: matchSeed(stream: .world, id: 84_000 + record.id))
            makeSlotOffers(using: &random)
            body += " Sucesso: torcida animada e patrocinadores refazem as propostas de cota com a marca nova."
        case .onTarget:
            body += " Dentro do esperado."
        case .below:
            world.growth.brand = max(0, world.growth.brand - 1)
            body += " Abaixo do esperado: o público não respondeu e a marca perde 1 ponto."
        }
        addInbox(.general, title: "Avaliação da campanha", body: body)
    }

    static func formatObjective(_ value: Double, _ objective: CampaignObjective) -> String {
        switch objective {
        case .fans: return "\(Int(value.rounded())) torcedores"
        case .mood: return "\(Int(value.rounded())) pt de humor"
        case .brand: return String(format: "%.1f pt de marca", value)
        }
    }

    // MARK: MAR-03 — contrato de imagem

    var activeImageContract: ImageContract? { brandState.contracts.last { $0.status == .active } }

    /// Proposta de uma marca: paga adiantado e cobra obrigações verificáveis em 10 dias de jogo.
    var imageContractOffer: ImageContract? {
        guard activeImageContract == nil, coachImage >= 35, selectedClubID != nil else { return nil }
        let names = Self.brands
        let brand = names[(worldDay + coachImage) % names.count]
        let payment = (40 + coachImage) * 1_000
        return ImageContract(id: brandState.nextID, brand: brand, payment: payment, startWorldDay: worldDay, deadlineWorldDay: worldDay + 10,
                             shootsRequired: 2, minimumImage: max(0, coachImage - 5))
    }

    @discardableResult
    mutating func signImageContract() -> Bool {
        guard let offer = imageContractOffer else { return false }
        world.projects.brand.contracts.append(offer)
        world.projects.brand.nextID += 1
        bookPersonal(offer.payment, "Contrato de imagem: \(offer.brand)", link: FinanceLink(kind: .contract, id: "\(offer.id)", title: offer.brand))
        logLife("Contrato de imagem com \(offer.brand)", "\(FootballFormat.money(offer.payment)) adiantados; \(offer.shootsRequired) comerciais e imagem ≥ \(offer.minimumImage) até o prazo.")
        return true
    }

    /// Conta comerciais gravados e crises; no prazo, confere cada obrigação. Chamado uma vez por dia de jogo.
    mutating func progressImageContract() {
        guard let index = brandState.contracts.lastIndex(where: { $0.status == .active }) else { return }
        if world.social.crisis != nil { world.projects.brand.contracts[index].hadCrisis = true }
        let contract = brandState.contracts[index]
        guard worldDay >= contract.deadlineWorldDay else { return }
        var failures: [String] = []
        if contract.shootsDone < contract.shootsRequired { failures.append("gravou \(contract.shootsDone) de \(contract.shootsRequired) comerciais") }
        if coachImage < contract.minimumImage { failures.append("imagem em \(coachImage), abaixo do mínimo de \(contract.minimumImage)") }
        if contract.hadCrisis { failures.append("houve crise de imagem durante o contrato") }
        world.projects.brand.contracts[index].failures = failures
        if failures.isEmpty {
            world.projects.brand.contracts[index].status = .fulfilled
            let bonus = contract.payment / 2
            bookPersonal(bonus, "Bônus do contrato: \(contract.brand)", link: FinanceLink(kind: .contract, id: "\(contract.id)", title: contract.brand))
            changeReputation(1)
            addInbox(.general, title: "\(contract.brand) renova a confiança",
                     body: "Todas as obrigações cumpridas: bônus de \(FootballFormat.money(bonus)) e reputação +1.")
        } else {
            world.projects.brand.contracts[index].status = .breached
            let refund = contract.payment / 2
            bookPersonal(-refund, "Multa do contrato: \(contract.brand)", link: FinanceLink(kind: .contract, id: "\(contract.id)", title: contract.brand))
            changeReputation(-1)
            addInbox(.general, title: "\(contract.brand) cobra o contrato",
                     body: "Obrigações descumpridas: \(failures.joined(separator: "; ")). Multa de \(FootballFormat.money(refund)) e reputação -1.")
        }
    }

    /// Chamado pela execução de atividades: comercial gravado conta para o contrato.
    mutating func noteImageActivity(_ activity: CoachActivity) {
        guard activity == .sponsorShoot, let index = brandState.contracts.lastIndex(where: { $0.status == .active }) else { return }
        world.projects.brand.contracts[index].shootsDone += 1
    }

    // MARK: MAR-04 — evolução e causas

    /// Registra os indicadores do dia e explica cada mudança pelos acontecimentos observáveis.
    mutating func recordBrandDay() {
        let today = brandIndicators
        let previous = brandState.snapshots.last
        let snapshot = BrandSnapshot(worldDay: worldDay, coachImage: today.coachImage, clubBrand: today.clubBrand, fanMood: today.fanMood)
        world.projects.brand.snapshots.removeAll { $0.worldDay == snapshot.worldDay }
        world.projects.brand.snapshots.append(snapshot)
        if brandState.snapshots.count > Self.brandHistoryLimit {
            world.projects.brand.snapshots.removeFirst(brandState.snapshots.count - Self.brandHistoryLimit)
        }
        guard let previous else { return }
        let causes = brandCauses()
        for (name, delta) in [("Imagem do treinador", today.coachImage - previous.coachImage),
                              ("Marca do clube", today.clubBrand - previous.clubBrand),
                              ("Humor da torcida", today.fanMood - previous.fanMood)] where delta != 0 {
            var reasons = causes
            if reasons.isEmpty {
                reasons = name == "Marca do clube" && delta < 0 ? ["Sem campanha: a marca esfria"] : ["Sem acontecimento marcante registrado"]
            }
            world.projects.brand.movements.append(BrandMovement(id: brandState.nextID, worldDay: worldDay, indicator: name, delta: delta, causes: reasons))
            world.projects.brand.nextID += 1
        }
        if brandState.movements.count > Self.brandHistoryLimit {
            world.projects.brand.movements.removeFirst(brandState.movements.count - Self.brandHistoryLimit)
        }
    }

    /// Acontecimentos do dia que acabou: resultado, campanha, crise e fatos públicos.
    private func brandCauses() -> [String] {
        var causes: [String] = []
        if let clubID = selectedClubID,
           let fixture = fixtures.first(where: { $0.matchDay == matchDayIndex - 1 && $0.involves(clubID) && $0.isPlayed }),
           let result = fixture.result(for: clubID) {
            let rival = FootballSeason.teamName(fixture.home == clubID ? fixture.away : fixture.home)
            let word = result == .win ? "Vitória" : (result == .loss ? "Derrota" : "Empate")
            causes.append("\(word) contra o \(rival)\(FootballSeason.isDerby(fixture.home, fixture.away) ? " (clássico)" : "")")
        }
        if let campaign = world.growth.campaign { causes.append("Campanha \(campaign.kind.title) no ar") }
        if let record = brandState.campaigns.last, record.verdict != nil, record.endWorldDay >= worldDay - 1 {
            causes.append("Fim da campanha \(record.brief.channel.title)")
        }
        if let crisis = world.social.crisis { causes.append("Crise: \(crisis.title)") }
        for fact in factStore.facts where fact.isPublic && fact.worldDay >= worldDay - 1 {
            causes.append(fact.title)
            if causes.count >= 5 { break }
        }
        return causes
    }
}
