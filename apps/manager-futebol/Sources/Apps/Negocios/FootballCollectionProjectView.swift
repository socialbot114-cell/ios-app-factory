import SwiftUI

/// Coleção da loja como projeto: briefing, previsão, vendas ao longo dos jogos e avaliação final (F4-02 / NEG-01/02/06).
struct FootballCollectionProjectPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var audience: CollectionAudience = .traditional
    @State private var size: CollectionSize = .capsule

    var body: some View {
        FactoryPanel(title: "Coleção da loja", systemImage: "tshirt.fill") {
            if let project = career.activeCollection {
                running(project)
            } else {
                briefing
            }
            let history = career.world.commercial.collections.filter { !$0.isActive && $0.clubID == career.selectedClubID }.suffix(3).reversed()
            if !history.isEmpty {
                Divider()
                Text("Coleções anteriores · previsto × realizado").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(Array(history)) { project in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(project.name).font(.caption.weight(.semibold))
                            Text("\(FootballFormat.money(project.forecast)) × \(FootballFormat.money(project.realized)) · custo \(FootballFormat.money(project.cost))")
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(verdictText(project.verdict)).font(.caption2.weight(.bold)).foregroundStyle(verdictTint(project.verdict))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .accessibilityIdentifier("collection-project")
    }

    private var briefing: some View {
        let brief = CollectionBrief(audience: audience, size: size)
        let blocker = career.collectionBlocker(brief)
        let cost = career.collectionCost(brief)
        let forecast = career.collectionForecast(brief)
        return VStack(alignment: .leading, spacing: 10) {
            Picker("Público", selection: $audience) {
                ForEach(CollectionAudience.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(audience.driver + " Resposta hoje: \(Int((career.audienceFit(audience) * 100).rounded()))%.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Porte", selection: $size) {
                ForEach(CollectionSize.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack(spacing: 12) {
                FactoryMetric(label: "Investimento", value: FootballFormat.money(cost), symbol: "arrow.down.circle.fill", tint: .orange)
                FactoryMetric(label: "Previsão em \(size.matchDays) jogos", value: FootballFormat.money(forecast), symbol: "chart.bar.fill",
                              tint: forecast >= cost ? .green : .red)
            }
            Text("A previsão supõe o clima de hoje. Embalo, humor da torcida e reputação mudam as vendas reais a cada jogo.")
                .font(.caption2).foregroundStyle(.secondary)
            if let blocker { Text(blocker).font(.caption2).foregroundStyle(.orange) }
            Button {
                if !career.launchCollection(brief) { onAlert(blocker ?? "Não foi possível lançar a coleção.") }
            } label: {
                Label("Lançar coleção", systemImage: "sparkles").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(blocker != nil)
            .accessibilityIdentifier("collection-launch")
        }
    }

    private func running(_ project: CollectionProject) -> some View {
        let days = project.brief.size.matchDays
        let pace = project.dailySales.isEmpty ? 0 : project.realized * days / project.dailySales.count
        return VStack(alignment: .leading, spacing: 8) {
            Text(project.name).font(.subheadline.weight(.semibold))
            ProgressView(value: Double(project.dailySales.count), total: Double(days))
            Text("\(project.dailySales.count)/\(days) jogos · vendido \(FootballFormat.money(project.realized)) · ritmo para \(FootballFormat.money(pace)) (previsto \(FootballFormat.money(project.forecast)))")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            if !project.dailySales.isEmpty {
                let top = max(1, project.dailySales.max() ?? 1)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(project.dailySales.enumerated()), id: \.offset) { _, sale in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.indigo.opacity(0.7))
                            .frame(height: max(3, 44 * Double(sale) / Double(top)))
                    }
                }
                .frame(height: 44, alignment: .bottom)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func verdictText(_ verdict: CollectionProject.Verdict?) -> String {
        switch verdict {
        case .success: return "Sucesso"
        case .onTarget: return "No previsto"
        case .below: return "Abaixo"
        case nil: return "Em venda"
        }
    }

    private func verdictTint(_ verdict: CollectionProject.Verdict?) -> Color {
        switch verdict {
        case .success: return .green
        case .onTarget: return .secondary
        case .below: return .red
        case nil: return .indigo
        }
    }
}
