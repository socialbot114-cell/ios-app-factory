import Foundation

enum MatchTeamSide {
    case home, away

    var other: MatchTeamSide { self == .home ? .away : .home }
}

enum ShotType: Int, CaseIterable {
    case openPlay, header, longRange, counter, setPiece

    var baseWeight: Double {
        switch self {
        case .openPlay: return 0.42
        case .header: return 0.12
        case .longRange: return 0.22
        case .counter: return 0.10
        case .setPiece: return 0.14
        }
    }

    /// xG médio da finalização deste tipo.
    var meanXG: Double {
        switch self {
        case .openPlay: return 0.115
        case .header: return 0.09
        case .longRange: return 0.035
        case .counter: return 0.19
        case .setPiece: return 0.075
        }
    }

    var assistChance: Double {
        switch self {
        case .openPlay: return 0.72
        case .header: return 0.85
        case .longRange: return 0.15
        case .counter: return 0.8
        case .setPiece: return 0.7
        }
    }
}

extension MatchSimulation {
    static let goalCalibration = 0.84
    static let foulsPerMinute = 0.135
    static let injuryPerMinute = 0.0013
    static let penaltyPerMinute = 0.0013

    subscript(side: MatchTeamSide) -> MatchSideState {
        get { side == .home ? home : away }
        set { if side == .home { home = newValue } else { away = newValue } }
    }

    // MARK: - Estado inicial

    static func make(fixtureID: Int, seed: UInt64, isCup: Bool, isDerby: Bool, detailed: Bool,
                     home: MatchSideState, away: MatchSideState) -> MatchSimulation {
        var sim = MatchSimulation(fixtureID: fixtureID, seed: seed, isCup: isCup, isDerby: isDerby, detailed: detailed, home: home, away: away)
        for side in [MatchTeamSide.home, .away] {
            sim[side].appeared = sim[side].onPitch
            if detailed {
                for id in sim[side].onPitch + sim[side].bench { sim[side].stats[id] = PlayerMatchStats(playerID: id) }
            }
        }
        return sim
    }

    // MARK: - Minuto a minuto

    mutating func step(players: [Int: FootballPlayer]) {
        guard !finished else { return }
        minute += 1
        var random = FootballRandom(seed: seed &+ UInt64(minute) &* 0xD6E8FEB86659FD93)

        applyFatigue(players: players)
        if needsRecompute || minute % (detailed ? 5 : 15) == 1 { recomputeStrengths(players: players) }

        // Posse de bola com variação lenta ao longo da partida.
        var blockRandom = FootballRandom(seed: seed ^ UInt64(minute / 15 + 1) &* 0xA24BAED4963EE407)
        let noise = Double(blockRandom.int(in: -3...3)) / 100
        possessionShare = min(0.7, max(0.3, 0.5 + (home.cachedControl - away.cachedControl) * 0.015 + noise))
        home.possessionAccumulator += possessionShare
        away.possessionAccumulator += 1 - possessionShare

        let periodFactor = inExtraTime ? 0.55 : 1.0
        let homeRate = FootballMatchEngine.expectedGoals(attack: home.cachedAttack, defense: away.cachedDefense, possessionShare: possessionShare) / 45 * periodFactor
        let awayRate = FootballMatchEngine.expectedGoals(attack: away.cachedAttack, defense: home.cachedDefense, possessionShare: 1 - possessionShare) / 45 * periodFactor
        home.expectedGoals += homeRate
        away.expectedGoals += awayRate
        momentum.append(Int(((homeRate - awayRate) / max(0.0001, homeRate + awayRate) * 100).rounded()))

        for side in [MatchTeamSide.home, .away] {
            shotPhase(side: side, rate: side == .home ? homeRate : awayRate, players: players, random: &random)
            penaltyPhase(side: side, attack: self[side].cachedAttack, rivalDefense: self[side.other].cachedDefense, players: players, random: &random)
            foulPhase(side: side, players: players, random: &random)
            injuryPhase(side: side, players: players, random: &random)
        }
        for side in [MatchTeamSide.home, .away] where detailed {
            touchPhase(side: side, players: players, random: &random)
            for id in self[side].onPitch { self[side].stats[id, default: PlayerMatchStats(playerID: id)].minutes += 1 }
        }

        for side in [MatchTeamSide.home, .away] where !self[side].isUserControlled {
            aiDecisions(side: side, players: players, random: &random)
        }

        if minute == 45 { addEvent(.halfTime, nil, "Intervalo: \(scoreLine).") }
        if minute == 90 {
            if isCup && home.goals == away.goals {
                inExtraTime = true
                wentToExtraTime = true
                addEvent(.extraTime, nil, "Empate em \(home.goals) × \(away.goals) no tempo normal. Vamos para a prorrogação!")
            } else {
                finished = true
            }
        }
        if minute == 120 {
            finished = true
            if home.goals == away.goals { needsShootout = true }
        }
    }

