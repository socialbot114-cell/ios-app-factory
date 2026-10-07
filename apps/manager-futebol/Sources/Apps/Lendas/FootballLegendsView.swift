import SwiftUI

// MARK: - App Lendas

/// App dedicado aos craques eternos: pacote esperando, craque da temporada e a vitrine das seis cartas.
struct FootballLegendsView: View {
    @Binding var career: FootballCareer
    @State private var showsPack = false
    @State private var selected: IconCard?

    private var collected: Set<IconCard> {
        var set = Set(career.iconState.collected)
        if let season = career.iconState.seasonIcon { set.insert(season) }
        return set
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Craques eternos",
                title: "Lendas",
                subtitle: "Uma lenda chega quando a carreira começa e outra a cada fim de temporada. Cada uma joga o ano inteiro com você.",
                accent: FootballTheme.gold
            )
            if career.iconState.pendingPack != nil && !career.isFired { packBanner }
            if let icon = career.iconState.seasonIcon { seasonRow(icon) }
            HStack {
                Text("COLEÇÃO").font(.caption.weight(.heavy)).tracking(1.4).foregroundStyle(.secondary)
                Spacer()
                Text("\(collected.count) de \(IconCard.allCases.count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("legends-count")
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(IconCard.allCases) { card in
                    cell(card)
                }
            }
            Text("As lendas não podem ser vendidas nem dispensadas e não têm salário.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .factoryPage()
        .navigationTitle("Lendas")
        .fullScreenCover(isPresented: $showsPack) {
            FootballIconPackView(career: $career) { showsPack = false }
        }
        .sheet(item: $selected) { card in
            FootballLegendDetail(card: card, unlocked: collected.contains(card), isSeason: career.iconState.seasonIcon == card)
                .presentationDetents([.large])
        }
        .accessibilityIdentifier("legends-app")
    }

    private var packBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Pacote de craque eterno", systemImage: "gift.fill").font(.headline)
            Text("Chegou um pacote. Abra para descobrir quem joga com você.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { showsPack = true } label: {
                Label("Abrir pacote", systemImage: "sparkles").frame(maxWidth: .infinity)
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .accessibilityIdentifier("legends-open-pack")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FootballTheme.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(FootballTheme.gold.opacity(0.6), lineWidth: 1.5)
        }
    }

    private func seasonRow(_ icon: IconCard) -> some View {
        Button { selected = icon } label: {
            HStack(spacing: 14) {
                Image(icon.assetName)
                    .resizable().scaledToFit()
                    .frame(width: 64, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("JOGA ESTA TEMPORADA").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(FootballTheme.gold)
                    Text(icon.name).font(.headline).foregroundStyle(.primary).lineLimit(2)
                    Text("\(icon.detail.title) · geral \(icon.overall)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("legends-season")
    }

    private func cell(_ card: IconCard) -> some View {
        let unlocked = collected.contains(card)
        return Button { selected = card } label: {
            VStack(spacing: 8) {
                ZStack {
                    Image(card.assetName)
                        .resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .saturation(unlocked ? 1 : 0)
                        .brightness(unlocked ? 0 : -0.55)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    if !unlocked {
                        Image(systemName: "lock.fill").font(.title).foregroundStyle(.white.opacity(0.85))
                    }
                }
                Text(unlocked ? card.shortName : "Bloqueada")
                    .font(.footnote.weight(.semibold)).foregroundStyle(unlocked ? Color.primary : Color.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unlocked ? "\(card.name), desbloqueada" : "Lenda bloqueada")
        .accessibilityIdentifier("legends-card-\(card.rawValue)")
    }
}

// MARK: - Detalhe da carta

struct FootballLegendDetail: View {
    let card: IconCard
    let unlocked: Bool
    let isSeason: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(card.assetName)
                        .resizable().scaledToFit()
                        .frame(maxWidth: 260)
                        .saturation(unlocked ? 1 : 0)
                        .brightness(unlocked ? 0 : -0.55)
                        .shadow(color: FootballTheme.gold.opacity(unlocked ? 0.4 : 0), radius: 18)
                    if unlocked {
                        Text(card.name).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                        Text("\(card.detail.title) · \(card.country) · geral \(card.overall)")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if isSeason {
                            Label("Joga com você nesta temporada", systemImage: "checkmark.seal.fill")
                                .font(.footnote.weight(.semibold)).foregroundStyle(FootballTheme.gold)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(Array(card.stats.enumerated()), id: \.offset) { _, stat in
                                VStack(spacing: 2) {
                                    Text("\(stat.value)").font(.title3.weight(.heavy))
                                    Text(stat.label).font(.caption2).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    } else {
                        Text("Lenda bloqueada").font(.title2.weight(.bold))
                        Text("Ela chega em um dos próximos pacotes: um no começo da carreira e outro a cada fim de temporada.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(unlocked ? card.shortName : "Bloqueada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fechar") { dismiss() } } }
        }
    }
}
