import SwiftUI

/// Resumo da rodada em um cartão: a manchete, o que mudou em fichas curtas, a causa dita uma vez e a próxima atenção.
/// O detalhe (cada mudança com a sua causa e os números do jogo) fica recolhido.
struct FootballPostMatchSummaryPanel: View {
    let summary: PostMatchSummary
    @State private var showsDetails = false

    /// Quando todas as mudanças vêm da mesma causa, ela aparece uma vez só.
    private var commonCause: String? {
        let causes = Set(summary.changes.map(\.cause))
        return causes.count == 1 ? summary.changes.first?.cause : nil
    }

    var body: some View {
        FactoryPanel(title: "Resumo da rodada", systemImage: "list.bullet.clipboard.fill") {
            Text(summary.headline).font(.headline)
            if !summary.changes.isEmpty {
                // Fichas curtas: o nome da mudança e a variação, quando ela é um número.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(summary.changes) { change in chip(change) }
                }
                if let commonCause {
                    Text(commonCause).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let next = summary.attention.first {
                Label(next, systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline.weight(.medium)).foregroundStyle(FootballTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if hasDetails {
                DisclosureGroup("Ver detalhes", isExpanded: $showsDetails) { details.padding(.top, 8) }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("post-match-details")
            }
        }
        .accessibilityIdentifier("post-match-summary")
    }

    private var hasDetails: Bool {
        !summary.changes.isEmpty || !summary.evidence.isEmpty || summary.attention.count > 1
    }

    private func chip(_ change: SummaryChange) -> some View {
        HStack(spacing: 6) {
            Text(change.label).font(.caption.weight(.semibold))
            if let delta = change.delta {
                Text(delta > 0 ? "+\(delta)" : "\(delta)")
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .foregroundStyle(delta > 0 ? Color.green : Color.red)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.primary.opacity(0.07), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(summary.changes) { change in
                VStack(alignment: .leading, spacing: 2) {
                    Text(change.text).font(.subheadline)
                    // A causa só se repete aqui quando as mudanças têm causas diferentes.
                    if commonCause == nil { Text("Por quê: \(change.cause)").font(.caption).foregroundStyle(.secondary) }
                }
                .accessibilityElement(children: .combine)
            }
            if !summary.evidence.isEmpty {
                Divider()
                Text("Números do jogo").font(.caption.weight(.heavy)).foregroundStyle(.secondary)
                ForEach(summary.evidence, id: \.self) { line in
                    Label(line, systemImage: "chart.bar.fill").font(.caption)
                }
            }
            if summary.attention.count > 1 {
                Divider()
                Text("Atenção antes do próximo jogo").font(.caption.weight(.heavy)).foregroundStyle(FootballTheme.accent)
                ForEach(summary.attention.dropFirst(), id: \.self) { line in
                    Label(line, systemImage: "exclamationmark.circle.fill").font(.caption)
                }
            }
        }
    }
}
