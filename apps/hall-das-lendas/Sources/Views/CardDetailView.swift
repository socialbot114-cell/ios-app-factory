import SwiftUI

/// Detalhe da carta: inclinação 3D com brilho, números animados, história e a compra única quando ainda é bloqueada.
struct CardDetailView: View {
    let card: LegendCard
    @Environment(CollectionStore.self) private var collection
    @Environment(StoreModel.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var barsVisible = false

    private var productID: String { StoreCatalog.productID(for: card.id) }
    private var access: Bool { collection.hasAccess(card.id) }

    var body: some View {
        ZStack {
            HallBackground()
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill").font(.title).symbolRenderingMode(.hierarchical).foregroundStyle(.white)
                        }
                        .accessibilityLabel("Fechar")
                        .accessibilityIdentifier("detail-close")
                    }
                    if access {
                        TiltCard(card: card, width: 270)
                    } else {
                        LegendCardFace(card: card, width: 270, locked: true)
                    }
                    RarityBadge(rarity: card.rarity)
                    VStack(spacing: 4) {
                        Text(card.name)
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("detail-name")
                        Text("\(card.flag) \(card.country) · \(card.positionTitle) · geral \(card.overall)")
                            .font(.subheadline).foregroundStyle(HallColor.muted)
                    }
                    statBars
                    Text(card.blurb)
                        .font(.callout)
                        .foregroundStyle(Color.white.opacity(0.82))
                        .hallPanel()
                    ownership
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            CelebrationLayer()
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9).delay(0.15)) { barsVisible = true } }
    }

    private var statBars: some View {
        VStack(spacing: 10) {
            ForEach(card.stats, id: \.label) { stat in
                HStack(spacing: 10) {
                    Text(stat.label).font(.caption.weight(.bold)).foregroundStyle(HallColor.muted).frame(width: 34, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Capsule()
                                .fill(LinearGradient(colors: card.rarity.glow, startPoint: .leading, endPoint: .trailing))
                                .frame(width: barsVisible ? proxy.size.width * CGFloat(stat.value) / 99 : 0)
                        }
                    }
                    .frame(height: 8)
                    Text("\(stat.value)").font(.footnote.monospacedDigit().weight(.heavy)).foregroundStyle(.white).frame(width: 28, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(stat.label) \(stat.value)")
            }
        }
        .hallPanel()
    }

    @ViewBuilder private var ownership: some View {
        if let owned = collection.ownedCard(card.id) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Na sua coleção", systemImage: "checkmark.seal.fill").font(.headline).goldText()
                Text("Seu exemplar nº \(String(format: "%04d", owned.serial))")
                    .font(.subheadline).foregroundStyle(.white).accessibilityIdentifier("detail-serial")
                Text("Adquirida em \(owned.acquired.formatted(date: .long, time: .omitted))")
                    .font(.footnote).foregroundStyle(HallColor.muted)
            }
            .hallPanel()
            .accessibilityIdentifier("detail-owned")
        } else {
            VStack(spacing: 12) {
                if let loan = collection.activeLoan, loan.cardID == card.id {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.checkmark.fill").foregroundStyle(HallColor.gold)
                        Text("Cartão do dia: disponível por mais")
                        Text(loan.expires, style: .relative).monospacedDigit()
                        Spacer()
                    }
                    .font(.footnote).foregroundStyle(HallColor.muted)
                }
                purchaseButton
                Text("Compra única. Você recebe exatamente esta carta, sem sorteio.")
                    .font(.caption).foregroundStyle(HallColor.muted).multilineTextAlignment(.center)
            }
        }
    }

    private var purchaseButton: some View {
        let price = store.price(for: productID)
        let busy = store.busyProductID == productID
        return Button {
            Task { await store.buy(productID: productID) }
        } label: {
            HStack(spacing: 10) {
                if busy { ProgressView().tint(.black) }
                Text(price.map { "Desbloquear por \($0)" } ?? "Loja indisponível no momento")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(Color.black.opacity(0.88))
            .background(LinearGradient(colors: [HallColor.goldLight, HallColor.gold, HallColor.goldDeep], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(price == nil ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(price == nil || store.busyProductID != nil)
        .accessibilityIdentifier("buy-\(card.id)")
    }
}
