import Foundation
import XCTest
@testable import ManagerFutebol

/// Build 31: astro puxa a loja, jogo grande aguenta ingresso mais caro e o patrocinador reage ao desempenho.
final class FootballLivingEconomyTests: XCTestCase {
    private func career(club: Int = 5, seed: Int = 7_919) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    /// Jogo em casa do clube escolhido contra o rival (clássico) ou contra o time mais fraco da divisão (jogo comum).
    private func homeFixture(_ career: FootballCareer, derby: Bool) -> LeagueFixture? {
        guard let id = career.selectedClubID else { return nil }
        let division = career.division(of: id)
        let rival = FootballSeason.rivalries.first { $0.contains(id) }?.first { $0 != id }
        let weakest = career.teamIDs(in: division).filter { $0 != id && $0 != rival }
            .min { (FootballSeason.team($0)?.strength ?? 0) < (FootballSeason.team($1)?.strength ?? 0) }
        guard let away = derby ? rival : weakest else { return nil }
        return LeagueFixture(id: 9_000 + away, matchDay: 3, round: 3, competition: .league(division), home: id, away: away)
    }

    // MARK: ECV-03

    func testNormalPriceIsUntouchedByTheStakesOfTheMatch() throws {
        var career = career(club: 15)
        career.ticketPrice = .normal
        let derby = try XCTUnwrap(homeFixture(career, derby: true))
        let ordinary = try XCTUnwrap(homeFixture(career, derby: false))
        XCTAssertEqual(career.priceDemandFactor(for: derby), 1)
        XCTAssertEqual(career.priceDemandFactor(for: ordinary), 1)
        career.ticketPrice = .popular
        XCTAssertEqual(career.priceDemandFactor(for: derby), TicketPrice.popular.demandFactor, "O ingresso barato não ganha bônus extra")
    }

    func testExpensiveTicketScaresFewerFansInADerbyThanInAnOrdinaryMatch() throws {
        var career = career(club: 15)
        career.ticketPrice = .elite
        let derby = try XCTUnwrap(homeFixture(career, derby: true))
        let ordinary = try XCTUnwrap(homeFixture(career, derby: false))
        XCTAssertEqual(career.matchStakes(for: derby), .derby)
        XCTAssertGreaterThan(career.priceDemandFactor(for: derby), career.priceDemandFactor(for: ordinary))
        XCTAssertEqual(career.priceDemandFactor(for: ordinary), TicketPrice.elite.demandFactor, accuracy: 0.0001)
        XCTAssertGreaterThan(career.attendance(for: derby), career.attendance(for: ordinary))
        XCTAssertGreaterThan(career.gateRevenue(attendance: career.attendance(for: derby)), career.gateRevenue(attendance: career.attendance(for: ordinary)))
    }

    func testSuggestedPriceIsHigherForTheBigMatch() throws {
        let career = career(club: 15)
        let derby = try XCTUnwrap(homeFixture(career, derby: true))
        let ordinary = try XCTUnwrap(homeFixture(career, derby: false))
        XCTAssertGreaterThanOrEqual(career.suggestedTicketPrice(for: derby).rawValue, career.suggestedTicketPrice(for: ordinary).rawValue)
    }

    // MARK: ECV-02

