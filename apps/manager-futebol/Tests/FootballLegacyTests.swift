import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballLegacyTests: XCTestCase {
    private func career() -> FootballCareer {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    func testUnlockRecordsContextThatSurvivesClubChange() throws {
        var career = career()
        var fixture = LeagueFixture(id: 501, matchDay: 0, round: 3, competition: .league(.serieA), home: 0, away: 1)
        fixture.homeGoals = 3
        fixture.awayGoals = 0
        career.counters["wins"] = 1
        let unlocked = career.checkAchievements(fixture: fixture)
        XCTAssertTrue(unlocked.contains(.firstWin))
        let record = try XCTUnwrap(career.trophyRecord(for: .firstWin))
        XCTAssertEqual(record.clubID, 0)
        XCTAssertEqual(record.fixtureID, 501)
        XCTAssertTrue(record.context.contains("3 × 0"), record.context)
        let name = record.clubName
        career.selectedClubID = 5
        XCTAssertEqual(career.trophyRecord(for: .firstWin)?.clubName, name, "O contexto original fica preservado")
        // Desbloquear de novo não reescreve o registro.
        career.recordTrophy(.firstWin, fixture: nil, record: nil)
        XCTAssertEqual(career.world.legacy.trophies.filter { $0.achievementRaw == "firstWin" }.count, 1)
    }

    func testProgressIsVerifiableAndCapped() {
        var career = career()
        XCTAssertEqual(career.achievementProgress(.veteran)?.target, 100)
        career.counters["matches"] = 40
        XCTAssertEqual(career.achievementProgress(.veteran)?.current, 40)
        career.counters["matches"] = 400
        XCTAssertEqual(career.achievementProgress(.veteran)?.current, 100)
        career.records.longestWinStreak = 3
        XCTAssertEqual(career.achievementProgress(.winStreak5)?.current, 3)
        XCTAssertNil(career.achievementProgress(.hatTrick), "Evento pontual não tem contagem")
    }

    func testHighlightsAreLimitedAndOnlyForUnlocked() {
        var career = career()
        XCTAssertFalse(career.setHighlight(.firstWin, on: true), "Bloqueada não pode ser destaque")
        for achievement in [Achievement.firstWin, .winStreak5, .hatTrick, .derbyWin] { career.achievements[achievement.rawValue] = 1 }
        XCTAssertTrue(career.setHighlight(.firstWin, on: true))
        XCTAssertTrue(career.setHighlight(.winStreak5, on: true))
        XCTAssertTrue(career.setHighlight(.hatTrick, on: true))
        XCTAssertFalse(career.setHighlight(.derbyWin, on: true), "Máximo \(FootballCareer.legacyHighlightLimit)")
        XCTAssertTrue(career.setHighlight(.firstWin, on: false))
        XCTAssertEqual(career.highlightedAchievements.map(\.rawValue), ["winStreak5", "hatTrick"])
        XCTAssertNil(career.shareText(for: .bigWin5))
        XCTAssertTrue(career.shareText(for: .winStreak5)?.contains("Embalado") ?? false)
    }

    func testTimelineListsTitlesRecordsAndTrophiesNewestFirst() {
        var career = career()
        career.history = [
            SeasonRecord(season: 1, clubID: 0, championID: 0, position: 1, points: 40, target: 4, objectiveMet: true, prizeMoney: 0,
                         topScorerName: "Fulano", topScorerTeamID: 0, topScorerGoals: 14, retiredPlayers: 0, youthPromoted: 0, wasFired: false),
            SeasonRecord(season: 2, clubID: 0, championID: 3, position: 5, points: 25, target: 4, objectiveMet: false, prizeMoney: 0,
                         topScorerName: "Beltrano", topScorerTeamID: 3, topScorerGoals: 12, retiredPlayers: 0, youthPromoted: 0, wasFired: false)
        ]
        career.records.longestWinStreak = 6
        let timeline = career.careerTimeline
        XCTAssertTrue(timeline.contains { $0.kind == .title && $0.season == 1 })
        XCTAssertTrue(timeline.contains { $0.kind == .award && $0.detail.contains("14 gols") })
        XCTAssertFalse(timeline.contains { $0.kind == .award && $0.season == 2 }, "Artilheiro de outro clube não entra")
        XCTAssertTrue(timeline.contains { $0.kind == .record && $0.title.contains("6 vitórias") })
        XCTAssertEqual(timeline.map(\.season), timeline.map(\.season).sorted(by: >))
    }

    func testOldSavesDecodeWithEmptyLegacy() throws {
        let data = try JSONEncoder().encode(WorldState())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "legacy")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let world = try JSONDecoder().decode(WorldState.self, from: stripped)
        XCTAssertEqual(world.legacy, LegacyState())
    }
}
