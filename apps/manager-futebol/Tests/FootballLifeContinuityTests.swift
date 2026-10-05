import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballLifeContinuityTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.world.coach.energy = 90
        career.reputation = 55
        return career
    }

    private func playDays(_ career: inout FootballCareer, _ count: Int) {
        for _ in 0..<count { XCTAssertTrue(career.simulateNextMatchDay()) }
    }

    // MARK: VID-02

    func testMediaContractSchedulesAppearancesAndPaysBonus() throws {
        var career = career()
        let offer = try XCTUnwrap(career.mediaContractOffer)
        XCTAssertEqual(offer.appearanceDays.count, 3)
        XCTAssertTrue(career.acceptMediaContract())
        XCTAssertNil(career.mediaContractOffer, "Um contrato por vez")
        let first = try XCTUnwrap(offer.appearanceDays.first)
        XCTAssertTrue(career.world.projects.personalPlan.contains { $0.worldDay == first && $0.activity == .tvPunditry },
                      "Aparição entra sozinha na agenda pessoal")
        var guardDays = 0
        while career.life.mediaContract?.status == .active, guardDays < 20 {
            career.world.coach.energy = 90
            XCTAssertTrue(career.simulateNextMatchDay())
            guardDays += 1
        }
        let contract = try XCTUnwrap(career.life.mediaContract)
        XCTAssertEqual(contract.status, .completed)
        XCTAssertEqual(contract.done.count, 3)
        XCTAssertEqual(career.life.mediaContractsDone, 1)
    }

    func testAppearanceOnANewTravelDayIsRescheduledNotPunished() throws {
        var career = career()
        XCTAssertTrue(career.acceptMediaContract())
        let days = try XCTUnwrap(career.life.mediaContract?.appearanceDays)
        // Simula o sorteio da copa: o dia da segunda aparição vira jogo fora.
        let target = days[1]
        let matchDay = target - (career.season - 1) * FootballSeason.matchDaysPerSeason
        let clubID = try XCTUnwrap(career.selectedClubID)
        let rival = try XCTUnwrap(FootballSeason.teams.first { $0.id != clubID }?.id)
        career.fixtures.removeAll { $0.matchDay == matchDay && $0.involves(clubID) }
        career.fixtures.append(LeagueFixture(id: 99_999, matchDay: matchDay, round: 1, competition: .league(.serieA), home: rival, away: clubID))
        career.schedulePendingAppearances()
        let moved = try XCTUnwrap(career.life.mediaContract?.appearanceDays)
        XCTAssertFalse(moved.contains(target))
        XCTAssertEqual(moved.count, 3)
        XCTAssertTrue(career.inbox.contains { $0.title == "Programa remarcado" })
        XCTAssertFalse(career.world.projects.personalPlan.contains { $0.worldDay == target && $0.activity == .tvPunditry && $0.status == .planned })
    }

    func testTwoMissedAppearancesCancelTheContract() throws {
        var career = career()
        XCTAssertTrue(career.acceptMediaContract())
        let days = try XCTUnwrap(career.life.mediaContract?.appearanceDays)
        let reputation = career.reputation
        // Esvazia a agenda: o treinador não aparece.
        _ = days
        while career.life.mediaContract?.status == .active, career.simulateNextMatchDay() {
            career.world.projects.personalPlan.removeAll { $0.activity == .tvPunditry && $0.status == .planned }
        }
        XCTAssertEqual(career.life.mediaContract?.status, .cancelled)
        XCTAssertEqual(career.life.mediaContract?.missed.count, 2)
        XCTAssertEqual(career.inbox.filter { $0.title == "Faltou ao programa" }.count, 2, "Cada falta é avisada e custa reputação")
        _ = reputation
        XCTAssertTrue(career.life.log.contains { $0.title == "Contrato de comentarista cancelado" })
    }

    func testBookDeadlineRewardsOnTimeDeliveryAndExtendsOnce() throws {
        var onTime = career()
        onTime.world.coach.bookSessions = 2
        playDays(&onTime, 1)
        let deadline = try XCTUnwrap(onTime.life.bookDeadlineWorldDay)
        XCTAssertEqual(deadline, onTime.worldDay + FootballCareer.bookDeadlineDays)
        let cash = onTime.world.coach.personalCash
        onTime.world.coach.booksPublished += 1
        onTime.world.coach.bookSessions = 0
        onTime.progressLife()
        XCTAssertEqual(onTime.world.coach.personalCash, cash + 15_000)
        XCTAssertNil(onTime.life.bookDeadlineWorldDay)

        var late = career()
        late.world.coach.bookSessions = 3
        late.progressLife()
        late.matchDayIndex += FootballCareer.bookDeadlineDays + 1
        late.progressLife()
        XCTAssertTrue(late.life.bookDeadlineExtended)
        XCTAssertTrue(late.inbox.contains { $0.title == "Livro atrasado" })
    }

    func testStalledCourseWarnsOnce() throws {
        var career = career()
        career.world.coach.personalCash = 1_000_000
        career.reputation = 80
        XCTAssertTrue(career.startCourse())
        career.matchDayIndex += FootballCareer.courseStallDays
        career.progressLife()
        career.progressLife()
        XCTAssertEqual(career.inbox.filter { $0.title == "Curso parado" }.count, 1)
        XCTAssertFalse(career.personalProjectsSummary.isEmpty)
    }

    // MARK: VID-03 / VID-04

    func testRestDependsOnTheWeekAndLeisureAssetsOnTravel() throws {
        var career = career()
        let familyIndex = try XCTUnwrap(career.world.contacts.contacts.firstIndex { $0.role == .family })
        career.world.contacts.contacts[familyIndex].relationship = 90
        career.world.coach.stress = 85
        let context = career.restContext(onWorldDay: career.worldDay)
        XCTAssertGreaterThanOrEqual(context.energy, 5)
        XCTAssertGreaterThanOrEqual(context.stress, 5)
        XCTAssertFalse(context.reasons.isEmpty)

        career.world.coach.assets = [OwnedAsset(id: 1, kind: .beachHouse, boughtSeason: 1), OwnedAsset(id: 2, kind: .apartment, boughtSeason: 1)]
        let days = career.personalPlanDays
        let away = try XCTUnwrap(days.first(where: \.isAway))
        let home = try XCTUnwrap(days.first { !$0.isAway })
        XCTAssertEqual(career.assetRestBonus(onWorldDay: away.worldDay), AssetKind.apartment.energyBonus, "Casa de praia não vale em dia de viagem")
        XCTAssertEqual(career.assetRestBonus(onWorldDay: home.worldDay), AssetKind.apartment.energyBonus + AssetKind.beachHouse.energyBonus)
        XCTAssertEqual(career.assetUpkeepPerSeason, AssetKind.beachHouse.upkeep + AssetKind.apartment.upkeep)
        XCTAssertEqual(career.assetNotes().count, 2)
    }

    // MARK: VID-05

    func testLifeContinuesWithoutAClub() throws {
        var career = career()
        career.world.coach.assets = [OwnedAsset(id: 1, kind: .yacht, boughtSeason: 1)]
        XCTAssertTrue(career.resign())
        XCTAssertNil(career.canDo(.podcast), "Atividades pessoais seguem sem clube")
        XCTAssertNil(career.canContact(.family))
        XCTAssertNotNil(career.canContact(.president), "Sem clube, sem presidente")
        let cash = career.world.coach.personalCash
        var random = FootballRandom(seed: 3)
        career.tickCoachFinances(using: &random)
        XCTAssertEqual(career.world.coach.personalCash, cash - AssetKind.yacht.upkeep / FootballSeason.matchDaysPerSeason,
                       "Sem salário, mas a manutenção da lancha continua")
    }

    // MARK: VID-06

    func testDecisionsAndWellbeingAreRecorded() throws {
        var career = career()
        career.world.coach.personalCash = 2_000_000
        XCTAssertTrue(career.buyAsset(.car))
        XCTAssertNotNil(career.doActivity(.podcast))
        playDays(&career, 3)
        XCTAssertTrue(career.life.log.contains { $0.title == "Comprou: \(AssetKind.car.title)" })
        XCTAssertTrue(career.life.log.contains { $0.title == CoachActivity.podcast.title })
        XCTAssertEqual(career.life.wellbeing.count, 3)
        XCTAssertEqual(career.life.wellbeing.last?.energy, career.world.coach.energy)
    }

    func testLegacyProjectsWithoutLifeLoad() throws {
        let career = career()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(json["world"] as? [String: Any])
        var projects = try XCTUnwrap(world["projects"] as? [String: Any])
        projects.removeValue(forKey: "life")
        world["projects"] = projects
        json["world"] = world
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.life.log.isEmpty)
        XCTAssertNil(decoded.life.mediaContract)
    }
}
