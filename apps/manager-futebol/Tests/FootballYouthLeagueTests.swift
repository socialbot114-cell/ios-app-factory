import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballYouthLeagueTests: XCTestCase {
    private func started(seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(10))
        career.transferBudget = 5_000_000
        return career
    }

    func testSubFifteenExistsAndCategoryFollowsAge() {
        var sawUnder15 = false
        for seed in 1...20 {
            var career = started(seed: seed)
            var random = FootballRandom(seed: UInt64(seed))
            career.runYouthIntake(using: &random)
            for youth in career.youthRoster {
                let category = career.youthCategory(of: youth)
                if youth.age <= 15 { XCTAssertEqual(category, .under15) }
                if category == .under15 { sawUnder15 = true }
            }
        }
        XCTAssertTrue(sawUnder15, "A chegada traz jovens de 15 e 16 anos")
    }

    func testPartnershipRulesAndCancel() {
        var career = started()
        let region = ((career.selectedClub?.region ?? 0) + 1) % 5
        XCTAssertNil(career.canSignPartnership(kind: .school, region: region))
        XCTAssertTrue(career.signPartnership(kind: .school, region: region))
        XCTAssertNotNil(career.canSignPartnership(kind: .school, region: region), "Mesma parceria duas vezes não")
        XCTAssertTrue(career.signPartnership(kind: .club, region: region), "Tipo diferente na mesma região pode")
        XCTAssertEqual(career.academy.partnerships.count, 2)
        XCTAssertTrue(career.cancelPartnership(id: "school-\(region)"))
        XCTAssertEqual(career.academy.partnerships.map(\.id), ["club-\(region)"])
        career.transferBudget = 0
        XCTAssertNotNil(career.canSignPartnership(kind: .school, region: (region + 2) % 5), "Sem caixa não contrata")
    }

    func testPartnershipBringsRegionalCandidatesAndCostsUpkeep() {
        var career = started()
        let region = ((career.selectedClub?.region ?? 0) + 1) % 5
        XCTAssertTrue(career.signPartnership(kind: .school, region: region))
        let cash = career.transferBudget
        var random = FootballRandom(seed: 21)
        career.runYouthIntake(using: &random)
        XCTAssertEqual(cash - career.transferBudget, PartnershipKind.school.upkeep, "A chegada cobra só a manutenção")
        let fromPartner = career.youthRoster.filter { $0.region == region }
        XCTAssertEqual(fromPartner.count, PartnershipKind.school.bonusCandidates)
    }

    func testLeagueRunsOncePerCategoryWithMinutesAndOneChampionRule() {
        var career = started()
        var random = FootballRandom(seed: 5)
        career.runYouthIntake(using: &random)
        let categories = Set(career.youthRoster.map { career.youthCategory(of: $0) })
        career.runYouthLeague(using: &random)
        XCTAssertEqual(career.academy.leagueResults.count, categories.count)
        career.runYouthLeague(using: &random)
        XCTAssertEqual(career.academy.leagueResults.count, categories.count, "Cada categoria joga uma vez por temporada")
        for result in career.academy.leagueResults {
            XCTAssertTrue((1...8).contains(result.position))
            XCTAssertEqual(result.champion, result.position == 1)
            XCTAssertTrue((0...7).contains(result.wins))
        }
        for youth in career.youthRoster {
            let minutes = career.academy.minutes[youth.id, default: 0]
            XCTAssertTrue([0, FootballCareer.youthMinutesStarter, FootballCareer.youthMinutesBench].contains(minutes),
                          "Minutos: \(minutes)")
        }
        let best = career.youthRoster.max { $0.overall < $1.overall }
        if let best { XCTAssertEqual(career.academy.minutes[best.id], FootballCareer.youthMinutesStarter) }
    }

    func testMinutesRaiseGrowthButCapAtTwentyFivePercent() throws {
        var career = started()
        var random = FootballRandom(seed: 9)
        career.runYouthIntake(using: &random)
        let youth = try XCTUnwrap(career.youthRoster.first)
        let player = try XCTUnwrap(career.player(youth.id))
        career.academy.minutes[youth.id] = 0
        let base = career.academyGrowthFactor(for: player)
        career.academy.minutes[youth.id] = 900
        let played = career.academyGrowthFactor(for: player)
        career.academy.minutes[youth.id] = 9_000
        let capped = career.academyGrowthFactor(for: player)
        XCTAssertGreaterThan(played, base)
        XCTAssertEqual(capped / base, 1.25, accuracy: 0.0001, "O teto de minutos é +25%")
    }

    func testNewStateSurvivesSaveAndOldSavesStillOpen() throws {
        var career = started()
        XCTAssertTrue(career.signPartnership(kind: .club, region: 3))
        var random = FootballRandom(seed: 2)
        career.runYouthIntake(using: &random)
        career.runYouthLeague(using: &random)
        let data = try JSONEncoder().encode(career)
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertEqual(decoded.academy, career.academy)

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var academy = try XCTUnwrap(object["academy"] as? [String: Any])
        academy.removeValue(forKey: "partnerships")
        academy.removeValue(forKey: "leagueResults")
        academy.removeValue(forKey: "minutes")
        object["academy"] = academy
        let old = try JSONSerialization.data(withJSONObject: object)
        let oldDecoded = try JSONDecoder().decode(FootballCareer.self, from: old)
        XCTAssertTrue(oldDecoded.academy.partnerships.isEmpty)
        XCTAssertTrue(oldDecoded.academy.leagueResults.isEmpty)
        XCTAssertTrue(oldDecoded.academy.minutes.isEmpty)
    }
}
