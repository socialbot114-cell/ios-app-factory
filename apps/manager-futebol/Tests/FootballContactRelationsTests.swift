import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballContactRelationsTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.world.coach.energy = 90
        return career
    }

    private func contactID(_ career: FootballCareer, _ role: ContactRole) throws -> Int { try XCTUnwrap(career.contact(role)?.id) }

    // MARK: CON-03 / CON-02

    func testTopicsDependOnContextAndExplainBlocks() throws {
        var career = career()
        XCTAssertNotNil(career.topicBlocker(.agentScout), "Sem briefing, o empresário não sabe o que buscar")
        XCTAssertNotNil(career.topicBlocker(.journalistDenyRumor), "Sem boato, nada a desmentir")
        XCTAssertNotNil(career.topicBlocker(.friendVent), "Sem estresse, nada a desabafar")
        career.transferBudget = 80_000_000
        XCTAssertNotNil(career.createBrief(position: .forward, maxAge: 30, minOverall: 50, maxFee: 80_000_000, maxWage: 9_000_000, role: .starter))
        XCTAssertNil(career.topicBlocker(.agentScout))
        let suggestion = try XCTUnwrap(career.agentSuggestion())
        let text = try XCTUnwrap(career.talk(.agentScout))
        XCTAssertTrue(text.contains(suggestion.name))
        XCTAssertTrue(career.watchlist.contains(suggestion.id))
        let history = career.contactHistory(try contactID(career, .agent))
        XCTAssertEqual(history.last?.title, ContactTopic.agentScout.title, "Conversa fica no histórico")
        XCTAssertNotNil(career.topicBlocker(.journalistExclusive), "Uma conversa por dia de jogo continua valendo")
        XCTAssertEqual(career.contactInterests(try XCTUnwrap(career.contact(.agent))).count, 2)
        XCTAssertEqual(career.contactInterests(try XCTUnwrap(career.contact(.agent))), career.contactInterests(try XCTUnwrap(career.contact(.agent))),
                       "Interesses estáveis")
    }

    func testDenyingARumorPublishesItAndCostsJournalistGoodwill() throws {
        var career = career()
        career.recordFact(WorldFact(id: "race-99", source: .market, worldDay: career.worldDay, title: "Rival quer o seu craque",
                                    detail: "Boato.", reliability: .rumor, isPublic: true))
        career.world.social.controversy = 40
        let before = career.relationship(.journalist)
        XCTAssertNotNil(career.talk(.journalistDenyRumor))
        XCTAssertNotNil(career.fact("race-99-denied"))
        XCTAssertEqual(career.relationship(.journalist), before - 2)
        XCTAssertEqual(career.world.social.controversy, 30)
        XCTAssertNil(career.latestRumor(), "Boato desmentido não volta à pauta")
    }

    func testFamilyPromiseUsesThePersonalAgendaAndIsJudged() throws {
        var kept = career()
        let day = try XCTUnwrap(kept.familyPromiseDay())
        XCTAssertNotNil(kept.talk(.familyPromise))
        XCTAssertTrue(kept.world.projects.personalPlan.contains { $0.worldDay == day && $0.activity == .rest })
        let familyBefore = kept.relationship(.family)
        while kept.worldDay <= day + 1, kept.simulateNextMatchDay() {}
        let promise = try XCTUnwrap(kept.world.projects.contactRelations.requests.first { $0.kind == .familyPromise })
        XCTAssertEqual(promise.status, .fulfilled)
        XCTAssertGreaterThan(kept.relationship(.family), familyBefore - 3)

        var broken = career()
        let brokenDay = try XCTUnwrap(broken.familyPromiseDay())
        XCTAssertNotNil(broken.talk(.familyPromise))
        broken.unplanActivity(on: brokenDay)
        while broken.worldDay <= brokenDay + 1, broken.simulateNextMatchDay() {}
        XCTAssertEqual(broken.world.projects.contactRelations.requests.first { $0.kind == .familyPromise }?.status, .broken)
        XCTAssertTrue(broken.contactHistory(try contactID(broken, .family)).contains { $0.title == "Faltou à folga prometida" })
    }

    // MARK: CON-04

    func testRequestsCanBeAcceptedDeclinedOrIgnored() throws {
        var career = career()
        let friend = try contactID(career, .friend)
        let president = try contactID(career, .president)
        let journalist = try contactID(career, .journalist)
        career.world.coach.personalCash = 500_000
        career.world.projects.contactRelations.requests = [
            ContactRequest(id: 1, contactID: friend, kind: .friendLoan, createdWorldDay: career.worldDay, deadlineWorldDay: career.worldDay + 3, amount: 50_000),
            ContactRequest(id: 2, contactID: president, kind: .presidentEvent, createdWorldDay: career.worldDay, deadlineWorldDay: career.worldDay + 3),
            ContactRequest(id: 3, contactID: journalist, kind: .journalistInterview, createdWorldDay: career.worldDay, deadlineWorldDay: career.worldDay + 3)
        ]
        career.world.projects.contactRelations.nextID = 4
        XCTAssertNotNil(career.answerContactRequest(1, accept: true))
        XCTAssertEqual(career.world.coach.personalCash, 450_000)
        let confidence = career.boardConfidence
        XCTAssertNotNil(career.answerContactRequest(2, accept: true))
        XCTAssertEqual(career.boardConfidence, min(100, confidence + 2))
        XCTAssertNil(career.answerContactRequest(2, accept: true), "Responde uma vez só")

        let journalistBefore = career.relationship(.journalist)
        career.matchDayIndex += 3
        career.settleContactRequests()
        XCTAssertEqual(career.world.projects.contactRelations.requests.first { $0.id == 3 }?.status, .ignored)
        XCTAssertEqual(career.relationship(.journalist), journalistBefore - 3)

        career.matchDayIndex += 7
        let cash = career.world.coach.personalCash
        career.settleContactRequests()
        XCTAssertEqual(career.world.coach.personalCash, cash + 52_500, "Amigo devolve com 5% de agradecimento")
        XCTAssertEqual(career.world.projects.contactRelations.requests.first { $0.id == 1 }?.status, .fulfilled)
    }

    func testRequestsArriveOverTimeAndRespectLimits() {
        var career = career()
        for index in career.world.contacts.contacts.indices { career.world.contacts.contacts[index].relationship = 80 }
        for _ in 0..<18 { _ = career.simulateNextMatchDay() }
        let all = career.world.projects.contactRelations.requests
        XCTAssertFalse(all.isEmpty, "Contatos próximos trazem pedidos")
        XCTAssertLessThanOrEqual(career.openContactRequests().count, 2)
        XCTAssertTrue(career.inbox.contains { message in message.kind == .general && ContactRole.allCases.contains { message.title.hasPrefix($0.title) } })
    }

    // MARK: CON-05 / CON-06

    func testEffectsAreExplainedAndPresidentWeighsOnTheBoard() throws {
        var career = career()
        career.world.contacts.contacts[career.world.contacts.contacts.firstIndex { $0.role == .agent }!].relationship = 100
        XCTAssertTrue(career.relationshipEffects(.agent).first?.contains("6%") ?? false)
        let presidentIndex = career.world.contacts.contacts.firstIndex { $0.role == .president }!
        career.world.contacts.contacts[presidentIndex].relationship = 100
        let warm = career.boardScore(.budgetBoost, noise: 0)
        career.world.contacts.contacts[presidentIndex].relationship = 0
        let cold = career.boardScore(.budgetBoost, noise: 0)
        XCTAssertEqual(warm - cold, 10, "Presidente vai de −5 a +5 na decisão")
        XCTAssertTrue(career.relationshipEffects(.president).contains { $0.contains("Reunião de diretoria") })
    }

    func testNewClubBringsNewPresidentButFamilyStays() throws {
        var career = career()
        let president = try XCTUnwrap(career.contact(.president))
        let family = try XCTUnwrap(career.contact(.family))
        let agentIndex = try XCTUnwrap(career.world.contacts.contacts.firstIndex { $0.role == .agent })
        career.world.contacts.contacts[agentIndex].relationship = 90
        let agent = career.world.contacts.contacts[agentIndex]
        XCTAssertTrue(career.resign())
        let job = try XCTUnwrap(career.jobOffers.first)
        XCTAssertTrue(career.acceptJob(job.id))
        XCTAssertNotEqual(career.contact(.president)?.name, president.name)
        XCTAssertEqual(career.contact(.president)?.id, president.id)
        XCTAssertEqual(career.contact(.family), family, "Família continua igual")
        XCTAssertEqual(career.contact(.agent)?.name, agent.name, "Empresário com boa relação acompanha")
        XCTAssertTrue(career.contactHistory(president.id).contains { $0.title == "Novo presidente" })
    }

    func testLegacyProjectsWithoutRelationsLoad() throws {
        let career = career()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(json["world"] as? [String: Any])
        var projects = try XCTUnwrap(world["projects"] as? [String: Any])
        projects.removeValue(forKey: "contactRelations")
        world["projects"] = projects
        json["world"] = world
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.world.projects.contactRelations.history.isEmpty)
    }
}
