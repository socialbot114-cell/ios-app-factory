import Foundation

// MARK: - Personalidade da partida

/// Perfil do jogo derivado só da seed: dois jogos da mesma rodada não se parecem.
/// Todos os fatores têm média 1 para não deslocar o equilíbrio de gols da liga.
struct MatchFlavor: Equatable {
    let tempo: Double
    let volatility: Int
    let strictness: Double
    let aerial: Double
    let wide: Double
    let title: String

    init(seed: UInt64) {
        var random = FootballRandom(seed: MatchSimulation.mix(seed, 0xF1A5C0DE, 1))
        tempo = 0.92 + 0.16 * random.unit()
        volatility = random.int(in: 1...5)
        strictness = 0.85 + 0.3 * random.unit()
        aerial = 0.8 + 0.4 * random.unit()
        wide = 0.8 + 0.4 * random.unit()
        let traits: [(Double, String)] = [
            (tempo - 1, "Jogo aberto e rápido"),
            (1 - tempo, "Jogo truncado e estudado"),
            (strictness - 1, "Jogo físico e faltoso"),
            (aerial - 1, "Jogo de bolas aéreas"),
            (wide - 1, "Jogo pelas pontas")
        ]
        title = traits.max { $0.0 < $1.0 }?.1 ?? "Jogo equilibrado"
    }
}

// MARK: - Jogadas construídas

/// Como a finalização nasceu. Define quem finaliza, quem passa e o texto do lance.
enum BuildUp: CaseIterable {
    case wideCross, throughBall, oneTwo, cutback, longBall, cornerKick, freeKick, rebound, soloRun, recycled

    static func weights(for type: ShotType, flavor: MatchFlavor, style: FootballPlayStyle) -> [Double] {
        func table(_ values: [BuildUp: Double]) -> [Double] { allCases.map { values[$0] ?? 0 } }
        switch type {
        case .header:
            return table([.wideCross: 0.7 * flavor.wide, .cornerKick: 0.2, .freeKick: 0.1])
        case .setPiece:
            return table([.cornerKick: 0.45, .freeKick: 0.55])
        case .counter:
            return table([.longBall: 0.45, .throughBall: 0.4, .soloRun: 0.15])
        case .longRange:
            return table([.recycled: 0.5, .rebound: 0.2, .soloRun: 0.3])
        case .openPlay:
            let possession = style == .possession ? 1.4 : 1.0
            return table([.throughBall: 0.26, .oneTwo: 0.2 * possession, .cutback: 0.17 * flavor.wide,
                          .wideCross: 0.12 * flavor.wide, .soloRun: 0.1, .rebound: 0.08, .recycled: 0.07])
        }
    }

    var assistChance: Double {
        switch self {
        case .wideCross: return 0.88
        case .throughBall: return 0.92
        case .oneTwo: return 0.85
        case .cutback: return 0.95
        case .longBall: return 0.88
        case .cornerKick: return 0.75
        case .freeKick: return 0.55
        case .rebound: return 0.1
        case .soloRun: return 0
        case .recycled: return 0.3
        }
    }

    /// Quanto cada posição serve como autor do passe nesta jogada.
    func assistAffinity(_ player: FootballPlayer, role: PlayerRole?) -> Double {
        var value: Double
        switch self {
        case .wideCross, .cutback:
            switch player.detail {
            case .winger: value = 3
            case .rightBack, .leftBack: value = 2.2
            case .attackingMid: value = 1
            default: value = 0.5
            }
            if role == .dribblingWinger || role == .fullbackAttacking { value *= 1.4 }
        case .throughBall:
            switch player.detail {
            case .attackingMid: value = 2.6
            case .centralMid: value = 2
            case .winger: value = 1.4
            case .defensiveMid, .striker: value = 1
            default: value = 0.4
            }
        case .oneTwo:
            switch player.detail {
            case .striker, .attackingMid: value = 1.8
            case .winger: value = 1.5
            case .centralMid: value = 1.2
            default: value = 0.5
            }
        case .longBall:
            switch player.detail {
            case .centreBack, .defensiveMid: value = 2.1
            case .centralMid: value = 1.4
            default: value = 0.5
            }
        case .cornerKick, .freeKick:
            value = player.has(.setPieceSpecialist) ? 3 : 1
            if player.detail == .winger || player.detail == .centralMid || player.detail == .attackingMid { value *= 1.5 }
        case .rebound, .soloRun, .recycled:
            value = 1
        }
        if role == .playmaker { value *= 1.3 }
        return value
    }

