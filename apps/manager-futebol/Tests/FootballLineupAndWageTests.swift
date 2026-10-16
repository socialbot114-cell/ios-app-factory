import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballLineupAndWageTests: XCTestCase {
    private func careerWithClub(seed: Int = 21) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(10))
        return career
    }

    // MARK: Escalação escolhida pelo treinador

    func testCurrentStartersAreAValidLineup() {
        let career = careerWithClub()
        XCTAssertEqual(career.startingXI.count, 11)
        XCTAssertNil(career.lineupProblem(career.startingXI))
    }

    func testLineupNeedsElevenDistinctPlayers() {
        let career = careerWithClub()
        let eleven = career.startingXI
        XCTAssertNotNil(career.lineupProblem(Array(eleven.prefix(10))), "Dez titulares não fecham a escalação")
        var duplicated = eleven
        duplicated[0] = duplicated[1]
        XCTAssertNotNil(career.lineupProblem(duplicated), "Um atleta não ocupa duas vagas")
    }

    func testLineupNeedsAGoalkeeperInTheRightSlot() throws {
        let career = careerWithClub()
        let keeper = try XCTUnwrap(career.starters.first { $0.position == .goalkeeper })
        let bench = try XCTUnwrap(career.clubRoster.first { !career.startingXI.contains($0.id) && $0.position != .goalkeeper })
        var lineup = career.startingXI.filter { $0 != keeper.id }
        lineup.append(bench.id)
        XCTAssertNotNil(career.lineupProblem(lineup), "Sem goleiro a escalação não sai")
    }

    func testSaveStoresAValidLineupAndRejectsAnInvalidOne() throws {
        var career = careerWithClub()
        let original = career.startingXI
        XCTAssertNil(career.saveStartingXI(original))
        XCTAssertEqual(career.startingXI, original)

        let keeper = try XCTUnwrap(career.starters.first { $0.position == .goalkeeper })
        XCTAssertNotNil(career.saveStartingXI(original.filter { $0 != keeper.id }))
        XCTAssertEqual(career.startingXI, original, "Escalação inválida não substitui a atual")
    }

    // MARK: Teto da folha pela diretoria

    func testWageIncreaseNeedsHealthyCash() {
        var career = careerWithClub()
        career.transferBudget = 0
        XCTAssertFalse(career.cashIsHealthy)
        XCTAssertNotNil(career.boardMeetingBlocker(.wageIncrease), "Caixa apertado não recebe o pedido de folha maior")
        XCTAssertFalse(career.requestBoardMeeting(.wageIncrease))
    }

    func testWageIncreaseOpensWhenCashCoversAYearOfWages() {
        var career = careerWithClub()
        career.transferBudget = career.wageBill * 10
        XCTAssertTrue(career.cashIsHealthy)
        XCTAssertNil(career.boardMeetingBlocker(.wageIncrease))
        XCTAssertTrue(career.requestBoardMeeting(.wageIncrease))
    }

    func testWageCutIsOncePerSeasonAndStepIsTenPercent() {
        var career = careerWithClub()
        career.wageCap = 10_000_000
        XCTAssertEqual(career.wageStep, 1_000_000)
        XCTAssertTrue(career.requestBoardMeeting(.wageCut))
        XCTAssertNotNil(career.boardMeetingBlocker(.wageCut), "Um assunto de cada vez com a diretoria")
    }

    func testEveryRequestKindHasTitleAndPitch() {
        for kind in BoardRequestKind.allCases {
            XCTAssertFalse(kind.title.isEmpty)
            XCTAssertFalse(kind.pitch.isEmpty)
        }
        XCTAssertEqual(BoardRequestKind.allCases.count, 4)
    }
}
