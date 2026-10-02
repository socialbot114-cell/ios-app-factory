import Foundation

enum FootballSeason {
    static let teamsPerDivision = 10
    static let leagueRounds = 18
    static let relegationSpots = 2

    static let teams: [LeagueTeam] = [
        // Série A
        .init(id: 0, name: "Aurora FC", shortName: "AUR", city: "Brasília", stadium: "Arena Alvorada", capacity: 52_000,
              strength: 76, startingBudget: 8_000_000, preferredStyle: .possession, preferredFormation: .fourThreeThree, initialDivision: .serieA),
        .init(id: 1, name: "Atlético Cerrado", shortName: "ACE", city: "Goiânia", stadium: "Estádio do Ipê", capacity: 38_000,
              strength: 73, startingBudget: 6_200_000, preferredStyle: .highPress, preferredFormation: .fourFourTwo, initialDivision: .serieA),
        .init(id: 2, name: "Maré Alta", shortName: "MAR", city: "Salvador", stadium: "Arena Maré", capacity: 45_000,
              strength: 76, startingBudget: 6_800_000, preferredStyle: .attacking, preferredFormation: .fourThreeThree, initialDivision: .serieA),
        .init(id: 3, name: "União da Serra", shortName: "UNI", city: "Belo Horizonte", stadium: "Estádio das Gerais", capacity: 48_000,
              strength: 77, startingBudget: 7_500_000, preferredStyle: .balanced, preferredFormation: .fourTwoThreeOne, initialDivision: .serieA),
        .init(id: 4, name: "Estrela do Sul", shortName: "EST", city: "Porto Alegre", stadium: "Estádio Cruzeiro do Sul", capacity: 44_000,
              strength: 76, startingBudget: 6_500_000, preferredStyle: .defensive, preferredFormation: .fourFourTwo, initialDivision: .serieA),
        .init(id: 5, name: "Portuários", shortName: "POR", city: "Santos", stadium: "Estádio do Cais", capacity: 27_000,
              strength: 71, startingBudget: 5_800_000, preferredStyle: .counter, preferredFormation: .fourFourTwo, initialDivision: .serieA),
        .init(id: 6, name: "Capital Norte", shortName: "CAP", city: "Manaus", stadium: "Arena da Floresta", capacity: 40_000,
              strength: 69, startingBudget: 5_000_000, preferredStyle: .counter, preferredFormation: .fourTwoThreeOne, initialDivision: .serieA),
        .init(id: 7, name: "Vale Verde", shortName: "VAL", city: "Curitiba", stadium: "Estádio dos Pinheirais", capacity: 33_000,
              strength: 72, startingBudget: 5_600_000, preferredStyle: .possession, preferredFormation: .fourTwoThreeOne, initialDivision: .serieA),
        .init(id: 8, name: "Litoral FC", shortName: "LIT", city: "Florianópolis", stadium: "Estádio da Ilha", capacity: 26_000,
              strength: 70, startingBudget: 5_200_000, preferredStyle: .attacking, preferredFormation: .fourThreeThree, initialDivision: .serieA),
        .init(id: 9, name: "Sertanejos EC", shortName: "SER", city: "Petrolina", stadium: "Arena do Velho Chico", capacity: 22_000,
              strength: 68, startingBudget: 4_600_000, preferredStyle: .defensive, preferredFormation: .fourFourTwo, initialDivision: .serieA),
        // Série B
        .init(id: 10, name: "Pantanal AC", shortName: "PAN", city: "Cuiabá", stadium: "Arena Pantaneira", capacity: 30_000,
              strength: 66, startingBudget: 3_400_000, preferredStyle: .counter, preferredFormation: .fourFourTwo, initialDivision: .serieB),
        .init(id: 11, name: "Ipê Amarelo FC", shortName: "IPÊ", city: "Campinas", stadium: "Estádio do Ipê Amarelo", capacity: 24_000,
              strength: 65, startingBudget: 3_200_000, preferredStyle: .possession, preferredFormation: .fourTwoThreeOne, initialDivision: .serieB),
        .init(id: 12, name: "Serra Azul EC", shortName: "SAZ", city: "Vitória", stadium: "Estádio Mestre Álvaro", capacity: 18_000,
              strength: 64, startingBudget: 3_000_000, preferredStyle: .balanced, preferredFormation: .fourFourTwo, initialDivision: .serieB),
        .init(id: 13, name: "Tropeiros FC", shortName: "TRO", city: "Lages", stadium: "Estádio do Planalto", capacity: 15_000,
              strength: 63, startingBudget: 2_800_000, preferredStyle: .highPress, preferredFormation: .fourFourTwo, initialDivision: .serieB),
        .init(id: 14, name: "Cacique EC", shortName: "CAC", city: "Natal", stadium: "Arena Potiguar", capacity: 21_000,
              strength: 62, startingBudget: 2_700_000, preferredStyle: .attacking, preferredFormation: .fourThreeThree, initialDivision: .serieB),
        .init(id: 15, name: "Jangadeiros AC", shortName: "JAN", city: "Fortaleza", stadium: "Estádio das Jangadas", capacity: 25_000,
              strength: 62, startingBudget: 2_600_000, preferredStyle: .counter, preferredFormation: .fourTwoThreeOne, initialDivision: .serieB),
        .init(id: 16, name: "Carcará FC", shortName: "CAR", city: "Teresina", stadium: "Estádio do Carcará", capacity: 16_000,
              strength: 61, startingBudget: 2_400_000, preferredStyle: .defensive, preferredFormation: .fourFourTwo, initialDivision: .serieB),
        .init(id: 17, name: "Garimpo EC", shortName: "GAR", city: "Porto Velho", stadium: "Estádio da Pepita", capacity: 12_000,
              strength: 60, startingBudget: 2_200_000, preferredStyle: .balanced, preferredFormation: .fourFourTwo, initialDivision: .serieB),
        .init(id: 18, name: "Araucária FC", shortName: "ARA", city: "Ponta Grossa", stadium: "Estádio dos Campos Gerais", capacity: 14_000,
              strength: 59, startingBudget: 2_100_000, preferredStyle: .possession, preferredFormation: .fourThreeThree, initialDivision: .serieB),
        .init(id: 19, name: "Rio Doce FC", shortName: "RDO", city: "Ipatinga", stadium: "Arena do Vale do Aço", capacity: 13_000,
              strength: 58, startingBudget: 2_000_000, preferredStyle: .highPress, preferredFormation: .fourFourTwo, initialDivision: .serieB)
    ]

