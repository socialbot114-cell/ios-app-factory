import Foundation
import XCTest
@testable import ManagerFutebol

/// Build 28: contratação e promoção da base não podem travar em silêncio.
final class FootballBuild28Tests: XCTestCase {
    private func career(club: Int = 6, seed: Int = 1) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    // MARK: - Teto salarial

    func testWageCapNeverEndsBelowTheBillAfterSeasonRollover() throws {
        // Antes: o teto caía 3% por temporada sem meta cumprida e a folha só crescia, o que travava tudo.
        for seed in [1, 3, 4] {
            var c = career(seed: seed)
            for _ in 0..<3 {
                var days = 0
                while !c.isSeasonComplete && days < 40 {
                    days += 1
                    if c.canPlay || c.canAdvanceWithoutPlaying { _ = c.simulateNextMatchDay(); c.skipPress() } else { break }
                }
                guard c.isSeasonComplete else { break }
                _ = c.startNextSeason()
                if c.isFired { break }
                XCTAssertGreaterThanOrEqual(c.wageCap, c.wageBill, "seed \(seed): teto abaixo da folha")
                XCTAssertGreaterThanOrEqual(Double(c.wageCap), Double(c.wageBill) * 1.11, "seed \(seed): sem folga mínima para trabalhar")
            }
        }
    }

    func testEnsureWageHeadroomRaisesOnlyWhenNeeded() {
        var c = career()
        c.wageCap = c.wageBill * 3
        let before = c.wageCap
        XCTAssertFalse(c.ensureWageHeadroom())
        XCTAssertEqual(c.wageCap, before, "Teto folgado não muda")
        c.wageCap = c.wageBill - 100_000
        XCTAssertTrue(c.ensureWageHeadroom())
        XCTAssertGreaterThanOrEqual(c.wageCap, Int(Double(c.wageBill) * 1.12))
    }

    func testSavedCareerWithSqueezedCapIsRepairedOnLoad() throws {
        var c = career()
        c.wageCap = c.wageBill - 50_000
        let data = try JSONEncoder().encode(c)
        let loaded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertGreaterThan(loaded.wageCap, loaded.wageBill, "Save travado volta a ter folga")
    }

    // MARK: - Promoção da base

    func testYouthPromotionExplainsWhyItIsBlocked() throws {
        var c = career(club: 0, seed: 2)
        var days = 0
        while !c.isSeasonComplete && days < 40 {
            days += 1
            if c.canPlay || c.canAdvanceWithoutPlaying { _ = c.simulateNextMatchDay(); c.skipPress() } else { break }
        }
        _ = c.startNextSeason()
        let youth = try XCTUnwrap(c.youthRoster.first)
        XCTAssertNil(c.promoteBlockReason(playerID: youth.id), "Com folga e vaga, o jovem sobe")
        XCTAssertTrue(c.promoteYouth(playerID: youth.id))
        XCTAssertFalse(c.player(youth.id)?.isYouth ?? true)

        let next = try XCTUnwrap(c.youthRoster.first)
        c.wageCap = c.wageBill
        let reason = try XCTUnwrap(c.promoteBlockReason(playerID: next.id), "Sem folga o motivo precisa aparecer")
        XCTAssertTrue(reason.contains("Faltam"), reason)
        XCTAssertFalse(c.canPromote(playerID: next.id))
        XCTAssertFalse(c.promoteYouth(playerID: next.id))
    }

    func testFullFirstTeamBlocksPromotionWithAReason() throws {
        var c = career(club: 0, seed: 2)
        var days = 0
        while !c.isSeasonComplete && days < 40 {
            days += 1
            if c.canPlay || c.canAdvanceWithoutPlaying { _ = c.simulateNextMatchDay(); c.skipPress() } else { break }
        }
        _ = c.startNextSeason()
        let youth = try XCTUnwrap(c.youthRoster.first)
        for index in c.players.indices where c.clubRoster.count < FootballCareer.rosterLimit {
            if c.players[index].teamID == nil && !c.players[index].isYouth { c.players[index].teamID = c.selectedClubID }
        }
        XCTAssertEqual(c.clubRoster.count, FootballCareer.rosterLimit)
        c.wageCap = c.wageBill * 3
        let reason = try XCTUnwrap(c.promoteBlockReason(playerID: youth.id))
        XCTAssertTrue(reason.contains("cheio"), reason)
    }

    // MARK: - Negociações

    func testTalkIsBlockedUpFrontWhenTheWageCapCannotFitEvenTheMinimumWage() throws {
        var c = career(club: 6, seed: 1)
        c.transferBudget = 60_000_000
        while !c.isTransferWindowOpen { _ = c.simulateNextMatchDay(); c.skipPress() }
        let target = try XCTUnwrap(c.players.first {
            $0.teamID != nil && $0.teamID != c.selectedClubID && !$0.isYouth && !$0.onLoan && c.sellerCanSell($0) && $0.overall >= 60
        })
        c.wageCap = c.wageBill
        let reason = try XCTUnwrap(c.transferTalkBlocker(playerID: target.id))
        XCTAssertTrue(reason.contains("folha") || reason.contains("teto"), reason)
        XCTAssertNil(c.startTransferTalk(playerID: target.id))
    }

    func testIdleTalkGoesColdAndFreesTheSlot() throws {
        var c = career(club: 0, seed: 2)
        c.transferBudget = 60_000_000
        c.wageCap = c.wageBill * 3
        let targets = c.players.filter {
            $0.teamID != nil && $0.teamID != c.selectedClubID && !$0.isYouth && !$0.onLoan && c.sellerCanSell($0) && $0.overall >= 60
        }.prefix(FootballCareer.maxOpenTalks + 1)
        var talkIDs: [Int] = []
        for target in targets.prefix(FootballCareer.maxOpenTalks) {
            talkIDs.append(try XCTUnwrap(c.startTransferTalk(playerID: target.id)).id)
        }
        let extra = try XCTUnwrap(targets.last)
        XCTAssertNotNil(c.transferTalkBlocker(playerID: extra.id), "Três abertas ocupam todas as vagas")
        for index in c.world.projects.transferTalks.indices { c.world.projects.transferTalks[index].lastActionWorldDay = c.worldDay - FootballCareer.talkIdleDays }
        c.progressTransferTalks()
        XCTAssertTrue(c.openTransferTalks.isEmpty, "Negociações paradas esfriam")
        XCTAssertNil(c.transferTalkBlocker(playerID: extra.id), "A vaga voltou")
    }

    func testClosedWindowMessageSaysWhenItOpens() {
        var c = career()
        while c.isTransferWindowOpen { _ = c.simulateNextMatchDay(); c.skipPress() }
        XCTAssertTrue(c.windowClosedReason.contains("rodada") || c.windowClosedReason.contains("pré-temporada"), c.windowClosedReason)
        XCTAssertEqual(TransferWindow.preseason.end, 2)
        XCTAssertEqual(TransferWindow.midseason.start, 8)
    }
}
