import Foundation

/// Dados públicos de um jogo para quem quer apostar (PAL-02): só o que qualquer torcedor vê.
struct FixtureBriefing: Equatable {
    struct Side: Equatable {
        let teamID: Int
        let form: [FootballResult]
        let absences: [String]
    }
    let home: Side
    let away: Side
    let headToHead: FootballLeagueAnalysis.HeadToHead
}

/// Perfil comparável de um palpiteiro (PAL-05).
struct TipsterProfile: Equatable, Identifiable {
    let id: Int
    let name: String
    let isUser: Bool
    let picks: Int
    let hits: Int
    let profit: Int
    var hitRate: Double? { picks == 0 ? nil : Double(hits) / Double(picks) }
}

extension FootballCareer {
    static let bettingRoleText = "Palpite+ é opcional: fichas fictícias, sem valor real, separadas do seu dinheiro pessoal e do caixa do clube. Nada na carreira exige apostar."
    static let tipsterPicksPerRound = 3

    // MARK: PAL-02

    func fixtureBriefing(_ fixture: LeagueFixture) -> FixtureBriefing {
        func side(_ teamID: Int) -> FixtureBriefing.Side {
            let form = standings(for: division(of: teamID)).first { $0.team.id == teamID }?.form ?? []
            let absent = players.filter { $0.teamID == teamID && ($0.isInjured || $0.isSuspended) }
                .sorted { $0.overall == $1.overall ? $0.id < $1.id : $0.overall > $1.overall }
                .prefix(3).map { "\($0.name) (\($0.isInjured ? "lesão" : "suspensão"))" }
            return .init(teamID: teamID, form: form, absences: Array(absent))
        }
        return FixtureBriefing(home: side(fixture.home), away: side(fixture.away),
                               headToHead: FootballLeagueAnalysis.headToHead(fixture.home, against: fixture.away, fixtures: fixtures))
    }

    // MARK: PAL-03

    /// Texto de fechamento: o mercado de um jogo fecha quando o dia de jogo é disputado.
    func bettingClosingText(for fixture: LeagueFixture) -> String {
        guard !fixture.isPlayed else { return "Mercado encerrado" }
        if fixture.matchDay == matchDayIndex { return "Fecha ao avançar o calendário (dia \(fixture.matchDay + 1))" }
        return fixture.matchDay < matchDayIndex ? "Mercado encerrado" : "Abre no dia \(fixture.matchDay + 1)"
    }

    mutating func saveBettingDraft(legs: [BetLeg], stake: Int) {
        world.betting.draft = legs.isEmpty ? nil : BetDraft(legs: legs, stake: stake)
    }

    /// Rascunho restaurado só com as seleções cujos mercados ainda estão abertos.
    func restoredBettingDraft() -> (draft: BetDraft?, dropped: Int) {
        guard let draft = world.betting.draft else { return (nil, 0) }
        let open = Set(bettingFixtures.map(\.id))
        let kept = draft.legs.filter { open.contains($0.fixtureID) }
        return (kept.isEmpty ? nil : BetDraft(legs: kept, stake: draft.stake), draft.legs.count - kept.count)
    }

    // MARK: PAL-04

    /// Explica a liquidação de uma seleção com o resultado real da partida da carreira.
    func settlementNote(for leg: BetLeg) -> String {
        guard let fixture = fixtures.first(where: { $0.id == leg.fixtureID }) else { return "Partida não encontrada." }
        guard let home = fixture.homeGoals, let away = fixture.awayGoals else { return "Aguardando o jogo." }
        let match = "\(FootballSeason.teamName(fixture.home)) \(home) × \(away) \(FootballSeason.teamName(fixture.away))"
        let verdict: String
        switch leg.won {
        case true?: verdict = "seleção acertada"
        case false?: verdict = "seleção errada"
        case nil: verdict = "ainda não liquidada"
        }
        var detail = ""
        switch leg.market {
        case .over25, .under25: detail = " (\(home + away) gols)"
        case .scorer: detail = leg.won == true ? " (\(player(leg.a)?.name ?? "o atleta") marcou)" : " (\(player(leg.a)?.name ?? "o atleta") não marcou)"
        case .qualify: if let winner = fixture.winner { detail = " (classificou \(FootballSeason.teamName(winner)))" }
        default: break
        }
        return "\(match)\(detail): \(verdict)"
    }

    // MARK: PAL-05

    /// Palpites e acertos de cada palpiteiro simulado, a cada dia de jogo.
    mutating func recordTipsterPicks() {
        var random = FootballRandom(seed: matchSeed(stream: .betting, id: 1_000 + matchDayIndex))
        for index in world.betting.tipsters.indices {
            let skill = world.betting.tipsters[index].skill
            var hits = 0
            for _ in 0..<Self.tipsterPicksPerRound where random.unit() < 0.3 + skill * 0.5 { hits += 1 }
            world.betting.tipsters[index].picks = (world.betting.tipsters[index].picks ?? 0) + Self.tipsterPicksPerRound
            world.betting.tipsters[index].hits = (world.betting.tipsters[index].hits ?? 0) + hits
        }
    }

    /// Seleções já liquidadas do jogador nos bilhetes guardados.
    var userBetLegRecord: (picks: Int, hits: Int) {
        let settled = world.betting.bets.flatMap(\.legs).compactMap(\.won)
        return (settled.count, settled.filter { $0 }.count)
    }

    var tipsterProfiles: [TipsterProfile] {
        let user = userBetLegRecord
        let rows = world.betting.tipsters.map {
            TipsterProfile(id: $0.id, name: $0.name, isUser: false, picks: $0.picks ?? 0, hits: $0.hits ?? 0, profit: $0.profit)
        } + [TipsterProfile(id: 0, name: "Você", isUser: true, picks: user.picks, hits: user.hits, profit: world.betting.seasonProfit)]
        return rows.sorted { $0.profit == $1.profit ? $0.id < $1.id : $0.profit > $1.profit }
    }
}
