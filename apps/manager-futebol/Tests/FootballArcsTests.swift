import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballArcsTests: XCTestCase {
    private func makeCareer() -> FootballCareer {
        var career = FootballCareer(seed: 41)
        XCTAssertTrue(career.chooseClub(0))
        career.matchDayIndex = 6
        return career
    }

    private func star(_ career: FootballCareer) throws -> FootballPlayer {
        try XCTUnwrap(career.clubRoster.max { $0.overall < $1.overall })
    }

    func testPilotArcHasOriginParticipantsReliabilityDeadlineAndChain() throws {
        var career = makeCareer()
        let athlete = try star(career)
        let arc = try XCTUnwrap(career.openRumorArc(playerID: athlete.id, truth: true))
        XCTAssertEqual(arc.stage, .start)
        XCTAssertEqual(arc.reliability, .rumor)
        XCTAssertTrue(arc.participants.contains { $0.contains(athlete.name) })
        XCTAssertGreaterThanOrEqual(arc.participants.count, 4)
        XCTAssertFalse(arc.origin.isEmpty)
        XCTAssertEqual(arc.deadlineWorldDay, career.worldDay + FootballCareer.arcLifetimeDays)
        XCTAssertEqual(career.arcChain(arc.id).count, 1)
        // Chega a Mensagens e à Chuteira com o mesmo ID de origem, como boato (autor torcedor).
        XCTAssertTrue(career.inbox.contains { $0.sourceFactID == "arc-\(arc.id)-open" })
        XCTAssertEqual(career.world.social.posts.first { $0.sourceFactID == "arc-\(arc.id)-open" }?.author, .fan)
        let commitmentID = try XCTUnwrap(arc.commitmentID)
        XCTAssertTrue(career.agenda.contains { $0.id == "commitment-\(commitmentID)" }, "O prazo aparece na agenda")
    }

    func testUpdateArrivesAndTruthfulRumorBecomesConfirmed() throws {
        var career = makeCareer()
        let athlete = try star(career)
        let truthful = try XCTUnwrap(career.openRumorArc(playerID: athlete.id, truth: true))
        career.matchDayIndex += FootballCareer.arcUpdateDay
        career.advanceArcs()
        let updated = try XCTUnwrap(career.arc(truthful.id))
        XCTAssertEqual(updated.stage, .decision)
        XCTAssertEqual(updated.reliability, .confirmed)
        XCTAssertEqual(career.arcChain(truthful.id).last?.kind, .update)

        var other = makeCareer()
        let rumor = try XCTUnwrap(other.openRumorArc(playerID: athlete.id, truth: false))
        other.matchDayIndex += FootballCareer.arcUpdateDay
        other.advanceArcs()
        XCTAssertEqual(other.arc(rumor.id)?.reliability, .rumor, "Boato falso não vira confirmado")
        XCTAssertEqual(other.arc(rumor.id)?.stage, .decision)
        // Repetir não muda nada.
        let before = other.arc(rumor.id)
        other.advanceArcs()
        XCTAssertEqual(other.arc(rumor.id), before)
    }

    func testDecisionsHaveDifferentOutcomesDependingOnTheHiddenTruth() throws {
        let athlete = try star(makeCareer())
        // Desmentir: derruba boato falso, queima credibilidade em boato verdadeiro.
        var falseCase = makeCareer()
        var arc = try XCTUnwrap(falseCase.openRumorArc(playerID: athlete.id, truth: false))
        let mood = falseCase.fanMood
        XCTAssertTrue(falseCase.decideArc(arc.id, .deny))
        XCTAssertEqual(falseCase.fanMood, min(100, mood + 2))
        XCTAssertFalse(falseCase.decideArc(arc.id, .talk), "Decide uma vez só")

        var trueCase = makeCareer()
        arc = try XCTUnwrap(trueCase.openRumorArc(playerID: athlete.id, truth: true))
        let reputation = trueCase.reputation
        let moodTrue = trueCase.fanMood
        XCTAssertTrue(trueCase.decideArc(arc.id, .deny))
        XCTAssertEqual(trueCase.fanMood, max(0, moodTrue - 2))
        XCTAssertEqual(trueCase.reputation, max(0, reputation - 1))

        // Conversar: ajuda mais quando o boato é verdadeiro.
        var talk = makeCareer()
        arc = try XCTUnwrap(talk.openRumorArc(playerID: athlete.id, truth: true))
        let morale = talk.player(athlete.id)?.morale ?? 0
        XCTAssertTrue(talk.decideArc(arc.id, .talk))
        XCTAssertEqual(talk.player(athlete.id)?.morale, min(100, morale + 8))
        XCTAssertTrue(talk.memories(of: athlete.id).contains { $0.kind == .meetingHeld })
        XCTAssertEqual(talk.arc(arc.id)?.stage, .ended)
        XCTAssertTrue(talk.arcChain(arc.id).contains { $0.kind == .decision })
        XCTAssertEqual(talk.arcChain(arc.id).last?.kind, .outcome)
        XCTAssertEqual(talk.commitments.first { $0.id == arc.commitmentID }?.state, .fulfilled)
    }

    func testOmissionIsRecordedWithConsequenceWhenTheDeadlinePasses() throws {
        var career = makeCareer()
        let athlete = try star(career)
        let arc = try XCTUnwrap(career.openRumorArc(playerID: athlete.id, truth: true))
        career.matchDayIndex += FootballCareer.arcLifetimeDays
        career.processDueItems()
        let ended = try XCTUnwrap(career.arc(arc.id))
        XCTAssertEqual(ended.stage, .ended)
        XCTAssertEqual(ended.choice, .ignore)
        XCTAssertTrue(ended.steps.contains { $0.kind == .omission })
        XCTAssertTrue(career.hasOpenMessage(.playerWantsOut, playerID: athlete.id), "Omissão num boato verdadeiro: o atleta pede para sair")
        XCTAssertEqual(career.commitments.first { $0.id == arc.commitmentID }?.state, .expired)
        XCTAssertNotNil(career.fact("arc-\(arc.id)-closed"))
        let count = career.inbox.count
        career.processDueItems()
        XCTAssertEqual(career.inbox.count, count, "O desfecho não se repete")

        // Boato falso: omissão custa pouco e o boato some.
        var quiet = makeCareer()
        let rumor = try XCTUnwrap(quiet.openRumorArc(playerID: athlete.id, truth: false))
        let mood = quiet.fanMood
        quiet.matchDayIndex += FootballCareer.arcLifetimeDays
        quiet.processDueItems()
        XCTAssertEqual(quiet.fanMood, max(0, mood - 1))
        XCTAssertFalse(quiet.hasOpenMessage(.playerWantsOut, playerID: athlete.id))
        XCTAssertTrue(quiet.arc(rumor.id)?.outcome?.contains("esvazia") ?? false)
    }

    func testAskingForInfoAndDelegatingAreOncePerArcAndDependOnTheAgent() throws {
        var career = makeCareer()
        let athlete = try star(career)
        let arc = try XCTUnwrap(career.openRumorArc(playerID: athlete.id, truth: true))
        XCTAssertNotNil(career.askArcInfo(arc.id))
        XCTAssertNil(career.askArcInfo(arc.id), "Pedir informação é uma vez por arco")
        XCTAssertEqual(career.arcChain(arc.id).filter { $0.kind == .info }.count, 1)
        XCTAssertTrue(career.arcChain(arc.id).last?.text.contains("não confirmação") ?? false, "A leitura do empresário não vira fato")

        // Delegar: sem relação, não adianta; com relação boa, ajuda.
        var weak = makeCareer()
        let weakArc = try XCTUnwrap(weak.openRumorArc(playerID: athlete.id, truth: true))
        let index = try XCTUnwrap(weak.world.contacts.contacts.firstIndex { $0.role == .agent })
        weak.world.contacts.contacts[index].relationship = 10
        let moraleWeak = weak.player(athlete.id)?.morale ?? 0
        XCTAssertTrue(weak.decideArc(weakArc.id, .delegate))
        XCTAssertEqual(weak.player(athlete.id)?.morale, moraleWeak)

        var strong = makeCareer()
        let strongArc = try XCTUnwrap(strong.openRumorArc(playerID: athlete.id, truth: true))
        let strongIndex = try XCTUnwrap(strong.world.contacts.contacts.firstIndex { $0.role == .agent })
        strong.world.contacts.contacts[strongIndex].relationship = 80
        let moraleStrong = strong.player(athlete.id)?.morale ?? 0
        XCTAssertTrue(strong.decideArc(strongArc.id, .delegate))
        XCTAssertEqual(strong.player(athlete.id)?.morale, min(100, moraleStrong + 4))
        XCTAssertTrue(strong.arcChain(strongArc.id).contains { $0.kind == .delegated })
    }

    func testArcsStartDeterministicallyAndAreClosedWhenTheAthleteLeaves() throws {
        var first = makeCareer()
        let athlete = try star(first)
        let index = try XCTUnwrap(first.players.firstIndex { $0.id == athlete.id })
        first.players[index].morale = 30
        var started: [Int] = []
        for day in 4..<24 {
            first.matchDayIndex = day
            if first.maybeStartRumorArc() != nil { started.append(day) }
        }
        XCTAssertFalse(started.isEmpty, "Um craque desmotivado atrai um boato")
        XCTAssertEqual(first.openArcs.count, 1, "Um arco por vez")

        var second = makeCareer()
        let secondIndex = try XCTUnwrap(second.players.firstIndex { $0.id == athlete.id })
        second.players[secondIndex].morale = 30
        var again: [Int] = []
        for day in 4..<24 {
            second.matchDayIndex = day
            if second.maybeStartRumorArc() != nil { again.append(day) }
        }
        XCTAssertEqual(started, again, "Mesmo estado, mesmo sorteio")

        var leaving = makeCareer()
        let arc = try XCTUnwrap(leaving.openRumorArc(playerID: athlete.id, truth: true))
        let leaver = try XCTUnwrap(leaving.players.firstIndex { $0.id == athlete.id })
        leaving.players[leaver].teamID = 5
        leaving.processDueItems()
        XCTAssertEqual(leaving.arc(arc.id)?.stage, .ended)
        XCTAssertEqual(leaving.commitments.first { $0.id == arc.commitmentID }?.state, .cancelled)
    }

    func testArcsSurviveSaveAndOldSavesHaveNone() throws {
        var career = makeCareer()
        let athlete = try star(career)
        let arc = try XCTUnwrap(career.openRumorArc(playerID: athlete.id, truth: false))
        let data = try JSONEncoder().encode(career)
        let loaded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertEqual(loaded.arcs, career.arcs)
        XCTAssertEqual(loaded.nextArcID, career.nextArcID)
        XCTAssertEqual(loaded.arcs(involving: athlete.id).map(\.id), [arc.id])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["arcs"] = nil
        object["nextArcID"] = nil
        let old = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(old.arcs.isEmpty)
        XCTAssertEqual(old.nextArcID, 1)
    }
}
