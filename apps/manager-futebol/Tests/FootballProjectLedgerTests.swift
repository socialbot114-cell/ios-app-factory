import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballProjectLedgerTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.transferBudget = 30_000_000
        return career
    }

    private func playDays(_ career: inout FootballCareer, _ count: Int) {
        for _ in 0..<count { XCTAssertTrue(career.simulateNextMatchDay()) }
    }

    func testNamingRealizedMatchesTheBankExactly() throws {
        var career = career()
        var random = FootballRandom(seed: 4)
        career.refreshNamingOffers(using: &random)
        let offer = try XCTUnwrap(career.world.business.namingOffers.first)
        XCTAssertTrue(career.acceptNamingOffer(offer.id))
        playDays(&career, 5)
        let entry = try XCTUnwrap(career.projectLedger.first { $0.kind == .naming })
        XCTAssertEqual(entry.daysElapsed, 5)
        let booked = career.finance.entries.filter { $0.category == .naming }.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(Int(entry.realized), booked)
        XCTAssertEqual(entry.ratio ?? 0, 1, accuracy: 0.0001, "Contrato fixo: realizado igual ao previsto")
        XCTAssertEqual(entry.forecastTotal, Double(offer.perSeason / FootballSeason.matchDaysPerSeason * offer.seasons * FootballSeason.matchDaysPerSeason))
    }

    func testEachShopUpgradeCountsOnlyItsOwnSlice() throws {
        var career = career()
        XCTAssertTrue(career.upgradeShop())
        let first = try XCTUnwrap(career.projectLedger.last { $0.kind == .shopUpgrade })
        XCTAssertGreaterThan(first.forecastPerDay, 0)
        XCTAssertGreaterThan(first.invested, 0)
        playDays(&career, 2)
        XCTAssertTrue(career.upgradeShop())
        playDays(&career, 2)
        let level2 = try XCTUnwrap(career.projectLedger.first { $0.key == FootballCareer.shopUpgradeKey(level: 2) })
        let level3 = try XCTUnwrap(career.projectLedger.first { $0.key == FootballCareer.shopUpgradeKey(level: 3) })
        XCTAssertEqual(level2.daysElapsed, 4)
        XCTAssertEqual(level3.daysElapsed, 2)
        // Hoje: fatia de cada ampliação sobre o fator atual (2→1,4−1,0; 3→1,9−1,4) — somadas dão o ganho total sobre o nível 1.
        let base = Double(career.baseMerchRevenuePerMatchDay)
        let total = Double(career.shopUpliftToday(fromLevel: 1, toLevel: 2) + career.shopUpliftToday(fromLevel: 2, toLevel: 3))
        XCTAssertEqual(total, base * (1 - 1.0 / 1.9), accuracy: 2)
        XCTAssertGreaterThan(level2.realized, 0)
        XCTAssertGreaterThan(level3.realized, 0)
    }

    func testProgramsTrackTheirOwnPromiseAndCloseWhenStopped() throws {
        var career = career()
        XCTAssertTrue(career.toggle(.fanClubs))
        XCTAssertTrue(career.toggle(.footballAcademy))
        playDays(&career, 6)
        let fans = try XCTUnwrap(career.projectLedger.first { $0.key == CommunityProgram.fanClubs.rawValue })
        XCTAssertEqual(fans.unit, .fans)
        XCTAssertGreaterThan(fans.realized, 0)
        XCTAssertEqual(fans.ratio ?? 0, 1, accuracy: 0.15, "Crescimento quase determinístico fica perto do previsto")
        let academy = try XCTUnwrap(career.projectLedger.first { $0.key == CommunityProgram.footballAcademy.rawValue })
        XCTAssertEqual(academy.unit, .talents)
        XCTAssertEqual(academy.forecastToDate, 0.02 * 6, accuracy: 0.0001)
        XCTAssertTrue(academy.realized == 0 || academy.realized >= 1, "Talento é inteiro: o previsto fracionário contrasta com o real")

        XCTAssertTrue(career.toggle(.fanClubs))
        XCTAssertTrue(career.projectLedger.first { $0.key == CommunityProgram.fanClubs.rawValue }?.closed ?? false)
        playDays(&career, 1)
        XCTAssertEqual(career.projectLedger.first { $0.key == CommunityProgram.fanClubs.rawValue }?.daysElapsed, 6, "Fechado não conta mais dias")
    }

    func testClubChangeClosesTheLedgerAndOldSavesLoad() throws {
        var career = career()
        XCTAssertTrue(career.toggle(.schoolProject))
        XCTAssertTrue(career.resign())
        let job = try XCTUnwrap(career.jobOffers.first)
        XCTAssertTrue(career.acceptJob(job.id))
        XCTAssertTrue(career.world.commercial.ledger.allSatisfy(\.closed))
        XCTAssertTrue(career.projectLedger.isEmpty, "Livro mostra só projetos do clube atual")

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(json["world"] as? [String: Any])
        var commercial = try XCTUnwrap(world["commercial"] as? [String: Any])
        commercial.removeValue(forKey: "ledger")
        commercial.removeValue(forKey: "ledgerNextID")
        world["commercial"] = commercial
        json["world"] = world
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.world.commercial.ledger.isEmpty)
    }
}
