import Foundation
import XCTest
@testable import ManagerFutebol

/// Build 26: placares ao vivo de outros jogos, manchete, notificações agrupadas, preferências do celular e relato de problema.
final class FootballBuild26Tests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 9) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    // MARK: Outros jogos ao vivo

    func testLiveRoundGamesFollowTheClockAndEndAtTheFinalScore() throws {
        var career = career()
        XCTAssertTrue(career.beginMatchDay())
        var live = try XCTUnwrap(career.liveMatch)
        XCTAssertFalse(live.others.isEmpty)
        XCTAssertEqual(career.liveRoundGames(live).count, live.others.count)
        XCTAssertTrue(career.liveRoundGames(live).allSatisfy { $0.homeScore == 0 && $0.awayScore == 0 }, "No minuto zero todos estão 0 × 0")

        career.liveAdvance(to: 120)
        live = try XCTUnwrap(career.liveMatch)
        for game in career.liveRoundGames(live) {
            let outcome = try XCTUnwrap(live.others.first { $0.fixtureID == game.fixtureID })
            XCTAssertEqual(game.homeScore, outcome.homeGoals)
            XCTAssertEqual(game.awayScore, outcome.awayGoals)
        }
    }

    func testGoalNoticesCoverEveryGoalOnceAndNeverRepeat() throws {
        var career = career()
        XCTAssertTrue(career.beginMatchDay())
        career.liveAdvance(to: 120)
        let live = try XCTUnwrap(career.liveMatch)
        let totalGoals = live.others.reduce(0) { $0 + $1.homeGoalMinutes.count + $1.awayGoalMinutes.count }

        let all = career.liveGoalNotices(live, after: 0, upTo: 120)
        XCTAssertEqual(all.count, totalGoals)
        XCTAssertEqual(all.map(\.minute), all.map(\.minute).sorted(), "Do mais antigo ao mais novo")

        // Fatiar o relógio não perde nem repete gols.
        var stitched: [LiveGoalNotice] = []
        var last = 0
        for minute in stride(from: 15, through: 120, by: 15) {
            stitched += career.liveGoalNotices(live, after: last, upTo: minute)
            last = minute
        }
        XCTAssertEqual(stitched.count, all.count)
        XCTAssertEqual(Set(stitched.map(\.id)).count, stitched.count)
        XCTAssertTrue(career.liveGoalNotices(live, after: 120, upTo: 120).isEmpty)
        for notice in all { XCTAssertTrue(notice.text.contains("×")) }
    }

    func testProvisionalTableUsesTodaysScoresAndStartsFromTheCurrentPosition() throws {
        var career = career()
        XCTAssertTrue(career.beginMatchDay())
        var live = try XCTUnwrap(career.liveMatch)
        let start = try XCTUnwrap(career.liveUserTablePosition(live))
        XCTAssertEqual(start.now, start.before, "Sem gols ainda, a posição provisória é a de hoje")
        XCTAssertEqual(career.liveTable(live).count, FootballSeason.teamsPerDivision)

        career.liveAdvance(to: 120)
        live = try XCTUnwrap(career.liveMatch)
        let end = try XCTUnwrap(career.liveUserTablePosition(live))
        XCTAssertTrue((1...FootballSeason.teamsPerDivision).contains(end.now))
        // A tabela provisória no apito final é a que a rodada vai produzir.
        let provisional = career.liveTable(live).map(\.team.id)
        _ = career.finishMatchDay()
        XCTAssertEqual(career.standings.map(\.team.id), provisional)
    }

    func testRelevantGamesInvolveClubsNextToTheUserInTheTable() throws {
        var career = career()
        XCTAssertTrue(career.beginMatchDay())
        let live = try XCTUnwrap(career.liveMatch)
        let games = career.liveRoundGames(live)
        let table = career.liveTable(live).map(\.team.id)
        let mine = try XCTUnwrap(table.firstIndex(of: 3))
        let near = Set(table[max(0, mine - 2)...min(table.count - 1, mine + 2)]).subtracting([3])
        for game in games {
            XCTAssertEqual(game.isRelevant, near.contains(game.homeID) || near.contains(game.awayID))
        }
        if let firstIrrelevant = games.firstIndex(where: { !$0.isRelevant }) {
            XCTAssertTrue(games[..<firstIrrelevant].allSatisfy(\.isRelevant), "Os relevantes vêm primeiro")
        }
    }

    // MARK: Manchete

    func testHeadlineMatchesTheResultAndIsStablePerMatch() {
        let win = FootballHeadline.make(club: "Aurora FC", opponent: "Maré Alta", userGoals: 2, rivalGoals: 1, isDerby: false, cameFromBehind: false, isCup: false, seed: 4)
        XCTAssertTrue(win.contains("Aurora FC"))
        let loss = FootballHeadline.make(club: "Aurora FC", opponent: "Maré Alta", userGoals: 0, rivalGoals: 2, isDerby: false, cameFromBehind: false, isCup: false, seed: 4)
        XCTAssertTrue(loss.contains("Maré Alta"))
        XCTAssertTrue(loss.contains("2 × 0") || loss.contains("cai") || loss.contains("Tropeço"))
        let comeback = FootballHeadline.make(club: "Aurora FC", opponent: "Maré Alta", userGoals: 2, rivalGoals: 1, isDerby: false, cameFromBehind: true, isCup: false, seed: 1)
        XCTAssertTrue(comeback.contains("Virada") || comeback.contains("sai de trás"))
        let nilNil = FootballHeadline.make(club: "A", opponent: "B", userGoals: 0, rivalGoals: 0, isDerby: false, cameFromBehind: false, isCup: false, seed: 0)
        XCTAssertTrue(nilNil.contains("Zero a zero") || nilNil.contains("Sem gols"))
        XCTAssertEqual(win, FootballHeadline.make(club: "Aurora FC", opponent: "Maré Alta", userGoals: 2, rivalGoals: 1, isDerby: false, cameFromBehind: false, isCup: false, seed: 4))
        let derby = FootballHeadline.make(club: "A", opponent: "B", userGoals: 1, rivalGoals: 0, isDerby: true, cameFromBehind: false, isCup: false, seed: 2)
        XCTAssertTrue(derby.contains("lássico") || derby.contains("rival"))
    }

    func testEveryPlayedMatchGetsAHeadline() throws {
        var career = career()
        XCTAssertTrue(career.simulateNextMatchDay())
        let fixture = try XCTUnwrap(career.latestUserFixture)
        let headline = try XCTUnwrap(career.matchHeadline(for: fixture))
        XCTAssertFalse(headline.isEmpty)
        XCTAssertNil(career.matchHeadline(for: try XCTUnwrap(career.nextUserFixture)), "Jogo que não aconteceu não tem manchete")
    }

    // MARK: Notificações e celular

    func testUnreadMessagesWithTheSameTitleAreGrouped() {
        var career = career()
        career.inbox.removeAll()
        for index in 0..<3 { career.addInbox(.news, title: "Zebra na copa", body: "Jogo \(index)") }
        career.addInbox(.news, title: "Outra notícia", body: "—")
        let groups = career.unreadMessageGroups
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first { $0.newest.title == "Zebra na copa" }?.count, 3)
        XCTAssertEqual(groups.reduce(0) { $0 + $1.count }, 4, "Nenhuma mensagem some, só agrupa")
        XCTAssertEqual(groups.first?.newest.id, career.inbox.filter { !$0.isRead }.map(\.id).max(), "O primeiro grupo é o da mensagem mais nova")
    }

    func testHomeOrderKeepsChosenAppsFirstAndAddsTheRest() {
        let factory = ["a", "b", "c", "d", "e"]
        XCTAssertEqual(PhonePreferences.ordered(factory, custom: nil), factory)
        XCTAssertEqual(PhonePreferences.ordered(factory, custom: ["d", "a"]), ["d", "a", "b", "c", "e"])
        XCTAssertEqual(PhonePreferences.ordered(factory, custom: ["x", "c", "c", "b"]), ["c", "b", "a", "d", "e"], "Ignora o que não existe e o repetido")
        XCTAssertEqual(PhonePreferences.swapped(factory, "a", "e"), ["e", "b", "c", "d", "a"])
        XCTAssertEqual(PhonePreferences.swapped(factory, "a", "zz"), factory)
    }

    func testNewPhonePreferencesDefaultAndSurviveOldSaves() throws {
        var career = career()
        XCTAssertEqual(career.world.phone.preferences.wallpaperStyle, .club)
        XCTAssertEqual(career.world.phone.preferences.themeChoice, .system)
        XCTAssertTrue(career.world.phone.preferences.hapticsOn)
        career.world.phone.preferences.wallpaper = .night
        career.world.phone.preferences.theme = .dark
        career.world.phone.preferences.hapticsEnabled = false
        career.world.phone.preferences.homeOrder = ["x", "y"]
        let roundTrip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(roundTrip.world.phone.preferences, career.world.phone.preferences)

        // Save antigo: sem nenhum dos campos novos.
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(object["world"] as? [String: Any])
        var phone = try XCTUnwrap(world["phone"] as? [String: Any])
        var preferences = try XCTUnwrap(phone["preferences"] as? [String: Any])
        for key in ["wallpaper", "theme", "hapticsEnabled", "homeOrder"] { preferences.removeValue(forKey: key) }
        phone["preferences"] = preferences
        world["phone"] = phone
        object["world"] = world
        let old = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(old.world.phone.preferences.wallpaperStyle, .club)
        XCTAssertTrue(old.world.phone.preferences.hapticsOn)
        XCTAssertNil(old.world.phone.preferences.homeOrder)
    }

    func testSupportReportCarriesTheCareerPointWithoutTheWholeSave() {
        var career = career()
        _ = career.simulateNextMatchDay()
        let report = career.supportReport(version: "1.1", build: "26")
        XCTAssertTrue(report.hasPrefix("Manager de Futebol 1.1 (26)"))
        XCTAssertTrue(report.contains("União da Serra"))
        XCTAssertTrue(report.contains("Temporada 1"))
        XCTAssertTrue(report.contains("O que aconteceu e o que você esperava:"))
        XCTAssertLessThan(report.count, 1_500, "É um resumo, não o save")
    }

    func testVisibleSponsorsListEveryActiveContractAndBrandHuesAreStable() {
        var career = career()
        career.sponsorDeal = SponsorDeal(sponsor: "Banco Aurora", fixedPerSeason: 1, bonusPerWin: 0, titleBonus: 0, endSeason: 2)
        career.world.growth.slotDeals = [SlotDeal(slot: .stadiumBoards, sponsor: "Rede Vale", perSeason: 1, endSeason: 2)]
        let sponsors = career.visibleSponsors
        XCTAssertEqual(sponsors.map(\.role), ["Camisa", "Placas do estádio"])
        XCTAssertEqual(sponsors.map(\.name), ["Banco Aurora", "Rede Vale"])
        career.sponsorDeal = nil
        career.world.growth.slotDeals = []
        XCTAssertTrue(career.visibleSponsors.isEmpty)
        XCTAssertEqual(FootballCareer.brandHue(of: "Banco Aurora"), FootballCareer.brandHue(of: "Banco Aurora"))
        XCTAssertTrue((0..<360).contains(FootballCareer.brandHue(of: "Qualquer marca")))
        XCTAssertNotEqual(FootballCareer.brandHue(of: "Banco Aurora"), FootballCareer.brandHue(of: "Rede Vale"))
    }

    func testEveryClubHasACityScaleAndTheCapitalsAreLarge() {
        let scales = FootballSeason.teams.map(\.cityScale)
        XCTAssertEqual(scales.count, 20)
        XCTAssertEqual(Set(scales).count, 3, "Há cidades pequenas, médias e grandes")
        XCTAssertEqual(FootballSeason.team(0)?.cityScale, .large, "Brasília")
        XCTAssertEqual(FootballSeason.team(13)?.cityScale, .small, "Lages")
        XCTAssertEqual(Set(CityScale.allCases.map(\.imageName)).count, 3)
    }

    /// A prévia mostra exatamente o que o motor faz: confere fan, diretoria e moral de cada tom contra `answerPress`.
    func testPressPreviewMatchesWhatTheEngineDoes() throws {
        var checked = Set<String>()
        for seed in 1...25 {
            var base = FootballCareer(seed: seed)
            XCTAssertTrue(base.chooseClub(3))
            XCTAssertTrue(base.simulateNextMatchDay())
            guard let press = base.pendingPress, let result = press.result,
                  let question = press.questions.first(where: { $0.topic == .general }) else { continue }
            // Valores no meio da escala e jornalista sem prestígio, para nada saturar nem somar bônus de relação.
            base.fanMood = 50
            base.boardConfidence = 50
            for index in base.players.indices where base.players[index].teamID == 3 { base.players[index].morale = 50 }
            if let index = base.world.contacts.contacts.firstIndex(where: { $0.role == .journalist }) {
                base.world.contacts.contacts[index].relationship = 10
            }
            for tone in PressTone.allCases {
                var career = base
                career.answerPress(questionID: question.id, tone: tone)
                let preview = tone.baseEffects(result: result, isDerby: press.isDerby)
                func delta(_ label: String) -> Int { preview.first { $0.label == label }?.delta ?? 0 }
                XCTAssertEqual(career.fanMood - 50, delta("Torcida"), "Torcida, \(tone) após \(result)")
                XCTAssertEqual(career.boardConfidence - 50, delta("Diretoria"), "Diretoria, \(tone) após \(result)")
                let squad = career.players.filter { $0.teamID == 3 && !$0.isYouth }
                XCTAssertTrue(squad.allSatisfy { $0.morale - 50 == delta("Moral do elenco") }, "Moral, \(tone) após \(result)")
                XCTAssertEqual(career.rivalMotivation[press.opponentID] != nil, preview.contains { $0.label == "Rival" })
                checked.insert("\(tone)-\(result)")
            }
        }
        XCTAssertGreaterThanOrEqual(checked.count, 6, "Pelo menos dois resultados diferentes foram conferidos: \(checked)")
    }
}
