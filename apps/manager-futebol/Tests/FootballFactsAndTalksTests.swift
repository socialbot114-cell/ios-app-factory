import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballFactsAndTalksTests: XCTestCase {
    private func makeCareer(seed: Int = 41) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    private func benched(_ career: FootballCareer) throws -> FootballPlayer {
        try XCTUnwrap(career.clubRoster.filter { !career.startingXI.contains($0.id) && !$0.isYouth }.first)
    }

    // MARK: F1 — fatos, canais e estados

    func testFactsAreRecordedOnceAndRetentionIsBounded() {
        var career = makeCareer()
        let fact = WorldFact(id: "f-1", source: .match, worldDay: 3, title: "Título", detail: "Detalhe")
        XCTAssertTrue(career.recordFact(fact))
        XCTAssertFalse(career.recordFact(fact), "Repetir o comando não duplica")
        XCTAssertEqual(career.factStore.facts.count, 1)
        for index in 0..<(FactStore.limit + 20) {
            career.recordFact(WorldFact(id: "bulk-\(index)", source: .match, worldDay: index, title: "x", detail: "y"))
        }
        XCTAssertEqual(career.factStore.facts.count, FactStore.limit)
        XCTAssertNil(career.fact("f-1"), "Os mais antigos saem primeiro")
        XCTAssertNotNil(career.fact("bulk-\(FactStore.limit + 19)"))
    }

    func testOneFactReachesInboxAndSocialWithTheSameIDOnlyOnce() throws {
        var career = makeCareer()
        let id = try benched(career).id
        career.recordFact(WorldFact(id: "pilot-1", source: .promise, worldDay: 5, title: "Caso piloto", detail: "O fato chega a todos os canais.",
                                    playerIDs: [id], reliability: .rumor, isPublic: true))
        let first = career.deliverFact("pilot-1", inbox: .news, social: true)
        XCTAssertTrue(first.inbox && first.social)
        let second = career.deliverFact("pilot-1", inbox: .news, social: true)
        XCTAssertFalse(second.inbox || second.social)
        XCTAssertEqual(career.inbox.filter { $0.sourceFactID == "pilot-1" }.count, 1)
        let post = try XCTUnwrap(career.world.social.posts.first { $0.sourceFactID == "pilot-1" })
        XCTAssertEqual(post.reliability, "rumor")
        XCTAssertEqual(post.author, .fan, "Boato não vira apuração de jornalista")
        XCTAssertTrue(post.text.contains("boato"))

        // Depois de salvar e carregar, o mesmo fato não se repete.
        var loaded = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        let again = loaded.deliverFact("pilot-1", inbox: .news, social: true)
        XCTAssertFalse(again.inbox || again.social)
        XCTAssertEqual(loaded.inbox.filter { $0.sourceFactID == "pilot-1" }.count, 1)
    }

    func testReadResolvedAndDismissedAreDifferentStates() throws {
        var career = makeCareer()
        let id = try benched(career).id
        career.addInbox(.news, title: "Aviso", body: "Só informa")
        career.addInbox(.playerPlayingTime, title: "Pedido", body: "Quero jogar", playerID: id)
        let notice = try XCTUnwrap(career.inbox.first { $0.title == "Aviso" })
        let request = try XCTUnwrap(career.inbox.first { $0.title == "Pedido" })
        XCTAssertEqual(career.messageState(notice), .unread)
        career.markMessageRead(id: notice.id)
        XCTAssertEqual(career.messageState(try XCTUnwrap(career.inbox.first { $0.id == notice.id })), .read)
        XCTAssertFalse(career.dismissMessage(id: request.id), "Pedido aberto não pode ser dispensado")
        XCTAssertTrue(career.dismissMessage(id: notice.id))
        XCTAssertFalse(career.dismissMessage(id: notice.id), "Dispensar de novo não faz nada")
        XCTAssertEqual(career.messageState(try XCTUnwrap(career.inbox.first { $0.id == notice.id })), .dismissed)
        career.dismissRequest(playerID: id)
        let resolved = try XCTUnwrap(career.inbox.first { $0.id == request.id })
        XCTAssertEqual(career.messageState(resolved), .resolved)
        XCTAssertNotEqual(career.messageState(resolved), .dismissed)
    }

    func testCommitmentsConcludeOnceAndExpireInOrder() {
        var career = makeCareer()
        let a = career.openCommitment(kind: .boardRequest, days: 3, title: "A", detail: "")
        let b = career.openCommitment(kind: .boardRequest, days: 1, title: "B", detail: "")
        let c = career.openCommitment(kind: .boardRequest, days: 1, title: "C", detail: "")
        XCTAssertTrue(career.resolveCommitment(id: a.id, as: .fulfilled))
        XCTAssertFalse(career.resolveCommitment(id: a.id, as: .broken), "Conclusão única")
        XCTAssertFalse(career.resolveCommitment(id: a.id, as: .open))
        career.matchDayIndex += 2
        let expired = career.expireDueCommitments()
        XCTAssertEqual(expired.map(\.id), [b.id, c.id], "Por prazo e depois por ID")
        XCTAssertTrue(career.expireDueCommitments().isEmpty, "Repetir não reexpira")
        XCTAssertEqual(career.commitments.first { $0.id == a.id }?.state, .fulfilled)
        XCTAssertEqual(career.processDueItems(), [.commitments, .negotiations], "Ordem explícita do calendário")
        XCTAssertEqual(FootballCareer.calendarProcessingOrder, [.events, .offers, .promises, .commitments, .negotiations, .contracts])
    }

    func testAgendaItemsCarryTheEntityAndShowOpenCommitments() throws {
        var career = makeCareer()
        let athlete = try benched(career)
        XCTAssertTrue(career.promiseStarts(playerID: athlete.id, starts: 2))
        let promise = try XCTUnwrap(career.agenda.first { $0.kind == .promise })
        XCTAssertEqual(promise.entityID, athlete.id)
        let commitment = career.openCommitment(kind: .followUp, playerID: athlete.id, days: 2, title: "Conversar", detail: "x")
        let item = try XCTUnwrap(career.agenda.first { $0.id == "commitment-\(commitment.id)" })
        XCTAssertEqual(item.entityID, athlete.id)
        XCTAssertEqual(item.kind, .commitment)
        career.resolveCommitment(id: commitment.id, as: .cancelled)
        XCTAssertNil(career.agenda.first { $0.id == "commitment-\(commitment.id)" })
    }

    // MARK: F3 — memória e interesses

    func testMemoryShapesTrustAndFadesWithTime() throws {
        var career = makeCareer()
        let id = try benched(career).id
        XCTAssertEqual(career.trust(of: id), 0)
        XCTAssertTrue(career.recordMemory(playerID: id, kind: .promiseBroken, id: "m1"))
        XCTAssertFalse(career.recordMemory(playerID: id, kind: .promiseBroken, id: "m1"))
        XCTAssertEqual(career.trust(of: id), -20)
        career.recordMemory(playerID: id, kind: .promiseKept, id: "m2")
        XCTAssertEqual(career.trust(of: id), -8)
        career.matchDayIndex += 300
        XCTAssertEqual(career.trust(of: id), -2, "Memória antiga pesa menos, mas não some")
        for index in 0..<30 { career.recordMemory(playerID: id, kind: .meetingHeld, id: "bulk-\(index)") }
        XCTAssertLessThanOrEqual(career.memories(of: id).count, FootballCareer.memoryPerPlayerLimit)
    }

    func testInterestsAreStableObservableAndDifferentBetweenAthletes() throws {
        let career = makeCareer()
        let roster = career.clubRoster
        let first = try XCTUnwrap(roster.first)
        XCTAssertEqual(career.interests(of: first), career.interests(of: first))
        XCTAssertEqual(career.topInterest(of: first), career.topInterest(of: first))
        let tops = Set(roster.map { career.topInterest(of: $0) })
        XCTAssertGreaterThan(tops.count, 1, "Atletas diferentes valorizam coisas diferentes")
        XCTAssertFalse(career.topInterest(of: first).label.isEmpty)
    }

    func testTrustAndInterestChangeTheAskingWage() throws {
        var career = makeCareer()
        let id = try XCTUnwrap(career.clubRoster.first?.id)
        let neutral = try XCTUnwrap(career.contractAsk(playerID: id)).wage
        career.recordMemory(playerID: id, kind: .promiseKept, id: "k1")
        career.recordMemory(playerID: id, kind: .renewalAgreed, id: "k2")
        let trusting = try XCTUnwrap(career.contractAsk(playerID: id)).wage
        XCTAssertLessThanOrEqual(trusting, neutral)
        var distrust = makeCareer()
        distrust.recordMemory(playerID: id, kind: .promiseBroken, id: "b1")
        distrust.recordMemory(playerID: id, kind: .promiseBroken, id: "b2")
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(distrust.contractAsk(playerID: id)).wage, neutral)
        var broke = makeCareer()
        broke.transferBudget = -1_000_000
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(broke.contractAsk(playerID: id)).wage, neutral, "Clube no vermelho paga mais caro")
    }

    // MARK: F3 — negociação por etapas

    func testRenewalTalkGoesThroughConsultationProposalCounterAndAgreement() throws {
        var career = makeCareer()
        let athlete = try XCTUnwrap(career.clubRoster.first)
        let talk = try XCTUnwrap(career.startRenewalTalk(playerID: athlete.id))
        XCTAssertEqual(talk.stage, .consultation)
        XCTAssertNil(career.startRenewalTalk(playerID: athlete.id), "Uma conversa aberta por atleta")
        XCTAssertTrue(career.inbox.contains { $0.sourceFactID == "talk-\(talk.id)-open" })

        let low = Int(Double(talk.askWage) * 0.92 / 5_000) * 5_000
        let outcome = career.proposeInTalk(talkID: talk.id, wage: low, years: talk.askYears, status: talk.askStatus)
        guard case .counter(let counter) = outcome else { return XCTFail("Esperava contraproposta, veio \(outcome)") }
        let countered = try XCTUnwrap(career.talks.first { $0.id == talk.id })
        XCTAssertEqual(countered.stage, .counter)
        XCTAssertEqual(countered.counterWage, counter)
        let commitment = try XCTUnwrap(career.commitments.first { $0.id == countered.commitmentID })
        XCTAssertEqual(commitment.kind, .negotiationCounter)
        XCTAssertEqual(commitment.state, .open)
        XCTAssertTrue(career.agenda.contains { $0.id == "commitment-\(commitment.id)" })

        XCTAssertTrue(career.acceptCounter(talkID: talk.id))
        XCTAssertFalse(career.acceptCounter(talkID: talk.id), "Acordo só uma vez")
        XCTAssertEqual(career.talks.first { $0.id == talk.id }?.stage, .agreed)
        XCTAssertEqual(career.player(athlete.id)?.contract.wage, counter)
        XCTAssertEqual(career.commitments.first { $0.id == commitment.id }?.state, .fulfilled)
        XCTAssertGreaterThan(career.trust(of: athlete.id), 0, "O atleta lembra do acordo")
        XCTAssertNotNil(career.fact("talk-\(talk.id)-agreed"))
    }

    func testRenewalTalkRefusalsAndExpiry() throws {
        var career = makeCareer()
        let athlete = try XCTUnwrap(career.clubRoster.first)
        let talk = try XCTUnwrap(career.startRenewalTalk(playerID: athlete.id))
        for round in 1...FootballCareer.maxProposalRounds {
            let outcome = career.proposeInTalk(talkID: talk.id, wage: 5_000, years: 1, status: talk.askStatus)
            guard case .refused = outcome else { return XCTFail("Rodada \(round): esperava recusa") }
        }
        XCTAssertEqual(career.talks.first { $0.id == talk.id }?.stage, .refused)
        XCTAssertLessThan(career.trust(of: athlete.id), 0, "Romper a negociação deixa marca")
        guard case .notAllowed = career.proposeInTalk(talkID: talk.id, wage: 50_000, years: 1, status: talk.askStatus) else { return XCTFail("Conversa encerrada") }

        // Conversa parada vence pelo calendário, em processamento único.
        var stale = makeCareer()
        let other = try XCTUnwrap(stale.clubRoster.dropFirst().first)
        let open = try XCTUnwrap(stale.startRenewalTalk(playerID: other.id))
        stale.matchDayIndex += FootballCareer.talkLifetimeDays + 1
        XCTAssertEqual(stale.expireStaleTalks(), [open.id])
        XCTAssertTrue(stale.expireStaleTalks().isEmpty)
        XCTAssertEqual(stale.talks.first { $0.id == open.id }?.stage, .expired)
        XCTAssertNotNil(stale.startRenewalTalk(playerID: other.id), "Depois de expirar, dá para reabrir")
    }

    func testIgnoredCounterExpiresThroughTheCalendar() throws {
        var career = makeCareer()
        let athlete = try XCTUnwrap(career.clubRoster.first)
        let talk = try XCTUnwrap(career.startRenewalTalk(playerID: athlete.id))
        let low = Int(Double(talk.askWage) * 0.92 / 5_000) * 5_000
        _ = career.proposeInTalk(talkID: talk.id, wage: low, years: talk.askYears, status: talk.askStatus)
        let commitmentID = try XCTUnwrap(career.talks.first { $0.id == talk.id }?.commitmentID)
        career.matchDayIndex += FootballCareer.counterAnswerDays
        career.processDueItems()
        XCTAssertEqual(career.commitments.first { $0.id == commitmentID }?.state, .expired)
        XCTAssertEqual(career.talks.first { $0.id == talk.id }?.stage, .expired)
        XCTAssertFalse(career.acceptCounter(talkID: talk.id), "Contraproposta expirada não vale mais")
    }

    func testDistrustBlocksTheConversation() throws {
        var career = makeCareer()
        let athlete = try XCTUnwrap(career.clubRoster.first)
        for index in 0..<4 { career.recordMemory(playerID: athlete.id, kind: .promiseBroken, id: "b\(index)") }
        XCTAssertLessThanOrEqual(career.trust(of: athlete.id), -60)
        XCTAssertNotNil(career.talkBlockReason(playerID: athlete.id))
        XCTAssertNil(career.startRenewalTalk(playerID: athlete.id))
    }

    // MARK: F3 — promessa quebrada, acompanhamento e memória

    func testBrokenPromiseOpensFollowUpMemoryAndSharedFactOnce() throws {
        var career = makeCareer()
        let athlete = try benched(career)
        XCTAssertTrue(career.promiseStarts(playerID: athlete.id))
        let promiseID = try XCTUnwrap(career.promises.first?.id)
        career.matchDayIndex += 20
        career.evaluatePromises(started: [])
        XCTAssertEqual(career.inbox.last?.title, "Promessa quebrada")
        XCTAssertEqual(career.inbox.last?.sourceFactID, "promise-\(promiseID)")
        XCTAssertNotNil(career.fact("promise-\(promiseID)"))
        let decision = try XCTUnwrap(career.fact("promise-\(promiseID)"))
        XCTAssertTrue(decision.effects?.contains { $0.hasPrefix("Moral") } ?? false, "F1-02: efeitos aplicados")
        XCTAssertEqual(decision.commitmentIDs?.count, 1, "F1-02: compromisso criado")
        XCTAssertFalse(decision.nextEvents?.isEmpty ?? true, "F1-02: próximos acontecimentos")
        XCTAssertEqual(career.memories(of: athlete.id).first?.kind, .promiseBroken)
        XCTAssertLessThan(career.trust(of: athlete.id), 0)
        let followUp = try XCTUnwrap(career.commitments.first { $0.kind == .followUp && $0.playerID == athlete.id })
        XCTAssertNil(career.openBrokenPromiseFollowUp(promiseID: promiseID, playerID: athlete.id), "Um acompanhamento por promessa")
        XCTAssertEqual(career.commitments.filter { $0.kind == .followUp }.count, 1)

        let moral = career.player(athlete.id)?.morale ?? 0
        XCTAssertTrue(career.holdMeeting(commitmentID: followUp.id))
        XCTAssertFalse(career.holdMeeting(commitmentID: followUp.id))
        XCTAssertEqual(career.player(athlete.id)?.morale, min(100, moral + 6))
        XCTAssertEqual(career.commitments.first { $0.id == followUp.id }?.state, .fulfilled)
        XCTAssertTrue(career.memories(of: athlete.id).contains { $0.kind == .meetingHeld })
    }

    func testIgnoredFollowUpCostsMoraleAndMayMakeTheAthleteAskToLeave() throws {
        var career = makeCareer()
        let athlete = try benched(career)
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == athlete.id })
        career.players[index].morale = 30
        XCTAssertTrue(career.promiseStarts(playerID: athlete.id))
        let promiseID = try XCTUnwrap(career.promises.first?.id)
        let commitment = try XCTUnwrap(career.openBrokenPromiseFollowUp(promiseID: promiseID, playerID: athlete.id))
        career.players[index].morale = 30
        career.matchDayIndex += FootballCareer.followUpDays
        career.processDueItems()
        XCTAssertEqual(career.commitments.first { $0.id == commitment.id }?.state, .expired)
        XCTAssertEqual(career.player(athlete.id)?.morale, 25)
        XCTAssertTrue(career.hasOpenMessage(.playerWantsOut, playerID: athlete.id))
        XCTAssertNotNil(career.fact("followup-expired-\(commitment.id)"))
        career.processDueItems()
        XCTAssertEqual(career.player(athlete.id)?.morale, 25, "Cobra uma vez só")
    }

    // MARK: Persistência

    func testNewStateSurvivesSaveAndOldSavesGetDefaults() throws {
        var career = makeCareer()
        let athlete = try XCTUnwrap(career.clubRoster.first)
        career.recordFact(WorldFact(id: "persist", source: .match, worldDay: 1, title: "t", detail: "d"))
        career.recordMemory(playerID: athlete.id, kind: .renewalAgreed, id: "mem")
        career.openCommitment(kind: .boardRequest, days: 3, title: "c", detail: "d")
        _ = career.startRenewalTalk(playerID: athlete.id)
        let data = try JSONEncoder().encode(career)
        let loaded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertEqual(loaded.factStore, career.factStore)
        XCTAssertEqual(loaded.playerMemories, career.playerMemories)
        XCTAssertEqual(loaded.commitments, career.commitments)
        XCTAssertEqual(loaded.talks, career.talks)
        XCTAssertEqual(loaded.nextCommitmentID, career.nextCommitmentID)
        XCTAssertEqual(loaded.nextTalkID, career.nextTalkID)

        // Save antigo, sem nenhum dos campos novos.
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["factStore", "commitments", "nextCommitmentID", "playerMemories", "talks", "nextTalkID"] { object[key] = nil }
        let old = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(old.factStore.facts.isEmpty)
        XCTAssertTrue(old.commitments.isEmpty && old.talks.isEmpty && old.playerMemories.isEmpty)
        XCTAssertEqual(old.nextCommitmentID, 1)
        XCTAssertEqual(old.nextTalkID, 1)
    }

    func testCalendarJumpsAndRepeatedCommandsAreDeterministic() throws {
        func play(_ days: Int) throws -> FootballCareer {
            var career = makeCareer(seed: 77)
            let athlete = try benched(career)
            XCTAssertTrue(career.promiseStarts(playerID: athlete.id))
            for _ in 0..<days { career.simulateNextMatchDay() }
            return career
        }
        let first = try play(8)
        let second = try play(8)
        XCTAssertEqual(first.factStore, second.factStore)
        XCTAssertEqual(first.commitments, second.commitments)
        XCTAssertEqual(first.playerMemories, second.playerMemories)
        var jumped = first
        jumped.matchDayIndex += 15
        jumped.processDueItems()
        let once = jumped.commitments
        jumped.processDueItems()
        XCTAssertEqual(jumped.commitments, once, "Repetir o processamento não muda nada")
    }
}