    /// Simula até o minuto informado (ou até o fim).
    mutating func advance(to target: Int, players: [Int: FootballPlayer]) {
        while !finished && minute < target { step(players: players) }
    }

    mutating func runToEnd(players: [Int: FootballPlayer]) {
        while !finished { step(players: players) }
    }

    var scoreLine: String { "\(FootballSeason.teamName(home.teamID)) \(home.goals) × \(away.goals) \(FootballSeason.teamName(away.teamID))" }

    // MARK: - Fadiga e forças

    private mutating func applyFatigue(players: [Int: FootballPlayer]) {
        for side in [MatchTeamSide.home, .away] {
            let state = self[side]
            let base = Double(state.style.fatigueCost) / 90 * state.instructions.fatigueFactor
            for id in state.onPitch {
                guard let player = players[id] else { continue }
                var cost = base * (1.3 - 0.03 * Double(player.attributes[.stamina]))
                if player.has(.workhorse) { cost *= 0.85 }
                if inExtraTime { cost *= 1.25 }
                self[side].matchCondition[id] = max(25, (self[side].matchCondition[id] ?? Double(player.condition)) - cost)
            }
        }
    }

    func matchSide(_ side: MatchTeamSide, players: [Int: FootballPlayer]) -> MatchSide {
        let state = self[side]
        let lineup: [FootballPlayer] = state.onPitch.compactMap { id in
            guard var player = players[id] else { return nil }
            player.condition = Int(state.matchCondition[id] ?? Double(player.condition))
            return player
        }
        return MatchSide(teamID: state.teamID, lineup: lineup, formation: state.formation, style: state.style,
                         opponentStyle: self[side.other].style, isHome: side == .home)
    }

    mutating func recomputeStrengths(players: [Int: FootballPlayer]) {
        for side in [MatchTeamSide.home, .away] {
            let state = self[side]
            let rival = self[side.other]
            let built = matchSide(side, players: players)
            var attack = built.attack
            var defense = built.defense
            var control = built.control
            let instructions = state.instructions.modifiers
            attack += instructions.attack
            defense += instructions.defense
            control += instructions.control
            let rivalInstructions = rival.instructions
            if rivalInstructions.timeWasting { control -= 2 }
            for id in state.onPitch {
                if let role = state.roles[id] {
                    let mods = role.modifiers
                    attack += mods.attack / 11
                    defense += mods.defense / 11
                    control += mods.control / 11
                }
            }
            if let target = state.markTargetID, rival.onPitch.contains(target) { defense -= 0.4 }
            if let target = rival.markTargetID, state.onPitch.contains(target) { attack -= 1.0 }
            attack += state.attackBoost
            if minute >= 60 {
                let difference = state.goals - rival.goals
                attack += min(1.5, max(-1.5, -Double(difference) * 0.7))
            }
            self[side].cachedAttack = attack
            self[side].cachedDefense = defense
            self[side].cachedControl = control
            let weights = typeWeights(side: side, players: players)
            self[side].cachedTypeWeights = weights
            self[side].cachedShotMean = zip(weights, ShotType.allCases).reduce(0.0) { $0 + $1.0 * $1.1.meanXG }
        }
        needsRecompute = false
    }

    // MARK: - Finalizações

    private func typeWeights(side: MatchTeamSide, players: [Int: FootballPlayer]) -> [Double] {
        let state = self[side]
        var weights = ShotType.allCases.map(\.baseWeight)
        if state.style == .counter { weights[ShotType.counter.rawValue] *= 1.8 }
        if state.style == .possession { weights[ShotType.longRange.rawValue] *= 0.7 }
        if state.instructions.width == .high { weights[ShotType.header.rawValue] *= 1.3 }
        if state.onPitch.contains(where: { state.roles[$0] == .targetMan }) { weights[ShotType.header.rawValue] *= 1.2 }
        let total = weights.reduce(0, +)
        return weights.map { $0 / total }
    }

    private mutating func shotPhase(side: MatchTeamSide, rate: Double, players: [Int: FootballPlayer], random: inout FootballRandom) {
        let chance = min(0.55, rate / max(0.02, self[side].cachedShotMean))
        guard random.chance(chance) else { return }
        let weights = self[side].cachedTypeWeights
        guard let typeIndex = random.weightedIndex(weights.map { Int($0 * 1000) }) else { return }
        let type = ShotType.allCases[typeIndex]
        takeShot(side: side, type: type, players: players, random: &random)
    }

