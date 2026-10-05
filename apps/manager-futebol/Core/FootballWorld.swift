import Foundation

// MARK: - Vida do treinador

enum AssetKind: String, Codable, CaseIterable, Identifiable {
    case apartment, car, watch, beachHouse, farm, yacht

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apartment: return "Apartamento"
        case .car: return "Carro esportivo"
        case .watch: return "Relógio de luxo"
        case .beachHouse: return "Casa de praia"
        case .farm: return "Sítio"
        case .yacht: return "Lancha"
        }
    }

    var symbol: String {
        switch self {
        case .apartment: return "building.2.fill"
        case .car: return "car.fill"
        case .watch: return "applewatch"
        case .beachHouse: return "beach.umbrella.fill"
        case .farm: return "leaf.fill"
        case .yacht: return "sailboat.fill"
        }
    }

    var price: Int {
        switch self {
        case .apartment: return 420_000
        case .car: return 260_000
        case .watch: return 90_000
        case .beachHouse: return 900_000
        case .farm: return 650_000
        case .yacht: return 1_400_000
        }
    }

    /// Custo de manutenção por temporada.
    var upkeep: Int { price / 40 }

    /// Energia recuperada a mais em cada dia de descanso.
    var energyBonus: Int {
        switch self {
        case .apartment: return 4
        case .car: return 1
        case .watch: return 0
        case .beachHouse: return 8
        case .farm: return 7
        case .yacht: return 6
        }
    }

    /// Prestígio: soma na reputação percebida pelos patrocinadores pessoais e pela imprensa.
    var prestige: Int {
        switch self {
        case .apartment: return 1
        case .car: return 2
        case .watch: return 1
        case .beachHouse: return 3
        case .farm: return 2
        case .yacht: return 4
        }
    }

    var summary: String {
        switch self {
        case .apartment: return "Um lar tranquilo: descansa melhor e reduz o estresse."
        case .car: return "Dá status e pequenas vantagens nas redes sociais."
        case .watch: return "Item de coleção para patrocinadores e publis."
        case .beachHouse: return "Fins de semana de descanso: grande recuperação de energia."
        case .farm: return "Refúgio longe da imprensa: recupera energia e rende pouco."
        case .yacht: return "O símbolo máximo de sucesso. Caro de manter."
        }
    }
}

struct OwnedAsset: Codable, Equatable, Identifiable {
    let id: Int
    let kind: AssetKind
    let boughtSeason: Int
}

enum InvestmentKind: String, Codable, CaseIterable, Identifiable {
    case fund, franchise, realEstate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fund: return "Fundo de ações"
        case .franchise: return "Franquia de lanchonete"
        case .realEstate: return "Imóveis para aluguel"
        }
    }

    var summary: String {
        switch self {
        case .fund: return "Retorno alto em média, mas oscila muito."
        case .franchise: return "Retorno estável e baixo risco."
        case .realEstate: return "Aluguel constante e valorização lenta."
        }
    }

    var symbol: String {
        switch self {
        case .fund: return "chart.line.uptrend.xyaxis"
        case .franchise: return "fork.knife"
        case .realEstate: return "house.fill"
        }
    }

    /// Retorno médio e volatilidade por dia de jogo.
    var drift: Double {
        switch self {
        case .fund: return 0.006
        case .franchise: return 0.004
        case .realEstate: return 0.003
        }
    }

    var volatility: Double {
        switch self {
        case .fund: return 0.03
        case .franchise: return 0.006
        case .realEstate: return 0.008
        }
    }
}

struct Investment: Codable, Equatable, Identifiable {
    let id: Int
    let kind: InvestmentKind
    var principal: Int
    var value: Int
    let startedWorldDay: Int
}

