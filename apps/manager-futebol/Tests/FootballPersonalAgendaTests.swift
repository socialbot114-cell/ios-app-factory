import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballPersonalAgendaTests: XCTestCase {
    private func career(club: Int = 0, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.world.coach.energy = 90
        return career
    }

    private func playDays(_ career: inout FootballCareer, _ count: Int) {
        for _ in 0..<count { XCTAssertTrue(career.simulateNextMatchDay()) }
    }

    func testPlannedActivityRunsOnItsDayOnce() throws {
        var career = career()
        let day = career.worldDay
        XCTAssertTrue(career.planActivity(.podcast, on: day))
        playDays(&career, 1)
        let entry = try XCTUnwrap(career.world.projects.personalPlan.first { $0.worldDay == day })
        XCTAssertEqual(entry.status, .done)
        XCTAssertFalse(entry.note.isEmpty)
        XCTAssertEqual(career.world.coach.lastActivityWorldDay, day)
        playDays(&career, 1)
        XCTAssertEqual(career.world.projects.personalPlan.filter { $0.worldDay == day && $0.status == .done }.count, 1)
        XCTAssertNil(career.canDo(.podcast), "O plano de ontem não bloqueia a atividade de hoje")
    }

    func testAwayMatchBlocksInPersonActivitiesButNotRemoteOnes() throws {
        let career = career()
        let away = try XCTUnwrap(career.personalPlanDays.first(where: \.isAway))
        let conflicts = career.planConflicts(.lecture, on: away.worldDay)
        XCTAssertTrue(conflicts.contains { $0.severity == .blocking && $0.text.hasPrefix("Dia de viagem") })
        XCTAssertFalse(career.planConflicts(.podcast, on: away.worldDay).contains { $0.severity == .blocking })
        var copy = career
        XCTAssertFalse(copy.planActivity(.lecture, on: away.worldDay))
    }

    func testEnergyProjectionChainsTheWholePlan() throws {
        var career = career()
        career.world.coach.energy = 30
        let days = career.personalPlanDays.map(\.worldDay)
        let remote: [CoachActivity] = [.writeBook, .podcast]
        XCTAssertTrue(career.planActivity(remote[0], on: days[0]))
        XCTAssertTrue(career.planActivity(remote[1], on: days[1]))
        let energy = career.projectedCoachEnergy(through: days[2])
        XCTAssertEqual(energy[days[0]], 30)
        XCTAssertEqual(energy[days[1]], 30 - CoachActivity.writeBook.energyCost + 3)
        XCTAssertEqual(energy[days[2]], 30 - CoachActivity.writeBook.energyCost + 3 - CoachActivity.podcast.energyCost + 3)
        career.world.coach.energy = 12
        career.world.projects.personalPlan = []
        let conflicts = career.planConflicts(.writeBook, on: days[0])
        XCTAssertTrue(conflicts.contains { $0.severity == .blocking && $0.text.hasPrefix("Energia prevista") })
        XCTAssertTrue(career.planActivity(.rest, on: days[0]), "Descansar nunca falta energia")
    }

    func testReplacingAPlanSaysWhatIsSacrificed() throws {
        var career = career()
        let day = career.worldDay + 1
        XCTAssertTrue(career.planActivity(.writeBook, on: day))
        let conflicts = career.planConflicts(.podcast, on: day)
        XCTAssertTrue(conflicts.contains { $0.severity == .warning && $0.text.contains("escrever um livro") })
        XCTAssertTrue(career.planActivity(.podcast, on: day))
        XCTAssertEqual(career.world.projects.personalPlan.filter { $0.worldDay == day }.map(\.activity), [.podcast])
        career.unplanActivity(on: day)
        XCTAssertTrue(career.world.projects.personalPlan.isEmpty)
    }

    func testManualActivityWinsAndThePlanIsSkippedWithAReason() throws {
        var career = career()
        let day = career.worldDay
        XCTAssertTrue(career.planActivity(.writeBook, on: day))
        XCTAssertNotNil(career.doActivity(.podcast))
        XCTAssertTrue(career.planConflicts(.rest, on: day).contains { $0.text == "Você já fez uma atividade hoje." })
        playDays(&career, 1)
        let entry = try XCTUnwrap(career.world.projects.personalPlan.first { $0.worldDay == day })
        XCTAssertEqual(entry.status, .skipped)
        XCTAssertTrue(entry.note.contains("outra atividade"))
        XCTAssertTrue(career.inbox.contains { $0.title == "Agenda: \(CoachActivity.writeBook.title) cancelado" })
    }

    func testClubDeadlinesAndDerbiesAppearAsWarnings() throws {
        var career = career()
        let day = career.worldDay + 2
        career.promises = [PlayerPromise(id: 1, playerID: career.clubRoster[0].id, requiredStarts: 3, startsDone: 0,
                                         deadlineMatchDay: day - (career.season - 1) * FootballSeason.matchDaysPerSeason + 1,
                                         season: career.season)]
        let planDay = try XCTUnwrap(career.personalPlanDays.first { $0.worldDay == day })
        XCTAssertFalse(planDay.deadlines.isEmpty)
        XCTAssertTrue(career.planConflicts(.podcast, on: day).contains { $0.text.hasPrefix("No mesmo dia vence") })
        XCTAssertFalse(career.planConflicts(.podcast, on: day).contains { $0.severity == .blocking })
    }

    func testOutOfHorizonAndSeasonTurn() throws {
        var career = career()
        let far = career.worldDay + FootballCareer.personalPlanHorizon
        XCTAssertTrue(career.planConflicts(.rest, on: far).contains { $0.severity == .blocking })
        XCTAssertFalse(career.planActivity(.rest, on: career.worldDay - 1))
        XCTAssertTrue(career.planActivity(.rest, on: career.worldDay + 3))
        career.closePersonalPlanSeason()
        XCTAssertEqual(career.world.projects.personalPlan.first?.status, .skipped)
    }

    func testLegacyProjectsWithoutPlanStillLoad() throws {
        var career = career()
        XCTAssertTrue(career.planActivity(.rest, on: career.worldDay))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(json["world"] as? [String: Any])
        var projects = try XCTUnwrap(world["projects"] as? [String: Any])
        projects.removeValue(forKey: "personalPlan")
        projects.removeValue(forKey: "nextPlanID")
        world["projects"] = projects
        json["world"] = world
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.world.projects.personalPlan.isEmpty)
        XCTAssertEqual(decoded.world.projects.nextPlanID, 1)
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip.world.projects.personalPlan, career.world.projects.personalPlan)
    }
}