    private func pickShooter(side: MatchTeamSide, type: ShotType, players: [Int: FootballPlayer], random: inout FootballRandom) -> FootballPlayer? {
        let state = self[side]
        let rival = self[side.other]
        let candidates = state.onPitch.compactMap { players[$0] }.filter { $0.position != .goalkeeper }
        let weights: [Int] = candidates.map { player in
            var weight = Double(player.position.scoringWeight)
            switch type {
            case .header: weight *= Double(player.attributes[.heading] + 2) * (player.position == .defender ? 1.5 : 1.0)
            case .longRange: weight *= player.position == .midfielder ? 1.6 : (player.position == .forward ? 0.6 : 0.8)
                weight *= Double(player.attributes[.finishing] + 4)
            case .setPiece: weight = Double(player.position.scoringWeight + 1) * (player.has(.setPieceSpecialist) ? 3.0 : 1.0)
                weight *= Double(player.attributes[.passing] + 4)
            default: weight *= Double(player.attributes[.finishing] + 2)
            }
            weight *= state.roles[player.id]?.shotWeight ?? 1.0
            if player.has(.naturalFinisher) { weight *= 1.35 }
            if rival.markTargetID == player.id { weight *= 0.5 }
            return max(1, Int(weight))
        }
        guard let index = random.weightedIndex(weights) else { return candidates.first }
        return candidates[index]
    }

    private func pickAssister(side: MatchTeamSide, excluding shooterID: Int, players: [Int: FootballPlayer], random: inout FootballRandom) -> FootballPlayer? {
        let mates = self[side].onPitch.compactMap { players[$0] }.filter { $0.id != shooterID && $0.position != .goalkeeper }
        let weights = mates.map { max(1, $0.position.assistWeight * ($0.attributes[.passing] * 3 + $0.attributes[.vision] * 2 + $0.overall / 2 - 40) / 4) }
        guard let index = random.weightedIndex(weights) else { return nil }
        return mates[index]
    }

    private func keeper(of side: MatchTeamSide, players: [Int: FootballPlayer]) -> FootballPlayer? {
        self[side].onPitch.compactMap { players[$0] }.first { $0.position == .goalkeeper }
    }

    private mutating func takeShot(side: MatchTeamSide, type: ShotType, players: [Int: FootballPlayer], random: inout FootballRandom) {
        guard let shooter = pickShooter(side: side, type: type, players: players, random: &random) else { return }
        let rivalKeeper = keeper(of: side.other, players: players)
        let xg = type.meanXG * (0.7 + 0.6 * random.unit())
        var finishing = Double(type == .header ? shooter.attributes[.heading] : shooter.attributes[.finishing])
        if type == .setPiece || type == .longRange { finishing = Double(shooter.attributes[.passing] + shooter.attributes[.finishing]) / 2 }
        var shooterFactor = min(1.35, max(0.7, 1 + (finishing - 10) * 0.03))
        if isCup || isDerby {
            if shooter.has(.bigMatchPlayer) { shooterFactor *= 1.05 }
            if shooter.has(.choker) { shooterFactor *= 0.95 }
        }
        let keeperFactor = rivalKeeper.map { min(1.3, max(0.75, 1 + (14 - Double($0.attributes[.reflexes])) * 0.025)) } ?? 1.4
        let goalChance = xg * shooterFactor * keeperFactor * Self.goalCalibration

        let x: Double
        switch type {
        case .openPlay: x = 0.08 + 0.2 * random.unit()
        case .header: x = 0.04 + 0.08 * random.unit()
        case .longRange: x = 0.3 + 0.2 * random.unit()
        case .counter: x = 0.05 + 0.15 * random.unit()
        case .setPiece: x = 0.04 + 0.36 * random.unit()
        }
        let y = type == .header ? 0.35 + 0.3 * random.unit() : 0.15 + 0.7 * random.unit()

        self[side].shots += 1
        self[side].expectedGoals += 0
        self[side].stats[shooter.id, default: PlayerMatchStats(playerID: shooter.id)].shots += 1
        let teamID = self[side].teamID

        if random.chance(goalChance) {
            self[side].shotsOnTarget += 1
            self[side].goals += 1
            self[side].scorerIDs.append(shooter.id)
            self[side].stats[shooter.id, default: PlayerMatchStats(playerID: shooter.id)].shotsOnTarget += 1
            self[side].stats[shooter.id, default: PlayerMatchStats(playerID: shooter.id)].goals += 1
            var assistName: String?
            var assistID: Int?
            if random.chance(type.assistChance), let assister = pickAssister(side: side, excluding: shooter.id, players: players, random: &random) {
                assistID = assister.id
                assistName = assister.name
                self[side].assistIDs.append(assister.id)
                self[side].stats[assister.id, default: PlayerMatchStats(playerID: assister.id)].assists += 1
            }
            if detailed {
                let teamName = FootballSeason.teamName(teamID)
                var text = "GOL! \(shooter.name) \(Self.goalPhrase(type, random: &random)) para o \(teamName)"
                if let assistName { text += ", após passe de \(assistName)." } else { text += "." }
                text += " \(scoreLineAfterGoal)"
                events.append(MatchEvent(minute: minute, kind: .goal, teamID: teamID, text: text, playerID: shooter.id,
                                         relatedPlayerID: assistID, xg: (xg * 100).rounded() / 100, x: x, y: y))
            }
            if minute >= 55 || detailed { needsRecompute = true }
            return
        }

        let onTarget = random.chance(type == .longRange ? 0.27 : 0.33)
        if onTarget {
            self[side].shotsOnTarget += 1
            self[side].stats[shooter.id, default: PlayerMatchStats(playerID: shooter.id)].shotsOnTarget += 1
            if let rivalKeeper { self[side.other].stats[rivalKeeper.id, default: PlayerMatchStats(playerID: rivalKeeper.id)].saves += 1 }
        }
        if random.chance(0.4) { self[side].corners += 1 }
        guard detailed, xg >= 0.09 || onTarget && random.chance(0.4) else { return }
        let keeperName = rivalKeeper?.name ?? "o goleiro"
        let text: String
        if onTarget {
            text = random.chance(0.5)
                ? "\(keeperName) faz grande defesa em chute de \(shooter.name)."
                : "\(shooter.name) finaliza forte e \(keeperName) espalma."
        } else {
            text = random.chance(0.5) ? "\(shooter.name) finaliza por cima do travessão." : "\(shooter.name) cabeceia rente à trave."
        }
        events.append(MatchEvent(minute: minute, kind: onTarget ? .save : .chance, teamID: teamID, text: text, playerID: shooter.id,
                                 relatedPlayerID: onTarget ? rivalKeeper?.id : nil, xg: (xg * 100).rounded() / 100, x: x, y: y))
    }

