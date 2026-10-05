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
        // Cada traço normalizado pela própria amplitude (−1…1) para nenhum dominar o título.
        let traits: [(Double, String)] = [
            ((tempo - 1) / 0.08, "Jogo aberto e rápido"),
            ((1 - tempo) / 0.08, "Jogo truncado e estudado"),
            ((strictness - 1) / 0.15, "Jogo físico e faltoso"),
            ((aerial - 1) / 0.2, "Jogo de bolas aéreas"),
            ((wide - 1) / 0.2, "Jogo pelas pontas")
        ]
        let strongest = traits.max { $0.0 < $1.0 }
        title = strongest.map { $0.0 >= 0.45 ? $0.1 : "Jogo equilibrado" } ?? "Jogo equilibrado"
    }

    /// Frase do narrador na saída de bola.
    var preview: String {
        switch title {
        case "Jogo aberto e rápido": return "Os dois times prometem um jogo de ritmo alto."
        case "Jogo truncado e estudado": return "Expectativa de um jogo travado, de muita cautela."
        case "Jogo físico e faltoso": return "O árbitro promete ser rigoroso nas divididas."
        case "Jogo de bolas aéreas": return "Muita bola na área deve decidir este jogo."
        case "Jogo pelas pontas": return "Os pontas devem ser os protagonistas da partida."
        default: return "Duelo equilibrado no papel."
        }
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
    /// Narra no máximo um lance por minuto e nunca por cima de gol, chance, cartão ou lesão.
    mutating func actionPhase(side: MatchTeamSide, flavor: MatchFlavor, players: [Int: FootballPlayer]) {
        var random = FootballRandom(seed: Self.mix(seed, UInt64(minute), side == .home ? 0xA1 : 0xA2))
        let state = self[side]
        let rival = self[side.other]
        let mates = state.onPitch.compactMap { players[$0] }.filter { $0.position != .goalkeeper }
        let rivals = rival.onPitch.compactMap { players[$0] }.filter { $0.position != .goalkeeper }
        guard !mates.isEmpty, !rivals.isEmpty else { return }
        let share = side == .home ? possessionShare : 1 - possessionShare
        let teamID = state.teamID
        let teamName = FootballSeason.teamName(teamID)
        var canNarrate = !events.contains { $0.minute == minute && $0.kind != .tactic && $0.kind != .substitution }

        func narrate(_ kind: MatchEvent.Kind, team: Int, _ lines: [String], player: Int, related: Int?, odds: Double) {
            guard canNarrate, random.chance(odds), let text = random.pick(lines) else { return }
            events.append(MatchEvent(minute: minute, kind: kind, teamID: team, text: text, playerID: player, relatedPlayerID: related))
            canNarrate = false
        }

        func weighted(_ pool: [FootballPlayer], _ weight: (FootballPlayer) -> Double) -> FootballPlayer? {
            guard let index = random.weightedIndex(pool.map { max(1, Int(weight($0) * 10)) }) else { return nil }
            return pool[index]
        }

        // Impedimento: atacantes velozes contra linha alta caem mais na armadilha.
        let offsideChance = 0.03 * (0.6 + share) * flavor.tempo * (state.style == .counter ? 1.4 : 1) * (rival.instructions.lineHeight == .high ? 1.6 : 1)
        if random.chance(offsideChance),
           let runner = weighted(mates.filter { $0.position == .forward || $0.detail == .attackingMid || $0.detail == .winger }, {
               Double($0.attributes[.pace] + 4) * ($0.detail == .striker ? 1.6 : 1) * (state.roles[$0.id] == .poacher ? 1.3 : 1)
           }) {
            narrate(.offside, team: teamID, [
                "A bandeira sobe: \(runner.name) estava impedido.",
                "\(runner.name) parte na frente da zaga, mas o assistente marca impedimento.",
                "Impedimento de \(runner.name) anula a jogada do \(teamName).",
                "A linha do rival sobe na hora certa e deixa \(runner.name) em impedimento."
            ], player: runner.id, related: nil, odds: 0.6)
        }

        // Desarme: o time sem a bola recupera a posse; volantes destruidores aparecem mais.
        if random.chance(0.11 * (1.6 - share) * (state.instructions.pressing == .high ? 1.2 : 1)),
           let tackler = weighted(mates, { player in
               let base = player.position == .forward ? 1.0 : 3.0
               return base * Double(player.attributes[.tackling] + 3) * (state.roles[player.id] == .destroyer ? 1.4 : 1)
           }),
           let victim = weighted(rivals, { $0.position == .defender ? 0.6 : 1.0 }) {
            self[side].stats[tackler.id, default: PlayerMatchStats(playerID: tackler.id)].tackles += 1
            narrate(.tackle, team: teamID, [
                "\(tackler.name) chega firme e desarma \(victim.name).",
                "Bela recuperação de \(tackler.name), que tira a bola de \(victim.name).",
                "\(tackler.name) corta o avanço de \(victim.name) no tempo certo.",
                "Carrinho limpo de \(tackler.name) em \(victim.name), e a torcida aplaude."
            ], player: tackler.id, related: victim.id, odds: 0.18)
        }

        // Drible: duelo de habilidade contra marcação; quem perde entrega um desarme ao rival.
        if random.chance(0.05 * (0.6 + share) * flavor.tempo),
           let dribbler = weighted(mates.filter { $0.position != .defender || state.roles[$0.id] == .fullbackAttacking }, {
               let role = state.roles[$0.id]
               let detail = $0.detail == .winger || $0.detail == .attackingMid ? 2.0 : 0.7
               return detail * Double($0.attributes[.dribbling] + 2) * (role == .dribblingWinger ? 1.5 : 1)
           }),
           let marker = weighted(rivals.filter { $0.position != .forward }, { Double($0.attributes[.marking] + 2) }) {
            let skill = Double(dribbler.attributes[.dribbling] + dribbler.attributes[.pace]) / 2
            let marking = Double(marker.attributes[.marking] + marker.attributes[.tackling]) / 2
            if random.chance(min(0.8, max(0.25, 0.5 + (skill - marking) * 0.03))) {
                let flank = Self.flank(of: dribbler)
                narrate(.dribble, team: teamID, [
                    "\(dribbler.name) dribla \(marker.name) e ganha espaço pela \(flank).",
                    "Drible desconcertante de \(dribbler.name) em cima de \(marker.name).",
                    "\(dribbler.name) deixa \(marker.name) para trás e avança com a bola.",
                    "Caneta de \(dribbler.name) em \(marker.name)! A torcida vai ao delírio."
                ], player: dribbler.id, related: marker.id, odds: 0.5)
            } else {
                self[side.other].stats[marker.id, default: PlayerMatchStats(playerID: marker.id)].tackles += 1
                narrate(.tackle, team: rival.teamID, [
                    "\(marker.name) lê o drible de \(dribbler.name) e rouba a bola.",
                    "\(dribbler.name) tenta o drible, mas \(marker.name) não cai na finta."
                ], player: marker.id, related: dribbler.id, odds: 0.3)
            }
        }

        // Cruzamento afastado: quem cruza vem das pontas, quem corta é o zagueiro bom de cabeça.
        if random.chance(0.045 * (0.6 + share) * flavor.wide * (state.instructions.width == .high ? 1.3 : 1)),
           let crosser = weighted(mates.filter { $0.detail == .winger || $0.detail == .rightBack || $0.detail == .leftBack }, {
               Double($0.attributes[.passing] + 2) * (state.roles[$0.id] == .fullbackAttacking ? 1.4 : 1)
           }),
           let clearer = weighted(rivals.filter { $0.position == .defender }, { Double($0.attributes[.heading] + 2) }) {
            let flank = Self.flank(of: crosser)
            narrate(.cross, team: teamID, [
                "\(crosser.name) levanta da \(flank), mas \(clearer.name) afasta de cabeça.",
                "Cruzamento perigoso de \(crosser.name) e \(clearer.name) tira antes do atacante.",
                "\(clearer.name) se antecipa e corta o cruzamento de \(crosser.name).",
                "\(crosser.name) cruza rasteiro pela \(flank) e \(clearer.name) afasta o perigo."
            ], player: crosser.id, related: clearer.id, odds: 0.4)
        }
    }

    /// Lado do campo em que o atleta costuma atuar.
    static func flank(of player: FootballPlayer) -> String {
        switch player.detail {
        case .rightBack: return "direita"
        case .leftBack: return "esquerda"
        default: return player.id % 2 == 0 ? "direita" : "esquerda"
        }
    }
}
