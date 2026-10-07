import SwiftUI

/// Coleção: progresso em anel, filtro por raridade e grade com as cartas (bloqueadas aparecem em silhueta).
struct CollectionView: View {
    @Environment(CollectionStore.self) private var collection
    @State private var filter: LegendRarity?
    @State private var selected: LegendCard?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var cards: [LegendCard] {
        LegendCatalog.all
            .filter { filter == nil || $0.rarity == filter }
            .sorted { $0.overall == $1.overall ? $0.name < $1.name : $0.overall > $1.overall }
    }

    private var progress: Double {
        Double(collection.ownedCount) / Double(max(1, LegendCatalog.all.count))
    }

    var body: some View {
        ZStack {
            HallBackground()
            ScrollView {
                VStack(spacing: 20) {
                    progressHeader
                    filterBar
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(cards) { card in
                            let access = collection.hasAccess(card.id)
                            Button { selected = card } label: {
                                VStack(spacing: 8) {
                                    LegendCardFace(card: card, locked: !access)
                                    Text(card.shortName).font(.footnote.weight(.semibold)).foregroundStyle(.white)
                                    RarityBadge(rarity: card.rarity)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("collection-card-\(card.id)")
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 18)
            }
        }
        .fullScreenCover(item: $selected) { card in
            CardDetailView(card: card)
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(LinearGradient(colors: [HallColor.goldLight, HallColor.goldDeep], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: progress)
                Text("\(collection.ownedCount)/\(LegendCatalog.all.count)")
                    .font(.headline.monospacedDigit().weight(.heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text("Minha coleção").font(.title3.weight(.bold)).foregroundStyle(.white)
                Text(collection.isComplete ? "Coleção completa. Todas as lendas estão com você." : "Desbloqueie as lendas que faltam na loja.")
                    .font(.footnote).foregroundStyle(HallColor.muted)
            }
            Spacer()
        }
        .hallPanel()
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("collection-progress")
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(title: "Todas", rarity: nil)
                ForEach(LegendRarity.allCases.reversed(), id: \.rawValue) { rarity in
                    chip(title: rarity.title, rarity: rarity)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chip(title: String, rarity: LegendRarity?) -> some View {
        let active = filter == rarity
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { filter = rarity }
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(active ? Color.black.opacity(0.85) : Color.white)
                .background(active ? AnyShapeStyle(HallColor.gold) : AnyShapeStyle(HallColor.panel), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier("collection-filter-\(rarity?.title ?? "todas")")
    }
}