    private var scoreLineAfterGoal: String { "\(home.goals) × \(away.goals)." }

    private static func goalPhrase(_ type: ShotType, random: inout FootballRandom) -> String {
        switch type {
        case .openPlay: return random.chance(0.5) ? "finaliza com categoria" : "bate firme, sem chances para o goleiro"
        case .header: return "sobe mais alto que a defesa e cabeceia"
        case .longRange: return "arrisca de longe e acerta um golaço"
        case .counter: return "conclui o contra-ataque"
        case .setPiece: return "aproveita a bola parada e marca"
        }
    }

    // MARK: - Pênaltis

    private mutating func penaltyPhase(side: MatchTeamSide, attack: Double, rivalDefense: Double, players: [Int: FootballPlayer], random: inout FootballRandom) {
        let probability = Self.penaltyPerMinute * exp((attack - rivalDefense) / 25)
        guard random.chance(probability) else { return }
        let state = self[side]
        let rivalKeeper = keeper(of: side.other, players: players)
        let takers = state.onPitch.compactMap { players[$0] }.filter { $0.position != .goalkeeper }
        let taker: FootballPlayer?
        if let chosen = state.penaltyTakerID, let player = takers.first(where: { $0.id == chosen }) {
            taker = player
        } else {
            taker = takers.max {
                let left = Double($0.attributes[.finishing]) * ($0.has(.setPieceSpecialist) ? 1.4 : 1.0)
                let right = Double($1.attributes[.finishing]) * ($1.has(.setPieceSpecialist) ? 1.4 : 1.0)
                return left < right
            }
        }
        guard let taker else { return }
        let teamID = state.teamID
        let chance = min(0.9, max(0.55, 0.74 + Double(taker.attributes[.finishing] - 10) * 0.012
                                  - Double((rivalKeeper?.attributes[.handling] ?? 12) - 12) * 0.01 + (taker.has(.setPieceSpecialist) ? 0.05 : 0)))
        if detailed {
            events.append(MatchEvent(minute: minute, kind: .penaltyAwarded, teamID: teamID,
                                     text: "Pênalti para o \(FootballSeason.teamName(teamID))! \(taker.name) vai para a bola.", playerID: taker.id))
        }
        self[side].shots += 1
        self[side].stats[taker.id, default: PlayerMatchStats(playerID: taker.id)].shots += 1
        if random.chance(chance) {
            self[side].shotsOnTarget += 1
            self[side].goals += 1
            self[side].scorerIDs.append(taker.id)
            self[side].stats[taker.id, default: PlayerMatchStats(playerID: taker.id)].goals += 1
            if detailed {
                events.append(MatchEvent(minute: minute, kind: .goal, teamID: teamID,
                                         text: "GOL de pênalti! \(taker.name) converte para o \(FootballSeason.teamName(teamID)). \(scoreLineAfterGoal)",
                                         playerID: taker.id, xg: 0.76, x: 0.11, y: 0.5))
            }
            needsRecompute = true
        } else if detailed {
            let saved = random.chance(0.6)
            if saved, let rivalKeeper {
                self[side].shotsOnTarget += 1
                self[side.other].stats[rivalKeeper.id, default: PlayerMatchStats(playerID: rivalKeeper.id)].saves += 1
            }
            let text = saved && rivalKeeper != nil ? "\(rivalKeeper!.name) defende o pênalti de \(taker.name)!" : "\(taker.name) isola a cobrança!"
            events.append(MatchEvent(minute: minute, kind: .save, teamID: teamID, text: text, playerID: taker.id, xg: 0.76, x: 0.11, y: 0.5))
        }
    }

