import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballQuickSummaryTests: XCTestCase {
    /// O resumo que o aviso mostra é o mesmo texto que fica no histórico de ações (FLX-02).
    func testQuickSimulationSummaryStaysInTheActionHistory() {
        var career = FootballCareer(seed: 7)
        let text = career.logQuickSimulation(days: 2, nextPriority: "Renovar Ana · até dia 5")
        XCTAssertEqual(text, "2 dias de calendário simulados. Resultados, treino e prazos atualizados. Próxima prioridade: Renovar Ana · até dia 5.")
        XCTAssertEqual(career.world.phone.actionLog.first?.text, text)
        XCTAssertNil(career.world.phone.actionLog.first?.appID)
    }

    func testPluralHelperAgreesWithTheNumber() {
        XCTAssertEqual(FootballFormat.plural(1, "dia"), "1 dia")
        XCTAssertEqual(FootballFormat.plural(0, "dia"), "0 dias")
        XCTAssertEqual(FootballFormat.plural(3, "dia"), "3 dias")
        XCTAssertEqual(FootballFormat.plural(1, "jovem", "jovens"), "1 jovem")
        XCTAssertEqual(FootballFormat.plural(2, "jovem", "jovens"), "2 jovens")
    }

    func testAttentionBannersAreWrittenInTheRightNumber() throws {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(10))
        if let banner = career.phoneAppAttention(appID: "messages") {
            XCTAssertFalse(banner.detail.contains("("), "Sem plural entre parênteses: \(banner.detail)")
        }
    }

    /// Sem prazos na agenda, o resumo diz isso em vez de citar uma prioridade.
    func testQuickSimulationWithoutDeadlinesSaysSo() {
        var career = FootballCareer(seed: 7)
        let text = career.logQuickSimulation(days: 1, nextPriority: nil)
        XCTAssertTrue(text.hasPrefix("1 dia de calendário simulado."), "Um dia fica no singular")
        XCTAssertTrue(text.hasSuffix(" Agenda sem pendências com prazo."))
        XCTAssertEqual(career.world.phone.actionLog.first?.text, text)
    }
}
