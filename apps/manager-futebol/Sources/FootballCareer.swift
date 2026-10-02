import Foundation

struct FootballCareer: Codable, Equatable {
    static let saveKey = "football.career"
    static let backupKey = "football.career.backup"
    static let schemaVersion = 2
    static let rosterLimit = 18
    static let minimumRoster = 12
    static let quickSaleRate = 0.7

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case seed
        case season
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
        case boardTarget
        case boardConfidence
        case isFired
        case history
        case offers
        case nextOfferID
        case nextPlayerID
        case liveMatch
        case lastRoundRevenue
    }

    var seed: Int
    var season: Int
    var currentRound: Int
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
    var champions: [Int]
    var boardTarget: Int
    var boardConfidence: Int
    var isFired: Bool
    var history: [SeasonRecord]
    var offers: [TransferOffer]
    var nextOfferID: Int
    var nextPlayerID: Int
    var liveMatch: LiveMatchState?
    var lastRoundRevenue: Int

    init(seed: Int) {
        self.seed = seed
        self.season = 1
        self.currentRound = 0
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
        self.fixtures = FootballSeason.fixtures()
        self.champions = []
        self.boardTarget = 4
        self.boardConfidence = 60
        self.isFired = false
        self.history = []
        self.offers = []
        self.nextOfferID = 1
        self.nextPlayerID = (generatedPlayers.map(\.id).max() ?? 0) + 1
        self.liveMatch = nil
        self.lastRoundRevenue = 0
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSeed = try container.decodeIfPresent(Int.self, forKey: .seed) ?? 26
        let decodedClubID = try container.decodeIfPresent(Int.self, forKey: .selectedClubID)
        let decodedFormation = try container.decodeIfPresent(FootballFormation.self, forKey: .formation) ?? .fourFourTwo
        let decodedPlayers = try container.decodeIfPresent([FootballPlayer].self, forKey: .players)
            ?? FootballSeason.generatePlayers(seed: decodedSeed)
        seed = decodedSeed
        season = try container.decodeIfPresent(Int.self, forKey: .season) ?? 1
        currentRound = try container.decodeIfPresent(Int.self, forKey: .currentRound) ?? 0
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
        fixtures = try container.decodeIfPresent([LeagueFixture].self, forKey: .fixtures) ?? FootballSeason.fixtures()
        champions = try container.decodeIfPresent([Int].self, forKey: .champions) ?? []
        boardTarget = try container.decodeIfPresent(Int.self, forKey: .boardTarget) ?? 4
        boardConfidence = try container.decodeIfPresent(Int.self, forKey: .boardConfidence) ?? 60
        isFired = try container.decodeIfPresent(Bool.self, forKey: .isFired) ?? false
        history = try container.decodeIfPresent([SeasonRecord].self, forKey: .history) ?? []
        offers = try container.decodeIfPresent([TransferOffer].self, forKey: .offers) ?? []
        nextOfferID = try container.decodeIfPresent(Int.self, forKey: .nextOfferID) ?? 1
        nextPlayerID = try container.decodeIfPresent(Int.self, forKey: .nextPlayerID)
            ?? (decodedPlayers.map(\.id).max() ?? 0) + 1
        liveMatch = try container.decodeIfPresent(LiveMatchState.self, forKey: .liveMatch)
        lastRoundRevenue = try container.decodeIfPresent(Int.self, forKey: .lastRoundRevenue) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(seed, forKey: .seed)
        try container.encode(season, forKey: .season)
        try container.encode(currentRound, forKey: .currentRound)
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
        try container.encode(boardTarget, forKey: .boardTarget)
        try container.encode(boardConfidence, forKey: .boardConfidence)
        try container.encode(isFired, forKey: .isFired)
        try container.encode(history, forKey: .history)
        try container.encode(offers, forKey: .offers)
        try container.encode(nextOfferID, forKey: .nextOfferID)
        try container.encode(nextPlayerID, forKey: .nextPlayerID)
        try container.encodeIfPresent(liveMatch, forKey: .liveMatch)
        try container.encode(lastRoundRevenue, forKey: .lastRoundRevenue)
    }

    // MARK: - Persistência

    static func randomSeed() -> Int { Int.random(in: 1...9_999_999) }

    /// Carrega o save. Um save ilegível é preservado em uma chave de backup antes de começar do zero.
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

    var isSeasonComplete: Bool { currentRound >= FootballSeason.roundsPerSeason }

    var standings: [FootballStanding] { FootballSeason.standings(results: fixtures) }

    var userPosition: Int? {
        guard let selectedClubID else { return nil }
        return standings.firstIndex { $0.team.id == selectedClubID }.map { $0 + 1 }
    }

    var nextUserFixture: LeagueFixture? {
        guard let selectedClubID, !isSeasonComplete else { return nil }
        return fixtures.first { $0.round == currentRound + 1 && !$0.isPlayed && $0.involves(selectedClubID) }
    }

    var latestUserFixture: LeagueFixture? {
        guard let selectedClubID else { return nil }
        return fixtures
            .filter { $0.isPlayed && $0.involves(selectedClubID) }
            .max { $0.round < $1.round }
    }

    var championID: Int? {
        guard isSeasonComplete else { return nil }
        return standings.first?.team.id
    }

    var canPlay: Bool {
        selectedClubID != nil && !isSeasonComplete && !isFired && nextUserFixture != nil
    }

    var objectiveText: String { Self.objectiveText(target: boardTarget) }

    static func objectiveText(target: Int) -> String {
        switch target {
        case 1: return "Conquistar o título"
        default: return "Terminar entre os \(target) primeiros"
        }
    }

    var jobOffers: [LeagueTeam] {
        guard isFired else { return [] }
        return FootballSeason.teams
            .filter { $0.id != selectedClubID }
            .sorted { $0.strength < $1.strength }
            .prefix(3)
            .map { $0 }
    }

    func player(_ id: Int) -> FootballPlayer? {
        players.first { $0.id == id }
    }

    func players(forTeam teamID: Int) -> [FootballPlayer] {
        players.filter { $0.teamID == teamID }.sorted {
            if $0.position.sortOrder != $1.position.sortOrder { return $0.position.sortOrder < $1.position.sortOrder }
            if $0.overall != $1.overall { return $0.overall > $1.overall }
            return $0.name < $1.name
        }
    }

    func topScorers(limit: Int = 10) -> [FootballPlayer] {
        Array(players.filter { $0.goals > 0 }.sorted {
            if $0.goals != $1.goals { return $0.goals > $1.goals }
            if $0.assists != $1.assists { return $0.assists > $1.assists }
            return $0.name < $1.name
        }.prefix(limit))
    }

    func form(teamID: Int) -> [FootballResult] {
        standings.first { $0.team.id == teamID }?.form ?? []
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
        return FootballSeason.bestLineup(roster: players.filter { $0.teamID == teamID }, formation: formation(for: teamID))
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

    var predictedOpponentStyle: FootballPlayStyle? {
        guard let selectedClubID, let fixture = nextUserFixture else { return nil }
        let opponentID = fixture.opponent(of: selectedClubID)
        if let liveMatch, liveMatch.fixtureID == fixture.id {
            let isHome = fixture.home == selectedClubID
            let opponentGoals = isHome ? liveMatch.awayGoals : liveMatch.homeGoals
            let ownGoals = isHome ? liveMatch.homeGoals : liveMatch.awayGoals
            return aiSecondHalfStyle(teamID: opponentID, opponentID: selectedClubID, goalsFor: opponentGoals, goalsAgainst: ownGoals)
        }
        return aiStyle(teamID: opponentID, opponentID: selectedClubID)
    }

    var lineupWarnings: [String] {
        var warnings: [String] = []
        let starters = self.starters
        let injured = starters.filter(\.isInjured)
        if !injured.isEmpty {
            warnings.append("\(injured.count) titular(es) lesionado(s) serão substituídos automaticamente.")
        }
        let tired = starters.filter { !$0.isInjured && $0.condition < 65 }
        if !tired.isEmpty {
            warnings.append("\(tired.count) titular(es) com energia abaixo de 65%.")
        }
        let outOfPosition = FootballSeason.outOfPositionCount(lineup: starters, formation: formation)
        if outOfPosition > 0 {
            warnings.append("\(outOfPosition) atleta(s) improvisado(s) fora de posição.")
        }
        return warnings
    }

    // MARK: - Clube e diretoria

    mutating func chooseClub(_ clubID: Int) -> Bool {
        guard selectedClubID == nil, let club = FootballSeason.team(clubID) else { return false }
        selectedClubID = club.id
        transferBudget = club.startingBudget
        boardConfidence = 60
        startingXI = FootballSeason.bestLineup(roster: clubRoster, formation: formation)
        boardTarget = computeBoardTarget()
        return startingXI.count == 11
    }

    @discardableResult
    mutating func acceptJob(_ clubID: Int) -> Bool {
        guard isFired, liveMatch == nil, clubID != selectedClubID,
              jobOffers.contains(where: { $0.id == clubID }),
              let club = FootballSeason.team(clubID) else { return false }
        selectedClubID = club.id
        transferBudget = club.startingBudget / 2
        boardConfidence = 55
        isFired = false
        offers = []
        if !FootballSeason.canFill(roster: clubRoster, formation: formation) { formation = .fourFourTwo }
        startingXI = FootballSeason.bestLineup(roster: clubRoster, formation: formation)
        boardTarget = computeBoardTarget()
        return true
    }

    private func computeBoardTarget() -> Int {
        guard let selectedClubID else { return 4 }
        let ranking = FootballSeason.teams
            .map { team -> (Int, Double) in
                let roster = players.filter { $0.teamID == team.id }
                let teamFormation = team.id == selectedClubID ? formation : aiFormation(teamID: team.id)
                let lineup = FootballSeason.bestLineup(roster: roster, formation: teamFormation).compactMap { player($0) }
                return (team.id, lineup.map { Double($0.overall) }.reduce(0, +) / Double(max(1, lineup.count)))
            }
            .sorted { $0.1 > $1.1 }
        let rank = (ranking.firstIndex { $0.0 == selectedClubID } ?? 3) + 1
        switch rank {
        case 1: return 1
        case 2...3: return 3
        case 4...5: return 4
        default: return 6
        }
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
    }

    mutating func setTrainingIntensity(_ newIntensity: FootballTrainingIntensity) {
        trainingIntensity = newIntensity
    }

    mutating func autoSelectLineup() {
        guard liveMatch == nil else { return }
        startingXI = FootballSeason.bestLineup(roster: clubRoster, formation: formation)
    }

    /// Mantém os titulares escolhidos que ainda servem à formação e completa as vagas com os melhores disponíveis.
    private func rebuiltLineup(keeping current: [Int], formation: FootballFormation) -> [Int] {
        let roster = clubRoster.filter { !$0.isInjured }
        var chosen: [Int] = []
        for position in FootballPosition.allCases {
            let required = formation.requiredPlayers[position, default: 0]
            let kept = roster
                .filter { $0.position == position && current.contains($0.id) }
                .sorted(by: FootballSeason.strongerFirst)
                .prefix(required)
                .map(\.id)
            chosen.append(contentsOf: kept)
            if kept.count < required {
                let fill = roster
                    .filter { $0.position == position && !chosen.contains($0.id) }
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
        return chosen
    }

    /// Remove lesionados e ex-atletas da escalação, repondo pela mesma posição sempre que possível.
    mutating func repairLineup() {
        guard let selectedClubID else { return }
        var lineup: [Int] = []
        for id in startingXI where !lineup.contains(id) {
            if let candidate = player(id), candidate.teamID == selectedClubID, !candidate.isInjured {
                lineup.append(id)
            }
        }
        if lineup.count > 11 { lineup = Array(lineup.prefix(11)) }
        if lineup.count < 11 || lineup.count != startingXI.count {
            lineup = rebuiltLineup(keeping: lineup, formation: formation)
        }
        startingXI = lineup
    }

    func canSubstitute(outgoingID: Int, incomingID: Int) -> Bool {
        guard let selectedClubID,
              startingXI.contains(outgoingID), !startingXI.contains(incomingID),
              let incoming = player(incomingID), incoming.teamID == selectedClubID, !incoming.isInjured else { return false }
        if let liveMatch { return liveMatch.substitutionsUsed < LiveMatchState.maxSubstitutions }
        return true
    }

    @discardableResult
    mutating func substitute(outgoingID: Int, incomingID: Int) -> Bool {
        guard canSubstitute(outgoingID: outgoingID, incomingID: incomingID),
              let index = startingXI.firstIndex(of: outgoingID) else { return false }
        startingXI[index] = incomingID
        if var live = liveMatch {
            live.substitutionsUsed += 1
            let outName = player(outgoingID)?.name ?? "Atleta"
            let inName = player(incomingID)?.name ?? "Atleta"
            live.events.append(MatchEvent(minute: 45, kind: .substitution, teamID: selectedClubID,
                                          text: "Substituição: sai \(outName), entra \(inName)."))
            liveMatch = live
        }
        return true
    }

    // MARK: - Mercado

    func quickSalePrice(playerID: Int) -> Int {
        guard let player = player(playerID) else { return 0 }
        return Int(Double(player.marketValue) * Self.quickSaleRate / 10_000) * 10_000
    }

    func canSell(playerID: Int) -> Bool {
        guard let selectedClubID, liveMatch == nil, !isFired,
              let player = player(playerID), player.teamID == selectedClubID,
              clubRoster.count > Self.minimumRoster else { return false }
        let remaining = clubRoster.filter { $0.id != playerID }
        let healthyCount = remaining.filter { !$0.isInjured }.count
        return healthyCount >= 11 && FootballSeason.canFill(roster: remaining.map { member in
            var healthy = member
            healthy.injuryRounds = 0
            return healthy
        }, formation: formation)
    }

    @discardableResult
    mutating func sellPlayer(playerID: Int) -> Bool {
        guard canSell(playerID: playerID), let index = players.firstIndex(where: { $0.id == playerID }) else { return false }
        transferBudget += quickSalePrice(playerID: playerID)
        players[index].teamID = nil
        offers.removeAll { $0.playerID == playerID }
        repairLineup()
        return true
    }

    func canSign(playerID: Int) -> Bool {
        guard selectedClubID != nil, liveMatch == nil, !isFired,
              let player = player(playerID), player.teamID == nil else { return false }
        return clubRoster.count < Self.rosterLimit && transferBudget >= player.marketValue
    }

    @discardableResult
    mutating func signPlayer(playerID: Int) -> Bool {
        guard canSign(playerID: playerID), let selectedClubID,
              let index = players.firstIndex(where: { $0.id == playerID }) else { return false }
        transferBudget -= players[index].marketValue
        players[index].teamID = selectedClubID
        players[index].goals = 0
        players[index].assists = 0
        players[index].appearances = 0
        return true
    }

    func canAccept(offerID: Int) -> Bool {
        guard let offer = offers.first(where: { $0.id == offerID }) else { return false }
        return canSell(playerID: offer.playerID)
    }

    @discardableResult
    mutating func acceptOffer(_ offerID: Int) -> Bool {
        guard canAccept(offerID: offerID),
              let offer = offers.first(where: { $0.id == offerID }),
              let index = players.firstIndex(where: { $0.id == offer.playerID }) else { return false }
        let position = players[index].position
        transferBudget += offer.amount
        players[index].teamID = offer.clubID
        offers.removeAll { $0.playerID == offer.playerID }
        // O comprador libera o atleta mais fraco da mesma posição para manter o elenco equilibrado.
        if let released = players.indices
            .filter({ players[$0].teamID == offer.clubID && players[$0].position == position && players[$0].id != offer.playerID })
            .min(by: { players[$0].overall < players[$1].overall }) {
            players[released].teamID = nil
        }
        repairLineup()
        return true
    }

    mutating func rejectOffer(_ offerID: Int) {
        offers.removeAll { $0.id == offerID }
    }

    // MARK: - Treino

    @discardableResult
    mutating func applyWeeklyTraining(for round: Int) -> FootballTrainingReport {
        guard let selectedClubID else {
            let emptyReport = FootballTrainingReport(round: round, focus: trainingFocus, intensity: trainingIntensity,
                                                     developedPlayers: 0, averageConditionGain: 0)
            lastTrainingReport = emptyReport
            return emptyReport
        }

        var random = FootballRandom(seed: matchSeed(fixtureID: 10_000 + round) ^ 0xD1B54A32D192ED03)
        let rosterIndices = players.indices.filter { players[$0].teamID == selectedClubID }
        var developedPlayers = 0
        var totalConditionGain = 0

        for index in rosterIndices {
            let player = players[index]
            let conditionBefore = player.condition
            players[index].condition = min(100, conditionBefore + trainingIntensity.conditionRecovery(for: trainingFocus))
            totalConditionGain += players[index].condition - conditionBefore

            guard !player.isInjured,
                  trainingFocus.developmentPositions.contains(player.position),
                  player.overall < player.potential else { continue }
            let developmentChance = min(75, Int(Double(trainingIntensity.developmentChance) * ageMultiplier(player.age)))
            guard random.int(in: 0...99) < developmentChance else { continue }
            players[index].overall += 1
            refreshValue(at: index)
            developedPlayers += 1
        }

        let averageConditionGain = rosterIndices.isEmpty ? 0 : totalConditionGain / rosterIndices.count
        let report = FootballTrainingReport(round: round, focus: trainingFocus, intensity: trainingIntensity,
                                            developedPlayers: developedPlayers, averageConditionGain: averageConditionGain)
        lastTrainingReport = report
        return report
    }

    private func ageMultiplier(_ age: Int) -> Double {
        if age <= 21 { return 1.35 }
        if age <= 25 { return 1.15 }
        if age >= 30 { return 0.6 }
        return 1.0
    }

    // MARK: - Rodada

    /// Joga a rodada inteira de uma vez (simulação rápida).
    @discardableResult
    mutating func simulateNextRound() -> Bool {
        guard beginMatchDay() else { return false }
        return finishMatchDay()
    }

    /// Aplica o treino e joga o primeiro tempo da partida do usuário. A carreira fica no intervalo.
    @discardableResult
    mutating func beginMatchDay() -> Bool {
        guard liveMatch == nil, canPlay, let selectedClubID, let fixture = nextUserFixture else { return false }
        let round = currentRound + 1
        guard fixtures.filter({ $0.round == round && !$0.isPlayed }).count == FootballSeason.matchesPerRound else { return false }

        applyWeeklyTraining(for: round)
        for index in players.indices where players[index].teamID != selectedClubID {
            players[index].condition = min(100, players[index].condition + 8)
        }
        repairLineup()

        let home = side(teamID: fixture.home, opponentID: fixture.away, isHome: true, style: nil)
        let away = side(teamID: fixture.away, opponentID: fixture.home, isHome: false, style: nil)
        var random = FootballRandom(seed: matchSeed(fixtureID: fixture.id))
        let half = FootballMatchEngine.simulateHalf(home: home, away: away, half: 1, narrate: true, using: &random)

        var events = [MatchEvent(minute: 0, kind: .kickoff, teamID: nil,
                                 text: "Bola rolando: \(FootballSeason.teamName(fixture.home)) × \(FootballSeason.teamName(fixture.away)).")]
        events.append(contentsOf: half.events)
        events.append(MatchEvent(minute: 45, kind: .halfTime, teamID: nil,
                                 text: "Intervalo: \(FootballSeason.teamName(fixture.home)) \(half.homeGoals.count) × \(half.awayGoals.count) \(FootballSeason.teamName(fixture.away))."))

        liveMatch = LiveMatchState(
            fixtureID: fixture.id,
            round: round,
            homeGoals: half.homeGoals.count,
            awayGoals: half.awayGoals.count,
            homeScorerIDs: half.homeGoals.map(\.scorerID),
            awayScorerIDs: half.awayGoals.map(\.scorerID),
            homeAssistIDs: half.homeGoals.compactMap(\.assistID),
            awayAssistIDs: half.awayGoals.compactMap(\.assistID),
            homeShots: half.homeShots,
            awayShots: half.awayShots,
            homeOnTarget: half.homeOnTarget,
            awayOnTarget: half.awayOnTarget,
            homeExpectedGoals: half.homeExpectedGoals,
            awayExpectedGoals: half.awayExpectedGoals,
            homePossession: half.homePossession,
            events: events,
            firstHalfHomeLineup: home.lineup.map(\.id),
            firstHalfAwayLineup: away.lineup.map(\.id),
            substitutionsUsed: 0,
            styleAtKickoff: playStyle
        )
        return true
    }

    /// Joga o segundo tempo do usuário (com as mudanças feitas no intervalo) e as demais partidas da rodada.
    @discardableResult
    mutating func finishMatchDay() -> Bool {
        guard let live = liveMatch, let selectedClubID,
              let userIndex = fixtures.firstIndex(where: { $0.id == live.fixtureID }) else { return false }
        repairLineup()
        let fixture = fixtures[userIndex]
        let round = live.round

        // Segundo tempo da partida do usuário.
        let userIsHome = fixture.home == selectedClubID
        let opponentID = fixture.opponent(of: selectedClubID)
        let opponentGoals = userIsHome ? live.awayGoals : live.homeGoals
        let ownGoals = userIsHome ? live.homeGoals : live.awayGoals
        let opponentStyle = aiSecondHalfStyle(teamID: opponentID, opponentID: selectedClubID,
                                              goalsFor: opponentGoals, goalsAgainst: ownGoals)
        let homeStyle = userIsHome ? playStyle : opponentStyle
        let awayStyle = userIsHome ? opponentStyle : playStyle
        let home = side(teamID: fixture.home, opponentID: fixture.away, isHome: true, style: homeStyle, opponentStyle: awayStyle)
        let away = side(teamID: fixture.away, opponentID: fixture.home, isHome: false, style: awayStyle, opponentStyle: homeStyle)
        var random = FootballRandom(seed: matchSeed(fixtureID: fixture.id) ^ 0x5DEECE66D)
        let second = FootballMatchEngine.simulateHalf(home: home, away: away, half: 2, narrate: true, using: &random)

        var events = live.events
        if playStyle != live.styleAtKickoff {
            events.append(MatchEvent(minute: 46, kind: .tactic, teamID: selectedClubID,
                                     text: "Mudança tática do \(FootballSeason.teamName(selectedClubID)): \(playStyle.rawValue)."))
        }
        let previousOpponentStyle = aiStyle(teamID: opponentID, opponentID: selectedClubID)
        if opponentStyle != previousOpponentStyle {
            events.append(MatchEvent(minute: 46, kind: .tactic, teamID: opponentID,
                                     text: "O \(FootballSeason.teamName(opponentID)) volta do intervalo em postura \(opponentStyle.rawValue.lowercased())."))
        }
        events.append(contentsOf: second.events)

        var userFixture = fixture
        let homeGoals = live.homeGoals + second.homeGoals.count
        let awayGoals = live.awayGoals + second.awayGoals.count
        userFixture.homeGoals = homeGoals
        userFixture.awayGoals = awayGoals
        userFixture.homeScorerIDs = live.homeScorerIDs + second.homeGoals.map(\.scorerID)
        userFixture.awayScorerIDs = live.awayScorerIDs + second.awayGoals.map(\.scorerID)
        userFixture.homeShots = live.homeShots + second.homeShots
        userFixture.awayShots = live.awayShots + second.awayShots
        userFixture.homeOnTarget = live.homeOnTarget + second.homeOnTarget
        userFixture.awayOnTarget = live.awayOnTarget + second.awayOnTarget
        userFixture.homeExpectedGoals = FootballMatchEngine.rounded(live.homeExpectedGoals + second.homeExpectedGoals)
        userFixture.awayExpectedGoals = FootballMatchEngine.rounded(live.awayExpectedGoals + second.awayExpectedGoals)
        let possession = (live.homePossession + second.homePossession) / 2
        userFixture.homePossession = possession
        userFixture.awayPossession = 100 - possession
        events.append(MatchEvent(minute: 90, kind: .fullTime, teamID: nil,
                                 text: "Apito final: \(FootballSeason.teamName(fixture.home)) \(homeGoals) × \(awayGoals) \(FootballSeason.teamName(fixture.away))."))

        // Estatísticas individuais da partida do usuário.
        let homeFinal = home.lineup.map(\.id)
        let awayFinal = away.lineup.map(\.id)
        var participation: [(lineupStart: [Int], lineupEnd: [Int], style: FootballPlayStyle)] = [
            (live.firstHalfHomeLineup, homeFinal, homeStyle),
            (live.firstHalfAwayLineup, awayFinal, awayStyle)
        ]
        let scorers = userFixture.homeScorerIDs + userFixture.awayScorerIDs
        let assists = live.homeAssistIDs + live.awayAssistIDs + second.homeGoals.compactMap(\.assistID) + second.awayGoals.compactMap(\.assistID)
        userFixture.events = events
        fixtures[userIndex] = userFixture
        liveMatch = nil

        // Demais partidas da rodada.
        for index in fixtures.indices where fixtures[index].round == round && !fixtures[index].isPlayed {
            let other = fixtures[index]
            let otherHomeStyle = aiStyle(teamID: other.home, opponentID: other.away)
            let otherAwayStyle = aiStyle(teamID: other.away, opponentID: other.home)
            let otherHome = side(teamID: other.home, opponentID: other.away, isHome: true, style: otherHomeStyle, opponentStyle: otherAwayStyle)
            let otherAway = side(teamID: other.away, opponentID: other.home, isHome: false, style: otherAwayStyle, opponentStyle: otherHomeStyle)
            var otherRandom = FootballRandom(seed: matchSeed(fixtureID: other.id))
            let first = FootballMatchEngine.simulateHalf(home: otherHome, away: otherAway, half: 1, narrate: false, using: &otherRandom)
            let last = FootballMatchEngine.simulateHalf(home: otherHome, away: otherAway, half: 2, narrate: false, using: &otherRandom)
            var played = other
            played.homeGoals = first.homeGoals.count + last.homeGoals.count
            played.awayGoals = first.awayGoals.count + last.awayGoals.count
            played.homeScorerIDs = (first.homeGoals + last.homeGoals).map(\.scorerID)
            played.awayScorerIDs = (first.awayGoals + last.awayGoals).map(\.scorerID)
            played.homeShots = first.homeShots + last.homeShots
            played.awayShots = first.awayShots + last.awayShots
            played.homeOnTarget = first.homeOnTarget + last.homeOnTarget
            played.awayOnTarget = first.awayOnTarget + last.awayOnTarget
            played.homeExpectedGoals = FootballMatchEngine.rounded(first.homeExpectedGoals + last.homeExpectedGoals)
            played.awayExpectedGoals = FootballMatchEngine.rounded(first.awayExpectedGoals + last.awayExpectedGoals)
            let otherPossession = (first.homePossession + last.homePossession) / 2
            played.homePossession = otherPossession
            played.awayPossession = 100 - otherPossession
            fixtures[index] = played

            let lineupHome = otherHome.lineup.map(\.id)
            let lineupAway = otherAway.lineup.map(\.id)
            participation.append((lineupHome, lineupHome, otherHomeStyle))
            participation.append((lineupAway, lineupAway, otherAwayStyle))
            recordGoals(played.homeScorerIDs + played.awayScorerIDs)
            recordAssists((first.homeGoals + last.homeGoals + first.awayGoals + last.awayGoals).compactMap(\.assistID))
        }
        recordGoals(scorers)
        recordAssists(assists)

        // Lesões anteriores avançam uma rodada antes de novas lesões serem sorteadas.
        for index in players.indices where players[index].injuryRounds > 0 {
            players[index].injuryRounds -= 1
        }

        var postRandom = FootballRandom(seed: matchSeed(fixtureID: 20_000 + round))
        var userInjuries: [String] = []
        var playedIDs = Set<Int>()
        for entry in participation {
            let starters = Set(entry.lineupStart)
            let finishers = Set(entry.lineupEnd)
            for id in starters.union(finishers) {
                guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
                playedIDs.insert(id)
                players[index].appearances += 1
                let fullMatch = starters.contains(id) && finishers.contains(id)
                let cost = fullMatch ? entry.style.fatigueCost : (entry.style.fatigueCost + 1) / 2
                players[index].condition = max(40, players[index].condition - cost)

                var injuryChance = 0.012
                if players[index].condition < 55 { injuryChance += 0.03 } else if players[index].condition < 70 { injuryChance += 0.012 }
                if entry.style == .highPress { injuryChance += 0.006 }
                if postRandom.chance(injuryChance) {
                    let rounds = postRandom.int(in: 1...4)
                    players[index].injuryRounds = rounds
                    if players[index].teamID == selectedClubID {
                        userInjuries.append("\(players[index].name) sofreu uma lesão e ficará fora por \(rounds) rodada(s).")
                    }
                }
            }
        }
        for index in players.indices where players[index].teamID != nil && !playedIDs.contains(players[index].id) {
            players[index].condition = min(100, players[index].condition + 6)
        }
        if !userInjuries.isEmpty {
            fixtures[userIndex].events.append(contentsOf: userInjuries.map {
                MatchEvent(minute: 90, kind: .injury, teamID: selectedClubID, text: "Departamento médico: \($0)")
            })
        }

        developAIPlayers(using: &postRandom)
        currentRound = round
        settleUserRound(fixture: fixtures[userIndex])
        generateOffers(using: &postRandom)
        for index in players.indices { refreshValue(at: index) }
        repairLineup()
        return true
    }

    private func side(teamID: Int, opponentID: Int, isHome: Bool, style: FootballPlayStyle?,
                      opponentStyle: FootballPlayStyle? = nil) -> MatchSide {
        let ownStyle = style ?? self.style(for: teamID, against: opponentID)
        let rivalStyle = opponentStyle ?? self.style(for: opponentID, against: teamID)
        return MatchSide(
            teamID: teamID,
            lineup: lineup(for: teamID).compactMap { player($0) },
            formation: formation(for: teamID),
            style: ownStyle,
            opponentStyle: rivalStyle,
            isHome: isHome
        )
    }

    private mutating func recordGoals(_ scorerIDs: [Int]) {
        for id in scorerIDs {
            guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
            players[index].goals += 1
            players[index].careerGoals += 1
        }
    }

    private mutating func recordAssists(_ assistIDs: [Int]) {
        for id in assistIDs {
            guard let index = players.firstIndex(where: { $0.id == id }) else { continue }
            players[index].assists += 1
        }
    }

    private mutating func developAIPlayers(using random: inout FootballRandom) {
        for index in players.indices {
            guard let teamID = players[index].teamID, teamID != selectedClubID,
                  players[index].overall < players[index].potential else { continue }
            let chance = 0.03 * ageMultiplier(players[index].age)
            if random.chance(chance) { players[index].overall += 1 }
        }
    }

    /// Bilheteria, confiança da diretoria e expiração de propostas após a partida do usuário.
    private mutating func settleUserRound(fixture: LeagueFixture) {
        guard let selectedClubID, let club = selectedClub, let result = fixture.result(for: selectedClubID) else { return }
        let isHome = fixture.home == selectedClubID
        if isHome {
            let formBonus = form(teamID: selectedClubID).filter { $0 == .win }.count * 8_000
            lastRoundRevenue = Int(Double(club.startingBudget) * 0.018) + formBonus
            transferBudget += lastRoundRevenue
        } else {
            lastRoundRevenue = 0
        }

        let expectation = teamRating(selectedClubID) - teamRating(fixture.opponent(of: selectedClubID)) + (isHome ? 1.5 : -1.5)
        let delta: Int
        switch result {
        case .win: delta = expectation < -2 ? 6 : 4
        case .draw: delta = expectation > 3 ? -2 : 1
        case .loss: delta = expectation > 0 ? -6 : -3
        }
        boardConfidence = min(100, max(0, boardConfidence + delta))
        offers.removeAll { $0.expiresAfterRound < currentRound }
    }

    private mutating func generateOffers(using random: inout FootballRandom) {
        guard let selectedClubID, offers.count < 2, !isSeasonComplete, random.chance(0.3) else { return }
        let candidates = clubRoster
            .filter { candidate in !offers.contains { $0.playerID == candidate.id } }
            .sorted { $0.marketValue > $1.marketValue }
            .prefix(8)
        guard let target = random.pick(Array(candidates)) else { return }
        let buyers = FootballSeason.teams.filter { $0.id != selectedClubID }
        guard let buyer = random.pick(buyers) else { return }
        let amount = Int(Double(target.marketValue) * Double(random.int(in: 95...125)) / 100 / 10_000) * 10_000
        offers.append(TransferOffer(id: nextOfferID, playerID: target.id, clubID: buyer.id,
                                    amount: max(amount, 100_000), expiresAfterRound: currentRound + 2))
        nextOfferID += 1
    }

    private mutating func refreshValue(at index: Int) {
        let player = players[index]
        players[index].marketValue = FootballSeason.marketValue(overall: player.overall, age: player.age, potential: player.potential)
    }

    // MARK: - Temporada

    /// Encerra a temporada (premiação, diretoria, envelhecimento, aposentadorias e base) e inicia a próxima.
    @discardableResult
    mutating func startNextSeason() -> SeasonRecord? {
        guard isSeasonComplete, liveMatch == nil, let selectedClubID else { return nil }
        let table = standings
        guard let champion = table.first?.team.id else { return nil }
        champions.append(champion)

        let position = (table.firstIndex { $0.team.id == selectedClubID } ?? table.count - 1) + 1
        let points = table.first { $0.team.id == selectedClubID }?.points ?? 0
        let objectiveMet = position <= boardTarget
        let prize = FootballSeason.prizeMoney[min(position, FootballSeason.prizeMoney.count) - 1]
            + (objectiveMet ? FootballSeason.objectiveBonus : 0)
        transferBudget += prize
        boardConfidence = min(100, max(0, boardConfidence + (objectiveMet ? 15 : -20) + (champion == selectedClubID ? 10 : 0)))
        let fired = !objectiveMet && boardConfidence <= 20
        let topScorer = topScorers(limit: 1).first

        var random = FootballRandom(seed: matchSeed(fixtureID: 50_000) ^ 0x2545F4914F6CDD1D)
        let changes = runOffseason(using: &random)

        let record = SeasonRecord(
            season: season,
            clubID: selectedClubID,
            championID: champion,
            position: position,
            points: points,
            target: boardTarget,
            objectiveMet: objectiveMet,
            prizeMoney: prize,
            topScorerName: topScorer?.name ?? "—",
            topScorerTeamID: topScorer?.teamID,
            topScorerGoals: topScorer?.goals ?? 0,
            retiredPlayers: changes.retired,
            youthPromoted: changes.youth,
            wasFired: fired
        )
        history.append(record)

        season += 1
        currentRound = 0
        fixtures = FootballSeason.fixtures()
        lastTrainingReport = nil
        lastRoundRevenue = 0
        offers = []
        for index in players.indices {
            players[index].goals = 0
            players[index].assists = 0
            players[index].appearances = 0
            players[index].injuryRounds = 0
            players[index].condition = min(100, players[index].condition + 30)
            refreshValue(at: index)
        }
        if !FootballSeason.canFill(roster: clubRoster, formation: formation) { formation = .fourFourTwo }
        startingXI = FootballSeason.bestLineup(roster: clubRoster, formation: formation)
        boardTarget = computeBoardTarget()
        if fired {
            isFired = true
            boardConfidence = 0
        }
        return record
    }

    private mutating func runOffseason(using random: inout FootballRandom) -> (retired: Int, youth: Int) {
        var retired = 0
        var youth = 0
        var survivors: [FootballPlayer] = []
        var replacements: [FootballPlayer] = []

        for var player in players {
            player.age += 1
            if player.age <= 23, player.overall < player.potential {
                player.overall = min(player.potential, player.overall + random.int(in: 0...2))
            } else if player.age <= 28, player.overall < player.potential, random.chance(0.4) {
                player.overall += 1
            } else if player.age >= 33 {
                player.overall = max(48, player.overall - random.int(in: 1...3))
            } else if player.age >= 31 {
                player.overall = max(48, player.overall - random.int(in: 0...2))
            }
            player.potential = max(player.overall, player.age >= 30 ? player.overall : player.potential)

            let retires = player.age >= 36 || (player.age >= 33 && random.chance(0.3))
            if retires {
                if player.teamID == selectedClubID { retired += 1 }
                if let teamID = player.teamID {
                    let strength = FootballSeason.team(teamID)?.strength ?? 70
                    replacements.append(FootballSeason.makeYouth(id: nextPlayerID, position: player.position,
                                                                 teamStrength: strength, teamID: teamID, using: &random))
                    nextPlayerID += 1
                    if teamID == selectedClubID { youth += 1 }
                }
                continue
            }
            survivors.append(player)
        }
        players = survivors + replacements

        // Renova o mercado de agentes livres.
        let marketCount = players.filter { $0.teamID == nil }.count
        if marketCount < 14 {
            for offset in 0..<(14 - marketCount) {
                let position = FootballSeason.freeAgentTemplate[offset % FootballSeason.freeAgentTemplate.count]
                players.append(FootballSeason.makeFreeAgent(id: nextPlayerID, position: position, using: &random))
                nextPlayerID += 1
            }
        }
        return (retired, youth)
    }

    private func matchSeed(fixtureID: Int) -> UInt64 {
        UInt64(bitPattern: Int64(seed))
            &+ UInt64(season) &* 0x9E3779B97F4A7C15
            &+ UInt64(fixtureID + 1) &* 0xBF58476D1CE4E5B9
    }
}