    // MARK: - Faltas e cartões

    private mutating func foulPhase(side: MatchTeamSide, players: [Int: FootballPlayer], random: inout FootballRandom) {
        let state = self[side]
        var factor = state.instructions.foulFactor
        switch state.style {
        case .highPress: factor *= 1.2
        case .defensive: factor *= 0.95
        case .possession: factor *= 0.9
        default: break
        }
        guard random.chance(Self.foulsPerMinute * factor) else { return }
        let candidates = state.onPitch.compactMap { players[$0] }
        let weights = candidates.map { player -> Int in
            let base: Double
            switch player.position {
            case .goalkeeper: base = 0.1
            case .defender: base = 3
            case .midfielder: base = 3
            case .forward: base = 1.5
            }
            var weight = base * (1 + Double(player.attributes[.tackling] - 10) * 0.03) * (state.roles[player.id] == .destroyer ? 1.4 : 1.0)
            weight *= 10
            return max(1, Int(weight))
        }
        guard let index = random.weightedIndex(weights) else { return }
        let fouler = candidates[index]
        self[side].fouls += 1
        self[side].stats[fouler.id, default: PlayerMatchStats(playerID: fouler.id)].fouls += 1
        let teamID = state.teamID
        let redChance = 0.0012
        let yellowChance = 0.175 + (state.style == .highPress ? 0.03 : 0) + (state.instructions.timeWasting ? 0.02 : 0)
        if random.chance(redChance) {
            sendOff(side: side, playerID: fouler.id, second: false, players: players)
            _ = teamID
        } else if random.chance(yellowChance) {
            if self[side].booked.contains(fouler.id) {
                // O árbitro nem sempre dá o segundo amarelo.
                if random.chance(0.35) { sendOff(side: side, playerID: fouler.id, second: true, players: players) }
            } else {
                self[side].booked.append(fouler.id)
                self[side].yellowCards += 1
                self[side].yellowCardIDs.append(fouler.id)
                self[side].stats[fouler.id, default: PlayerMatchStats(playerID: fouler.id)].yellowCards += 1
                if detailed {
                    events.append(MatchEvent(minute: minute, kind: .yellowCard, teamID: teamID,
                                             text: "Cartão amarelo para \(fouler.name) (\(FootballSeason.teamName(teamID))).", playerID: fouler.id))
                }
            }
        }
    }

    private mutating func sendOff(side: MatchTeamSide, playerID: Int, second: Bool, players: [Int: FootballPlayer]) {
        guard self[side].onPitch.contains(playerID) else { return }
        let teamID = self[side].teamID
        let name = players[playerID]?.name ?? "Atleta"
        self[side].onPitch.removeAll { $0 == playerID }
        self[side].removed.append(playerID)
        self[side].redCards += 1
        self[side].redCardIDs.append(playerID)
        self[side].stats[playerID, default: PlayerMatchStats(playerID: playerID)].redCard = true
        if second {
            self[side].yellowCardIDs.append(playerID)
            self[side].yellowCards += 1
        }
        needsRecompute = true
        if detailed {
            let text = second ? "Segundo amarelo e expulsão de \(name) (\(FootballSeason.teamName(teamID)))! O time fica com um a menos."
                              : "Cartão vermelho direto para \(name) (\(FootballSeason.teamName(teamID)))! O time fica com um a menos."
            events.append(MatchEvent(minute: minute, kind: .redCard, teamID: teamID, text: text, playerID: playerID))
        }
    }

