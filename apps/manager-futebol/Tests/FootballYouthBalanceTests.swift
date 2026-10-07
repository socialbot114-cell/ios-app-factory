import Foundation
import XCTest
@testable import ManagerFutebol

/// Simulação do equilíbrio da base, sem nenhuma tela.
/// Roda muitas carreiras por quatro temporadas e conta quantos jovens chegam a titular (overall 70+)
/// e quantos viram craque (potencial 86+). O relatório sai no log do CI, na linha que começa com "BALANCE",
/// e é a base para calibrar as metas do roadmap (cerca de 1 em 12 titulares e 1 em 100 craques).
final class FootballYouthBalanceTests: XCTestCase {
    static let starterOverall = 70
    static let gemPotential = 86

    func testYouthPipelineBalanceReport() {
        var snapshots: [Int: FootballPlayer] = [:]
        for seed in 1...30 {
            var career = FootballCareer(seed: seed * 313)
            XCTAssertTrue(career.chooseClub(10))
            career.youthAcademyLevel = 3
            var random = FootballRandom(seed: UInt64(seed))
            for _ in 0..<4 {
                career.runYouthIntake(using: &random)
                XCTAssertLessThanOrEqual(career.youthRoster.count, FootballCareer.youthRosterLimit)
                for _ in 0..<FootballSeason.matchDaysPerSeason { career.tickYouthDevelopment(using: &random) }
                for youth in career.youthRoster { snapshots[youth.id] = youth }
                for index in career.players.indices where career.players[index].isYouth { career.players[index].age += 1 }
                career.retireOverageYouth()
            }
        }

        let youths = snapshots.count
        let starters = snapshots.values.filter { $0.overall >= Self.starterOverall }.count
        let gems = snapshots.values.filter { $0.potential >= Self.gemPotential }.count
        let starterRate = youths == 0 ? 0 : Double(youths) / Double(max(1, starters))
        let gemRate = youths == 0 ? 0 : Double(youths) / Double(max(1, gems))
        print("BALANCE youths=\(youths) starters=\(starters) (1 em \(String(format: "%.1f", starterRate))) gems=\(gems) (1 em \(String(format: "%.1f", gemRate)))")

        XCTAssertGreaterThan(youths, 100, "A simulação precisa de jovens suficientes para ser estatística")
        XCTAssertGreaterThan(starters, 0, "Algum jovem deve chegar a titular")
        XCTAssertGreaterThan(gems, 0, "Algum jovem deve virar craque")
    }
}
