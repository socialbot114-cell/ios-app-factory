import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballWorldTests: XCTestCase {
    private func career(club: Int = 0, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    // MARK: - Vida do treinador

    func testSalaryAssetsInvestmentsAndWellbeing() throws {
        var career = career(club: 3)
        XCTAssertGreaterThan(career.coachSalaryPerSeason, 0)
        XCTAssertGreaterThan(career.coachSalaryPerSeason, self.career(club: 19).coachSalaryPerSeason)
        let cash = career.world.coach.personalCash
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertGreaterThan(career.world.coach.personalCash, cash, "O salário é pago a cada dia de jogo")

        career.world.coach.personalCash = 2_000_000
        XCTAssertNil(career.canBuyAsset(.apartment))
        XCTAssertTrue(career.buyAsset(.apartment))
        XCTAssertNotNil(career.canBuyAsset(.apartment), "Só um de cada, exceto relógios")
        XCTAssertNil(career.canBuyAsset(.watch))
        let before = career.world.coach.personalCash
        let asset = try XCTUnwrap(career.world.coach.assets.first)
        XCTAssertTrue(career.sellAsset(id: asset.id))
        XCTAssertEqual(career.world.coach.personalCash, before + Int(Double(AssetKind.apartment.price) * 0.7))

        XCTAssertFalse(career.invest(.fund, amount: 5_000), "Mínimo de R$ 10 mil")
        XCTAssertTrue(career.invest(.fund, amount: 100_000))
        XCTAssertTrue(career.invest(.franchise, amount: 100_000))
        XCTAssertEqual(career.investmentsValue, 200_000)
        for _ in 0..<5 { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertNotEqual(career.investmentsValue, 200_000)
        XCTAssertGreaterThan(career.coachNetWorth, career.world.coach.personalCash)
        let investment = try XCTUnwrap(career.world.coach.investments.first)
        XCTAssertTrue(career.withdrawInvestment(id: investment.id))

        // Energia e estresse reagem aos resultados.
        var tired = self.career()
        tired.world.coach.energy = 10
        tired.world.coach.stress = 90
        let confidence = tired.boardConfidence
        tired.tickCoachWellbeing(result: .loss, derby: true)
        XCTAssertGreaterThan(tired.world.coach.stress, 90 - 2)
        XCTAssertLessThan(tired.boardConfidence, confidence, "Estresse extremo pesa na confiança")
    }

    func testActivitiesFollowOneDailySlotAndEnergyRules() throws {
        var career = career()
        career.world.coach.energy = 50
        XCTAssertNotNil(career.canDo(.study), "Sem curso não há aula")
        let result = try XCTUnwrap(career.doActivity(.tvPunditry))
        XCTAssertGreaterThan(result.cashChange, 0)
        XCTAssertNotNil(career.canDo(.lecture), "Uma atividade por dia de jogo")
        XCTAssertNil(career.doActivity(.lecture))
        XCTAssertEqual(career.world.coach.energy, 35)
        XCTAssertTrue(career.simulateNextMatchDay())
        career.world.coach.energy = 5
        XCTAssertNotNil(career.canDo(.tvPunditry), "Sem energia")
        let rest = try XCTUnwrap(career.doActivity(.rest))
        XCTAssertFalse(rest.text.isEmpty)
        XCTAssertGreaterThanOrEqual(career.world.coach.energy, 35)

        // Livro: seis sessões publicam e passam a render royalties.
        var writer = self.career()
        for day in 0..<6 {
            writer.world.coach.energy = 80
            writer.world.coach.lastActivityWorldDay = -1
            XCTAssertNotNil(writer.doActivity(.writeBook), "sessão \(day)")
            writer.matchDayIndex += 1
        }
        XCTAssertEqual(writer.world.coach.booksPublished, 1)
        XCTAssertEqual(writer.world.coach.bookSessions, 0)
    }

    func testCoachingLicensesCostMoneyTakeStudyAndWidenTheJobMarket() throws {
        var career = career()
        XCTAssertEqual(career.world.coach.licenseLevel, 1)
        career.reputation = 10
        XCTAssertNotNil(career.canStartCourse(), "Reputação baixa demais para a licença B")
        career.reputation = 60
        career.world.coach.personalCash = 500_000
        XCTAssertNil(career.canStartCourse())
        XCTAssertTrue(career.startCourse())
        XCTAssertEqual(career.world.coach.personalCash, 500_000 - CoachProfile.courseCosts[1])
        XCTAssertNotNil(career.canStartCourse(), "Um curso por vez")
        for session in 0..<CoachProfile.courseSessions[1] {
            career.world.coach.energy = 80
            career.world.coach.lastActivityWorldDay = -1
            XCTAssertNotNil(career.doActivity(.study), "aula \(session)")
            career.matchDayIndex += 1
        }
        XCTAssertEqual(career.world.coach.licenseLevel, 2)
        XCTAssertNil(career.world.coach.course)
        XCTAssertEqual(career.maxPrestige, 50 + Int(Double(career.reputation) * 0.4) + 3)
        XCTAssertEqual(career.world.coach.licenseName, "Licença B")
        XCTAssertTrue(career.inbox.contains { $0.title.contains("Nova licença") })
    }

    // MARK: - Rede social

    func testFeedIsGeneratedFromResultsAndStaysBounded() throws {
        var career = career()
        XCTAssertGreaterThan(career.world.social.coachFollowers, 3_000)
        XCTAssertGreaterThan(career.world.social.clubFollowers, 100_000)
        for _ in 0..<10 { XCTAssertTrue(career.simulateNextMatchDay()) }
        let posts = career.world.social.posts
        XCTAssertFalse(posts.isEmpty)
        XCTAssertLessThanOrEqual(posts.count, FootballCareer.socialPostLimit)
        XCTAssertGreaterThan(Set(posts.map(\.author)).count, 2)
        XCTAssertTrue(posts.allSatisfy { $0.handle.hasPrefix("@") && !$0.text.isEmpty && $0.likes >= 0 })
        XCTAssertEqual(Set(posts.map(\.id)).count, posts.count)
        XCTAssertTrue(posts.contains { $0.author == .fan })
        XCTAssertTrue(posts.contains { $0.author == .journalist })
    }

    func testPostingToneEffectsLimitsAndViralRisk() throws {
        var career = career()
        XCTAssertTrue(career.simulateNextMatchDay())
        let fans = career.fanMood
        let followers = career.world.social.coachFollowers
        let post = try XCTUnwrap(career.publishPost(tone: .thanks))
        XCTAssertTrue(post.isUser)
        XCTAssertEqual(post.author, .coach)
        XCTAssertGreaterThanOrEqual(career.fanMood, fans + 2)
        XCTAssertGreaterThanOrEqual(career.world.social.coachFollowers, followers)
        XCTAssertNotNil(career.canPost(.humor), "Uma publicação por dia de jogo")
        XCTAssertNil(career.publishPost(tone: .humor))
        XCTAssertNotNil(career.canPost(.sponsored), "Sem contrato de marca")
        XCTAssertEqual(career.counters["posts"], 1)

        // Provocar com frequência gera polêmica, crise e custo de imagem.
        var risky = self.career(seed: 21)
        var crises = 0
        var backlash = 0
        for day in 0..<40 {
            risky.world.social.lastPostWorldDay = -1
            risky.matchDayIndex = day % 20
            risky.world.social.crisis = nil
            if risky.publishPost(tone: .provocative) != nil, risky.world.social.controversy >= 12 { backlash += 1 }
            if risky.world.social.crisis != nil { crises += 1 }
            risky.world.social.controversy = max(0, risky.world.social.controversy - 5)
        }
        XCTAssertGreaterThan(backlash, 0)

        // Publis exigem contrato de marca e pagam por post.
        var sponsored = self.career()
        sponsored.world.social.coachFollowers = 60_000
        sponsored.refreshBrandOffers()
        XCTAssertGreaterThanOrEqual(sponsored.world.social.brandOffers.count, 2)
        let offer = try XCTUnwrap(sponsored.world.social.brandOffers.first)
        XCTAssertTrue(sponsored.acceptBrandDeal(id: offer.id))
        let cash = sponsored.world.coach.personalCash
        XCTAssertNotNil(sponsored.publishPost(tone: .sponsored))
        XCTAssertEqual(sponsored.world.coach.personalCash, cash + offer.payPerPost)
        XCTAssertEqual(sponsored.world.social.brandDeals.first?.postsDone, 1)
        _ = crises
    }

    func testCrisesAreResolvedWithTradeOffs() throws {
        var career = career()
        career.world.social.controversy = 80
        var random = FootballRandom(seed: 5)
        career.maybeTriggerCrisis(using: &random)
        let crisis = try XCTUnwrap(career.world.social.crisis)
        XCTAssertNotNil(career.canPost(.motivational), "Crise ativa bloqueia postagens")
        XCTAssertTrue(career.inbox.contains { $0.title.contains(crisis.title) })

        var apologize = career
        let before = apologize.world.social.controversy
        XCTAssertNotNil(apologize.resolveCrisis(.apologize))
        XCTAssertEqual(apologize.world.social.controversy, before - 30)
        XCTAssertNil(apologize.world.social.crisis)

        var ignore = career
        let confidence = ignore.boardConfidence
        XCTAssertNotNil(ignore.resolveCrisis(.ignore))
        XCTAssertLessThan(ignore.boardConfidence, confidence)

        var legal = career
        legal.world.coach.personalCash = 10_000
        XCTAssertNil(legal.resolveCrisis(.legal), "Sem dinheiro para a assessoria")
        legal.world.coach.personalCash = 100_000
        XCTAssertNotNil(legal.resolveCrisis(.legal))
        XCTAssertEqual(legal.world.coach.personalCash, 80_000)

        var reply = self.career()
        _ = reply.simulateNextMatchDay()
        let fanPost = try XCTUnwrap(reply.world.social.posts.first { $0.author == .fan })
        let followers = reply.world.social.coachFollowers
        XCTAssertTrue(reply.replyToFan(postID: fanPost.id))
        XCTAssertFalse(reply.replyToFan(postID: fanPost.id), "Só uma resposta por post")
        XCTAssertEqual(reply.world.social.coachFollowers, followers + 120)
    }

    // MARK: - Acontecimentos

    func testEveryEventTemplateIsWellFormedAndApplicable() throws {
        XCTAssertGreaterThanOrEqual(FootballCareer.eventTemplates.count, 28)
        XCTAssertEqual(Set(FootballCareer.eventTemplates.map(\.id)).count, FootballCareer.eventTemplates.count)
        var career = self.career()
        for _ in 0..<5 { XCTAssertTrue(career.simulateNextMatchDay()) }
        career.world.coach.personalCash = 200_000
        career.fanMood = 40
        for template in FootballCareer.eventTemplates {
            XCTAssertGreaterThanOrEqual(template.options.count, 2, template.id)
            XCTAssertTrue(template.options.indices.contains(template.defaultChoice), template.id)
            var random = FootballRandom(seed: 3)
            let built = template.build(career, &random)
            XCTAssertFalse(built.title.isEmpty)
            XCTAssertFalse(built.body.isEmpty)
            for (index, option) in template.options.enumerated() {
                var copy = career
                for effect in option.effects { copy.apply(effect, playerID: built.playerID, using: &random) }
                XCTAssertTrue((0...100).contains(copy.fanMood), "\(template.id) opção \(index)")
                XCTAssertTrue((0...100).contains(copy.boardConfidence))
                XCTAssertTrue((0...100).contains(copy.world.coach.energy))
                XCTAssertTrue((0...100).contains(copy.world.coach.stress))
                XCTAssertTrue(copy.players.allSatisfy { (0...100).contains($0.morale) && (40...100).contains($0.condition) })
                XCTAssertEqual(copy.startingXI.count, 11)
                XCTAssertFalse(option.result.isEmpty)
            }
        }
    }

    func testEventsAppearAreLimitedResolvedAndExpireWithTheDefaultChoice() throws {
        var career = career(seed: 11)
        var seen = Set<String>()
        for _ in 0..<FootballSeason.matchDaysPerSeason {
            XCTAssertTrue(career.simulateNextMatchDay())
            XCTAssertLessThanOrEqual(career.world.events.pending.count, 2 + 1)
            for event in career.world.events.pending { seen.insert(event.templateID) }
            if let event = career.world.events.pending.first, event.expiresWorldDay > career.worldDay + 1 {
                let before = career.world.events.history.count
                let text = career.resolveEvent(id: event.id, choice: 0)
                XCTAssertNotNil(text)
                XCTAssertEqual(career.world.events.history.count, before + 1)
                XCTAssertEqual(career.world.events.history.first?.resolvedChoice, 0)
                XCTAssertNil(career.resolveEvent(id: event.id, choice: 0), "Já resolvido")
            }
        }
        XCTAssertGreaterThanOrEqual(seen.count, 3, "Eventos variados ao longo da temporada")
        XCTAssertGreaterThan(career.counters["events"] ?? 0, 0)

        var expiring = self.career()
        let template = FootballCareer.eventTemplates[0]
        var random = FootballRandom(seed: 1)
        let built = template.build(expiring, &random)
        expiring.world.events.pending = [WorldEvent(id: 99, templateID: template.id, category: template.category, season: 1, matchDay: 0, title: built.title,
                                                    body: built.body, choices: template.options.map { EventChoice(label: $0.label, hint: $0.hint) },
                                                    expiresWorldDay: 0, defaultChoice: template.defaultChoice, playerID: built.playerID)]
        expiring.expireWorldEvents()
        XCTAssertTrue(expiring.world.events.pending.isEmpty)
        XCTAssertEqual(expiring.world.events.history.first?.resolvedChoice, template.defaultChoice)
        XCTAssertLessThanOrEqual(expiring.world.events.history.count, 40)
    }

    // MARK: - Negócios

    func testShopNamingRightsAndCommunityProgramsMoveMoney() throws {
        var career = career(club: 3)
        career.transferBudget = 20_000_000
        let revenue = career.merchRevenuePerMatchDay
        XCTAssertGreaterThan(revenue, 0)
        XCTAssertTrue(career.upgradeShop())
        XCTAssertGreaterThan(career.merchRevenuePerMatchDay, revenue)
        career.setShopPrice(.low)
        let cheap = career.merchRevenuePerMatchDay
        career.setShopPrice(.high)
        XCTAssertNotEqual(career.merchRevenuePerMatchDay, cheap)
        let normal = career.merchRevenuePerMatchDay
        XCTAssertTrue(career.launchCollection())
        XCTAssertGreaterThan(career.merchRevenuePerMatchDay, normal)
        XCTAssertFalse(career.launchCollection(), "Coleção já ativa")

        var random = FootballRandom(seed: 4)
        career.refreshNamingOffers(using: &random)
        XCTAssertEqual(career.world.business.namingOffers.count, 3)
        let offer = try XCTUnwrap(career.world.business.namingOffers.first)
        XCTAssertGreaterThan(offer.perSeason, 0)
        XCTAssertTrue(career.acceptNamingOffer(offer.id))
        XCTAssertEqual(career.stadiumDisplayName, offer.stadiumName)
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertTrue(career.finance.entries(season: 1).contains { $0.category == .naming })
        XCTAssertTrue(career.finance.entries(season: 1).contains { $0.category == .merchandise })

        XCTAssertTrue(career.toggle(.fanClubs))
        XCTAssertTrue(career.toggle(.schoolProject))
        XCTAssertTrue(career.toggle(.hospitalVisits))
        XCTAssertNotNil(career.canToggle(.footballAcademy), "Máximo de três programas")
        let fans = career.fanBase
        for _ in 0..<6 { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertGreaterThan(career.fanBase, fans)
        XCTAssertTrue(career.finance.entries(season: 1).contains { $0.category == .community })
        XCTAssertTrue(career.toggle(.fanClubs), "Dá para encerrar um programa")
        XCTAssertEqual(career.world.business.programs.count, 2)
    }

    func testFriendliesAndTourRulesAndEffects() throws {
        var career = career()
        XCTAssertNil(career.canPlayFriendly(), "Pré-temporada")
        let cash = career.transferBudget
        let appearances = career.players.reduce(0) { $0 + $1.appearances }
        let goals = career.players.reduce(0) { $0 + $1.goals }
        let record = try XCTUnwrap(career.playFriendly(opponentID: 5, home: true))
        XCTAssertEqual(record.opponentID, 5)
        XCTAssertGreaterThan(career.transferBudget, cash)
        XCTAssertEqual(career.players.reduce(0) { $0 + $1.appearances }, appearances, "Amistoso não conta nas estatísticas")
        XCTAssertEqual(career.players.reduce(0) { $0 + $1.goals }, goals)
        XCTAssertEqual(career.matchDayIndex, 0)
        XCTAssertEqual(career.startingXI.count, 11)
        XCTAssertEqual(career.world.business.friendliesThisSeason, 1)
        for opponent in [6, 7, 8] { XCTAssertNotNil(career.playFriendly(opponentID: opponent, home: false)) }
        XCTAssertNotNil(career.canPlayFriendly(), "Limite por temporada")
        XCTAssertNil(career.playFriendly(opponentID: 9, home: true))

        var other = self.career()
        XCTAssertTrue(career.doPreseasonTour() || career.canDoTour() != nil)
        let fans = other.fanBase
        XCTAssertNil(other.canDoTour())
        XCTAssertTrue(other.doPreseasonTour())
        XCTAssertGreaterThan(other.fanBase, fans)
        XCTAssertNotNil(other.canDoTour(), "Uma por temporada")
        XCTAssertTrue(other.simulateNextMatchDay())
        XCTAssertNotNil(other.canPlayFriendly(), "Em dia de jogo não há amistoso")
    }

    func testAgentOffersDiscountWagesButHideRisks() throws {
        var career = career()
        career.transferBudget = 50_000_000
        career.wageCap = career.wageBill * 3
        var found: AgentOffer?
        for seed in 1...60 where found == nil {
            var random = FootballRandom(seed: UInt64(seed))
            career.world.business.agentOffers = []
            career.generateAgentOffers(using: &random)
            found = career.world.business.agentOffers.first
        }
        let offer = try XCTUnwrap(found)
        let target = try XCTUnwrap(career.player(offer.playerID))
        XCTAssertLessThan(offer.discountedWage, target.contract.wage)
        let cash = career.transferBudget
        XCTAssertTrue(career.acceptAgentOffer(offer.id))
        let signed = try XCTUnwrap(career.player(offer.playerID))
        XCTAssertEqual(signed.teamID, 0)
        XCTAssertEqual(signed.contract.wage, offer.discountedWage)
        XCTAssertEqual(career.transferBudget, cash - target.marketValue - offer.agentFee)
        XCTAssertTrue(career.world.business.agentOffers.isEmpty)
    }

    // MARK: - Missões

    func testQuestsTrackCountersPayRewardsAndRefresh() throws {
        var career = career()
        var random = FootballRandom(seed: 3)
        career.refreshQuests(using: &random)
        XCTAssertEqual(career.world.quests.active.filter { !$0.seasonal }.count, 3)
        XCTAssertEqual(career.world.quests.active.filter(\.seasonal).count, 2)
        XCTAssertEqual(Set(career.world.quests.active.map(\.templateID)).count, 5)
        for quest in career.world.quests.active { XCTAssertEqual(career.progress(of: quest), 0) }

        let quest = try XCTUnwrap(career.world.quests.active.first { !$0.seasonal })
        let fichas = career.world.betting.fichas
        let cash = career.world.coach.personalCash
        let followers = career.world.social.coachFollowers
        career.counters[quest.counter, default: 0] += quest.target
        XCTAssertEqual(career.progress(of: quest), quest.target)
        career.updateQuests()
        XCTAssertTrue(career.world.quests.active.first { $0.id == quest.id }!.completed)
        XCTAssertEqual(career.world.quests.completedCount, 1)
        XCTAssertEqual(career.world.betting.fichas, fichas + quest.reward.fichas)
        XCTAssertEqual(career.world.coach.personalCash, cash + quest.reward.cash)
        XCTAssertEqual(career.world.social.coachFollowers, followers + quest.reward.followers)
        XCTAssertTrue(career.inbox.contains { $0.title == "Missão cumprida: \(quest.title)" })
        career.updateQuests()
        XCTAssertEqual(career.world.quests.completedCount, 1, "Paga uma vez")

        career.refreshQuests(using: &random)
        XCTAssertFalse(career.world.quests.active.contains { $0.id == quest.id })
        XCTAssertEqual(career.world.quests.active.filter { !$0.seasonal }.count, 3)

        for _ in 0..<12 { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertGreaterThan(career.world.quests.nextQuestID, 6, "Novas missões surgem com o tempo")
    }

    // MARK: - Integração e saves

    func testAllSystemsRunTogetherForSeveralSeasonsWithoutBreakingInvariants() throws {
        var career = career(club: 5, seed: 99)
        for season in 1...3 {
            for day in 0..<FootballSeason.matchDaysPerSeason {
                if day % 4 == 0 { _ = career.publishPost(tone: .thanks); career.world.social.lastPostWorldDay = -1 }
                if day % 5 == 0, let option = career.bettingFixtures.first.flatMap({ career.options(for: $0).first }) {
                    _ = career.placeBet(stake: 20, legs: [option.leg])
                }
                if day % 6 == 0 { _ = career.setFantasyLineup(ids: career.suggestedFantasyLineup().ids, captainID: career.suggestedFantasyLineup().captainID) }
                if day % 7 == 0 { _ = career.doActivity(.rest) }
                if career.isFired, let job = career.jobOffers.first { XCTAssertTrue(career.acceptJob(job.id)) }
                XCTAssertTrue(career.simulateNextMatchDay(), "temporada \(season) dia \(day)")
                career.world.events.pending.forEach { _ = career.resolveEvent(id: $0.id, choice: $0.defaultChoice) }
            }
            XCTAssertGreaterThanOrEqual(career.world.betting.fichas, 0)
            XCTAssertLessThanOrEqual(career.world.social.posts.count, FootballCareer.socialPostLimit)
            XCTAssertLessThanOrEqual(career.world.events.history.count, 40)
            XCTAssertTrue((0...100).contains(career.world.coach.energy))
            XCTAssertNotNil(career.startNextSeason())
            if career.isFired, let job = career.jobOffers.first { XCTAssertTrue(career.acceptJob(job.id)) }
        }
        XCTAssertGreaterThan(career.world.quests.completedCount, 0)
    }

    func testWorldStateSurvivesSaveAndOldSavesGetDefaults() throws {
        var career = career()
        for _ in 0..<6 { XCTAssertTrue(career.simulateNextMatchDay()) }
        _ = career.publishPost(tone: .motivational)
        _ = career.buyAsset(.watch)
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip, career)

        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        legacy["schemaVersion"] = 9
        legacy.removeValue(forKey: "world")
        if let fixtures = legacy["fixtures"] as? [[String: Any]] {
            legacy["fixtures"] = fixtures.map { var copy = $0; for key in ["assistIDs", "playedIDs", "yellowIDs", "redIDs"] { copy.removeValue(forKey: key) }; return copy }
        }
        let migrated = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(migrated.world.betting.fichas, 1_000)
        XCTAssertTrue(migrated.world.social.posts.isEmpty)
        var playable = migrated
        XCTAssertTrue(playable.simulateNextMatchDay())
    }
}
