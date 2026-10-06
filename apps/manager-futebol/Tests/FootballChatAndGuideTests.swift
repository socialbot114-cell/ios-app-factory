import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballChatAndGuideTests: XCTestCase {
    private func career() -> FootballCareer {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        return career
    }

    func testGuideAlwaysHasAnActionBeforeTheSeasonEnds() {
        let career = career()
        XCTAssertNotNil(career.nextBestAction())
        let ids = career.suggestions().map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Sugestões não devem se repetir")
    }

    func testPendingPressIsTheMostUrgentSuggestion() {
        var career = career()
        XCTAssertTrue(career.simulateNextMatchDay())
        if career.pendingPress != nil {
            XCTAssertEqual(career.nextBestAction()?.id, "press")
        }
    }

    func testTipsRotateWithTheCalendar() {
        var career = career()
        let first = career.dailyTip()
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertNotEqual(first, career.dailyTip())
    }

    func testChatListsStaffFamilyAndPlayersAndAnswersQuickMessages() throws {
        var career = career()
        career.ensureContacts()
        let threads = career.chatThreads()
        XCTAssertTrue(threads.contains { $0.group == .family })
        XCTAssertTrue(threads.contains { $0.id == "contact-family" })

        let family = try XCTUnwrap(threads.first { $0.id == "contact-family" })
        XCTAssertNil(career.chatQuickBlocker(family))
        let before = career.relationship(.family)
        XCTAssertNotNil(career.sendChatQuick(threadID: family.id, quickID: "care"))
        XCTAssertGreaterThan(career.relationship(.family), before)
        let bubbles = career.chatBubbles(threadID: family.id)
        XCTAssertEqual(bubbles.suffix(2).map(\.fromCoach), [true, false])
        XCTAssertNotNil(career.chatQuickBlocker(family), "Uma mensagem rápida por dia")
        XCTAssertNil(career.sendChatQuick(threadID: family.id, quickID: "care"))
    }

    func testPraisingAPlayerRaisesMoraleAndCreatesAThread() throws {
        var career = career()
        let athlete = try XCTUnwrap(career.clubRoster.first { !$0.isYouth })
        let before = athlete.morale
        XCTAssertNotNil(career.sendChatQuick(threadID: "player-\(athlete.id)", quickID: "praise"))
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(career.player(athlete.id)).morale, min(100, before + 3))
        XCTAssertTrue(career.chatThreads().contains { $0.id == "player-\(athlete.id)" })
    }

    func testSocialPhotoBoostsLikes() throws {
        var plain = career()
        var withPhoto = career()
        let plainPost = try XCTUnwrap(plain.publishPost(draft: PostDraft(tone: .thanks, subject: .team)))
        let photoPost = try XCTUnwrap(withPhoto.publishPost(draft: PostDraft(tone: .thanks, subject: .team, photo: .trophy)))
        XCTAssertEqual(photoPost.photo ?? .trophy, .trophy)
        XCTAssertGreaterThanOrEqual(withPhoto.world.social.posts.first { $0.id == photoPost.id }?.likes ?? 0, plain.world.social.posts.first { $0.id == plainPost.id }?.likes ?? 0)
    }

    func testLikeTogglesAndStoriesExist() throws {
        var career = career()
        XCTAssertTrue(career.simulateNextMatchDay())
        let post = try XCTUnwrap(career.world.social.posts.first)
        let likes = post.likes
        XCTAssertTrue(career.toggleLike(postID: post.id))
        XCTAssertEqual(career.world.social.posts.first { $0.id == post.id }?.likes, likes + 1)
        XCTAssertFalse(career.toggleLike(postID: post.id))
        XCTAssertFalse(career.storyItems().isEmpty)
    }

    func testDebtOutranksRoutineAndSuggestionsAreSortedByScore() {
        var career = career()
        career.transferBudget = -500_000
        let list = career.suggestions()
        XCTAssertEqual(list.first?.id, "debt")
        XCTAssertEqual(list.map(\.score), list.map(\.score).sorted(by: >))
        XCTAssertEqual(list.first?.priority, 2)
        XCTAssertNotNil(list.first?.why)
    }

    func testSnoozeHidesNonUrgentSuggestionUntilTheNextDay() {
        var career = career()
        career.transferBudget = -500_000
        career.snoozeSuggestion("debt")
        XCTAssertFalse(career.suggestions().contains { $0.id == "debt" })
        XCTAssertTrue(career.suggestions(includeSnoozed: true).contains { $0.id == "debt" })
        XCTAssertTrue(career.simulateNextMatchDay())
        career.transferBudget = -500_000
        XCTAssertTrue(career.suggestions().contains { $0.id == "debt" }, "Volta no dia seguinte")
    }

    func testDayPlanKeepsVarietyAndEndsWithTheRoutine() {
        var career = career()
        career.transferBudget = -500_000
        let plan = career.dayPlan()
        XCTAssertLessThanOrEqual(plan.count, 4)
        XCTAssertTrue(["play", "advance", "season-end"].contains(plan.last?.id ?? ""))
        let ids = plan.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
