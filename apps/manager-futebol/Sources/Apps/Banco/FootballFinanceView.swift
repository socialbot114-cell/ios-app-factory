import SwiftUI

// MARK: - Finanças

struct FootballFinanceView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                FactoryMetric(label: "Caixa", value: FootballFormat.money(career.transferBudget), symbol: "banknote.fill", tint: career.isInDebt ? .red : FootballTheme.accent)
                FactoryMetric(label: "Projeção fim de temporada", value: FootballFormat.money(career.projectedSeasonEndCash), symbol: "chart.line.uptrend.xyaxis", tint: .indigo)
            }
            HStack(spacing: 12) {
                FactoryMetric(label: "Folha salarial", value: FootballFormat.money(career.wageBill), symbol: "person.3.fill", tint: .orange)
                FactoryMetric(label: "Teto da folha", value: FootballFormat.money(career.wageCap), symbol: "lock.fill", tint: .gray)
            }
            if career.isInDebt {
                Label("Clube no vermelho: juros, risco de transfer ban e diretoria preocupada.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.red)
            }
            FootballCashProjectionPanel(career: career)
            FootballCoachLoanPanel(career: $career)
            FootballStatementsPanel(career: career)
            FactoryPanel(title: "Aporte do treinador", systemImage: "arrow.down.to.line.circle.fill") {
                Text("Seu bolso: \(FootballFormat.money(career.world.coach.personalCash)). Emprestar dinheiro ao clube alivia o caixa e, no vermelho, acalma a diretoria.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach([100_000, 250_000, 500_000], id: \.self) { amount in
                        Button("+ \(FootballFormat.money(amount))") {
                            if !career.lendToClub(amount: amount) { onAlert("Seu caixa pessoal não cobre este aporte.") }
                        }
                        .buttonStyle(.bordered).font(.caption.weight(.bold))
                        .accessibilityIdentifier("lend-\(amount)")
                    }
                }
            }
            FactoryPanel(title: "Temporada \(career.season) por categoria", systemImage: "chart.pie.fill") {
                let cats = FinanceCategory.allCases.map { ($0, career.finance.total(season: career.season, category: $0)) }.filter { $0.1 != 0 }
                if cats.isEmpty { Text("Os números aparecem depois dos primeiros jogos.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(cats, id: \.0) { category, amount in
                    HStack {
                        Image(systemName: category.symbol).frame(width: 24).foregroundStyle(amount >= 0 ? .green : .red)
                        Text(category.title).font(.subheadline)
                        Spacer()
                        Text(FootballFormat.money(amount)).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(amount >= 0 ? .green : .red)
                    }
                }
            }
            FactoryPanel(title: "Mês a mês", systemImage: "calendar") {
                let months = career.monthReports(season: career.season)
                if months.isEmpty { Text("Sem fechamento mensal ainda.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(months) { month in
                    HStack {
                        Text("Mês \(month.month)").font(.subheadline.weight(.semibold))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(FootballFormat.money(month.result)).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(month.result >= 0 ? .green : .red)
                            Text("caixa \(FootballFormat.money(month.closingCash))").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !career.finance.summaries.isEmpty {
                FactoryPanel(title: "Temporadas anteriores", systemImage: "clock.arrow.circlepath") {
                    ForEach(career.finance.summaries.reversed()) { summary in
                        HStack {
                            Text("T\(summary.season)").font(.caption.weight(.heavy))
                            Spacer()
                            Text("Receita \(FootballFormat.money(summary.income)) · Despesa \(FootballFormat.money(summary.expenses))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Finanças")
    }
}
