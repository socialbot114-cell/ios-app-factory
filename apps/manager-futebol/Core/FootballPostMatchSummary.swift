import Foundation

// MARK: - Resumo pós-jogo com mudanças e causas (GES-04, TAC-05)

/// Uma mudança provocada pelo jogo e a causa registrada nos dados da partida.
struct SummaryChange: Codable, Equatable, Identifiable {
    var id: String { label }
    let label: String
    /// Variação numérica quando faz sentido (pontos, moral, reais).
    let delta: Int?
    let text: String
    let cause: String
}

struct PostMatchSummary: Codable, Equatable {
    var headline: String
    var changes: [SummaryChange]
    /// Só fatos que o motor registra: números, momentos e sequências. Nada de causalidade que o motor não mede.
    var evidence: [String]
    /// O que pede atenção antes do próximo jogo.
    var attention: [String]
}

/// Foto do estado antes do dia de jogo, para medir o que mudou.
struct PostMatchSnapshot: Equatable {
    var fanMood: Int
    var boardConfidence: Int
    var reputation: Int
    var hype: Int
    var cash: Int
    var morale: [Int: Int]
    var injured: Set<Int>
    var suspended: Set<Int>
}

extension FootballCareer {
    func capturePostMatchSnapshot() -> PostMatchSnapshot {
        let roster = clubRoster
        return PostMatchSnapshot(fanMood: fanMood, boardConfidence: boardConfidence, reputation: reputation, hype: clubHype, cash: transferBudget,
                                 morale: Dictionary(uniqueKeysWithValues: roster.map { ($0.id, $0.morale) }),
                                 injured: Set(roster.filter(\.isInjured).map(\.id)), suspended: Set(roster.filter(\.isSuspended).map(\.id)))
    }

