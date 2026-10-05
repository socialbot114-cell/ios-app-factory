import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballRecruitmentTests: XCTestCase {
    private func careerInWindow(seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(3))
        career.transferBudget = 120_000_000
        career.wageCap = career.wageBill * 3
        while career.matchDayIndex < TransferWindow.midseason.start, career.simulateNextMatchDay() {}
        XCTAssertTrue(career.isTransferWindowOpen)
        return career
    }

    /// Um atleta vendável de outro clube, de nível médio.
    private func target(in career: FootballCareer) throws -> FootballPlayer {
        try XCTUnwrap(career.players.filter { $0.teamID != nil && $0.teamID != career.selectedClubID && !$0.onLoan && !$0.isYouth
            && career.sellerCanSell($0) && $0.position == .midfielder }.sorted { $0.overall > $1.overall }.dropFirst(5).first)
    }

    // MARK: TRF-01/02/03

    func testBriefFindsMatchingCandidatesAndShortlistCompares() throws {
        var career = careerInWindow()
        let brief = try XCTUnwrap(career.createBrief(position: .forward, maxAge: 27, minOverall: 60, maxFee: 40_000_000, maxWage: 3_000_000, role: .starter))
        let list = career.candidates(for: brief)
        XCTAssertFalse(list.isEmpty)
        for row in list {
            let athlete = try XCTUnwrap(career.player(row.playerID))
            XCTAssertEqual(athlete.position, .forward)
            XCTAssertLessThanOrEqual(athlete.age, 27)
            XCTAssertGreaterThanOrEqual(row.fit, 4)
        }
        for row in list.prefix(FootballCareer.shortlistLimit + 1) { career.toggleShortlist(briefID: brief.id, playerID: row.playerID) }
        let saved = try XCTUnwrap(career.recruitmentBriefs.first)
        XCTAssertLessThanOrEqual(saved.shortlist.count, FootballCareer.shortlistLimit)
        XCTAssertEqual(career.shortlistComparison(for: saved).map(\.playerID), saved.shortlist)
        XCTAssertNotNil(career.createBrief(position: .defender, maxAge: 30, minOverall: 55, maxFee: 1, maxWage: 1, role: .rotation))
        XCTAssertNotNil(career.createBrief(position: .goalkeeper, maxAge: 30, minOverall: 55, maxFee: 1, maxWage: 1, role: .rotation))
        XCTAssertNil(career.createBrief(position: .midfielder, maxAge: 30, minOverall: 55, maxFee: 1, maxWage: 1, role: .rotation), "Limite de briefings")
    }

    func testReportsCarryDateReliabilityAndAge() throws {
        var career = careerInWindow()
        let athlete = try target(in: career)
        XCTAssertEqual(career.recruitmentReport(for: athlete.id).reliability, .none)
        career.observe(athlete.id, gain: 70)
        career.stampScoutReports()
        let fresh = career.recruitmentReport(for: athlete.id)
        XCTAssertEqual(fresh.observedWorldDay, career.worldDay)
        XCTAssertEqual(fresh.reliability, career.scoutKnowledge(of: athlete.id) >= 80 ? .high : .medium)
        career.matchDayIndex += 12
        let old = career.recruitmentReport(for: athlete.id)
        XCTAssertEqual(old.ageInDays, 12)
        XCTAssertNotEqual(old.reliability, fresh.reliability, "Relatório velho perde um degrau")
    }

    // MARK: TRF-04/05/06

    func testFullStagedSigningChargesOnceAndKeepsTheRole() throws {
        var career = careerInWindow()
        let athlete = try target(in: career)
        let talk = try XCTUnwrap(career.startTransferTalk(playerID: athlete.id))
        XCTAssertNil(career.startTransferTalk(playerID: athlete.id), "Uma conversa por atleta")
        let ask = career.askingPrice(for: athlete)

        guard case .counter = career.proposeFee(talkID: talk.id, fee: Int(Double(ask) * 0.9), installments: 2) else { return XCTFail("Esperava contraproposta") }
        XCTAssertEqual(career.openTalk(forPlayer: athlete.id)?.stage, .clubCounter)
        let counterCommitment = try XCTUnwrap(career.openTalk(forPlayer: athlete.id)?.commitmentID)
        XCTAssertTrue(career.agenda.contains { $0.id == "commitment-\(counterCommitment)" })
        guard case .accepted = career.acceptClubCounter(talkID: talk.id) else { return XCTFail("Aceitar a contraproposta do clube") }
        XCTAssertEqual(career.commitments.first { $0.id == counterCommitment }?.state, .fulfilled)

        let needed = try XCTUnwrap(career.wageNeeded(talk: try XCTUnwrap(career.openTalk(forPlayer: athlete.id)), years: 3, role: .starter))
        guard case .counter = career.proposeTerms(talkID: talk.id, wage: Int(Double(needed) * 0.85), years: 3, role: .starter) else {
            return XCTFail("Esperava pedido do atleta")
        }
        guard case .accepted = career.acceptPlayerCounter(talkID: talk.id) else { return XCTFail("Aceitar o pedido do atleta") }
        XCTAssertEqual(career.openTalk(forPlayer: athlete.id)?.stage, .agreed)

        let summary = try XCTUnwrap(career.costSummary(talkID: talk.id))
        XCTAssertTrue(summary.fitsBudget)
        XCTAssertEqual(summary.upfront + summary.laterInstallments, career.transferTalks.first { $0.id == talk.id }?.fee)
        let cash = career.transferBudget
        guard case .accepted = career.signTalk(talkID: talk.id) else { return XCTFail("Assinar") }
        XCTAssertEqual(career.player(athlete.id)?.teamID, career.selectedClubID)
        XCTAssertEqual(career.player(athlete.id)?.contract.status, .starter, "Papel negociado vai para o contrato")
        XCTAssertEqual(career.transferBudget, cash - summary.upfront, "Só a entrada sai agora")
        XCTAssertEqual(career.pendingPayments.filter { $0.note.contains(athlete.name) }.reduce(0) { $0 + $1.amount }, summary.laterInstallments)
        XCTAssertNotNil(career.fact("talk-\(talk.id)-signed"))
        guard case .notAllowed = career.signTalk(talkID: talk.id) else { return XCTFail("Não assina duas vezes") }
        XCTAssertEqual(career.finance.entries.filter { $0.note == "Entrada por \(athlete.name)" }.count, 1)
    }

    func testCounterExpiresByCalendarAndRefusalsCollapse() throws {
        var career = careerInWindow()
        let athlete = try target(in: career)
        let talk = try XCTUnwrap(career.startTransferTalk(playerID: athlete.id))
        let ask = career.askingPrice(for: athlete)
        _ = career.proposeFee(talkID: talk.id, fee: Int(Double(ask) * 0.9))
        career.matchDayIndex += FootballCareer.counterValidityDays
        career.progressTransferTalks()
        XCTAssertEqual(career.transferTalks.first { $0.id == talk.id }?.stage, .expired)

        let second = try XCTUnwrap(career.startTransferTalk(playerID: athlete.id))
        for _ in 0..<FootballCareer.maxRefusals { _ = career.proposeFee(talkID: second.id, fee: ask / 3) }
        XCTAssertEqual(career.transferTalks.first { $0.id == second.id }?.stage, .collapsed)
    }

    func testLowerRoleCostsMoreAndBrokenTalksAreRemembered() throws {
        var career = careerInWindow()
        let athlete = try target(in: career)
        let talk = try XCTUnwrap(career.startTransferTalk(playerID: athlete.id))
        _ = career.proposeFee(talkID: talk.id, fee: career.askingPrice(for: athlete))
        let open = try XCTUnwrap(career.openTalk(forPlayer: athlete.id))
        let asStarter = try XCTUnwrap(career.wageNeeded(talk: open, years: open.years, role: .key))
        let asBackup = try XCTUnwrap(career.wageNeeded(talk: open, years: open.years, role: .backup))
        XCTAssertGreaterThanOrEqual(asBackup, asStarter, "Papel menor custa mais salário")
        for _ in 0..<FootballCareer.maxRefusals { _ = career.proposeTerms(talkID: talk.id, wage: 10_000, years: 3, role: .rotation) }
        XCTAssertEqual(career.transferTalks.first { $0.id == talk.id }?.stage, .collapsed)
        XCTAssertTrue(career.memories(of: athlete.id).contains { $0.kind == .negotiationBroke })
    }

    func testTalkCollapsesWhenPlayerLeavesAndOldSavesLoad() throws {
        var career = careerInWindow()
        let athlete = try target(in: career)
        let talk = try XCTUnwrap(career.startTransferTalk(playerID: athlete.id))
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == athlete.id })
        career.players[index].teamID = FootballSeason.teams.first { $0.id != athlete.teamID && $0.id != career.selectedClubID }?.id
        career.progressTransferTalks()
        XCTAssertEqual(career.transferTalks.first { $0.id == talk.id }?.stage, .collapsed)

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(json["world"] as? [String: Any])
        var projects = try XCTUnwrap(world["projects"] as? [String: Any])
        for key in ["recruitment", "transferTalks", "nextTalkID"] { projects.removeValue(forKey: key) }
        world["projects"] = projects
        json["world"] = world
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.transferTalks.isEmpty)
        XCTAssertTrue(decoded.recruitmentBriefs.isEmpty)
    }
}
