import Foundation

struct FootballCareer: Codable, Equatable {
    static let saveKey = "football.career"
    static let backupKey = "football.career.backup"
    static let schemaVersion = 11
    static let rosterLimit = 18
    static let minimumRoster = 12
    static let quickSaleRate = 0.7

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case seed
        case season
        case matchDayIndex
        case currentRound
        case selectedClubID
        case transferBudget
        case formation
        case playStyle
        case trainingFocus
        case trainingIntensity
        case lastTrainingReport
        case startingXI
        case players
        case fixtures
        case champions
        case cupWinners
        case divisionOfTeam
        case boardTarget
        case boardConfidence
        case isFired
        case history
        case offers
        case nextOfferID
        case nextPlayerID
        case liveMatch
        case lastRoundRevenue
        case finance
        case inbox
        case nextInboxID
        case promises
        case nextPromiseID
        case wageCap
        case teamInstructions
        case playerRoles
        case penaltyTakerID
        case rivalMotivation
        case fanMood
        case clubHype
        case factStore
        case commitments
        case nextCommitmentID
        case playerMemories
        case talks
        case tacticalPlans
        case nextTalkID
        case pendingPress
        case transferLog
        case nextTransferID
        case scoutKnowledge
        case scoutMissions
        case scoutReports
        case nextScoutID
        case watchlist
        case pendingPayments
        case goalBonuses
        case nextPaymentID
        case youthCupHistory
        case youthAcademyLevel
        case lastYouthIntake
        case staff
        case staffMarket
        case nextStaffID
        case trainingCenterLevel
        case medicalLevel
        case stadiumLevel
        case upgradeProject
        case nextProjectID
        case ticketPrice
        case fanBase
        case sponsorDeal
        case sponsorOffers
        case redMatchDays
        case secondaryTrainingFocus
        case opponentPrep
        case headToHead
        case records
        case legends
        case reputation
        case invitations
        case leaderID
        case lastProtestMatchDay
        case difficulty
        case challenge
        case achievements
        case counters
        case tutorialSeen
        case tutorialDismissed
        case world
    }

    var seed: Int
    var season: Int
    /// Quantos dias de jogo do calendário já foram disputados nesta temporada.
    var matchDayIndex: Int
    var selectedClubID: Int?
    var transferBudget: Int
    var formation: FootballFormation
    var playStyle: FootballPlayStyle
    var trainingFocus: FootballTrainingFocus
    var trainingIntensity: FootballTrainingIntensity
    var lastTrainingReport: FootballTrainingReport?
    var startingXI: [Int]
    var players: [FootballPlayer]
    var fixtures: [LeagueFixture]
    /// Campeões da Série A, uma entrada por temporada.
    var champions: [Int]
    var cupWinners: [Int]
    /// Divisão atual de cada clube, indexada pelo id do clube.
    var divisionOfTeam: [Division]
    var boardTarget: Int
    var boardConfidence: Int
    var isFired: Bool
    var history: [SeasonRecord]
    var offers: [TransferOffer]
    var nextOfferID: Int
    var nextPlayerID: Int
    var liveMatch: LiveMatchState?
    var lastRoundRevenue: Int
    var finance: FinanceBook
    var inbox: [InboxMessage]
    var nextInboxID: Int
    var promises: [PlayerPromise]
    var nextPromiseID: Int
    var wageCap: Int
    var teamInstructions = TeamInstructions()
    var playerRoles: [Int: PlayerRole] = [:]
    var penaltyTakerID: Int? = nil
    /// Bônus de ataque que um rival ganha no próximo confronto por declarações provocadoras.
    var rivalMotivation: [Int: Double] = [:]
    var fanMood = 60
    /// Embalo da torcida (0 a 100): mais público e mais camisas depois de bons jogos.
    var clubHype = 0
    var factStore = FactStore()
    var commitments: [Commitment] = []
    var nextCommitmentID = 1
    var playerMemories: [PlayerMemory] = []
    var talks: [RenewalTalk] = []
    var tacticalPlans: [TacticalPlan] = []
    var nextTalkID = 1
    var pendingPress: PressConference? = nil
    var transferLog: [TransferRecord] = []
    var nextTransferID = 1
    /// Conhecimento do olheiro sobre cada atleta de fora do clube (0 a 100).
    var scoutKnowledge: [Int: Int] = [:]
    var scoutMissions: [ScoutMission] = []
    var scoutReports: [ScoutReport] = []
    var nextScoutID = 1
    var watchlist: [Int] = []
    var pendingPayments: [PendingPayment] = []
    var goalBonuses: [GoalBonus] = []
    var nextPaymentID = 1
    var youthCupHistory: [YouthCupResult] = []
    var youthAcademyLevel = 3
    var lastYouthIntake: [Int] = []
    var staff: [StaffMember] = []
    var staffMarket: [StaffMember] = []
    var nextStaffID = 1
    var trainingCenterLevel = 3
    var medicalLevel = 3
    var stadiumLevel = 1
    var upgradeProject: UpgradeProject? = nil
    var nextProjectID = 1
    var ticketPrice = TicketPrice.normal
    var fanBase = 40_000
    var sponsorDeal: SponsorDeal? = nil
    var sponsorOffers: [SponsorOffer] = []
    /// Dias de jogo seguidos com o caixa no vermelho.
    var redMatchDays = 0
    var secondaryTrainingFocus: FootballTrainingFocus? = nil
    var opponentPrep = false
    var headToHead: [String: HeadToHead] = [:]
    var records = ClubRecords()
    var legends: [LegendEntry] = []
    var reputation = 35
    var invitations: [JobInvitation] = []
    var leaderID: Int? = nil
    var lastProtestMatchDay = -10
    var difficulty = Difficulty.normal
    var challenge: ChallengeState? = nil
    /// Conquistas desbloqueadas: id e temporada em que saiu.
    var achievements: [String: Int] = [:]
    var counters: [String: Int] = [:]
    var tutorialSeen: [String] = []
    var tutorialDismissed = false
    var world = WorldState()
    /// Titulares do jogo em andamento (usado para as promessas aos atletas).
    var startingXIAtKickoff: Set<Int> = []
    /// Atletas que entraram em campo no dia de jogo em andamento (condição física e presença).
    var playedThisMatchDay: Set<Int> = []

    init(seed: Int) {
        self.seed = seed
        self.season = 1
        self.matchDayIndex = 0
        self.selectedClubID = nil
        self.transferBudget = 0
        self.formation = .fourFourTwo
        self.playStyle = .balanced
        self.trainingFocus = .tactical
        self.trainingIntensity = .balanced
        self.lastTrainingReport = nil
        self.startingXI = []
        let generatedPlayers = FootballSeason.generatePlayers(seed: seed)
        self.players = generatedPlayers
        self.fixtures = []
        self.champions = []
        self.cupWinners = []
        self.divisionOfTeam = FootballSeason.teams.map(\.initialDivision)
        self.boardTarget = 4
        self.boardConfidence = 60
        self.isFired = false
        self.history = []
        self.offers = []
        self.nextOfferID = 1
        self.nextPlayerID = (generatedPlayers.map(\.id).max() ?? 0) + 1
        self.liveMatch = nil
        self.lastRoundRevenue = 0
        self.finance = FinanceBook()
        self.inbox = []
        self.nextInboxID = 1
        self.promises = []
        self.nextPromiseID = 1
        self.wageCap = 0
        for index in players.indices where players[index].contract.endSeason == 0 && players[index].teamID != nil {
            players[index].contract.endSeason = 1 + (players[index].id % 4)
        }
        scheduleSeason()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let decodedSeed = try container.decodeIfPresent(Int.self, forKey: .seed) ?? 26
        let decodedClubID = try container.decodeIfPresent(Int.self, forKey: .selectedClubID)
        let decodedFormation = try container.decodeIfPresent(FootballFormation.self, forKey: .formation) ?? .fourFourTwo
        let decodedPlayers = try container.decodeIfPresent([FootballPlayer].self, forKey: .players)
            ?? FootballSeason.generatePlayers(seed: decodedSeed)
        seed = decodedSeed
        season = try container.decodeIfPresent(Int.self, forKey: .season) ?? 1
        matchDayIndex = try container.decodeIfPresent(Int.self, forKey: .matchDayIndex) ?? 0
        selectedClubID = decodedClubID
        transferBudget = try container.decodeIfPresent(Int.self, forKey: .transferBudget) ?? 0
        formation = decodedFormation
        playStyle = try container.decodeIfPresent(FootballPlayStyle.self, forKey: .playStyle) ?? .balanced
        trainingFocus = try container.decodeIfPresent(FootballTrainingFocus.self, forKey: .trainingFocus) ?? .tactical
        trainingIntensity = try container.decodeIfPresent(FootballTrainingIntensity.self, forKey: .trainingIntensity) ?? .balanced
        lastTrainingReport = try container.decodeIfPresent(FootballTrainingReport.self, forKey: .lastTrainingReport)
        players = decodedPlayers
        startingXI = try container.decodeIfPresent([Int].self, forKey: .startingXI)
            ?? decodedClubID.map { clubID in
                FootballSeason.bestLineup(roster: decodedPlayers.filter { $0.teamID == clubID }, formation: decodedFormation)
            }
            ?? []
        fixtures = try container.decodeIfPresent([LeagueFixture].self, forKey: .fixtures) ?? []
        champions = try container.decodeIfPresent([Int].self, forKey: .champions) ?? []
        cupWinners = try container.decodeIfPresent([Int].self, forKey: .cupWinners) ?? []
        divisionOfTeam = try container.decodeIfPresent([Division].self, forKey: .divisionOfTeam)
            ?? FootballSeason.teams.map(\.initialDivision)
        boardTarget = try container.decodeIfPresent(Int.self, forKey: .boardTarget) ?? 4
        boardConfidence = try container.decodeIfPresent(Int.self, forKey: .boardConfidence) ?? 60
        isFired = try container.decodeIfPresent(Bool.self, forKey: .isFired) ?? false
        history = try container.decodeIfPresent([SeasonRecord].self, forKey: .history) ?? []
        offers = try container.decodeIfPresent([TransferOffer].self, forKey: .offers) ?? []
        nextOfferID = try container.decodeIfPresent(Int.self, forKey: .nextOfferID) ?? 1
        nextPlayerID = try container.decodeIfPresent(Int.self, forKey: .nextPlayerID)
            ?? (decodedPlayers.map(\.id).max() ?? 0) + 1
        liveMatch = version >= 5 ? try container.decodeIfPresent(LiveMatchState.self, forKey: .liveMatch) : nil
        lastRoundRevenue = try container.decodeIfPresent(Int.self, forKey: .lastRoundRevenue) ?? 0
        finance = try container.decodeIfPresent(FinanceBook.self, forKey: .finance) ?? FinanceBook()
        inbox = try container.decodeIfPresent([InboxMessage].self, forKey: .inbox) ?? []
        nextInboxID = try container.decodeIfPresent(Int.self, forKey: .nextInboxID) ?? 1
        promises = try container.decodeIfPresent([PlayerPromise].self, forKey: .promises) ?? []
        nextPromiseID = try container.decodeIfPresent(Int.self, forKey: .nextPromiseID) ?? 1
        wageCap = try container.decodeIfPresent(Int.self, forKey: .wageCap) ?? 0
        teamInstructions = try container.decodeIfPresent(TeamInstructions.self, forKey: .teamInstructions) ?? TeamInstructions()
        playerRoles = try container.decodeIfPresent([Int: PlayerRole].self, forKey: .playerRoles) ?? [:]
        penaltyTakerID = try container.decodeIfPresent(Int.self, forKey: .penaltyTakerID)
        rivalMotivation = try container.decodeIfPresent([Int: Double].self, forKey: .rivalMotivation) ?? [:]
        fanMood = try container.decodeIfPresent(Int.self, forKey: .fanMood) ?? 60
        clubHype = try container.decodeIfPresent(Int.self, forKey: .clubHype) ?? 0
        factStore = try container.decodeIfPresent(FactStore.self, forKey: .factStore) ?? FactStore()
        commitments = try container.decodeIfPresent([Commitment].self, forKey: .commitments) ?? []
        nextCommitmentID = try container.decodeIfPresent(Int.self, forKey: .nextCommitmentID) ?? 1
        playerMemories = try container.decodeIfPresent([PlayerMemory].self, forKey: .playerMemories) ?? []
        talks = try container.decodeIfPresent([RenewalTalk].self, forKey: .talks) ?? []
        tacticalPlans = try container.decodeIfPresent([TacticalPlan].self, forKey: .tacticalPlans) ?? []
        nextTalkID = try container.decodeIfPresent(Int.self, forKey: .nextTalkID) ?? 1
        pendingPress = try container.decodeIfPresent(PressConference.self, forKey: .pendingPress)
        transferLog = try container.decodeIfPresent([TransferRecord].self, forKey: .transferLog) ?? []
        nextTransferID = try container.decodeIfPresent(Int.self, forKey: .nextTransferID) ?? 1
        scoutKnowledge = try container.decodeIfPresent([Int: Int].self, forKey: .scoutKnowledge) ?? [:]
        scoutMissions = try container.decodeIfPresent([ScoutMission].self, forKey: .scoutMissions) ?? []
        scoutReports = try container.decodeIfPresent([ScoutReport].self, forKey: .scoutReports) ?? []
        nextScoutID = try container.decodeIfPresent(Int.self, forKey: .nextScoutID) ?? 1
        watchlist = try container.decodeIfPresent([Int].self, forKey: .watchlist) ?? []
        pendingPayments = try container.decodeIfPresent([PendingPayment].self, forKey: .pendingPayments) ?? []
        goalBonuses = try container.decodeIfPresent([GoalBonus].self, forKey: .goalBonuses) ?? []
        nextPaymentID = try container.decodeIfPresent(Int.self, forKey: .nextPaymentID) ?? 1
        youthCupHistory = try container.decodeIfPresent([YouthCupResult].self, forKey: .youthCupHistory) ?? []
        youthAcademyLevel = try container.decodeIfPresent(Int.self, forKey: .youthAcademyLevel) ?? 3
        lastYouthIntake = try container.decodeIfPresent([Int].self, forKey: .lastYouthIntake) ?? []
        staff = try container.decodeIfPresent([StaffMember].self, forKey: .staff) ?? []
        staffMarket = try container.decodeIfPresent([StaffMember].self, forKey: .staffMarket) ?? []
        nextStaffID = try container.decodeIfPresent(Int.self, forKey: .nextStaffID) ?? 1
        trainingCenterLevel = try container.decodeIfPresent(Int.self, forKey: .trainingCenterLevel) ?? 3
        medicalLevel = try container.decodeIfPresent(Int.self, forKey: .medicalLevel) ?? 3
        stadiumLevel = try container.decodeIfPresent(Int.self, forKey: .stadiumLevel) ?? 1
        upgradeProject = try container.decodeIfPresent(UpgradeProject.self, forKey: .upgradeProject)
        nextProjectID = try container.decodeIfPresent(Int.self, forKey: .nextProjectID) ?? 1
        ticketPrice = try container.decodeIfPresent(TicketPrice.self, forKey: .ticketPrice) ?? .normal
        fanBase = try container.decodeIfPresent(Int.self, forKey: .fanBase)
            ?? Int(Double(decodedClubID.flatMap { FootballSeason.team($0)?.capacity } ?? 30_000) * 1.15)
        sponsorDeal = try container.decodeIfPresent(SponsorDeal.self, forKey: .sponsorDeal)
        sponsorOffers = try container.decodeIfPresent([SponsorOffer].self, forKey: .sponsorOffers) ?? []
        redMatchDays = try container.decodeIfPresent(Int.self, forKey: .redMatchDays) ?? 0
        secondaryTrainingFocus = try container.decodeIfPresent(FootballTrainingFocus.self, forKey: .secondaryTrainingFocus)
        opponentPrep = try container.decodeIfPresent(Bool.self, forKey: .opponentPrep) ?? false
        headToHead = try container.decodeIfPresent([String: HeadToHead].self, forKey: .headToHead) ?? [:]
        records = try container.decodeIfPresent(ClubRecords.self, forKey: .records) ?? ClubRecords()
        legends = try container.decodeIfPresent([LegendEntry].self, forKey: .legends) ?? []
        reputation = try container.decodeIfPresent(Int.self, forKey: .reputation) ?? 35
        invitations = try container.decodeIfPresent([JobInvitation].self, forKey: .invitations) ?? []
        leaderID = try container.decodeIfPresent(Int.self, forKey: .leaderID)
        lastProtestMatchDay = try container.decodeIfPresent(Int.self, forKey: .lastProtestMatchDay) ?? -10
        difficulty = try container.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .normal
        challenge = try container.decodeIfPresent(ChallengeState.self, forKey: .challenge)
        achievements = try container.decodeIfPresent([String: Int].self, forKey: .achievements) ?? [:]
        counters = try container.decodeIfPresent([String: Int].self, forKey: .counters) ?? [:]
        tutorialSeen = try container.decodeIfPresent([String].self, forKey: .tutorialSeen) ?? []
        tutorialDismissed = try container.decodeIfPresent(Bool.self, forKey: .tutorialDismissed) ?? false
        world = try container.decodeIfPresent(WorldState.self, forKey: .world) ?? WorldState()
        if version < 3 { migrateToWorldV3() }
        if version < 4 { migrateToPlayersV4() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(seed, forKey: .seed)
        try container.encode(season, forKey: .season)
        try container.encode(matchDayIndex, forKey: .matchDayIndex)
        try container.encodeIfPresent(selectedClubID, forKey: .selectedClubID)
        try container.encode(transferBudget, forKey: .transferBudget)
        try container.encode(formation, forKey: .formation)
        try container.encode(playStyle, forKey: .playStyle)
        try container.encode(trainingFocus, forKey: .trainingFocus)
        try container.encode(trainingIntensity, forKey: .trainingIntensity)
        try container.encodeIfPresent(lastTrainingReport, forKey: .lastTrainingReport)
        try container.encode(startingXI, forKey: .startingXI)
        try container.encode(players, forKey: .players)
        try container.encode(fixtures, forKey: .fixtures)
        try container.encode(champions, forKey: .champions)
        try container.encode(cupWinners, forKey: .cupWinners)
        try container.encode(divisionOfTeam, forKey: .divisionOfTeam)
        try container.encode(boardTarget, forKey: .boardTarget)
        try container.encode(boardConfidence, forKey: .boardConfidence)
        try container.encode(isFired, forKey: .isFired)
        try container.encode(history, forKey: .history)
        try container.encode(offers, forKey: .offers)
        try container.encode(nextOfferID, forKey: .nextOfferID)
        try container.encode(nextPlayerID, forKey: .nextPlayerID)
        try container.encodeIfPresent(liveMatch, forKey: .liveMatch)
        try container.encode(lastRoundRevenue, forKey: .lastRoundRevenue)
        try container.encode(finance, forKey: .finance)
        try container.encode(inbox, forKey: .inbox)
        try container.encode(nextInboxID, forKey: .nextInboxID)
        try container.encode(promises, forKey: .promises)
        try container.encode(nextPromiseID, forKey: .nextPromiseID)
        try container.encode(wageCap, forKey: .wageCap)
        try container.encode(teamInstructions, forKey: .teamInstructions)
        try container.encode(playerRoles, forKey: .playerRoles)
        try container.encodeIfPresent(penaltyTakerID, forKey: .penaltyTakerID)
        try container.encode(rivalMotivation, forKey: .rivalMotivation)
        try container.encode(fanMood, forKey: .fanMood)
        try container.encode(clubHype, forKey: .clubHype)
        try container.encode(factStore, forKey: .factStore)
        try container.encode(commitments, forKey: .commitments)
        try container.encode(nextCommitmentID, forKey: .nextCommitmentID)
        try container.encode(playerMemories, forKey: .playerMemories)
        try container.encode(talks, forKey: .talks)
        try container.encode(tacticalPlans, forKey: .tacticalPlans)
        try container.encode(nextTalkID, forKey: .nextTalkID)
        try container.encodeIfPresent(pendingPress, forKey: .pendingPress)
        try container.encode(transferLog, forKey: .transferLog)
        try container.encode(nextTransferID, forKey: .nextTransferID)
        try container.encode(scoutKnowledge, forKey: .scoutKnowledge)
        try container.encode(scoutMissions, forKey: .scoutMissions)
        try container.encode(scoutReports, forKey: .scoutReports)
        try container.encode(nextScoutID, forKey: .nextScoutID)
        try container.encode(watchlist, forKey: .watchlist)
        try container.encode(pendingPayments, forKey: .pendingPayments)
        try container.encode(goalBonuses, forKey: .goalBonuses)
        try container.encode(nextPaymentID, forKey: .nextPaymentID)
        try container.encode(youthCupHistory, forKey: .youthCupHistory)
        try container.encode(youthAcademyLevel, forKey: .youthAcademyLevel)
        try container.encode(lastYouthIntake, forKey: .lastYouthIntake)
        try container.encode(staff, forKey: .staff)
        try container.encode(staffMarket, forKey: .staffMarket)
        try container.encode(nextStaffID, forKey: .nextStaffID)
        try container.encode(trainingCenterLevel, forKey: .trainingCenterLevel)
        try container.encode(medicalLevel, forKey: .medicalLevel)
        try container.encode(stadiumLevel, forKey: .stadiumLevel)
        try container.encodeIfPresent(upgradeProject, forKey: .upgradeProject)
        try container.encode(nextProjectID, forKey: .nextProjectID)
        try container.encode(ticketPrice, forKey: .ticketPrice)
        try container.encode(fanBase, forKey: .fanBase)
        try container.encodeIfPresent(sponsorDeal, forKey: .sponsorDeal)
        try container.encode(sponsorOffers, forKey: .sponsorOffers)
        try container.encode(redMatchDays, forKey: .redMatchDays)
        try container.encodeIfPresent(secondaryTrainingFocus, forKey: .secondaryTrainingFocus)
        try container.encode(opponentPrep, forKey: .opponentPrep)
        try container.encode(headToHead, forKey: .headToHead)
        try container.encode(records, forKey: .records)
        try container.encode(legends, forKey: .legends)
        try container.encode(reputation, forKey: .reputation)
        try container.encode(invitations, forKey: .invitations)
        try container.encodeIfPresent(leaderID, forKey: .leaderID)
        try container.encode(lastProtestMatchDay, forKey: .lastProtestMatchDay)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encodeIfPresent(challenge, forKey: .challenge)
        try container.encode(achievements, forKey: .achievements)
        try container.encode(counters, forKey: .counters)
        try container.encode(tutorialSeen, forKey: .tutorialSeen)
        try container.encode(tutorialDismissed, forKey: .tutorialDismissed)
        try container.encode(world, forKey: .world)
    }

    /// Save v3: atletas ganham contratos coerentes e o teto salarial é definido a partir da folha atual.
    private mutating func migrateToPlayersV4() {
        for index in players.indices where players[index].contract.endSeason == 0 && players[index].teamID != nil {
            players[index].contract.endSeason = season + (players[index].id % 4)
        }
        if selectedClubID != nil && wageCap == 0 { wageCap = Int(Double(wageBill) * 1.25) }
    }

    /// Save v1/v2 (liga única de 8 clubes): mantém clube, elenco, caixa, histórico e títulos,
    /// cria os clubes novos e reinicia a temporada atual no formato de duas divisões com copa.
    private mutating func migrateToWorldV3() {
        var random = FootballRandom(seed: UInt64(bitPattern: Int64(seed)) ^ 0x76335F776F726C64)
        let existingTeams = Set(players.compactMap(\.teamID))
        for team in FootballSeason.teams where !existingTeams.contains(team.id) {
            for position in FootballSeason.squadTemplate {
                let overall = team.strength + random.int(in: -9...9)
                let age = random.int(in: 18...34)
                let growth = age <= 22 ? random.int(in: 8...17) : (age <= 27 ? random.int(in: 1...8) : random.int(in: 0...3))
                players.append(FootballSeason.makePlayer(id: nextPlayerID, position: position, age: age, overall: overall,
                                                         potential: overall + growth, teamID: team.id, using: &random))
                nextPlayerID += 1
            }
        }
        divisionOfTeam = FootballSeason.teams.map(\.initialDivision)
        matchDayIndex = 0
        liveMatch = nil
        offers = []
        lastTrainingReport = nil
        for index in players.indices {
            players[index].goals = 0
            players[index].assists = 0
            players[index].appearances = 0
            players[index].injuryRounds = 0
        }
        scheduleSeason()
        if selectedClubID != nil {
            repairLineup()
            boardTarget = computeBoardTarget()
        }
    }

    // MARK: - Persistência legada (UserDefaults)

    static func randomSeed() -> Int { Int.random(in: 1...9_999_999) }

    /// Carrega o save antigo do UserDefaults. Um save ilegível é preservado em uma chave de backup.
    static func load(defaults: UserDefaults = .standard) -> FootballCareer {
        guard let data = defaults.data(forKey: saveKey) else { return FootballCareer(seed: randomSeed()) }
        do {
            return try JSONDecoder().decode(FootballCareer.self, from: data)
        } catch {
            defaults.set(data, forKey: backupKey)
            return FootballCareer(seed: randomSeed())
        }
    }

    func persist(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.saveKey)
    }

    // MARK: - Consultas

    var selectedClub: LeagueTeam? {
        guard let selectedClubID else { return nil }
        return FootballSeason.team(selectedClubID)
    }

    /// Categoria de base do clube do usuário.
    var youthRoster: [FootballPlayer] {
        guard let selectedClubID else { return [] }
        return players.filter { $0.teamID == selectedClubID && $0.isYouth }.sorted { $0.potential > $1.potential }
    }

    var clubRoster: [FootballPlayer] {
        guard let selectedClubID else { return [] }
        return players(forTeam: selectedClubID)
    }

    var starters: [FootballPlayer] {
        startingXI.compactMap { player($0) }
    }

    var marketPlayers: [FootballPlayer] {
        players.filter { $0.teamID == nil }.sorted {
            if $0.overall != $1.overall { return $0.overall > $1.overall }
            return $0.name < $1.name
        }
    }

    var calendar: [MatchDaySlot] { FootballSeason.calendar }

    var currentSlot: MatchDaySlot? {
        calendar.indices.contains(matchDayIndex) ? calendar[matchDayIndex] : nil
    }

    var isSeasonComplete: Bool { matchDayIndex >= FootballSeason.matchDaysPerSeason }

    /// Rodadas de liga já disputadas.
    var completedLeagueRounds: Int {
        calendar.prefix(matchDayIndex).filter { $0.leagueRound != nil }.count
    }

    func division(of teamID: Int) -> Division {
        divisionOfTeam.indices.contains(teamID) ? divisionOfTeam[teamID] : .serieB
    }

    var userDivision: Division? {
        selectedClubID.map { division(of: $0) }
    }

    func teamIDs(in division: Division) -> [Int] {
        FootballSeason.teams.map(\.id).filter { self.division(of: $0) == division }
    }

    func standings(for division: Division) -> [FootballStanding] {
        FootballSeason.standings(teamIDs: teamIDs(in: division),
                                 fixtures: fixtures.filter { $0.competition == .league(division) })
    }

    /// Tabela da divisão do usuário.
    var standings: [FootballStanding] {
        standings(for: userDivision ?? .serieA)
    }

    var userPosition: Int? {
        guard let selectedClubID else { return nil }
        return standings.firstIndex { $0.team.id == selectedClubID }.map { $0 + 1 }
    }

    var currentFixtures: [LeagueFixture] {
        fixtures.filter { $0.matchDay == matchDayIndex }
    }

    var nextUserFixture: LeagueFixture? {
        guard let selectedClubID, !isSeasonComplete else { return nil }
        return currentFixtures.first { !$0.isPlayed && $0.involves(selectedClubID) }
    }

    /// Próxima partida do usuário em qualquer dia de jogo futuro (para o calendário).
    var upcomingUserFixtures: [LeagueFixture] {
        guard let selectedClubID else { return [] }
        return fixtures
            .filter { !$0.isPlayed && $0.involves(selectedClubID) && $0.matchDay >= matchDayIndex }
            .sorted { $0.matchDay < $1.matchDay }
    }

    var latestUserFixture: LeagueFixture? {
        guard let selectedClubID else { return nil }
        return fixtures
            .filter { $0.isPlayed && $0.involves(selectedClubID) }
            .max { $0.matchDay < $1.matchDay }
    }

    var championID: Int? {
        guard isSeasonComplete else { return nil }
        return standings(for: .serieA).first?.team.id
    }

    var cupFixtures: [LeagueFixture] {
        fixtures.filter { $0.competition.isCup }.sorted {
            if $0.matchDay != $1.matchDay { return $0.matchDay < $1.matchDay }
            return $0.id < $1.id
        }
    }

    var cupWinnerThisSeason: Int? {
        cupFixtures.first { $0.competition == .cup(.final) && $0.isPlayed }?.winner
    }

    /// Situação do usuário na copa: "Campeão", "Eliminado nas quartas de final", "Na semifinal"…
    var userCupStatus: String {
        guard let selectedClubID else { return "—" }
        let mine = cupFixtures.filter { $0.involves(selectedClubID) }
        guard let last = mine.last, let round = last.competition.cupRound else {
            let preliminaryDrawn = cupFixtures.contains { $0.competition == .cup(.preliminary) }
            return preliminaryDrawn && !isSeasonComplete ? "Estreia nas oitavas de final" : "Não disputou"
        }
        guard last.isPlayed else { return "Próxima fase: \(round.name.lowercased())" }
        if last.winner == selectedClubID {
            return round == .final ? "Campeão" : "Classificado para \(round.next.map { $0 == .roundOf16 || $0 == .quarterFinal ? "as \($0.name.lowercased())" : "a \($0.name.lowercased())" } ?? "a próxima fase")"
        }
        return round == .final ? "Vice-campeão" : "Eliminado \(round.withPreposition)"
    }

    var isEliminatedFromCup: Bool {
        guard let selectedClubID else { return true }
        return cupFixtures.contains { $0.isPlayed && $0.involves(selectedClubID) && $0.winner != selectedClubID }
    }

    var canPlay: Bool {
        selectedClubID != nil && !isSeasonComplete && !isFired && nextUserFixture != nil
    }

    /// Há um dia de jogo em que o usuário não entra em campo (fase da copa sem o clube).
    var canAdvanceWithoutPlaying: Bool {
        selectedClubID != nil && !isSeasonComplete && !isFired && liveMatch == nil && nextUserFixture == nil
    }

    var objectiveText: String { Self.objectiveText(target: boardTarget, division: userDivision ?? .serieA) }

    static func objectiveText(target: Int, division: Division) -> String {
        switch (division, target) {
        case (_, 1): return "Conquistar o título"
        case (.serieB, 2): return "Conquistar o acesso"
        case (.serieA, FootballSeason.teamsPerDivision - FootballSeason.relegationSpots):
            return "Evitar o rebaixamento"
        default: return "Terminar entre os \(target) primeiros"
        }
    }

    /// Clubes que querem contratar o treinador depois de uma demissão ou pedido de demissão.
    var jobOffers: [LeagueTeam] {
        guard isFired else { return [] }
        let others = FootballSeason.teams.filter { $0.id != selectedClubID }
        let reachable = others.filter { clubPrestige($0.id) <= maxPrestige }.sorted { clubPrestige($0.id) > clubPrestige($1.id) }
        var offers = Array(reachable.prefix(3))
        if offers.count < 3 {
            let extra = others.filter { club in !offers.contains(where: { $0.id == club.id }) }.sorted { $0.strength < $1.strength }
            offers += extra.prefix(3 - offers.count)
        }
        return offers
    }

    func player(_ id: Int) -> FootballPlayer? {
        players.first { $0.id == id }
    }

    func players(forTeam teamID: Int) -> [FootballPlayer] {
        players.filter { $0.teamID == teamID && !$0.isYouth }.sorted {
            if $0.position.sortOrder != $1.position.sortOrder { return $0.position.sortOrder < $1.position.sortOrder }
            if $0.overall != $1.overall { return $0.overall > $1.overall }
            return $0.name < $1.name
        }
    }

    /// Artilharia da temporada (todas as competições). Com `division`, só atletas de clubes dessa divisão.
    func topScorers(limit: Int = 10, division: Division? = nil) -> [FootballPlayer] {
        Array(players.filter { player in
            guard player.goals > 0 else { return false }
            guard let division else { return true }
            return player.teamID.map { self.division(of: $0) == division } ?? false
        }.sorted {
            if $0.goals != $1.goals { return $0.goals > $1.goals }
            if $0.assists != $1.assists { return $0.assists > $1.assists }
            return $0.name < $1.name
        }.prefix(limit))
    }

    func form(teamID: Int) -> [FootballResult] {
        standings(for: division(of: teamID)).first { $0.team.id == teamID }?.form ?? []
    }

    /// Formação usada por um clube da IA: a preferida, se o elenco disponível permitir.
    func aiFormation(teamID: Int) -> FootballFormation {
        let roster = players.filter { $0.teamID == teamID }
        if let preferred = FootballSeason.team(teamID)?.preferredFormation,
           FootballSeason.canFill(roster: roster, formation: preferred) {
            return preferred
        }
        return FootballFormation.allCases.first { FootballSeason.canFill(roster: roster, formation: $0) } ?? .fourFourTwo
    }

    func formation(for teamID: Int) -> FootballFormation {
        teamID == selectedClubID ? formation : aiFormation(teamID: teamID)
    }

    func lineup(for teamID: Int) -> [Int] {
        if teamID == selectedClubID, startingXI.count == 11 { return startingXI }
        return FootballSeason.bestLineup(roster: players.filter { $0.teamID == teamID }, formation: formation(for: teamID), matchDay: matchDayIndex)
    }

    func teamRating(_ teamID: Int) -> Double {
        let lineupPlayers = lineup(for: teamID).compactMap { player($0) }
        return FootballSeason.rating(of: lineupPlayers, formation: formation(for: teamID))
    }

    /// Estilo que a IA escolhe para uma partida: recua contra favoritos e se impõe contra os mais fracos.
    func aiStyle(teamID: Int, opponentID: Int) -> FootballPlayStyle {
        guard let team = FootballSeason.team(teamID) else { return .balanced }
        let difference = teamRating(teamID) - teamRating(opponentID)
        if difference <= -4 {
            return team.id.isMultiple(of: 2) ? .counter : .defensive
        }
        if difference >= 4 {
            switch team.preferredStyle {
            case .defensive, .counter: return .possession
            default: return team.preferredStyle
            }
        }
        return team.preferredStyle
    }

    func style(for teamID: Int, against opponentID: Int) -> FootballPlayStyle {
        teamID == selectedClubID ? playStyle : aiStyle(teamID: teamID, opponentID: opponentID)
    }

    /// Reação da IA no intervalo, conforme o placar.
    func aiSecondHalfStyle(teamID: Int, opponentID: Int, goalsFor: Int, goalsAgainst: Int) -> FootballPlayStyle {
        if goalsFor < goalsAgainst { return .attacking }
        if goalsFor - goalsAgainst >= 2 { return .defensive }
        return aiStyle(teamID: teamID, opponentID: opponentID)
    }

    /// Estilo do rival que o auxiliar aponta. Durante o jogo, o que o rival realmente está usando.
    var predictedOpponentStyle: FootballPlayStyle? {
        if let live = liveMatch {
            return live.userIsHome ? live.sim.away.style : live.sim.home.style
        }
        guard let fixture = nextUserFixture else { return nil }
        return scoutedOpponentStyle(for: fixture).style
    }

    /// Se o auxiliar leu o rival corretamente (só o analista de desempenho revela o erro).
    var opponentReadIsReliable: Bool {
        guard let fixture = nextUserFixture else { return true }
        return scoutedOpponentStyle(for: fixture).isCorrect
    }

    var lineupWarnings: [String] {
        var warnings: [String] = []
        let starters = self.starters
        let injured = starters.filter { !$0.isAvailable(matchDay: matchDayIndex) }
        if !injured.isEmpty {
            warnings.append("\(injured.count) titular(es) indisponível(is) (lesão, suspensão ou seleção) serão substituídos automaticamente.")
        }
        let tired = starters.filter { !$0.isInjured && $0.condition < 65 }
        if !tired.isEmpty {
            warnings.append("\(tired.count) titular(es) com energia abaixo de 65%.")
        }
        let outOfPosition = FootballSeason.outOfPositionCount(lineup: starters, formation: formation)
        if outOfPosition > 0 {
            warnings.append("\(outOfPosition) atleta(s) improvisado(s) fora de posição.")
        }
        if let limit = starterAgeLimit, let old = starters.first(where: { $0.age > limit }) {
            warnings.append("Desafio: \(old.name) tem \(old.age) anos e o limite para titulares é \(limit).")
        }
        if let slot = currentSlot, slot.isMidweek, nextUserFixture != nil {
            warnings.append("Jogo no meio de semana: o elenco recupera só metade da energia. Considere poupar titulares.")
        }
        return warnings
    }

    // MARK: - Clube e diretoria

    mutating func chooseClub(_ clubID: Int) -> Bool {
        guard selectedClubID == nil, let club = FootballSeason.team(clubID) else { return false }
        selectedClubID = club.id
        transferBudget = club.startingBudget
        boardConfidence = 60
        startingXI = FootballSeason.bestLineup(roster: clubRoster, formation: formation, matchDay: matchDayIndex)
        boardTarget = computeBoardTarget()
        wageCap = Int(Double(wageBill) * 1.25)
        setupClubInfrastructure()
        reputation = initialReputation(for: club)
        return startingXI.count == 11
    }

    @discardableResult
    mutating func acceptJob(_ clubID: Int) -> Bool {
        guard isFired, liveMatch == nil, clubID != selectedClubID,
              jobOffers.contains(where: { $0.id == clubID }) else { return false }
        takeOverClub(clubID, budgetFraction: 0.5, confidence: 55)
        bump("rehired")
        return true
    }

    /// Meta da diretoria pela força do elenco dentro da própria divisão.
    func computeBoardTarget() -> Int {
        guard let selectedClubID else { return 4 }
        return boardTarget(forClub: selectedClubID)
    }

    // MARK: - Tática e escalação

    @discardableResult
    mutating func setFormation(_ newFormation: FootballFormation) -> Bool {
        guard selectedClubID != nil, FootballSeason.canFill(roster: clubRoster, formation: newFormation) else { return false }
        formation = newFormation
        startingXI = rebuiltLineup(keeping: startingXI, formation: newFormation)
        return true
    }

    mutating func setPlayStyle(_ newStyle: FootballPlayStyle) {
        playStyle = newStyle
    }

    mutating func setTrainingFocus(_ newFocus: FootballTrainingFocus) {
        trainingFocus = newFocus
        if secondaryTrainingFocus == newFocus { secondaryTrainingFocus = nil }
    }

    mutating func setTrainingIntensity(_ newIntensity: FootballTrainingIntensity) {
        trainingIntensity = newIntensity
    }

    mutating func autoSelectLineup() {
        guard liveMatch == nil else { return }
        startingXI = eligibleLineup()
    }

    /// Mantém os titulares escolhidos que ainda servem à formação e completa as vagas com os melhores disponíveis.
    func rebuiltLineup(keeping current: [Int], formation: FootballFormation) -> [Int] {
        let roster = lineupEligibleRoster.filter { $0.isAvailable(matchDay: matchDayIndex) }
        var chosen: [Int] = []
        for position in FootballPosition.allCases {
            let required = formation.requiredPlayers[position, default: 0]
            let kept = roster
                .filter { $0.canPlay(as: position) && current.contains($0.id) && !chosen.contains($0.id) }
                .sorted(by: FootballSeason.strongerFirst)
                .prefix(required)
                .map(\.id)
            chosen.append(contentsOf: kept)
            if kept.count < required {
                let fill = roster
                    .filter { $0.canPlay(as: position) && !chosen.contains($0.id) }
                    .sorted(by: FootballSeason.strongerFirst)
                    .prefix(required - kept.count)
                    .map(\.id)
                chosen.append(contentsOf: fill)
            }
        }
        if chosen.count < 11 {
            let extras = roster
                .filter { !chosen.contains($0.id) }
                .sorted(by: FootballSeason.strongerFirst)
                .prefix(11 - chosen.count)
                .map(\.id)
            chosen.append(contentsOf: extras)
        }
        if chosen.count < 11 {
            let everyone = players.filter { $0.teamID == selectedClubID }
            chosen.append(contentsOf: FootballSeason.emergencyFill(roster: everyone, excluding: chosen, count: 11 - chosen.count, matchDay: matchDayIndex))
        }
        return chosen
    }

    /// Remove lesionados e ex-atletas da escalação, repondo pela mesma posição sempre que possível.
    mutating func repairLineup() {
        guard let selectedClubID else { return }
        var lineup: [Int] = []
        for id in startingXI where !lineup.contains(id) {
            if let candidate = player(id), candidate.teamID == selectedClubID, candidate.isAvailable(matchDay: matchDayIndex), !candidate.isYouth {
                lineup.append(id)
            }
        }
        if lineup.count > 11 { lineup = Array(lineup.prefix(11)) }
        if lineup.count < 11 || lineup.count != startingXI.count {
            lineup = rebuiltLineup(keeping: lineup, formation: formation)
        }
        startingXI = lineup
    }

    // MARK: - Mercado

    func quickSalePrice(playerID: Int) -> Int {
        guard let player = player(playerID) else { return 0 }
        return Int(Double(player.marketValue) * Self.quickSaleRate / 10_000) * 10_000
    }

    func canSell(playerID: Int) -> Bool {
        guard isTransferWindowOpen, let athlete = player(playerID), !athlete.onLoan else { return false }
        return canRelease(playerID: playerID)
    }

    @discardableResult
    mutating func sellPlayer(playerID: Int) -> Bool {
        guard canSell(playerID: playerID), let index = players.firstIndex(where: { $0.id == playerID }) else { return false }
        book(.playerSales, quickSalePrice(playerID: playerID), "Venda de \(players[index].name)")
        players[index].teamID = nil
        players[index].isListed = false
        players[index].isLoanListed = false
        offers.removeAll { $0.playerID == playerID }
        repairLineup()
        return true
    }

    func canSign(playerID: Int) -> Bool {
        guard selectedClubID != nil, liveMatch == nil, !isFired,
              let player = player(playerID), player.teamID == nil else { return false }
        return clubRoster.count < Self.rosterLimit && transferBudget >= player.marketValue
            && wageCapAllows(extra: player.contract.wage) && !isTransferBanned
    }

    /// Por que o atleta não pode ser contratado agora (nil quando pode).
    func signBlockReason(playerID: Int) -> String? {
        guard let player = player(playerID), player.teamID == nil else { return "Atleta indisponível." }
        if liveMatch != nil { return "Termine a partida antes de contratar." }
        if clubRoster.count >= Self.rosterLimit { return "Elenco completo: venda um atleta antes." }
        if isTransferBanned { return "O clube está proibido de contratar por causa da dívida (transfer ban)." }
        if transferBudget < player.marketValue { return "Caixa insuficiente." }
        if !wageCapAllows(extra: player.contract.wage) { return "A folha salarial passaria do teto definido pela diretoria." }
        return nil
    }

    @discardableResult
    mutating func signPlayer(playerID: Int, years: Int = 2) -> Bool {
        guard canSign(playerID: playerID), let selectedClubID,
              let index = players.firstIndex(where: { $0.id == playerID }) else { return false }
        book(.playerPurchases, -players[index].marketValue, "Contratação de \(players[index].name)")
        players[index].teamID = selectedClubID
        players[index].goals = 0
        players[index].assists = 0
        players[index].appearances = 0
        players[index].benchStreak = 0
        bump("signings")
        players[index].morale = 70
        players[index].form = PlayerForm()
        let status = expectedStatus(of: players[index])
        players[index].contract = PlayerContract(wage: players[index].contract.wage, endSeason: season + max(1, years) - 1, status: status)
        return true
    }

    func canAccept(offerID: Int) -> Bool {
        guard let offer = offers.first(where: { $0.id == offerID }) else { return false }
        return canSell(playerID: offer.playerID)
    }

    @discardableResult
    mutating func acceptOffer(_ offerID: Int) -> Bool {
        guard canAccept(offerID: offerID), let offer = offers.first(where: { $0.id == offerID }) else { return false }
        if offer.kind == .loan { return acceptLoanOffer(offerID) }
        guard let index = players.firstIndex(where: { $0.id == offer.playerID }) else { return false }
        book(.playerSales, offer.amount, "Venda de \(players[index].name) para \(FootballSeason.teamName(offer.clubID))")
        players[index].teamID = offer.clubID
        players[index].isListed = false
        players[index].isLoanListed = false
        players[index].morale = 60
        players[index].contract.endSeason = season + 3
        logTransfer(playerID: offer.playerID, name: players[index].name, from: selectedClubID, to: offer.clubID, fee: offer.amount)
        offers.removeAll { $0.playerID == offer.playerID }
        var random = FootballRandom(seed: matchSeed(stream: .transfers, id: 400 + offer.playerID))
        normalizeSquad(teamID: offer.clubID, using: &random)
        repairLineup()
        return true
    }

    mutating func rejectOffer(_ offerID: Int) {
        offers.removeAll { $0.id == offerID }
    }

    // MARK: - Treino

    /// Treino antes de um dia de jogo. No meio de semana o elenco recupera metade e não há evolução técnica.
    @discardableResult
    mutating func applyWeeklyTraining(for matchDay: Int, midweek: Bool = false) -> FootballTrainingReport {
        guard let selectedClubID else {
            let emptyReport = FootballTrainingReport(round: matchDay, focus: trainingFocus, intensity: trainingIntensity,
                                                     developedPlayers: 0, averageConditionGain: 0)
            lastTrainingReport = emptyReport
            return emptyReport
        }

        var random = FootballRandom(seed: matchSeed(stream: .training, id: matchDay))
        let rosterIndices = players.indices.filter { players[$0].teamID == selectedClubID }
        var developedPlayers = 0
        var totalConditionGain = 0
        var recovery = trainingIntensity.conditionRecovery(for: trainingFocus)
        if secondaryTrainingFocus == .recovery { recovery += 4 }
        recovery += max(0, (fitnessAbilityValue - 8) / 4)
        let goalkeeperFactor = 1 + 0.03 * Double((staffAbility(.goalkeeperCoach) ?? 8) - 8)

        for index in rosterIndices {
            let player = players[index]
            let conditionBefore = player.condition
            players[index].condition = min(100, conditionBefore + (midweek ? recovery / 2 : recovery))
            totalConditionGain += players[index].condition - conditionBefore

            // Aprender uma nova posição no treino individual.
            if !midweek, !player.isInjured, let learning = player.learningPosition {
                players[index].learningProgress += player.age <= 24 ? 2 : 1
                if players[index].learningProgress >= 6 {
                    players[index].learnedPositions.append(learning)
                    players[index].learningPosition = nil
                    players[index].learningProgress = 0
                    addInbox(.general, title: "\(player.name) aprendeu uma posição",
                             body: "\(player.name) já pode atuar como \(learning.title.lowercased()) com pouca perda de rendimento.", playerID: player.id)
                }
            }

            guard !midweek, !player.isInjured, player.overall < player.potential else { continue }
            let individual = player.individualFocus
            var chance = 0.0
            let ageFactor = ageMultiplier(player.age)
            if trainingFocus.developmentPositions.contains(player.position) {
                chance += Double(trainingIntensity.developmentChance) * ageFactor
            }
            if let secondary = secondaryTrainingFocus, secondary.developmentPositions.contains(player.position) {
                chance += Double(trainingIntensity.developmentChance) * ageFactor * 0.5
            }
            chance *= trainingFacilityFactor
            if player.position == .goalkeeper { chance *= goalkeeperFactor }
            if player.has(.prodigy) && player.age <= 22 { chance *= 1.25 }
            if opponentPrep { chance *= 0.7 }
            if individual != nil { chance += 12 }
            guard chance > 0, random.int(in: 0...99) < min(80, Int(chance)) else { continue }

            var pool = FootballPlayer.trainableAttributes(focus: trainingFocus, position: player.position).filter { player.attributes[$0] < 20 }
            if let secondary = secondaryTrainingFocus {
                pool += FootballPlayer.trainableAttributes(focus: secondary, position: player.position).filter { player.attributes[$0] < 20 }
            }
            if let individual, player.attributes[individual] < 20 { pool = [individual] + pool }
            guard !pool.isEmpty else { continue }
            var candidate = player.attributes
            var gained = 0
            for slot in 0..<2 {
                let choice = slot == 0 ? pool[0] : pool[random.int(in: 0...(pool.count - 1))]
                if candidate[choice] < 20 { candidate[choice] += 1; gained += 1 }
            }
            guard gained > 0, candidate.overall(for: player.position) <= player.potential else { continue }
            players[index].attributes = candidate
            players[index].recomputeOverall()
            refreshValue(at: index)
            developedPlayers += 1
        }

        let averageConditionGain = rosterIndices.isEmpty ? 0 : totalConditionGain / rosterIndices.count
        let report = FootballTrainingReport(round: matchDay + 1, focus: trainingFocus, intensity: trainingIntensity,
                                            developedPlayers: developedPlayers, averageConditionGain: averageConditionGain)
        lastTrainingReport = report
        return report
    }

    func ageMultiplier(_ age: Int) -> Double {
        if age <= 21 { return 1.35 }
        if age <= 25 { return 1.15 }
        if age >= 30 { return 0.6 }
        return 1.0
    }

    mutating func refreshValue(at index: Int) {
        let player = players[index]
        players[index].marketValue = FootballSeason.marketValue(overall: player.overall, age: player.age, potential: player.potential)
    }

    // MARK: - Aleatoriedade por subsistema

    /// Cada subsistema usa um fluxo próprio, para que mudar um não altere os resultados dos outros.
    enum RandomStream: UInt64 {
        case match = 1, secondHalf, extraTime, penalties, training, postMatch, offseason, cupDraw, transfers
        case world, social, betting, events, fantasy, business, quests
    }

    func matchSeed(stream: RandomStream, id: Int) -> UInt64 {
        UInt64(bitPattern: Int64(seed))
            &+ UInt64(season) &* 0x9E3779B97F4A7C15
            &+ UInt64(id + 1) &* 0xBF58476D1CE4E5B9
            &+ stream.rawValue &* 0x94D049BB133111EB
    }
}
