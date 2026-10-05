import Foundation

// MARK: - Troféus e legado (TRO-01..05)

/// Contexto preservado de uma conquista: sobrevive a troca de clube, venda de atletas e mudança de nome.
struct TrophyRecord: Codable, Equatable, Identifiable {
    let achievementRaw: String
    let season: Int
    let matchDay: Int
    let clubID: Int
    let clubName: String
    let fixtureID: Int?
    let participantNames: [String]
    let context: String
    var id: String { achievementRaw }
}

struct LegacyState: Codable, Equatable {
    var trophies: [TrophyRecord] = []
    /// Até `FootballCareer.legacyHighlightLimit` conquistas em destaque no perfil.
    var highlights: [String] = []
}

enum TimelineKind: String, Equatable {
    case title, promotion, relegation, cup, award, record, trophy, season
}

struct TimelineEntry: Equatable, Identifiable {
    let season: Int
    let kind: TimelineKind
    let title: String
    let detail: String
    var id: String { "\(season)-\(kind.rawValue)-\(title)" }
}

extension FootballCareer {
    static let legacyHighlightLimit = 3

    // MARK: Registro do desbloqueio (TRO-01/02)

    mutating func recordTrophy(_ achievement: Achievement, fixture: LeagueFixture?, record: SeasonRecord?) {
        guard !world.legacy.trophies.contains(where: { $0.achievementRaw == achievement.rawValue }) else { return }
        let clubID = selectedClubID ?? -1
        var names: [String] = []
        var context = "Marco de carreira na temporada \(season)."
        var fixtureID: Int?
        if let fixture {
            fixtureID = fixture.id
            let score = [fixture.homeGoals, fixture.awayGoals].map { $0.map(String.init) ?? "–" }.joined(separator: " × ")
            context = "\(fixture.competition.name), rodada \(fixture.round): \(FootballSeason.teamName(fixture.home)) \(score) \(FootballSeason.teamName(fixture.away))."
            let scorers = (fixture.homeScorerIDs + fixture.awayScorerIDs).compactMap { id in player(id).map { ($0.teamID == clubID) ? $0.name : nil } ?? nil }
            names = Array(NSOrderedSet(array: scorers)) as? [String] ?? []
        } else if let record {
            context = "Fim da temporada \(record.season): \(record.position)º lugar na \(record.division.name) com \(record.points) pontos."
            if !record.topScorerName.isEmpty, record.topScorerTeamID == record.clubID { names = [record.topScorerName] }
        }
        world.legacy.trophies.append(TrophyRecord(achievementRaw: achievement.rawValue, season: season, matchDay: matchDayIndex,
                                                  clubID: clubID, clubName: FootballSeason.teamName(clubID),
                                                  fixtureID: fixtureID, participantNames: names, context: context))
    }

    func trophyRecord(for achievement: Achievement) -> TrophyRecord? {
        world.legacy.trophies.first { $0.achievementRaw == achievement.rawValue }
    }

    // MARK: Progresso (TRO-03)

    /// Progresso verificável; nil quando a conquista é um evento pontual sem contagem.
    func achievementProgress(_ achievement: Achievement) -> (current: Int, target: Int)? {
        func counter(_ key: String, _ target: Int) -> (Int, Int) { (min(target, counters[key] ?? 0), target) }
        switch achievement {
        case .firstWin: return counter("wins", 1)
        case .winStreak5: return (min(5, records.longestWinStreak), 5)
        case .unbeaten10: return (min(10, records.longestUnbeaten), 10)
        case .bigWin5: return (min(5, records.biggestWinMargin), 5)
        case .stadiumLevel3: return (min(3, stadiumLevel), 3)
        case .allFacilities4:
            return ([trainingCenterLevel, medicalLevel, youthAcademyLevel, stadiumLevel].reduce(0) { $0 + min(4, $1) }, 16)
        case .millionaire: return (min(25, transferBudget / 1_000_000), 25)
        case .fiveSeasons: return (min(5, history.count), 5)
        case .tenSeasons: return (min(10, history.count), 10)
        case .reputation90: return (min(90, reputation), 90)
        case .veteran: return counter("matches", 100)
        case .pressMaster: return counter("press", 20)
        case .epicComeback: return counter("comebacks", 3)
        case .fansOnFire: return (min(80, max(0, clubHype)), 80)
        case .scoutEye: return (min(10, scoutReports.count), 10)
        case .eventsMaster: return counter("events", 25)
        case .questsMaster: return (min(15, world.quests.completedCount), 15)
        default: return nil
        }
    }