    /// Clássicos regionais: jogos com mais peso para torcida e diretoria.
    static let rivalries: [Set<Int>] = [[0, 6], [3, 1], [2, 15], [4, 7], [5, 11], [8, 13], [9, 16], [10, 17]]

    static func isDerby(_ first: Int, _ second: Int) -> Bool {
        rivalries.contains([first, second])
    }

    /// Premiação por posição final em cada divisão (1º ao 10º).
    static func prizeMoney(division: Division, position: Int) -> Int {
        let table: [Int] = division == .serieA
            ? [3_000_000, 2_400_000, 2_000_000, 1_700_000, 1_500_000, 1_300_000, 1_100_000, 1_000_000, 800_000, 700_000]
            : [1_200_000, 1_000_000, 800_000, 700_000, 600_000, 550_000, 500_000, 450_000, 400_000, 350_000]
        return table[min(max(position, 1), table.count) - 1]
    }

    static let objectiveBonus = 500_000

    private static let firstNames = [
        "Rafael", "Mateus", "Lucas", "André", "João", "Caio", "Bruno", "Davi",
        "Gabriel", "Pedro", "Igor", "Vinícius", "Daniel", "Marcos", "Felipe", "Renan",
        "Thiago", "Samuel", "Gustavo", "Enzo", "Luan", "Ruan", "Diego", "Alex",
        "Heitor", "Otávio", "Murilo", "Kauã", "Wesley", "Emerson", "Leandro", "Fábio",
        "Ítalo", "Breno", "Yuri", "Jonas", "Ramon", "Nícolas", "Arthur", "Cauê",
        "Edson", "Hugo", "Wallace", "Douglas", "Everton", "Jefferson", "Rodrigo", "Saulo"
    ]

