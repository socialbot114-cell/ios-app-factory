import SwiftUI

/// Resumo da rodada: o que mudou, por quê, os números do jogo e o que pede atenção antes do próximo.
struct FootballPostMatchSummaryPanel: View {
    let summary: PostMatchSummary

    var body: some View {
        FactoryPanel(title: "Resumo da rodada", systemImage: "list.bullet.clipboard.fill") {
            Text(summary.headline).font(.subheadline.weight(.semibold))
            if !summary.changes.isEmpty {
                ForEach(summary.changes) { change in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(change.text).font(.subheadline)
                            Spacer(minLength: 8)
                            if let delta = change.delta {
                                Text(delta > 0 ? "+\(delta)" : "\(delta)")
                                    .font(.caption.weight(.heavy).monospacedDigit())
                                    .foregroundStyle(delta > 0 ? Color.green : Color.red)
                            }
                        }
                        Text("Por quê: \(change.cause)").font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if !summary.evidence.isEmpty {
                Divider()
                Text("Números do jogo").font(.caption.weight(.heavy)).foregroundStyle(.secondary)
                ForEach(summary.evidence, id: \.self) { line in
                    Label(line, systemImage: "chart.bar.fill").font(.caption)
                }
            }
            if !summary.attention.isEmpty {
                Divider()
                Text("Atenção antes do próximo jogo").font(.caption.weight(.heavy)).foregroundStyle(FootballTheme.accent)
                ForEach(summary.attention, id: \.self) { line in
                    Label(line, systemImage: "exclamationmark.circle.fill").font(.caption)
                }
            }
        }
        .accessibilityIdentifier("post-match-summary")
    }
}
