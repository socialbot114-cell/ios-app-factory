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

    // MARK: - MSG-04 e CON-01

    func testScheduledMeetingAnswersTheRequestAndIsChargedIfForgotten() throws {
        var career = makeCareer()
        let athlete = try benched(career)
        career.inbox = []
        career.addInbox(.playerPlayingTime, title: "Quer jogar", body: "x", playerID: athlete.id)
        let moral = career.player(athlete.id)?.morale ?? 0
        let meeting = try XCTUnwrap(career.replyWithMeeting(playerID: athlete.id))
        XCTAssertEqual(meeting.kind, .followUp)
        XCTAssertEqual(career.player(athlete.id)?.morale, min(100, moral + 2))
        let request = try XCTUnwrap(career.inbox.first { $0.title == "Quer jogar" })
        XCTAssertEqual(career.messageState(request), .answered)
        XCTAssertTrue(career.agenda.contains { $0.id == "commitment-\(meeting.id)" }, "A conversa entra na agenda")
        XCTAssertNil(career.replyWithMeeting(playerID: athlete.id), "Uma conversa marcada por atleta")

        // A mensagem de origem oferece o botão e a conversa resolve o compromisso.
        let notice = try XCTUnwrap(career.inbox.first { $0.sourceFactID == meeting.factID })
        XCTAssertEqual(career.openMeetingCommitment(for: notice)?.id, meeting.id)
        var held = career
        XCTAssertTrue(held.holdMeeting(commitmentID: meeting.id))
        XCTAssertNil(held.openMeetingCommitment(for: notice))
        XCTAssertEqual(held.commitments.first { $0.id == meeting.id }?.state, .fulfilled)

        // Esquecida: o atleta se irrita no prazo.
        career.matchDayIndex += 5
        career.processDueItems()
        XCTAssertEqual(career.commitments.first { $0.id == meeting.id }?.state, .expired)
        XCTAssertLessThan(career.player(athlete.id)?.morale ?? 100, min(100, moral + 2))
    }

    func testAgentMessagesPointToTheContactCard() throws {
        var career = makeCareer()
        career.inbox = []
        career.addInbox(.agent, title: "Empresário", body: "Tem proposta")
        let attachments = career.attachments(for: try XCTUnwrap(career.inbox.last))
        XCTAssertEqual(attachments, [.contact(.agent)])
        XCTAssertEqual(MessageAttachment.contact(.agent).id, "contact-agent")
    }
}
