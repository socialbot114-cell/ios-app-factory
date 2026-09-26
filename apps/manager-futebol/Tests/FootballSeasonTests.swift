import XCTest
@testable import ManagerFutebol

final class FootballSeasonTests: XCTestCase {
    func testDoubleRoundRobinContainsFourMatchesPerRound() {
        let fixtures = FootballSeason.fixtures(seed: 42)
        XCTAssertEqual(fixtures.count, 56)
        XCTAssertEqual(Set(fixtures.map(\.round)), Set(1...14))
        XCTAssertTrue((1...14).allSatisfy { round in fixtures.filter { $0.round == round }.count == 4 })
        XCTAssertTrue(fixtures.allSatisfy { $0.home != $0.away })
        for first in 0..<8 {
            for second in (first + 1)..<8 {
                let meetings = fixtures.filter { Set([$0.home, $0.away]) == Set([first, second]) }
                XCTAssertEqual(meetings.count, 2)
                XCTAssertEqual(meetings.filter { $0.home == first }.count, 1)
                XCTAssertEqual(meetings.filter { $0.home == second }.count, 1)
            }
        }
    }

    func testSameSeedProducesSameFixturesAndStandingsUseSavedResults() {
        XCTAssertEqual(FootballSeason.fixtures(seed: 7), FootballSeason.fixtures(seed: 7))
        XCTAssertNotEqual(FootballSeason.fixtures(seed: 7), FootballSeason.fixtures(seed: 8))
        let firstTwo = FootballSeason.fixtures(seed: 7).filter { $0.round <= 2 }
        XCTAssertEqual(FootballSeason.standings(results: firstTwo).count, 8)
        XCTAssertEqual(FootballSeason.fixtures(seed: .min).count, 56)
    }
}
