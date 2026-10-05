import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballCommercialDelegationTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.transferBudget = 30_000_000
        career.fanMood = 90
        career.clubHype = 80
        return career
    }

    private func playDays(_ career: inout FootballCareer, _ count: Int) {
        for _ in 0..<count { XCTAssertTrue(career.simulateNextMatchDay()) }
    }

    func testManagerChargesDailyFeeShownInProjectionAndLaunchesWithinProfile() throws {
        var career = career()
        XCTAssertTrue(career.delegateCommercial(risk: .bold, limit: .large))
        let fee = career.delegationFeePerMatchDay
        let line = try XCTUnwrap(career.cashProjection(horizon: 3).lines.first { $0.title == "Gerente comercial" })
        XCTAssertEqual(line.certainty, .contracted)
        XCTAssertEqual(line.total, -fee * 3)

        let choice = try XCTUnwrap(career.delegatedCollectionChoice(), "Clima favorável: deve haver oportunidade")
        XCTAssertGreaterThanOrEqual(Double(career.collectionForecast(choice)), Double(career.collectionCost(choice)) * DelegationRisk.bold.minimumReturn)
        playDays(&career, 1)
        let delegation = try XCTUnwrap(career.commercialDelegation)
        XCTAssertEqual(delegation.launchedIDs.count, 1)
        XCTAssertNotNil(career.activeCollection)
        XCTAssertEqual(delegation.spentThisSeason, career.activeCollection?.cost)
        XCTAssertEqual(career.finance.entries.filter { $0.note == "Gerente comercial" }.count, 1)
    }

    func testCautiousManagerNeverLaunchesFlagshipAndSkipsBadClimate() throws {
        var career = career()
        XCTAssertTrue(career.delegateCommercial(risk: .cautious, limit: .large))
        if let choice = career.delegatedCollectionChoice() { XCTAssertNotEqual(choice.size, .flagship) }
        career.fanMood = 0
        career.clubHype = 0
        career.reputation = 0
        career.world.business.shopLevel = 1
        XCTAssertNil(career.delegatedCollectionChoice(), "Sem retorno esperado, o gerente não arrisca")
    }

    func testSeasonCapIsRespectedAndReportsArrive() throws {
        var career = career()
        XCTAssertTrue(career.delegateCommercial(risk: .bold, limit: .small))
        let cap = career.delegationCap(.small)
        playDays(&career, 12)
        let delegation = try XCTUnwrap(career.commercialDelegation)
        XCTAssertLessThanOrEqual(delegation.spentThisSeason, cap, "Nunca passa do teto")
        let launched = career.world.commercial.collections.filter { delegation.launchedIDs.contains($0.id) }
        XCTAssertEqual(launched.reduce(0) { $0 + $1.cost }, delegation.spentThisSeason)
        XCTAssertTrue(career.inbox.contains { $0.title == "Gerente comercial: relatório" })
        XCTAssertEqual(career.finance.entries.filter { $0.note == "Gerente comercial" }.count, 12, "Honorário cobrado uma vez por dia")

        career.endCommercialDelegation()
        XCTAssertNil(career.commercialDelegation)
        XCTAssertTrue(career.inbox.contains { $0.title == "Gerente comercial: relatório final" })
    }

    func testManagerRespectsPlayersOwnCollection() throws {
        var career = career()
        XCTAssertTrue(career.launchCollection(CollectionBrief(audience: .youth, size: .capsule)))
        XCTAssertTrue(career.delegateCommercial(risk: .bold, limit: .large))
        playDays(&career, 1)
        XCTAssertTrue(career.commercialDelegation?.launchedIDs.isEmpty ?? false, "Não lança por cima da coleção do jogador")
    }

    func testNewSeasonResetsCapAndClubChangeEndsDelegation() throws {
        var career = career()
        XCTAssertTrue(career.delegateCommercial(risk: .bold, limit: .small))
        career.world.commercial.delegation?.spentThisSeason = 999_999_999
        career.world.commercial.delegation?.season = career.season - 1
        career.runCommercialDelegation()
        XCTAssertLessThan(career.commercialDelegation?.spentThisSeason ?? .max, 999_999_999)

        career.world.commercial.delegation = CommercialDelegation(clubID: 99, season: career.season, startWorldDay: 0,
                                                                  risk: .bold, limit: .small, lastReportWorldDay: 0)
        career.runCommercialDelegation()
        XCTAssertNil(career.commercialDelegation)
    }

    func testLegacyCommercialWithoutDelegationLoads() throws {
        var career = career()
        XCTAssertTrue(career.delegateCommercial(risk: .cautious, limit: .medium))
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip.commercialDelegation, career.commercialDelegation)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(json["world"] as? [String: Any])
        var commercial = try XCTUnwrap(world["commercial"] as? [String: Any])
        commercial.removeValue(forKey: "delegation")
        world["commercial"] = commercial
        json["world"] = world
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.commercialDelegation)
    }
}
