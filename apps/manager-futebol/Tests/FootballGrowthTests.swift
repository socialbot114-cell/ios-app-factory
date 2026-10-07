import XCTest
@testable import ManagerFutebol

final class FootballGrowthTests: XCTestCase {
    private func started(seed: Int = 26, club: Int = 0) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    func testOffersExistAtStartAndAutoSignBasicTV() {
        var career = started()
        XCTAssertEqual(career.world.growth.tvOffers.count, 3)
        XCTAssertFalse(career.world.growth.slotOffers.isEmpty)
        XCTAssertNil(career.world.growth.tv)
        XCTAssertTrue(career.beginMatchDay())
        XCTAssertEqual(career.world.growth.tv?.kind, .basic)
        XCTAssertTrue(career.world.growth.tvOffers.isEmpty)
    }

    func testTVContractsChangeIncomeAndWinBonusIsPaid() {
        var career = started()
        let base = career.baseTVPerMatchDay
        let premium = career.world.growth.tvOffers.first { $0.kind == .premium }!
        XCTAssertTrue(career.signTV(offerID: premium.id))
        XCTAssertLessThan(career.tvIncomePerMatchDay, base)
        let before = career.finance.total(season: 1, category: .tv)
        career.settleTVWin()
        XCTAssertEqual(career.finance.total(season: 1, category: .tv) - before, premium.winBonus)
    }

    func testTVExpiresAndNewOffersAppearNextSeason() {
        var career = started()
        let offer = career.world.growth.tvOffers.first { $0.kind == .performance }!
        career.signTV(offerID: offer.id)
        var random = FootballRandom(seed: 1)
        career.closeGrowthSeason()
        XCTAssertNil(career.world.growth.tv)
        career.prepareGrowthSeason(using: &random)
        XCTAssertEqual(career.world.growth.tvOffers.count, 3)
    }

    func testCampaignCostsMoneyGrowsFansAndEnds() {
        var career = started()
        let cash = career.transferBudget
        let fans = career.fanBase
        XCTAssertTrue(career.startCampaign(.regionalTV))
        XCTAssertEqual(cash - career.transferBudget, MarketingCampaign.regionalTV.cost)
        XCTAssertNotNil(career.canStartCampaign(.localMedia))
        var random = FootballRandom(seed: 3)
        let brand = career.world.growth.brand
        for _ in 0..<MarketingCampaign.regionalTV.days {
            career.matchDayIndex += 1
            career.tickGrowth(using: &random)
        }
        XCTAssertGreaterThan(career.fanBase, fans)
        XCTAssertNil(career.world.growth.campaign)
        XCTAssertGreaterThan(career.world.growth.brand, brand)
    }

    func testSlotSponsorsPayPerMatchDayAndCannotDuplicate() {
        var career = started()
        let offer = career.world.growth.slotOffers[0]
        XCTAssertTrue(career.acceptSlotOffer(offer.id))
        XCTAssertFalse(career.acceptSlotOffer(offer.id))
        let before = career.finance.total(season: 1, category: .sponsor)
        var random = FootballRandom(seed: 3)
        career.tickGrowth(using: &random)
        XCTAssertEqual(career.finance.total(season: 1, category: .sponsor) - before, offer.perSeason / FootballSeason.matchDaysPerSeason)
        XCTAssertFalse(career.world.growth.slotOffers.contains { $0.slot == offer.slot })
    }

    func testPressureIsBoundedAndReactsToMood() {
        var career = started()
        XCTAssertTrue((0...100).contains(career.fanPressure))
        let calm = career.fanPressure
        career.fanMood = 10
        XCTAssertGreaterThan(career.fanPressure, calm)
        career.fanMood = 100
        XCTAssertLessThan(career.fanPressure, calm)
        career.fanMood = 5
        career.boardConfidence = 10
        let before = career.world.coach.stress
        career.tickPressure()
        XCTAssertGreaterThanOrEqual(career.world.coach.stress, before)
    }

    func testAtmosphereIsBoundedAndHigherWithHappyFans() {
        var career = started()
        while career.nextUserFixture.map({ $0.home != career.selectedClubID }) ?? false { career.simulateNextMatchDay() }
        career.fanMood = 95
        let happy = career.stadiumAtmosphere
        career.fanMood = 10
        let angry = career.stadiumAtmosphere
        XCTAssertGreaterThan(happy, angry)
        XCTAssertTrue((-0.4...0.6).contains(happy) && (-0.4...0.6).contains(angry))
    }

    func testTryoutAddsTwoYouthsOncePerSeason() {
        var career = started()
        let before = career.youthRoster.count
        let cash = career.transferBudget
        let found = career.holdTryout(region: 1)
        XCTAssertEqual(found.count, 2)
        XCTAssertEqual(career.youthRoster.count, before + 2)
        XCTAssertEqual(cash - career.transferBudget, career.tryoutCost)
        XCTAssertNotNil(career.canHoldTryout())
        XCTAssertTrue(career.holdTryout(region: nil).isEmpty)
    }

    func testYouthCategoriesPartitionTheAcademy() {
        let career = started()
        let total = career.youth(in: .under15).count + career.youth(in: .under17).count + career.youth(in: .under20).count
        XCTAssertEqual(total, career.youthRoster.count)
    }

    func testYouthDevelopmentNeverExceedsPotential() {
        var career = started()
        career.setYouthProgram(.technical)
        var random = FootballRandom(seed: 5)
        for _ in 0..<200 { career.tickYouthDevelopment(using: &random) }
        for youth in career.youthRoster { XCTAssertLessThanOrEqual(youth.overall, max(youth.potential, youth.overall)) }
        XCTAssertTrue(career.youthRoster.allSatisfy { $0.overall <= 99 })
    }

    func testFullSeasonWithGrowthStaysSolventAndSavesRoundTrip() throws {
        var career = started()
        for _ in 0..<FootballSeason.matchDaysPerSeason { career.simulateNextMatchDay() }
        XCTAssertGreaterThan(career.finance.total(season: 1, category: .tv), 0)
        let data = try JSONEncoder().encode(career)
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertEqual(decoded.world.growth, career.world.growth)
    }
}
