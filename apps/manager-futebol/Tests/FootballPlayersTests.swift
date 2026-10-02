import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballPlayersTests: XCTestCase {
    // MARK: - Atributos

    func testGeneratedAttributesMatchTheOverallAndStayInRange() {
        let career = FootballCareer(seed: 7)
        for player in career.players {
            XCTAssertEqual(player.attributes.overall(for: player.position), player.overall, "\(player.name) \(player.position)")
            for kind in AttributeKind.allCases {
                XCTAssertTrue((1...20).contains(player.attributes[kind]))
            }
            XCTAssertEqual(player.detail.group, player.position)
            XCTAssertLessThanOrEqual(player.traits.count, 2)
        }
        let keepers = career.players.filter { $0.position == .goalkeeper }
        XCTAssertTrue(keepers.allSatisfy { $0.attributes[.reflexes] > $0.attributes[.finishing] })
        let strikers = career.players.filter { $0.detail == .striker }
        XCTAssertTrue(strikers.allSatisfy { $0.attributes[.finishing] >= $0.attributes[.tackling] })
    }

    func testTrainingRaisesAttributesAndKeepsTheOverallConsistent() throws {
        var career = FootballCareer(seed: 26)
        XCTAssertTrue(career.chooseClub(0))
        career.setTrainingFocus(.attacking)
        career.setTrainingIntensity(.intense)
        let before = Dictionary(uniqueKeysWithValues: career.clubRoster.map { ($0.id, $0) })
        for day in 0..<8 { career.applyWeeklyTraining(for: day) }
        var grew = 0
        for player in career.clubRoster {
            let old = try XCTUnwrap(before[player.id])
            XCTAssertEqual(player.attributes.overall(for: player.position), player.overall)
            XCTAssertLessThanOrEqual(player.overall, player.potential)
            if player.attributes != old.attributes { grew += 1 }
            for kind in AttributeKind.allCases where player.attributes[kind] < old.attributes[kind] {
                XCTFail("Treino não deve reduzir \(kind)")
            }
        }
        XCTAssertGreaterThan(grew, 0)
    }

    func testIndividualTrainingFocusesTheChosenAttribute() throws {
        var career = FootballCareer(seed: 3)
        XCTAssertTrue(career.chooseClub(2))
        career.setTrainingFocus(.recovery)
        let target = try XCTUnwrap(career.clubRoster.first { $0.position == .forward && $0.overall < $0.potential - 2 })
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == target.id })
        career.players[index].individualFocus = .finishing
        let before = target.attributes[.finishing]
        for day in 0..<30 { career.applyWeeklyTraining(for: day) }
        XCTAssertGreaterThan(career.players[index].attributes[.finishing], before)
    }

    func testPlayersWithDifferentAttributesPlayDifferently() {
        let career = FootballCareer(seed: 5)
        var lineup = career.lineup(for: 0).compactMap { career.player($0) }
        let formation = career.formation(for: 0)
        let side = MatchSide(teamID: 0, lineup: lineup, formation: formation, style: .balanced, opponentStyle: .balanced, isHome: true)
        // Troca os atacantes por finalizadores excelentes: o setor de ataque tem que subir.
        for index in lineup.indices where lineup[index].position == .forward {
            lineup[index].attributes[.finishing] = 20
            lineup[index].attributes[.dribbling] = 18
        }
        let boosted = MatchSide(teamID: 0, lineup: lineup, formation: formation, style: .balanced, opponentStyle: .balanced, isHome: true)
        XCTAssertGreaterThan(boosted.attackSector, side.attackSector)
    }

    func testStrikerWithBetterFinishingScoresMoreOften() throws {
        let career = FootballCareer(seed: 99)
        var players = career.playersByID()
        let fixture = try XCTUnwrap(career.fixtures.first { $0.involves(0) && $0.competition.division != nil })
        let template = career.makeSimulation(fixture: fixture, detailed: false)
        let strikers = template.home.onPitch.compactMap { players[$0] }.filter { $0.position == .forward }
        let sharp = try XCTUnwrap(strikers.first)
        let blunt = try XCTUnwrap(strikers.last)
        XCTAssertNotEqual(sharp.id, blunt.id)
        for id in [sharp.id, blunt.id] {
            players[id]?.attributes[.finishing] = id == sharp.id ? 20 : 5
            players[id]?.traits = []
            players[id]?.morale = 60
        }
        var sharpGoals = 0
        var bluntGoals = 0
        for seed in 1...250 {
            var sim = MatchSimulation.make(fixtureID: 1, seed: UInt64(seed) &* 7_777, isCup: false, isDerby: false, detailed: false,
                                           home: template.home, away: template.away)
            sim.runToEnd(players: players)
            sharpGoals += sim.home.scorerIDs.filter { $0 == sharp.id }.count
            bluntGoals += sim.home.scorerIDs.filter { $0 == blunt.id }.count
        }
        XCTAssertGreaterThan(sharpGoals, Int(Double(bluntGoals) * 1.3), "Finalização 20 deve marcar bem mais que finalização 5 (\(sharpGoals) × \(bluntGoals))")
    }

    // MARK: - Posições

    func testLearnedPositionsFillSlotsAsAdaptedAndImprovisedCostsMore() throws {
        var career = FootballCareer(seed: 8)
        XCTAssertTrue(career.chooseClub(0))
        let formation = FootballFormation.fourFourTwo
        let natural = FootballSeason.assignSlots(lineup: career.starters, formation: formation)
        XCTAssertTrue(natural.allSatisfy { $0.fit == .natural })
        let naturalRating = FootballSeason.rating(of: career.starters, formation: formation)

        // Troca os atacantes por dois meias com o mesmo geral: improvisados.
        var lineup = career.starters.filter { $0.position != .forward }
        for offset in 0..<2 {
            lineup.append(FootballPlayer(id: 9_000 + offset, name: "Meia \(offset)", position: .midfielder, age: 25, overall: 76,
                                         potential: 76, condition: 100, marketValue: 1, teamID: 0))
        }
        let improvised = FootballSeason.assignSlots(lineup: lineup, formation: formation)
        XCTAssertEqual(improvised.filter { $0.slot == .forward && $0.fit == .improvised }.count, 2)
        let improvisedRating = FootballSeason.rating(of: lineup, formation: formation)

        // Com a posição aprendida, passam a ser adaptados e a penalidade cai.
        for index in lineup.indices where lineup[index].id >= 9_000 { lineup[index].learnedPositions = [.forward] }
        let adapted = FootballSeason.assignSlots(lineup: lineup, formation: formation)
        XCTAssertEqual(adapted.filter { $0.slot == .forward && $0.fit == .adapted }.count, 2)
        XCTAssertGreaterThan(FootballSeason.rating(of: lineup, formation: formation), improvisedRating)
        XCTAssertGreaterThan(naturalRating, 0)
        XCTAssertEqual(FootballSeason.outOfPositionCount(lineup: lineup, formation: formation), 0)
    }

    // MARK: - Contratos e salários

    func testWagesAreChargedEveryMatchDayThroughTheFinanceBook() throws {
        var career = FootballCareer(seed: 13)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertGreaterThan(career.wageBill, 0)
        XCTAssertGreaterThan(career.wageCap, career.wageBill)
        let cash = career.transferBudget
        XCTAssertTrue(career.simulateNextMatchDay())
        let entries = career.finance.entries(season: 1)
        let wages = entries.filter { $0.category == .wages }
        XCTAssertEqual(wages.count, 1)
        XCTAssertEqual(wages[0].amount, -(career.wageBill / FootballSeason.matchDaysPerSeason))
        XCTAssertEqual(career.transferBudget, cash + entries.reduce(0) { $0 + $1.amount })
        XCTAssertTrue(entries.contains { $0.category == .tv })
    }

    func testRenewalNegotiationAcceptsCountersAndRefuses() throws {
        var career = FootballCareer(seed: 21)
        XCTAssertTrue(career.chooseClub(0))
        let player = try XCTUnwrap(career.clubRoster.first)
        let ask = try XCTUnwrap(career.contractAsk(playerID: player.id))
        XCTAssertGreaterThan(ask.years, 0)

        guard case .refused = career.offerRenewal(playerID: player.id, wage: ask.wage / 2, years: 2, status: ask.status) else {
            return XCTFail("Uma oferta muito baixa deve ser recusada")
        }
        let counter = career.offerRenewal(playerID: player.id, wage: Int(Double(ask.wage) * 0.92 / 5_000) * 5_000, years: 2, status: ask.status)
        guard case .counter(let wage) = counter else { return XCTFail("Oferta próxima do pedido gera contraproposta: \(counter)") }
        XCTAssertGreaterThan(wage, 0)

        let before = career.player(player.id)?.contract.endSeason ?? 0
        XCTAssertEqual(career.offerRenewal(playerID: player.id, wage: ask.wage, years: ask.years, status: ask.status), .accepted)
        let renewed = try XCTUnwrap(career.player(player.id))
        XCTAssertEqual(renewed.contract.wage, ask.wage)
        XCTAssertEqual(renewed.contract.endSeason, max(before, career.season) + ask.years)

        career.wageCap = career.wageBill
        XCTAssertEqual(career.offerRenewal(playerID: player.id, wage: ask.wage * 3, years: 2, status: .key), .overWageCap)
    }

    func testWageCapBlocksSigningsAndExpiredContractsBecomeFreeAgents() throws {
        var career = FootballCareer(seed: 31)
        XCTAssertTrue(career.chooseClub(10))
        let freeAgent = try XCTUnwrap(career.marketPlayers.first)
        career.transferBudget = 100_000_000
        let seller = try XCTUnwrap(career.clubRoster.first { career.canSell(playerID: $0.id) })
        XCTAssertTrue(career.sellPlayer(playerID: seller.id))
        career.wageCap = career.wageBill
        XCTAssertFalse(career.canSign(playerID: freeAgent.id))
        XCTAssertNotNil(career.signBlockReason(playerID: freeAgent.id))
        career.wageCap = career.wageBill + freeAgent.contract.wage + 1
        XCTAssertTrue(career.canSign(playerID: freeAgent.id))

        // Contratos de quem não renovou terminam com a temporada.
        for index in career.players.indices where career.players[index].teamID == 10 { career.players[index].contract.endSeason = 1 }
        let squadIDs = career.clubRoster.map(\.id)
        for _ in 0..<FootballSeason.matchDaysPerSeason { XCTAssertTrue(career.simulateNextMatchDay()) }
        XCTAssertNotNil(career.startNextSeason())
        let stillThere = career.clubRoster.filter { squadIDs.contains($0.id) }
        XCTAssertTrue(stillThere.isEmpty || stillThere.allSatisfy { $0.contract.endSeason >= career.season }, "Quem não renovou sai do clube")
        XCTAssertGreaterThanOrEqual(career.clubRoster.count, 14, "O clube contrata o mínimo para continuar jogando")
        XCTAssertTrue(career.finance.summaries.contains { $0.season == 1 })
        for team in FootballSeason.teams where team.id != 10 {
            XCTAssertTrue(career.players(forTeam: team.id).allSatisfy { $0.contract.endSeason >= career.season })
        }
    }

    // MARK: - Moral, notas e pedidos

    func testMatchRatingsAreBoundedAndReflectGoalsAndResults() throws {
        var career = FootballCareer(seed: 17)
        XCTAssertTrue(career.chooseClub(0))
        for _ in 0..<6 { XCTAssertTrue(career.simulateNextMatchDay()) }
        let fixtures = career.fixtures.filter { $0.isPlayed && $0.involves(0) && !$0.userStats.isEmpty }
        XCTAssertFalse(fixtures.isEmpty)
        var scorerRatings: [Double] = []
        var otherRatings: [Double] = []
        for fixture in fixtures {
            XCTAssertNotNil(FootballRatings.manOfTheMatch(fixture.userStats))
            for stat in fixture.userStats where stat.minutes > 0 {
                XCTAssertTrue((4.0...10.0).contains(stat.rating), "Nota fora da faixa: \(stat.rating)")
                if stat.goals > 0 { scorerRatings.append(stat.rating) } else { otherRatings.append(stat.rating) }
            }
        }
        if !scorerRatings.isEmpty {
            XCTAssertGreaterThan(scorerRatings.reduce(0, +) / Double(scorerRatings.count), otherRatings.reduce(0, +) / Double(otherRatings.count))
        }
        let played = career.clubRoster.filter { $0.form.seasonGames > 0 }
        XCTAssertFalse(played.isEmpty)
        XCTAssertTrue(played.allSatisfy { $0.form.recent.count <= 5 && $0.form.seasonAverage != nil })
    }

    func testBenchedStarsLoseMoraleAndAskToPlayThenPromisesAreTracked() throws {
        var career = FootballCareer(seed: 41)
        XCTAssertTrue(career.chooseClub(0))
        let benched = try XCTUnwrap(career.starters.max { $0.overall < $1.overall })
        // Mantém o melhor atleta fora do onze durante vários jogos.
        for _ in 0..<3 {
            career.startingXI.removeAll { $0 == benched.id }
            if let replacement = career.clubRoster.first(where: { $0.position == benched.position && !career.startingXI.contains($0.id) && $0.id != benched.id }) {
                career.startingXI.append(replacement.id)
            }
            XCTAssertTrue(career.beginMatchDay())
            XCTAssertTrue(career.finishMatchDay())
        }
        let after = try XCTUnwrap(career.player(benched.id))
        XCTAssertLessThan(after.morale, benched.morale)
        XCTAssertEqual(after.benchStreak, 3)

        // Força o cenário de pedido e confere a promessa.
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == benched.id })
        career.players[index].benchStreak = 5
        career.players[index].morale = 30
        career.generatePlayerRequests()
        XCTAssertTrue(career.hasOpenMessage(.playerPlayingTime, playerID: benched.id))
        XCTAssertGreaterThan(career.pendingRequestCount, 0)
        XCTAssertTrue(career.promiseStarts(playerID: benched.id, starts: 2))
        XCTAssertEqual(career.promises.count, 1)
        XCTAssertFalse(career.hasOpenMessage(.playerPlayingTime, playerID: benched.id))
        XCTAssertGreaterThan(career.player(benched.id)?.morale ?? 0, 30)

        // Cumprir a promessa dá moral; quebrar custa mais.
        career.evaluatePromises(started: [benched.id])
        career.evaluatePromises(started: [benched.id])
        XCTAssertTrue(career.promises.isEmpty)
        let fulfilled = career.player(benched.id)?.morale ?? 0
        XCTAssertGreaterThan(fulfilled, 40)

        XCTAssertTrue(career.promiseStarts(playerID: benched.id, starts: 3))
        career.matchDayIndex += 20
        career.evaluatePromises(started: [])
        XCTAssertTrue(career.promises.isEmpty)
        XCTAssertLessThan(career.player(benched.id)?.morale ?? 100, fulfilled)
    }

    func testMoraleChangesTheEffectiveStrength() {
        var player = FootballPlayer(id: 1, name: "A", position: .midfielder, age: 25, overall: 80, potential: 80, condition: 100, marketValue: 1, teamID: 0)
        player.morale = 100
        let happy = player.effectiveOverall
        player.morale = 0
        let furious = player.effectiveOverall
        XCTAssertGreaterThan(happy, furious)
        XCTAssertEqual(happy / furious, 1.04 / 0.96, accuracy: 0.001)
        XCTAssertEqual(MoraleLevel(value: 10), .furious)
        XCTAssertEqual(MoraleLevel(value: 90), .excellent)
    }

    // MARK: - Saves

    func testSaveRoundTripKeepsPlayersAndMigratesV3Saves() throws {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(2))
        XCTAssertTrue(career.simulateNextMatchDay())
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip, career)

        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        legacy["schemaVersion"] = 3
        for key in ["finance", "inbox", "nextInboxID", "promises", "nextPromiseID", "wageCap"] { legacy.removeValue(forKey: key) }
        if let players = legacy["players"] as? [[String: Any]] {
            legacy["players"] = players.map { player in
                var copy = player
                for key in ["attributes", "traits", "morale", "contract", "form", "discipline", "region", "detail", "benchStreak"] { copy.removeValue(forKey: key) }
                return copy
            }
        }
        if let fixtures = legacy["fixtures"] as? [[String: Any]] {
            legacy["fixtures"] = fixtures.map { fixture in
                var copy = fixture
                copy.removeValue(forKey: "userStats")
                return copy
            }
        }
        let migrated = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(migrated.players.count, career.players.count)
        for player in migrated.players {
            XCTAssertEqual(player.attributes.overall(for: player.position), player.overall)
            if player.teamID != nil { XCTAssertGreaterThan(player.contract.endSeason, 0) }
        }
        XCTAssertGreaterThan(migrated.wageCap, migrated.wageBill)
        var playable = migrated
        XCTAssertTrue(playable.simulateNextMatchDay())
    }
}
