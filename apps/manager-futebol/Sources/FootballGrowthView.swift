import SwiftUI

// MARK: - Marketing, TV e cotas

struct FootballGrowthView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    private var growth: GrowthState { career.world.growth }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                FactoryMetric(label: "Força da marca", value: "\(growth.brand)", symbol: "sparkles", tint: FootballTheme.gold)
                FactoryMetric(label: "Torcida", value: FootballFormat.compact(career.fanBase), symbol: "person.3.fill", tint: FootballTheme.accent)
            }
            pressurePanel
            tvPanel
            campaignPanel
            slotsPanel
        }
        .factoryPage()
        .navigationTitle("Marketing e TV")
    }

    // MARK: Pressão

    private var pressurePanel: some View {
        FactoryPanel(title: "Pressão da torcida: \(career.pressureLabel)", systemImage: "flame.fill") {
            ConditionBar(value: 100 - career.fanPressure)
            Text("Posição na tabela contra a meta, humor da torcida, últimos resultados e prestígio do clube. Pressão alta estressa você e abala atletas menos determinados. Em casa, estádio feliz e cheio empurra o time.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: TV

    private var tvPanel: some View {
        FactoryPanel(title: "Cotas de TV", systemImage: "tv.fill") {
            if let tv = growth.tv {
                Text(tv.kind.title).font(.subheadline.weight(.bold))
                Text("\(FootballFormat.money(career.tvIncomePerMatchDay)) por jogo" + (tv.winBonus > 0 ? " + \(FootballFormat.money(tv.winBonus)) por vitória" : "") + " · até a T\(tv.endSeason)")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Escolha o contrato antes do primeiro jogo. Se não escolher, o clube assina a cota fixa.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(growth.tvOffers) { offer in
                HStack(spacing: 12) {
                    Image(systemName: offer.kind.symbol).frame(width: 26).foregroundStyle(FootballTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.kind.title).font(.subheadline.weight(.semibold))
                        Text(offer.kind.summary).font(.caption).foregroundStyle(.secondary)
                        Text("Garantido \(FootballFormat.money(Int(Double(career.baseTVPerMatchDay) * offer.baseFactor)))/jogo" + (offer.winBonus > 0 ? " · \(FootballFormat.money(offer.winBonus))/vitória" : "") + " · \(offer.seasons) temp.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Assinar") { career.signTV(offerID: offer.id) }
                        .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                        .accessibilityIdentifier("tv-\(offer.kind.rawValue)")
                }
            }
        }
    }

    // MARK: Marketing

    private var campaignPanel: some View {
        FactoryPanel(title: "Campanhas de marketing", systemImage: "megaphone.fill") {
            if let campaign = growth.campaign {
                Label("\(campaign.kind.title) em andamento: termina no dia \(campaign.endsWorldDay)", systemImage: "hourglass").font(.subheadline.weight(.semibold))
            }
            ForEach(MarketingCampaign.allCases) { kind in
                let block = career.canStartCampaign(kind)
                Button {
                    if !career.startCampaign(kind) { onAlert(block ?? "Indisponível.") }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: kind.symbol).frame(width: 26).foregroundStyle(FootballTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text(kind.summary).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                            Text("\(FootballFormat.money(kind.cost)) · \(kind.days) jogos").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(block == nil ? 1 : 0.45)
                .accessibilityIdentifier("campaign-\(kind.rawValue)")
            }
        }
    }

    // MARK: Cotas de patrocínio

    private var slotsPanel: some View {
        FactoryPanel(title: "Cotas de patrocínio", systemImage: "rectangle.3.group.fill") {
            Text("Além do patrocinador master: receita extra de \(FootballFormat.money(career.slotIncomePerSeason)) por temporada.").font(.caption).foregroundStyle(.secondary)
            ForEach(growth.slotDeals) { deal in
                HStack {
                    Image(systemName: deal.slot.symbol).frame(width: 26).foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(deal.slot.title) · \(deal.sponsor)").font(.subheadline.weight(.semibold))
                        Text("\(FootballFormat.money(deal.perSeason))/temporada · até a T\(deal.endSeason)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(growth.slotOffers) { offer in
                HStack {
                    Image(systemName: offer.slot.symbol).frame(width: 26).foregroundStyle(FootballTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(offer.slot.title) · \(offer.sponsor)").font(.subheadline.weight(.semibold))
                        Text("\(FootballFormat.money(offer.perSeason))/temporada · \(offer.seasons) temp.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Fechar") { career.acceptSlotOffer(offer.id) }
                        .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                }
            }
            if growth.slotDeals.isEmpty && growth.slotOffers.isEmpty {
                Text("Sem propostas agora. Novas cotas aparecem a cada temporada.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
