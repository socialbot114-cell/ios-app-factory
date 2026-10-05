import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballPublicSphereTests: XCTestCase {
    private func makeCareer() -> FootballCareer {
        var career = FootballCareer(seed: 41)
        XCTAssertTrue(career.chooseClub(0))
        career.matchDayIndex = 6
        career.ensureProfiles()
        return career
    }

    func testProfilesArePersistentStableAndIdempotent() throws {
        var career = makeCareer()
        let count = career.profiles.count
        XCTAssertGreaterThan(count, FootballSeason.teams.count, "Clubes, jornalistas, comentaristas, torcida e craques")
        career.ensureProfiles()
        XCTAssertEqual(career.profiles.count, count)
        XCTAssertEqual(Set(career.profiles.map(\.id)).count, count)
        let journalist = try XCTUnwrap(career.profiles.first { $0.kind == .journalist })
        XCTAssertTrue((0...100).contains(journalist.credibility))
        XCTAssertTrue(journalist.handle.hasPrefix("@"))
        XCTAssertEqual(career.profile("club-\(career.selectedClubID ?? 0)")?.kind, .club)
        let loaded = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(loaded.profiles, career.profiles)
        var again = makeCareer()
        XCTAssertEqual(again.profiles, career.profiles, "Mesmo estado, mesmos perfis")
        again.ensureProfiles()
    }

    func testPreviewIsDeterministicAndExplainsReachRiskAndEffects() throws {
        let career = makeCareer()
        let athlete = try XCTUnwrap(career.clubRoster.max { $0.overall < $1.overall })
        let draft = PostDraft(tone: .provocative, subject: .rival(3))
        let first = career.previewPost(draft)
        XCTAssertEqual(first, career.previewPost(draft))
        XCTAssertLessThan(first.reachLow, first.reachHigh)
        XCTAssertEqual(first.risk, "alto")
        XCTAssertTrue(first.effects.contains { $0.contains("motivado") })
        XCTAssertTrue(first.text.contains(FootballSeason.teamName(3)))
        let praise = career.previewPost(PostDraft(tone: .thanks, subject: .player(athlete.id)))
        XCTAssertTrue(praise.text.contains(athlete.name))
        XCTAssertEqual(praise.risk, "baixo")
        XCTAssertTrue(praise.effects.contains { $0.contains("Moral de \(athlete.name) +4") })
        XCTAssertNil(praise.blocked)
    }

    func testTargetedPostAppliesSubjectEffectsAndRecordsFactAndMemory() throws {
        var career = makeCareer()
        let athlete = try XCTUnwrap(career.clubRoster.max { $0.overall < $1.overall })
        let morale = career.player(athlete.id)?.morale ?? 0
        let post = try XCTUnwrap(career.publishPost(draft: PostDraft(tone: .thanks, subject: .player(athlete.id))))
        XCTAssertEqual(career.player(athlete.id)?.morale, min(100, morale + 4 + 1), "+4 do alvo e +1 do agradecimento ao elenco")
        XCTAssertEqual(post.targetID, "player-\(athlete.id)")
        XCTAssertTrue(post.text.contains(athlete.name))
        XCTAssertNotNil(career.fact("post-\(post.id)"))
        XCTAssertTrue(career.publicMemory.contains { $0.id == "post-\(post.id)" && $0.kind == .praise })
        XCTAssertNil(career.publishPost(draft: PostDraft(tone: .humor)), "Uma publicação por dia")

        var rival = makeCareer()
        let controversy = rival.world.social.controversy
        let provocation = try XCTUnwrap(rival.publishPost(draft: PostDraft(tone: .provocative, subject: .rival(4))))
        XCTAssertGreaterThanOrEqual(rival.rivalMotivation[4] ?? 0, 1.5)
        XCTAssertGreaterThanOrEqual(rival.world.social.controversy, controversy + 4 - 3, "Polêmica sobe com a provocação")
        XCTAssertTrue(rival.publicMemory.contains { $0.id == "post-\(provocation.id)" && $0.kind == .controversy })

        var press = makeCareer()
        let journalist = try XCTUnwrap(press.profiles.first { $0.kind == .journalist })
        _ = try XCTUnwrap(press.publishPost(draft: PostDraft(tone: .provocative, subject: .journalist(journalist.id))))
        XCTAssertEqual(press.profile(journalist.id)?.stance, journalist.stance - 12)
    }

    func testEngagementArrivesInStagesWithoutRerollingAndRepliesAreStored() throws {
        var career = makeCareer()
        let post = try XCTUnwrap(career.publishPost(draft: PostDraft(tone: .provocative, subject: .rival(2))))
        let stored = try XCTUnwrap(career.world.social.posts.first { $0.id == post.id })
        let final = try XCTUnwrap(stored.finalLikes)
        XCTAssertEqual(stored.stage, 0)
        XCTAssertLessThan(stored.likes, final, "No primeiro momento só parte do engajamento")
        XCTAssertTrue(career.replies(for: post.id).isEmpty)

        // Abrir a tela (ou avançar no mesmo dia) não muda nada.
        career.advancePublicSphere()
        XCTAssertEqual(career.world.social.posts.first { $0.id == post.id }?.likes, stored.likes)

        career.matchDayIndex += 1
        career.advancePublicSphere()
        let second = try XCTUnwrap(career.world.social.posts.first { $0.id == post.id })
        XCTAssertEqual(second.stage, 1)
        XCTAssertEqual(second.likes, Int(Double(final) * 0.75))
        XCTAssertFalse(career.replies(for: post.id).isEmpty, "Comentários chegam no segundo momento")
        XCTAssertTrue(career.replies(for: post.id).contains { $0.sentiment < 0 }, "Provocação gera reação negativa")
        let before = career.replies(for: post.id)
        career.advancePublicSphere()
        XCTAssertEqual(career.replies(for: post.id), before, "Sem novo sorteio no mesmo dia")

        career.matchDayIndex += 2
        career.advancePublicSphere()
        XCTAssertEqual(career.world.social.posts.first { $0.id == post.id }?.likes, final)
        XCTAssertEqual(career.world.social.posts.first { $0.id == post.id }?.stage, 2)
        XCTAssertLessThanOrEqual(career.replies(for: post.id).count, FootballCareer.repliesPerPostLimit)

        // Persistência das respostas e das etapas.
        let loaded = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(loaded.postReplies, career.postReplies)
        XCTAssertEqual(loaded.world.social.posts.first { $0.id == post.id }, career.world.social.posts.first { $0.id == post.id })
    }

    func testAnsweringARepliesIsOnePerCommentAndShiftsStanceAndControversy() throws {
        var career = makeCareer()
        let post = try XCTUnwrap(career.publishPost(draft: PostDraft(tone: .provocative, subject: .rival(2))))
        career.matchDayIndex += 1
        career.advancePublicSphere()
        let negative = try XCTUnwrap(career.replies(for: post.id).first { $0.sentiment < 0 })
        let stance = career.profile(negative.profileID ?? "")?.stance ?? 0
        let controversy = career.world.social.controversy
        XCTAssertTrue(career.answerReply(negative.id, firm: false))
        XCTAssertFalse(career.answerReply(negative.id, firm: true), "Uma resposta por comentário")
        XCTAssertEqual(career.profile(negative.profileID ?? "")?.stance, min(100, stance + 3))
        XCTAssertEqual(career.world.social.controversy, max(0, controversy - 2))
        XCTAssertEqual(career.replies(for: post.id).first { $0.id == negative.id }?.answer, "calm")
    }

    func testSourcesAndRumorReliabilityFollowTheOutcome() throws {
        var career = makeCareer()
        let athlete = try XCTUnwrap(career.clubRoster.max { $0.overall < $1.overall })
        let arc = try XCTUnwrap(career.openRumorArc(playerID: athlete.id, truth: false))
        var post = try XCTUnwrap(career.world.social.posts.first { $0.sourceFactID == "arc-\(arc.id)-open" })
        XCTAssertEqual(career.postSource(post).reliability, "rumor")
        XCTAssertTrue(career.postSource(post).label.contains("boato"))
        let reporter = arc.participants[1].split(separator: "(").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        let credibility = try XCTUnwrap(career.profile(career.profileID(forName: reporter) ?? "")?.credibility)
        XCTAssertTrue(career.decideArc(arc.id, .deny))
        post = try XCTUnwrap(career.world.social.posts.first { $0.sourceFactID == "arc-\(arc.id)-open" })
        XCTAssertEqual(post.reliability, "denied")
        XCTAssertTrue(career.postSource(post).label.contains("desmentido"))
        XCTAssertEqual(career.profile(career.profileID(forName: reporter) ?? "")?.credibility, max(0, credibility - 6), "Quem espalhou boato falso perde credibilidade")

        var truthful = makeCareer()
        let real = try XCTUnwrap(truthful.openRumorArc(playerID: athlete.id, truth: true))
        let name = real.participants[1].split(separator: "(").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        let before = try XCTUnwrap(truthful.profile(truthful.profileID(forName: name) ?? "")?.credibility)
        XCTAssertTrue(truthful.decideArc(real.id, .talk))
        XCTAssertEqual(truthful.profile(truthful.profileID(forName: name) ?? "")?.credibility, min(100, before + 4))
        XCTAssertEqual(truthful.world.social.posts.first { $0.sourceFactID == "arc-\(real.id)-open" }?.reliability, "confirmed")
        let opinion = SocialPost(id: 999, season: 1, matchDay: 0, author: .pundit, name: "Mestre Lima", handle: "@m", text: "x", likes: 0, shares: 0, replies: 0, sentiment: 0)
        XCTAssertEqual(career.postSource(opinion).label, "Opinião de Mestre Lima")
    }

    func testPublicMemoryResurfacesInACrisisAndSponsoredExcessCutsOffers() throws {
        var career = makeCareer()
        let post = try XCTUnwrap(career.publishPost(draft: PostDraft(tone: .provocative)))
        let entry = try XCTUnwrap(career.publicMemory.first { $0.postID == post.id })
        XCTAssertNil(career.resurfacingPost, "Muito recente para voltar")
        career.matchDayIndex += 9
        XCTAssertEqual(career.resurfacingPost?.id, entry.id)

        // Memória tem limite e não duplica.
        for index in 0..<30 { career.recordPublicMemory(id: "bulk-\(index)", kind: .praise, text: "x", weight: 1) }
        XCTAssertLessThanOrEqual(career.publicMemory.count, FootballCareer.publicMemoryLimit)
        XCTAssertFalse(career.recordPublicMemory(id: "bulk-29", kind: .praise, text: "x", weight: 1))

        // Excesso de publis desvaloriza novas propostas de marca.
        var brand = makeCareer()
        brand.world.social.coachFollowers = 60_000
        brand.refreshBrandOffers()
        let normal = brand.world.social.brandOffers.map(\.payPerPost)
        brand.recordPublicMemory(id: "sponsored-test", kind: .sponsored, text: "Excesso de publis", weight: 1)
        XCTAssertEqual(brand.brandOfferFactor, 0.9)
        brand.refreshBrandOffers()
        let reduced = brand.world.social.brandOffers.map(\.payPerPost)
        if !normal.isEmpty, normal.count == reduced.count { XCTAssertTrue(zip(reduced, normal).allSatisfy { $0 <= $1 }) }
    }

    func testResolvingACrisisLeavesPublicMemory() throws {
        var career = makeCareer()
        career.world.social.crisis = SocialCrisis(kind: .oldPost, title: "Publicação antiga", body: "x", matchDay: 6)
        XCTAssertNotNil(career.resolveCrisis(.apologize))
        XCTAssertTrue(career.publicMemory.contains { $0.kind == .crisis })
    }
}