    private static let lastNames = [
        "Nascimento", "Duarte", "Campos", "Ribeiro", "Nunes", "Oliveira", "Moura", "Barbosa",
        "Freitas", "Lima", "Teixeira", "Carvalho", "Mendes", "Azevedo", "Pereira", "Costa",
        "Cardoso", "Rocha", "Alves", "Farias", "Cavalcante", "Batista", "Gomes", "Monteiro",
        "Siqueira", "Pacheco", "Brandão", "Vasconcelos", "Peixoto", "Magalhães", "Sampaio", "Queiroz",
        "Tavares", "Bezerra", "Coutinho", "Assunção", "Prado", "Viana", "Leite", "Aragão",
        "Fontes", "Matos", "Rezende", "Xavier", "Barros", "Damasceno", "Guedes", "Lacerda"
    ]

    static func team(_ id: Int) -> LeagueTeam? {
        teams.indices.contains(id) && teams[id].id == id ? teams[id] : teams.first { $0.id == id }
    }

    static func teamName(_ id: Int) -> String {
        team(id)?.name ?? "Clube"
    }

    // MARK: - Calendário

    /// Fases da copa disputadas no meio de semana, logo após estas rodadas da liga.
    static let cupAfterLeagueRound: [Int: CupRound] = [
        3: .preliminary, 6: .roundOf16, 9: .quarterFinal, 12: .semiFinal, 15: .final
    ]

    static let calendar: [MatchDaySlot] = {
        var slots: [MatchDaySlot] = []
        var week = 4
        for round in 1...leagueRounds {
            slots.append(MatchDaySlot(index: slots.count, week: week, isMidweek: false, leagueRound: round, cupRound: nil))
            if let cupRound = cupAfterLeagueRound[round] {
                slots.append(MatchDaySlot(index: slots.count, week: week + 1, isMidweek: true, leagueRound: nil, cupRound: cupRound))
            }
            week += 1
        }
        return slots
    }()

    static var matchDaysPerSeason: Int { calendar.count }

    static func matchDayIndex(leagueRound: Int) -> Int {
        calendar.first { $0.leagueRound == leagueRound }?.index ?? 0
    }

    static func matchDayIndex(cupRound: CupRound) -> Int {
        calendar.first { $0.cupRound == cupRound }?.index ?? 0
    }

    /// Turno e returno pelo método do círculo, alternando mandos.
    static func leagueFixtures(teamIDs: [Int], division: Division, firstID: Int) -> [LeagueFixture] {
        let count = teamIDs.count
        guard count >= 2, count.isMultiple(of: 2) else { return [] }
        let roundsPerLeg = count - 1
        var firstLeg: [[(Int, Int)]] = []
        var rotating = teamIDs
        for round in 0..<roundsPerLeg {
            var pairs: [(Int, Int)] = []
            for index in 0..<(count / 2) {
                let first = rotating[index]
                let second = rotating[count - 1 - index]
                let flip = index == 0 ? round.isMultiple(of: 2) : (round + index).isMultiple(of: 2)
                pairs.append(flip ? (first, second) : (second, first))
            }
            firstLeg.append(pairs)
            let fixed = rotating[0]
            var rest = Array(rotating.dropFirst())
            let last = rest.removeLast()
            rest.insert(last, at: 0)
            rotating = [fixed] + rest
        }

        var output: [LeagueFixture] = []
        for round in 0..<(roundsPerLeg * 2) {
            let leagueRound = round + 1
            for pair in firstLeg[round % roundsPerLeg] {
                let home = round < roundsPerLeg ? pair.0 : pair.1
                let away = round < roundsPerLeg ? pair.1 : pair.0
                output.append(LeagueFixture(id: firstID + output.count, matchDay: matchDayIndex(leagueRound: leagueRound),
                                            round: leagueRound, competition: .league(division), home: home, away: away))
            }
        }
        return output
    }

