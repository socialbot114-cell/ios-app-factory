import SwiftUI

// MARK: - App Loja (módulos Pro)

/// Vitrine dos módulos pagos. Nesta versão a venda ainda não está ligada ao App Store: os cartões mostram o mistério
/// e o que vem, sem botão de compra e sem cobrança. O conteúdo e o preço ficam visíveis antes de qualquer compra.
struct FootballStoreView: View {
    /// Módulos já comprados. Vazio até a compra ser ligada ao StoreKit.
    var owned: Set<FootballProModule> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Módulos Pro",
                title: "Loja",
                subtitle: "Ferramentas que mostram o jogo por dentro. Cada módulo se compra uma vez.",
                accent: FootballTheme.gold
            )
            HStack(spacing: 12) {
                FactoryMetric(label: "Comprados", value: "\(owned.count)/\(FootballProModule.allCases.count)", symbol: "checkmark.seal.fill", tint: .green, animatesValue: true)
                FactoryMetric(label: "A partir de", value: Self.price(cheapestCents), symbol: "tag.fill", tint: FootballTheme.gold)
                FactoryMetric(label: "Até", value: Self.price(priciestCents), symbol: "crown.fill", tint: .purple)
            }
            .accessibilityIdentifier("store-metrics")
            ForEach(FootballProModule.allCases) { module in
                moduleCard(module)
            }
            Text("Prévia: os módulos ainda não estão à venda e nenhuma cobrança acontece nesta versão.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("store-footer")
        }
        .factoryPage()
        .navigationTitle("Loja")
        .accessibilityIdentifier("store-app")
    }

    /// Menor e maior preço da vitrine, para as métricas do topo.
    private var cheapestCents: Int { FootballProModule.allCases.map { $0.priceCents }.min() ?? 0 }
    private var priciestCents: Int { FootballProModule.allCases.map { $0.priceCents }.max() ?? 0 }

    private func moduleCard(_ module: FootballProModule) -> some View {
        let isOwned = owned.contains(module)
        let tint = Self.moduleTint(module)
        return FactoryPanel {
            moduleHeader(module, tint: tint)
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("O que vai ter".uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                ForEach(module.highlights, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(tint)
                            .accessibilityHidden(true)
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if module == .market {
                marketPreview(tint: tint)
            }
            Divider()
            HStack(alignment: .center) {
                if isOwned {
                    PillLabel(text: "Comprado", systemImage: "checkmark.seal.fill", tint: .green)
                } else {
                    PillLabel(text: "Em breve", systemImage: "lock.fill", tint: tint)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Preço proposto")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(Self.price(module.priceCents))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1)
        }
        .accessibilityIdentifier("store-module-\(module.rawValue)")
    }

    /// Cabeçalho do cartão no desenho das linhas da Academia: quadrado tingido com o ícone, nome e a frase de mistério.
    private func moduleHeader(_ module: FootballProModule, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: module.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 50, height: 50)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(module.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(module.teaser)
                    .font(.subheadline.weight(.semibold))
                    .italic()
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// Prévia borrada dos sinais do Market Pro: mostra que existe, sem revelar os nomes dos atletas.
    /// As barras têm o mesmo tamanho de propósito, para não sugerir valor nenhum.
    private func marketPreview(tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Self.marketSignals, id: \.self) { signal in
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                    Text(signal)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Capsule()
                        .fill(tint.opacity(0.4))
                        .frame(width: 96, height: 8)
                        .blur(radius: 3)
                }
            }
            Text("Os nomes dos atletas ficam ocultos nesta prévia.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prévia do Market Pro: \(Self.marketSignals.joined(separator: ", ")). Os nomes ficam ocultos.")
    }

    /// Os sinais que a prévia do Market Pro mostra, na ordem dela.
    private static let marketSignals = ["Em alta", "Subvalorizados", "Oportunidades"]

    /// Cor de cada módulo: ícone, frase, pílula e borda usam a mesma, para reconhecer o cartão de relance.
    private static func moduleTint(_ module: FootballProModule) -> Color {
        switch module {
        case .scout: return .blue
        case .analytics: return .indigo
        case .market: return FootballTheme.accent
        case .academy: return .teal
        case .medical: return .pink
        }
    }

    /// "R$ 4,90" no formato brasileiro. O valor fica em centavos no módulo.
    private static func price(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
    }
}
