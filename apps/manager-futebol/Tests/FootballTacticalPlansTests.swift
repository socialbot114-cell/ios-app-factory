import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballTacticalPlansTests: XCTestCase {
    private func makeCareer() -> FootballCareer {
        var career = FootballCareer(seed: 55)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    func testSavingAndApplyingPlansSwitchesEverythingAndKeepsThePlansApart() throws {
        var career = makeCareer()
        XCTAssertTrue(career.setFormation(.fourFourTwo))
        career.setPlayStyle(.defensive)
        career.teamInstructions.pressing = .low
        let planA = try XCTUnwrap(career.saveTacticalPlan(.a))
        XCTAssertTrue(career.setFormation(.fourThreeThree))
        career.setPlayStyle(.attacking)
        career.teamInstructions.pressing = .high
        career.teamInstructions.tempo = .high
        career.autoSelectLineup()
        let planB = try XCTUnwrap(career.saveTacticalPlan(.b))
        XCTAssertNotEqual(planA, planB)
        XCTAssertEqual(career.tacticalPlans.count, 2)

        let report = career.applyTacticalPlan(.a)
        XCTAssertTrue(report.applied)
        XCTAssertEqual(career.formation, .fourFourTwo)
        XCTAssertEqual(career.playStyle, .defensive)
        XCTAssertEqual(career.teamInstructions.pressing, .low)
        XCTAssertEqual(career.startingXI.count, 11)
        XCTAssertEqual(Set(career.startingXI).count, 11)
        XCTAssertTrue(career.applyTacticalPlan(.b).applied)
        XCTAssertEqual(career.formation, .fourThreeThree)
        XCTAssertEqual(career.teamInstructions.tempo, .high)

        // Salvar de novo substitui só aquele plano.
        career.setPlayStyle(.counter)
        career.saveTacticalPlan(.b)
        XCTAssertEqual(career.tacticalPlan(.b)?.style, .counter)
        XCTAssertEqual(career.tacticalPlan(.a), planA)
        XCTAssertEqual(career.tacticalPlans.count, 2)
    }

    func testUnavailableStartersAreReplacedAndReported() throws {
        var career = makeCareer()
        let plan = try XCTUnwrap(career.saveTacticalPlan(.a))
        let hurtID = try XCTUnwrap(plan.lineup.first { career.player($0)?.position != .goalkeeper })
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == hurtID })
        career.players[index].injuryRounds = 3
        XCTAssertEqual(career.unavailableStarters(in: plan), [hurtID])
        let report = career.applyTacticalPlan(.a)
        XCTAssertTrue(report.applied)
        XCTAssertEqual(report.replaced, [hurtID])
        XCTAssertFalse(career.startingXI.contains(hurtID))
        XCTAssertEqual(career.startingXI.count, 11)
        XCTAssertTrue(report.message.contains("substituídos"))
        XCTAssertTrue(career.compareTacticalPlans().first?.contains("Salve os dois") ?? false)
    }

    func testPlansCompareOnVerifiableFactsOnly() throws {
        var career = makeCareer()
        career.setPlayStyle(.defensive)
        career.teamInstructions = TeamInstructions()
        career.saveTacticalPlan(.a)
        career.setPlayStyle(.attacking)
        career.teamInstructions.lineHeight = .high
        career.saveTacticalPlan(.b)
        let lines = career.compareTacticalPlans()
        XCTAssertTrue(lines.contains { $0.hasPrefix("Estilo: Defensivo × Ofensivo") })
        XCTAssertTrue(lines.contains { $0.hasPrefix("Instruções: ataque") && $0.contains("desgaste") })
        XCTAssertTrue(lines.contains { $0.hasPrefix("Titulares em comum") })
    }

    func testLiveSwitchChangesTacticsButNotTheLineup() throws {
        var career = makeCareer()
        career.setPlayStyle(.defensive)
        career.saveTacticalPlan(.a)
        career.setPlayStyle(.attacking)
        career.teamInstructions.tempo = .high
        career.saveTacticalPlan(.b)
        XCTAssertTrue(career.beginMatchDay())
        XCTAssertFalse(career.applyTacticalPlan(.a).applied, "Antes do jogo só fora da partida")
        XCTAssertFalse(career.saveTacticalPlan(.a) != nil, "Não salva plano no meio da partida")
        career.liveAdvance(to: 20)
        let lineupBefore = try XCTUnwrap(career.liveMatch).userSide.onPitch
        let report = career.liveApplyTacticalPlan(.a)
        XCTAssertTrue(report.applied)
        let side = try XCTUnwrap(career.liveMatch).userSide
        XCTAssertEqual(side.style, .defensive)
        XCTAssertEqual(side.instructions.tempo, .normal)
        XCTAssertEqual(side.onPitch, lineupBefore)
        XCTAssertTrue(career.liveApplyTacticalPlan(.b).applied)
        XCTAssertEqual(try XCTUnwrap(career.liveMatch).userSide.style, .attacking)
        career.tacticalPlans.removeAll()
        XCTAssertFalse(career.liveApplyTacticalPlan(.a).applied)
    }

    func testPlansSurviveSaveAndOldSavesHaveNone() throws {
        var career = makeCareer()
        career.saveTacticalPlan(.a)
        let data = try JSONEncoder().encode(career)
        XCTAssertEqual(try JSONDecoder().decode(FootballCareer.self, from: data).tacticalPlans, career.tacticalPlans)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["tacticalPlans"] = nil
        let old = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(old.tacticalPlans.isEmpty)
    }
}

final class FootballAdvancePausesTests: XCTestCase {
    private func makeCareer() -> FootballCareer {
        var career = FootballCareer(seed: 21)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    func testFastAdvanceStopsOnlyWhereThePlayerChose() throws {
        // Sem pausar em pedidos e lesões, o avanço corre até um motivo fixo (clássico, janela, fim da temporada...).
        var relaxed = makeCareer()
        relaxed.world.phone.preferences.pauses = AdvancePauses(decisions: false, injuries: false, press: false, offers: false)
        let free = relaxed.simulateUntilDecision(maxDays: 12)

        var strict = makeCareer()
        strict.world.phone.preferences.pauses = AdvancePauses(decisions: true, injuries: true, press: false, offers: true)
        let careful = strict.simulateUntilDecision(maxDays: 12)
        XCTAssertLessThanOrEqual(careful.days, free.days, "Pausar em mais coisas nunca avança mais")

        // Com pausa na coletiva, o avanço para assim que a primeira partida gera uma coletiva pendente.
        var press = makeCareer()
        press.world.phone.preferences.pauses = AdvancePauses(decisions: false, injuries: false, press: true, offers: false)
        let stopped = press.simulateUntilDecision(maxDays: 12)
        XCTAssertEqual(stopped.reason, "Coletiva de imprensa aguardando resposta.")
        XCTAssertNotNil(press.pendingPress, "A coletiva fica para o treinador responder")

        var skipping = makeCareer()
        skipping.world.phone.preferences.pauses = AdvancePauses(decisions: false, injuries: false, press: false, offers: false)
        _ = skipping.simulateUntilDecision(maxDays: 3)
        XCTAssertNil(skipping.pendingPress, "Sem pausa na coletiva, ela é dispensada")
    }
}
