import XCTest
@testable import AtelieColorir

final class AtelierProTests: XCTestCase {
    func testLibraryHasTwelveUniqueArtworks() {
        let all = AtelierLibrary.artworks
        XCTAssertEqual(all.count, 12)
        XCTAssertEqual(Set(all.map { $0.id }).count, 12)
        XCTAssertTrue(all.allSatisfy { $0.regionCount > 0 })
    }

    func testLegacyArtworkKeepsNineRegions() {
        let jardim = AtelierLibrary.artwork(id: "jardim-tracos")
        XCTAssertEqual(jardim.kind, .flower9)
        XCTAssertEqual(jardim.regionCount, 9)
    }

    func testPaletteHasTwelveNamedColors() {
        XCTAssertEqual(AtelierPalette.colors.count, 12)
        XCTAssertEqual(AtelierPalette.names.count, 12)
        XCTAssertEqual(AtelierPalette.fixedCount, 12)
    }

    func testEditingSessionFillUndoRedo() {
        var session = AtelierEditingSession(regionCount: 9)
        session.fill(region: 2, color: 4)
        XCTAssertEqual(session.fills[2], 4)
        session.fill(region: 2, color: 1)
        XCTAssertEqual(session.fills[2], 1)
        session.undo()
        XCTAssertEqual(session.fills[2], 4)
        XCTAssertTrue(session.canRedo)
        session.redo()
        XCTAssertEqual(session.fills[2], 1)
    }

    func testEditingSessionRejectsOutOfRange() {
        var session = AtelierEditingSession(regionCount: 9)
        session.fill(region: 40, color: 2)
        session.fill(region: 1, color: 99)
        XCTAssertTrue(session.fills.isEmpty)
        XCTAssertFalse(session.canUndo)
    }

    func testEditingSessionClearIsUndoable() {
        var session = AtelierEditingSession(regionCount: 16)
        session.fill(region: 0, color: 0)
        session.fill(region: 5, color: 3)
        session.clear()
        XCTAssertTrue(session.fills.isEmpty)
        session.undo()
        XCTAssertEqual(session.fills.count, 2)
    }

    func testStoreOpenOrCreateReusesInProgress() {
        let store = AtelierStore(loadImmediately: false)
        let first = store.openOrCreate(artworkId: "sol-alegre")
        store.updateFills(id: first.id, fills: [0: 1])
        let second = store.openOrCreate(artworkId: "sol-alegre")
        XCTAssertEqual(first.id, second.id)
    }

    func testStoreRenameDuplicateDeleteFavorite() {
        let store = AtelierStore(loadImmediately: false)
        let inst = store.createInstance(artworkId: "ipe-amarelo")
        store.rename(id: inst.id, title: "  Meu ipê  ")
        XCTAssertEqual(store.instances.first?.customTitle, "Meu ipê")
        store.toggleFavorite(id: inst.id)
        XCTAssertEqual(store.instances.first?.isFavorite, true)
        let copy = store.duplicate(id: inst.id)
        XCTAssertNotNil(copy)
        XCTAssertEqual(store.instances.count, 2)
        store.delete(id: inst.id)
        XCTAssertEqual(store.instances.count, 1)
    }

    func testStoreMigratesLegacyEngine() {
        let suite = UserDefaults(suiteName: "atelier.migration.test")!
        suite.removePersistentDomain(forName: "atelier.migration.test")
        var legacy = ColoringEngine()
        legacy.fill(region: 2, color: 4)
        legacy.persist(defaults: suite)
        let store = AtelierStore(loadImmediately: false)
        store.migrateLegacyIfNeeded(defaults: suite)
        XCTAssertEqual(store.instances.count, 1)
        XCTAssertEqual(store.instances.first?.artworkId, "jardim-tracos")
        XCTAssertEqual(store.instances.first?.fills[2], 4)
        suite.removePersistentDomain(forName: "atelier.migration.test")
    }

    func testPaletteTotalCountIncludesFourCustomSlots() {
        XCTAssertEqual(AtelierPalette.totalCount, 16)
        XCTAssertEqual(Array(AtelierPalette.customIndices), [12, 13, 14, 15])
        XCTAssertEqual(AtelierPalette.name(for: 12), "Personalizada 1")
        XCTAssertEqual(AtelierPalette.name(for: 15), "Personalizada 4")
    }

