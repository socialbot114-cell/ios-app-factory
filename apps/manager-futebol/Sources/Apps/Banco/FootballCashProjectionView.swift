import SwiftUI

/// Projeção de caixa do Banco: próximos dias de jogo, separando o garantido do estimado (F4-01 / BAN-02 / BAN-04).
struct FootballCashProjectionPanel: View {
    let career: FootballCareer
    @State private var showLines = false
    @State private var scenario = FootballBudgetScenario()
    @State private var horizon = FootballCareer.defaultProjectionHorizon
    @State private var showSimulator = false

    var body: some View {
        let baseline = career.cashProjection(horizon: horizon)
        let projection = scenario.projection(for: career, horizon: horizon)
        FactoryPanel(title: "Próximos \(projection.horizon) dias de jogo", systemImage: "chart.line.uptrend.xyaxis") {
            if projection.days.isEmpty {
                Text(career.selectedClubID == nil ? "Escolha um clube para planejar seu caixa." : "Sem dias disponíveis nesta temporada. O planejamento volta quando houver novos jogos e um clube ativo.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                summary(projection)
                chart(projection)
                DisclosureGroup(isExpanded: $showSimulator) {
                    controls.padding(.top, 8)
                } label: {
                    Label("Simular contratação ou obra", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("budget-simulator")
                Text("Simulação apenas: não contrata, compra nem altera as finanças do clube.")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("budget-simulation-disclaimer")
                VStack(alignment: .leading, spacing: 5) {
                    Text("Saldo mínimo conservador: \(FootballFormat.money(FootballBudgetScenario.minimum(projection, expected: false)))")
                    Text("Saldo mínimo esperado: \(FootballFormat.money(FootballBudgetScenario.minimum(projection, expected: true)))")
                    Text("Sem novos gastos: mínimo esperado \(FootballFormat.money(FootballBudgetScenario.minimum(baseline, expected: true))) · final \(FootballFormat.money(baseline.endingExpected))")
                    Text("Obrigações no período: \(FootballFormat.money(-projection.committedOutflows)) · saída hoje: \(FootballFormat.money(max(0, scenario.upfront)))")
                    Text("Parcelas simuladas totais: \(FootballFormat.money(scenario.installmentAmount * scenario.installmentCount)). Vencimentos fora do período não entram no gráfico.")
                }
                .font(.caption).accessibilityIdentifier("budget-comparison")
                if FootballBudgetScenario.minimum(projection, expected: true) < 0 {
                    Label("Mesmo com receitas estimadas, há caixa negativo: risco de dívida e juros. Reduza gastos ou planeje receitas antes de assumir compromissos.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                        .accessibilityIdentifier("budget-expected-risk")
                } else if FootballBudgetScenario.minimum(projection, expected: false) < 0 {
                    Text("O conservador fica negativo: o plano depende de receitas variáveis. O esperado positivo não garante capacidade de pagamento.")
                        .font(.caption).foregroundStyle(.orange)
                        .accessibilityIdentifier("budget-conservative-risk")
                }
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
                Text("Salário informado por temporada; cobrança por dia = folha total ÷ \(FootballSeason.matchDaysPerSeason), com truncamento do motor. Parcelas a cada 2 dias de jogo. Entrada sai hoje; juros seguem a ordem do motor. Dificuldade já incluída nas receitas, sem novo multiplicador. Elenco, torcida e estrutura constantes; sem prever resultados, novas obras ou mudança de temporada. Obras já assumidas continuam incluídas.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .accessibilityIdentifier("budget-assumptions")
            }
        }
        .accessibilityIdentifier("cash-projection")
        .onAppear { if FactoryCapture.screen == "budget-planning" { showSimulator = true } }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper("Próximos \(horizon) dias de jogo", value: $horizon, in: 1...FootballSeason.matchDaysPerSeason)
                .accessibilityIdentifier("budget-horizon")
            VStack(alignment: .leading, spacing: 8) {
                Button("Zerar") { scenario = FootballBudgetScenario() }
                    .accessibilityIdentifier("budget-reset")
                if let player = career.clubRoster.sorted(by: { $0.marketValue < $1.marketValue }).first {
                    Button("Referência do elenco") {
                        scenario = FootballBudgetScenario(upfront: player.marketValue, annualWage: player.contract.wage)
                    }.accessibilityIdentifier("budget-roster-preset")
                    Button("Referência do elenco em 3 pagamentos") {
                        let entry = player.marketValue / 3
                        scenario = FootballBudgetScenario(upfront: entry, annualWage: player.contract.wage,
                            installmentAmount: (player.marketValue - entry) / 2, installmentCount: 2)
                    }.accessibilityIdentifier("budget-roster-installments-preset")
                }
                if let cost = career.upgradeCost(for: .trainingCenter) {
                    Button("Obra à vista") { scenario = FootballBudgetScenario(upfront: cost) }
                        .accessibilityIdentifier("budget-construction-preset")
                }
            }.font(.caption)
            Text("Obra à vista usa o custo integral da próxima melhoria do centro de treinamento, sem simular seus benefícios ou impactos esportivos.")
                .font(.caption2).foregroundStyle(.secondary)
            if career.clubRoster.isEmpty {
                Text("Sem elenco para referência salarial. Simule entrada e parcelas; salário disponível quando houver jogadores no clube.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Referência do elenco: valor de mercado e salário do jogador de menor valor; não é uma proposta de transferência.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            amountField("Gasto à vista hoje", value: $scenario.upfront, id: "budget-upfront")
            amountField("Salário adicional por temporada", value: $scenario.annualWage, id: "budget-wage")
                .disabled(career.clubRoster.isEmpty)
            amountField("Valor de cada parcela", value: $scenario.installmentAmount, id: "budget-installment-amount")
            Stepper("\(scenario.installmentCount) parcelas adicionais", value: $scenario.installmentCount, in: 0...12)
                .accessibilityIdentifier("budget-installment-count")
        }
    }

    private func amountField(_ title: String, value: Binding<Int>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption)
            TextField(title, text: Binding(
                get: { String(value.wrappedValue) },
                set: { text in
                    let digits = text.filter { $0.isASCII && $0.isNumber }
                    value.wrappedValue = digits.isEmpty ? 0 : min(1_000_000_000, Int(digits) ?? 1_000_000_000)
                }))
                .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                .accessibilityLabel(title).accessibilityIdentifier(id)
        }
    }

    private func summary(_ projection: CashProjection) -> some View {
        HStack(spacing: 12) {
            FactoryMetric(label: "Só garantido", value: FootballFormat.money(projection.endingContracted),
                          symbol: "lock.fill", tint: projection.endingContracted >= 0 ? .teal : .red)
            FactoryMetric(label: "Esperado", value: FootballFormat.money(projection.endingExpected),
                          symbol: "chart.line.uptrend.xyaxis", tint: projection.endingExpected >= 0 ? .indigo : .red)
        }
        .accessibilityIdentifier("budget-summary")
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
                .accessibilityIdentifier("budget-day-\(day.matchDay)")
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
                Text(line.dueMatchDay.map { "\(line.certainty.title) · vence no dia \($0 + 1)" } ?? line.certainty.title)
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
