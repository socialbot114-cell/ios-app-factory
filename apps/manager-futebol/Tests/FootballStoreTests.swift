import Foundation
import XCTest
@testable import ManagerFutebol

/// Catálogo da Loja: os cinco módulos Pro, a faixa de preço combinada e o texto que o cliente lê antes de comprar.
final class FootballStoreTests: XCTestCase {
    func testCatalogHasTheFiveProModules() {
        XCTAssertEqual(FootballProModule.allCases.map(\.title), ["Scout Pro", "Analytics Pro", "Market Pro", "Academy Pro", "Medical Pro"])
    }

    func testPricesStayInTheAgreedRange() {
        for module in FootballProModule.allCases {
            XCTAssertGreaterThanOrEqual(module.priceCents, 490, module.title)
            XCTAssertLessThanOrEqual(module.priceCents, 1490, module.title)
        }
        XCTAssertEqual(FootballProModule.scout.priceCents, 490)
        XCTAssertEqual(FootballProModule.market.priceCents, 1490)
    }

    func testEveryModuleHasATeaserAndVisibleHighlights() {
        for module in FootballProModule.allCases {
            XCTAssertFalse(module.teaser.isEmpty, module.title)
            XCTAssertFalse(module.highlights.isEmpty, module.title)
        }
    }

    func testMarketProListsTheSixSignals() throws {
        let first = try XCTUnwrap(FootballProModule.market.highlights.first)
        for signal in ["Em alta", "Subvalorizados", "Em queda", "Fim de contrato", "Jovens promessas", "Oportunidades"] {
            XCTAssertTrue(first.contains(signal), signal)
        }
    }

    func testProductIdsAreUniqueAndPrefixed() {
        let ids = FootballProModule.allCases.map(\.productID)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(ids.allSatisfy { $0.hasPrefix("futos.pro.") })
    }
}
