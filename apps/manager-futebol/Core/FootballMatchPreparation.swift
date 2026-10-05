import Foundation

// MARK: - Comparativo com o rival (TAC-02) e rotação ligada ao calendário e às promessas (TAC-03)

/// Uma ameaça do rival e o quanto ela foi de fato observada.
struct RivalThreat: Equatable, Identifiable {
    let id: String
    let title: String
    let detail: String
    /// Observada pelos olheiros (conhecimento ≥ 50) ou só estimada.
    let observed: Bool
}

struct MatchupReport: Equatable {
    let opponentID: Int
    let isHome: Bool
    let ownFitness: Int
    let rivalFitness: Int
    let ownRoles: [String]
    let rivalKeyPlayers: [String]
    let rivalStyle: FootballPlayStyle?
    let threats: [RivalThreat]
    let suggestions: [String]
}

/// Situação de um titular nos próximos jogos.
struct RotationRow: Equatable, Identifiable {
    let playerID: Int
    let name: String
    let condition: Int
    /// Condição estimada se jogar todos os próximos jogos.
    let projectedCondition: Int
    /// Titularidades que ainda faltam para cumprir uma promessa, e até quando.
    let promisedStartsLeft: Int
    let promiseDeadlineMatchDay: Int?
    let advice: String

    var id: Int { playerID }
}

struct RotationPlan: Equatable {
    let upcoming: [LeagueFixture]
    let rows: [RotationRow]
    let suggestedFocus: FootballTrainingFocus
    let reasons: [String]
}

extension FootballCareer {
    /// Desgaste estimado por jogo e recuperação por dia sem jogar (os mesmos números do motor, em média).
    static let fatiguePerMatch = 14
    static let recoveryPerRestDay = 6

    var nextUserFixtureForPrep: LeagueFixture? { nextUserFixture }

    // MARK: TAC-02

    func matchupReport() -> MatchupReport? {
        guard let clubID = selectedClubID, let fixture = nextUserFixture else { return nil }
        let rivalID = fixture.home == clubID ? fixture.away : fixture.home
        let own = starters
        let rivalSquad = players(forTeam: rivalID).filter { !$0.isYouth }
        let rivalXI = Array(rivalSquad.sorted { $0.overall > $1.overall }.prefix(11))
        func avgCondition(_ list: [FootballPlayer]) -> Int { list.isEmpty ? 0 : list.reduce(0) { $0 + $1.condition } / list.count }

        let roles = own.compactMap { player in playerRoles[player.id].map { "\(player.name): \($0.title)" } }
        let keys = rivalXI.prefix(3).map { "\($0.name) (\($0.detail.rawValue))" }
        let style: FootballPlayStyle? = opponentPrep ? scoutedOpponentStyle(for: fixture).style : nil

        var threats: [RivalThreat] = []
        if let scorer = rivalSquad.max(by: { $0.goals < $1.goals }), scorer.goals > 0 {
            threats.append(RivalThreat(id: "scorer", title: "Artilheiro: \(scorer.name)", detail: "\(scorer.goals) gol(s) na temporada.",
                                       observed: scoutKnowledge(of: scorer.id) >= 50))
        }
        let attackers = rivalXI.filter { $0.position == .forward }
        if !attackers.isEmpty {
            let pace = attackers.reduce(0) { $0 + $1.attributes[.pace] } / attackers.count
            let ownDefense = own.filter { $0.position == .defender }
            let ownPace = ownDefense.isEmpty ? pace : ownDefense.reduce(0) { $0 + $1.attributes[.pace] } / ownDefense.count
            if pace >= ownPace + 2 {
                threats.append(RivalThreat(id: "pace", title: "Ataque mais rápido que a sua zaga",
                                           detail: "Velocidade média \(pace) contra \(ownPace) dos seus defensores.",
                                           observed: attackers.contains { scoutKnowledge(of: $0.id) >= 50 }))
            }
        }
        let aerial = rivalXI.filter { $0.position != .goalkeeper }.map { $0.attributes[.heading] }.sorted(by: >).prefix(4)
        if !aerial.isEmpty, aerial.reduce(0, +) / aerial.count >= 14 {
            threats.append(RivalThreat(id: "aerial", title: "Forte na bola aérea",
                                       detail: "Os 4 melhores cabeceadores têm média \(aerial.reduce(0, +) / aerial.count).", observed: true))
        }
        if let specialist = rivalXI.first(where: { $0.has(.setPieceSpecialist) }) {
            threats.append(RivalThreat(id: "setpiece", title: "Especialista em bola parada: \(specialist.name)",
                                       detail: "Evite faltas perto da área.", observed: scoutKnowledge(of: specialist.id) >= 50))
        }

        let ownFitness = avgCondition(own)
        let rivalFitness = avgCondition(rivalXI)
        var suggestions: [String] = []
        if ownFitness + 5 < rivalFitness { suggestions.append("Seu time chega mais cansado: rode quem está abaixo de 70 de condição.") }
        if threats.contains(where: { $0.id == "pace" }) { suggestions.append("Contra ataque veloz, prefira linha mais baixa.") }
        if threats.contains(where: { $0.id == "aerial" }) { suggestions.append("Rival forte no alto: treino de bola parada e zagueiros bons de cabeça.") }
        if style == nil { suggestions.append("Ative a preparação para o rival para conhecer o estilo de jogo dele.") }
        if !threats.contains(where: \.observed) && !threats.isEmpty { suggestions.append("As ameaças são estimativas: mande olheiros para confirmar.") }

        return MatchupReport(opponentID: rivalID, isHome: fixture.home == clubID, ownFitness: ownFitness, rivalFitness: rivalFitness,
                             ownRoles: roles, rivalKeyPlayers: keys, rivalStyle: style, threats: threats, suggestions: suggestions)
    }

