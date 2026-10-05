import SwiftUI

/// Projeção de caixa do Banco: próximos dias de jogo, separando o garantido do estimado (F4-01 / BAN-02 / BAN-04).
struct FootballCashProjectionPanel: View {
    let career: FootballCareer
    @State private var showLines = false

    var body: some View {
        let projection = career.cashProjection()
        FactoryPanel(title: "Próximos \(projection.horizon) jogos", systemImage: "chart.line.uptrend.xyaxis") {
            if projection.days.isEmpty {
                Text("A projeção volta quando houver jogos pela frente nesta temporada.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                summary(projection)
                chart(projection)
                if let shortfall = projection.firstContractedShortfall {
                    Label("Só com o garantido, o caixa fica negativo no dia \(shortfall.matchDay + 1). Venda, aporte ou corte antes disso.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.red)
                }
                DisclosureGroup(isExpanded: $showLines) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(projection.lines) { line in row(line) }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Compromissos e premissas").font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("cash-projection-lines")
                Text("Garantido: contratos, folha, estrutura e parcelas já assumidas. Estimado: bilheteria, sócios, loja e juros pela situação de hoje. Não inclui vendas, compras ou prêmios futuros.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("cash-projection")
    }

    private func summary(_ projection: CashProjection) -> some View {
        HStack(spacing: 12) {
            FactoryMetric(label: "Só garantido", value: FootballFormat.money(projection.endingContracted),
                          symbol: "lock.fill", tint: projection.endingContracted >= 0 ? .teal : .red)
            FactoryMetric(label: "Esperado", value: FootballFormat.money(projection.endingExpected),
                          symbol: "chart.line.uptrend.xyaxis", tint: projection.endingExpected >= 0 ? .indigo : .red)
        }
    }

    /// Barras do saldo esperado por dia; a marca escura mostra o cenário só com o garantido.
    private func chart(_ projection: CashProjection) -> some View {
        let values = projection.days.flatMap { [$0.expectedBalance, $0.contractedBalance] } + [projection.startingCash, 0]
        let top = Double(values.max() ?? 1)
        let bottom = Double(values.min() ?? 0)
        let span = max(1, top - bottom)
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(projection.days) { day in
                VStack(spacing: 3) {
                    GeometryReader { proxy in
                        let height = proxy.size.height
                        let zero = height * (top / span)
                        let expected = height * Double(day.expectedBalance) / span
                        let contracted = height * Double(day.contractedBalance) / span
                        ZStack(alignment: .topLeading) {
                            Rectangle()
                                .fill(day.expectedBalance >= 0 ? Color.indigo.opacity(0.55) : Color.red.opacity(0.6))
                                .frame(height: abs(expected))
                                .offset(y: expected >= 0 ? zero - expected : zero)
                            Rectangle()
                                .fill(Color.primary.opacity(0.75))
                                .frame(height: 2)
                                .offset(y: zero - contracted)
                        }
                    }
                    Image(systemName: day.hasHomeMatch ? "house.fill" : "airplane")
                        .font(.system(size: 8)).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Dia \(day.matchDay + 1)\(day.hasHomeMatch ? ", jogo em casa" : ""): esperado \(FootballFormat.money(day.expectedBalance)), só garantido \(FootballFormat.money(day.contractedBalance))")
            }
        }
        .frame(height: 96)
    }

    private func row(_ line: CashProjectionLine) -> some View {
        HStack(spacing: 8) {
            Image(systemName: line.category.symbol).frame(width: 22).foregroundStyle(line.total >= 0 ? .green : .red)
            VStack(alignment: .leading, spacing: 1) {
                Text(line.title).font(.subheadline).lineLimit(1)
                Text(line.dueMatchDay.map { "\(line.certainty.title) · vence no dia \($0)" } ?? line.certainty.title)
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(FootballFormat.money(line.total))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(line.total >= 0 ? .green : .red)
        }
        .accessibilityElement(children: .combine)
    }
}