enum CoachActivity: String, Codable, CaseIterable, Identifiable {
    case rest, study, tvPunditry, lecture, writeBook, schoolVisit, podcast, sponsorShoot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rest: return "Descansar"
        case .study: return "Estudar para a licença"
        case .tvPunditry: return "Comentarista de TV"
        case .lecture: return "Palestra"
        case .writeBook: return "Escrever um livro"
        case .schoolVisit: return "Visitar uma escola"
        case .podcast: return "Gravar podcast"
        case .sponsorShoot: return "Gravar comercial"
        }
    }

    var summary: String {
        switch self {
        case .rest: return "Recupera energia e reduz o estresse."
        case .study: return "Avança no curso de licença em andamento."
        case .tvPunditry: return "Rende dinheiro e seguidores, mas cansa."
        case .lecture: return "Cachê por uma palestra sobre liderança."
        case .writeBook: return "Seis sessões de escrita viram royalties para sempre."
        case .schoolVisit: return "Aproxima o clube da comunidade e agrada a torcida."
        case .podcast: return "Mais seguidores nas redes; pode render polêmica."
        case .sponsorShoot: return "Dinheiro rápido, mas cansa e pesa na imagem."
        }
    }

    var symbol: String {
        switch self {
        case .rest: return "bed.double.fill"
        case .study: return "graduationcap.fill"
        case .tvPunditry: return "tv.fill"
        case .lecture: return "person.wave.2.fill"
        case .writeBook: return "book.fill"
        case .schoolVisit: return "backpack.fill"
        case .podcast: return "mic.fill"
        case .sponsorShoot: return "camera.fill"
        }
    }

    var energyCost: Int {
        switch self {
        case .rest: return -30
        case .study: return 10
        case .tvPunditry: return 15
        case .lecture: return 10
        case .writeBook: return 14
        case .schoolVisit: return 8
        case .podcast: return 10
        case .sponsorShoot: return 12
        }
    }
}

struct CoachCourse: Codable, Equatable {
    let targetLicense: Int
    var sessionsDone: Int
    let sessionsNeeded: Int
}

struct CoachProfile: Codable, Equatable {
    var name = "Treinador"
    var personalCash = 150_000
    var energy = 80
    var stress = 20
    var licenseLevel = 1
    var course: CoachCourse? = nil
    var assets: [OwnedAsset] = []
    var investments: [Investment] = []
    var lastActivityWorldDay = -1
    var bookSessions = 0
    var booksPublished = 0
    var nextItemID = 1
    var contract: CoachContract? = nil

    static let licenseNames = ["Licença C", "Licença B", "Licença A", "Licença Pro"]
    static let courseCosts = [0, 40_000, 90_000, 180_000]
    static let courseSessions = [0, 6, 8, 10]
    static let courseMinimumReputation = [0, 25, 50, 70]

    var licenseName: String { Self.licenseNames[min(max(licenseLevel, 1), 4) - 1] }

    var prestige: Int { assets.reduce(0) { $0 + $1.kind.prestige } }
}

// MARK: - Rede social

enum SocialAuthor: String, Codable {
    case fan, journalist, player, club, rival, coach, brand, pundit
}

enum PostTone: String, Codable, CaseIterable, Identifiable {
    case motivational, humor, thanks, provocative, serious, sponsored

    var id: String { rawValue }

    var title: String {
        switch self {
        case .motivational: return "Motivacional"
        case .humor: return "Bom humor"
        case .thanks: return "Agradecimento"
        case .provocative: return "Provocação"
        case .serious: return "Sério"
        case .sponsored: return "Publi"
        }
    }

    var summary: String {
        switch self {
        case .motivational: return "Segurança: a torcida gosta, pouco risco."
        case .humor: return "Alcance alto, risco médio de gerar polêmica."
        case .thanks: return "Agrada torcida e elenco, sobe devagar."
        case .provocative: return "Pode viralizar, mas gera polêmica e irrita a diretoria."
        case .serious: return "Passa autoridade; engajamento baixo."
        case .sponsored: return "Paga o contrato de marca, mas cansa os seguidores."
        }
    }
}

struct SocialPost: Codable, Equatable, Identifiable {
    let id: Int
    let season: Int
    let matchDay: Int
    let author: SocialAuthor
    let name: String
    let handle: String
    var text: String
    var likes: Int
    var shares: Int
    var replies: Int
    /// -1 negativo, 0 neutro, 1 positivo para o clube.
    let sentiment: Int
    var isUser = false
    var tag: String? = nil
    var viral = false
    var sourceFactID: String? = nil
    var reliability: String? = nil
}