    // MARK: - Lesões

    private mutating func injuryPhase(side: MatchTeamSide, players: [Int: FootballPlayer], random: inout FootballRandom) {
        let state = self[side]
        guard random.chance(Self.injuryPerMinute * (state.instructions.pressing == .high ? 1.1 : 1.0)) else { return }
        let candidates = state.onPitch.compactMap { players[$0] }
        let weights = candidates.map { player -> Int in
            let condition = state.matchCondition[player.id] ?? Double(player.condition)
            var weight = Double(player.attributes[.injuryProneness] + 2) * (1 + (100 - condition) / 60)
            if player.has(.fragile) { weight *= 1.8 }
            return max(1, Int(weight * 4))
        }
        guard let index = random.weightedIndex(weights) else { return }
        let hurt = candidates[index]
        let rounds = min(6, 1 + Int(-log(max(0.0001, random.unit())) * 1.4))
        self[side].injuries[hurt.id] = rounds
        let teamID = state.teamID
        if detailed {
            events.append(MatchEvent(minute: minute, kind: .injury, teamID: teamID,
                                     text: "\(hurt.name) sente a lesão e não pode continuar (\(FootballSeason.teamName(teamID))).", playerID: hurt.id))
        }
        // Substituição de emergência: não consome janela de substituições.
        let bench = self[side].bench.compactMap { players[$0] }
        let replacement = bench.filter { $0.position == hurt.position }.max(by: { $0.effectiveOverall < $1.effectiveOverall })
            ?? bench.max(by: { $0.effectiveOverall < $1.effectiveOverall })
        if self[side].substitutionsUsed < Self.maxSubstitutions, let replacement {
            performSubstitution(side: side, out: hurt.id, in: replacement.id, players: players, emergency: true)
        } else {
            self[side].onPitch.removeAll { $0 == hurt.id }
            self[side].removed.append(hurt.id)
            needsRecompute = true
        }
    }

    // MARK: - Substituições

    func canSubstitute(side: MatchTeamSide, out: Int, in incoming: Int) -> Bool {
        let state = self[side]
        guard state.onPitch.contains(out), state.bench.contains(incoming), !finished else { return false }
        guard state.substitutionsUsed < Self.maxSubstitutions else { return false }
        let stops = Set(state.substitutionMinutes.filter { $0 != 45 })
        if minute != 45 && !stops.contains(minute) && stops.count >= Self.maxSubstitutionStops { return false }
        return true
    }

    @discardableResult
    mutating func substitute(side: MatchTeamSide, out: Int, in incoming: Int, players: [Int: FootballPlayer]) -> Bool {
        guard canSubstitute(side: side, out: out, in: incoming) else { return false }
        performSubstitution(side: side, out: out, in: incoming, players: players, emergency: false)
        return true
    }

    private mutating func performSubstitution(side: MatchTeamSide, out: Int, in incoming: Int, players: [Int: FootballPlayer], emergency: Bool) {
        guard let outIndex = self[side].onPitch.firstIndex(of: out) else { return }
        self[side].onPitch[outIndex] = incoming
        self[side].bench.removeAll { $0 == incoming }
        self[side].removed.append(out)
        self[side].substitutionsUsed += 1
        self[side].substitutionMinutes.append(minute)
        if let player = players[incoming] { self[side].matchCondition[incoming] = Double(player.condition) }
        if !self[side].appeared.contains(incoming) { self[side].appeared.append(incoming) }
        if let role = self[side].roles[out] { self[side].roles[incoming] = role; self[side].roles[out] = nil }
        needsRecompute = true
        if detailed {
            let teamID = self[side].teamID
            let outName = players[out]?.name ?? "Atleta"
            let inName = players[incoming]?.name ?? "Atleta"
            events.append(MatchEvent(minute: minute, kind: .substitution, teamID: teamID,
                                     text: "\(emergency ? "Substituição forçada" : "Substituição") no \(FootballSeason.teamName(teamID)): sai \(outName), entra \(inName).",
                                     playerID: incoming, relatedPlayerID: out))
        }
    }

    // MARK: - Ajustes táticos

    mutating func setStyle(side: MatchTeamSide, _ style: FootballPlayStyle) {
        guard self[side].style != style else { return }
        self[side].style = style
        needsRecompute = true
        if detailed || self[side].isUserControlled {
            let teamID = self[side].teamID
            events.append(MatchEvent(minute: minute, kind: .tactic, teamID: teamID,
                                     text: "Mudança tática do \(FootballSeason.teamName(teamID)): estilo \(style.rawValue.lowercased())."))
        }
    }

