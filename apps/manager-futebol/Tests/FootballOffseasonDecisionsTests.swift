import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballOffseasonDecisionsTests: XCTestCase {
    /// Com tudo pendente, o painel lista as escolhas na ordem do ritual, sem as etapas que só informam (PIL-03 v3).
    func testClassicPanelListsOnlyOpenChoicesInOrder() {
        let open = OffseasonStep.openDecisions(from: .endOfSeason, contractsPending: true, iconPackPending: true,
                                               holidayChosen: false, sponsorPending: true, campChosen: false)
        XCTAssertEqual(open, [.contracts, .iconPack, .holiday, .sponsor, .preseason])
    }

    /// Escolhas já feitas saem do painel; sem nenhuma pendência, o painel fica vazio.
    func testChoicesAlreadyMadeLeaveThePanel() {
        let open = OffseasonStep.openDecisions(from: .review, contractsPending: false, iconPackPending: false,
                                               holidayChosen: false, sponsorPending: false, campChosen: false)
        XCTAssertEqual(open, [.holiday, .preseason])
        let none = OffseasonStep.openDecisions(from: .review, contractsPending: false, iconPackPending: false,
                                               holidayChosen: true, sponsorPending: false, campChosen: true)
        XCTAssertTrue(none.isEmpty)
    }

    /// Etapas antes da atual já passaram: não aparecem no painel.
    func testStepsBeforeTheCurrentOneAreNotListed() {
        let open = OffseasonStep.openDecisions(from: .sponsor, contractsPending: true, iconPackPending: true,
                                               holidayChosen: false, sponsorPending: true, campChosen: false)
        XCTAssertEqual(open, [.sponsor, .preseason])
    }

    /// Depois da pré-temporada só resta a bola rolando, que não é escolha: o painel fica vazio.
    func testNothingLeftAfterPreseasonGivesAnEmptyPanel() {
        let open = OffseasonStep.openDecisions(from: .kickoff, contractsPending: false, iconPackPending: false,
                                               holidayChosen: true, sponsorPending: false, campChosen: false)
        XCTAssertTrue(open.isEmpty)
    }
}
