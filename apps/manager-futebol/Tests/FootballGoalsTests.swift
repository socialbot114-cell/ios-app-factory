import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballGoalsTests: XCTestCase {
    private func career() -> FootballCareer {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        career.world.quests = QuestState()
        return career
    }

    func testAutomaticGoalsHaveOriginAndSkipOptInActivities() {
        var career = career()
        var random = FootballRandom(seed: 3)
        career.refreshQuests(using: &random)
        XCTAssertFalse(career.world.quests.active.isEmpty)
        XCTAssertTrue(career.world.quests.active.allSatisfy { $0.origin != nil && !($0.sourceName ?? "").isEmpty })
        XCTAssertTrue(career.world.quests.active.allSatisfy { !FootballCareer.questOptInIDs.contains($0.templateID) },
                      "Apostas, Rodada, redes e agenda nunca são impostas")
    }

    func testPersonalGoalsAreLimitedAndOptional() {
        var career = career()
        XCTAssertTrue(career.adoptGoal(templateID: "w-bets"))
        XCTAssertTrue(career.adoptGoal(templateID: "w-fantasy"))
        XCTAssertTrue(career.adoptGoal(templateID: "w-posts"))
        XCTAssertFalse(career.adoptGoal(templateID: "w-wins"), "Limite de metas pessoais")
        XCTAssertEqual(career.personalGoals.count, FootballCareer.personalGoalLimit)
        XCTAssertFalse(career.adoptGoal(templateID: "w-bets"))
        XCTAssertEqual(career.personalGoals.first?.origin, .player)
    }

    func testContributionsAreLoggedAndCompletionPaysOnce() throws {
        var career = career()
        XCTAssertTrue(career.adoptGoal(templateID: "w-wins"))
        let fichas = career.world.betting.fichas
        career.bump("wins")
        let quest = try XCTUnwrap(career.world.quests.active.first)
        XCTAssertEqual(quest.contributions?.map(\.text), ["vitória"])
        career.updateQuests()
        XCTAssertFalse(career.world.quests.active[0].completed)
        career.bump("wins")
        career.updateQuests()
        XCTAssertTrue(career.world.quests.active[0].completed)
        XCTAssertEqual(career.world.betting.fichas, fichas + 150)
        career.bump("wins")
        career.updateQuests()
        XCTAssertEqual(career.world.betting.fichas, fichas + 150, "Recompensa única")
        XCTAssertEqual(career.world.quests.history?.filter { $0.outcome == .completed }.count, 1)
        XCTAssertEqual(career.world.quests.history?.first?.contributions.count, 2)
    }

    func testReplacementAndFailureKeepHistory() throws {
        var career = career()
        XCTAssertTrue(career.adoptGoal(templateID: "w-wins"))
        let id = try XCTUnwrap(career.personalGoals.first?.id)
        XCTAssertFalse(career.replaceGoal(questID: id, with: "w-wins"), "Não troca por ela mesma")
        XCTAssertTrue(career.replaceGoal(questID: id, with: "w-press"))
        XCTAssertEqual(career.world.quests.history?.first?.outcome, .replaced)
        XCTAssertEqual(career.personalGoals.map(\.templateID), ["w-press"])
        career.matchDayIndex += 8
        var random = FootballRandom(seed: 3)
        career.refreshQuests(using: &random)
        XCTAssertTrue(career.world.quests.history?.contains { $0.outcome == .failed && $0.templateID == "w-press" } ?? false)
    }

    func testEveryTemplateCounterHasAnActionOrIsIntentionallyPassive() {
        for template in FootballCareer.questTemplates {
            XCTAssertNotNil(FootballCareer.questActionApp(counter: template.counter), template.id)
            XCTAssertNotNil(FootballCareer.questActionTitle(counter: template.counter))
        }
    }

    func testOldSavesWithoutNewFieldsStillDecode() throws {
        let old = #"{"active":[],"completedCount":2,"nextQuestID":3,"lastRefreshWorldDay":5}"#
        let state = try JSONDecoder().decode(QuestState.self, from: Data(old.utf8))
        XCTAssertNil(state.history)
        XCTAssertEqual(state.completedCount, 2)
    }
}
