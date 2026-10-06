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

final class FootballMatchFlowTests: XCTestCase {
    private func liveAtHalftime() -> FootballCareer {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        career.liveAdvance(to: 45)
        return career
    }

    func testHalftimeTalkOnlyAtTheInterval() {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        XCTAssertFalse(career.canHoldHalftimeTalk)
        XCTAssertNil(career.holdHalftimeTalk(.praise))
        career.liveAdvance(to: 45)
        XCTAssertTrue(career.canHoldHalftimeTalk)
    }

    func testHalftimeTalkAppliesOnceAndLeavesAnEvent() {
        var career = liveAtHalftime()
        let before = career.liveMatch?.events.count ?? 0
        let moraleBefore = career.starters.map(\.morale).reduce(0, +)
        XCTAssertNotNil(career.holdHalftimeTalk(.praise))
        XCTAssertFalse(career.canHoldHalftimeTalk)
        XCTAssertNil(career.holdHalftimeTalk(.demand), "Só uma conversa por jogo")
        XCTAssertEqual(career.liveMatch?.events.count, before + 1)
        XCTAssertEqual(career.liveMatch?.halftimeTalk, HalftimeTalk.praise.rawValue)
        XCTAssertGreaterThan(career.starters.map(\.morale).reduce(0, +), moraleBefore - 1)
    }

    func testRecommendedTalkFollowsTheScore() {
        var career = liveAtHalftime()
        guard var live = career.liveMatch else { return XCTFail("sem partida") }
        let side: MatchTeamSide = live.userIsHome ? .home : .away
        live.sim[side].goals = live.sim[side.other].goals + 1
        career.liveMatch = live
        XCTAssertEqual(career.recommendedHalftimeTalk(), .calm)
        live.sim[side].goals = live.sim[side.other].goals
        career.liveMatch = live
        XCTAssertEqual(career.recommendedHalftimeTalk(), .praise)
    }

    func testFullTimeDigestSummarisesTheMatch() throws {
        var career = liveAtHalftime()
        career.liveAdvance(minutes: 200)
        let digest = try XCTUnwrap(career.fullTimeDigest())
        XCTAssertEqual(digest.goalLines.count, (career.liveMatch?.homeGoals ?? 0) + (career.liveMatch?.awayGoals ?? 0))
        XCTAssertTrue((0...100).contains(digest.possessionUser))
    }

    func testPostMatchReactionsAreCappedAndUnread() {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.simulateNextMatchDay())
        let log = career.world.phone.chat?.log.filter { $0.unread == true } ?? []
        XCTAssertFalse(log.isEmpty)
        XCTAssertLessThanOrEqual(log.count, 2)
        XCTAssertGreaterThanOrEqual(career.unreadMessageBadge, log.count)
        let thread = log[0].threadID
        career.markChatRead(thread)
        XCTAssertFalse((career.world.phone.chat?.log ?? []).contains { $0.threadID == thread && $0.unread == true })
    }

    func testPassiveNewsDoNotCountAsUnread() {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        let before = career.unreadCount
        career.addInbox(.news, title: "Zebra", body: "x")
        XCTAssertEqual(career.unreadCount, before)
        career.addInbox(.board, title: "Diretoria", body: "x")
        XCTAssertEqual(career.unreadCount, before + 1)
    }
}

final class FootballShootoutRevealTests: XCTestCase {
    func testRevealedShootoutIsNotDuplicatedAndMatchesTheOutcome() throws {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        XCTAssertTrue(career.beginMatchDay())
        career.liveAdvance(minutes: 200)
        var live = try XCTUnwrap(career.liveMatch)
        live.sim.needsShootout = true
        career.liveMatch = live
        XCTAssertTrue(career.canRevealShootout)
        career.revealLiveShootout()
        XCTAssertFalse(career.canRevealShootout)
        var sim = try XCTUnwrap(career.liveMatch).sim
        let kicks = sim.events.filter { $0.kind == .penalties }.count
        XCTAssertGreaterThanOrEqual(kicks, 2)
        let players = career.playersByID()
        let outcome = sim.makeOutcome(players: players, startHome: sim.home.onPitch, startAway: sim.away.onPitch)
        XCTAssertEqual(sim.events.filter { $0.kind == .penalties }.count, kicks, "Sem cobranças duplicadas")
        XCTAssertNotNil(outcome.homePenalties)
    }
}

final class FootballReactionQualityTests: XCTestCase {
    func testFamilyRepliesStayRareVariedAndNeverPileUp() {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        for _ in 0..<20 where career.canPlay || career.canAdvanceWithoutPlaying { _ = career.simulateNextMatchDay(); career.skipPress() }
        let family = (career.world.phone.chat?.log ?? []).filter { $0.threadID == "contact-family" && !$0.fromCoach }
        XCTAssertLessThanOrEqual(family.filter { $0.unread == true }.count, 2, "Sem acúmulo de não lidas")
        for pair in zip(family, family.dropFirst()) { XCTAssertNotEqual(pair.0.text, pair.1.text, "Sem repetir a mesma frase em sequência") }
        XCTAssertLessThan(family.count, 20, "Nem todo jogo gera mensagem")
    }

    func testNewsThreadsNeverShowUnreadBadges() {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        career.addInbox(.news, title: "Zebra na copa", body: "x")
        XCTAssertEqual(career.chatThreads().first { $0.id == "kind-news" }?.unread, 0)
    }
}
