import SwiftUI

// MARK: - App Loja (módulos Pro)

/// Vitrine dos módulos pagos. Nesta versão a venda ainda não está ligada ao App Store: os cartões mostram o mistério
/// e o que vem, sem botão de compra e sem cobrança. O conteúdo e o preço ficam visíveis antes de qualquer compra.
struct FootballStoreView: View {
    /// Módulos já comprados. Vazio até a compra ser ligada ao StoreKit.
    var owned: Set<FootballProModule> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FactoryHeader(
                eyebrow: "Módulos Pro",
                title: "Loja",
                subtitle: "Ferramentas que mostram o jogo por dentro. Cada módulo se compra uma vez.",
                accent: FootballTheme.gold
            )
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

    private func moduleCard(_ module: FootballProModule) -> some View {
        let isOwned = owned.contains(module)
        return FactoryPanel(title: module.title, systemImage: module.symbol) {
            Text(module.teaser)
                .font(.subheadline.weight(.semibold))
                .italic()
                .foregroundStyle(FootballTheme.gold)
            if module == .market {
                marketPreview
            }
            DisclosureGroup("O que vai ter") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(module.highlights, id: \.self) { line in
                        Label(line, systemImage: "checkmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
            HStack {
                Text(Self.price(module.priceCents))
                    .font(.headline.monospacedDigit())
                Spacer()
                if isOwned {
                    PillLabel(text: "Comprado", systemImage: "checkmark.seal.fill", tint: .green)
                } else {
                    PillLabel(text: "Em breve", systemImage: "lock.fill", tint: FootballTheme.gold)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(FootballTheme.gold.opacity(0.35), lineWidth: 1)
        }
        .accessibilityIdentifier("store-module-\(module.rawValue)")
    }

    /// Prévia borrada dos sinais do Market Pro: mostra que existe, sem revelar os nomes dos atletas.
    private var marketPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(["Em alta", "Subvalorizados", "Oportunidades"], id: \.self) { signal in
                HStack {
                    Text(signal).font(.caption.weight(.heavy))
                    Spacer()
                    Text("??? · ??? ????").font(.caption.monospacedDigit())
                }
                .foregroundStyle(.secondary)
                .blur(radius: 3)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }

    /// "R$ 4,90" no formato brasileiro. O valor fica em centavos no módulo.
    private static func price(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
    }
}
