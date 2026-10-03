import XCTest
@testable import ManagerFutebol

final class FootballContactsTests: XCTestCase {
    private func started() -> FootballCareer {
        var career = FootballCareer(seed: 26)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    func testSixContactsOneOfEachRoleDeterministic() {
        let career = started()
        XCTAssertEqual(career.world.contacts.contacts.map(\.role), ContactRole.allCases)
        XCTAssertEqual(career.world.contacts.contacts, started().world.contacts.contacts)
        XCTAssertTrue(career.world.contacts.contacts.allSatisfy { (0...100).contains($0.relationship) && !$0.name.isEmpty })
    }

    func testOneConversationPerDayAndCostsEnergy() {
        var career = started()
        let energy = career.world.coach.energy
        XCTAssertNotNil(career.contactAction(.agent))
        XCTAssertEqual(energy - career.world.coach.energy, 6)
        XCTAssertNotNil(career.canContact(.friend))
        XCTAssertNil(career.contactAction(.friend))
        career.matchDayIndex += 1
        XCTAssertNil(career.canContact(.friend))
    }

    func testRelationshipGrowsAndCapsAtHundred() {
        var career = started()
        for _ in 0..<40 {
            career.world.coach.energy = 80
            career.contactAction(.president)
            career.matchDayIndex += 1
        }
        XCTAssertEqual(career.relationship(.president), 100)
    }

    func testPerksReflectRelationships() {
        var career = started()
        let player = career.players.first { $0.teamID != nil && $0.teamID != 0 }!
        career.world.contacts.contacts[ContactRole.allCases.firstIndex(of: .agent)!].relationship = 40
        let normal = career.askingPrice(for: player)
        career.world.contacts.contacts[ContactRole.allCases.firstIndex(of: .agent)!].relationship = 100
        XCTAssertLessThan(career.askingPrice(for: player), normal)
        XCTAssertEqual(career.agentDiscount, 0.06, accuracy: 0.0001)
        career.world.contacts.contacts[ContactRole.allCases.firstIndex(of: .president)!].relationship = 100
        XCTAssertEqual(career.presidentPatience, 4)
    }

    func testFamilyActionRelievesStressAndNeglectDecays() {
        var career = started()
        career.world.coach.stress = 60
        career.contactAction(.family)
        XCTAssertEqual(career.world.coach.stress, 48)
        let before = career.relationship(.mentor)
        career.matchDayIndex += 12
        career.tickContacts()
        XCTAssertLessThan(career.relationship(.mentor), before)
    }

    func testOldSaveWithoutContactsDecodes() throws {
        let career = started()
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as! [String: Any]
        var world = json["world"] as! [String: Any]
        world["contacts"] = nil
        json["world"] = world
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertTrue(decoded.world.contacts.contacts.isEmpty)
    }

    func testLendToClubMovesMoneyAndHelpsBoardWhenInDebt() {
        var career = started()
        career.world.coach.personalCash = 400_000
        let club = career.transferBudget
        XCTAssertFalse(career.lendToClub(amount: 500_000))
        XCTAssertFalse(career.lendToClub(amount: 10_000))
        career.transferBudget = -300_000
        let confidence = career.boardConfidence
        XCTAssertTrue(career.lendToClub(amount: 200_000))
        XCTAssertEqual(career.world.coach.personalCash, 200_000)
        XCTAssertEqual(career.transferBudget, -100_000)
        XCTAssertGreaterThan(career.boardConfidence, confidence)
        _ = club
    }

    func testResolveInboxMessage() {
        var career = started()
        career.addInbox(.general, title: "Teste", body: "x")
        let id = career.inbox.last!.id
        career.resolveInboxMessage(id: id)
        XCTAssertTrue(career.inbox.last!.isResolved && career.inbox.last!.isRead)
    }
}
