import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballConversationsTests: XCTestCase {
    private func makeCareer() -> FootballCareer {
        var career = FootballCareer(seed: 41)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    private func benched(_ career: FootballCareer) throws -> FootballPlayer {
        try XCTUnwrap(career.clubRoster.filter { !career.startingXI.contains($0.id) && !$0.isYouth }.first)
    }

    func testMessagesGroupByPersonAndTopicAndCountWhatIsOpen() throws {
        var career = makeCareer()
        let athlete = try benched(career)
        career.inbox = []
        career.addInbox(.playerPlayingTime, title: "Quer jogar", body: "x", playerID: athlete.id)
        career.addInbox(.general, title: "Promessa", body: "y", playerID: athlete.id)
        career.addInbox(.news, title: "Notícia", body: "z")
        career.addInbox(.news, title: "Outra", body: "w")
        let groups = career.conversations()
        XCTAssertEqual(groups.count, 2)
        let person = try XCTUnwrap(groups.first { $0.playerID == athlete.id })
        XCTAssertEqual(person.title, athlete.name)
        XCTAssertEqual(person.messageIDs.count, 2)
        XCTAssertEqual(person.open, 1, "Só o pedido exige resposta")
        XCTAssertEqual(person.unread, 2)
        let news = try XCTUnwrap(groups.first { $0.playerID == nil })
        XCTAssertEqual(news.title, "Notícias")
        XCTAssertEqual(news.messageIDs, news.messageIDs.sorted(by: >), "Mais novas primeiro")

        career.markConversationRead(person.id)
        XCTAssertEqual(career.conversations().first { $0.id == person.id }?.unread, 0)
        XCTAssertEqual(career.conversations().first { $0.id == person.id }?.open, 1, "Ler não resolve")
        XCTAssertEqual(career.conversations().first { $0.id == news.id }?.unread, 2, "Outra conversa continua não lida")
        let noticeID = try XCTUnwrap(career.inbox.first { $0.title == "Notícia" }?.id)
        career.dismissMessage(id: noticeID)
        XCTAssertEqual(career.conversations().first { $0.id == news.id }?.messageIDs.count, 1)
    }

    func testMessageStatesDistinguishReadAnsweredResolvedAndExpired() throws {
        var career = makeCareer()
        let athlete = try benched(career)
        career.inbox = []
        career.addInbox(.playerPlayingTime, title: "Pedido", body: "x", playerID: athlete.id)
        var message = try XCTUnwrap(career.inbox.last)
        XCTAssertEqual(career.messageState(message), .unread)
        career.markMessageRead(id: message.id)
        message = try XCTUnwrap(career.inbox.last)
        XCTAssertEqual(career.messageState(message), .read)

        // Sem resposta por 3 dias de jogo: expirada, mas ainda aberta.
        career.matchDayIndex += 3
        career.escalateIgnoredRequests()
        message = try XCTUnwrap(career.inbox.last)
        XCTAssertEqual(career.messageState(message), .expired)
        XCTAssertFalse(message.isResolved)

        // Responder depois muda para respondida.
        XCTAssertTrue(career.promiseStarts(playerID: athlete.id, starts: 2))
        message = try XCTUnwrap(career.inbox.first { $0.title == "Pedido" })
        XCTAssertEqual(career.messageState(message), .answered)

        // Encerrada sem resposta própria: resolvida.
        career.addInbox(.offer, title: "Oferta", body: "o", offerID: 99)
        let offerID = try XCTUnwrap(career.inbox.last?.id)
        let index = try XCTUnwrap(career.inbox.firstIndex { $0.id == offerID })
        career.inbox[index].isResolved = true
        XCTAssertEqual(career.messageState(career.inbox[index]), .resolved)
        XCTAssertEqual(MessageState.expired.title, "SEM RESPOSTA")
    }

    func testAttachmentsPointToSheetLineupContractProposalAndOrigin() throws {
        var career = makeCareer()
        let athlete = try benched(career)
        career.inbox = []
        career.addInbox(.playerPlayingTime, title: "Pedido", body: "x", playerID: athlete.id)
        let request = try XCTUnwrap(career.inbox.last)
        XCTAssertEqual(career.attachments(for: request), [.playerSheet(athlete.id), .lineup(athlete.id)])

        career.addInbox(.playerContract, title: "Contrato", body: "x", playerID: athlete.id)
        XCTAssertTrue(career.attachments(for: try XCTUnwrap(career.inbox.last)).contains(.contract(athlete.id)))

        // Fato e compromisso de origem aparecem quando existem.
        XCTAssertTrue(career.promiseStarts(playerID: athlete.id))
        let promiseID = try XCTUnwrap(career.promises.first?.id)
        career.matchDayIndex += 20
        career.evaluatePromises(started: [])
        let outcome = try XCTUnwrap(career.inbox.first { $0.sourcePromiseID == promiseID && $0.title == "Promessa quebrada" })
        let attachments = career.attachments(for: outcome)
        XCTAssertTrue(attachments.contains(.fact("promise-\(promiseID)")))
        XCTAssertTrue(attachments.contains { if case .commitment = $0 { return true } else { return false } })
        XCTAssertEqual(Set(attachments.map(\.id)).count, attachments.count)
        XCTAssertFalse(MessageAttachment.fact("x").symbol.isEmpty)
    }
}