    /// Tabela de uma divisão, considerando apenas jogos de liga entre os clubes informados.
    static func standings(teamIDs: [Int], fixtures: [LeagueFixture]) -> [FootballStanding] {
        var table = Dictionary(uniqueKeysWithValues: teamIDs.compactMap { id in team(id).map { (id, FootballStanding(team: $0)) } })
        for match in fixtures.sorted(by: { $0.matchDay < $1.matchDay }) where match.competition.division != nil {
            guard let homeGoals = match.homeGoals, let awayGoals = match.awayGoals else { continue }
            guard var home = table[match.home], var away = table[match.away] else { continue }
            home.played += 1
            away.played += 1
            home.goalsFor += homeGoals
            home.goalsAgainst += awayGoals
            away.goalsFor += awayGoals
            away.goalsAgainst += homeGoals
            if homeGoals > awayGoals {
                home.wins += 1
                away.losses += 1
                home.points += 3
                home.form.append(.win)
                away.form.append(.loss)
            } else if homeGoals < awayGoals {
                away.wins += 1
                home.losses += 1
                away.points += 3
                home.form.append(.loss)
                away.form.append(.win)
            } else {
                home.draws += 1
                away.draws += 1
                home.points += 1
                away.points += 1
                home.form.append(.draw)
                away.form.append(.draw)
            }
            table[match.home] = home
            table[match.away] = away
        }

        return table.values.map { standing in
            var trimmed = standing
            trimmed.form = Array(standing.form.suffix(5))
            return trimmed
        }.sorted { lhs, rhs in
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
            if lhs.goalDifference != rhs.goalDifference { return lhs.goalDifference > rhs.goalDifference }
            if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
            return lhs.team.name < rhs.team.name
        }
    }

    // MARK: - Escalação e força

    enum PositionFit: Int {
        case natural = 0, adapted, improvised

        /// Pontos de geral perdidos por jogar fora da posição natural.
        var penalty: Double {
            switch self {
            case .natural: return 0
            case .adapted: return 1.0
            case .improvised: return 1.6
            }
        }
    }

    struct SlotAssignment {
        let slot: FootballPosition
        let player: FootballPlayer
        let fit: PositionFit
    }

    static let groupOrder: [FootballPosition] = [.goalkeeper, .defender, .midfielder, .forward]

    static func score(_ player: FootballPlayer, for slot: FootballPosition) -> Double {
        let fit: PositionFit = player.position == slot ? .natural : (player.learnedPositions.contains(slot) ? .adapted : .improvised)
        return player.effectiveOverall - fit.penalty
    }

    /// Distribui os jogadores pelas vagas da formação: naturais primeiro, depois adaptados, por fim improvisados.
    static func assignSlots(lineup: [FootballPlayer], formation: FootballFormation) -> [SlotAssignment] {
        var remaining = lineup
        var output: [SlotAssignment] = []
        for slot in groupOrder {
            let required = formation.requiredPlayers[slot, default: 0]
            var picked = 0
            for fit in [PositionFit.natural, .adapted] {
                while picked < required {
                    let candidates = remaining.enumerated().filter { _, player in
                        fit == .natural ? player.position == slot : (player.position != slot && player.learnedPositions.contains(slot))
                    }
                    guard let best = candidates.max(by: { score($0.element, for: slot) < score($1.element, for: slot) }) else { break }
                    output.append(SlotAssignment(slot: slot, player: best.element, fit: fit))
                    remaining.remove(at: best.offset)
                    picked += 1
                }
            }
        }
        // O que sobrar preenche as vagas ainda abertas, improvisando.
        for slot in groupOrder {
            let required = formation.requiredPlayers[slot, default: 0]
            var filled = output.filter { $0.slot == slot }.count
            while filled < required, let best = remaining.enumerated().max(by: { score($0.element, for: slot) < score($1.element, for: slot) }) {
                output.append(SlotAssignment(slot: slot, player: best.element, fit: .improvised))
                remaining.remove(at: best.offset)
                filled += 1
            }
        }
        return output
    }

    /// Melhor escalação disponível (sem lesionados, suspensos nem convocados), considerando a condição física.
    static func bestLineup(roster: [FootballPlayer], formation: FootballFormation, matchDay: Int = -1) -> [Int] {
        let available = roster.filter { $0.isAvailable(matchDay: matchDay) && !$0.isYouth }
        var chosen: [Int] = []
        for slot in groupOrder {
            let required = formation.requiredPlayers[slot, default: 0]
            var picks = available
                .filter { $0.position == slot && !chosen.contains($0.id) }
                .sorted(by: strongerFirst)
                .prefix(required)
                .map(\.id)
            if picks.count < required {
                let learned = available
                    .filter { $0.learnedPositions.contains(slot) && !chosen.contains($0.id) && !picks.contains($0.id) }
                    .sorted(by: strongerFirst)
                    .prefix(required - picks.count)
                    .map(\.id)
                picks.append(contentsOf: learned)
            }
            chosen.append(contentsOf: picks)
        }
        if chosen.count < 11 {
            let extras = available
                .filter { !chosen.contains($0.id) }
                .sorted(by: strongerFirst)
                .prefix(11 - chosen.count)
                .map(\.id)
            chosen.append(contentsOf: extras)
        }
        return chosen
    }

