import SwiftUI

/// Delegar as coleções a um gerente comercial: perfil de risco, teto por temporada, custo e relatório (F4-05 / CLB-05).
struct FootballCommercialDelegationPanel: View {
    @Binding var career: FootballCareer
    @State private var risk: DelegationRisk = .cautious
    @State private var limit: DelegationLimit = .medium

    var body: some View {
        FactoryPanel(title: "Gerente comercial", systemImage: "person.badge.key.fill") {
            if let delegation = career.commercialDelegation {
                active(delegation)
            } else {
                hire
            }
        }
        .accessibilityIdentifier("commercial-delegation")
    }

    private var hire: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Delegue as coleções: o gerente escolhe público e porte, lança quando a previsão compensa e manda relatório a cada \(FootballCareer.delegationReportInterval) jogos.")
                .font(.caption).foregroundStyle(.secondary)
            settings
            HStack(spacing: 12) {
                FactoryMetric(label: "Custo por jogo", value: FootballFormat.money(career.delegationFeePerMatchDay), symbol: "banknote", tint: .orange)
                FactoryMetric(label: "Teto da temporada", value: FootballFormat.money(career.delegationCap(limit)), symbol: "lock.fill", tint: .gray)
            }
            Button {
                career.delegateCommercial(risk: risk, limit: limit)
            } label: {
                Label("Contratar gerente", systemImage: "checkmark.seal.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("delegation-hire")
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Perfil", selection: $risk) {
                ForEach(DelegationRisk.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(risk.summary).font(.caption2).foregroundStyle(.secondary)
            Picker("Teto", selection: $limit) {
                ForEach(DelegationLimit.allCases) { Text(FootballFormat.money(career.delegationCap($0))).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private func active(_ delegation: CommercialDelegation) -> some View {
        let result = career.delegationResult
        let net = result.realized - result.invested - result.fees
        let cap = career.delegationCap(delegation.limit)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Perfil \(delegation.risk.title.lowercased()) · custa \(FootballFormat.money(career.delegationFeePerMatchDay)) por jogo.")
                .font(.subheadline.weight(.semibold))
            ProgressView(value: Double(min(delegation.spentThisSeason, cap)), total: Double(max(1, cap)))
            Text("Teto usado: \(FootballFormat.money(delegation.spentThisSeason)) de \(FootballFormat.money(cap)) nesta temporada.")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text("Vendas extras \(FootballFormat.money(result.realized)) · investido \(FootballFormat.money(result.invested)) · honorários \(FootballFormat.money(result.fees))")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Label("Saldo da delegação: \(FootballFormat.money(net))", systemImage: net >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption.weight(.bold)).foregroundStyle(net >= 0 ? .green : .red)
            if !delegation.pendingNotes.isEmpty {
                Text(delegation.pendingNotes.joined(separator: " ")).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            settings
            HStack(spacing: 10) {
                Button("Atualizar ordens") { career.delegateCommercial(risk: risk, limit: limit) }
                    .buttonStyle(.bordered)
                Button("Dispensar", role: .destructive) { career.endCommercialDelegation() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("delegation-end")
            }
        }
        .onAppear {
            risk = delegation.risk
            limit = delegation.limit
        }
    }
}
