import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballClubTests: XCTestCase {
    private func career(club: Int = 0, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    // MARK: - Bilheteria e preço

    func testTicketPriceTradesAttendanceForRevenueAndMoodMovesTheCrowd() throws {
        var career = career(club: 3)
        let fixture = try XCTUnwrap(career.fixtures.first { $0.home == 3 && $0.competition.division != nil })
        var crowds: [TicketPrice: Int] = [:]
        var revenue: [TicketPrice: Int] = [:]
        for price in TicketPrice.allCases {
            career.ticketPrice = price
            crowds[price] = career.attendance(for: fixture)
            revenue[price] = career.gateRevenue(attendance: crowds[price]!)
        }
        XCTAssertGreaterThanOrEqual(crowds[.popular]!, crowds[.normal]!)
        XCTAssertGreaterThan(crowds[.normal]!, crowds[.premium]!)
        XCTAssertGreaterThan(crowds[.premium]!, crowds[.elite]!)
        XCTAssertGreaterThan(revenue[.normal]!, revenue[.popular]!, "Popular enche o estádio mas rende menos")
        XCTAssertTrue(crowds.values.allSatisfy { $0 <= career.stadiumCapacity })

        career.ticketPrice = .normal
        career.fanMood = 90
        let happy = career.attendance(for: fixture)
        career.fanMood = 20
        let sad = career.attendance(for: fixture)
        XCTAssertGreaterThan(happy, sad)

        let derby = try XCTUnwrap(FootballSeason.rivalries.first { $0.contains(3) }.flatMap { pair -> LeagueFixture? in
            let rival = pair.first { $0 != 3 }!
            return LeagueFixture(id: 8_888, matchDay: 0, round: 1, competition: .league(.serieA), home: 3, away: rival)
        })
        career.fanMood = 50
        let normalGame = career.attendance(for: LeagueFixture(id: 8_889, matchDay: 0, round: 1, competition: .league(.serieA), home: 3, away: 9))
        XCTAssertGreaterThanOrEqual(career.attendance(for: derby), normalGame)
    }

    func testHomeMatchRecordsAttendanceAndEveryMatchDayCollectsAllIncomeAndCosts() throws {
        var career = career()
        XCTAssertTrue(career.simulateNextMatchDay())
        let entries = career.finance.entries(season: 1)
        let categories = Set(entries.map(\.category))
        XCTAssertTrue(categories.isSuperset(of: [.tv, .members, .sponsor, .wages, .staff, .facilities]), "\(categories)")
        let home = career.fixtures.first { $0.matchDay == 0 && $0.home == 0 }
        if let home {
            XCTAssertNotNil(home.attendance)
            XCTAssertTrue(categories.contains(.gate))
            XCTAssertEqual(career.lastRoundRevenue, career.gateRevenue(attendance: home.attendance!))
        }
        let total = entries.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(career.transferBudget, FootballSeason.team(0)!.startingBudget + total)
    }

    // MARK: - Relatórios

    func testMonthlyReportsAddUpToTheCashAndProjectionIsReasonable() throws {
        var career = career()
        for _ in 0..<12 { XCTAssertTrue(career.simulateNextMatchDay()) }
        let reports = career.monthReports(season: 1)
        XCTAssertGreaterThanOrEqual(reports.count, 3)
        XCTAssertEqual(reports.last?.closingCash, career.transferBudget)
        let income = reports.reduce(0) { $0 + $1.income }
        let expenses = reports.reduce(0) { $0 + $1.expenses }
        XCTAssertEqual(income, career.finance.income(season: 1))
        XCTAssertEqual(expenses, career.finance.expenses(season: 1))
        XCTAssertEqual(reports.map(\.month), reports.map(\.month).sorted())
        let projected = career.projectedSeasonEndCash
        XCTAssertGreaterThan(projected, career.transferBudget - 10_000_000)
        XCTAssertLessThan(projected, career.transferBudget + 15_000_000)
    }

    // MARK: - Dívida e transfer ban

    func testDebtAccruesInterestPressuresTheBoardAndBansSignings() throws {
        var career = career(club: 10)
        career.transferBudget = -2_000_000
        let confidence = career.boardConfidence
        for _ in 0..<7 {
            XCTAssertTrue(career.simulateNextMatchDay())
            career.transferBudget = min(career.transferBudget, -1_000_000)
        }
        XCTAssertTrue(career.finance.entries(season: 1).contains { $0.category == .interest })
        XCTAssertLessThan(career.boardConfidence, confidence)
        XCTAssertTrue(career.isInDebt)
        XCTAssertTrue(career.isTransferBanned)
        let freeAgent = try XCTUnwrap(career.marketPlayers.first)
        XCTAssertFalse(career.canSign(playerID: freeAgent.id))
        XCTAssertTrue(career.signBlockReason(playerID: freeAgent.id)?.contains("transfer ban") ?? false)
        career.matchDayIndex = 0
        let target = try XCTUnwrap(career.players(forTeam: 14).first { career.sellerCanSell($0) })
        if case .notAllowed(let reason) = career.evaluateBid(TransferBid(playerID: target.id, fee: 1, wage: 1)) {
            XCTAssertTrue(reason.contains("transfer ban"))
        } else { XCTFail("Transfer ban bloqueia propostas") }

        career.transferBudget = 5_000_000
        _ = career.chargeOperatingCosts()
        XCTAssertFalse(career.isTransferBanned)
    }

    // MARK: - Patrocínio

    func testSponsorDealPaysFixedWinBonusAndTitleBonusThenOffersNewDeals() throws {
        var career = career()
        let deal = try XCTUnwrap(career.sponsorDeal)
        XCTAssertGreaterThan(deal.fixedPerSeason, 0)
        XCTAssertTrue(career.sponsorOffers.isEmpty, "Contrato vigente: sem novas ofertas")
        let offers = career.makeSponsorOffers(using: &career.rngForTests)
        XCTAssertEqual(offers.count, 3)
        XCTAssertEqual(Set(offers.map(\.profile)), ["Seguro", "Equilibrado", "Arriscado"])
        let safe = try XCTUnwrap(offers.first { $0.profile == "Seguro" })
        let risky = try XCTUnwrap(offers.first { $0.profile == "Arriscado" })
        XCTAssertGreaterThan(safe.fixedPerSeason, risky.fixedPerSeason)
        XCTAssertGreaterThan(risky.bonusPerWin, safe.bonusPerWin)
        XCTAssertGreaterThan(risky.titleBonus, safe.titleBonus)

        career.sponsorOffers = offers
        XCTAssertTrue(career.acceptSponsorOffer(risky.id))
        XCTAssertEqual(career.sponsorDeal?.sponsor, risky.sponsor)
        XCTAssertTrue(career.sponsorOffers.isEmpty)

        var wins = 0
        for _ in 0..<FootballSeason.matchDaysPerSeason {
            XCTAssertTrue(career.simulateNextMatchDay())
            if career.latestUserFixture?.result(for: 0) == .win { wins += 1 }
        }
        let bonuses = career.finance.entries(season: 1).filter { $0.category == .sponsor && $0.note.contains("Bônus por vitória") }
        XCTAssertGreaterThan(bonuses.count, 0)
        XCTAssertLessThanOrEqual(bonuses.count, wins)
        XCTAssertNotNil(career.startNextSeason())
        XCTAssertEqual(career.sponsorOffers.count, 3, "Contrato de 1 temporada terminou: novas ofertas")
        XCTAssertNil(career.sponsorDeal)
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertNotNil(career.sponsorDeal, "O clube fecha o contrato equilibrado se você não escolher")
    }

    // MARK: - Estrutura

    func testFacilityUpgradesCostMoneyTakeTimeAndImproveEffects() throws {
        var career = career(club: 3)
        career.transferBudget = 40_000_000
        XCTAssertNil(career.canStartUpgrade(.stadium))
        let capacity = career.stadiumCapacity
        let cost = try XCTUnwrap(career.upgradeCost(for: .stadium))
        let cash = career.transferBudget
        XCTAssertTrue(career.startUpgrade(.stadium))
        XCTAssertEqual(career.transferBudget, cash - cost)
        XCTAssertNotNil(career.upgradeProject)
        XCTAssertNotNil(career.canStartUpgrade(.medical), "Só uma obra por vez")
        XCTAssertEqual(career.stadiumLevel, 1)

        let days = career.upgradeDuration(for: .stadium)
        for _ in 0..<days { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertNil(career.upgradeProject)
        XCTAssertEqual(career.stadiumLevel, 2)
        XCTAssertEqual(career.stadiumCapacity, Int(Double(FootballSeason.team(3)!.capacity) * 1.08))
        XCTAssertGreaterThan(career.stadiumCapacity, capacity)
        XCTAssertTrue(career.inbox.contains { $0.title == "Obra concluída" })

        // Efeitos dos demais níveis.
        career.trainingCenterLevel = 1
        let low = career.trainingFacilityFactor
        career.trainingCenterLevel = 5
        XCTAssertGreaterThan(career.trainingFacilityFactor, low)
        career.medicalLevel = 1
        let slow = career.injuryDurationFactor
        career.medicalLevel = 5
        XCTAssertLessThan(career.injuryDurationFactor, slow)

        career.stadiumLevel = 5
        XCTAssertNil(career.upgradeCost(for: .stadium))
        XCTAssertEqual(career.canStartUpgrade(.stadium), "Nível máximo.")
        career.transferBudget = 0
        XCTAssertNotNil(career.canStartUpgrade(.medical))
    }

    // MARK: - Comissão técnica

    func testStaffMarketHiringFiringAndSeverance() throws {
        var career = career()
        XCTAssertEqual(career.staff.count, 3)
        for role in StaffRole.allCases { XCTAssertEqual(career.staffCandidates(for: role).count, 3) }
        XCTAssertNil(career.staffAbility(.analyst))
        XCTAssertFalse(career.hasAnalyst)
        let analyst = try XCTUnwrap(career.staffCandidates(for: .analyst).first)
        XCTAssertTrue(career.hireStaff(candidateID: analyst.id))
        XCTAssertTrue(career.hasAnalyst)
        XCTAssertFalse(career.staffMarket.contains { $0.id == analyst.id })

        let current = try XCTUnwrap(career.staffMember(.assistant))
        let better = try XCTUnwrap(career.staffCandidates(for: .assistant).first)
        let cash = career.transferBudget
        XCTAssertTrue(career.hireStaff(candidateID: better.id))
        XCTAssertEqual(career.staffMember(.assistant)?.id, better.id)
        XCTAssertLessThan(career.transferBudget, cash, "Rescisão do antigo")
        XCTAssertEqual(career.staff.filter { $0.role == .assistant }.count, 1)
        XCTAssertTrue(career.finance.entries(season: 1).contains { $0.category == .staff && $0.note.contains(current.name) })
        XCTAssertTrue(career.fireStaff(id: better.id))
        XCTAssertNil(career.staffMember(.assistant))
        XCTAssertFalse(career.fireStaff(id: 9_999))
    }

    func testAssistantAbilityControlsTheReadOfTheRival() throws {
        var career = career()
        let fixture = try XCTUnwrap(career.nextUserFixture)
        func setAssistant(_ ability: Int?) {
            career.staff.removeAll { $0.role == .assistant }
            if let ability { career.staff.append(StaffMember(id: 900, name: "Teste", role: .assistant, ability: ability, wage: 100_000)) }
        }
        setAssistant(20)
        XCTAssertEqual(career.assistantMisreadProbability, 0)
        XCTAssertTrue(career.scoutedOpponentStyle(for: fixture).isCorrect)
        XCTAssertEqual(career.scoutedOpponentStyle(for: fixture).style, career.trueOpponentStyle(for: fixture))

        setAssistant(nil)
        XCTAssertGreaterThan(career.assistantMisreadProbability, 0.25)
        var wrong = 0
        for id in 0..<400 {
            let probe = LeagueFixture(id: 20_000 + id, matchDay: 0, round: 1, competition: .league(.serieA), home: 0, away: 1 + id % 9)
            let read = career.scoutedOpponentStyle(for: probe)
            XCTAssertEqual(read.isCorrect, read.style == career.trueOpponentStyle(for: probe))
            XCTAssertEqual(read.style, career.scoutedOpponentStyle(for: probe).style, "O erro é fixo para cada jogo")
            if !read.isCorrect { wrong += 1 }
        }
        XCTAssertGreaterThan(wrong, 60)
        XCTAssertLessThan(wrong, 180)
    }

    func testFitnessCoachAndDoctorReduceInjuriesAndRecovery() throws {
        var career = career()
        func setStaff(_ role: StaffRole, _ ability: Int) {
            career.staff.removeAll { $0.role == role }
            career.staff.append(StaffMember(id: 800 + role.hashValue % 50, name: "T", role: role, ability: ability, wage: 100_000))
        }
        setStaff(.fitnessCoach, 4)
        let weakRisk = career.injuryRiskFactor
        setStaff(.fitnessCoach, 18)
        XCTAssertLessThan(career.injuryRiskFactor, weakRisk)
        setStaff(.doctor, 4)
        let slow = career.injuryDurationFactor
        setStaff(.doctor, 18)
        XCTAssertLessThan(career.injuryDurationFactor, slow)

        // Na simulação, um fator de risco menor gera menos lesões.
        let fixture = try XCTUnwrap(career.fixtures.first { $0.home == 0 })
        var base = career.makeSimulation(fixture: fixture, detailed: false)
        let players = career.playersByID()
        var high = 0, low = 0
        for seed in 1...300 {
            base.home.injuryFactor = 1.4
            var a = MatchSimulation.make(fixtureID: 1, seed: UInt64(seed) &* 11, isCup: false, isDerby: false, detailed: false, home: base.home, away: base.away)
            a.runToEnd(players: players)
            high += a.home.injuries.count
            base.home.injuryFactor = 0.6
            var b = MatchSimulation.make(fixtureID: 1, seed: UInt64(seed) &* 11, isCup: false, isDerby: false, detailed: false, home: base.home, away: base.away)
            b.runToEnd(players: players)
            low += b.home.injuries.count
        }
        XCTAssertGreaterThan(high, low)

        // Recuperação: preparador físico melhor devolve mais condição.
        var strong = career
        var weak = career
        for index in strong.players.indices { strong.players[index].condition = 60; weak.players[index].condition = 60 }
        strong.staff.removeAll { $0.role == .fitnessCoach }
        weak.staff.removeAll { $0.role == .fitnessCoach }
        strong.staff.append(StaffMember(id: 1, name: "F", role: .fitnessCoach, ability: 20, wage: 1))
        strong.applyWeeklyTraining(for: 0)
        weak.applyWeeklyTraining(for: 0)
        XCTAssertGreaterThan(strong.lastTrainingReport!.averageConditionGain, weak.lastTrainingReport!.averageConditionGain)
    }

    // MARK: - Treino 2.0

    func testSecondaryFocusSetPiecesAndFacilityShapeDevelopment() throws {
        func developed(_ configure: (inout FootballCareer) -> Void) -> Int {
            var total = 0
            for seed in 1...6 {
                var career = FootballCareer(seed: seed * 101)
                _ = career.chooseClub(2)
                career.setTrainingFocus(.technical)
                career.setTrainingIntensity(.intense)
                configure(&career)
                for day in 0..<6 { career.applyWeeklyTraining(for: day) }
                total += career.clubRoster.map { $0.attributes.storage.reduce(0, +) }.reduce(0, +) -
                    FootballCareer(seed: seed * 101).players(forTeam: 2).map { $0.attributes.storage.reduce(0, +) }.reduce(0, +)
            }
            return total
        }
        let plain = developed { _ in }
        let withSecondary = developed { $0.setSecondaryTrainingFocus(.defending) }
        let withBadCentre = developed { $0.trainingCenterLevel = 1 }
        let withGoodCentre = developed { $0.trainingCenterLevel = 5 }
        XCTAssertGreaterThan(withSecondary, plain, "Um segundo foco desenvolve mais atletas")
        XCTAssertGreaterThan(withGoodCentre, withBadCentre)

        var career = career()
        career.setTrainingFocus(.attacking)
        career.setSecondaryTrainingFocus(.attacking)
        XCTAssertNil(career.secondaryTrainingFocus, "O segundo foco não repete o primeiro")
        career.setSecondaryTrainingFocus(.setPieces)
        XCTAssertEqual(career.secondaryTrainingFocus, .setPieces)
        let side = career.makeSideState(teamID: 0, rivalID: 1, isUser: true)
        XCTAssertEqual(side.setPieceBoost, 0.06, accuracy: 0.0001)
        career.setTrainingFocus(.setPieces)
        XCTAssertEqual(career.makeSideState(teamID: 0, rivalID: 1, isUser: true).setPieceBoost, 0.06, accuracy: 0.0001, "Só conta uma vez por sessão distinta")
    }

    func testSetPieceTrainingProducesMoreSetPieceGoals() throws {
        let career = career()
        let fixture = try XCTUnwrap(career.fixtures.first { $0.home == 0 })
        let base = career.makeSimulation(fixture: fixture, detailed: true)
        let players = career.playersByID()
        func setPieceGoals(boost: Double) -> Int {
            var total = 0
            for seed in 1...400 {
                var home = base.home
                home.setPieceBoost = boost
                var sim = MatchSimulation.make(fixtureID: 1, seed: UInt64(seed) &* 19, isCup: false, isDerby: false, detailed: true, home: home, away: base.away)
                sim.runToEnd(players: players)
                total += sim.events.filter { $0.kind == .goal && $0.teamID == 0 && $0.text.contains("bola parada") }.count
            }
            return total
        }
        XCTAssertGreaterThan(setPieceGoals(boost: 0.9), setPieceGoals(boost: 0.0))
    }

    func testOpponentPrepGivesBonusOnlyWithACorrectReadAndIsConsumed() throws {
        var career = career()
        career.staff.removeAll { $0.role == .assistant }
        career.staff.append(StaffMember(id: 700, name: "A", role: .assistant, ability: 20, wage: 100_000))
        career.setOpponentPrep(true)
        let prepared = career.makeSideState(teamID: 0, rivalID: 1, isUser: true)
        XCTAssertEqual(prepared.attackBoost, 1.5, accuracy: 0.0001)
        XCTAssertEqual(prepared.defenseBoost, 1.0, accuracy: 0.0001)

        career.setOpponentPrep(false)
        XCTAssertEqual(career.makeSideState(teamID: 0, rivalID: 1, isUser: true).attackBoost, 0, accuracy: 0.0001)

        // O treino rende menos na semana de preparação.
        func gain(prep: Bool) -> Int {
            var total = 0
            for seed in 1...6 {
                var copy = FootballCareer(seed: seed * 101)
                _ = copy.chooseClub(2)
                copy.setTrainingFocus(.technical)
                copy.setTrainingIntensity(.intense)
                copy.setOpponentPrep(prep)
                for day in 0..<6 { copy.applyWeeklyTraining(for: day) }
                total += copy.lastTrainingReport?.developedPlayers ?? 0
                total += copy.clubRoster.filter { $0.overall > (FootballCareer(seed: seed * 101).player($0.id)?.overall ?? 0) }.count
            }
            return total
        }
        XCTAssertGreaterThan(gain(prep: false), gain(prep: true))

        career.setOpponentPrep(true)
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertFalse(career.opponentPrep, "A preparação vale para um jogo")
    }

    func testIndividualProgramsAreLimitedAndLearningAPositionMakesItAdapted() throws {
        var career = career()
        let squad = career.clubRoster
        XCTAssertTrue(career.setIndividualFocus(playerID: squad[0].id, kind: .finishing))
        XCTAssertTrue(career.setIndividualFocus(playerID: squad[1].id, kind: .passing))
        let midfielder = try XCTUnwrap(squad.first { $0.position == .midfielder && $0.individualFocus == nil })
        XCTAssertTrue(career.startLearning(playerID: midfielder.id, position: .forward))
        XCTAssertEqual(career.individualProgramCount, 3)
        XCTAssertFalse(career.setIndividualFocus(playerID: squad[2].id, kind: .pace), "No máximo três programas")
        XCTAssertFalse(career.startLearning(playerID: squad[3].id, position: .defender))
        XCTAssertFalse(career.setIndividualFocus(playerID: squad[0].id, kind: .injuryProneness), "Atributos ocultos não se treinam")
        XCTAssertFalse(career.startLearning(playerID: midfielder.id, position: .midfielder), "Já é a posição natural")

        for day in 0..<4 { career.applyWeeklyTraining(for: day) }
        let learned = try XCTUnwrap(career.player(midfielder.id))
        XCTAssertTrue(learned.learnedPositions.contains(.forward) || learned.learningProgress > 0)
        for day in 4..<8 { career.applyWeeklyTraining(for: day) }
        let done = try XCTUnwrap(career.player(midfielder.id))
        XCTAssertEqual(done.learnedPositions, [.forward])
        XCTAssertNil(done.learningPosition)
        XCTAssertTrue(done.canPlay(as: .forward))
        XCTAssertEqual(career.individualProgramCount, 2)
        XCTAssertTrue(career.inbox.contains { $0.title.contains("aprendeu uma posição") })
    }

    // MARK: - Economia ao longo do tempo

    func testEconomyStaysSustainableForDifferentClubsOverSeasons() throws {
        for (club, range) in [(0, -1_500_000...5_000_000), (9, -2_500_000...3_000_000), (10, -2_000_000...2_500_000)] {
            var career = self.career(club: club, seed: 4_242)
            var nets: [Int] = []
            for _ in 0..<3 {
                for _ in 0..<FootballSeason.matchDaysPerSeason { XCTAssertTrue(career.simulateNextMatchDay()) }
                let season = career.season
                let income = career.finance.income(season: season)
                let expenses = career.finance.expenses(season: season)
                let byCategory = FinanceCategory.allCases.reduce(0) { $0 + career.finance.total(season: season, category: $1) }
                XCTAssertEqual(byCategory, income - expenses)
                nets.append(income - expenses)
                _ = career.startNextSeason()
                if career.isFired, let job = career.jobOffers.first { XCTAssertTrue(career.acceptJob(job.id)); break }
                XCTAssertEqual(career.finance.summaries.last?.season, season)
            }
            let average = nets.reduce(0, +) / max(1, nets.count)
            XCTAssertTrue(range.contains(average), "Resultado médio do clube \(club): \(average)")
        }
    }

    // MARK: - Saves

    func testClubStateSurvivesSaveAndOldSavesGetDefaults() throws {
        var career = career(club: 3)
        career.transferBudget = 30_000_000
        XCTAssertTrue(career.startUpgrade(.medical))
        career.ticketPrice = .premium
        career.setSecondaryTrainingFocus(.recovery)
        career.setOpponentPrep(true)
        career.stadiumLevel = 2
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip, career)

        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        legacy["schemaVersion"] = 6
        for key in ["trainingCenterLevel", "medicalLevel", "stadiumLevel", "upgradeProject", "nextProjectID", "ticketPrice", "fanBase",
                    "sponsorDeal", "sponsorOffers", "redMatchDays", "secondaryTrainingFocus", "opponentPrep"] {
            legacy.removeValue(forKey: key)
        }
        let migrated = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(migrated.ticketPrice, .normal)
        XCTAssertEqual(migrated.stadiumLevel, 1)
        XCTAssertGreaterThan(migrated.fanBase, 10_000)
        var playable = migrated
        XCTAssertTrue(playable.simulateNextMatchDay())
    }
}

extension FootballCareer {
    /// Gerador fixo para testes.
    var rngForTests: FootballRandom {
        get { FootballRandom(seed: 12_345) }
        set { _ = newValue }
    }
}