    // MARK: Linha do tempo (TRO-04)

    var careerTimeline: [TimelineEntry] {
        var entries: [TimelineEntry] = []
        for record in history {
            let club = FootballSeason.teamName(record.clubID)
            let champion = record.championID == record.clubID || (record.division == .serieB && record.position == 1)
            if champion {
                entries.append(TimelineEntry(season: record.season, kind: .title, title: "Campeão da \(record.division.name)",
                                             detail: "\(club) · \(record.points) pontos"))
            }
            if record.promoted { entries.append(TimelineEntry(season: record.season, kind: .promotion, title: "Acesso à Série A", detail: club)) }
            if record.relegated { entries.append(TimelineEntry(season: record.season, kind: .relegation, title: "Rebaixamento", detail: club)) }
            if record.cupWinnerID == record.clubID { entries.append(TimelineEntry(season: record.season, kind: .cup, title: "Campeão da Copa", detail: club)) }
            if record.topScorerTeamID == record.clubID, record.topScorerGoals > 0 {
                entries.append(TimelineEntry(season: record.season, kind: .award, title: "Artilheiro do campeonato",
                                             detail: "\(record.topScorerName) · \(record.topScorerGoals) gols"))
            }
            entries.append(TimelineEntry(season: record.season, kind: .season, title: "Temporada \(record.season)",
                                         detail: "\(club) · \(record.position)º na \(record.division.name) · \(record.points) pts"))
        }
        for trophy in world.legacy.trophies {
            guard let achievement = Achievement(rawValue: trophy.achievementRaw) else { continue }
            entries.append(TimelineEntry(season: trophy.season, kind: .trophy, title: achievement.title, detail: trophy.context))
        }
        if records.longestWinStreak >= 3 {
            entries.append(TimelineEntry(season: season, kind: .record, title: "Recorde: \(records.longestWinStreak) vitórias seguidas", detail: "Sequência mais longa da carreira"))
        }
        if records.biggestWinMargin >= 3 {
            entries.append(TimelineEntry(season: season, kind: .record, title: "Recorde: goleada por \(records.biggestWinMargin) gols", detail: "Maior vitória da carreira"))
        }
        return entries.sorted { $0.season == $1.season ? $0.id < $1.id : $0.season > $1.season }
    }

    // MARK: Destaques e marco compartilhável (TRO-05)

    @discardableResult
    mutating func setHighlight(_ achievement: Achievement, on: Bool) -> Bool {
        guard isUnlocked(achievement) else { return false }
        var list = world.legacy.highlights
        if on {
            guard !list.contains(achievement.rawValue), list.count < Self.legacyHighlightLimit else { return false }
            list.append(achievement.rawValue)
        } else {
            list.removeAll { $0 == achievement.rawValue }
        }
        world.legacy.highlights = list
        return true
    }

    var highlightedAchievements: [Achievement] {
        world.legacy.highlights.compactMap(Achievement.init(rawValue:)).filter(isUnlocked)
    }

    func shareText(for achievement: Achievement) -> String? {
        guard isUnlocked(achievement) else { return nil }
        let trophy = trophyRecord(for: achievement)
        let place = trophy.map { " pelo \($0.clubName), temporada \($0.season)" } ?? ""
        return "\(achievement.title)\(place): \(achievement.detail)" + (trophy.map { " \($0.context)" } ?? "")
    }
}
