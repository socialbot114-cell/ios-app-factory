import SwiftUI

/// Vitrine: carrossel de cartas com paralaxe, destaque da carta em foco e o cartão do dia gratuito.
struct ShowcaseView: View {
    @Environment(CollectionStore.self) private var collection
    @Environment(StoreModel.self) private var store
    @State private var focusID: String? = LegendCatalog.all.first?.id
    @State private var selected: LegendCard?
    @State private var showsPack: Bool

    init() {
        _selected = State(initialValue: FactoryCapture.screen == "detail" ? LegendCatalog.card(id: "garrincha") : nil)
        _showsPack = State(initialValue: FactoryCapture.screen == "pack")
    }

    private var focusCard: LegendCard {
        focusID.flatMap { LegendCatalog.card(id: $0) } ?? LegendCatalog.all[0]
    }

    var body: some View {
        ZStack {
            HallBackground()
            ScrollView {
                VStack(spacing: 22) {
                    header
                    dailyBanner
                    carousel
                    focusInfo
                }
                .padding(.vertical, 18)
            }
        }
        .fullScreenCover(item: $selected) { card in
            CardDetailView(card: card)
        }
        .fullScreenCover(isPresented: $showsPack) {
            DailyPackView()
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("HALL DAS LENDAS")
                .font(.system(size: 30, weight: .black, design: .serif))
                .tracking(3)
                .goldText()
                .accessibilityAddTraits(.isHeader)
            Text("\(collection.ownedCount) de \(LegendCatalog.all.count) lendas na sua coleção")
                .font(.subheadline)
                .foregroundStyle(HallColor.muted)
                .accessibilityIdentifier("showcase-progress")
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder private var dailyBanner: some View {
        if collection.canOpenDailyPack {
            Button { showsPack = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "gift.fill").font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cartão do dia · grátis").font(.headline)
                        Text("Abra e veja uma lenda por 24 horas.").font(.caption)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                }
                .foregroundStyle(Color.black.opacity(0.85))
                .padding(16)
                .background(LinearGradient(colors: [HallColor.goldLight, HallColor.gold, HallColor.goldDeep],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .accessibilityIdentifier("daily-pack-banner")
        } else if let loan = collection.activeLoan, let card = LegendCatalog.card(id: loan.cardID) {
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.checkmark.fill").foregroundStyle(HallColor.gold)
                Text("Cartão do dia: \(card.shortName) · acaba em")
                Text(loan.expires, style: .relative).monospacedDigit()
                Spacer()
            }
            .font(.footnote)
            .foregroundStyle(HallColor.muted)
            .hallPanel()
            .padding(.horizontal, 20)
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 20) {
                ForEach(LegendCatalog.all) { card in
                    Button { selected = card } label: {
                        LegendCardFace(card: card, locked: !collection.hasAccess(card.id))
                    }
                    .buttonStyle(.plain)
                    .containerRelativeFrame(.horizontal) { width, _ in width * 0.66 }
                    .id(card.id)
                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.8)
                            .rotation3DEffect(.degrees(phase.value * -28), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                            .opacity(phase.isIdentity ? 1 : 0.55)
                    }
                    .accessibilityIdentifier("showcase-card-\(card.id)")
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 18)
        }
        .scrollPosition(id: $focusID)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 40, for: .scrollContent)
    }

    private var focusInfo: some View {
        let card = focusCard
        let access = collection.hasAccess(card.id)
        return VStack(spacing: 12) {
            RarityBadge(rarity: card.rarity)
            Text(card.name)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("\(card.flag) \(card.country) · \(card.positionTitle) · geral \(card.overall)")
                .font(.subheadline)
                .foregroundStyle(HallColor.muted)
            HStack(spacing: 10) {
                ForEach(card.stats, id: \.label) { stat in
                    VStack(spacing: 2) {
                        Text("\(stat.value)").font(.headline.monospacedDigit().weight(.heavy)).goldText()
                        Text(stat.label).font(.caption2.weight(.bold)).foregroundStyle(HallColor.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .hallPanel()
            Button { selected = card } label: {
                Text(access ? "Ver carta" : (store.price(for: StoreCatalog.productID(for: card.id)).map { "Desbloquear · \($0)" } ?? "Ver detalhes"))
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(access ? Color.white : Color.black.opacity(0.85))
                    .background(access ? AnyShapeStyle(HallColor.panel) : AnyShapeStyle(HallColor.gold),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("showcase-open-detail")
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.2), value: focusID)
    }
}
