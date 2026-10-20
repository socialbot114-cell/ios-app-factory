import XCTest
@testable import ManagerFutebol

final class FootballKitDesignTests: XCTestCase {
    func testEveryClubOfTheLeagueHasItsOwnShirtDesign() {
        let designs = FootballSeason.teams.map { KitDesign.design(forTeam: $0.id) }
        XCTAssertGreaterThanOrEqual(designs.count, 20)
        for (index, design) in designs.enumerated() {
            for other in designs[(index + 1)...] {
                XCTAssertNotEqual(design, other, "Dois clubes com o mesmo desenho de camisa")
            }
        }
    }

    func testDesignIsStableAndUsesAllPatterns() {
        XCTAssertEqual(KitDesign.design(forTeam: 7), KitDesign.design(forTeam: 7))
        let patterns = Set(FootballSeason.teams.map { KitDesign.design(forTeam: $0.id).pattern })
        XCTAssertEqual(patterns.count, KitPattern.allCases.count)
    }
}