struct BrandDeal: Codable, Equatable, Identifiable {
    let id: Int
    let brand: String
    let payPerPost: Int
    let postsRequired: Int
    var postsDone: Int
    let endSeason: Int
    let minFollowers: Int
}

enum CrisisKind: String, Codable {
    case leakedChat, harshComment, oldPost, fakeNews
}

struct SocialCrisis: Codable, Equatable {
    let kind: CrisisKind
    let title: String
    let body: String
    let matchDay: Int
}

struct SocialState: Codable, Equatable {
    var coachFollowers = 12_000
    var clubFollowers = 300_000
    var posts: [SocialPost] = []
    var nextPostID = 1
    var lastPostWorldDay = -1
    var controversy = 0
    var verified = false
    var brandDeals: [BrandDeal] = []
    var brandOffers: [BrandDeal] = []
    var crisis: SocialCrisis? = nil
    var totalLikes = 0
    var viralPosts = 0
    var sponsoredStreak = 0
}

// MARK: - Palpite+ (apostas com fichas fictícias)

enum BetMarket: String, Codable, CaseIterable, Identifiable {
    case homeWin, draw, awayWin, over25, under25, bothScore, exactScore, scorer, qualify

    var id: String { rawValue }

    var title: String {
        switch self {
        case .homeWin: return "Vitória do mandante"
        case .draw: return "Empate"
        case .awayWin: return "Vitória do visitante"
        case .over25: return "Mais de 2,5 gols"
        case .under25: return "Menos de 2,5 gols"
        case .bothScore: return "Ambos marcam"
        case .exactScore: return "Placar exato"
        case .scorer: return "Marca a qualquer momento"
        case .qualify: return "Classifica-se"
        }
    }
}

struct BetLeg: Codable, Equatable, Identifiable {
    var id: String { "\(fixtureID)-\(market.rawValue)-\(a)-\(b)" }
    let fixtureID: Int
    let market: BetMarket
    /// Placar exato (a × b) ou id do atleta (a); para "classifica-se", a = id do clube.
    let a: Int
    let b: Int
    let odds: Double
    let description: String
    var won: Bool? = nil
}

enum BetStatus: String, Codable {
    case open, won, lost, void
}

struct Bet: Codable, Equatable, Identifiable {
    let id: Int
    let season: Int
    let placedMatchDay: Int
    let stake: Int
    var legs: [BetLeg]
    var status: BetStatus = .open
    var payout = 0

    var totalOdds: Double { legs.reduce(1.0) { $0 * $1.odds } }
    var potentialPayout: Int { Int(Double(stake) * totalOdds) }
}

enum OutrightMarket: String, Codable, CaseIterable, Identifiable {
    case leagueWinner, relegated, cupWinner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leagueWinner: return "Campeão da Série A"
        case .relegated: return "Rebaixado da Série A"
        case .cupWinner: return "Campeão da Copa"
        }
    }
}

struct OutrightBet: Codable, Equatable, Identifiable {
    let id: Int
    let season: Int
    let market: OutrightMarket
    let clubID: Int
    let stake: Int
    let odds: Double
    var status: BetStatus = .open
    var payout = 0
}

struct Tipster: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let skill: Double
    var profit: Int
    /// Histórico simulado de palpites (PAL-05); optional para saves antigos.
    var picks: Int? = nil
    var hits: Int? = nil
}

/// Rascunho persistido do bilhete (PAL-03); guarda as seleções e o valor.
struct BetDraft: Codable, Equatable {
    var legs: [BetLeg]
    var stake: Int
}

struct BettingState: Codable, Equatable {
    var fichas = 1_000
    var bets: [Bet] = []
    var outrights: [OutrightBet] = []
    var nextBetID = 1
    var lastDailyBonusWorldDay = -10
    var selfExcludedUntilWorldDay = -1
    var lossLimit = 1_000
    var lifetimeProfit = 0
    var seasonProfit = 0
    var wins = 0
    var losses = 0
    var biggestWin = 0
    var lossStreak = 0
    var emergencyUsedSeason = 0
    var tipsters: [Tipster] = []
    /// Ganhos e perdas por dia de jogo para o limite de responsabilidade.
    var dailyNet: [Int: Int] = [:]
    var draft: BetDraft? = nil
}

