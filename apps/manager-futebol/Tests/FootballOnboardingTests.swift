import XCTest
@testable import ManagerFutebol

final class FootballOnboardingTests: XCTestCase {
    func testSixOffersFromDistinctClubsAndDeterministic() {
        let career = FootballCareer(seed: 26)
        let offers = career.careerOffers()
        XCTAssertEqual(offers.count, 6)
        XCTAssertEqual(Set(offers.map(\.clubID)).count, 6)
        XCTAssertEqual(offers, FootballCareer(seed: 26).careerOffers())
        XCTAssertNotEqual(offers.map(\.clubID), FootballCareer(seed: 99).careerOffers().map(\.clubID))
    }

    func testOffersSpanStrengthBandsAndHaveSaneTerms() {
        for seed in [26, 5, 1234] {
            let offers = FootballCareer(seed: seed).careerOffers()
            let strengths = offers.map { FootballSeason.team($0.clubID)!.strength }
            XCTAssertGreaterThan((strengths.max() ?? 0) - (strengths.min() ?? 0), 6)
            for offer in offers {
                XCTAssertTrue((1...5).contains(offer.difficulty))
                XCTAssertTrue((1...3).contains(offer.contractSeasons))
                XCTAssertGreaterThan(offer.budget, 0)
                XCTAssertTrue((35...75).contains(offer.fanMood))
                XCTAssertFalse(offer.pitch.isEmpty)
            }
        }
    }

    func testAcceptingOfferAppliesTermsAndName() {
        var career = FootballCareer(seed: 26)
        let offer = career.careerOffers()[2]
        XCTAssertTrue(career.acceptCareerOffer(clubID: offer.clubID, coachName: "  Zé da Tática  "))
        XCTAssertEqual(career.world.coach.name, "Zé da Tática")
        XCTAssertEqual(career.selectedClubID, offer.clubID)
        XCTAssertEqual(career.transferBudget, offer.budget)
        XCTAssertEqual(career.boardTarget, offer.boardTarget)
        XCTAssertEqual(career.boardConfidence, offer.startingConfidence)
        XCTAssertEqual(career.fanMood, offer.fanMood)
        XCTAssertEqual(career.world.coach.contract?.seasons, offer.contractSeasons)
        XCTAssertGreaterThanOrEqual(career.world.coach.personalCash, 150_000 + offer.signingBonus)
        XCTAssertEqual(career.firstCareerGuideStep, .welcome, "O roteiro prático começa depois do primeiro contrato")
        XCTAssertFalse(career.acceptCareerOffer(clubID: offer.clubID, coachName: "Outro"))
    }

    func testFirstCareerGuidePersistsTransitionsSkipsAndCanReplay() throws {
        var career = FootballCareer(seed: 26)
        XCTAssertNil(career.firstCareerGuideStep, "Carreira sem clube ainda não iniciou o roteiro")
        let offer = career.careerOffers()[0]
        XCTAssertTrue(career.acceptCareerOffer(clubID: offer.clubID, coachName: "Treinadora"))
        XCTAssertTrue(career.isFirstCareerGuideActive)

        XCTAssertTrue(career.advanceFirstCareerGuide(from: .welcome, to: .manager))
        XCTAssertFalse(career.advanceFirstCareerGuide(from: .welcome, to: .tactics), "Toque repetido não deve pular uma etapa")
        XCTAssertTrue(career.advanceFirstCareerGuide(from: .manager, to: .tactics))

        let data = try JSONEncoder().encode(career)
        var restored = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertEqual(restored.firstCareerGuideStep, .tactics)
        restored.skipFirstCareerGuide()
        XCTAssertFalse(restored.isFirstCareerGuideActive)
        restored.replayFirstCareerGuide()
        XCTAssertEqual(restored.firstCareerGuideStep, .welcome)
    }