    /// Ajuste na escolha do finalizador conforme a jogada.
    func shooterAffinity(_ player: FootballPlayer) -> Double {
        switch self {
        case .cutback: return player.position == .midfielder ? 1.5 : 1
        case .throughBall, .longBall: return player.position == .forward ? 1.25 : 1
        case .soloRun: return player.detail == .winger || player.detail == .attackingMid ? 1.4 : 1
        case .recycled: return player.position == .midfielder ? 1.3 : 1
        default: return 1
        }
    }

    func goalClause(assister: String?) -> String {
        guard let assister else {
            switch self {
            case .soloRun: return ", em jogada individual."
            case .rebound: return ", no rebote."
            default: return "."
            }
        }
        switch self {
        case .wideCross: return ", após cruzamento de \(assister)."
        case .throughBall: return ", após passe em profundidade de \(assister)."
        case .oneTwo: return ", após tabela com \(assister)."
        case .cutback: return ", após \(assister) ir à linha de fundo e rolar para trás."
        case .longBall: return ", após lançamento de \(assister)."
        case .cornerKick: return ", após escanteio cobrado por \(assister)."
        case .freeKick: return ", após falta cobrada por \(assister)."
        case .recycled: return ", após bola recuada por \(assister)."
        case .rebound, .soloRun: return ", após passe de \(assister)."
        }
    }

    func missLead(_ name: String) -> String? {
        switch self {
        case .wideCross: return "Cruzamento de \(name) na área!"
        case .throughBall: return "Passe em profundidade de \(name)!"
        case .oneTwo: return "Tabela com \(name) deixa a defesa para trás!"
        case .cutback: return "\(name) cruza rasteiro da linha de fundo!"
        case .longBall: return "Lançamento longo de \(name)!"
        case .cornerKick: return "Escanteio cobrado por \(name)."
        case .freeKick: return "Falta cobrada por \(name) na área."
        case .recycled: return "\(name) recua a bola para a entrada da área."
        case .rebound, .soloRun: return nil
        }
    }
}

// MARK: - Ações sem gol