    func testStarPullsTheShopAndLeavingTakesItBack() throws {
        var career = career(club: 5)
        let before = career.starMerchFactor
        let starID = try XCTUnwrap(career.starPlayer?.id)
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == starID })
        career.players[index].setOverall(min(99, career.players[index].overall + 8))
        let shining = career.starMerchFactor
        XCTAssertGreaterThan(shining, before, "Um craque bem acima do resto vende mais camisa")
        XCTAssertLessThanOrEqual(shining, 1.15)
        let revenueWithStar = career.baseMerchRevenuePerMatchDay
        career.players[index].injuryRounds = 4
        XCTAssertLessThan(career.starMerchFactor, shining, "Machucado, ele puxa menos")
        career.players[index].injuryRounds = 0
        career.players[index].teamID = nil
        XCTAssertLessThan(career.starMerchFactor, shining, "Sem ele, a venda cai")
        XCTAssertLessThan(career.baseMerchRevenuePerMatchDay, revenueWithStar)
        XCTAssertGreaterThanOrEqual(career.starMerchFactor, 0.94)
    }

    func testGoodFormRaisesTheStarEffect() throws {
        var career = career(club: 5)
        let starID = try XCTUnwrap(career.starPlayer?.id)
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == starID })
        career.players[index].form = PlayerForm()
        for _ in 0..<5 { career.players[index].form.add(5.5) }
        let cold = career.starMerchFactor
        career.players[index].form = PlayerForm()
        for _ in 0..<5 { career.players[index].form.add(8.2) }
        XCTAssertGreaterThan(career.starMerchFactor, cold)
    }

    // MARK: PAT-02

    func testSponsorPaysMoreWhenHappyAndLessWhenNot() throws {
        var career = career(club: 5)
        var deal = try XCTUnwrap(career.sponsorDeal)
        XCTAssertEqual(deal.satisfaction, 55)
        deal.satisfaction = 100
        career.sponsorDeal = deal
        XCTAssertEqual(career.sponsorExposureFactor, 1.08, accuracy: 0.0001)
        deal.satisfaction = 0
        career.sponsorDeal = deal
        XCTAssertEqual(career.sponsorExposureFactor, 0.92, accuracy: 0.0001)
        XCTAssertEqual(career.sponsorMood, "Insatisfeito")
    }

    func testSponsorReactsToResultsAndWarnsOncePerMood() throws {
        var career = career(club: 0)
        for _ in 0..<FootballSeason.matchDaysPerSeason { career.simulateNextMatchDay() }
        let id = try XCTUnwrap(career.selectedClubID)
        let win = try XCTUnwrap(career.fixtures.first { $0.competition.division != nil && $0.result(for: id) == .win })
        let loss = try XCTUnwrap(career.fixtures.first { $0.competition.division != nil && $0.result(for: id) == .loss })

        var deal = try XCTUnwrap(career.sponsorDeal)
        deal.satisfaction = 74
        deal.notifiedTier = 0
        career.sponsorDeal = deal
        career.clubHype = 40
        career.inbox.removeAll()
        let messages = 0
        career.updateSponsorSatisfaction(fixture: win, result: .win)
        XCTAssertGreaterThanOrEqual(career.sponsorDeal?.satisfaction ?? 0, 75)
        XCTAssertEqual(career.inbox.count, messages + 1, "Cruzar o limite de satisfeito avisa")
        XCTAssertEqual(career.inbox.last?.kind, .finance)
        career.updateSponsorSatisfaction(fixture: win, result: .win)
        XCTAssertEqual(career.inbox.count, messages + 1, "Não repete o aviso")

        deal = try XCTUnwrap(career.sponsorDeal)
        deal.satisfaction = 31
        deal.notifiedTier = 0
        career.sponsorDeal = deal
        career.clubHype = 40
        career.inbox.removeAll()
        career.updateSponsorSatisfaction(fixture: loss, result: .loss)
        XCTAssertLessThanOrEqual(career.sponsorDeal?.satisfaction ?? 100, 30)
        XCTAssertEqual(career.sponsorDeal?.notifiedTier, -1)
        XCTAssertEqual(career.inbox.count, 1, "Cair para insatisfeito avisa")
        XCTAssertTrue(career.inbox.last?.title.contains("reclama") ?? false)
    }

    func testHappySponsorOffersABetterRenewalAndUnhappyOneLeaves() throws {
        var happy = career(club: 5)
        var deal = try XCTUnwrap(happy.sponsorDeal)
        deal.satisfaction = 82
        deal.endSeason = happy.season
        happy.sponsorDeal = deal
        var random = FootballRandom(seed: 99)
        happy.closeSeasonClub(objectiveMet: true, champion: false, using: &random)
        XCTAssertNil(happy.sponsorDeal)
        let renewal = try XCTUnwrap(happy.sponsorRenewal)
        XCTAssertEqual(renewal.sponsor, deal.sponsor)
        XCTAssertGreaterThan(renewal.fixedPerSeason, deal.fixedPerSeason)
        happy.prepareNewSeasonClub(using: &random)
        XCTAssertTrue(happy.sponsorOffers.contains { $0.profile == "Renovação" && $0.sponsor == deal.sponsor })
        XCTAssertTrue(happy.signSponsor(renewal))
        XCTAssertNil(happy.sponsorRenewal)

        var unhappy = career(club: 5)
        var sour = try XCTUnwrap(unhappy.sponsorDeal)
        sour.satisfaction = 20
        sour.endSeason = unhappy.season
        unhappy.sponsorDeal = sour
        unhappy.closeSeasonClub(objectiveMet: false, champion: false, using: &random)
        XCTAssertNil(unhappy.sponsorRenewal)
        XCTAssertTrue(unhappy.inbox.contains { $0.title.contains("não renova") })
    }

    func testOldSponsorSaveWithoutSatisfactionOpensNeutral() throws {
        let json = #"{"sponsor":"Bancorte","fixedPerSeason":900000,"bonusPerWin":30000,"titleBonus":400000,"endSeason":2}"#
        let deal = try JSONDecoder().decode(SponsorDeal.self, from: Data(json.utf8))
        XCTAssertEqual(deal.satisfaction, 55)
        XCTAssertEqual(deal.notifiedTier, 0)
        let again = try JSONDecoder().decode(SponsorDeal.self, from: JSONEncoder().encode(deal))
        XCTAssertEqual(again, deal)
    }

    func testMarketHeatStaysInRangeAndAverageNearOne() {
        let career = career()
        var random = FootballRandom(seed: 5)
        let heats = (0..<400).map { _ in career.sponsorMarketHeat(using: &random) }
        XCTAssertTrue(heats.allSatisfy { $0 >= 0.92 && $0 <= 1.10 })
        let mean = heats.reduce(0, +) / Double(heats.count)
        XCTAssertEqual(mean, 1.0, accuracy: 0.03)
        XCTAssertGreaterThan(heats.max()! - heats.min()!, 0.08, "Os valores mudam de uma temporada para a outra")
    }

    func testScreenNotesExplainEachEffect() throws {
        let career = career(club: 5)
        let shop = try XCTUnwrap(career.starShopNote)
        XCTAssertTrue(shop.contains("Astro:"))
        let sponsor = try XCTUnwrap(career.sponsorMoodNote)
        XCTAssertTrue(sponsor.contains("55/100"))
        let ticket = try XCTUnwrap(career.nextHomeTicketNote)
        XCTAssertTrue(ticket.contains("Próximo jogo em casa"))
    }
}
