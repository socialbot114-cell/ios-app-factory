import Foundation
import XCTest
@testable import ManagerFutebol

/// Build 27: Foco, pastas, notas, clima da partida e relógio.
final class FootballBuild27Tests: XCTestCase {
    private func career(club: Int = 3, seed: Int = 9) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    private let factory = ["a", "b", "c", "d", "e", "f"]

    // MARK: Foco

    func testFocusModesFilterByAppButUrgentNoticesAlwaysPass() {
        var prefs = PhonePreferences()
        XCTAssertTrue(prefs.allows(appID: "bank", priority: 1), "Sem foco, tudo passa")
        prefs.focus = .rest
        XCTAssertFalse(prefs.allows(appID: "manager", priority: 2))
        XCTAssertTrue(prefs.allows(appID: "manager", priority: 3), "Urgente passa em qualquer foco")
        prefs.focus = .game
        XCTAssertTrue(prefs.allows(appID: "market", priority: 2))
        XCTAssertFalse(prefs.allows(appID: "bank", priority: 2))
        prefs.focus = .business
        XCTAssertTrue(prefs.allows(appID: "bank", priority: 2))
        XCTAssertFalse(prefs.allows(appID: "betting", priority: 2))
        prefs.focus = PhoneFocusMode.none
        prefs.mutedApps = ["bank"]
        XCTAssertFalse(prefs.allows(appID: "bank", priority: 1), "O silêncio por app continua valendo")
    }

    func testFocusHidesNotificationsInTheCareer() {
        var career = career()
        career.addInbox(.news, title: "Notícia qualquer", body: "—")
        XCTAssertFalse(career.world.phone.preferences.allows(appID: "messages", priority: 1) == false)
        career.world.phone.preferences.focus = .rest
        XCTAssertFalse(career.world.phone.preferences.allows(appID: "messages", priority: 1))
    }

    // MARK: Pastas

    func testCreatingAFolderTakesTheSlotOfTheFirstApp() throws {
        var prefs = PhonePreferences()
        let id = try XCTUnwrap(prefs.createFolder(with: ["c", "a"], factory: factory))
        XCTAssertEqual(id, "folder:1")
        XCTAssertEqual(prefs.homeFolders?.first?.name, "Pasta 1")
        // c e a saem da grade; a pasta fica onde estava c.
        XCTAssertEqual(prefs.homeItemIDs(factory: factory), ["b", "folder:1", "d", "e", "f"])
        XCTAssertEqual(prefs.folder(id)?.appIDs, ["c", "a"])
        XCTAssertNil(prefs.createFolder(with: ["zz"], factory: factory), "Sem app válido não cria pasta")
        XCTAssertNil(prefs.createFolder(with: ["c"], factory: factory), "Um app já em pasta não entra em outra")
    }

    func testFolderOperationsKeepEveryAppSomewhere() throws {
        var prefs = PhonePreferences()
        let id = try XCTUnwrap(prefs.createFolder(with: ["a", "b"], factory: factory))
        prefs.addToFolder(app: "e", folder: id, factory: factory)
        XCTAssertEqual(prefs.folder(id)?.appIDs, ["a", "b", "e"])
        XCTAssertFalse(prefs.homeItemIDs(factory: factory).contains("e"))

        prefs.renameFolder(id, to: "  Clube e dinheiro  ")
        XCTAssertEqual(prefs.folder(id)?.name, "Clube e dinheiro")
        prefs.renameFolder(id, to: "    ")
        XCTAssertEqual(prefs.folder(id)?.name, "Clube e dinheiro", "Nome vazio não vale")
        prefs.renameFolder(id, to: String(repeating: "x", count: 40))
        XCTAssertEqual(prefs.folder(id)?.name.count, PhonePreferences.folderNameLimit)

        prefs.removeFromFolder(app: "b")
        XCTAssertTrue(prefs.homeItemIDs(factory: factory).contains("b"))
        XCTAssertEqual(prefs.folder(id)?.appIDs, ["a", "e"])

        prefs.deleteFolder(id)
        XCTAssertNil(prefs.homeFolders)
        XCTAssertEqual(Set(prefs.homeItemIDs(factory: factory)), Set(factory), "Todos os apps voltam à grade")

        // Pasta que perde o último app some sozinha.
        let other = try XCTUnwrap(prefs.createFolder(with: ["d"], factory: factory))
        prefs.removeFromFolder(app: "d")
        XCTAssertNil(prefs.folder(other))
        XCTAssertEqual(Set(prefs.homeItemIDs(factory: factory)), Set(factory))
    }