extension MatchSimulation {
    /// Misturador de seeds (SplitMix) para derivar fluxos independentes sem consumir o fluxo principal.
    static func mix(_ seed: UInt64, _ a: UInt64, _ b: UInt64) -> UInt64 {
        var value = seed &+ a &* 0x9E3779B97F4A7C15 &+ b &* 0xD6E8FEB86659FD93
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    var flavor: MatchFlavor { MatchFlavor(seed: seed) }

    /// Desarmes, dribles, cruzamentos e impedimentos. Usa fluxo próprio: não altera placar nem estatísticas de gol.
    mutating func actionPhase(side: MatchTeamSide, players: [Int: FootballPlayer]) {
        var random = FootballRandom(seed: Self.mix(seed, UInt64(minute), side == .home ? 0xA1 : 0xA2))
        let state = self[side]
        let rival = self[side.other]
        let mates = state.onPitch.compactMap { players[$0] }
        let rivals = rival.onPitch.compactMap { players[$0] }
        guard !mates.isEmpty, !rivals.isEmpty else { return }
        let share = side == .home ? possessionShare : 1 - possessionShare
        let teamID = state.teamID
        let teamName = FootballSeason.teamName(teamID)
        let tempo = flavor.tempo

        // Impedimento: ataque no limite da linha alta do rival.
        let offsideChance = 0.045 * (0.6 + share) * tempo * (state.style == .counter ? 1.4 : 1) * (rival.instructions.lineHeight == .high ? 1.5 : 1)
        if random.chance(offsideChance) {
            let runners = mates.filter { $0.position == .forward || $0.detail == .attackingMid }
            if let runner = random.pick(runners) {
                let lines = ["A bandeira sobe: \(runner.name) estava impedido.",
                             "\(runner.name) parte na frente da defesa, mas o assistente marca impedimento.",
                             "Impedimento de \(runner.name) anula a jogada do \(teamName)."]
                events.append(MatchEvent(minute: minute, kind: .offside, teamID: teamID, text: lines[random.int(in: 0...(lines.count - 1))], playerID: runner.id))
            }
        }

        // Desarme: o time sem a bola recupera a posse.
        if random.chance(0.075 * (1.6 - share)) {
            let weights = mates.map { player -> Int in
                let base: Double = player.position == .defender ? 3 : (player.position == .midfielder ? 3 : (player.position == .forward ? 1 : 0.2))
                return max(1, Int(base * Double(player.attributes[.tackling] + 3) * (state.roles[player.id] == .destroyer ? 1.4 : 1)))
            }
            if let index = random.weightedIndex(weights) {
                let tackler = mates[index]
                self[side].stats[tackler.id, default: PlayerMatchStats(playerID: tackler.id)].tackles += 1
                if random.chance(0.4), let victim = random.pick(rivals.filter { $0.position != .goalkeeper }) {
                    let lines = ["\(tackler.name) chega firme e desarma \(victim.name).",
                                 "Bela recuperação de \(tackler.name), que tira a bola de \(victim.name).",
                                 "\(tackler.name) corta o avanço de \(victim.name) no tempo certo."]
                    events.append(MatchEvent(minute: minute, kind: .tackle, teamID: teamID, text: lines[random.int(in: 0...(lines.count - 1))],
                                             playerID: tackler.id, relatedPlayerID: victim.id))
                }
            }
        }

        // Drible: ponta ou meia ofensivo encara o marcador.
        if random.chance(0.05 * (0.6 + share) * tempo) {
            let dribblers = mates.filter { $0.detail == .winger || $0.detail == .attackingMid || ($0.detail == .striker && random.chance(0.3)) }
            let defenders = rivals.filter { $0.position == .defender || $0.position == .midfielder }
            if let dribbler = random.pick(dribblers), let marker = random.pick(defenders) {
                let skill = Double(dribbler.attributes[.dribbling] + dribbler.attributes[.pace]) / 2
                let marking = Double(marker.attributes[.marking] + marker.attributes[.tackling]) / 2
                let wins = random.chance(min(0.8, max(0.25, 0.5 + (skill - marking) * 0.03)))
                if wins {
                    let lines = ["\(dribbler.name) dribla \(marker.name) e ganha espaço pela \(random.chance(0.5) ? "direita" : "esquerda").",
                                 "Drible desconcertante de \(dribbler.name) em cima de \(marker.name).",
                                 "\(dribbler.name) deixa \(marker.name) sentado e avança com a bola."]
                    events.append(MatchEvent(minute: minute, kind: .dribble, teamID: teamID, text: lines[random.int(in: 0...(lines.count - 1))],
                                             playerID: dribbler.id, relatedPlayerID: marker.id))
                } else {
                    self[side.other].stats[marker.id, default: PlayerMatchStats(playerID: marker.id)].tackles += 1
                    if random.chance(0.35) {
                        events.append(MatchEvent(minute: minute, kind: .tackle, teamID: rival.teamID,
                                                 text: "\(marker.name) lê o drible de \(dribbler.name) e rouba a bola.",
                                                 playerID: marker.id, relatedPlayerID: dribbler.id))
                    }
                }
            }
        }

        // Cruzamento afastado pela defesa.
        if random.chance(0.05 * (0.6 + share) * flavor.wide) {
            let crossers = mates.filter { $0.detail == .winger || $0.detail == .rightBack || $0.detail == .leftBack }
            let clearers = rivals.filter { $0.position == .defender }
            if let crosser = random.pick(crossers), let clearer = random.pick(clearers) {
                let lines = ["\(crosser.name) levanta na área, mas \(clearer.name) afasta de cabeça.",
                             "Cruzamento perigoso de \(crosser.name) e \(clearer.name) tira antes do atacante.",
                             "\(clearer.name) se antecipa e corta o cruzamento de \(crosser.name)."]
                events.append(MatchEvent(minute: minute, kind: .cross, teamID: teamID, text: lines[random.int(in: 0...(lines.count - 1))],
                                         playerID: crosser.id, relatedPlayerID: clearer.id))
            }
        }
    }
}