// MARK: - Rodada Mágica (fantasy)

struct FantasyRoundResult: Codable, Equatable, Identifiable {
    let round: Int
    let season: Int
    let points: Double
    let captainName: String
    let rank: Int

    var id: String { "\(season)-\(round)" }
}

struct FantasyManager: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    var points: Double
}

struct FantasyState: Codable, Equatable {
    static let budget = 100.0
    var lineup: [Int] = []
    var captainID: Int? = nil
    var history: [FantasyRoundResult] = []
    var seasonPoints = 0.0
    var managers: [FantasyManager] = []
    var lastScoredRound = 0
    var titles = 0
    /// Rascunho da escalação da próxima rodada (ROD-03); optional para saves antigos.
    var draft: FantasyDraft? = nil
}

// MARK: - Acontecimentos (eventos com decisões)

enum EventCategory: String, Codable {
    case dressingRoom, fans, media, board, finance, personal, community, luck
}

struct EventChoice: Codable, Equatable {
    let label: String
    let hint: String
}

struct WorldEvent: Codable, Equatable, Identifiable {
    let id: Int
    let templateID: String
    let category: EventCategory
    let season: Int
    let matchDay: Int
    let title: String
    let body: String
    let choices: [EventChoice]
    let expiresWorldDay: Int
    let defaultChoice: Int
    var playerID: Int? = nil
    var resolvedChoice: Int? = nil
    var resultText: String? = nil
}

struct EventsState: Codable, Equatable {
    var pending: [WorldEvent] = []
    var history: [WorldEvent] = []
    var nextEventID = 1
    var recentTemplates: [String] = []
}

// MARK: - Negócios do clube

enum ShopPrice: Int, Codable, CaseIterable, Identifiable {
    case low = 0, normal, high

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low: return "Promocional"
        case .normal: return "Normal"
        case .high: return "Premium"
        }
    }

    var margin: Double {
        switch self {
        case .low: return 0.72
        case .normal: return 1.0
        case .high: return 1.35
        }
    }

    var demand: Double {
        switch self {
        case .low: return 1.3
        case .normal: return 1.0
        case .high: return 0.75
        }
    }
}

enum CommunityProgram: String, Codable, CaseIterable, Identifiable {
    case schoolProject, footballAcademy, hospitalVisits, fanClubs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schoolProject: return "Projeto nas escolas"
        case .footballAcademy: return "Escolinha de futebol"
        case .hospitalVisits: return "Visitas a hospitais"
        case .fanClubs: return "Rede de torcidas"
        }
    }

    var summary: String {
        switch self {
        case .schoolProject: return "Mais torcedores jovens a longo prazo e boa imagem."
        case .footballAcademy: return "Revela talentos locais e traz receita pequena."
        case .hospitalVisits: return "Melhora a imagem do clube e a reputação do treinador."
        case .fanClubs: return "Cresce a torcida e o número de sócios."
        }
    }

    var symbol: String {
        switch self {
        case .schoolProject: return "backpack.fill"
        case .footballAcademy: return "figure.soccer"
        case .hospitalVisits: return "heart.fill"
        case .fanClubs: return "person.3.sequence.fill"
        }
    }

    var costPerSeason: Int {
        switch self {
        case .schoolProject: return 120_000
        case .footballAcademy: return 180_000
        case .hospitalVisits: return 60_000
        case .fanClubs: return 150_000
        }
    }
}

struct NamingRightsOffer: Codable, Equatable, Identifiable {
    let id: Int
    let sponsor: String
    let stadiumName: String
    let perSeason: Int
    let seasons: Int
}

struct NamingRightsDeal: Codable, Equatable {
    let sponsor: String
    let stadiumName: String
    let perSeason: Int
    var endSeason: Int
}