    static func strongerFirst(_ lhs: FootballPlayer, _ rhs: FootballPlayer) -> Bool {
        if lhs.effectiveOverall != rhs.effectiveOverall { return lhs.effectiveOverall > rhs.effectiveOverall }
        return lhs.id < rhs.id
    }

    static func canFill(roster: [FootballPlayer], formation: FootballFormation, matchDay: Int = -1) -> Bool {
        let available = roster.filter { !$0.isInjured && !$0.isYouth }
        return formation.requiredPlayers.allSatisfy { requirement in
            available.filter { $0.canPlay(as: requirement.key) }.count >= requirement.value
        }
    }

    /// Quantas vagas da formação estão ocupadas por atletas fora de posição (adaptados contam menos).
    static func outOfPositionCount(lineup: [FootballPlayer], formation: FootballFormation) -> Int {
        assignSlots(lineup: lineup, formation: formation).filter { $0.fit == .improvised }.count
    }

    /// Força média da escalação, com penalidade para improvisos e para ausência de goleiro.
    static func rating(of lineup: [FootballPlayer], formation: FootballFormation) -> Double {
        guard !lineup.isEmpty else { return 55 }
        let assignments = assignSlots(lineup: lineup, formation: formation)
        let total = assignments.reduce(0.0) { $0 + $1.player.effectiveOverall - $1.fit.penalty }
        var rating = total / Double(max(1, assignments.count))
        if !lineup.contains(where: { $0.position == .goalkeeper || $0.learnedPositions.contains(.goalkeeper) }) { rating -= 6 }
        if lineup.count < 11 { rating -= Double(11 - lineup.count) * 4 }
        return rating
    }

    // MARK: - Valores e geração de atletas

    static func marketValue(overall: Int, age: Int, potential: Int) -> Int {
        let base = Double(max(150_000, (overall - 38) * (overall - 38) * 1_250))
        let ageFactor: Double
        switch age {
        case ...21: ageFactor = 1.4
        case 22...24: ageFactor = 1.2
        case 25...29: ageFactor = 1.0
        case 30...31: ageFactor = 0.8
        default: ageFactor = 0.55
        }
        let growth = age <= 24 ? 1 + Double(max(0, potential - overall)) * 0.02 : 1
        let value = base * ageFactor * growth
        return Int((value / 10_000).rounded()) * 10_000
    }

    static func randomName(using random: inout FootballRandom) -> String {
        let first = random.pick(firstNames) ?? "Atleta"
        let last = random.pick(lastNames) ?? "Silva"
        return "\(first) \(last)"
    }

    static func makeTraits(attributes: PlayerAttributes, position: FootballPosition, age: Int, overall: Int, potential: Int,
                           using random: inout FootballRandom) -> [PlayerTrait] {
        var traits: [PlayerTrait] = []
        func offer(_ trait: PlayerTrait, _ condition: Bool, _ chance: Double) {
            if condition && traits.count < 2 && random.chance(chance) { traits.append(trait) }
        }
        offer(.naturalFinisher, position == .forward && attributes[.finishing] >= 15, 0.55)
        offer(.fragile, attributes[.injuryProneness] >= 14, 0.7)
        offer(.leader, attributes[.leadership] >= 14, 0.5)
        offer(.workhorse, attributes[.stamina] >= 15, 0.5)
        offer(.bigMatchPlayer, attributes[.bigMatches] >= 14, 0.6)
        offer(.choker, attributes[.bigMatches] <= 6, 0.6)
        offer(.setPieceSpecialist, position != .goalkeeper && attributes[.passing] >= 14, 0.25)
        offer(.prodigy, age <= 21 && potential - overall >= 12, 0.5)
        return traits
    }

