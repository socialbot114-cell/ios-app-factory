import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballManagerBoardTests: XCTestCase {
    private func makeCareer() -> FootballCareer {
        var career = FootballCareer(seed: 41)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    private func busyCareer() throws -> FootballCareer {
        var career = makeCareer()
        let athlete = try XCTUnwrap(career.clubRoster.filter { !career.startingXI.contains($0.id) && !$0.isYouth }.first)
        XCTAssertTrue(career.promiseStarts(playerID: athlete.id, starts: 2))
        career.matchDayIndex = 6
        let star = try XCTUnwrap(career.clubRoster.max { $0.overall < $1.overall })
        _ = career.openRumorArc(playerID: star.id, truth: false)
        _ = career.openCommitment(kind: .boardRequest, days: 5, title: "Pedido da diretoria", detail: "x")
        return career
    }

    func testAgendaItemsCarryImportanceAndOwnerAndSortingIsStable() throws {
        let career = try busyCareer()
        let items = career.agenda
        XCTAssertGreaterThanOrEqual(items.count, 3)
        XCTAssertTrue(items.contains { $0.owner == .press && $0.importance == 3 }, "Boato: imprensa, importância alta")
        XCTAssertTrue(items.contains { $0.owner == .board && $0.importance == 3 })
        XCTAssertTrue(items.contains { $0.owner == .athlete })

        let byImportance = career.sortedAgenda(by: .importance)
        XCTAssertEqual(Set(byImportance.map(\.id)), Set(items.map(\.id)), "Mesmos itens, só reordenados")
        XCTAssertEqual(byImportance.map(\.importance), byImportance.map(\.importance).sorted(by: >))
        let byOwner = career.sortedAgenda(by: .owner)
        XCTAssertEqual(byOwner.map(\.owner.rawValue), byOwner.map(\.owner.rawValue).sorted())
        XCTAssertEqual(career.sortedAgenda(by: .deadline).map(\.id), items.map(\.id))
        XCTAssertEqual(career.sortedAgenda(by: .importance).map(\.id), byImportance.map(\.id), "Ordenação repetível")
    }

    func testWhatExpiresBeforeTheNextAdvanceListsTheMostImportantFirst() throws {
        var career = try busyCareer()
        let athlete = try XCTUnwrap(career.promises.first?.playerID)
        career.matchDayIndex = (career.promises.first?.deadlineMatchDay ?? 8)
        XCTAssertTrue(career.dueBeforeNextAdvance.contains { $0.id.hasPrefix("promise-") })
        let due = career.dueBeforeNextAdvance
        XCTAssertEqual(due.map(\.importance), due.map(\.importance).sorted(by: >))
        XCTAssertTrue(due.allSatisfy(\.expiresOnNextAdvance))
        _ = athlete
    }

    func testPreparationChecklistShowsWhatIsReadyAndWhatIsMissing() throws {
        var career = makeCareer()
        let items = career.matchPreparation()
        let ids = items.map(\.id)
        XCTAssertTrue(["scout", "lineup", "condition", "promises", "press"].allSatisfy(ids.contains))
        XCTAssertFalse(try XCTUnwrap(items.first { $0.id == "scout" }).done)
        career.opponentPrep = true
        XCTAssertTrue(try XCTUnwrap(career.matchPreparation().first { $0.id == "scout" }).done)

        // Promessa pendente fora do time aparece como falta.
        let athlete = try XCTUnwrap(career.clubRoster.filter { !career.startingXI.contains($0.id) && !$0.isYouth }.first)
        XCTAssertTrue(career.promiseStarts(playerID: athlete.id, starts: 2))
        let promises = try XCTUnwrap(career.matchPreparation().first { $0.id == "promises" })
        XCTAssertFalse(promises.done)
        XCTAssertTrue(promises.detail.contains("promessa pendente"))

        // Cansaço derruba a condição física.
        for index in career.players.indices where career.startingXI.contains(career.players[index].id) { career.players[index].condition = 60 }
        XCTAssertFalse(try XCTUnwrap(career.matchPreparation().first { $0.id == "condition" }).done)

        // Sem partida futura ou durante o jogo, não há preparação.
        XCTAssertTrue(career.beginMatchDay())
        XCTAssertTrue(career.matchPreparation().isEmpty)
    }
}