struct FriendlyRecord: Codable, Equatable, Identifiable {
    let id: Int
    let season: Int
    let opponentID: Int
    let home: Bool
    let goalsFor: Int
    let goalsAgainst: Int
    let revenue: Int
}

struct AgentOffer: Codable, Equatable, Identifiable {
    let id: Int
    let playerID: Int
    let agentName: String
    let discountedWage: Int
    let agentFee: Int
    let expiresWorldDay: Int
}

struct BusinessState: Codable, Equatable {
    var shopLevel = 1
    var shopPrice = ShopPrice.normal
    var collectionUntilWorldDay = -1
    var programs: [CommunityProgram] = []
    var namingOffers: [NamingRightsOffer] = []
    var naming: NamingRightsDeal? = nil
    var friendlies: [FriendlyRecord] = []
    var friendliesThisSeason = 0
    var agentOffers: [AgentOffer] = []
    var tourDoneSeason = 0
    var nextID = 1
}

// MARK: - Missões

struct QuestReward: Codable, Equatable {
    var fichas = 0
    var cash = 0
    var reputation = 0
    var followers = 0

    var text: String {
        var parts: [String] = []
        if fichas > 0 { parts.append("\(fichas) fichas") }
        if cash > 0 { parts.append(FootballFormat.money(cash)) }
        if reputation > 0 { parts.append("+\(reputation) reputação") }
        if followers > 0 { parts.append("+\(followers) seguidores") }
        return parts.joined(separator: " · ")
    }
}

struct Quest: Codable, Equatable, Identifiable {
    let id: Int
    let templateID: String
    let title: String
    let detail: String
    let counter: String
    let baseline: Int
    let target: Int
    let reward: QuestReward
    let expiresWorldDay: Int
    let seasonal: Bool
    var completed = false
    /// MET-01/04: origem e eventos que contaram para o progresso; optional para saves antigos.
    var origin: QuestOrigin? = nil
    var sourceName: String? = nil
    var contributions: [QuestContribution]? = nil
}

struct QuestState: Codable, Equatable {
    /// MET-05: conclusão, falha e substituição preservadas; optional para saves antigos.
    var history: [QuestRecord]? = nil
    var active: [Quest] = []
    var completedCount = 0
    var nextQuestID = 1
    var lastRefreshWorldDay = -100
}

// MARK: - Estado agregado

struct WorldState: Codable, Equatable {
    var coach = CoachProfile()
    var social = SocialState()
    var betting = BettingState()
    var fantasy = FantasyState()
    var events = EventsState()
    var business = BusinessState()
    var quests = QuestState()
    var growth = GrowthState()
    var contacts = ContactsState()
    var projects = ProjectsState()
    var commercial = CommercialState()
    var legacy = LegacyState()

    init() {}

    private enum CodingKeys: String, CodingKey { case coach, social, betting, fantasy, events, business, quests, growth, contacts, projects, commercial, legacy }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coach = try container.decodeIfPresent(CoachProfile.self, forKey: .coach) ?? CoachProfile()
        social = try container.decodeIfPresent(SocialState.self, forKey: .social) ?? SocialState()
        betting = try container.decodeIfPresent(BettingState.self, forKey: .betting) ?? BettingState()
        fantasy = try container.decodeIfPresent(FantasyState.self, forKey: .fantasy) ?? FantasyState()
        events = try container.decodeIfPresent(EventsState.self, forKey: .events) ?? EventsState()
        business = try container.decodeIfPresent(BusinessState.self, forKey: .business) ?? BusinessState()
        quests = try container.decodeIfPresent(QuestState.self, forKey: .quests) ?? QuestState()
        growth = try container.decodeIfPresent(GrowthState.self, forKey: .growth) ?? GrowthState()
        contacts = try container.decodeIfPresent(ContactsState.self, forKey: .contacts) ?? ContactsState()
        projects = try container.decodeIfPresent(ProjectsState.self, forKey: .projects) ?? ProjectsState()
        commercial = try container.decodeIfPresent(CommercialState.self, forKey: .commercial) ?? CommercialState()
        legacy = try container.decodeIfPresent(LegacyState.self, forKey: .legacy) ?? LegacyState()
    }
}