    mutating func setInstructions(side: MatchTeamSide, _ instructions: TeamInstructions) {
        guard self[side].instructions != instructions else { return }
        self[side].instructions = instructions
        needsRecompute = true
    }

    mutating func setFormation(side: MatchTeamSide, _ formation: FootballFormation) {
        guard self[side].formation != formation else { return }
        self[side].formation = formation
        needsRecompute = true
        let teamID = self[side].teamID
        events.append(MatchEvent(minute: minute, kind: .tactic, teamID: teamID,
                                 text: "O \(FootballSeason.teamName(teamID)) muda para o \(formation.rawValue)."))
    }

    // MARK: - Decisões da IA

    private mutating func aiDecisions(side: MatchTeamSide, players: [Int: FootballPlayer], random: inout FootballRandom) {
        let state = self[side]
        let difference = state.goals - self[side.other].goals
        if minute == 46 || minute == 70 {
            let target: FootballPlayStyle
            if difference < 0 { target = .attacking } else if difference >= 2 { target = .defensive } else { target = state.style }
            if target != state.style { setStyle(side: side, target) }
        }
        if minute == 80 && difference == 1 {
            var instructions = state.instructions
            instructions.timeWasting = true
            setInstructions(side: side, instructions)
        }
        guard [58, 68, 78].contains(minute), state.substitutionsUsed < Self.maxSubstitutions else { return }
        var made = 0
        let tired = state.onPitch.compactMap { players[$0] }
            .filter { $0.position != .goalkeeper }
            .sorted { (state.matchCondition[$0.id] ?? 100) < (state.matchCondition[$1.id] ?? 100) }
        for candidate in tired {
            guard made < 2, self[side].substitutionsUsed < Self.maxSubstitutions else { break }
            let condition = self[side].matchCondition[candidate.id] ?? 100
            guard condition < (minute >= 78 ? 80 : 68) else { break }
            let bench = self[side].bench.compactMap { players[$0] }.filter { $0.position == candidate.position && $0.isAvailable(matchDay: -1) }
            guard let fresh = bench.max(by: { $0.effectiveOverall < $1.effectiveOverall }) else { continue }
            performSubstitution(side: side, out: candidate.id, in: fresh.id, players: players, emergency: false)
            made += 1
        }
    }

    // MARK: - Toques e mapa de calor

    private mutating func touchPhase(side: MatchTeamSide, players: [Int: FootballPlayer], random: inout FootballRandom) {
        let share = side == .home ? possessionShare : 1 - possessionShare
        for id in self[side].onPitch {
            guard let player = players[id] else { continue }
            let involvement: Double
            switch player.position {
            case .goalkeeper: involvement = 0.35
            case .defender: involvement = 0.55
            case .midfielder: involvement = 0.85
            case .forward: involvement = 0.5
            }
            guard random.chance(min(0.95, involvement * (0.6 + share))) else { continue }
            let (baseColumn, baseRow) = Self.baseZone(player.detail)
            let columnShift = random.int(in: -1...1)
            var column = min(MatchSideState.heatColumns - 1, max(0, baseColumn + (random.chance(0.5) ? columnShift : 0) + (share > 0.55 && random.chance(0.4) ? 1 : 0)))
            if player.position == .goalkeeper { column = 0 }
            let row = min(MatchSideState.heatRows - 1, max(0, baseRow + (random.chance(0.35) ? random.int(in: -1...1) : 0)))
            var grid = self[side].heat[id] ?? Array(repeating: 0, count: MatchSideState.heatColumns * MatchSideState.heatRows)
            grid[column * MatchSideState.heatRows + row] += 1
            self[side].heat[id] = grid
        }
    }

    /// Zona-base de cada posição: coluna (0 = próprio gol, 3 = gol adversário) e faixa (0 esquerda, 1 centro, 2 direita).
    static func baseZone(_ detail: PositionDetail) -> (Int, Int) {
        switch detail {
        case .goalkeeper: return (0, 1)
        case .rightBack: return (1, 2)
        case .leftBack: return (1, 0)
        case .centreBack: return (1, 1)
        case .defensiveMid: return (1, 1)
        case .centralMid: return (2, 1)
        case .attackingMid: return (2, 1)
        case .winger: return (3, 0)
        case .striker: return (3, 1)
        }
    }

    // MARK: - Eventos

    mutating func addEvent(_ kind: MatchEvent.Kind, _ teamID: Int?, _ text: String) {
        guard detailed else { return }
        events.append(MatchEvent(minute: minute, kind: kind, teamID: teamID, text: text))
    }

    // MARK: - Resultado

