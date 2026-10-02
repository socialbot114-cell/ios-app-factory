import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballModesTests: XCTestCase {
    private func career(club: Int = 0, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    // MARK: - Dificuldade

    func testDifficultyChangesRivalsIncomePricesAndBoardPatience() throws {
        var easy = career(club: 5)
        var hard = career(club: 5)
        easy.difficulty = .easy
        hard.difficulty = .hard
        let rivalEasy = easy.makeSideState(teamID: 1, rivalID: 5, isUser: false)
        let rivalHard = hard.makeSideState(teamID: 1, rivalID: 5, isUser: false)
        XCTAssertEqual(rivalEasy.attackBoost, -1.5, accuracy: 0.001)
        XCTAssertEqual(rivalHard.defenseBoost, 1.5, accuracy: 0.001)
        let neutral = hard.makeSideState(teamID: 1, rivalID: 2, isUser: false)
        XCTAssertEqual(neutral.attackBoost, 0, "Só os rivais do usuário são afetados")

        easy.book(.gate, 100_000, "x")
        hard.book(.gate, 100_000, "x")
        XCTAssertGreaterThan(easy.finance.entries.last!.amount, 100_000)
        XCTAssertLessThan(hard.finance.entries.last!.amount, 100_000)
        easy.book(.prize, 100_000, "p")
        XCTAssertEqual(easy.finance.entries.last!.amount, 100_000, "Premiações não mudam")

        let player = try XCTUnwrap(easy.players(forTeam: 3).first)
        XCTAssertLessThan(easy.askingPrice(for: player), hard.askingPrice(for: player))
        XCTAssertLessThan(easy.boardPatienceThreshold(for: 5), hard.boardPatienceThreshold(for: 5))
        XCTAssertEqual(Difficulty.allCases.count, 3)
    }

    func testEasyIsKinderThanHardOverSeveralSeasons() throws {
        func points(_ difficulty: Difficulty) -> Int {
            var total = 0
            for seed in 1...8 {
                var career = FootballCareer(seed: seed * 4_001)
                _ = career.chooseClub(5)
                career.difficulty = difficulty
                for _ in 0..<FootballSeason.matchDaysPerSeason { career.simulateNextMatchDay() }
                total += career.standings.first { $0.team.id == 5 }?.points ?? 0
            }
            return total
        }
        XCTAssertGreaterThan(points(.easy), points(.hard))
    }

    // MARK: - Desafios

    func testEveryChallengeScenarioBuildsAPlayableCareerWithItsRules() throws {
        XCTAssertEqual(ChallengeScenario.all.count, 5)
        for scenario in ChallengeScenario.all {
            var career = FootballCareer.challenge(scenario)
            XCTAssertEqual(career.selectedClubID, scenario.clubID, scenario.title)
            XCTAssertEqual(career.transferBudget, scenario.startingCash)
            XCTAssertEqual(career.difficulty, scenario.difficulty)
            XCTAssertEqual(career.challenge?.status, .active)
            XCTAssertEqual(career.startingXI.count, 11)
            XCTAssertTrue(career.inbox.contains { $0.title.contains(scenario.title) })
            if let factor = scenario.wageCapFactor { XCTAssertEqual(career.wageCap, Int(Double(career.wageBill) * factor)) }
            if let age = scenario.youngSquadMaxAge { XCTAssertTrue(career.clubRoster.allSatisfy { $0.age <= age }, scenario.title) }
            XCTAssertTrue(career.simulateNextMatchDay(), scenario.title)
        }
    }

    func testYoungStarterRuleKeepsLineupsEligibleAndFailsTheChallengeOtherwise() throws {
        let scenario = try XCTUnwrap(ChallengeScenario.scenario(id: "so-garotos"))
        var career = FootballCareer.challenge(scenario)
        XCTAssertEqual(career.starterAgeLimit, 23)
        XCTAssertTrue(career.starters.allSatisfy { $0.age <= 23 })
        career.autoSelectLineup()
        XCTAssertTrue(career.starters.allSatisfy { $0.age <= 23 })
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertEqual(career.challenge?.status, .active)

        // Um titular veterano quebra a regra.
        let veteran = try XCTUnwrap(career.clubRoster.first { !career.startingXI.contains($0.id) })
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == veteran.id })
        career.players[index].age = 31
        let outgoing = try XCTUnwrap(career.starters.first { $0.position == veteran.position })
        XCTAssertTrue(career.substitute(outgoingID: outgoing.id, incomingID: veteran.id))
        XCTAssertTrue(career.lineupWarnings.contains { $0.hasPrefix("Desafio:") })
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertEqual(career.challenge?.status, .failed)
        XCTAssertTrue(career.challenge?.failureReason?.contains("limite do desafio") ?? false)
        XCTAssertNil(career.starterAgeLimit, "Depois de falhar, a regra deixa de valer")
    }

    func testChallengeGoalsAreEvaluatedAtSeasonEndWithinTheAllowedSeasons() throws {
        func record(position: Int, promoted: Bool = false, relegated: Bool = false, cup: Bool = false, fired: Bool = false, season: Int = 1, division: Division = .serieA) -> SeasonRecord {
            var record = SeasonRecord(season: season, clubID: 6, championID: 0, position: position, points: 20, target: 8, objectiveMet: true, prizeMoney: 0,
                                      topScorerName: "—", topScorerTeamID: nil, topScorerGoals: 0, retiredPlayers: 0, youthPromoted: 0, wasFired: fired)
            record.promoted = promoted
            record.relegated = relegated
            record.division = division
            record.cupWinnerID = cup ? 6 : 0
            return record
        }
        var survive = FootballCareer.challenge(try XCTUnwrap(ChallengeScenario.scenario(id: "capital-norte")))
        survive.evaluateChallenge(after: record(position: 9, relegated: true))
        XCTAssertEqual(survive.challenge?.status, .failed)

        var saved = FootballCareer.challenge(try XCTUnwrap(ChallengeScenario.scenario(id: "capital-norte")))
        saved.evaluateChallenge(after: record(position: 7))
        XCTAssertEqual(saved.challenge?.status, .won)
        XCTAssertEqual(saved.challenge?.wonInSeason, 1)
        XCTAssertTrue(saved.isUnlocked(.challengeWon) || saved.checkAchievements().contains(.challengeWon))

        var promotion = FootballCareer.challenge(try XCTUnwrap(ChallengeScenario.scenario(id: "orcamento-zero")))
        promotion.evaluateChallenge(after: record(position: 5, season: 1, division: .serieB))
        XCTAssertEqual(promotion.challenge?.status, .active, "Ainda resta uma temporada")
        promotion.evaluateChallenge(after: record(position: 2, promoted: true, season: 2, division: .serieB))
        XCTAssertEqual(promotion.challenge?.status, .won)

        var rebuild = FootballCareer.challenge(try XCTUnwrap(ChallengeScenario.scenario(id: "reconstrucao")))
        rebuild.transferBudget = 500_000
        rebuild.evaluateChallenge(after: record(position: 4))
        XCTAssertEqual(rebuild.challenge?.status, .active, "Caixa abaixo da meta")
        rebuild.transferBudget = 3_000_000
        rebuild.evaluateChallenge(after: record(position: 4, season: 2))
        XCTAssertEqual(rebuild.challenge?.status, .won, "Duas metas juntas")

        var cup = FootballCareer.challenge(try XCTUnwrap(ChallengeScenario.scenario(id: "rei-da-copa")))
        cup.evaluateChallenge(after: record(position: 3, fired: true))
        XCTAssertEqual(cup.challenge?.status, .failed)
        XCTAssertTrue(cup.challenge?.failureReason?.contains("demitido") ?? false)
    }

    // MARK: - Conquistas

    func testAchievementsUnlockOnceFromRealPlayAndCraftedMilestones() throws {
        var career = career()
        XCTAssertEqual(career.unlockedAchievementCount, 0)
        XCTAssertEqual(Set(Achievement.allCases.map(\.rawValue)).count, Achievement.allCases.count)
        XCTAssertGreaterThanOrEqual(Achievement.allCases.count, 48)
        XCTAssertTrue(Achievement.allCases.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty && !$0.symbol.isEmpty })

        for _ in 0..<12 { XCTAssertTrue(career.simulateNextMatchDay()) }
        if (career.counters["wins"] ?? 0) > 0 { XCTAssertTrue(career.isUnlocked(.firstWin)) }
        XCTAssertEqual(career.counters["matches"], career.fixtures.filter { $0.isPlayed && $0.involves(0) }.count)

        // Marcos fabricados.
        career.transferBudget = 30_000_000
        career.stadiumLevel = 3
        career.records.longestWinStreak = 6
        career.records.biggestWinMargin = 5
        career.reputation = 92
        career.counters["invitations"] = 1
        career.counters["matches"] = 100
        career.counters["press"] = 20
        for role in StaffRole.allCases where career.staffMember(role) == nil {
            career.staff.append(StaffMember(id: 500 + role.hashValue % 100, name: "S", role: role, ability: 12, wage: 100_000))
        }
        let unlocked = career.checkAchievements()
        for expected in [Achievement.millionaire, .stadiumLevel3, .winStreak5, .bigWin5, .reputation90, .invitationAccepted, .veteran, .pressMaster, .fullStaff] {
            XCTAssertTrue(unlocked.contains(expected) || career.isUnlocked(expected), "\(expected)")
        }
        XCTAssertTrue(career.checkAchievements().isEmpty, "Cada conquista sai uma vez")
        XCTAssertTrue(career.inbox.contains { $0.title == "Conquista: Cofre cheio" })
        let season = career.achievements[Achievement.millionaire.rawValue]
        XCTAssertEqual(season, career.season)
    }

    func testMatchBasedAchievementsReadTheLastFixture() throws {
        var career = career()
        var fixture = LeagueFixture(id: 77, matchDay: 3, round: 4, competition: .cup(.quarterFinal), home: 0, away: 1)
        fixture.homeGoals = 3
        fixture.awayGoals = 3
        fixture.wentToExtraTime = true
        fixture.homePenalties = 5
        fixture.awayPenalties = 3
        fixture.events = [
            MatchEvent(minute: 10, kind: .goal, teamID: 1, text: ""), MatchEvent(minute: 20, kind: .goal, teamID: 1, text: ""),
            MatchEvent(minute: 40, kind: .goal, teamID: 0, text: ""), MatchEvent(minute: 70, kind: .goal, teamID: 0, text: ""),
            MatchEvent(minute: 85, kind: .goal, teamID: 0, text: ""), MatchEvent(minute: 95, kind: .goal, teamID: 1, text: "")
        ]
        var stats = PlayerMatchStats(playerID: career.clubRoster[0].id)
        stats.goals = 3
        stats.minutes = 90
        fixture.userStats = [stats]
        let unlocked = career.checkAchievements(fixture: fixture)
        XCTAssertTrue(unlocked.contains(.hatTrick))
        XCTAssertTrue(unlocked.contains(.shootoutWin))
        XCTAssertTrue(unlocked.contains(.comeback))
        XCTAssertFalse(unlocked.contains(.derbyWin))
        var derby = LeagueFixture(id: 78, matchDay: 3, round: 4, competition: .league(.serieA), home: 0, away: 6)
        derby.homeGoals = 2
        derby.awayGoals = 0
        XCTAssertTrue(career.checkAchievements(fixture: derby).contains(.derbyWin))

        // Mata-gigantes: clube da Série B eliminando um da Série A.
        var small = self.career(club: 10)
        var cup = LeagueFixture(id: 79, matchDay: 6, round: 2, competition: .cup(.roundOf16), home: 10, away: 0)
        cup.homeGoals = 1
        cup.awayGoals = 0
        XCTAssertTrue(small.checkAchievements(fixture: cup).contains(.giantKiller))
    }

    func testSeasonBasedAchievementsReadHistoryAndAwards() throws {
        var career = career()
        func record(season: Int, champion: Bool, cup: Bool) -> SeasonRecord {
            var record = SeasonRecord(season: season, clubID: 0, championID: champion ? 0 : 3, position: champion ? 1 : 3, points: 40, target: 1, objectiveMet: champion,
                                      prizeMoney: 0, topScorerName: "—", topScorerTeamID: nil, topScorerGoals: 0, retiredPlayers: 0, youthPromoted: 0, wasFired: false)
            record.cupWinnerID = cup ? 0 : 5
            var awards = SeasonAwards()
            awards.bestPlayer = AwardEntry(playerID: 1, name: "A", position: .forward, teamID: 0)
            awards.coachOfTheYearClubID = champion ? 0 : 2
            record.awards = awards
            return record
        }
        career.history = [record(season: 1, champion: true, cup: true), record(season: 2, champion: true, cup: false), record(season: 3, champion: true, cup: false)]
        let unlocked = Set(career.checkAchievements(record: career.history.last))
        XCTAssertTrue(unlocked.isSuperset(of: [.leagueTitle, .cupTitle, .doubleWinner, .threePeat, .objectiveMet, .bestPlayerAward, .coachOfTheYear]))
        XCTAssertFalse(unlocked.contains(.fiveSeasons))
        career.history += [record(season: 4, champion: false, cup: false), record(season: 5, champion: false, cup: false)]
        XCTAssertTrue(career.checkAchievements().contains(.fiveSeasons))
    }

    // MARK: - Tutorial

    func testTutorialTracksStepsAndCanBeDismissed() throws {
        var career = career()
        XCTAssertTrue(career.shouldShowTutorial)
        XCTAssertEqual(career.tutorialProgress.total, 8)
        XCTAssertEqual(career.tutorialProgress.done, 0)
        career.markTutorialSeen("squad")
        career.markTutorialSeen("squad")
        XCTAssertEqual(career.tutorialSeen, ["squad"])
        XCTAssertTrue(career.tutorialSteps.first { $0.id == "lineup" }!.done)
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertTrue(career.tutorialSteps.first { $0.id == "match" }!.done)
        career.answerPress(questionID: 1, tone: .calm)
        career.pendingPress = career.makePressConference(fixture: career.latestUserFixture!)
        career.answerPress(questionID: 1, tone: .calm)
        XCTAssertTrue(career.tutorialSteps.first { $0.id == "press" }!.done)
        for key in ["dashboard", "inbox", "table", "market", "club"] { career.markTutorialSeen(key) }
        XCTAssertEqual(career.tutorialProgress.done, 8)
        XCTAssertFalse(career.shouldShowTutorial)

        var other = self.career()
        other.tutorialDismissed = true
        XCTAssertFalse(other.shouldShowTutorial)
    }

    // MARK: - Simular até a decisão

    func testSimulateUntilDecisionStopsForRequestsDerbiesAndWindows() throws {
        var career = career()
        let first = career.simulateUntilDecision(maxDays: 3)
        XCTAssertGreaterThanOrEqual(first.days, 1)
        XCTAssertLessThanOrEqual(first.days, 3)
        XCTAssertFalse(first.reason.isEmpty)
        XCTAssertEqual(career.matchDayIndex, first.days)

        // Fora da janela e sem pedidos, o limite de dias é que encerra.
        var calm = self.career(seed: 7)
        calm.matchDayIndex = 4
        let quiet = calm.simulateUntilDecision(maxDays: 2)
        XCTAssertGreaterThanOrEqual(quiet.days, 1)
        XCTAssertFalse(quiet.reason.isEmpty)

        // Pedido de atleta aparece e interrompe.
        var asking = self.career(seed: 21)
        for index in asking.players.indices where asking.players[index].teamID == 0 {
            asking.players[index].morale = 20
            asking.players[index].benchStreak = 6
        }
        let result = asking.simulateUntilDecision(maxDays: 10)
        XCTAssertGreaterThan(result.days, 0)
        XCTAssertTrue(result.reason.contains("mensagens") || result.reason.contains("janela") || result.reason.contains("Clássico") || result.reason.contains("proposta") || result.reason.contains("titulares"),
                      result.reason)
        XCTAssertLessThan(result.days, 10)

        // Último dia da janela.
        var window = self.career(seed: 5)
        for index in window.players.indices { window.players[index].morale = 60; window.players[index].benchStreak = 0 }
        window.matchDayIndex = 0
        let stop = window.simulateUntilDecision(maxDays: 5)
        XCTAssertGreaterThan(stop.days, 0)
        XCTAssertNil(window.pendingPress, "A coletiva é pulada na simulação em lote")

        // Fim da temporada e sem clube.
        var done = self.career(seed: 9)
        let long = done.simulateUntilDecision(maxDays: 100)
        XCTAssertLessThan(long.days, 100)
        done.matchDayIndex = FootballSeason.matchDaysPerSeason
        XCTAssertEqual(done.simulateUntilDecision(maxDays: 5).reason, "A temporada terminou.")
        var fired = self.career()
        fired.isFired = true
        XCTAssertEqual(fired.simulateUntilDecision().reason, "Você está sem clube.")
    }

    // MARK: - Saves

    func testModesStateSurvivesSaveAndOldSavesGetDefaults() throws {
        var career = FootballCareer.challenge(ChallengeScenario.all[1])
        career.difficulty = .hard
        career.counters["matches"] = 4
        career.achievements["firstWin"] = 1
        career.markTutorialSeen("market")
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip, career)

        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        legacy["schemaVersion"] = 8
        for key in ["difficulty", "challenge", "achievements", "counters", "tutorialSeen", "tutorialDismissed"] { legacy.removeValue(forKey: key) }
        let migrated = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(migrated.difficulty, .normal)
        XCTAssertNil(migrated.challenge)
        XCTAssertTrue(migrated.achievements.isEmpty)
        var playable = migrated
        XCTAssertTrue(playable.simulateNextMatchDay())
    }
}