    func testFoldersSurviveSaveAndOldSavesHaveNone() throws {
        var career = career()
        _ = career.world.phone.preferences.createFolder(with: ["bank", "brand"], factory: ["bank", "brand", "life"], name: "Dinheiro")
        career.world.phone.preferences.focus = .game
        career.world.phone.preferences.soundEnabled = false
        _ = career.addNote("Renovar o camisa 10")
        let trip = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(trip.world.phone.preferences, career.world.phone.preferences)
        XCTAssertEqual(trip.coachNotes.map(\.text), ["Renovar o camisa 10"])

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        var world = try XCTUnwrap(object["world"] as? [String: Any])
        var phone = try XCTUnwrap(world["phone"] as? [String: Any])
        var prefs = try XCTUnwrap(phone["preferences"] as? [String: Any])
        for key in ["focus", "homeFolders", "soundEnabled"] { prefs.removeValue(forKey: key) }
        phone["preferences"] = prefs
        phone.removeValue(forKey: "notes")
        phone.removeValue(forKey: "nextNoteID")
        world["phone"] = phone
        object["world"] = world
        let old = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(old.world.phone.preferences.focusMode, PhoneFocusMode.none)
        XCTAssertTrue(old.world.phone.preferences.soundsOn)
        XCTAssertNil(old.world.phone.preferences.homeFolders)
        XCTAssertTrue(old.coachNotes.isEmpty)
    }

    // MARK: Notas

    func testNotesAreTrimmedCappedAndNewestFirst() {
        var career = career()
        XCTAssertNil(career.addNote("   \n  "))
        let first = career.addNote("  Conversar com o capitão  ")
        XCTAssertEqual(first?.text, "Conversar com o capitão")
        career.addNote(String(repeating: "x", count: 1_000))
        XCTAssertEqual(career.coachNotes.first?.text.count, FootballCareer.noteCharacterLimit)
        XCTAssertEqual(career.coachNotes.last?.text, "Conversar com o capitão")
        for index in 0..<60 { career.addNote("nota \(index)") }
        XCTAssertEqual(career.coachNotes.count, FootballCareer.noteLimit)
        XCTAssertEqual(career.coachNotes.first?.text, "nota 59")
        let id = career.coachNotes[0].id
        career.deleteNote(id: id)
        XCTAssertFalse(career.coachNotes.contains { $0.id == id })
    }

    // MARK: Clima

    func testWeatherIsStablePerMatchAndFollowsTheRegion() {
        let career = career()
        func fixture(_ id: Int, home: Int) -> LeagueFixture {
            LeagueFixture(id: id, matchDay: 0, round: 1, competition: .league(.serieA), home: home, away: 0)
        }
        XCTAssertEqual(career.weather(for: fixture(5, home: 6)), career.weather(for: fixture(5, home: 6)))
        func rainShare(home: Int) -> Double {
            Double((0..<600).filter { career.weather(for: fixture($0, home: home)) == .rain }.count) / 600
        }
        let manaus = rainShare(home: 6)       // Norte
        let natal = rainShare(home: 14)       // Nordeste
        XCTAssertTrue((0.34...0.50).contains(manaus), "Norte: \(manaus)")
        XCTAssertTrue((0.13...0.27).contains(natal), "Nordeste: \(natal)")
        XCTAssertGreaterThan(manaus, natal)
        let kinds = Set((0..<200).map { career.weather(for: fixture($0, home: 4)) })
        XCTAssertEqual(kinds.count, 3, "Os três climas aparecem")
    }

    // MARK: Relógio

    func testClockCountsDownToTheNextMatchWindowAndSeasonEnd() throws {
        var career = career()
        let items = career.clockItems
        let match = try XCTUnwrap(items.first { $0.id == "match" })
        XCTAssertNotNil(match.days)
        XCTAssertTrue(match.detail.contains("·"))
        XCTAssertEqual(try XCTUnwrap(items.first { $0.id == "window" }).title, "Janela aberta", "No dia 0 a pré-temporada está aberta")
        XCTAssertNotNil(items.first { $0.id == "season" })

        for _ in 0..<4 { XCTAssertTrue(career.simulateNextMatchDay()) }
        let later = career.clockItems
        let window = try XCTUnwrap(later.first { $0.id == "window" })
        XCTAssertEqual(window.title, "Próxima janela", "Entre as janelas, o relógio conta até a próxima")
        XCTAssertGreaterThan(try XCTUnwrap(window.days), 0)
        XCTAssertEqual(try XCTUnwrap(later.first { $0.id == "match" }).whenText.isEmpty, false)

        while career.canPlay || career.canAdvanceWithoutPlaying { _ = career.simulateNextMatchDay() }
        XCTAssertNil(career.clockItems.first { $0.id == "season" }, "Temporada encerrada não tem contagem")
    }
}
