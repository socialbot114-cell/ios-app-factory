import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballPresentationCoordinatorTests: XCTestCase {
    /// A ordem das apresentações é a da fila: coletiva, resumo, mensagem, alerta e guia (FLX-01).
    func testPresentationOrderIsPressSummaryMessageAlertGuide() {
        XCTAssertEqual(FootballPresentation.allCases, [.press, .summary, .message, .alert, .guide])
    }

    /// Pedidos chegam em qualquer ordem, mas aparecem um por vez, sempre na ordem da fila.
    func testOnePresentationAtATimeInOrder() {
        var coordinator = FootballPresentationCoordinator()
        coordinator.request(.guide)
        coordinator.request(.press)
        coordinator.request(.alert)
        XCTAssertEqual(coordinator.current, .guide, "a tela estava livre: o primeiro pedido entra na hora")
        XCTAssertEqual(coordinator.waiting, [.press, .alert])
        coordinator.finishCurrent()
        XCTAssertEqual(coordinator.current, .press)
        coordinator.finishCurrent()
        XCTAssertEqual(coordinator.current, .alert)
        coordinator.finishCurrent()
        XCTAssertNil(coordinator.current)
        XCTAssertTrue(coordinator.waiting.isEmpty)
    }

    /// Um pedido repetido, na tela ou na fila, não abre a mesma apresentação duas vezes.
    func testRepeatedRequestsAreNotQueuedTwice() {
        var coordinator = FootballPresentationCoordinator()
        coordinator.request(.summary)
        coordinator.request(.summary)
        coordinator.request(.message)
        coordinator.request(.message)
        XCTAssertEqual(coordinator.current, .summary)
        XCTAssertEqual(coordinator.waiting, [.message])
        coordinator.finishCurrent()
        XCTAssertEqual(coordinator.current, .message)
        coordinator.finishCurrent()
        XCTAssertNil(coordinator.current)
    }

    /// Fechar com a fila vazia, ou sem nada na tela, não quebra nem inventa uma apresentação.
    func testFinishingWithNothingWaitingLeavesTheScreenEmpty() {
        var coordinator = FootballPresentationCoordinator()
        coordinator.finishCurrent()
        XCTAssertNil(coordinator.current)
        coordinator.request(.press)
        coordinator.finishCurrent()
        coordinator.finishCurrent()
        XCTAssertNil(coordinator.current)
        XCTAssertTrue(coordinator.waiting.isEmpty)
    }
}
