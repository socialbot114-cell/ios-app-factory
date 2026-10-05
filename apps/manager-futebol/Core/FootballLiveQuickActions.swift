import Foundation

// MARK: - Planos rápidos de jogo

/// Atalho de um toque que muda estilo e instruções de uma vez durante a partida.
enum QuickTacticPreset: String, CaseIterable, Identifiable {
    case allOut, attack, press, balanced, counter, protect

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allOut: return "Tudo ao ataque"
        case .attack: return "Atacar"
        case .press: return "Pressionar"
        case .balanced: return "Equilibrar"
        case .counter: return "Contra-ataque"
        case .protect: return "Segurar"
        }
    }

    var systemImage: String {
        switch self {
        case .allOut: return "flame.fill"
        case .attack: return "arrow.up.forward.circle.fill"
        case .press: return "bolt.fill"
        case .balanced: return "equal.circle.fill"
        case .counter: return "arrow.triangle.swap"
        case .protect: return "shield.fill"
        }
    }

    var summary: String {
        switch self {
        case .allOut: return "Linha altíssima, ritmo e pressão no máximo. Ataca muito, cansa rápido e deixa espaço atrás."
        case .attack: return "Estilo ofensivo com linha alta e ritmo rápido."
        case .press: return "Pressão alta para roubar a bola cedo. Gasta mais fôlego e gera mais faltas."
        case .balanced: return "Volta ao plano neutro."
        case .counter: return "Linha baixa e saída rápida para explorar espaços."
        case .protect: return "Linha baixa, ritmo lento, pressão leve e cera para proteger o placar."
        }
    }

    var style: FootballPlayStyle {
        switch self {
        case .allOut, .attack: return .attacking
        case .press: return .highPress
        case .balanced: return .balanced
        case .counter: return .counter
        case .protect: return .defensive
        }
    }

    var instructions: TeamInstructions {
        var value = TeamInstructions()
        switch self {
        case .allOut:
            value.lineHeight = .high; value.tempo = .high; value.width = .high; value.pressing = .high
        case .attack:
            value.lineHeight = .high; value.tempo = .high
        case .press:
            value.lineHeight = .high; value.pressing = .high
        case .balanced:
            break
        case .counter:
            value.lineHeight = .low; value.tempo = .high
        case .protect:
            value.lineHeight = .low; value.tempo = .low; value.pressing = .low; value.timeWasting = true
        }
        return value
    }

    func isActive(on side: MatchSideState) -> Bool {
        side.style == style && side.instructions == instructions
    }
}

// MARK: - Trocas rápidas

enum QuickSubstitutionKind: String, CaseIterable, Identifiable {
    case tired, offensive, defensive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tired: return "Trocar cansado"
        case .offensive: return "Reforçar ataque"
        case .defensive: return "Reforçar defesa"
        }
    }

    var systemImage: String {
        switch self {
        case .tired: return "battery.25percent"
        case .offensive: return "figure.soccer"
        case .defensive: return "shield.lefthalf.filled"
        }
    }
}

extension FootballCareer {
    /// Aplica um plano rápido ao time do usuário e registra o lance no feed.
    @discardableResult
    mutating func liveApplyPreset(_ preset: QuickTacticPreset) -> Bool {
        guard var live = liveMatch, !live.sim.finished else { return false }
        let side: MatchTeamSide = live.userIsHome ? .home : .away
        guard !preset.isActive(on: live.sim[side]) else { return false }
        live.sim.setStyle(side: side, preset.style)
        live.sim.setInstructions(side: side, preset.instructions)
        let teamID = live.sim[side].teamID
        live.sim.events.append(MatchEvent(minute: live.sim.minute, kind: .tactic, teamID: teamID,
                                          text: "Plano rápido do \(FootballSeason.teamName(teamID)): \(preset.title.lowercased())."))
        liveMatch = live
        return true
    }

    /// Escolhe quem sai e quem entra para a troca rápida, sem executá-la.
    func liveQuickSubstitutionPlan(_ kind: QuickSubstitutionKind) -> (out: FootballPlayer, incoming: FootballPlayer)? {
        guard let live = liveMatch, !live.sim.finished else { return nil }
        let side = live.userSide
        let sideKey: MatchTeamSide = live.userIsHome ? .home : .away
        func condition(_ player: FootballPlayer) -> Double { side.matchCondition[player.id] ?? Double(player.condition) }
        let onPitch = side.onPitch.compactMap { player($0) }.filter { $0.position != .goalkeeper }
        let bench = side.bench.compactMap { player($0) }.filter { $0.position != .goalkeeper && $0.isAvailable(matchDay: -1) }

        let out: FootballPlayer?
        let pool: [FootballPlayer]
        switch kind {
        case .tired:
            out = onPitch.min { condition($0) < condition($1) }
            pool = out.map { target in bench.filter { $0.position == target.position } } ?? []
        case .offensive:
            out = onPitch.filter { $0.position != .forward }
                .min { ($0.position == .defender ? 1 : 0, condition($0)) < ($1.position == .defender ? 1 : 0, condition($1)) }
            pool = bench.filter { $0.position == .forward }
        case .defensive:
            out = onPitch.filter { $0.position != .defender }
                .min { ($0.position == .forward ? 0 : 1, condition($0)) < ($1.position == .forward ? 0 : 1, condition($1)) }
            pool = bench.filter { $0.position == .defender }
        }
        guard let out, let incoming = pool.max(by: { $0.effectiveOverall < $1.effectiveOverall }),
              live.sim.canSubstitute(side: sideKey, out: out.id, in: incoming.id) else { return nil }
        return (out, incoming)
    }

    @discardableResult
    mutating func liveQuickSubstitute(_ kind: QuickSubstitutionKind) -> Bool {
        guard let plan = liveQuickSubstitutionPlan(kind) else { return false }
        return substitute(outgoingID: plan.out.id, incomingID: plan.incoming.id)
    }
}
