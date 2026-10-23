import Foundation
import XCTest
@testable import ManagerFutebol

/// Sonda da economia viva (build 31). Só imprime números, para comparar antes e depois; as travas ficam em `FootballLivingEconomyTests`.
final class FootballEconomyProbeTests: XCTestCase {
    func testPrintEconomyProbe() {
        let seeds = 1...6
        for club in [0, 5, 15] {
            for price in [TicketPrice.normal, .premium, .elite] {
                var gateDerby: [Int] = [], gateRegular: [Int] = [], fillDerby: [Double] = [], fillRegular: [Double] = []
                var seasonGate = 0, seasonMerch = 0, seasonSponsor = 0
                var wins: [Int] = [], sponsor: [Int] = [], merch: [Int] = []
                for seed in seeds {
                    var career = FootballCareer(seed: seed * 7_919)
                    XCTAssertTrue(career.chooseClub(club))
                    career.ticketPrice = price
                    for _ in 0..<FootballSeason.matchDaysPerSeason { career.simulateNextMatchDay() }
                    var sponsorSeason = 0, merchSeason = 0
                    for entry in career.finance.entries(season: career.season) {
                        switch entry.category {
                        case .gate: seasonGate += entry.amount
                        case .merchandise: seasonMerch += entry.amount; merchSeason += entry.amount
                        case .sponsor: seasonSponsor += entry.amount; sponsorSeason += entry.amount
                        default: break
                        }
                    }
                    guard let id = career.selectedClubID else { continue }
                    wins.append(career.fixtures.filter { $0.competition.division != nil && $0.result(for: id) == .win }.count)
                    sponsor.append(sponsorSeason)
                    merch.append(merchSeason)
                    for fixture in career.fixtures where fixture.home == id {
                        guard let crowd = fixture.attendance else { continue }
                        let fill = Double(crowd) / Double(career.effectiveStadiumCapacity)
                        if FootballSeason.isDerby(fixture.home, fixture.away) { gateDerby.append(career.gateRevenue(attendance: crowd)); fillDerby.append(fill) }
                        else if fixture.competition.division != nil { gateRegular.append(career.gateRevenue(attendance: crowd)); fillRegular.append(fill) }
                    }
                }
                let n = seeds.count
                func mean(_ v: [Double]) -> String { v.isEmpty ? "-" : String(format: "%.2f", v.reduce(0, +) / Double(v.count)) }
                func avg(_ v: [Int]) -> Int { v.isEmpty ? 0 : v.reduce(0, +) / v.count }
                func spread(_ v: [Int]) -> String { v.isEmpty ? "-" : "\(v.min()!)–\(v.max()!)" }
                print("ECON club \(club) \(price.title): bilheteria/temp \(seasonGate / n) | loja \(seasonMerch / n) | patrocínio \(seasonSponsor / n) | gate/jogo clássico \(avg(gateDerby)) lotação \(mean(fillDerby)) · comum \(avg(gateRegular)) lotação \(mean(fillRegular)) | vitórias \(spread(wins)) patrocínio \(spread(sponsor)) loja \(spread(merch))")
            }
        }
    }
}
