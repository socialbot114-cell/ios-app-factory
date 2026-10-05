import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballBankStatementTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.transferBudget = 30_000_000
        career.world.coach.personalCash = 2_000_000
        return career
    }

    // MARK: BAN-01

    func testPersonalStatementAlwaysReconciles() {
        var career = career()
        XCTAssertTrue(career.buyAsset(.car))
        XCTAssertTrue(career.lendToClub(amount: 100_000))
        XCTAssertNotNil(career.doActivity(.lecture))
        // Movimentação fora dos pontos registrados (ex.: evento): a reconciliação a explica.
        career.world.coach.personalCash += 7_000
        for _ in 0..<4 { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertEqual(career.personalLedgerBalance, career.world.coach.personalCash, "Saldo e extrato batem")
        let notes = career.personalLedger.entries.map(\.note)
        XCTAssertTrue(notes.contains("Compra: \(AssetKind.car.title)"))
        XCTAssertTrue(notes.contains("Aporte ao clube"))
        XCTAssertTrue(notes.contains("Salário de treinador"))
        XCTAssertTrue(notes.contains("Outras movimentações (eventos, redes, missões)"))
    }

    func testRetentionKeepsTheBalanceRight() {
        var career = career()
        for index in 0..<(FootballCareer.personalEntryLimit + 30) { career.bookPersonal(index.isMultiple(of: 2) ? 1_000 : -400, "Teste") }
        XCTAssertEqual(career.personalLedger.entries.count, FootballCareer.personalEntryLimit)
        XCTAssertEqual(career.personalLedgerBalance, career.world.coach.personalCash)
    }

    // MARK: BAN-06

    func testClubEntriesOpenTheirOrigin() throws {
        var career = career()
        XCTAssertTrue(career.lendToClub(amount: 200_000))
        let loanEntry = try XCTUnwrap(career.finance.entries.last { $0.note == "Aporte do treinador" })
        let loanLink = try XCTUnwrap(loanEntry.link)
        XCTAssertEqual(loanLink.kind, .loan)
        XCTAssertTrue(career.financeOrigin(loanLink).detail.contains("falta"))

        XCTAssertTrue(career.startUpgrade(.trainingCenter))
        let stage = try XCTUnwrap(career.finance.entries.last { $0.note.hasPrefix("Obra:") })
        XCTAssertEqual(stage.link?.kind, .construction)
        XCTAssertTrue(career.financeOrigin(try XCTUnwrap(stage.link)).detail.contains("Etapa atual"))

        XCTAssertTrue(career.launchCollection(CollectionBrief(audience: .traditional, size: .capsule)))
        XCTAssertEqual(career.finance.entries.last { $0.note.hasPrefix("Lançamento:") }?.link?.kind, .collection)

        XCTAssertTrue(career.launchCampaign(CampaignBrief(channel: .localMedia, objective: .fans, audience: .local, budget: .lean)))
        let campaign = try XCTUnwrap(career.finance.entries.last { $0.note.hasPrefix("Campanha:") }?.link)
        XCTAssertEqual(career.financeOrigin(campaign).title, "Campanha \(MarketingCampaign.localMedia.title)")
    }

    func testOldEntriesWithoutLinkStillDecode() throws {
        let career = career()
        let data = try JSONEncoder().encode(FinanceEntry(season: 1, matchDay: 0, category: .other, amount: 10, note: "Antigo"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "link")
        let decoded = try JSONDecoder().decode(FinanceEntry.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.link)
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip.personalLedger, career.personalLedger)
    }
}
