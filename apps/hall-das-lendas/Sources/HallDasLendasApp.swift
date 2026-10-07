import SwiftUI

@main
struct HallDasLendasApp: App {
    @State private var collection: CollectionStore
    @State private var store: StoreModel

    init() {
        if FactoryCapture.isUITesting { FactoryCapture.resetAppDefaults() }
        let collection = CollectionStore()
        let simulated = FactoryCapture.isUITesting || FactoryCapture.screen != nil
        if FactoryCapture.screen != nil { collection.seedForDemo(ownedIDs: ["yashin", "garrincha"]) }
        _collection = State(initialValue: collection)
        _store = State(initialValue: StoreModel(provider: simulated ? MockPurchaseProvider() : StoreKitProvider(), collection: collection))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(collection)
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(HallColor.gold)
        }
    }
}

struct RootView: View {
    private enum Tab: Hashable { case showcase, collection, shop }

    @Environment(StoreModel.self) private var store
    @State private var tab: Tab

    init() {
        switch FactoryCapture.screen {
        case "collection": _tab = State(initialValue: .collection)
        case "shop": _tab = State(initialValue: .shop)
        default: _tab = State(initialValue: .showcase)
        }
    }

    var body: some View {
        ZStack {
            TabView(selection: $tab) {
                ShowcaseView()
                    .tabItem { Label("Vitrine", systemImage: "sparkles") }
                    .tag(Tab.showcase)
                CollectionView()
                    .tabItem { Label("Coleção", systemImage: "square.grid.2x2.fill") }
                    .tag(Tab.collection)
                ShopView()
                    .tabItem { Label("Loja", systemImage: "bag.fill") }
                    .tag(Tab.shop)
            }
            CelebrationLayer()
        }
        .task { await store.start() }
    }
}
