import Foundation
import Observation
import StoreKit

// MARK: - Produtos

/// Compras únicas e sem sorteio: cada produto entrega uma carta conhecida (ou todas, no pacote da coleção).
enum StoreCatalog {
    static let prefix = "br.com.socialbot114.factory.halldaslendas"
    static let completeID = "\(prefix).complete"

    static func productID(for cardID: String) -> String { "\(prefix).card.\(cardID)" }

    static func cardID(forProduct productID: String) -> String? {
        let head = "\(prefix).card."
        guard productID.hasPrefix(head) else { return nil }
        let id = String(productID.dropFirst(head.count))
        return LegendCatalog.card(id: id) == nil ? nil : id
    }

    static var allIDs: [String] {
        LegendCatalog.all.map { productID(for: $0.id) } + [completeID]
    }
}

struct StoreProduct: Equatable {
    let id: String
    let displayPrice: String
}

enum PurchaseOutcome: Equatable {
    case success
    case cancelled
    case pending
    case failed(String)
}

protocol PurchaseProviding {
    func loadProducts(ids: [String]) async -> [String: StoreProduct]
    func purchase(id: String) async -> PurchaseOutcome
    func restore() async -> [String]
    func currentEntitlements() async -> [String]
    func updates() -> AsyncStream<String>
}

// MARK: - StoreKit 2

final class StoreKitProvider: PurchaseProviding {
    private var products: [String: Product] = [:]

    func loadProducts(ids: [String]) async -> [String: StoreProduct] {
        guard let list = try? await Product.products(for: ids) else { return [:] }
        var result: [String: StoreProduct] = [:]
        for product in list {
            products[product.id] = product
            result[product.id] = StoreProduct(id: product.id, displayPrice: product.displayPrice)
        }
        return result
    }

    func purchase(id: String) async -> PurchaseOutcome {
        guard let product = products[id] else { return .failed("Produto indisponível no momento.") }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return .success
                case .unverified:
                    return .failed("Não foi possível verificar a compra.")
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Resultado de compra desconhecido.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async -> [String] {
        try? await AppStore.sync()
        return await currentEntitlements()
    }

    func currentEntitlements() async -> [String] {
        var ids: [String] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result { ids.append(transaction.productID) }
        }
        return ids
    }

    func updates() -> AsyncStream<String> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                        continuation.yield(transaction.productID)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Simulado (testes, capturas e prévias)

/// Compra instantânea e em memória; não toca na App Store.
final class MockPurchaseProvider: PurchaseProviding {
    private var entitled: Set<String> = []
    private let prices: [String: String]
    var nextOutcome: PurchaseOutcome = .success

    init() {
        var table: [String: String] = [:]
        for card in LegendCatalog.all {
            table[StoreCatalog.productID(for: card.id)] = card.rarity == .eternal ? "R$ 14,90" : (card.rarity == .legendary ? "R$ 11,90" : "R$ 8,90")
        }
        table[StoreCatalog.completeID] = "R$ 49,90"
        prices = table
    }

    func loadProducts(ids: [String]) async -> [String: StoreProduct] {
        var result: [String: StoreProduct] = [:]
        for id in ids {
            if let price = prices[id] { result[id] = StoreProduct(id: id, displayPrice: price) }
        }
        return result
    }

    func purchase(id: String) async -> PurchaseOutcome {
        guard prices[id] != nil else { return .failed("Produto indisponível no momento.") }
        if nextOutcome == .success { entitled.insert(id) }
        return nextOutcome
    }

    func restore() async -> [String] { Array(entitled) }
    func currentEntitlements() async -> [String] { Array(entitled) }
    func updates() -> AsyncStream<String> { AsyncStream { $0.finish() } }
}

// MARK: - Modelo da loja

@Observable
final class StoreModel {
    private(set) var products: [String: StoreProduct] = [:]
    private(set) var busyProductID: String?
    private(set) var didLoadProducts = false
    var message: String?
    /// Carta recém-entregue por uma compra: a tela mostra a comemoração e limpa o valor.
    var celebration: LegendCard?

    @ObservationIgnored private let provider: PurchaseProviding
    @ObservationIgnored private let collection: CollectionStore
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(provider: PurchaseProviding, collection: CollectionStore) {
        self.provider = provider
        self.collection = collection
    }

    deinit { updatesTask?.cancel() }

    func price(for productID: String) -> String? {
        products[productID]?.displayPrice
    }

    @MainActor
    func start() async {
        if updatesTask == nil {
            let stream = provider.updates()
            updatesTask = Task { @MainActor [weak self] in
                for await productID in stream { self?.apply(productIDs: [productID], source: .purchase) }
            }
        }
        products = await provider.loadProducts(ids: StoreCatalog.allIDs)
        didLoadProducts = true
        apply(productIDs: await provider.currentEntitlements(), source: .restored)
    }

    @MainActor
    func buy(productID: String) async {
        guard busyProductID == nil else { return }
        busyProductID = productID
        defer { busyProductID = nil }
        switch await provider.purchase(id: productID) {
        case .success:
            apply(productIDs: [productID], source: .purchase)
        case .cancelled:
            break
        case .pending:
            message = "Compra pendente de aprovação. A carta chega assim que for liberada."
        case .failed(let reason):
            message = reason
        }
    }

    @MainActor
    func restore() async {
        let ids = await provider.restore()
        let before = collection.ownedCount
        apply(productIDs: ids, source: .restored, celebrate: false)
        let restored = collection.ownedCount - before
        message = restored > 0 ? "\(restored) compra(s) restaurada(s)." : "Nenhuma compra nova para restaurar."
    }

    /// Entrega ao usuário o que cada produto liberou; repetir a chamada não duplica nada.
    @MainActor
    private func apply(productIDs: [String], source: CollectionStore.Source, celebrate: Bool = true) {
        for productID in productIDs {
            if productID == StoreCatalog.completeID {
                for card in LegendCatalog.all { collection.grant(card.id, source: source) }
            } else if let cardID = StoreCatalog.cardID(forProduct: productID),
                      collection.grant(cardID, source: source) != nil, celebrate, source == .purchase {
                celebration = LegendCatalog.card(id: cardID)
            }
        }
    }
}
