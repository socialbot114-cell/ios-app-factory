import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballStaffTasksTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    private func playDays(_ career: inout FootballCareer, _ count: Int) {
        for _ in 0..<count { XCTAssertTrue(career.simulateNextMatchDay()) }
    }

    func testTaskRunsForItsDurationAndDeliversAReport() throws {
        var career = career()
        XCTAssertTrue(career.assignStaffTask(.studyRival))
        XCTAssertNotNil(career.staffTaskBlocker(.studyRival), "O auxiliar fica ocupado")
        let fixtureID = try XCTUnwrap(career.runningStaffTasks.first?.fixtureID)
        playDays(&career, StaffTaskKind.studyRival.days)
        let task = try XCTUnwrap(career.staffTasks.tasks.first)
        XCTAssertEqual(task.status, .done)
        XCTAssertFalse(task.report.isEmpty)
        XCTAssertTrue(career.inbox.contains { $0.title == "Relatório: \(StaffTaskKind.studyRival.title)" })
        XCTAssertTrue(career.staffTasks.studiedFixtureIDs.contains(fixtureID))
    }

    func testStaffLimitAndMissingProfessionals() {
        var career = career()
        let available = StaffTaskKind.allCases.filter { career.staffTaskBlocker($0) == nil }
        for kind in available { career.assignStaffTask(kind) }
        XCTAssertLessThanOrEqual(career.runningStaffTasks.count, FootballCareer.maxStaffTasks)
        if career.staffMember(.analyst) == nil {
            XCTAssertEqual(career.staffTaskBlocker(.performanceReport), "Contrate um \(StaffRole.analyst.title.lowercased()) para esta tarefa.")
        }
    }

    func testRecoveryPlanRestoresConditionAndLowersInjuryRisk() throws {
        var career = career()
        guard career.staffMember(.fitnessCoach) != nil else { throw XCTSkip("Clube sem preparador") }
        let risk = career.injuryRiskFactor
        XCTAssertTrue(career.assignStaffTask(.recoveryPlan))
        XCTAssertEqual(career.injuryRiskFactor, risk * 0.9, accuracy: 0.0001)
        for index in career.players.indices where career.startingXI.contains(career.players[index].id) { career.players[index].condition = 60 }
        career.progressStaffTasks()
        XCTAssertTrue(career.starters.allSatisfy { $0.condition >= 63 })
    }

    func testMedicalReviewShortensInjuries() throws {
        var career = career()
        guard career.staffMember(.doctor) != nil else { throw XCTSkip("Clube sem médico") }
        let index = try XCTUnwrap(career.players.firstIndex { $0.teamID == career.selectedClubID })
        career.players[index].injuryRounds = 4
        XCTAssertTrue(career.assignStaffTask(.medicalReview))
        career.matchDayIndex += StaffTaskKind.medicalReview.days
        career.progressStaffTasks()
        XCTAssertEqual(career.players[index].injuryRounds, 3)
    }

    func testAutoDelegationPicksWhatIsNeeded() throws {
        var career = career()
        career.setStaffAutoDelegate(true)
        for index in career.players.indices where career.startingXI.contains(career.players[index].id) { career.players[index].condition = 55 }
        career.progressStaffTasks()
        XCTAssertFalse(career.runningStaffTasks.isEmpty)
        XCTAssertTrue(career.runningStaffTasks.allSatisfy(\.delegated))
        if career.staffMember(.fitnessCoach) != nil {
            XCTAssertTrue(career.runningStaffTasks.contains { $0.kind == .recoveryPlan })
        }
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip.staffTasks, career.staffTasks)
    }
}
