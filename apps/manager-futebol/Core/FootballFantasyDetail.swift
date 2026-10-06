import Foundation

struct FantasyComponent: Codable, Equatable, Identifiable {
    let id: String
    let label: String
    let quantity: Int
    let points: Double
}

struct FantasyAthleteDetail: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let fixtureID: Int?
    let status: String
    let components: [FantasyComponent]
    let isCaptain: Bool
    var basePoints: Double { components.reduce(0) { $0 + $1.points } }
    var captainBonus: Double { isCaptain ? basePoints * 0.5 : 0 }
    var points: Double { basePoints + captainBonus }
}

struct FantasyRoundDetail: Codable, Equatable {
    let season: Int
    let round: Int
    let athletes: [FantasyAthleteDetail]
    var points: Double { (athletes.reduce(0) { $0 + $1.points } * 10).rounded() / 10 }
}

struct FantasyParticipant: Equatable, Identifiable {
    let id: Int
    let name: String
    let bio: String
    let points: Double
    let lastRoundPoints: Double?
    let isUser: Bool
}

extension FootballCareer {
    static let fantasyDetailLimitation = "Detalhe disponível apenas para a última rodada com snapshot registrado. Saves antigos guardam total e capitão, mas não a escalação; não reconstruímos esse histórico. Rivais têm pontuação simulada, sem escalação registrada."

    func fantasyComponents(for athlete: FootballPlayer, in fixture: LeagueFixture) -> [FantasyComponent] {
        guard fixture.isPlayed, let home = fixture.homeGoals, let away = fixture.awayGoals,
              fixture.involves(athlete.teamID ?? -1), fixture.playedIDs.contains(athlete.id) else { return [] }
        let conceded = fixture.home == athlete.teamID ? away : home
        let scored = fixture.home == athlete.teamID ? home : away
        let goalValue: Double
        let cleanValue: Double
        switch athlete.position {
        case .goalkeeper: goalValue = 15; cleanValue = 5
        case .defender: goalValue = 12; cleanValue = 4
        case .midfielder: goalValue = 10; cleanValue = 1
        case .forward: goalValue = 8; cleanValue = 0
        }
        let goals = (fixture.homeScorerIDs + fixture.awayScorerIDs).filter { $0 == athlete.id }.count
        let assists = fixture.assistIDs.filter { $0 == athlete.id }.count
        let yellows = fixture.yellowIDs.filter { $0 == athlete.id }.count
        let reds = fixture.redIDs.filter { $0 == athlete.id }.count
        return [
            FantasyComponent(id: "appearance", label: "Participação", quantity: 1, points: 1),
            FantasyComponent(id: "goals", label: "Gols", quantity: goals, points: Double(goals) * goalValue),
            FantasyComponent(id: "assists", label: "Assistências", quantity: assists, points: Double(assists) * 5),
            FantasyComponent(id: "clean", label: "Sem sofrer gols", quantity: conceded == 0 ? 1 : 0, points: conceded == 0 ? cleanValue : 0),
            FantasyComponent(id: "conceded", label: "Gols sofridos (goleiro)", quantity: athlete.position == .goalkeeper ? conceded : 0, points: athlete.position == .goalkeeper ? -Double(conceded) : 0),
            FantasyComponent(id: "win", label: "Vitória", quantity: scored > conceded ? 1 : 0, points: scored > conceded ? 1 : 0),
            FantasyComponent(id: "yellow", label: "Amarelos", quantity: yellows, points: -Double(yellows) * 2),
            FantasyComponent(id: "red", label: "Vermelhos", quantity: reds, points: -Double(reds) * 5)
        ]
    }

    func makeFantasyDetail(matchDay: Int, round: Int) -> FantasyRoundDetail {
        let athletes = world.fantasy.lineup.map { id -> FantasyAthleteDetail in
            let athlete = player(id)
            let fixture = athlete.flatMap { athlete in fixtures.first {
                $0.matchDay == matchDay && $0.competition.division != nil && $0.involves(athlete.teamID ?? -1)
            } }
            let components = athlete.flatMap { athlete in fixture.map { fantasyComponents(for: athlete, in: $0) } } ?? []
            let status = fixture == nil ? "Sem jogo disponível" : (fixture?.isPlayed != true ? "Jogo pendente" : (components.isEmpty ? "Não participou" : "Jogo registrado"))
            return FantasyAthleteDetail(id: id, name: athlete?.name ?? "Atleta #\(id)", fixtureID: fixture?.id,
                                        status: status, components: components, isCaptain: id == world.fantasy.captainID)
        }
        return FantasyRoundDetail(season: season, round: round, athletes: athletes)
    }