    /// Disputa de pênaltis e resultado final. Deve ser chamado depois que a simulação termina.
    mutating func makeOutcome(players: [Int: FootballPlayer], startHome: [Int], startAway: [Int]) -> MatchOutcome {
        var homePenalties: Int?
        var awayPenalties: Int?
        if needsShootout {
            var shootoutRandom = FootballRandom(seed: seed ^ 0x5EEDBEEF)
            let homeSide = matchSide(.home, players: players)
            let awaySide = matchSide(.away, players: players)
            let result = FootballMatchEngine.penaltyShootout(home: homeSide, away: awaySide, using: &shootoutRandom)
            homePenalties = result.homeScore
            awayPenalties = result.awayScore
            if detailed {
                events.append(MatchEvent(minute: 120, kind: .extraTime, teamID: nil, text: "Fim da prorrogação. A vaga será decidida nos pênaltis."))
                events.append(contentsOf: result.events)
            }
        }
        let length = wentToExtraTime ? 120 : 90
        var finalText = "Apito final: \(scoreLine)"
        if let homePenalties, let awayPenalties {
            let winner = homePenalties > awayPenalties ? home.teamID : away.teamID
            finalText += " (\(homePenalties) × \(awayPenalties) nos pênaltis). \(FootballSeason.teamName(winner)) avança"
        }
        if detailed { events.append(MatchEvent(minute: length, kind: .fullTime, teamID: nil, text: finalText + ".")) }

        var finalCondition: [Int: Int] = [:]
        for side in [MatchTeamSide.home, .away] {
            for (id, value) in self[side].matchCondition { finalCondition[id] = max(40, Int(value.rounded())) }
        }
        var userStats: [PlayerMatchStats] = []
        if detailed {
            for side in [MatchTeamSide.home, .away] {
                for (id, var stats) in self[side].stats {
                    stats.heat = self[side].heat[id] ?? []
                    userStats.append(stats)
                }
            }
        }
        let homePossession = minute > 0 ? Int((home.possessionAccumulator / Double(minute) * 100).rounded()) : 50
        func goalMinutes(_ side: MatchTeamSide) -> [Int] {
            events.filter { $0.kind == .goal && $0.teamID == self[side].teamID }.map(\.minute)
        }
        return MatchOutcome(
            fixtureID: fixtureID,
            homeGoals: home.goals, awayGoals: away.goals,
            homeScorerIDs: home.scorerIDs, awayScorerIDs: away.scorerIDs,
            homeAssistIDs: home.assistIDs, awayAssistIDs: away.assistIDs,
            homeShots: home.shots, awayShots: away.shots,
            homeOnTarget: home.shotsOnTarget, awayOnTarget: away.shotsOnTarget,
            homeExpectedGoals: FootballMatchEngine.rounded(home.expectedGoals),
            awayExpectedGoals: FootballMatchEngine.rounded(away.expectedGoals),
            homePossession: min(75, max(25, homePossession)),
            homeCorners: home.corners, awayCorners: away.corners,
            homeFouls: home.fouls, awayFouls: away.fouls,
            homeYellow: home.yellowCards, awayYellow: away.yellowCards,
            homeRed: home.redCards, awayRed: away.redCards,
            wentToExtraTime: wentToExtraTime,
            homePenalties: homePenalties, awayPenalties: awayPenalties,
            yellowCardIDs: home.yellowCardIDs + away.yellowCardIDs,
            redCardIDs: home.redCardIDs + away.redCardIDs,
            injuries: home.injuries.merging(away.injuries) { first, _ in first },
            finalCondition: finalCondition,
            appeared: home.appeared + away.appeared,
            homeGoalMinutes: detailed ? goalMinutes(.home) : Self.syntheticGoalMinutes(count: home.goals, seed: seed, salt: 1),
            awayGoalMinutes: detailed ? goalMinutes(.away) : Self.syntheticGoalMinutes(count: away.goals, seed: seed, salt: 2),
            events: events,
            momentum: detailed ? momentum : [],
            homeLineupStart: startHome, awayLineupStart: startAway,
            homeLineupEnd: home.onPitch, awayLineupEnd: away.onPitch,
            homeStyle: home.style, awayStyle: away.style,
            userStats: userStats,
            heat: [:]
        )
    }

    /// Minutos dos gols nos jogos simulados sem narração, só para o placar ao vivo dos outros jogos.
    static func syntheticGoalMinutes(count: Int, seed: UInt64, salt: UInt64) -> [Int] {
        var random = FootballRandom(seed: seed ^ (salt &* 0x1234567))
        return (0..<count).map { _ in random.int(in: 2...90) }.sorted()
    }
}