    // MARK: TAC-03

    /// Próximos jogos do clube, desgaste dos titulares e promessas de titularidade que vencem no caminho.
    func rotationPlan(games: Int = 3) -> RotationPlan? {
        guard let clubID = selectedClubID else { return nil }
        let upcoming = Array(fixtures.filter { $0.involves(clubID) && !$0.isPlayed && $0.matchDay >= matchDayIndex }
            .sorted { $0.matchDay < $1.matchDay }.prefix(games))
        guard let last = upcoming.last else { return nil }
        let span = max(1, last.matchDay - matchDayIndex + 1)
        let restDays = max(0, span - upcoming.count)
        var rows: [RotationRow] = []
        for player in starters {
            let projected = min(100, max(25, player.condition - Self.fatiguePerMatch * upcoming.count + Self.recoveryPerRestDay * restDays))
            let promise = promises.first { $0.playerID == player.id && $0.startsDone < $0.requiredStarts && $0.season == season }
            let left = promise.map { $0.requiredStarts - $0.startsDone } ?? 0
            let advice: String
            if projected < 60 { advice = "Poupe em um dos próximos \(upcoming.count) jogos." }
            else if player.condition < 70 { advice = "Chega cansado ao próximo jogo." }
            else { advice = "Aguenta a sequência." }
            rows.append(RotationRow(playerID: player.id, name: player.name, condition: player.condition, projectedCondition: projected,
                                    promisedStartsLeft: left, promiseDeadlineMatchDay: promise?.deadlineMatchDay, advice: advice))
        }
        // Reservas com promessa precisam entrar antes do prazo.
        for promise in promises where promise.startsDone < promise.requiredStarts && promise.season == season && !starters.contains(where: { $0.id == promise.playerID }) {
            guard let athlete = player(promise.playerID), athlete.teamID == clubID else { continue }
            let gamesBefore = upcoming.filter { $0.matchDay <= promise.deadlineMatchDay }.count
            let left = promise.requiredStarts - promise.startsDone
            rows.append(RotationRow(playerID: athlete.id, name: athlete.name, condition: athlete.condition, projectedCondition: athlete.condition,
                                    promisedStartsLeft: left, promiseDeadlineMatchDay: promise.deadlineMatchDay,
                                    advice: gamesBefore >= left ? "Escale em \(left) dos próximos \(gamesBefore) jogos para cumprir a promessa."
                                                                 : "Só restam \(gamesBefore) jogo(s) antes do prazo: a promessa corre risco."))
        }
        let tired = rows.filter { $0.projectedCondition < 60 }.count
        let derby = upcoming.contains { FootballSeason.isDerby($0.home, $0.away) }
        var reasons: [String] = ["\(upcoming.count) jogo(s) em \(span) dia(s) de calendário."]
        let focus: FootballTrainingFocus
        if tired >= 3 {
            focus = .recovery
            reasons.append("\(tired) titular(es) chegariam abaixo de 60 de condição: priorize recuperação.")
        } else if derby {
            focus = .tactical
            reasons.append("Clássico no caminho: treino tático.")
        } else {
            focus = trainingFocus
            reasons.append("Calendário tranquilo: mantenha o foco atual.")
        }
        if rows.contains(where: { $0.promisedStartsLeft > 0 }) { reasons.append("Há promessas de titularidade a cumprir nesta sequência.") }
        return RotationPlan(upcoming: upcoming, rows: rows.sorted { $0.projectedCondition < $1.projectedCondition }, suggestedFocus: focus, reasons: reasons)
    }
}
