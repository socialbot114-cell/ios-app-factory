import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballBusinessDealsTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.transferBudget = 30_000_000
        return career
    }

    private func playDays(_ career: inout FootballCareer, _ count: Int) {
        for _ in 0..<count { XCTAssertTrue(career.simulateNextMatchDay()) }
    }

    // MARK: NEG-03

    func testNamingNegotiationCountersAgreesAndReactsToTheName() throws {
        var career = career()
        var random = FootballRandom(seed: 4)
        career.refreshNamingOffers(using: &random)
        let offer = try XCTUnwrap(career.world.business.namingOffers.first)
        let talk = try XCTUnwrap(career.startNamingTalk(offerID: offer.id))
        XCTAssertNil(career.startNamingTalk(offerID: offer.id), "Uma negociação por vez")
        // Pedido um pouco alto: contraproposta com o teto da marca.
        let high = Int(Double(talk.reservePerSeason) * 1.1)
        guard case .counter(let counter, _) = career.proposeNaming(talkID: talk.id, perSeason: high, seasons: offer.seasons, keepTraditionalName: false) else {
            return XCTFail("Esperava contraproposta")
        }
        XCTAssertGreaterThan(counter, offer.perSeason, "Negociar rende mais que a oferta inicial")
        career.fanMood = 60
        let mood = career.fanMood
        guard case .agreed = career.proposeNaming(talkID: talk.id, perSeason: counter, seasons: offer.seasons, keepTraditionalName: false) else {
            return XCTFail("Esperava acordo")
        }
        XCTAssertEqual(career.world.business.naming?.perSeason, counter)
        XCTAssertEqual(career.fanMood, mood - career.namingBacklash(keepTraditionalName: false) - 0)
        XCTAssertNotNil(career.fact("naming-\(talk.id)"))
        XCTAssertTrue(career.projectLedger.contains { $0.kind == .naming })
    }

    func testTraditionalNameCostsValueButSoftensTheReaction() {
        let career = career()
        XCTAssertLessThan(career.namingBacklash(keepTraditionalName: true), career.namingBacklash(keepTraditionalName: false))
    }

    func testTwoRefusalsMakeTheSponsorWalkAway() throws {
        var career = career()
        var random = FootballRandom(seed: 4)
        career.refreshNamingOffers(using: &random)
        let offer = try XCTUnwrap(career.world.business.namingOffers.first)
        let talk = try XCTUnwrap(career.startNamingTalk(offerID: offer.id))
        for _ in 0..<2 { _ = career.proposeNaming(talkID: talk.id, perSeason: talk.reservePerSeason * 3, seasons: 3, keepTraditionalName: false) }
        XCTAssertEqual(career.deals.namingTalks.last?.status, .withdrawn)
        XCTAssertFalse(career.world.business.namingOffers.contains { $0.id == offer.id })
        XCTAssertNil(career.world.business.naming)
    }

    // MARK: NEG-04

    func testSocialProjectGoesThroughStagesAndRecordsResults() throws {
        var career = career()
        let fans = career.fanBase
        XCTAssertTrue(career.startSocialProject(.schoolProject))
        XCTAssertNotNil(career.socialProjectBlocker(.fanClubs), "Um projeto por vez")
        let total = SocialProject.Stage.allCases.reduce(0) { $0 + $1.days } + 2
        playDays(&career, total)
        let project = try XCTUnwrap(career.deals.socialProjects.last)
        XCTAssertEqual(project.stage, .done)
        XCTAssertGreaterThan(project.peopleReached, 0)
        XCTAssertGreaterThan(project.fansGained, 0)
        XCTAssertGreaterThan(career.fanBase, fans)
        XCTAssertEqual(project.spent, career.socialStageCost(.schoolProject, stage: .planning) + career.socialStageCost(.schoolProject, stage: .execution))
        XCTAssertTrue(project.reports.contains { $0.hasPrefix("Balanço") })
        XCTAssertNotNil(career.fact("social-\(project.id)"))
        let booked = career.finance.entries.filter { $0.note.hasPrefix("Projeto social") }.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(booked, -project.spent)
    }

    // MARK: NEG-05

    func testScheduledFriendlyIsPlayedOnItsDateWithEstimateAndResult() throws {
        var career = career()
        guard let date = career.freeFriendlyDates.first else { throw XCTSkip("Sem data livre nesta temporada") }
        let opponent = try XCTUnwrap(FootballSeason.teams.first { $0.id != career.selectedClubID }?.id)
        let friendly = try XCTUnwrap(career.scheduleFriendly(opponentID: opponent, home: true, matchDay: date))
        XCTAssertGreaterThan(friendly.expectedRevenue, 0)
        XCTAssertGreaterThan(friendly.expectedFatigue, 0)
        XCTAssertNotNil(career.friendlyBlocker(matchDay: date), "A data fica ocupada")
        var guardDays = 0
        while career.deals.friendlies.first(where: { $0.id == friendly.id })?.status == .scheduled, guardDays < 40 {
            XCTAssertTrue(career.simulateNextMatchDay())
            guardDays += 1
        }
        let played = try XCTUnwrap(career.deals.friendlies.first { $0.id == friendly.id })
        XCTAssertEqual(played.status, .played, played.result)
        XCTAssertTrue(played.result.contains("previsto"))
        XCTAssertEqual(career.world.business.friendlies.first?.opponentID, opponent)
    }

    func testFriendliesRespectDatesAndLimit() throws {
        var career = career()
        let busy = try XCTUnwrap(career.fixtures.first { $0.involves(career.selectedClubID!) && $0.matchDay > career.matchDayIndex }?.matchDay)
        XCTAssertNotNil(career.friendlyBlocker(matchDay: busy), "Não marca em dia de jogo")
        career.world.business.friendliesThisSeason = FootballCareer.friendlyLimit
        if let date = career.freeFriendlyDates.first { XCTAssertNotNil(career.friendlyBlocker(matchDay: date)) }
    }

    func testTourIsScheduledForNextPreseason() throws {
        var career = career()
        XCTAssertTrue(career.scheduleTour())
        XCTAssertFalse(career.scheduleTour(), "Uma excursão agendada por vez")
        while career.canPlay || career.canAdvanceWithoutPlaying { XCTAssertTrue(career.simulateNextMatchDay()) }
        let fans = career.fanBase
        _ = career.startNextSeason()
        if !career.isFired {
            XCTAssertEqual(career.world.business.tourDoneSeason, career.season)
            XCTAssertNil(career.deals.tourScheduledForSeason)
            _ = fans
        }
    }
}
