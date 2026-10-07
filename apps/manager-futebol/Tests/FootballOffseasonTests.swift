import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballOffseasonTests: XCTestCase {
    /// Carreira com a temporada inteira jogada e a diretoria satisfeita, pronta para o ritual de virada.
    private func finishedSeason(seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(0))
        var days = 0
        while !career.isSeasonComplete, days < FootballSeason.matchDaysPerSeason + 5 {
            if !career.simulateNextMatchDay() { break }
            days += 1
        }
        XCTAssertTrue(career.isSeasonComplete)
        career.boardConfidence = 100
        return career
    }

    func testRitualOnlyStartsWhenTheSeasonIsComplete() {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertFalse(career.beginOffseason())
        XCTAssertNil(career.offseason)
        var done = finishedSeason()
        XCTAssertTrue(done.beginOffseason())
        XCTAssertEqual(done.offseason?.step, .endOfSeason)
        XCTAssertFalse(done.beginOffseason(), "Não abre duas vezes")
    }

    func testWalkingEveryStepInOrderAndNothingCanBeSkipped() throws {
        var career = finishedSeason()
        let firstSeason = career.season
        XCTAssertTrue(career.beginOffseason())
        var visited: [OffseasonStep] = []
        var guardCount = 0
        while let step = career.offseason?.step, guardCount < 20 {
            visited.append(step)
            switch step {
            case .iconPack:
                XCTAssertFalse(career.advanceOffseason(), "O pacote precisa ser aberto")
            case .holiday:
                XCTAssertFalse(career.advanceOffseason(), "As férias precisam de uma decisão")
            case .sponsor:
                XCTAssertFalse(career.advanceOffseason(), "O patrocinador precisa ser escolhido")
            case .preseason:
                XCTAssertFalse(career.advanceOffseason(), "A pré-temporada precisa de uma decisão")
            default:
                break
            }
            if step == .review || step == .holiday || step == .iconPack {
                XCTAssertFalse(career.canPlay, "Ninguém joga durante o ritual")
            }
            career.applyDefaultOffseasonDecision()
            XCTAssertTrue(career.advanceOffseason(), "Etapa \(step) deveria avançar depois da decisão")
            guardCount += 1
        }
        XCTAssertNil(career.offseason)
        XCTAssertEqual(career.season, firstSeason + 1)
        XCTAssertTrue(visited.contains(.endOfSeason))
        XCTAssertTrue(visited.contains(.review))
        XCTAssertTrue(visited.contains(.holiday))
        XCTAssertTrue(visited.contains(.preseason))
        XCTAssertEqual(visited.last, .kickoff)
        XCTAssertEqual(visited, visited.sorted { $0.rawValue < $1.rawValue }, "As etapas seguem a ordem")
        XCTAssertTrue(career.canPlay, "Depois do ritual a temporada pode começar")
    }

    func testCloseSeasonHappensOnlyWhenLeavingTheLastPreCloseStep() throws {
        var career = finishedSeason()
        let firstSeason = career.season
        XCTAssertTrue(career.beginOffseason())
        XCTAssertEqual(career.season, firstSeason)
        if !career.expiringContractPlayers.isEmpty {
            XCTAssertTrue(career.advanceOffseason())
            XCTAssertEqual(career.offseason?.step, .contracts)
            XCTAssertEqual(career.season, firstSeason, "Ver os contratos ainda não vira a temporada")
        }
        XCTAssertTrue(career.advanceOffseason())
        XCTAssertEqual(career.season, firstSeason + 1)
        XCTAssertEqual(career.offseason?.step, .review)
    }

    func testHolidayChangesMoraleConditionAndHealsInjuries() throws {
        var career = FootballCareer.offseasonPreview(at: .holiday)
        XCTAssertEqual(career.offseason?.step, .holiday)
        let clubID = try XCTUnwrap(career.selectedClubID)
        let injured = try XCTUnwrap(career.players.firstIndex { $0.teamID == clubID && !$0.isYouth })
        career.players[injured].injuryRounds = 3
        let moraleBefore = career.players.filter { $0.teamID == clubID }.map(\.morale)
        XCTAssertTrue(career.chooseHoliday(.fullRest))
        let moraleAfter = career.players.filter { $0.teamID == clubID }.map(\.morale)
        XCTAssertTrue(zip(moraleBefore, moraleAfter).allSatisfy { $1 >= $0 })
        XCTAssertGreaterThan(moraleAfter.reduce(0, +), moraleBefore.reduce(0, +))
        XCTAssertEqual(career.players[injured].injuryRounds, 0)
        XCTAssertFalse(career.chooseHoliday(.noBreak), "Só uma decisão de férias por ritual")
        XCTAssertEqual(career.offseason?.holiday, .fullRest)
    }

    func testNoBreakCostsMorale() throws {
        var career = FootballCareer.offseasonPreview(at: .holiday)
        let clubID = try XCTUnwrap(career.selectedClubID)
        let before = career.players.filter { $0.teamID == clubID }.map(\.morale).reduce(0, +)
        XCTAssertTrue(career.chooseHoliday(.noBreak))
        let after = career.players.filter { $0.teamID == clubID }.map(\.morale).reduce(0, +)
        XCTAssertLessThan(after, before)
    }

    func testCampCostsMoneyOnlyWhenAffordableAndGrowsTheFanBase() throws {
        var career = FootballCareer.offseasonPreview(at: .preseason)
        XCTAssertEqual(career.offseason?.step, .preseason)
        let base = try XCTUnwrap(career.selectedClub).startingBudget

        var poor = career
        poor.transferBudget = 0
        XCTAssertFalse(poor.canAffordCamp(.overseasTour))
        XCTAssertFalse(poor.chooseCamp(.overseasTour))
        XCTAssertEqual(poor.offseason?.step, .preseason)
        XCTAssertNil(poor.offseason?.camp)

        career.transferBudget = 50_000_000
        let fans = career.fanBase
        XCTAssertTrue(career.chooseCamp(.overseasTour))
        let expected = 50_000_000 - PreseasonCamp.overseasTour.cost(baseBudget: base) + PreseasonCamp.overseasTour.revenue(baseBudget: base)
        XCTAssertEqual(career.transferBudget, expected)
        XCTAssertGreaterThan(career.fanBase, fans)
        XCTAssertNotNil(career.offseason?.campReport)
        XCTAssertFalse(career.chooseCamp(.homeTraining), "Só uma preparação por ritual")
    }

    func testHomeTrainingIsAlwaysFreeAndAffordable() {
        var career = FootballCareer.offseasonPreview(at: .preseason)
        career.transferBudget = 0
        XCTAssertTrue(career.canAffordCamp(.homeTraining))
        XCTAssertTrue(career.chooseCamp(.homeTraining))
        XCTAssertEqual(career.transferBudget, 0)
    }

    func testPlayAndCalendarAreBlockedWhileTheRitualIsOpen() {
        var career = FootballCareer.offseasonPreview(at: .holiday)
        XCTAssertTrue(career.isInOffseason)
        XCTAssertFalse(career.canPlay)
        XCTAssertFalse(career.canAdvanceWithoutPlaying)
        XCTAssertFalse(career.beginMatchDay())
        XCTAssertFalse(career.simulateNextMatchDay())
    }

    func testRitualSurvivesSaveAndOldSavesHaveNone() throws {
        let career = FootballCareer.offseasonPreview(at: .holiday)
        let data = try JSONEncoder().encode(career)
        let loaded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertEqual(loaded.offseason, career.offseason)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["offseason"] = nil
        let old = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(old.offseason)
    }

    func testSponsorStepAppearsWhenTheDealEndedAndRequiresAChoice() throws {
        var career = FootballCareer.offseasonPreview(at: .sponsor)
        guard career.offseason?.step == .sponsor else {
            // O contrato de patrocínio continua válido: a etapa é pulada de propósito.
            XCTAssertTrue(career.sponsorOffers.isEmpty)
            return
        }
        XCTAssertFalse(career.sponsorOffers.isEmpty)
        XCTAssertFalse(career.advanceOffseason())
        let offer = try XCTUnwrap(career.sponsorOffers.first)
        XCTAssertTrue(career.acceptSponsorOffer(offer.id))
        XCTAssertNotNil(career.sponsorDeal)
        XCTAssertTrue(career.advanceOffseason())
        XCTAssertEqual(career.offseason?.step, .preseason)
    }
}
