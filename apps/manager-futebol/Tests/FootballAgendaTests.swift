import XCTest
@testable import ManagerFutebol

final class FootballAgendaTests: XCTestCase {
    private func career() -> FootballCareer {
        var career = FootballCareer(seed: 26)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    func testMixedDeadlinesAreAbsoluteSortedAndQueryIsPure() throws {
        var game = career()
        game.season = 2
        game.matchDayIndex = 4
        let athlete = try XCTUnwrap(game.clubRoster.first)
        XCTAssertTrue(game.promiseStarts(playerID: athlete.id, starts: 2))
        game.offers = [TransferOffer(id: 91, playerID: athlete.id, clubID: 1, amount: 100_000, expiresAfterRound: 5)]
        game.world.events.pending = [WorldEvent(id: 92, templateID: "test", category: .board,
            season: 2, matchDay: 4, title: "Decisão", body: "", choices: [],
            expiresWorldDay: game.worldDay + 2, defaultChoice: 0)]
        let index = try XCTUnwrap(game.players.firstIndex { $0.id == athlete.id })
        game.players[index].contract.endSeason = 2
        let before = game
        let agenda = game.agenda
        XCTAssertEqual(game, before)
        XCTAssertEqual(Array(agenda.prefix(3).map(\.kind)), [.offer, .event, .promise])
        XCTAssertEqual(agenda.first?.daysRemaining, 1)
        XCTAssertEqual(agenda.first?.deadlineWorldDay, FootballSeason.matchDaysPerSeason + 5)
        XCTAssertEqual(agenda.first?.destination, .market)
        XCTAssertEqual(agenda.first { $0.kind == .event }?.destination, .alerts)
        XCTAssertEqual(agenda.first { $0.kind == .promise }?.destination, .squad)
        XCTAssertNotNil(agenda.first { $0.id == "contract-\(athlete.id)" && $0.destination == .contracts })
    }

    func testOfferBoundaryMatchesActualCalendarExpiry() throws {
        var game = career()
        let athlete = try XCTUnwrap(game.clubRoster.first)
        game.offers = [TransferOffer(id: 991, playerID: athlete.id, clubID: 1, amount: 100_000, expiresAfterRound: 2)]
        XCTAssertFalse(try XCTUnwrap(game.agenda.first { $0.id == "offer-991" }).expiresOnNextAdvance)
        XCTAssertTrue(game.simulateNextMatchDay())
        XCTAssertTrue(try XCTUnwrap(game.agenda.first { $0.id == "offer-991" }).expiresOnNextAdvance)
        XCTAssertTrue(game.simulateNextMatchDay())
        XCTAssertFalse(game.offers.contains { $0.id == 991 })
    }

    func testLastPromiseDayStillAllowsFulfillmentAndResolvedItemsDisappear() throws {
        var game = career()
        let athlete = try XCTUnwrap(game.clubRoster.first)
        XCTAssertTrue(game.promiseStarts(playerID: athlete.id, starts: 1))
        let deadline = try XCTUnwrap(game.promises.first?.deadlineMatchDay)
        game.matchDayIndex = deadline - 1
        XCTAssertTrue(try XCTUnwrap(game.agenda.first { $0.kind == .promise }).expiresOnNextAdvance)
        game.matchDayIndex += 1
        game.evaluatePromises(started: [athlete.id])
        XCTAssertFalse(game.agenda.contains { $0.kind == .promise })
        XCTAssertEqual(game.inbox.last?.title, "Promessa cumprida")
    }

    func testContractsDoNotExpireDuringQuickAdvanceAndExcludeLoansAndFreeAgents() throws {
        var game = career()
        let ids = Array(game.clubRoster.prefix(3).map(\.id))
        XCTAssertEqual(ids.count, 3)
        for id in ids {
            let index = try XCTUnwrap(game.players.firstIndex { $0.id == id })
            game.players[index].contract.endSeason = game.season
        }
        game.players[try XCTUnwrap(game.players.firstIndex { $0.id == ids[1] })].parentTeamID = 1
        game.players[try XCTUnwrap(game.players.firstIndex { $0.id == ids[2] })].contract.endSeason = 0
        game.matchDayIndex = FootballSeason.matchDaysPerSeason - 1
        XCTAssertTrue(game.agenda.contains { $0.id == "contract-\(ids[0])" })
        XCTAssertFalse(game.agenda.contains { $0.id == "contract-\(ids[1])" || $0.id == "contract-\(ids[2])" })
        XCTAssertFalse(game.agendaExpiringOnNextAdvance.contains { $0.kind == .contract })
    }

    func testBatchReturnsBeforeConsumingPriorityAndReportsActualProgress() throws {
        var game = career()
        let athlete = try XCTUnwrap(game.clubRoster.first)
        game.offers = [TransferOffer(id: 77, playerID: athlete.id, clubID: 1, amount: 100_000, expiresAfterRound: 1)]
        let before = game
        let stopped = game.simulateUntilAgendaDecision()
        XCTAssertEqual(stopped.days, 0)
        XCTAssertTrue(stopped.reason.contains("Prioridade na agenda"))
        XCTAssertEqual(game, before)
        game.offers = []
        game.world.events.pending = []
        let day = game.worldDay
        let result = game.simulateUntilAgendaDecision(maxDays: 1)
        XCTAssertEqual(result.days, game.worldDay - day)
        XCTAssertEqual(result.days, 1)
    }
}
