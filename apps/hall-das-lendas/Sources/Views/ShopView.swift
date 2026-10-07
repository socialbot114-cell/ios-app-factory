import SwiftUI

/// Loja: pacote com toda a coleção e cada lenda à parte. Tudo é compra única e sem sorteio; a compra pode ser restaurada.
struct ShopView: View {
    @Environment(CollectionStore.self) private var collection
    @Environment(StoreModel.self) private var store

    var body: some View {
        ZStack {
            HallBackground()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("LOJA").font(.system(size: 28, weight: .black, design: .serif)).tracking(4).goldText()
                            .accessibilityAddTraits(.isHeader)
                        Text("Compras únicas. Você sabe qual carta recebe antes de pagar.")
                            .font(.footnote).foregroundStyle(HallColor.muted).multilineTextAlignment(.center)
                    }
                    bundleHero
                    VStack(spacing: 12) {
                        ForEach(LegendCatalog.all.sorted { $0.overall > $1.overall }) { card in
                            row(card)
                        }
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .alert("Loja", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.message ?? "")
        }
    }

    // MARK: Pacote da coleção

    private var bundleHero: some View {
        let price = store.price(for: StoreCatalog.completeID)
        let busy = store.busyProductID == StoreCatalog.completeID
        return VStack(spacing: 16) {
            ZStack {
                ForEach(Array(LegendCatalog.all.enumerated()), id: \.element.id) { index, card in
                    let offset = Double(index) - Double(LegendCatalog.all.count - 1) / 2
                    LegendCardFace(card: card, width: 92, locked: false)
                        .rotationEffect(.degrees(offset * 9))
                        .offset(x: CGFloat(offset) * 34, y: abs(CGFloat(offset)) * 6)
                        .zIndex(Double(LegendCatalog.all.count) - abs(offset))
                }
            }
            .frame(height: 150)
            .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("Coleção Eterna").font(.system(size: 22, weight: .bold, design: .serif)).foregroundStyle(.white)
                Text("As \(LegendCatalog.all.count) lendas de uma vez. Quem já tem algumas paga só pelo pacote.")
                    .font(.footnote).foregroundStyle(HallColor.muted).multilineTextAlignment(.center)
            }
            if collection.isComplete {
                Label("Coleção completa", systemImage: "checkmark.seal.fill").font(.headline).goldText()
                    .accessibilityIdentifier("owned-complete")
            } else {
                Button {
                    Task { await store.buy(productID: StoreCatalog.completeID) }
                } label: {
                    HStack(spacing: 10) {
                        if busy { ProgressView().tint(.black) }
                        Text(price.map { "Levar tudo por \($0)" } ?? "Indisponível no momento").font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(Color.black.opacity(0.88))
                    .background(LinearGradient(colors: [HallColor.goldLight, HallColor.gold, HallColor.goldDeep], startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(price == nil ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .disabled(price == nil || store.busyProductID != nil)
                .accessibilityIdentifier("buy-complete")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(HallColor.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(LinearGradient(colors: [HallColor.goldLight.opacity(0.7), HallColor.goldDeep.opacity(0.2)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
    }

    // MARK: Cartas

    private func row(_ card: LegendCard) -> some View {
        let productID = StoreCatalog.productID(for: card.id)
        let owned = collection.isOwned(card.id)
        let price = store.price(for: productID)
        let busy = store.busyProductID == productID
        return HStack(spacing: 14) {
            LegendCardFace(card: card, width: 56, locked: false)
            VStack(alignment: .leading, spacing: 5) {
                Text(card.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                RarityBadge(rarity: card.rarity)
            }
            Spacer(minLength: 8)
            if owned {
                Label("Na coleção", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold)).foregroundStyle(HallColor.gold)
                    .accessibilityIdentifier("owned-\(card.id)")
            } else {
                Button {
                    Task { await store.buy(productID: productID) }
                } label: {
                    Group {
                        if busy { ProgressView().tint(.black) } else { Text(price ?? "—").font(.footnote.weight(.bold)) }
                    }
                    .frame(minWidth: 74, minHeight: 36)
                    .padding(.horizontal, 10)
                    .foregroundStyle(Color.black.opacity(0.88))
                    .background(HallColor.gold, in: Capsule())
                    .opacity(price == nil ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .disabled(price == nil || store.busyProductID != nil)
                .accessibilityLabel("Comprar \(card.shortName)")
                .accessibilityIdentifier("buy-\(card.id)")
            }
        }
        .hallPanel()
    }

    // MARK: Rodapé

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Task { await store.restore() }
            } label: {
                Text("Restaurar compras").font(.subheadline.weight(.semibold)).goldText()
            }
            .accessibilityIdentifier("restore-purchases")
            Text("Pagamento processado pela App Store. Compras restauráveis em qualquer aparelho com o mesmo Apple ID. O cartão do dia é gratuito e temporário.")
                .font(.caption2).foregroundStyle(HallColor.muted).multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }
}
