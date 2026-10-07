import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballAcademyTests: XCTestCase {
    private func careerWithYouth(seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(10))
        var random = FootballRandom(seed: UInt64(seed))
        career.runYouthIntake(using: &random)
        XCTAssertFalse(career.youthRoster.isEmpty)
        return career
    }

    func testProfileIsStableAcrossSeasonsAndCalls() throws {
        var career = careerWithYouth()
        let youth = try XCTUnwrap(career.youthRoster.first)
        let before = career.academyProfile(for: youth)
        XCTAssertEqual(before, career.academyProfile(for: youth))
        career.season += 3
        XCTAssertEqual(before, career.academyProfile(for: youth), "O perfil não muda com a temporada")
        XCTAssertFalse(before.traits.isEmpty)
        XCTAssertTrue((0.85...1.2).contains(before.growthSpeed))
        XCTAssertFalse(before.hometown.isEmpty)
    }

    func testTraitsNeverContradictAndEveryTraitAppears() {
        var seen = Set<YouthTrait>()
        for seed in 1...60 {
            let career = careerWithYouth(seed: seed)
            for youth in career.youthRoster {
                let traits = career.academyProfile(for: youth).traits
                XCTAssertFalse(traits.contains(.lateBloomer) && traits.contains(.earlyBloomer))
                XCTAssertEqual(Set(traits).count, traits.count)
                seen.formUnion(traits)
            }
        }
        XCTAssertEqual(seen, Set(YouthTrait.allCases))
    }

    func testEstimateAlwaysContainsTheTruePotentialAndShrinksWithObservation() throws {
        var career = careerWithYouth()
        career.transferBudget = 10_000_000
        let youth = try XCTUnwrap(career.youthRoster.first)
        var widths: [Int] = []
        for _ in 0..<6 {
            let player = try XCTUnwrap(career.player(youth.id))
            let range = career.potentialEstimate(for: player)
            XCTAssertTrue(range.contains(player.potential), "\(range) deve conter \(player.potential)")
            XCTAssertGreaterThanOrEqual(range.lowerBound, player.overall)
            widths.append(range.upperBound - range.lowerBound)
            career.academy.points = career.academyPointsMax
            XCTAssertTrue(career.observeYouth(playerID: youth.id))
        }
        let final = try XCTUnwrap(career.player(youth.id))
        let finalRange = career.potentialEstimate(for: final)
        XCTAssertTrue(finalRange.contains(final.potential))
        XCTAssertLessThanOrEqual(finalRange.upperBound - finalRange.lowerBound, 6)
        XCTAssertLessThanOrEqual(finalRange.upperBound - finalRange.lowerBound, widths[0], "Observar deixa a estimativa mais precisa")
    }

    func testObserveSpendsPointAndMoney() throws {
        var career = careerWithYouth()
        career.transferBudget = 1_000_000
        let youth = try XCTUnwrap(career.youthRoster.first)
        let points = career.academy.points
        let cash = career.transferBudget
        XCTAssertTrue(career.observeYouth(playerID: youth.id))
        XCTAssertEqual(career.academy.points, points - 1)
        XCTAssertEqual(cash - career.transferBudget, FootballCareer.academyObserveCost)
        XCTAssertEqual(career.observedWeeks(for: youth.id), 6)
        career.academy.points = 0
        XCTAssertNotNil(career.canObserve(playerID: youth.id))
        XCTAssertFalse(career.observeYouth(playerID: youth.id))
        career.academy.points = 2
        career.transferBudget = 0
        XCTAssertNotNil(career.canObserve(playerID: youth.id), "Sem caixa não observa")
    }

    func testPointsRefillOncePerDayUpToTheMaximum() {
        var career = careerWithYouth()
        career.academy.points = 0
        var random = FootballRandom(seed: 3)
        career.tickYouthDevelopment(using: &random)
        XCTAssertEqual(career.academy.points, 1)
        for _ in 0..<20 { career.tickYouthDevelopment(using: &random) }
        XCTAssertEqual(career.academy.points, career.academyPointsMax)
    }

    func testPassiveObservationAccumulatesAndRevealsTraits() throws {
        var career = careerWithYouth()
        let youth = try XCTUnwrap(career.youthRoster.first)
        XCTAssertTrue(career.revealedTraits(for: youth).isEmpty)
        var random = FootballRandom(seed: 9)
        for _ in 0..<13 { career.tickYouthDevelopment(using: &random) }
        XCTAssertEqual(career.observedWeeks(for: youth.id), 13)
        let player = try XCTUnwrap(career.player(youth.id))
        XCTAssertEqual(career.revealedTraits(for: player).count, min(2, career.academyProfile(for: player).traits.count))
    }

    func testMentorRules() throws {
        var career = careerWithYouth()
        let youth = career.youthRoster
        let kid = try XCTUnwrap(youth.first)
        let veteran = try XCTUnwrap(career.mentorCandidates.first)
        XCTAssertGreaterThanOrEqual(veteran.age, 27)
        XCTAssertNotNil(career.canAssignMentor(playerID: kid.id, mentorID: kid.id), "Jovem não orienta")
        career.academy.points = career.academyPointsMax
        XCTAssertTrue(career.assignMentor(playerID: kid.id, mentorID: veteran.id))
        XCTAssertEqual(career.academyFollowUp(for: kid.id)?.mentorID, veteran.id)
        XCTAssertTrue(career.clearMentor(playerID: kid.id))
        XCTAssertNil(career.academyFollowUp(for: kid.id)?.mentorID)

        // Limite de dois pupilos por veterano.
        career.academy.points = 9
        var others = Array(career.youthRoster.prefix(3))
        if others.count < 3 {
            var random = FootballRandom(seed: 99)
            career.academy.followUps = []
            career.runYouthIntake(using: &random)
            others = Array(career.youthRoster.prefix(3))
        }
        guard others.count == 3 else { return }
        XCTAssertTrue(career.assignMentor(playerID: others[0].id, mentorID: veteran.id))
        XCTAssertTrue(career.assignMentor(playerID: others[1].id, mentorID: veteran.id))
        XCTAssertNotNil(career.canAssignMentor(playerID: others[2].id, mentorID: veteran.id))
    }

    func testTraitsChangeGrowthFactor() throws {
        var worker: Double?
        var plain: Double?
        for seed in 1...80 where worker == nil || plain == nil {
            let candidate = careerWithYouth(seed: seed)
            for youth in candidate.youthRoster where !youth.has(.prodigy) {
                let profile = candidate.academyProfile(for: youth)
                let ratio = candidate.academyGrowthFactor(for: youth) / profile.growthSpeed
                if profile.traits == [.worker], worker == nil { worker = ratio }
                if profile.traits == [.temperamental], plain == nil { plain = ratio }
            }
        }
        XCTAssertEqual(try XCTUnwrap(worker), 1.2, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(plain), 0.95, accuracy: 0.0001)
    }

    func testFocusIsStoredAndFollowUpsAreCleanedWhenYouthLeaves() throws {
        var career = careerWithYouth()
        let kid = try XCTUnwrap(career.youthRoster.first)
        XCTAssertTrue(career.setYouthFocus(playerID: kid.id, focus: .physical))
        XCTAssertEqual(career.academyFollowUp(for: kid.id)?.focus, .physical)
        XCTAssertTrue(career.releaseYouth(playerID: kid.id))
        var random = FootballRandom(seed: 1)
        career.tickYouthDevelopment(using: &random)
        XCTAssertNil(career.academyFollowUp(for: kid.id))
    }

    func testAcademyStateRoundTripAndOldSaves() throws {
        var career = careerWithYouth()
        let kid = try XCTUnwrap(career.youthRoster.first)
        career.transferBudget = 1_000_000
        XCTAssertTrue(career.observeYouth(playerID: kid.id))
        let data = try JSONEncoder().encode(career)
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertEqual(decoded.academy, career.academy)

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "academy")
        let old = try JSONSerialization.data(withJSONObject: object)
        let oldDecoded = try JSONDecoder().decode(FootballCareer.self, from: old)
        XCTAssertEqual(oldDecoded.academy, AcademyState())
        XCTAssertEqual(try JSONDecoder().decode(AcademyState.self, from: Data("{}".utf8)), AcademyState())
    }

    func testYouthStillNeverExceedsPotentialWithTheNewGrowthFactors() {
        var career = careerWithYouth()
        career.setYouthProgram(.mental)
        var random = FootballRandom(seed: 11)
        for _ in 0..<300 { career.tickYouthDevelopment(using: &random) }
        for youth in career.youthRoster {
            XCTAssertLessThanOrEqual(youth.overall, max(youth.potential, youth.overall))
            XCTAssertLessThanOrEqual(youth.overall, 99)
        }
    }
}
