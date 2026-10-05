import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballCoachLoanTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.world.coach.personalCash = 2_000_000
        return career
    }

    private func playDays(_ career: inout FootballCareer, _ count: Int) {
        for _ in 0..<count { XCTAssertTrue(career.simulateNextMatchDay()) }
    }

    func testLoanIsRepaidAfterGraceAndMoneyReconciles() throws {
        var career = career()
        career.transferBudget = 20_000_000
        XCTAssertTrue(career.lendToClub(amount: 240_000))
        let loan = try XCTUnwrap(career.activeCoachLoans.first)
        XCTAssertEqual(loan.installment, 20_000)
        XCTAssertEqual(career.coachLoanOutstanding, 240_000)

        playDays(&career, FootballCareer.coachLoanGraceDays - 1)
        XCTAssertEqual(career.coachLoanOutstanding, 240_000, "Sem parcela durante a carência")
        let cashBefore = career.world.coach.personalCash
        playDays(&career, 1)
        XCTAssertEqual(career.coachLoanOutstanding, 220_000)
        let refunds = career.finance.entries.filter { $0.note == "Devolução do aporte ao treinador" }
        XCTAssertEqual(refunds.map(\.amount), [-20_000])
        XCTAssertGreaterThanOrEqual(career.world.coach.personalCash - cashBefore, 20_000 - 1, "Parcela volta ao bolso")

        playDays(&career, 11)
        let done = try XCTUnwrap(career.coachLoans.first { $0.id == loan.id })
        XCTAssertEqual(done.status, .repaid)
        XCTAssertEqual(career.finance.entries.filter { $0.note == "Devolução do aporte ao treinador" }.reduce(0) { $0 + $1.amount }, -240_000,
                       "Devolvido exatamente o emprestado, nem mais nem menos")
        XCTAssertTrue(career.inbox.contains { $0.title == "Aporte devolvido" })
    }

    func testInstallmentWaitsWhenTheClubHasNoCash() throws {
        var career = career()
        career.transferBudget = -1_000_000
        XCTAssertTrue(career.lendToClub(amount: 100_000))
        career.matchDayIndex += FootballCareer.coachLoanGraceDays
        career.repayCoachLoans()
        let loan = try XCTUnwrap(career.activeCoachLoans.first)
        XCTAssertEqual(loan.outstanding, 100_000)
        XCTAssertEqual(loan.postponed, 1)
        XCTAssertFalse(career.finance.entries.contains { $0.note == "Devolução do aporte ao treinador" })
    }

    func testForgivingTurnsLoanIntoDonationOnce() throws {
        var career = career()
        career.transferBudget = 5_000_000
        XCTAssertTrue(career.lendToClub(amount: 200_000))
        let id = try XCTUnwrap(career.activeCoachLoans.first?.id)
        let confidence = career.boardConfidence
        XCTAssertTrue(career.forgiveCoachLoan(id))
        XCTAssertEqual(career.boardConfidence, min(100, confidence + 3))
        XCTAssertFalse(career.forgiveCoachLoan(id), "Não se perdoa duas vezes")
        XCTAssertEqual(career.coachLoanOutstanding, 0)
        playDays(&career, FootballCareer.coachLoanGraceDays + 2)
        XCTAssertFalse(career.finance.entries.contains { $0.note == "Devolução do aporte ao treinador" })
    }

    func testProjectionShowsRepaymentsAndDepartureSettles() throws {
        var career = career()
        career.transferBudget = 5_000_000
        XCTAssertTrue(career.lendToClub(amount: 120_000))
        let line = try XCTUnwrap(career.cashProjection(horizon: 8).lines.first { $0.title == "Devolução do aporte ao treinador" })
        XCTAssertEqual(line.certainty, .contracted)
        // Carência de 3 dias: o tick do dia 2 (índice) já paga, pois o calendário avança antes; 6 parcelas no horizonte de 8.
        XCTAssertEqual(line.total, -10_000 * (8 - FootballCareer.coachLoanGraceDays + 1))

        let cash = career.world.coach.personalCash
        XCTAssertTrue(career.resign())
        let job = try XCTUnwrap(career.jobOffers.first)
        XCTAssertTrue(career.acceptJob(job.id))
        XCTAssertEqual(career.world.coach.personalCash, cash + 120_000, "Rescisão quita o saldo devedor")
        XCTAssertEqual(career.coachLoans.first?.status, .settled)
        XCTAssertTrue(career.activeCoachLoans.isEmpty)
    }

    func testLegacyProjectsWithoutLoansLoad() throws {
        let career = career()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(json["world"] as? [String: Any])
        var projects = try XCTUnwrap(world["projects"] as? [String: Any])
        projects.removeValue(forKey: "coachLoans")
        projects.removeValue(forKey: "nextLoanID")
        world["projects"] = projects
        json["world"] = world
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.coachLoans.isEmpty)
    }
}