    func testFirstCareerGuideFinishesOnlyAfterTheRecap() {
        var career = FootballCareer(seed: 26)
        let offer = career.careerOffers()[0]
        XCTAssertTrue(career.acceptCareerOffer(clubID: offer.clubID, coachName: "Treinador"))
        XCTAssertFalse(career.finishFirstCareerGuide(), "Não conclui antes de chegar ao resumo")

        XCTAssertTrue(career.advanceFirstCareerGuide(from: .welcome, to: .manager))
        XCTAssertTrue(career.advanceFirstCareerGuide(from: .manager, to: .tactics))
        XCTAssertTrue(career.advanceFirstCareerGuide(from: .tactics, to: .match))
        XCTAssertTrue(career.advanceFirstCareerGuide(from: .match, to: .liveMatch))
        XCTAssertTrue(career.advanceFirstCareerGuide(from: .liveMatch, to: .recap))
        XCTAssertTrue(career.finishFirstCareerGuide())
        XCTAssertEqual(career.firstCareerGuideStep, .finished)
        XCTAssertFalse(career.isFirstCareerGuideActive)
    }

    func testOlderCareerSaveDefaultsToNoFirstRunGuide() throws {
        let career = FootballCareer(seed: 26)
        let data = try JSONEncoder().encode(career)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "firstCareerGuideStep")
        legacy["schemaVersion"] = 12
        let restored = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(restored.firstCareerGuideStep)
        XCTAssertFalse(restored.isFirstCareerGuideActive)
    }

    func testEmptyNameFallsBackAndNameIsTrimmedToLimit() {
        var career = FootballCareer(seed: 26)
        let id = career.careerOffers()[0].clubID
        XCTAssertTrue(career.acceptCareerOffer(clubID: id, coachName: String(repeating: "A", count: 80)))
        XCTAssertEqual(career.world.coach.name.count, FootballCareer.coachNameLimit)
        var other = FootballCareer(seed: 26)
        XCTAssertTrue(other.acceptCareerOffer(clubID: id, coachName: "   "))
        XCTAssertEqual(other.world.coach.name, "Treinador")
    }

    func testOfferNotInListIsRejected() {
        var career = FootballCareer(seed: 26)
        let offered = Set(career.careerOffers().map(\.clubID))
        let other = FootballSeason.teams.first { !offered.contains($0.id) }!.id
        XCTAssertFalse(career.acceptCareerOffer(clubID: other, coachName: "X"))
        XCTAssertNil(career.selectedClubID)
    }

    func testSeveranceAndSaveRoundTrip() throws {
        var career = FootballCareer(seed: 26)
        let id = career.careerOffers()[1].clubID
        XCTAssertTrue(career.acceptCareerOffer(clubID: id, coachName: "Teste"))
        let data = try JSONEncoder().encode(career)
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertEqual(decoded.world.coach.contract, career.world.coach.contract)
        XCTAssertEqual(decoded.world.coach.name, "Teste")
        let before = career.world.coach.personalCash
        career.payContractSeverance()
        XCTAssertGreaterThan(career.world.coach.personalCash, before)
        XCTAssertNil(career.world.coach.contract)
    }

    func testOldCoachProfileWithoutContractStillDecodes() throws {
        let json = #"{"name":"Treinador","personalCash":150000,"energy":80,"stress":20,"licenseLevel":1,"assets":[],"investments":[],"lastActivityWorldDay":-1,"bookSessions":0,"booksPublished":0,"nextItemID":1}"#
        let profile = try JSONDecoder().decode(CoachProfile.self, from: Data(json.utf8))
        XCTAssertNil(profile.contract)
    }

    func testPatienceBonusMakesBoardMorePatient() {
        var career = FootballCareer(seed: 26)
        let offer = career.careerOffers()[0]
        let id = offer.clubID
        let offerBonus = offer.patienceBonus
        XCTAssertTrue(career.acceptCareerOffer(clubID: id, coachName: "T"))
        let withBonus = career.boardPatienceThreshold(for: id)
        career.world.coach.contract?.patienceBonus = 0
        let neutral = career.boardPatienceThreshold(for: id)
        XCTAssertEqual(neutral - withBonus, offerBonus)
    }
}