    /// Monta o resumo comparando o estado de agora com a foto de antes. Só descreve o que os dados mostram.
    func buildPostMatchSummary(fixture: LeagueFixture, before: PostMatchSnapshot) -> PostMatchSummary? {
        guard let userID = selectedClubID, let result = fixture.result(for: userID) else { return nil }
        let isHome = fixture.home == userID
        let goalsFor = (isHome ? fixture.homeGoals : fixture.awayGoals) ?? 0
        let goalsAgainst = (isHome ? fixture.awayGoals : fixture.homeGoals) ?? 0
        let opponent = FootballSeason.teamName(fixture.opponent(of: userID))
        var changes: [SummaryChange] = []

        func add(_ label: String, _ delta: Int, _ text: String, _ cause: String) {
            guard delta != 0 else { return }
            changes.append(SummaryChange(label: label, delta: delta, text: text, cause: cause))
        }

        let resultText = result == .win ? "vitória" : (result == .draw ? "empate" : "derrota")
        let impact = fixture.impact
        let mainCause = "\(resultText.capitalized) por \(goalsFor) × \(goalsAgainst) contra o \(opponent)" + (impact.map { " (\($0.verdict.lowercased()))" } ?? "")
        add("Torcida", fanMood - before.fanMood, "Humor da torcida \(before.fanMood) → \(fanMood).", mainCause)
        add("Diretoria", boardConfidence - before.boardConfidence, "Confiança da diretoria \(before.boardConfidence) → \(boardConfidence).",
            FootballSeason.isDerby(fixture.home, fixture.away) ? "\(mainCause); clássico pesa mais." : mainCause)
        add("Embalo", clubHype - before.hype, "Embalo da torcida \(before.hype) → \(clubHype).", impact?.highlights.first ?? mainCause)
        add("Reputação", reputation - before.reputation, "Reputação \(before.reputation) → \(reputation).", impact?.highlights.first ?? mainCause)

        // Caixa: o que entrou e saiu neste dia de jogo, por categoria.
        let entries = finance.entries.filter { $0.season == season && $0.matchDay == matchDayIndex }
        if !entries.isEmpty {
            let byCategory = Dictionary(grouping: entries, by: \.category).mapValues { $0.reduce(0) { $0 + $1.amount } }
            let top = byCategory.sorted { abs($0.value) != abs($1.value) ? abs($0.value) > abs($1.value) : $0.key.rawValue < $1.key.rawValue }.prefix(3)
            let parts = top.map { "\($0.key.title) \(FootballFormat.money($0.value))" }
            add("Caixa", transferBudget - before.cash, "Caixa \(FootballFormat.money(before.cash)) → \(FootballFormat.money(transferBudget)).", parts.joined(separator: " · "))
        }

        // Elenco: quem mais mudou de moral e por quê.
        let roster = clubRoster
        let moraleShifts = roster.compactMap { athlete -> (FootballPlayer, Int)? in
            guard let old = before.morale[athlete.id] else { return nil }
            let delta = athlete.morale - old
            return abs(delta) >= 4 ? (athlete, delta) : nil
        }.sorted { abs($0.1) != abs($1.1) ? abs($0.1) > abs($1.1) : $0.0.id < $1.0.id }.prefix(3)
        for (athlete, delta) in moraleShifts {
            let stat = fixture.userStats.first { $0.playerID == athlete.id }
            var cause: String
            if let stat, stat.minutes > 0 {
                cause = "Jogou \(stat.minutes) min, nota \(String(format: "%.1f", stat.rating))"
                if stat.goals > 0 { cause += ", \(stat.goals) gol(s)" }
            } else {
                cause = "Não entrou em campo (\(athlete.benchStreak) jogo(s) seguidos no banco)"
            }
            changes.append(SummaryChange(label: athlete.name, delta: delta, text: "Moral de \(athlete.name) \(delta > 0 ? "+" : "")\(delta).", cause: cause))
        }

        // Lesões e suspensões novas.
        for athlete in roster where athlete.isInjured && !before.injured.contains(athlete.id) {
            changes.append(SummaryChange(label: "Lesão: \(athlete.name)", delta: nil, text: "\(athlete.name) está fora por \(athlete.injuryRounds) jogo(s).",
                                         cause: fixture.events.first { $0.kind == .injury && $0.playerID == athlete.id }.map { "Saiu machucado aos \($0.minute)′." } ?? "Lesão registrada no jogo."))
        }
        for athlete in roster where athlete.isSuspended && !before.suspended.contains(athlete.id) {
            changes.append(SummaryChange(label: "Suspensão: \(athlete.name)", delta: nil, text: "\(athlete.name) cumpre \(athlete.discipline.suspensionGames) jogo(s) de suspensão.",
                                         cause: "Cartões recebidos nesta partida."))
        }

        // Evidências: apenas números e sequências do motor.
        var evidence: [String] = []
        if let homeShots = fixture.homeShots, let awayShots = fixture.awayShots, let homeTarget = fixture.homeOnTarget, let awayTarget = fixture.awayOnTarget {
            let ownShots = isHome ? homeShots : awayShots, otherShots = isHome ? awayShots : homeShots
            let ownTarget = isHome ? homeTarget : awayTarget, otherTarget = isHome ? awayTarget : homeTarget
            evidence.append("Finalizações \(ownShots) × \(otherShots) (no alvo \(ownTarget) × \(otherTarget)).")
        }
        if let homeXG = fixture.homeExpectedGoals, let awayXG = fixture.awayExpectedGoals {
            evidence.append("Gols esperados (xG) \(FootballFormat.expectedGoals(isHome ? homeXG : awayXG)) × \(FootballFormat.expectedGoals(isHome ? awayXG : homeXG)).")
        }
        if let homePossession = fixture.homePossession, let awayPossession = fixture.awayPossession {
            evidence.append("Posse de bola \(isHome ? homePossession : awayPossession)% × \(isHome ? awayPossession : homePossession)%.")
        }
        let ownReds = (isHome ? fixture.homeRed : fixture.awayRed) ?? 0
        let rivalReds = (isHome ? fixture.awayRed : fixture.homeRed) ?? 0
        if ownReds + rivalReds > 0 { evidence.append("Expulsões: \(ownReds) do seu time, \(rivalReds) do rival.") }
        let tactics = fixture.events.filter { $0.kind == .tactic }
        let subs = fixture.events.filter { $0.kind == .substitution }
        if !tactics.isEmpty {
            let minutes = tactics.map { "\($0.minute)′" }.joined(separator: ", ")
            let goalsAfter = fixture.events.filter { $0.kind == .goal && ($0.minute >= (tactics.first?.minute ?? 999)) }
            let own = goalsAfter.filter { $0.teamID == userID }.count
            evidence.append("Mudanças táticas aos \(minutes). Depois da primeira, saíram \(own) gol(s) seus e \(goalsAfter.count - own) do rival. É uma sequência, não prova de causa.")
        }
        if !subs.isEmpty { evidence.append("Substituições aos \(subs.map { "\($0.minute)′" }.joined(separator: ", ")).") }
        let momentum = fixture.momentum
        if !momentum.isEmpty {
            let split = momentum.count / 2
            let first = momentum.prefix(split).reduce(0, +) / max(1, split)
            let second = momentum.suffix(momentum.count - split).reduce(0, +) / max(1, momentum.count - split)
            let ownFirst = isHome ? first : -first, ownSecond = isHome ? second : -second
            evidence.append("Pressão média: 1º tempo \(ownFirst >= 0 ? "+" : "")\(ownFirst), 2º tempo \(ownSecond >= 0 ? "+" : "")\(ownSecond) (positivo favorece o seu time).")
        }

        // Atenção: o que vence ou pede decisão antes do próximo jogo.
        var attention: [String] = agenda.prefix(3).map { "\($0.title): \($0.deadlineText)" }
        if pendingPress != nil { attention.append("Coletiva de imprensa aguardando resposta.") }
        let missing = starters.filter { !$0.isAvailable(matchDay: matchDayIndex) }
        if !missing.isEmpty { attention.append("Titulares indisponíveis: \(missing.prefix(3).map(\.name).joined(separator: ", ")).") }

        let headline = "\(resultText.capitalized) por \(goalsFor) × \(goalsAgainst) contra o \(opponent)" + (impact.map { ". \($0.verdict)." } ?? ".")
        return PostMatchSummary(headline: headline, changes: changes, evidence: evidence, attention: attention)
    }
}
