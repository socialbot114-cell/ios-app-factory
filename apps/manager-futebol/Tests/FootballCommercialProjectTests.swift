import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballCommercialProjectTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.transferBudget = 20_000_000
        return career
    }

    private func playDays(_ career: inout FootballCareer, _ count: Int) {
        for _ in 0..<count { XCTAssertTrue(career.simulateNextMatchDay()) }
    }

    func testCollectionRunsForItsDurationReportsAndIsEvaluatedOnce() throws {
        var career = career()
        let brief = CollectionBrief(audience: .traditional, size: .season)
        let cost = career.collectionCost(brief)
        let forecast = career.collectionForecast(brief)
        XCTAssertGreaterThan(forecast, 0)
        let cash = career.transferBudget
        XCTAssertTrue(career.launchCollection(brief))
        XCTAssertEqual(career.transferBudget, cash - cost, "Investimento cobrado no lançamento")
        XCTAssertFalse(career.launchCollection(brief), "Uma coleção por vez")
        let project = try XCTUnwrap(career.activeCollection)
        XCTAssertEqual(project.forecast, forecast)

        playDays(&career, brief.size.matchDays)
        let done = try XCTUnwrap(career.world.commercial.collections.first { $0.id == project.id })
        XCTAssertNotNil(done.verdict)
        XCTAssertEqual(done.dailySales.count, brief.size.matchDays)
        let booked = career.finance.entries.filter { $0.note == "Vendas extras: \(project.name)" }.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(booked, done.realized, "Cada venda extra lançada uma vez no Banco")
        XCTAssertTrue(career.inbox.contains { $0.title == "Relatório de vendas: \(project.name)" })
        XCTAssertTrue(career.inbox.contains { $0.title == "Avaliação da coleção: \(project.name)" })

        // Depois de avaliada, nenhum dia extra é lançado.
        playDays(&career, 1)
        XCTAssertEqual(career.world.commercial.collections.first { $0.id == project.id }?.dailySales.count, brief.size.matchDays)
        XCTAssertNil(career.activeCollection)
    }

    func testCooldownAndAudienceFatiguePreventSpamming() throws {
        var career = career()
        let brief = CollectionBrief(audience: .youth, size: .capsule)
        XCTAssertTrue(career.launchCollection(brief))
        playDays(&career, brief.size.matchDays)
        XCTAssertNotNil(career.collectionBlocker(brief), "Intervalo entre coleções")
        let fresh = career.audienceFit(.traditional)
        playDays(&career, FootballCareer.collectionCooldown)
        XCTAssertNil(career.collectionBlocker(brief))
        var tired = career
        tired.clubHype = 50
        var other = tired
        other.world.commercial.collections = []
        XCTAssertLessThan(tired.audienceFit(.youth), other.audienceFit(.youth), "Repetir o público rende menos")
        XCTAssertGreaterThan(fresh, 0)
    }

    func testAudienceFollowsItsDriverAndBiggerCollectionsCostAndSellMore() {
        var career = career()
        career.fanMood = 20
        let gloomy = career.audienceFit(.traditional)
        career.fanMood = 90
        XCTAssertGreaterThan(career.audienceFit(.traditional), gloomy)
        career.clubHype = 0
        let calm = career.audienceFit(.youth)
        career.clubHype = 90
        XCTAssertGreaterThan(career.audienceFit(.youth), calm)

        let small = CollectionBrief(audience: .traditional, size: .capsule)
        let big = CollectionBrief(audience: .traditional, size: .flagship)
        XCTAssertGreaterThan(career.collectionCost(big), career.collectionCost(small))
        XCTAssertGreaterThan(career.collectionForecast(big), career.collectionForecast(small))
    }

    func testProjectionCountsCollectionOnlyForRemainingDays() throws {
        var career = career()
        let brief = CollectionBrief(audience: .traditional, size: .capsule)
        XCTAssertTrue(career.launchCollection(brief))
        playDays(&career, 2)
        let projection = career.cashProjection(horizon: 8)
        let project = try XCTUnwrap(career.activeCollection)
        let line = try XCTUnwrap(projection.lines.first { $0.title == "Vendas extras: \(project.name)" })
        let remaining = brief.size.matchDays - project.dailySales.count
        XCTAssertEqual(line.total, career.collectionExtra(brief) * remaining)
    }

    func testLegacyShortcutStillBoostsTheShop() {
        var career = career()
        let normal = career.merchRevenuePerMatchDay
        XCTAssertTrue(career.launchCollection())
        XCTAssertGreaterThan(career.merchRevenuePerMatchDay, normal)
        XCTAssertTrue(career.collectionActive)
    }

    func testLegacyWorldWithoutCommercialStillLoads() throws {
        let career = career()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(json["world"] as? [String: Any])
        world.removeValue(forKey: "commercial")
        json["world"] = world
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.world.commercial.collections.isEmpty)
    }
}
