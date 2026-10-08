import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballQuickSummaryTests: XCTestCase {
    /// O resumo que o aviso mostra é o mesmo texto que fica no histórico de ações (FLX-02).
    func testQuickSimulationSummaryStaysInTheActionHistory() {
        var career = FootballCareer(seed: 7)
        let text = career.logQuickSimulation(days: 2, nextPriority: "Renovar Ana · até dia 5")
        XCTAssertEqual(text, "2 dia(s) de calendário simulado(s). Resultados, treino e prazos atualizados. Próxima prioridade: Renovar Ana · até dia 5.")
        XCTAssertEqual(career.world.phone.actionLog.first?.text, text)
        XCTAssertNil(career.world.phone.actionLog.first?.appID)
    }

    /// Sem prazos na agenda, o resumo diz isso em vez de citar uma prioridade.
    func testQuickSimulationWithoutDeadlinesSaysSo() {
        var career = FootballCareer(seed: 7)
        let text = career.logQuickSimulation(days: 1, nextPriority: nil)
        XCTAssertTrue(text.hasSuffix(" Agenda sem pendências com prazo."))
        XCTAssertEqual(career.world.phone.actionLog.first?.text, text)
    }
}
