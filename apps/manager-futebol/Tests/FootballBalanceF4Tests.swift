import Foundation
import XCTest
@testable import ManagerFutebol

/// F4-06 (nenhuma ação sem custo domina) e F4-07 (troca de clube, demissão e nova temporada).
final class FootballBalanceF4Tests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    private func playDays(_ career: inout FootballCareer, _ count: Int) {
        for _ in 0..<count { XCTAssertTrue(career.simulateNextMatchDay()) }
    }

    // MARK: F4-06

    func testShopPriceIsATradeOffNotADominantChoice() {
        var career = career()
        var revenue: [ShopPrice: Int] = [:]
        for price in ShopPrice.allCases {
            career.setShopPrice(price)
            revenue[price] = career.baseMerchRevenuePerMatchDay
        }
        XCTAssertLessThan(revenue[.low]!, revenue[.normal]!, "Promoção não pode render mais e ainda agradar")
        XCTAssertGreaterThanOrEqual(revenue[.high]!, revenue[.normal]!)

        var cheap = career
        cheap.setShopPrice(.low)
        cheap.fanMood = 60
        var premium = career
        premium.setShopPrice(.high)
        premium.fanMood = 60
        for day in 0..<40 {
            cheap.matchDayIndex = day
            premium.matchDayIndex = day
            cheap.applyShopPriceMood()
            premium.applyShopPriceMood()
        }
        XCTAssertGreaterThan(cheap.fanMood, 60, "Promoção agrada a torcida")
        XCTAssertLessThan(premium.fanMood, 60, "Premium irrita a torcida")
    }

    func testRepeatedLoansCalmTheBoardOncePerDayAndOnlyWhenRelevant() {
        var career = career()
        career.world.coach.personalCash = 10_000_000
        career.transferBudget = -4_000_000
        career.boardConfidence = 40
        XCTAssertTrue(career.lendToClub(amount: 50_000))
        XCTAssertEqual(career.boardConfidence, 40, "50 mil não chegam a 5% da dívida")
        XCTAssertTrue(career.lendToClub(amount: 250_000))
        XCTAssertEqual(career.boardConfidence, 42)
        for _ in 0..<5 { XCTAssertTrue(career.lendToClub(amount: 250_000)) }
        XCTAssertEqual(career.boardConfidence, 42, "Aportes repetidos no mesmo dia não somam confiança")
        career.matchDayIndex += 1
        XCTAssertTrue(career.lendToClub(amount: 250_000))
        XCTAssertEqual(career.boardConfidence, 44)
    }

    func testPaidActivitiesBuildStressSoRestingMatters() throws {
        var grinder = career()
        var balanced = grinder
        grinder.world.coach.stress = 20
        balanced.world.coach.stress = 20
        grinder.world.coach.energy = 100
        balanced.world.coach.energy = 100
        for day in 0..<8 {
            grinder.matchDayIndex = day
            balanced.matchDayIndex = day
            grinder.world.coach.energy = 100
            balanced.world.coach.energy = 100
            _ = grinder.doActivity(day % 2 == 0 ? .tvPunditry : .lecture)
            _ = balanced.doActivity(day % 3 == 2 ? .rest : .lecture)
        }
        // TV (+4) e palestra (+3) alternadas por 8 dias: +28. Com descanso a cada 3 dias, o estresse quase zera.
        XCTAssertEqual(grinder.world.coach.stress, 20 + 4 * 4 + 4 * 3, "Trabalhar todo dia acumula estresse")
        XCTAssertEqual(balanced.world.coach.stress, 6)
        XCTAssertLessThan(CoachActivity.schoolVisit.stressCost, 0, "Visita à comunidade alivia")
    }

    // MARK: F4-07

    func testChangingClubLeavesOldClubBusinessBehind() throws {
        var career = career()
        career.transferBudget = 30_000_000
        var random = FootballRandom(seed: 4)
        career.refreshNamingOffers(using: &random)
        let offer = try XCTUnwrap(career.world.business.namingOffers.first)
        XCTAssertTrue(career.acceptNamingOffer(offer.id))
        XCTAssertTrue(career.upgradeShop())
        XCTAssertTrue(career.launchCollection(CollectionBrief(audience: .traditional, size: .capsule)))
        XCTAssertTrue(career.delegateCommercial(risk: .bold, limit: .large))
        career.boardConfidence = 90
        XCTAssertTrue(career.requestBoardMeeting(.targetReview))
        let oldSponsor = career.sponsorDeal?.sponsor
        let personalPlanDay = career.worldDay + 3
        XCTAssertTrue(career.planActivity(.podcast, on: personalPlanDay))

        XCTAssertTrue(career.resign())
        let job = try XCTUnwrap(career.jobOffers.first)
        XCTAssertTrue(career.acceptJob(job.id))

        XCTAssertNil(career.world.business.naming)
        XCTAssertEqual(career.stadiumDisplayName, job.stadium, "Estádio novo com o próprio nome")
        XCTAssertEqual(career.world.business.shopLevel, 1)
        XCTAssertNil(career.activeCollection)
        XCTAssertNil(career.commercialDelegation)
        XCTAssertNil(career.openBoardMeeting)
        XCTAssertNotNil(career.sponsorDeal)
        XCTAssertNotNil(oldSponsor)
        XCTAssertTrue(career.world.projects.personalPlan.contains { $0.worldDay == personalPlanDay && $0.status == .planned },
                      "A agenda pessoal acompanha o treinador")

        let fees = career.finance.entries.filter { $0.note == "Gerente comercial" }.count
        let extras = career.finance.entries.filter { $0.note.hasPrefix("Vendas extras") }.count
        if career.canPlay || career.canAdvanceWithoutPlaying { playDays(&career, 1) }
        XCTAssertEqual(career.finance.entries.filter { $0.note == "Gerente comercial" }.count, fees, "Gerente do clube antigo não cobra mais")
        XCTAssertEqual(career.finance.entries.filter { $0.note.hasPrefix("Vendas extras") }.count, extras)
        XCTAssertFalse(career.cashProjection().lines.contains { $0.title.hasPrefix("Naming rights") || $0.title == "Gerente comercial" })
    }

    func testFiredCoachStopsClubRoutinesUntilRehired() throws {
        var career = career()
        career.transferBudget = 30_000_000
        XCTAssertTrue(career.delegateCommercial(risk: .bold, limit: .large))
        playDays(&career, 8)
        career.boardConfidence = 0
        let fees = career.finance.entries.filter { $0.note == "Gerente comercial" }.count
        career.checkMidSeasonSacking()
        XCTAssertTrue(career.isFired)
        XCTAssertTrue(career.cashProjection().days.isEmpty, "Sem clube, sem projeção")
        XCTAssertNotNil(career.boardMeetingBlocker(.budgetBoost))
        XCTAssertNotNil(career.collectionBlocker(CollectionBrief(audience: .youth, size: .capsule)))
        var random = FootballRandom(seed: 1)
        career.tickBusiness(using: &random)
        XCTAssertEqual(career.finance.entries.filter { $0.note == "Gerente comercial" }.count, fees)
    }

    func testNewSeasonSettlesBoardAndArchivesPlanWithoutDoubleCharges() throws {
        var career = career()
        career.transferBudget = 30_000_000
        career.boardConfidence = 95
        XCTAssertTrue(career.requestBoardMeeting(.budgetBoost))
        playDays(&career, 2)
        XCTAssertEqual(career.openBoardMeeting?.status, .conditionRunning)
        while career.canPlay || career.canAdvanceWithoutPlaying {
            if career.matchDayIndex == FootballSeason.matchDaysPerSeason - 2 {
                XCTAssertTrue(career.planActivity(.rest, on: career.worldDay + 1))
            }
            XCTAssertTrue(career.simulateNextMatchDay())
        }
        let grants = career.finance.entries.filter { $0.note == "Verba extra da diretoria" }.count
        _ = career.startNextSeason()
        XCTAssertNil(career.openBoardMeeting, "Condição liquidada na virada")
        XCTAssertFalse(career.world.projects.personalPlan.contains { $0.status == .planned })
        XCTAssertEqual(career.finance.entries.filter { $0.note == "Verba extra da diretoria" }.count, grants)
        if !career.isFired {
            XCTAssertNotEqual(career.boardMeetingBlocker(.budgetBoost), "A verba extra desta temporada já foi concedida.", "Nova temporada, novo pedido possível")
        }
    }
}