    func testSessionAcceptsCustomSlotColors() {
        var session = AtelierEditingSession(regionCount: 9)
        session.fill(region: 0, color: 15)
        XCTAssertEqual(session.fills[0], 15)
        session.fill(region: 1, color: 16)
        XCTAssertNil(session.fills[1])
    }

    func testSessionRestoreKeepsHistory() {
        var session = AtelierEditingSession(regionCount: 9, fills: [0: 1])
        session.restore(undo: [[0: 0]], redo: [[0: 2]])
        XCTAssertTrue(session.canUndo)
        XCTAssertTrue(session.canRedo)
        session.undo()
        XCTAssertEqual(session.fills[0], 0)
        session.redo()
        XCTAssertEqual(session.fills[0], 1)
    }

    func testLegacyInstanceJSONStillDecodes() throws {
        let old = """
        {"id":"\(UUID().uuidString)","artworkId":"jardim-tracos","fills":{"0":1},"isFavorite":true,
        "createdAt":718610400,"updatedAt":718610400,"totalSeconds":0}
        """.data(using: .utf8)!
        let inst = try JSONDecoder().decode(AtelierArtInstance.self, from: old)
        XCTAssertEqual(inst.fills[0], 1)
        XCTAssertTrue(inst.customColors.isEmpty)
        XCTAssertNil(inst.album)
        XCTAssertTrue(inst.history.isEmpty)
        XCTAssertTrue(inst.events.isEmpty)
    }

    func testEffectiveCustomColorsAlwaysFour() {
        let inst = AtelierArtInstance(artworkId: "sol-alegre")
        XCTAssertEqual(inst.effectiveCustomColors().count, 4)
    }

    func testStreakIncrementsOnConsecutiveDays() {
        let suite = UserDefaults(suiteName: "atelier.streak.test")!
        suite.removePersistentDomain(forName: "atelier.streak.test")
        AtelierStreak.touch(defaults: suite, today: "2026-09-25")
        XCTAssertEqual(AtelierStreak.current(defaults: suite), 1)
        AtelierStreak.touch(defaults: suite, today: "2026-09-25")
        XCTAssertEqual(AtelierStreak.current(defaults: suite), 1)
        AtelierStreak.touch(defaults: suite, today: "2026-09-26")
        XCTAssertEqual(AtelierStreak.current(defaults: suite), 2)
        AtelierStreak.touch(defaults: suite, today: "2026-09-30")
        XCTAssertEqual(AtelierStreak.current(defaults: suite), 1)
        suite.removePersistentDomain(forName: "atelier.streak.test")
    }

    func testArtworkOfTheDayIsDeterministic() {
        let day = Date(timeIntervalSince1970: 1_750_000_000)
        XCTAssertEqual(AtelierLibrary.artworkOfTheDay(today: day).id,
                       AtelierLibrary.artworkOfTheDay(today: day).id)
    }

    func testThumbCacheURLIsStable() {
        let id = UUID()
        XCTAssertEqual(AtelierThumbCache.fileURL(id: id).lastPathComponent, "\(id.uuidString).png")
    }

    func testStorePersistsHistoryAndAlbum() {
        let store = AtelierStore(loadImmediately: false)
        let inst = store.createInstance(artworkId: "sol-alegre")
        store.saveHistory(id: inst.id, undo: [[0: 1]], redo: [[0: 2]])
        store.setAlbum(id: inst.id, album: "Família")
        XCTAssertEqual(store.history(id: inst.id).undo, [[0: 1]])
        XCTAssertEqual(store.albums, ["Família"])
        store.setAlbum(id: inst.id, album: "  ")
        XCTAssertTrue(store.albums.isEmpty)
    }

    func testInstanceProgress() {
        let inst = AtelierArtInstance(artworkId: "jardim-tracos", fills: [0: 0, 1: 1, 2: 2])
        XCTAssertEqual(inst.progress(regionCount: 9), 3.0 / 9.0, accuracy: 0.001)
        XCTAssertEqual(inst.displayTitle(fallback: "Jardim"), "Jardim")
        let named = AtelierArtInstance(artworkId: "jardim-tracos", customTitle: "Presente p/ vó")
        XCTAssertEqual(named.displayTitle(fallback: "Jardim"), "Presente p/ vó")
    }
}
