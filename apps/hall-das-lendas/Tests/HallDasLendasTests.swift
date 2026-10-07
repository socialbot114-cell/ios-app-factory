import Foundation
import XCTest
@testable import HallDasLendas

final class HallDasLendasTests: XCTestCase {
    private func makeStore(now: @escaping () -> Date = Date.init) -> (CollectionStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "hall.tests.\(UUID().uuidString)")!
        return (CollectionStore(defaults: defaults, now: now), defaults)
    }

    // MARK: Catálogo

    func testCatalogHasSixCardsWithUniqueIDsAndRarityFromOverall() {
        XCTAssertEqual(LegendCatalog.all.count, 6)
        XCTAssertEqual(Set(LegendCatalog.all.map(\.id)).count, 6)
        XCTAssertEqual(Set(LegendCatalog.all.map(\.assetName)).count, 6)
        XCTAssertTrue(LegendCatalog.all.allSatisfy { $0.stats.count == 6 })
        XCTAssertEqual(LegendCatalog.card(id: "garrincha")?.rarity, .eternal)
        XCTAssertEqual(LegendCatalog.card(id: "beckenbauer")?.rarity, .legendary)
        XCTAssertEqual(LegendCatalog.card(id: "zagallo")?.rarity, .gold)
        XCTAssertLessThan(LegendRarity.gold, LegendRarity.eternal)
    }

    func testProductIDsMapBackToCards() {
        XCTAssertEqual(StoreCatalog.allIDs.count, 7)
        XCTAssertEqual(Set(StoreCatalog.allIDs).count, 7)
        for card in LegendCatalog.all {
            XCTAssertEqual(StoreCatalog.cardID(forProduct: StoreCatalog.productID(for: card.id)), card.id)
        }
        XCTAssertNil(StoreCatalog.cardID(forProduct: StoreCatalog.completeID))
        XCTAssertNil(StoreCatalog.cardID(forProduct: "outro.produto"))
    }

    // MARK: Coleção

    func testGrantIsIdempotentAndNumbersCopiesInOrder() throws {
        let (store, _) = makeStore()
        let first = try XCTUnwrap(store.grant("yashin", source: .purchase))
        let second = try XCTUnwrap(store.grant("eusebio", source: .purchase))
        XCTAssertEqual(first.serial, 1)
        XCTAssertEqual(second.serial, 2)
        XCTAssertNil(store.grant("yashin", source: .restored), "Restaurar de novo não duplica a carta")
        XCTAssertNil(store.grant("desconhecida", source: .purchase))
        XCTAssertEqual(store.ownedCount, 2)
        XCTAssertTrue(store.isOwned("yashin"))
        XCTAssertFalse(store.isComplete)
    }

    func testCollectionSurvivesRelaunch() throws {
        let (store, defaults) = makeStore()
        store.grant("zagallo", source: .purchase)
        let reloaded = CollectionStore(defaults: defaults)
        XCTAssertEqual(reloaded.owned, store.owned)
        XCTAssertEqual(try XCTUnwrap(reloaded.grant("charlton", source: .purchase)).serial, 2, "A numeração continua de onde parou")
    }

    func testDailyPackLoansAnUnownedCardForADayAndOnlyOncePerDay() throws {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let (store, _) = makeStore(now: { clock })
        store.grant("yashin", source: .purchase)
        var generator = SeededGenerator(seed: 3)
        let card = try XCTUnwrap(store.openDailyPack(using: &generator))
        XCTAssertNotEqual(card.id, "yashin", "O cartão do dia nunca repete uma carta que o usuário já tem")
        XCTAssertTrue(store.hasAccess(card.id))
        XCTAssertFalse(store.isOwned(card.id))
        XCTAssertFalse(store.canOpenDailyPack)
        XCTAssertNil(store.openDailyPack(using: &generator))

        clock = clock.addingTimeInterval(CollectionStore.loanDuration + 60)
        XCTAssertFalse(store.hasAccess(card.id), "Depois de 24 horas o cartão volta a ficar bloqueado")
        XCTAssertTrue(store.canOpenDailyPack)
    }

    func testBuyingTheLoanedCardClearsTheLoan() throws {
        let (store, _) = makeStore()
        var generator = SeededGenerator(seed: 11)
        let card = try XCTUnwrap(store.openDailyPack(using: &generator))
        XCTAssertNotNil(store.activeLoan)
        store.grant(card.id, source: .purchase)
        XCTAssertNil(store.activeLoan)
        XCTAssertTrue(store.isOwned(card.id))
    }

    func testCompleteCollectionClosesTheDailyPack() {
        let (store, _) = makeStore()
        for card in LegendCatalog.all { store.grant(card.id, source: .purchase) }
        XCTAssertTrue(store.isComplete)
        XCTAssertFalse(store.canOpenDailyPack)
        XCTAssertNil(store.openDailyPack())
    }

    // MARK: Loja

    @MainActor
    func testBuyingACardGrantsItAndCelebrates() async throws {
        let (collection, _) = makeStore()
        let model = StoreModel(provider: MockPurchaseProvider(), collection: collection)
        await model.start()
        XCTAssertNotNil(model.price(for: StoreCatalog.productID(for: "yashin")))
        await model.buy(productID: StoreCatalog.productID(for: "yashin"))
        XCTAssertTrue(collection.isOwned("yashin"))
        XCTAssertEqual(model.celebration?.id, "yashin")
        XCTAssertNil(model.busyProductID)
    }

    @MainActor
    func testBuyingTheCompleteBundleGrantsEverything() async {
        let (collection, _) = makeStore()
        let model = StoreModel(provider: MockPurchaseProvider(), collection: collection)
        await model.start()
        await model.buy(productID: StoreCatalog.completeID)
        XCTAssertTrue(collection.isComplete)
    }

    @MainActor
    func testCancelledAndFailedPurchasesGrantNothing() async {
        let (collection, _) = makeStore()
        let provider = MockPurchaseProvider()
        let model = StoreModel(provider: provider, collection: collection)
        await model.start()
        provider.nextOutcome = .cancelled
        await model.buy(productID: StoreCatalog.productID(for: "zagallo"))
        XCTAssertEqual(collection.ownedCount, 0)
        XCTAssertNil(model.message)
        provider.nextOutcome = .failed("Sem conexão")
        await model.buy(productID: StoreCatalog.productID(for: "zagallo"))
        XCTAssertEqual(collection.ownedCount, 0)
        XCTAssertEqual(model.message, "Sem conexão")
    }

    @MainActor
    func testRestoreBringsBackEntitledCardsWithoutCelebration() async {
        let (first, _) = makeStore()
        let provider = MockPurchaseProvider()
        let model = StoreModel(provider: provider, collection: first)
        await model.start()
        await model.buy(productID: StoreCatalog.productID(for: "charlton"))

        let (fresh, _) = makeStore()
        let other = StoreModel(provider: provider, collection: fresh)
        await other.restore()
        XCTAssertTrue(fresh.isOwned("charlton"))
        XCTAssertNil(other.celebration)
        XCTAssertEqual(other.message, "1 compra(s) restaurada(s).")
        await other.restore()
        XCTAssertEqual(other.message, "Nenhuma compra nova para restaurar.")
    }
}
