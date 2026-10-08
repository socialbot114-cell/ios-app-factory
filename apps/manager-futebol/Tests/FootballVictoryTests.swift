import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballVictoryTests: XCTestCase {
    /// Saldo de três gols ou mais é goleada, com ou sem outros motivos (ANI-03).
    func testThreeGoalMarginIsAGoleada() {
        XCTAssertEqual(FootballVictory.tier(VictoryContext(goalsFor: 3, goalsAgainst: 0)), .goleada)
        XCTAssertEqual(FootballVictory.tier(VictoryContext(goalsFor: 5, goalsAgainst: 1, cameFromBehind: true)), .goleada)
    }

    /// Virada, clássico ou decisão de título contam como vitória grande, mesmo com um gol de saldo.
    func testComebackClassicOrTitleIsAGreatVictoryWithOneGoalMargin() {
        XCTAssertEqual(FootballVictory.tier(VictoryContext(goalsFor: 2, goalsAgainst: 1, cameFromBehind: true)), .big)
        XCTAssertEqual(FootballVictory.tier(VictoryContext(goalsFor: 1, goalsAgainst: 0, isClassic: true)), .big)
        XCTAssertEqual(FootballVictory.tier(VictoryContext(goalsFor: 1, goalsAgainst: 0, decidesTitle: true)), .big)
    }

    /// Vitória simples fica como sempre foi; empate e derrota não são vitória.
    func testPlainWinIsRegularAndNonWinsGiveNothing() {
        XCTAssertEqual(FootballVictory.tier(VictoryContext(goalsFor: 1, goalsAgainst: 0)), .regular)
        XCTAssertNil(FootballVictory.tier(VictoryContext(goalsFor: 2, goalsAgainst: 2, isClassic: true)))
        XCTAssertNil(FootballVictory.tier(VictoryContext(goalsFor: 0, goalsAgainst: 1, decidesTitle: true)))
    }

    /// Cada faixa tem o seu texto.
    func testHeadlines() {
        XCTAssertEqual(VictoryTier.goleada.headline, "GOLEADA")
        XCTAssertEqual(VictoryTier.big.headline, "VITÓRIA GRANDE")
        XCTAssertEqual(VictoryTier.regular.headline, "VITÓRIA")
    }
}