    /// Cria um atleta completo: atributos coerentes com o geral, características, contrato e região.
    static func makePlayer(id: Int, position: FootballPosition, detail: PositionDetail? = nil, age: Int, overall: Int, potential: Int,
                           teamID: Int?, season: Int = 1, region: Int? = nil, using random: inout FootballRandom) -> FootballPlayer {
        let clampedOverall = min(94, max(48, overall))
        let clampedPotential = min(96, max(clampedOverall, potential))
        let resolvedDetail = detail ?? (random.pick(PositionDetail.defaults(for: position)) ?? .centralMid)
        let attributes = PlayerAttributes.derive(overall: clampedOverall, position: position, detail: resolvedDetail, random: &random)
        let traits = makeTraits(attributes: attributes, position: position, age: age, overall: clampedOverall,
                                potential: clampedPotential, using: &random)
        let value = marketValue(overall: clampedOverall, age: age, potential: clampedPotential)
        var player = FootballPlayer(
            id: id,
            name: randomName(using: &random),
            position: position,
            age: age,
            overall: clampedOverall,
            potential: clampedPotential,
            condition: random.int(in: 84...100),
            marketValue: value,
            teamID: teamID,
            detail: resolvedDetail,
            attributes: attributes,
            traits: traits,
            region: region ?? teamID.flatMap { team($0)?.region } ?? random.int(in: 0...4)
        )
        player.contract = PlayerContract(
            wage: PlayerContract.wage(forValue: value),
            endSeason: season + random.int(in: 0...3),
            status: .rotation
        )
        player.morale = random.int(in: 55...70)
        return player
    }

    static func makeYouth(id: Int, position: FootballPosition, teamStrength: Int, teamID: Int?, season: Int = 1,
                          quality: Int = 3, using random: inout FootballRandom) -> FootballPlayer {
        let overall = teamStrength - 16 + random.int(in: -4...5) + (quality - 3) * 2
        var youth = makePlayer(id: id, position: position, age: random.int(in: 17...19), overall: overall,
                               potential: overall + random.int(in: 10...22) + (quality - 3) * 2, teamID: teamID,
                               season: season, using: &random)
        youth.contract.endSeason = season + random.int(in: 2...4)
        youth.contract.wage = max(30_000, youth.contract.wage / 2)
        youth.contract.status = .prospect
        return youth
    }

    static func makeFreeAgent(id: Int, position: FootballPosition, season: Int = 1, using random: inout FootballRandom) -> FootballPlayer {
        let overall = random.int(in: 61...77)
        let age = random.int(in: 19...32)
        let growth = age <= 23 ? random.int(in: 4...14) : random.int(in: 0...5)
        var player = makePlayer(id: id, position: position, age: age, overall: overall, potential: overall + growth,
                                teamID: nil, season: season, using: &random)
        player.contract.endSeason = 0
        return player
    }

    static let squadTemplate: [FootballPosition] = [
        .goalkeeper, .goalkeeper,
        .defender, .defender, .defender, .defender, .defender,
        .midfielder, .midfielder, .midfielder, .midfielder, .midfielder,
        .forward, .forward, .forward, .forward
    ]

    static let squadDetails: [PositionDetail] = [
        .goalkeeper, .goalkeeper,
        .rightBack, .leftBack, .centreBack, .centreBack, .centreBack,
        .defensiveMid, .defensiveMid, .centralMid, .centralMid, .attackingMid,
        .winger, .winger, .striker, .striker
    ]

    static let freeAgentTemplate: [FootballPosition] = [
        .goalkeeper, .defender, .midfielder, .forward,
        .defender, .midfielder, .forward, .goalkeeper,
        .midfielder, .defender, .forward, .midfielder
    ]

    static func generatePlayers(seed: Int) -> [FootballPlayer] {
        var random = FootballRandom(seed: UInt64(bitPattern: Int64(seed)))
        var players: [FootballPlayer] = []
        for team in teams {
            for (offset, position) in squadTemplate.enumerated() {
                let id = team.id * squadTemplate.count + offset
                let overall = team.strength + random.int(in: -9...9)
                let age = random.int(in: 18...34)
                let growth = age <= 22 ? random.int(in: 8...17) : (age <= 27 ? random.int(in: 1...8) : random.int(in: 0...3))
                players.append(makePlayer(id: id, position: position, detail: squadDetails[offset], age: age, overall: overall,
                                          potential: overall + growth, teamID: team.id, using: &random))
            }
        }
        for (offset, position) in freeAgentTemplate.enumerated() {
            players.append(makeFreeAgent(id: teams.count * squadTemplate.count + offset, position: position, using: &random))
        }
        return players
    }
}
