import Foundation

// MARK: - Conversa de vestiário no intervalo

enum HalftimeTalk: String, Codable, CaseIterable, Identifiable {
    case praise, demand, calm, allIn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .praise: return "Elogiar"
        case .demand: return "Cobrar"
        case .calm: return "Acalmar"
        case .allIn: return "Tudo ou nada"
        }
    }

    var summary: String {
        switch self {
        case .praise: return "Reforça a confiança do grupo. Bom quando o jogo está encaminhado ou equilibrado."
        case .demand: return "Aumenta a intensidade, mas pesa na moral. Funciona quando o time perde."
        case .calm: return "Fecha a casa e protege o resultado. Bom para quem está ganhando."
        case .allIn: return "Ataque total: muito mais gols a favor e muito mais risco atrás."
        }
    }

    var symbol: String {
        switch self {
        case .praise: return "hand.thumbsup.fill"
        case .demand: return "flame.fill"
        case .calm: return "shield.lefthalf.filled"
        case .allIn: return "bolt.fill"
        }
    }

    /// Ajustes pequenos e limitados para o 2º tempo: pontos de ataque e defesa e variação de moral.
    func effect(goalDifference: Int) -> (attack: Double, defense: Double, morale: Int) {
        switch self {
        case .praise:
            return goalDifference < 0 ? (0.2, 0.2, 3) : (0.4, 0.4, 3)
        case .demand:
            if goalDifference < 0 { return (1.0, -0.3, -2) }
            if goalDifference == 0 { return (0.5, -0.2, -2) }
            return (-0.2, 0, -3)
        case .calm:
            if goalDifference > 0 { return (-0.3, 0.9, 2) }
            if goalDifference == 0 { return (0, 0.4, 1) }
            return (-0.8, 0.3, 1)
        case .allIn:
            return (goalDifference < 0 ? 1.8 : 1.5, -1.5, 0)
        }
    }
}

extension LiveMatchState {
    var userGoalDifference: Int { userIsHome ? homeGoals - awayGoals : awayGoals - homeGoals }
}

extension FootballCareer {
    /// A conversa só acontece uma vez, exatamente no intervalo.
    var canHoldHalftimeTalk: Bool {
        guard let live = liveMatch else { return false }
        return live.sim.minute == 45 && !live.sim.finished && live.halftimeTalk == nil
    }

    func recommendedHalftimeTalk() -> HalftimeTalk? {
        guard let live = liveMatch else { return nil }
        let difference = live.userGoalDifference
        if difference < 0 { return .demand }
        if difference > 0 { return .calm }
        return .praise
    }

    /// Aplica a conversa e devolve a reação do vestiário.
    @discardableResult
    mutating func holdHalftimeTalk(_ talk: HalftimeTalk) -> String? {
        guard canHoldHalftimeTalk, var live = liveMatch else { return nil }
        let side: MatchTeamSide = live.userIsHome ? .home : .away
        let effect = talk.effect(goalDifference: live.userGoalDifference)
        live.sim[side].attackBoost += effect.attack
        live.sim[side].defenseBoost += effect.defense
        live.sim.needsRecompute = true
        let onPitch = live.sim[side].onPitch
        for index in players.indices where onPitch.contains(players[index].id) {
            players[index].morale = max(0, min(100, players[index].morale + effect.morale))
        }
        let reaction: String
        if talk == recommendedHalftimeTalk() {
            reaction = "O vestiário entendeu o recado e volta focado para o segundo tempo."
        } else if talk == .allIn {
            reaction = "O time volta ligado no 220, mas a defesa vai ficar exposta."
        } else {
            reaction = "O grupo ouve em silêncio. Vamos ver como reage em campo."
        }
        live.sim.events.append(MatchEvent(minute: 45, kind: .tactic, teamID: live.sim[side].teamID,
                                          text: "Conversa no vestiário (\(talk.title.lowercased())): \(reaction)"))
        live.halftimeTalk = talk.rawValue
        liveMatch = live
        bump("halftime")
        return reaction
    }
}

// MARK: - Resumo de fim de jogo

struct FullTimeDigest: Equatable {
    var goalLines: [String] = []
    var starLine: String?
    var cardsLine: String?
    var possessionUser = 50
    var shotsUser = 0
    var shotsRival = 0
}

extension FootballCareer {
    /// Os destaques do jogo que acabou, lidos da simulação ao vivo, antes de concluir a rodada.
    func fullTimeDigest() -> FullTimeDigest? {
        guard let live = liveMatch else { return nil }
        let userSide: MatchTeamSide = live.userIsHome ? .home : .away
        let user = live.sim[userSide]
        let rival = live.sim[userSide.other]
        var digest = FullTimeDigest()
        for event in live.sim.events where event.kind == .goal {
            let name = event.playerID.flatMap { player($0)?.name } ?? "Gol"
            let team = event.teamID.map { FootballSeason.team($0)?.shortName ?? "" } ?? ""
            digest.goalLines.append("\(event.minuteLabel) \(name) (\(team))")
        }
        let best = user.stats.values.max { lhs, rhs in Self.contribution(lhs) < Self.contribution(rhs) }
        if let best, Self.contribution(best) > 0, let athlete = player(best.playerID) {
            var parts: [String] = []
            if best.goals > 0 { parts.append("\(best.goals) gol(s)") }
            if best.assists > 0 { parts.append("\(best.assists) assistência(s)") }
            if best.saves > 0 { parts.append("\(best.saves) defesa(s)") }
            if best.tackles > 0 { parts.append("\(best.tackles) desarme(s)") }
            if parts.isEmpty { parts.append("\(best.shotsOnTarget) chute(s) no alvo") }
            digest.starLine = "\(athlete.name) · \(parts.joined(separator: ", "))"
        }
        if user.yellowCards + user.redCards > 0 {
            digest.cardsLine = "\(user.yellowCards) amarelo(s), \(user.redCards) vermelho(s) no seu time"
        }
        let total = user.possessionAccumulator + rival.possessionAccumulator
        digest.possessionUser = total > 0 ? Int((user.possessionAccumulator / total * 100).rounded()) : 50
        digest.shotsUser = user.shots
        digest.shotsRival = rival.shots
        return digest
    }

    private static func contribution(_ stats: PlayerMatchStats) -> Double {
        Double(stats.goals) * 3 + Double(stats.assists) * 2 + Double(stats.saves) * 0.5
            + Double(stats.tackles) * 0.25 + Double(stats.shotsOnTarget) * 0.3
    }
}

extension FootballCareer {
    /// Há uma disputa de pênaltis para mostrar e ela ainda não foi revelada.
    var canRevealShootout: Bool {
        guard let live = liveMatch else { return false }
        return live.sim.finished && live.sim.needsShootout && !live.sim.events.contains { $0.kind == .penalties }
    }

    mutating func revealLiveShootout() {
        guard canRevealShootout, var live = liveMatch else { return }
        live.sim.revealShootout(players: playersByID())
        liveMatch = live
    }
}
