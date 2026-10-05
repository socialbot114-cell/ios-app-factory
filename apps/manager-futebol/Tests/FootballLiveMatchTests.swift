import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballLiveMatchTests: XCTestCase {
    private func template(seed: Int = 5, home: Int = 0, away: Int = 1, detailed: Bool = true) -> (FootballCareer, MatchSimulation, [Int: FootballPlayer]) {
        let career = FootballCareer(seed: seed)
        let fixture = career.fixtures.first { $0.home == home && $0.away == away && $0.competition.division != nil }
            ?? LeagueFixture(id: 9_999, matchDay: 0, round: 1, competition: .league(.serieA), home: home, away: away)
        return (career, career.makeSimulation(fixture: fixture, detailed: detailed), career.playersByID())
    }

    private func run(_ base: MatchSimulation, seed: UInt64, players: [Int: FootballPlayer],
                     tweak: ((inout MatchSimulation) -> Void)? = nil) -> MatchSimulation {
        var sim = MatchSimulation.make(fixtureID: 1, seed: seed, isCup: base.isCup, isDerby: false, detailed: base.detailed, home: base.home, away: base.away)
        tweak?(&sim)
        sim.runToEnd(players: players)
        return sim
    }

    // MARK: - Consistência do motor

    func testMinuteEngineKeepsTheMatchConsistent() throws {
        let (_, base, players) = template()
        for seed in 1...120 {
            let sim = run(base, seed: UInt64(seed) &* 104_729, players: players)
            XCTAssertEqual(sim.minute, sim.regulationEnd)
            XCTAssertTrue(sim.finished)
            for side in [MatchTeamSide.home, .away] {
                let state = sim[side]
                XCTAssertEqual(state.goals, state.scorerIDs.count)
                XCTAssertGreaterThanOrEqual(state.shots, state.shotsOnTarget)
                XCTAssertGreaterThanOrEqual(state.shotsOnTarget, state.goals)
                XCTAssertEqual(Set(state.onPitch).count, state.onPitch.count, "Ninguém joga duas vezes")
                XCTAssertTrue(Set(state.onPitch).isDisjoint(with: state.bench))
                XCTAssertLessThanOrEqual(state.onPitch.count, 11)
                XCTAssertLessThanOrEqual(state.substitutionsUsed, MatchSimulation.maxSubstitutions)
                XCTAssertLessThanOrEqual(Set(state.substitutionMinutes.filter { $0 != 45 }).count, MatchSimulation.maxSubstitutionStops + 5, "Lesões não consomem janelas")
                XCTAssertTrue(state.scorerIDs.allSatisfy { players[$0]?.position != .goalkeeper })
                XCTAssertTrue(state.matchCondition.values.allSatisfy { $0 >= 25 && $0 <= 100 })
                XCTAssertEqual(state.redCards, state.redCardIDs.count)
            }
            XCTAssertEqual(sim.momentum.count, sim.minute)
            XCTAssertEqual(sim.events.filter { $0.kind == .goal }.count, sim.home.goals + sim.away.goals)
            XCTAssertEqual(sim.events.map(\.minute), sim.events.map(\.minute).sorted(), "Eventos em ordem cronológica")
        }
    }

    func testEngineIsDeterministicAndHalfTimeIsMarked() throws {
        let (_, base, players) = template()
        let first = run(base, seed: 42, players: players)
        let second = run(base, seed: 42, players: players)
        XCTAssertEqual(first, second)
        let other = run(base, seed: 43, players: players)
        XCTAssertNotEqual(first, other)
        XCTAssertEqual(first.events.filter { $0.kind == .halfTime }.count, 1)

        // Pausar no meio, salvar e continuar dá o mesmo jogo.
        var paused = MatchSimulation.make(fixtureID: 1, seed: 42, isCup: false, isDerby: false, detailed: true, home: base.home, away: base.away)
        paused.advance(to: 37, players: players)
        let restored = try JSONDecoder().decode(MatchSimulation.self, from: JSONEncoder().encode(paused))
        XCTAssertEqual(restored, paused)
        var resumed = restored
        resumed.runToEnd(players: players)
        XCTAssertEqual(resumed, first)
    }

    func testRedCardsLeaveTheTeamWithTenAndHurtPerformance() throws {
        let (_, base, players) = template()
        var withRed = 0
        var checked = 0
        for seed in 1...300 {
            let sim = run(base, seed: UInt64(seed) &* 31, players: players)
            for side in [MatchTeamSide.home, .away] where sim[side].redCards > 0 {
                checked += 1
                XCTAssertLessThan(sim[side].onPitch.count, 11 + 0)
                XCTAssertTrue(sim.events.contains { $0.kind == .redCard && $0.teamID == sim[side].teamID })
                withRed += 1
            }
        }
        XCTAssertGreaterThan(checked, 0, "Em 300 jogos deve haver expulsões")
        XCTAssertEqual(withRed, checked)

        // Um time com 10 sofre mais: força a expulsão de um titular e compara a diferença de gols.
        var plain = 0
        var down = 0
        for seed in 1...200 {
            let normal = run(base, seed: UInt64(seed) &* 17, players: players)
            let reduced = run(base, seed: UInt64(seed) &* 17, players: players) { sim in
                let victim = sim.home.onPitch.first { players[$0]?.position == .midfielder }!
                sim.home.onPitch.removeAll { $0 == victim }
                sim.needsRecompute = true
            }
            plain += normal.home.goals - normal.away.goals
            down += reduced.home.goals - reduced.away.goals
        }
        XCTAssertLessThan(down, plain, "Jogar com um a menos reduz o saldo de gols")
    }

    func testPenaltiesAreAwardedAndConverted() throws {
        let (_, base, players) = template()
        var awarded = 0
        var scored = 0
        var matches = 0
        for seed in 1...400 {
            let sim = run(base, seed: UInt64(seed) &* 13, players: players)
            matches += 1
            awarded += sim.events.filter { $0.kind == .penaltyAwarded }.count
            scored += sim.events.filter { $0.kind == .goal && $0.text.contains("pênalti") }.count
        }
        let perMatch = Double(awarded) / Double(matches)
        XCTAssertTrue((0.1...0.5).contains(perMatch), "Pênaltis por jogo: \(perMatch)")
        XCTAssertGreaterThan(Double(scored) / Double(max(1, awarded)), 0.55)
        XCTAssertLessThan(Double(scored) / Double(max(1, awarded)), 0.92)
    }

    // MARK: - Substituições

    func testSubstitutionRulesLimitToFiveChangesInThreeWindows() throws {
        let (career, base, players) = template()
        var sim = base
        // Banco maior para exercitar o limite de cinco trocas.
        let extra = career.players(forTeam: 8).prefix(3).map(\.id)
        sim.home.bench.append(contentsOf: extra)
        for id in extra { sim.home.matchCondition[id] = 90 }
        var allPlayers = players
        for id in extra { allPlayers[id] = players[id] }

        func swap(at minute: Int) -> Bool {
            sim.advance(to: minute, players: allPlayers)
            guard let out = sim.home.onPitch.first(where: { allPlayers[$0]?.position != .goalkeeper }),
                  let incoming = sim.home.bench.first(where: { allPlayers[$0]?.position != .goalkeeper }) else { return false }
            return sim.substitute(side: .home, out: out, in: incoming, players: allPlayers)
        }
        XCTAssertTrue(swap(at: 30), "Primeira janela")
        XCTAssertTrue(swap(at: 45), "O intervalo não conta como janela")
        XCTAssertTrue(swap(at: 60), "Segunda janela")
        XCTAssertTrue(swap(at: 70), "Terceira janela")
        XCTAssertFalse(swap(at: 80), "Quarta janela é recusada")
        XCTAssertEqual(sim.home.substitutionsUsed, 4)
        // Na mesma janela do minuto 80 já não cabe; mas voltando a uma janela aberta não é possível (tempo só avança).
        XCTAssertLessThanOrEqual(Set(sim.home.substitutionMinutes.filter { $0 != 45 }).count, MatchSimulation.maxSubstitutionStops)

        // Limite de cinco trocas dentro de uma mesma janela.
        var other = base
        other.home.bench.append(contentsOf: extra)
        for id in extra { other.home.matchCondition[id] = 90 }
        other.advance(to: 50, players: allPlayers)
        var made = 0
        for _ in 0..<6 {
            guard let out = other.home.onPitch.first(where: { allPlayers[$0]?.position != .goalkeeper }),
                  let incoming = other.home.bench.first else { break }
            if other.substitute(side: .home, out: out, in: incoming, players: allPlayers) { made += 1 }
        }
        XCTAssertEqual(made, MatchSimulation.maxSubstitutions)
        XCTAssertEqual(other.home.substitutionMinutes.filter { $0 == 50 }.count, 5)
    }

    // MARK: - Táticas

    func testHighPressingRaisesFoulsAndFatigueButTimeWastingCutsShots() throws {
        let (_, base, players) = template(seed: 11)
        var calmFouls = 0, pressFouls = 0
        var calmCondition = 0.0, pressCondition = 0.0
        var normalShots = 0, wastedShots = 0
        for seed in 1...150 {
            let calm = run(base, seed: UInt64(seed) &* 5, players: players)
            let press = run(base, seed: UInt64(seed) &* 5, players: players) { sim in
                var instructions = TeamInstructions()
                instructions.pressing = .high
                sim.home.instructions = instructions
            }
            calmFouls += calm.home.fouls
            pressFouls += press.home.fouls
            calmCondition += calm.home.onPitch.compactMap { calm.home.matchCondition[$0] }.reduce(0, +)
            pressCondition += press.home.onPitch.compactMap { press.home.matchCondition[$0] }.reduce(0, +)
            normalShots += calm.home.shots
            let wasted = run(base, seed: UInt64(seed) &* 5, players: players) { sim in
                var instructions = TeamInstructions()
                instructions.timeWasting = true
                sim.home.instructions = instructions
            }
            wastedShots += wasted.home.shots
        }
        XCTAssertGreaterThan(pressFouls, calmFouls)
        XCTAssertLessThan(pressCondition, calmCondition)
        XCTAssertLessThan(wastedShots, normalShots)
    }

    func testStyleMatchupsChangeShotsInTheMinuteEngine() throws {
        let (_, base, players) = template(seed: 12)
        var counterVsPossession = 0
        var balancedVsPossession = 0
        for seed in 1...200 {
            let counter = run(base, seed: UInt64(seed) &* 3, players: players) { sim in
                sim.home.style = .counter
                sim.away.style = .possession
            }
            let balanced = run(base, seed: UInt64(seed) &* 3, players: players) { sim in
                sim.home.style = .balanced
                sim.away.style = .possession
            }
            counterVsPossession += counter.home.goals
            balancedVsPossession += balanced.home.goals
        }
        XCTAssertGreaterThan(counterVsPossession, balancedVsPossession, "Contra-ataque castiga o time de posse")
    }

    func testMarkingTheStarReducesHisShotShare() throws {
        let (_, base, players) = template(seed: 13)
        let star = try XCTUnwrap(base.away.onPitch.compactMap { players[$0] }.filter { $0.position == .forward }.max { $0.overall < $1.overall })
        var free = 0
        var marked = 0
        for seed in 1...250 {
            free += run(base, seed: UInt64(seed) &* 7, players: players).away.stats[star.id]?.shots ?? 0
            marked += run(base, seed: UInt64(seed) &* 7, players: players) { sim in sim.home.markTargetID = star.id }.away.stats[star.id]?.shots ?? 0
        }
        XCTAssertLessThan(marked, free)
    }

    func testRolesChangeTheTeamAndOnlyFitTheirPositions() {
        XCTAssertEqual(PlayerRole.options(for: .goalkeeper), [.balanced])
        XCTAssertTrue(PlayerRole.options(for: .striker).contains(.poacher))
        XCTAssertFalse(PlayerRole.options(for: .striker).contains(.destroyer))
        let (_, base, players) = template(seed: 14)
        var sim = MatchSimulation.make(fixtureID: 1, seed: 1, isCup: false, isDerby: false, detailed: true, home: base.home, away: base.away)
        sim.recomputeStrengths(players: players)
        let before = sim.home.cachedAttack
        for id in sim.home.onPitch { if let player = players[id] { sim.home.roles[id] = PlayerRole.options(for: player.detail).last } }
        sim.recomputeStrengths(players: players)
        XCTAssertNotEqual(sim.home.cachedAttack, before)
    }

    // MARK: - Dia de jogo na carreira

    func testSuspensionsFromCardsKeepPlayersOutOfTheNextMatch() throws {
        var career = FootballCareer(seed: 77)
        XCTAssertTrue(career.chooseClub(0))
        let starter = try XCTUnwrap(career.starters.first { $0.position == .defender })
        // Três amarelos acumulam e geram suspensão.
        var outcome = try careerOutcome(&career)
        outcome.yellowCardIDs = [starter.id, starter.id, starter.id]
        let index = try XCTUnwrap(career.fixtures.firstIndex { $0.involves(0) && $0.matchDay == 0 })
        career.applyOutcome(outcome, fixtureIndex: index, isUser: false)
        XCTAssertEqual(career.player(starter.id)?.discipline.suspensionGames, 1)
        XCTAssertFalse(career.player(starter.id)?.isAvailable(matchDay: 1) ?? true)
        career.repairLineup()
        XCTAssertFalse(career.startingXI.contains(starter.id))
        XCTAssertEqual(career.startingXI.count, 11)

        // Vermelho direto: duas partidas; segundo amarelo: uma.
        var redOutcome = try careerOutcome(&career)
        let other = try XCTUnwrap(career.starters.first { $0.position == .midfielder })
        redOutcome.redCardIDs = [other.id]
        career.applyOutcome(redOutcome, fixtureIndex: index, isUser: false)
        XCTAssertEqual(career.player(other.id)?.discipline.suspensionGames, 2)
        XCTAssertEqual(career.player(other.id)?.discipline.redCards, 1)

        // A suspensão só corre quando o clube joga.
        career.matchDayIndex = 0
        career.tickRecovery()
        XCTAssertEqual(career.player(other.id)?.discipline.suspensionGames, 1)
    }

    private func careerOutcome(_ career: inout FootballCareer) throws -> MatchOutcome {
        let index = try XCTUnwrap(career.fixtures.firstIndex { $0.involves(0) && $0.matchDay == 0 })
        return career.simulateFixture(at: index, players: career.playersByID())
    }

    func testPressConferenceAnswersMoveMoraleFansAndRivals() throws {
        var career = FootballCareer(seed: 31)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.simulateNextMatchDay())
        var press = try XCTUnwrap(career.pendingPress)
        XCTAssertGreaterThanOrEqual(press.questions.count, 2)
        let opponent = press.opponentID
        let fans = career.fanMood

        career.answerPress(questionID: press.questions[0].id, tone: .provocative)
        XCTAssertEqual(career.rivalMotivation[opponent], press.isDerby ? 2.5 : 1.5)
        XCTAssertNotEqual(career.fanMood, fans)
        press = try XCTUnwrap(career.pendingPress)
        XCTAssertNotNil(press.questions[0].answered)
        for question in press.questions where question.answered == nil { career.answerPress(questionID: question.id, tone: .calm) }
        XCTAssertNil(career.pendingPress)

        // O rival motivado ganha ataque no próximo confronto contra o seu clube.
        let next = career.makeSideState(teamID: opponent, rivalID: 0, isUser: false)
        XCTAssertEqual(next.attackBoost, career.rivalMotivation[opponent])

        career.pendingPress = career.makePressConference(fixture: career.latestUserFixture!)
        career.skipPress()
        XCTAssertNil(career.pendingPress)
    }

    func testFullMatchDayStoresEventsStatsAndOtherScores() throws {
        var career = FootballCareer(seed: 55)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        let live = try XCTUnwrap(career.liveMatch)
        XCTAssertEqual(live.others.count, 9, "Os outros nove jogos das duas divisões já estão decididos")
        career.liveAdvance(to: 60)
        let at60 = try XCTUnwrap(career.liveMatch)
        for other in at60.others {
            let score = at60.score(of: other, at: 60)
            XCTAssertLessThanOrEqual(score.home, other.homeGoals)
            XCTAssertLessThanOrEqual(score.away, other.awayGoals)
        }
        XCTAssertTrue(career.finishMatchDay())
        let fixture = try XCTUnwrap(career.latestUserFixture)
        XCTAssertGreaterThan(fixture.userStats.count, 11)
        XCTAssertNotNil(FootballRatings.manOfTheMatch(fixture.userStats))
        XCTAssertTrue(fixture.userStats.contains { !$0.heat.isEmpty })
        XCTAssertNotNil(fixture.homeCorners)
        XCTAssertEqual(career.fixtures.filter { $0.matchDay == 0 }.filter(\.isPlayed).count, 10)
    }

    // MARK: - Ações rápidas

    func testQuickPresetsChangeStyleAndInstructionsAndLogTheMove() throws {
        var career = FootballCareer(seed: 55)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        career.liveAdvance(to: 20)
        XCTAssertTrue(career.liveApplyPreset(.allOut))
        var side = try XCTUnwrap(career.liveMatch).userSide
        XCTAssertEqual(side.style, .attacking)
        XCTAssertEqual(side.instructions.lineHeight, .high)
        XCTAssertTrue(QuickTacticPreset.allOut.isActive(on: side))
        XCTAssertFalse(career.liveApplyPreset(.allOut), "Repetir o plano ativo não faz nada")
        XCTAssertTrue(career.liveApplyPreset(.protect))
        side = try XCTUnwrap(career.liveMatch).userSide
        XCTAssertTrue(side.instructions.timeWasting)
        XCTAssertTrue(try XCTUnwrap(career.liveMatch).events.contains { $0.kind == .tactic && $0.text.contains("segurar") })
        career.liveAdvance(to: 40)
        XCTAssertEqual(career.liveMatch?.minute, 40)
    }

    func testQuickSubstitutionsPickValidPlayersAndRespectLimits() throws {
        var career = FootballCareer(seed: 55)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        career.liveAdvance(to: 30)
        let plan = try XCTUnwrap(career.liveQuickSubstitutionPlan(.tired))
        XCTAssertEqual(plan.out.position, plan.incoming.position)
        XCTAssertTrue(career.liveQuickSubstitute(.tired))
        let side = try XCTUnwrap(career.liveMatch).userSide
        XCTAssertTrue(side.onPitch.contains(plan.incoming.id))
        XCTAssertFalse(side.onPitch.contains(plan.out.id))
        if let attack = career.liveQuickSubstitutionPlan(.offensive) {
            XCTAssertEqual(attack.incoming.position, .forward)
            XCTAssertNotEqual(attack.out.position, .forward)
        }
        for _ in 0..<10 { _ = career.liveQuickSubstitute(.tired) }
        XCTAssertLessThanOrEqual(try XCTUnwrap(career.liveMatch).substitutionsUsed, LiveMatchState.maxSubstitutions)
    }

    // MARK: - Acréscimos e narração

    func testLeagueMatchesGetStoppageTimeAndCupsDoNot() throws {
        let (_, base, players) = template()
        var sawStoppage = false
        for seed in 1...40 {
            let sim = run(base, seed: UInt64(seed) &* 7_919, players: players)
            let added = try XCTUnwrap(sim.stoppageMinutes)
            XCTAssertTrue((1...7).contains(added))
            XCTAssertEqual(sim.regulationEnd, 90 + added)
            XCTAssertEqual(sim.events.filter { $0.kind == .stoppage }.count, 1)
            for event in sim.events where event.minute > 90 {
                XCTAssertEqual(event.added, event.minute - 90)
                XCTAssertEqual(event.minuteLabel, "90+\(event.minute - 90)′")
            }
            sawStoppage = sawStoppage || sim.events.contains { $0.added != nil }
        }
        XCTAssertTrue(sawStoppage, "Algum lance deve cair nos acréscimos")

        var cup = MatchSimulation.make(fixtureID: 1, seed: 9, isCup: true, isDerby: false, detailed: true, home: base.home, away: base.away)
        cup.runToEnd(players: players)
        XCTAssertEqual(cup.stoppageMinutes, 0)
        XCTAssertEqual(cup.events.filter { $0.kind == .stoppage }.count, 0)
    }

    // MARK: - Repercussão: torcida, ingressos, camisas e reputação

    private func playedCareer(seed: Int = 55) throws -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        XCTAssertTrue(career.finishMatchDay())
        return career
    }

    func testFinishedMatchStoresImpactAndFeedsFansHypeAndShirts() throws {
        var career = FootballCareer(seed: 55)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        career.liveAdvance(minutes: 200)
        let preview = try XCTUnwrap(career.previewMatchImpact())
        XCTAssertEqual(career.clubHype, 0, "A prévia não mexe na carreira")
        XCTAssertNotNil(career.liveMatch)
        XCTAssertTrue(career.finishMatchDay())
        let impact = try XCTUnwrap(career.latestUserFixture?.impact)
        XCTAssertEqual(impact.score, preview.score)
        XCTAssertEqual(impact.hypeAfter, preview.hypeAfter)
        XCTAssertEqual(career.clubHype, impact.hypeAfter)
        XCTAssertTrue((2.5...10).contains(impact.teamGrade))
        XCTAssertFalse(impact.verdict.isEmpty)
        if impact.score > 0 {
            XCTAssertGreaterThan(impact.shirtsSold, 0)
            XCTAssertTrue(career.finance.entries.contains { $0.note.contains("camisas vendidas") })
        } else {
            XCTAssertEqual(impact.shirtRevenue, 0)
        }
    }

    func testHypeRaisesAttendanceAndShopRevenueAndCoolsDown() throws {
        var career = try playedCareer()
        let fixture = try XCTUnwrap(career.fixtures.first { $0.involves(0) && !$0.isPlayed })
        career.clubHype = 0
        let cold = career.attendance(for: fixture)
        let coldShop = career.merchRevenuePerMatchDay
        career.clubHype = 100
        XCTAssertGreaterThanOrEqual(career.attendance(for: fixture), cold)
        XCTAssertGreaterThan(career.merchRevenuePerMatchDay, coldShop)
        career.coolDownHype()
        XCTAssertEqual(career.clubHype, 98)
        career.clubHype = 1
        career.coolDownHype()
        XCTAssertEqual(career.clubHype, 0)
        XCTAssertEqual(career.hypeTitle, "Torcida fria")
    }

    func testImpactRewardsComebacksAndPunishesHumiliation() throws {
        var career = try playedCareer()
        var fixture = try XCTUnwrap(career.latestUserFixture)
        fixture.userStats = []
        let isHome = fixture.home == 0
        fixture.homeGoals = isHome ? 3 : 2
        fixture.awayGoals = isHome ? 2 : 3
        let rival = fixture.opponent(of: 0)
        fixture.events = [
            MatchEvent(minute: 10, kind: .goal, teamID: rival, text: ""), MatchEvent(minute: 20, kind: .goal, teamID: rival, text: ""),
            MatchEvent(minute: 50, kind: .goal, teamID: 0, text: ""), MatchEvent(minute: 70, kind: .goal, teamID: 0, text: ""),
            MatchEvent(minute: 89, kind: .goal, teamID: 0, text: "")
        ]
        let comeback = try XCTUnwrap(career.evaluateImpact(fixture: fixture))
        XCTAssertTrue(comeback.tags.contains("comeback"))
        XCTAssertTrue(comeback.tags.contains("lateWinner"))
        XCTAssertGreaterThan(comeback.score, 60)
        XCTAssertGreaterThanOrEqual(comeback.reputationChange, 1)
        XCTAssertGreaterThan(comeback.shirtsSold, 0)

        fixture.homeGoals = isHome ? 0 : 4
        fixture.awayGoals = isHome ? 4 : 0
        fixture.events = []
        let disaster = try XCTUnwrap(career.evaluateImpact(fixture: fixture))
        XCTAssertLessThan(disaster.score, 0)
        XCTAssertTrue(disaster.tags.contains("humiliation"))
        XCTAssertEqual(disaster.shirtsSold, 0)
        XCTAssertLessThan(disaster.hypeChange, 0)

        career.clubHype = 50
        let index = try XCTUnwrap(career.fixtures.firstIndex { $0.id == fixture.id })
        let before = career.counters["comebacks"] ?? 0
        let reputation = career.reputation
        career.applyImpact(comeback, fixtureIndex: index)
        XCTAssertEqual(career.counters["comebacks"], before + 1)
        XCTAssertEqual(career.clubHype, comeback.hypeAfter)
        XCTAssertEqual(career.reputation, min(100, reputation + comeback.reputationChange))
        XCTAssertEqual(career.fixtures[index].impact, comeback)
    }

    func testCareerRoundTripKeepsHypeAndImpact() throws {
        var career = try playedCareer()
        career.clubHype = 64
        let data = try JSONEncoder().encode(career)
        let loaded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertEqual(loaded.clubHype, 64)
        XCTAssertEqual(loaded.latestUserFixture?.impact, career.latestUserFixture?.impact)
    }

    func testPressConferenceAsksAboutWhatHappenedAndTopicsChangeOutcomes() throws {
        var career = try playedCareer()
        var fixture = try XCTUnwrap(career.latestUserFixture)
        let isHome = fixture.home == 0
        let rival = fixture.opponent(of: 0)
        fixture.homeGoals = isHome ? 3 : 2
        fixture.awayGoals = isHome ? 2 : 3
        fixture.events = [
            MatchEvent(minute: 10, kind: .goal, teamID: rival, text: ""), MatchEvent(minute: 20, kind: .goal, teamID: rival, text: ""),
            MatchEvent(minute: 50, kind: .goal, teamID: 0, text: ""), MatchEvent(minute: 70, kind: .goal, teamID: 0, text: ""),
            MatchEvent(minute: 88, kind: .goal, teamID: 0, text: "")
        ]
        fixture.impact = career.evaluateImpact(fixture: fixture)
        let press = try XCTUnwrap(career.makePressConference(fixture: fixture))
        XCTAssertGreaterThanOrEqual(press.questions.count, 3)
        XCTAssertEqual(press.questions.map(\.id), Array(1...press.questions.count))
        XCTAssertTrue(press.questions.contains { $0.topic == .comeback })

        career.pendingPress = press
        career.boardConfidence = 50
        career.clubHype = 10
        let comebackQuestion = try XCTUnwrap(press.questions.first { $0.topic == .comeback })
        career.answerPress(questionID: comebackQuestion.id, tone: .confident)
        XCTAssertGreaterThan(career.clubHype, 10, "Resposta confiante alimenta o embalo")

        let boardBefore = career.boardConfidence
        career.applyPressTopicEffect(topic: .board, tone: .calm, result: .win, playerID: nil)
        XCTAssertGreaterThan(career.boardConfidence, boardBefore)
        career.applyPressTopicEffect(topic: .board, tone: .provocative, result: .win, playerID: nil)
        XCTAssertEqual(career.boardConfidence, boardBefore)
        XCTAssertFalse(PressTopic.star.hint(for: .calm).isEmpty)
    }
}
