import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballMatchdayStepTests: XCTestCase {
    /// Coletiva pendente vem antes de tudo: sem responder, o dia não anda (FLX-03).
    func testPendingPressComesFirst() {
        XCTAssertEqual(MatchdayStep.next(hasPendingPress: true, hasUserMatch: true, lineupWarnings: 2, canAdvanceWithoutPlaying: false), .press)
        XCTAssertEqual(MatchdayStep.next(hasPendingPress: true, hasUserMatch: false, lineupWarnings: 0, canAdvanceWithoutPlaying: true), .press)
    }

    /// Jogo com alertas na escalação pede revisão; sem alertas, o passo é jogar.
    func testMatchDayAsksForPreparationOnlyWhenTheLineupHasWarnings() {
        XCTAssertEqual(MatchdayStep.next(hasPendingPress: false, hasUserMatch: true, lineupWarnings: 1, canAdvanceWithoutPlaying: false), .prepare)
        XCTAssertEqual(MatchdayStep.next(hasPendingPress: false, hasUserMatch: true, lineupWarnings: 0, canAdvanceWithoutPlaying: false), .play)
    }

    /// Dia sem jogo do clube: o passo é avançar.
    func testDayWithoutUserMatchAdvances() {
        XCTAssertEqual(MatchdayStep.next(hasPendingPress: false, hasUserMatch: false, lineupWarnings: 0, canAdvanceWithoutPlaying: true), .advance)
    }

    /// Sem nada pendente e sem dia para avançar, não há passo a mostrar.
    func testNothingPendingGivesNoStep() {
        XCTAssertNil(MatchdayStep.next(hasPendingPress: false, hasUserMatch: false, lineupWarnings: 0, canAdvanceWithoutPlaying: false))
    }
}
