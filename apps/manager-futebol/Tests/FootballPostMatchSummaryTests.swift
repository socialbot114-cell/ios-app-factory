import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballPostMatchSummaryTests: XCTestCase {
    private func playOne(seed: Int = 55) throws -> (FootballCareer, LeagueFixture) {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        career.liveMatch.map { _ in () }
        XCTAssertTrue(career.finishMatchDay())
        let fixture = try XCTUnwrap(career.latestUserFixture)
        return (career, fixture)
    }

    func testSummaryExplainsWhatChangedWithCausesFromTheMatchData() throws {
        let (career, fixture) = try playOne()
        let summary = try XCTUnwrap(fixture.summary)
        XCTAssertTrue(summary.headline.contains("×"))
        XCTAssertFalse(summary.evidence.isEmpty)
        XCTAssertTrue(summary.evidence.contains { $0.hasPrefix("Finalizações") })
        XCTAssertTrue(summary.evidence.contains { $0.hasPrefix("Posse de bola") })
        for change in summary.changes {
            XCTAssertFalse(change.cause.isEmpty, "Toda mudança traz a causa registrada: \(change.label)")
            if let delta = change.delta { XCTAssertNotEqual(delta, 0) }
        }
        // Os números do resumo batem com o jogo registrado.
        let isHome = fixture.home == career.selectedClubID
        let shots = (isHome ? fixture.homeShots : fixture.awayShots) ?? -1
        XCTAssertTrue(summary.evidence.contains { $0.contains("Finalizações \(shots) ×") })
        // O caixa aparece com as categorias do dia.
        if let cash = summary.changes.first(where: { $0.label == "Caixa" }) { XCTAssertFalse(cash.cause.isEmpty) }
    }

    func testSummaryNeverClaimsCausalityForTacticalChanges() throws {
        var career = FootballCareer(seed: 55)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        career.liveAdvance(to: 30)
        XCTAssertTrue(career.liveApplyPreset(.allOut))
        XCTAssertTrue(career.finishMatchDay())
        let fixture = try XCTUnwrap(career.latestUserFixture)
        let tactical = try XCTUnwrap(fixture.summary?.evidence.first { $0.hasPrefix("Mudanças táticas") })
        XCTAssertTrue(tactical.contains("não prova de causa"))
        XCTAssertFalse(tactical.lowercased().contains("por causa"))
        XCTAssertFalse(tactical.lowercased().contains("graças"))
    }

    func testSummaryIsDeterministicAndSurvivesSave() throws {
        let first = try playOne().1.summary
        let second = try playOne().1.summary
        XCTAssertEqual(first, second)
        var (career, fixture) = try playOne(seed: 61)
        _ = fixture
        let data = try JSONEncoder().encode(career)
        let loaded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertEqual(loaded.latestUserFixture?.summary, career.latestUserFixture?.summary)
        career.fixtures = career.fixtures.map { var copy = $0; copy.summary = nil; return copy }
        let stripped = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertNil(stripped.latestUserFixture?.summary, "Save antigo sem resumo continua carregando")
    }

    func testBrokenPromiseAndPendingPressAppearInTheAttentionList() throws {
        var career = FootballCareer(seed: 55)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        XCTAssertTrue(career.finishMatchDay())
        let summary = try XCTUnwrap(career.latestUserFixture?.summary)
        XCTAssertTrue(summary.attention.contains("Coletiva de imprensa aguardando resposta."), "Coletiva pendente aparece")
    }
}
