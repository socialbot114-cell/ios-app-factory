import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballMarketTests: XCTestCase {
    private func career(club: Int = 0, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.transferBudget = 60_000_000
        career.wageCap = career.wageBill * 3
        return career
    }

    private func target(in career: FootballCareer, position: FootballPosition = .forward, club: Int = 3) throws -> FootballPlayer {
        try XCTUnwrap(career.players(forTeam: club).filter { $0.position == position }.sorted { $0.overall > $1.overall }.dropFirst().first)
    }

    // MARK: - Janelas

    func testTransferWindowsOpenOnlyInPreseasonAndMidseason() throws {
        var career = career()
        XCTAssertEqual(career.transferWindow?.kind, .preseason)
        XCTAssertEqual(career.transferWindow?.daysLeft, 2)
        let player = try target(in: career)
        var bid = TransferBid(playerID: player.id, fee: career.askingPrice(for: player), wage: career.joiningAsk(for: player).wage)
        bid.years = 3
        career.matchDayIndex = 5
        XCTAssertNil(career.transferWindow)
        XCTAssertEqual(career.evaluateBid(bid), .notAllowed("A janela de transferências está fechada."))
        XCTAssertFalse(career.canSell(playerID: career.clubRoster.last!.id))
        career.matchDayIndex = 10
        XCTAssertEqual(career.transferWindow?.kind, .midseason)
        career.matchDayIndex = 11
        XCTAssertTrue(career.transferWindow?.isLastDay ?? false)
        career.matchDayIndex = 12
        XCTAssertNil(career.transferWindow)
    }

    // MARK: - Propostas

    func testAskingPriceDependsOnImportanceAndContract() throws {
        var career = career()
        let squad = career.players(forTeam: 3).sorted { $0.overall > $1.overall }
        let star = squad[0]
        let bench = squad[13]
        XCTAssertGreaterThan(Double(career.askingPrice(for: star)) / Double(star.marketValue),
                             Double(career.askingPrice(for: bench)) / Double(max(1, bench.marketValue)))
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == star.id })
        career.players[index].contract.endSeason = career.season + 3
        let full = career.askingPrice(for: career.players[index])
        career.players[index].contract.endSeason = career.season
        XCTAssertLessThan(career.askingPrice(for: career.players[index]), full)
    }

    func testBidFlowRefusesCountersAndAcceptsThenMovesPlayerAndCash() throws {
        var career = career()
        let player = try target(in: career)
        let ask = career.askingPrice(for: player)
        let wage = career.joiningAsk(for: player).wage
        let sellerCount = career.players(forTeam: 3).count

        guard case .clubRefuses = career.evaluateBid(TransferBid(playerID: player.id, fee: ask / 3, wage: wage)) else {
            return XCTFail("Oferta muito baixa deve ser recusada")
        }
        let counter = career.evaluateBid(TransferBid(playerID: player.id, fee: Int(Double(ask) * 0.9), wage: wage))
        guard case .counter(let fee) = counter else { return XCTFail("Oferta próxima gera contraproposta: \(counter)") }
        XCTAssertGreaterThan(fee, Int(Double(ask) * 0.9))
        XCTAssertLessThanOrEqual(fee, ask)

        XCTAssertEqual(career.evaluateBid(TransferBid(playerID: player.id, fee: ask, wage: wage / 2)), .playerRefuses(askWage: wage))

        let cash = career.transferBudget
        XCTAssertEqual(career.submitBid(TransferBid(playerID: player.id, fee: ask, wage: wage, years: 3)), .accepted)
        let signed = try XCTUnwrap(career.player(player.id))
        XCTAssertEqual(signed.teamID, 0)
        XCTAssertEqual(signed.contract.wage, wage)
        XCTAssertEqual(signed.contract.endSeason, career.season + 2)
        XCTAssertEqual(career.transferBudget, cash - ask)
        XCTAssertEqual(career.players(forTeam: 3).count, sellerCount, "O vendedor repõe o elenco")
        XCTAssertTrue(career.transferLog.contains { $0.playerID == player.id && $0.toClubID == 0 })
        XCTAssertTrue(career.finance.entries.contains { $0.category == .playerPurchases && $0.amount == -ask })
    }

    func testInstallmentsSwapsAndGoalBonusesAreHonoured() throws {
        var career = career()
        let player = try target(in: career, position: .midfielder)
        let ask = career.askingPrice(for: player)
        let wage = career.joiningAsk(for: player).wage
        let swap = try XCTUnwrap(career.clubRoster.first { $0.position == .defender && career.canRelease(playerID: $0.id) && !career.startingXI.contains($0.id) })
        let cash = career.transferBudget
        var bid = TransferBid(playerID: player.id, fee: ask, installments: 3, swapPlayerID: swap.id, goalBonus: 600_000, wage: wage)
        bid.fee = max(0, ask - Int(Double(swap.marketValue) * 0.9) - 300_000)
        let response = career.evaluateBid(bid)
        XCTAssertEqual(response, .accepted, "\(response)")
        XCTAssertEqual(career.submitBid(bid), .accepted)
        XCTAssertEqual(career.player(swap.id)?.teamID, 3, "A troca leva o atleta oferecido")
        XCTAssertEqual(career.transferBudget, cash - bid.fee / 3)
        XCTAssertEqual(career.pendingPayments.count, 2)
        XCTAssertEqual(career.goalBonuses.count, 1)

        // Parcelas vencem com o calendário.
        let before = career.transferBudget
        career.matchDayIndex = 6
        career.settlePendingPayments()
        XCTAssertTrue(career.pendingPayments.isEmpty)
        XCTAssertLessThan(career.transferBudget, before)

        // O bônus é pago quando o atleta chega a 10 gols.
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == player.id })
        career.players[index].goals = 10
        let beforeBonus = career.transferBudget
        career.settlePendingPayments()
        XCTAssertEqual(career.transferBudget, beforeBonus - 600_000)
        XCTAssertTrue(career.goalBonuses.isEmpty)
    }

    func testSellersKeepTheirGoalkeepersAndMinimumSquads() throws {
        let career = career()
        let keeper = try XCTUnwrap(career.players(forTeam: 3).first { $0.position == .goalkeeper })
        XCTAssertFalse(career.sellerCanSell(keeper))
        guard case .clubRefuses = career.evaluateBid(TransferBid(playerID: keeper.id, fee: 90_000_000, wage: 1_000_000)) else {
            return XCTFail("Clube não vende o goleiro")
        }
        let forward = try target(in: career)
        XCTAssertTrue(career.sellerCanSell(forward))
    }

    func testOffersCanBeListedAndLoanOffersMoveThePlayerOut() throws {
        var career = career()
        let listed = try XCTUnwrap(career.clubRoster.first { !career.startingXI.contains($0.id) && career.canRelease(playerID: $0.id) })
        career.setListed(playerID: listed.id, listed: true)
        XCTAssertTrue(career.player(listed.id)?.isListed ?? false)
        career.setListed(playerID: listed.id, listed: true, loan: true)
        career.offers = [TransferOffer(id: 50, playerID: listed.id, clubID: 4, amount: 300_000, expiresAfterRound: 5, kind: .loan)]
        let cash = career.transferBudget
        XCTAssertTrue(career.acceptOffer(50))
        let loaned = try XCTUnwrap(career.player(listed.id))
        XCTAssertEqual(loaned.teamID, 4)
        XCTAssertEqual(loaned.parentTeamID, 0)
        XCTAssertEqual(career.transferBudget, cash + 300_000)
        XCTAssertFalse(loaned.isListed)

        // Ofertas geradas na janela respeitam a lista de transferência.
        var random = FootballRandom(seed: 3)
        career.offers = []
        let another = try XCTUnwrap(career.clubRoster.last { career.canRelease(playerID: $0.id) })
        career.setListed(playerID: another.id, listed: true)
        var sawListedOffer = false
        for _ in 0..<40 {
            career.offers = []
            career.generateOffers(using: &random)
            if career.offers.contains(where: { $0.playerID == another.id }) { sawListedOffer = true }
        }
        XCTAssertTrue(sawListedOffer)
        career.matchDayIndex = 5
        career.offers = []
        for _ in 0..<40 { career.generateOffers(using: &random) }
        XCTAssertTrue(career.offers.isEmpty, "Sem janela, sem propostas novas")
    }

    // MARK: - Empréstimos

    func testLoanInPaysFeeCountsWagesAndReturnsAtSeasonEnd() throws {
        var career = career()
        let candidate = try XCTUnwrap(career.players(forTeam: 3).sorted { $0.overall > $1.overall }.dropFirst(5).first { $0.position == .midfielder })
        XCTAssertNil(career.canLoanIn(playerID: candidate.id))
        let bill = career.wageBill
        let cash = career.transferBudget
        XCTAssertTrue(career.loanIn(playerID: candidate.id))
        let loaned = try XCTUnwrap(career.player(candidate.id))
        XCTAssertEqual(loaned.teamID, 0)
        XCTAssertEqual(loaned.parentTeamID, 3)
        XCTAssertEqual(career.transferBudget, cash - career.loanFee(for: candidate))
        XCTAssertEqual(career.wageBill, bill + candidate.contract.wage)
        XCTAssertNotNil(loaned.purchaseOption)
        XCTAssertFalse(career.canRenew(playerID: candidate.id), "Emprestado não renova")

        // Opção de compra.
        var bought = career
        bought.transferBudget = 100_000_000
        XCTAssertTrue(bought.buyOutLoan(playerID: candidate.id))
        XCTAssertNil(bought.player(candidate.id)?.parentTeamID)
        XCTAssertEqual(bought.player(candidate.id)?.teamID, 0)

        // Sem comprar, volta ao dono no fim da temporada.
        for _ in 0..<FootballSeason.matchDaysPerSeason { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertNotNil(career.startNextSeason())
        XCTAssertEqual(career.player(candidate.id)?.teamID, 3)
        XCTAssertNil(career.player(candidate.id)?.parentTeamID)
    }

    func testLoanOutGivesYoungPlayersDevelopmentWhenTheyReturn() throws {
        var career = career()
        let prospect = try XCTUnwrap(career.clubRoster.filter { !career.startingXI.contains($0.id) && $0.age <= 23 }.first
                                     ?? career.clubRoster.first { !career.startingXI.contains($0.id) })
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == prospect.id })
        career.players[index].age = 20
        career.players[index].potential = min(95, career.players[index].overall + 12)
        let destination = try XCTUnwrap(career.loanDestinations(for: career.players[index]).first)
        let cash = career.transferBudget
        XCTAssertTrue(career.loanOut(playerID: prospect.id, to: destination.id))
        XCTAssertGreaterThan(career.transferBudget, cash)
        XCTAssertEqual(career.player(prospect.id)?.teamID, destination.id)
        XCTAssertFalse(career.clubRoster.contains { $0.id == prospect.id })
        XCTAssertEqual(career.players(forTeam: destination.id).filter { $0.parentTeamID == nil }.count + career.players(forTeam: destination.id).filter { $0.parentTeamID != nil }.count,
                       career.players(forTeam: destination.id).count)

        var improved = 0
        for trial in 0..<40 {
            var copy = career
            var random = FootballRandom(seed: UInt64(trial + 1))
            let before = copy.player(prospect.id)?.overall ?? 0
            copy.returnLoans(using: &random)
            XCTAssertEqual(copy.player(prospect.id)?.teamID, 0)
            if (copy.player(prospect.id)?.overall ?? 0) > before { improved += 1 }
        }
        XCTAssertGreaterThan(improved, 10)
    }

    // MARK: - IA no mercado

    func testAIClubsTradeAmongThemselvesAndKeepSquadsBalanced() throws {
        var career = career()
        var random = FootballRandom(seed: 99)
        career.runAIMarket(using: &random, intensity: 6)
        XCTAssertFalse(career.transferLog.isEmpty, "A IA fez transferências")
        for team in FootballSeason.teams where team.id != 0 {
            let squad = career.players(forTeam: team.id)
            XCTAssertEqual(squad.count, FootballCareer.squadSize, team.name)
            for (position, minimum) in FootballCareer.positionMinimums {
                XCTAssertGreaterThanOrEqual(squad.filter { $0.position == position }.count, minimum, "\(team.name) \(position)")
            }
        }
        XCTAssertEqual(Set(career.players.map(\.id)).count, career.players.count)

        var again = self.career()
        var randomAgain = FootballRandom(seed: 99)
        again.runAIMarket(using: &randomAgain, intensity: 6)
        XCTAssertEqual(again.transferLog, career.transferLog)
    }

    func testMarketEventsRunAtWindowEdgesAndLastDayAnnounced() throws {
        var career = career()
        career.matchDayIndex = 1
        career.marketCalendarEvents()
        XCTAssertTrue(career.inbox.contains { $0.title == "Último dia da janela" })
        XCTAssertFalse(career.transferLog.isEmpty)
    }

    // MARK: - Observação

    func testScoutingFogOfWarShrinksAsPlayersAreObserved() throws {
        var career = career()
        let own = career.clubRoster[0]
        XCTAssertEqual(career.scoutKnowledge(of: own.id), 100)
        XCTAssertEqual(career.visibleOverallRange(of: own.id), own.overall...own.overall)
        let stranger = try target(in: career)
        XCTAssertEqual(career.scoutKnowledge(of: stranger.id), 20)
        let blurry = career.visibleOverallRange(of: stranger.id)
        XCTAssertTrue(blurry.contains(stranger.overall))
        XCTAssertGreaterThan(blurry.upperBound - blurry.lowerBound, 5)
        let attribute = career.visibleAttribute(playerID: stranger.id, kind: .finishing)
        XCTAssertTrue(attribute.contains(stranger.attributes[.finishing]))
        career.observe(stranger.id, gain: 60)
        XCTAssertEqual(career.scoutKnowledge(of: stranger.id), 80)
        let sharper = career.visibleOverallRange(of: stranger.id)
        XCTAssertTrue(sharper.contains(stranger.overall))
        XCTAssertLessThan(sharper.upperBound - sharper.lowerBound, blurry.upperBound - blurry.lowerBound)
        career.observe(stranger.id, gain: 60)
        XCTAssertEqual(career.visibleOverallRange(of: stranger.id), stranger.overall...stranger.overall)
        XCTAssertEqual(career.scoutKnowledge(of: career.marketPlayers[0].id), 70, "Agentes livres são conhecidos")
    }

    func testScoutMissionsDeliverStarReportsAndRespectSlots() throws {
        var career = career()
        XCTAssertTrue(career.startScoutMission(region: nil, position: .forward, maxAge: 24, maxValue: 5_000_000))
        XCTAssertTrue(career.startScoutMission(region: 3, position: nil, maxAge: 30, maxValue: 3_000_000))
        XCTAssertFalse(career.startScoutMission(region: 1, position: .defender, maxAge: 30, maxValue: 3_000_000), "No máximo duas missões")
        XCTAssertEqual(career.activeScoutMissions.count, 2)
        for _ in 0..<3 { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertTrue(career.activeScoutMissions.isEmpty)
        XCTAssertFalse(career.scoutReports.isEmpty)
        for report in career.scoutReports {
            XCTAssertTrue((1...5).contains(report.currentStars))
            XCTAssertTrue((1...5).contains(report.potentialStars))
            let athlete = try XCTUnwrap(career.player(report.playerID))
            XCTAssertNotEqual(athlete.teamID, 0)
            XCTAssertGreaterThanOrEqual(career.scoutKnowledge(of: athlete.id), 70)
        }
        let first = try XCTUnwrap(career.scoutReports.first)
        let mission = try XCTUnwrap(career.scoutMissions.first { $0.id == first.missionID })
        let reported = try XCTUnwrap(career.player(first.playerID))
        if let position = mission.position { XCTAssertEqual(reported.position, position) }
        XCTAssertLessThanOrEqual(reported.age, mission.maxAge)
        XCTAssertTrue(career.inbox.contains { $0.kind == .scouting })
        career.toggleWatch(playerID: first.playerID)
        XCTAssertEqual(career.watchlist, [first.playerID])
        career.toggleWatch(playerID: first.playerID)
        XCTAssertTrue(career.watchlist.isEmpty)
    }

    func testPlayingAnOpponentRevealsHisAttributes() throws {
        var career = career()
        XCTAssertTrue(career.simulateNextMatchDay())
        let observed = career.scoutKnowledge.filter { $0.value >= 45 }
        XCTAssertGreaterThanOrEqual(observed.count, 11, "Os onze do rival ficaram conhecidos")
        XCTAssertTrue(observed.keys.allSatisfy { career.player($0)?.teamID != 0 })
    }

    // MARK: - Base

    func testYouthIntakeAtSeasonEndAndPromotionRules() throws {
        var career = career(club: 10)
        XCTAssertTrue(career.youthRoster.isEmpty)
        for _ in 0..<FootballSeason.matchDaysPerSeason { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertNotNil(career.startNextSeason())
        let youth = career.youthRoster
        XCTAssertTrue((3...6).contains(youth.count), "A leva anual tem de 3 a 6 jovens: \(youth.count)")
        XCTAssertEqual(Set(career.lastYouthIntake), Set(youth.map(\.id)))
        XCTAssertTrue(youth.allSatisfy { $0.isYouth && $0.age <= 19 && $0.potential >= $0.overall })
        XCTAssertFalse(career.clubRoster.contains { $0.isYouth })
        XCTAssertFalse(career.startingXI.contains { id in youth.contains { $0.id == id } })

        let candidate = try XCTUnwrap(youth.first)
        career.wageCap = career.wageBill * 3
        let size = career.clubRoster.count
        XCTAssertTrue(career.promoteYouth(playerID: candidate.id))
        XCTAssertEqual(career.clubRoster.count, size + 1)
        XCTAssertFalse(career.player(candidate.id)?.isYouth ?? true)
        let other = try XCTUnwrap(career.youthRoster.first)
        XCTAssertTrue(career.releaseYouth(playerID: other.id))
        XCTAssertNil(career.player(other.id)?.teamID)
        XCTAssertFalse(career.promoteYouth(playerID: candidate.id), "Já é do elenco principal")
    }

    func testGemsAppearAndYouthCapIsRespectedOverManySeasons() throws {
        var gems = 0
        var intakes = 0
        for seed in 1...25 {
            var career = FootballCareer(seed: seed * 313)
            XCTAssertTrue(career.chooseClub(10))
            career.youthAcademyLevel = 5
            var random = FootballRandom(seed: UInt64(seed))
            for _ in 0..<3 {
                career.runYouthIntake(using: &random)
                XCTAssertLessThanOrEqual(career.youthRoster.count, FootballCareer.youthRosterLimit)
                intakes += career.lastYouthIntake.count
                gems += career.youthRoster.filter { $0.potential >= 86 }.count
                for index in career.players.indices where career.players[index].isYouth { career.players[index].age += 1 }
                career.retireOverageYouth()
            }
        }
        XCTAssertGreaterThan(gems, 0, "Com a base no nível máximo aparecem joias")
        XCTAssertGreaterThan(intakes, 25 * 3 * 3)
    }

    func testYouthCupRunsOnceAtTheScheduledMatchDay() throws {
        var career = career(club: 10)
        var random = FootballRandom(seed: 1)
        career.runYouthIntake(using: &random)
        for _ in 0..<(FootballCareer.youthCupMatchDay + 1) { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertEqual(career.youthCupHistory.count, 1)
        let result = try XCTUnwrap(career.youthCupHistory.first)
        XCTAssertEqual(result.season, 1)
        XCTAssertTrue(["Eliminado nas quartas de final", "Eliminado na semifinal", "Vice-campeão", "Campeão da Copinha"].contains(result.userResult))
        XCTAssertNotNil(FootballSeason.team(result.winnerID))
        career.runYouthCup(using: &random)
        XCTAssertEqual(career.youthCupHistory.count, 1, "Só uma vez por temporada")
    }

    // MARK: - Saves

    func testMarketStateSurvivesSaveAndOldSavesLoad() throws {
        var career = career()
        let player = try target(in: career)
        XCTAssertEqual(career.submitBid(TransferBid(playerID: player.id, fee: career.askingPrice(for: player), installments: 2, wage: career.joiningAsk(for: player).wage)), .accepted)
        career.startScoutMission(region: nil, position: nil, maxAge: 30, maxValue: 3_000_000)
        career.toggleWatch(playerID: player.id)
        career.observe(career.marketPlayers[0].id, gain: 10)
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip, career)

        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        legacy["schemaVersion"] = 5
        for key in ["transferLog", "nextTransferID", "scoutKnowledge", "scoutMissions", "scoutReports", "nextScoutID", "watchlist",
                    "pendingPayments", "goalBonuses", "nextPaymentID", "youthCupHistory", "youthAcademyLevel", "lastYouthIntake", "staff", "staffMarket", "nextStaffID"] {
            legacy.removeValue(forKey: key)
        }
        if var offers = legacy["offers"] as? [[String: Any]] {
            offers = offers.map { var copy = $0; copy.removeValue(forKey: "kind"); return copy }
            legacy["offers"] = offers
        }
        let migrated = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(migrated.youthAcademyLevel, 3)
        XCTAssertTrue(migrated.transferLog.isEmpty)
        var playable = migrated
        XCTAssertTrue(playable.simulateNextMatchDay())
    }
}
