import Foundation
import XCTest
@testable import ManagerFutebol

/// F0-07: saves de referência (nova carreira, meio de temporada, fim de temporada, várias temporadas, demitido e partida em andamento)
/// que precisam continuar abrindo, retomando e produzindo o mesmo jogo depois de salvar e carregar.
final class FootballReferenceSavesTests: XCTestCase {
    private func roundTrip(_ career: FootballCareer) throws -> FootballCareer {
        try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
    }

    private func start(seed: Int = 26, club: Int = 0) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    private func playDays(_ career: inout FootballCareer, _ days: Int) {
        for _ in 0..<days where career.canPlay || career.canAdvanceWithoutPlaying {
            career.simulateNextMatchDay()
            career.skipPress()
        }
    }

    func testEveryReferenceSaveReopensAndContinuesIdentically() throws {
        var references: [(String, FootballCareer)] = []
        references.append(("nova carreira", start()))

        var mid = start()
        playDays(&mid, 14)
        references.append(("meio de temporada", mid))

        var end = start()
        playDays(&end, FootballSeason.matchDaysPerSeason)
        XCTAssertTrue(end.isSeasonComplete)
        references.append(("fim de temporada", end))

        var long = start(seed: 33, club: 4)
        for _ in 0..<3 {
            playDays(&long, FootballSeason.matchDaysPerSeason)
            _ = long.startNextSeason()
        }
        references.append(("três temporadas", long))

        var live = start()
        XCTAssertTrue(live.beginMatchDay())
        live.liveAdvance(to: 37)
        references.append(("partida em andamento", live))

        var fired = start()
        playDays(&fired, 8)
        fired.boardConfidence = 0
        fired.isFired = true
        references.append(("demitido", fired))

        for (name, career) in references {
            let reopened = try roundTrip(career)
            XCTAssertEqual(reopened.season, career.season, name)
            XCTAssertEqual(reopened.matchDayIndex, career.matchDayIndex, name)
            XCTAssertEqual(reopened.factStore, career.factStore, name)
            XCTAssertEqual(reopened.commitments, career.commitments, name)
            XCTAssertEqual(reopened.liveMatch, career.liveMatch, name)
            XCTAssertEqual(reopened.fixtures.count, career.fixtures.count, name)
            XCTAssertEqual(reopened.players.count, career.players.count, name)
            XCTAssertEqual(reopened.agenda.map(\.id), career.agenda.map(\.id), "\(name): a agenda é a mesma")
            // Salvar duas vezes dá o mesmo conteúdo (sem estado oculto fora do save).
            XCTAssertEqual(try JSONEncoder().encode(try roundTrip(reopened)).count, try JSONEncoder().encode(reopened).count, name)
        }

        // Continuar depois de reabrir dá o mesmo jogo que continuar sem reabrir.
        var direct = mid
        var viaSave = try roundTrip(mid)
        playDays(&direct, 6)
        playDays(&viaSave, 6)
        XCTAssertEqual(direct.fixtures.compactMap(\.homeGoals), viaSave.fixtures.compactMap(\.homeGoals))
        XCTAssertEqual(direct.factStore, viaSave.factStore)
        XCTAssertEqual(direct.transferBudget, viaSave.transferBudget)
    }

    func testPartialLiveMatchFinishesTheSameAfterReopening() throws {
        var live = start()
        XCTAssertTrue(live.beginMatchDay())
        live.liveAdvance(to: 45)
        var reopened = try roundTrip(live)
        live.liveAdvance(minutes: 200)
        reopened.liveAdvance(minutes: 200)
        XCTAssertEqual(live.liveMatch?.sim.home.goals, reopened.liveMatch?.sim.home.goals)
        XCTAssertEqual(live.liveMatch?.sim.away.goals, reopened.liveMatch?.sim.away.goals)
        XCTAssertEqual(live.liveMatch?.sim.events.count, reopened.liveMatch?.sim.events.count)
        XCTAssertTrue(live.finishMatchDay())
        XCTAssertTrue(reopened.finishMatchDay())
        XCTAssertEqual(live.latestUserFixture?.impact, reopened.latestUserFixture?.impact)
        XCTAssertEqual(live.latestUserFixture?.summary, reopened.latestUserFixture?.summary)
    }

    func testLegacySavesWithoutAnyNewSystemStillOpenAndPlay() throws {
        var career = start()
        playDays(&career, 10)
        let data = try JSONEncoder().encode(career)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        // Remove tudo o que foi acrescentado depois da versão de referência 11.
        let newKeys = ["clubHype", "factStore", "commitments", "nextCommitmentID", "playerMemories", "talks", "nextTalkID", "tacticalPlans",
                       "arcs", "nextArcID", "profiles", "postReplies", "nextReplyID", "publicMemory"]
        for key in newKeys { object[key] = nil }
        var legacy = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(legacy.season, career.season)
        XCTAssertEqual(legacy.clubHype, 0)
        XCTAssertTrue(legacy.factStore.facts.isEmpty && legacy.commitments.isEmpty && legacy.arcs.isEmpty && legacy.profiles.isEmpty)
        playDays(&legacy, 8)
        XCTAssertGreaterThan(legacy.matchDayIndex, career.matchDayIndex)
        XCTAssertFalse(legacy.factStore.facts.isEmpty || legacy.profiles.isEmpty && legacy.matchDayIndex > 15, "Os sistemas novos voltam a funcionar num save antigo")
        let reopened = try roundTrip(legacy)
        XCTAssertEqual(reopened.factStore, legacy.factStore)
    }
}