    var fantasyLatestDetail: FantasyRoundDetail? {
        guard let result = world.fantasy.history.first, result.season == season,
              let detail = fact("fantasy-result-\(result.id)")?.fantasySnapshot,
              detail.season == result.season, detail.round == result.round, detail.points == result.points else { return nil }
        return detail
    }

    func fantasyRivalScores(matchDay: Int) -> [Double] {
        var random = FootballRandom(seed: matchSeed(stream: .fantasy, id: matchDay + 100))
        return world.fantasy.managers.indices.map { index in
            max(0, 34 + Double(random.int(in: -120...120)) / 10 + Double(index) * 0.2)
        }
    }

    var fantasyParticipants: [FantasyParticipant] {
        let bios = ["Veterano da liga", "Analista de confrontos", "Torcedor de longa data", "Entusiasta de capitães", "Observador do mercado", "Fã do 4-3-3", "Caçador de surpresas"]
        let last = world.fantasy.history.first
        let day = last.flatMap { result in result.season == season ? calendar.firstIndex { $0.leagueRound == result.round } : nil }
        let scores = day.map { fantasyRivalScores(matchDay: $0) } ?? []
        var rows = world.fantasy.managers.enumerated().map { index, manager in
            FantasyParticipant(id: manager.id, name: manager.name, bio: bios[index % bios.count], points: manager.points,
                               lastRoundPoints: scores.indices.contains(index) ? scores[index] : nil, isUser: false)
        }
        rows.append(FantasyParticipant(id: 0, name: world.coach.name, bio: "Seu time · capitão 1,5×", points: world.fantasy.seasonPoints,
                                       lastRoundPoints: last?.season == season ? last?.points : nil, isUser: true))
        return rows.sorted { $0.points == $1.points ? $0.id < $1.id : $0.points > $1.points }
    }

    func fantasyShareText(_ result: FantasyRoundResult) -> String {
        "Rodada Mágica · T\(result.season) R\(result.round): \(String(format: "%.1f", result.points)) pontos, \(result.rank)º na liga dos amigos. Capitão: \(result.captainName). #RodadaMágica"
    }

    func fantasyShareBlockReason(_ result: FantasyRoundResult) -> String? {
        guard world.fantasy.history.contains(result) else { return "Resultado indisponível." }
        // High-water mark survives feed/fact retention, without one key per round.
        let sharedSeason = counters["fantasySharedSeason"] ?? 0
        let sharedRound = counters["fantasySharedRound"] ?? 0
        if result.season < sharedSeason || (result.season == sharedSeason && result.round <= sharedRound) {
            return "Resultado já compartilhado ou anterior ao último compartilhamento."
        }
        return canPost(.humor)
    }

    @discardableResult
    mutating func shareFantasyResult(_ result: FantasyRoundResult) -> SocialPost? {
        guard fantasyShareBlockReason(result) == nil,
              let post = publishPost(draft: PostDraft(tone: .humor)),
              let index = world.social.posts.firstIndex(where: { $0.id == post.id }) else { return nil }
        let text = fantasyShareText(result)
        let factID = "fantasy-result-\(result.id)"
        recordFact(WorldFact(id: factID, source: .match, worldDay: worldDay, title: "Rodada Mágica", detail: text, isPublic: true))
        if let factIndex = factStore.facts.firstIndex(where: { $0.id == factID }) {
            factStore.facts[factIndex].isPublic = true
            factStore.facts[factIndex].detail = text
        }
        world.social.posts[index].text = text
        world.social.posts[index].tag = "#RodadaMágica"
        attachFact(toPost: post.id, factID: factID, reliability: .confirmed)
        counters["fantasySharedSeason"] = result.season
        counters["fantasySharedRound"] = result.round
        return world.social.posts[index]
    }
}
