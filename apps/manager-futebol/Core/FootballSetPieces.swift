import Foundation

// MARK: - Bolas paradas com efeito no motor (TAC-04)

enum CornerRoutine: String, Codable, CaseIterable, Identifiable {
    case nearPost, farPost, short
    var id: String { rawValue }
    var title: String {
        switch self {
        case .nearPost: return "Primeiro pau"
        case .farPost: return "Segundo pau"
        case .short: return "Escanteio curto"
        }
    }
    var summary: String {
        switch self {
        case .nearPost: return "Bola rápida no primeiro pau para os atacantes desviarem."
        case .farPost: return "Bola alta no segundo pau para os zagueiros cabecearem."
        case .short: return "Toque curto e finalização dos meias na entrada da área."
        }
    }
}

enum FreeKickRoutine: String, Codable, CaseIterable, Identifiable {
    case direct, cross
    var id: String { rawValue }
    var title: String { self == .direct ? "Chute direto" : "Cruzamento na área" }
    var summary: String {
        self == .direct ? "O cobrador bate direto no gol." : "A falta vira cruzamento para os bons de cabeça."
    }
}

/// Rotina escolhida na Tática. Na partida, carrega também o encaixe com o elenco (calculado fora do motor).
struct SetPieceRoutine: Codable, Equatable {
    var corner: CornerRoutine = .farPost
    var freeKick: FreeKickRoutine = .cross
    var cornerTakerID: Int? = nil
    var freeKickTakerID: Int? = nil
    /// Fatores de xG da partida (0,9 a 1,12), definidos ao montar o time.
    var cornerFit = 1.0
    var freeKickFit = 1.0

    /// Peso extra na escolha de quem finaliza a jogada de bola parada.
    func shooterWeight(_ player: FootballPlayer, buildUp: BuildUp) -> Double {
        switch buildUp {
        case .cornerKick:
            if player.id == cornerTakerID { return 0.2 }
            switch corner {
            case .nearPost: return player.position == .forward ? 1.6 : (player.position == .defender ? 0.7 : 1.0)
            case .farPost: return player.position == .defender ? 1.8 : (player.position == .forward ? 0.9 : 0.8)
            case .short: return player.position == .midfielder ? 1.7 : (player.position == .defender ? 0.6 : 0.9)
            }
        case .freeKick:
            switch freeKick {
            case .direct: return player.id == freeKickTakerID ? 6.0 : 0.8
            case .cross: return player.id == freeKickTakerID ? 0.2 : (player.position == .defender ? 1.3 : 1.0)
            }
        default:
            return 1
        }
    }

    /// Peso extra na escolha do autor do passe: o cobrador designado.
    func assistWeight(_ player: FootballPlayer, buildUp: BuildUp) -> Double {
        switch buildUp {
        case .cornerKick: return player.id == cornerTakerID ? 20 : 1
        case .freeKick: return freeKick == .cross && player.id == freeKickTakerID ? 20 : 1
        default: return 1
        }
    }

    func xgFactor(for buildUp: BuildUp) -> Double {
        switch buildUp {
        case .cornerKick: return cornerFit
        case .freeKick: return freeKickFit
        default: return 1
        }
    }
}

extension FootballCareer {
    var setPieceRoutine: SetPieceRoutine { world.projects.setPieces ?? SetPieceRoutine() }

    mutating func setSetPieceRoutine(_ routine: SetPieceRoutine) {
        var stored = routine
        stored.cornerFit = 1
        stored.freeKickFit = 1
        world.projects.setPieces = stored
    }

    /// Nota de 0 a 20 de como o elenco escalado executa cada rotina.
    func setPieceScores(lineup: [FootballPlayer]) -> (corner: [CornerRoutine: Double], freeKick: [FreeKickRoutine: Double]) {
        func average(_ list: [Int]) -> Double { list.isEmpty ? 8 : Double(list.reduce(0, +)) / Double(list.count) }
        let forwards = lineup.filter { $0.position == .forward }
        let defenders = lineup.filter { $0.position == .defender }
        let midfielders = lineup.filter { $0.position == .midfielder }
        let headers = lineup.filter { $0.position != .goalkeeper }.map { $0.attributes[.heading] }.sorted(by: >).prefix(3)
        let routine = setPieceRoutine
        let freeTaker = lineup.first { $0.id == routine.freeKickTakerID }
        return (
            [.nearPost: average(forwards.map { ($0.attributes[.finishing] + $0.attributes[.pace]) / 2 }),
             .farPost: average(Array(headers)) * 0.6 + average(defenders.map { $0.attributes[.heading] }) * 0.4,
             .short: average(midfielders.map { ($0.attributes[.passing] + $0.attributes[.finishing]) / 2 })],
            [.direct: freeTaker.map { Double($0.attributes[.finishing] + $0.attributes[.passing]) / 2 + ($0.has(.setPieceSpecialist) ? 3 : 0) } ?? 7,
             .cross: average(Array(headers))]
        )
    }

    /// Encaixe da escolha entre as alternativas: a melhor para o elenco rende 1,12; a pior, 0,9.
    private static func fit<Key: Hashable>(_ chosen: Key, scores: [Key: Double]) -> Double {
        guard let value = scores[chosen], let low = scores.values.min(), let high = scores.values.max(), high > low else { return 1 }
        return 0.9 + 0.22 * (value - low) / (high - low)
    }

    /// Rotina pronta para a partida: cobradores só se estiverem escalados e encaixe calculado.
    func matchSetPieceRoutine(lineup ids: [Int]) -> SetPieceRoutine? {
        guard world.projects.setPieces != nil else { return nil }
        let lineup = ids.compactMap { player($0) }
        var routine = setPieceRoutine
        if let taker = routine.cornerTakerID, !ids.contains(taker) { routine.cornerTakerID = nil }
        if let taker = routine.freeKickTakerID, !ids.contains(taker) { routine.freeKickTakerID = nil }
        let scores = setPieceScores(lineup: lineup)
        routine.cornerFit = Self.fit(routine.corner, scores: scores.corner)
        routine.freeKickFit = Self.fit(routine.freeKick, scores: scores.freeKick)
        if let taker = lineup.first(where: { $0.id == routine.cornerTakerID }), taker.has(.setPieceSpecialist) {
            routine.cornerFit = min(1.12, routine.cornerFit + 0.03)
        }
        return routine
    }

    /// Explicação para a tela: qual rotina combina com o elenco atual.
    func setPieceAdvice() -> [String] {
        let scores = setPieceScores(lineup: starters)
        var lines: [String] = []
        if let best = scores.corner.max(by: { $0.value < $1.value })?.key {
            lines.append("Escanteio que mais combina com o time: \(best.title.lowercased()).")
        }
        if let best = scores.freeKick.max(by: { $0.value < $1.value })?.key {
            lines.append("Falta: \(best.title.lowercased()) rende mais com o elenco atual.")
        }
        if let routine = matchSetPieceRoutine(lineup: startingXI) {
            lines.append("Encaixe atual: escanteio \(Int((routine.cornerFit * 100).rounded()))%, falta \(Int((routine.freeKickFit * 100).rounded()))%.")
        }
        return lines
    }
}
