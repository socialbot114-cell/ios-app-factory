import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballBrandImageTests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.transferBudget = 20_000_000
        career.world.coach.energy = 90
        return career
    }

    private func playDays(_ career: inout FootballCareer, _ count: Int) {
        for _ in 0..<count { XCTAssertTrue(career.simulateNextMatchDay()) }
    }

    // MARK: MAR-01

    func testThreeIndicatorsAreSeparateAndExplained() {
        var career = career()
        career.reputation = 60
        career.world.social.controversy = 0
        let calm = career.coachImage
        career.world.social.controversy = 40
        XCTAssertEqual(career.coachImage, calm - 10, "Polêmica pesa na imagem do treinador, não na marca do clube")
        let indicators = career.brandIndicators
        XCTAssertEqual(indicators.clubBrand, career.world.growth.brand)
        XCTAssertEqual(indicators.fanMood, career.fanMood)
        XCTAssertEqual(BrandIndicators.definitions.count, 3)
    }

    // MARK: MAR-02 / MAR-05

    func testBriefChangesCostAndForecast() {
        let career = career()
        let lean = CampaignBrief(channel: .influencers, objective: .fans, audience: .young, budget: .lean)
        let heavy = CampaignBrief(channel: .influencers, objective: .fans, audience: .young, budget: .heavy)
        XCTAssertLessThan(career.campaignCost(lean), career.campaignCost(heavy))
        XCTAssertLessThan(career.campaignForecast(lean), career.campaignForecast(heavy))
        let matched = CampaignBrief(channel: .influencers, objective: .fans, audience: .young, budget: .standard)
        let mismatched = CampaignBrief(channel: .influencers, objective: .fans, audience: .local, budget: .standard)
        XCTAssertGreaterThan(career.campaignForecast(matched), career.campaignForecast(mismatched), "Canal certo para o público rende mais")
    }

    func testCampaignRunsIsEvaluatedOnceAndRefreshesOffersOnSuccess() throws {
        var career = career()
        let brief = CampaignBrief(channel: .stadiumFest, objective: .mood, audience: .families, budget: .heavy)
        let cash = career.transferBudget
        XCTAssertTrue(career.launchCampaign(brief))
        XCTAssertEqual(career.transferBudget, cash - career.campaignCost(brief))
        XCTAssertNotNil(career.campaignBlocker(brief), "Uma campanha por vez")
        playDays(&career, brief.channel.days + 2)
        let record = try XCTUnwrap(career.brandState.campaigns.last)
        XCTAssertNotNil(record.verdict)
        XCTAssertGreaterThan(record.realized, 0)
        XCTAssertEqual(career.inbox.filter { $0.title == "Avaliação da campanha" }.count, 1, "Avaliada uma vez")
        XCTAssertNil(career.world.growth.campaign)
    }

    // MARK: MAR-03

    func testImageContractChecksEveryObligation() throws {
        var kept = career()
        kept.reputation = 60
        let offer = try XCTUnwrap(kept.imageContractOffer)
        let cash = kept.world.coach.personalCash
        XCTAssertTrue(kept.signImageContract())
        XCTAssertEqual(kept.world.coach.personalCash, cash + offer.payment)
        XCTAssertNil(kept.imageContractOffer, "Um contrato por vez")
        for _ in 0..<offer.shootsRequired {
            kept.world.coach.energy = 90
            XCTAssertNotNil(kept.doActivity(.sponsorShoot))
            playDays(&kept, 1)
        }
        while kept.worldDay < offer.deadlineWorldDay { playDays(&kept, 1) }
        kept.reputation = max(kept.reputation, 60)
        kept.world.social.controversy = 0
        kept.progressImageContract()
        XCTAssertEqual(kept.brandState.contracts.last?.status, .fulfilled)

        var broken = career()
        broken.reputation = 60
        XCTAssertTrue(broken.signImageContract())
        let deadline = try XCTUnwrap(broken.activeImageContract?.deadlineWorldDay)
        broken.matchDayIndex = deadline - (broken.season - 1) * FootballSeason.matchDaysPerSeason
        let before = broken.world.coach.personalCash
        broken.progressImageContract()
        let contract = try XCTUnwrap(broken.brandState.contracts.last)
        XCTAssertEqual(contract.status, .breached)
        XCTAssertTrue(contract.failures.contains { $0.contains("comerciais") })
        XCTAssertEqual(broken.world.coach.personalCash, before - contract.payment / 2)
    }

    // MARK: MAR-04

    func testEveryMovementHasObservableCauses() throws {
        var career = career()
        XCTAssertTrue(career.launchCampaign(CampaignBrief(channel: .influencers, objective: .fans, audience: .young, budget: .standard)))
        playDays(&career, 8)
        XCTAssertGreaterThanOrEqual(career.brandState.snapshots.count, 8)
        XCTAssertFalse(career.brandState.movements.isEmpty)
        XCTAssertTrue(career.brandState.movements.allSatisfy { !$0.causes.isEmpty && $0.delta != 0 })
        XCTAssertTrue(career.brandState.movements.contains { $0.causes.contains { $0.hasPrefix("Vitória") || $0.hasPrefix("Derrota") || $0.hasPrefix("Empate") || $0.hasPrefix("Campanha") } })
    }

    func testClubChangeClosesCampaignAndOldSavesLoad() throws {
        var career = career()
        XCTAssertTrue(career.launchCampaign(CampaignBrief(channel: .localMedia, objective: .brand, audience: .local, budget: .lean)))
        XCTAssertTrue(career.resign())
        let job = try XCTUnwrap(career.jobOffers.first)
        XCTAssertTrue(career.acceptJob(job.id))
        XCTAssertFalse(career.brandState.campaigns.contains(where: \.isRunning))
        XCTAssertNil(career.world.growth.campaign)

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(json["world"] as? [String: Any])
        var projects = try XCTUnwrap(world["projects"] as? [String: Any])
        projects.removeValue(forKey: "brand")
        world["projects"] = projects
        json["world"] = world
        let decoded = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.brandState.campaigns.isEmpty)
    }
}
