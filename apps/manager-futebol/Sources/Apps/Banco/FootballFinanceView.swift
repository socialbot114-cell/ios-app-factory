import SwiftUI

// MARK: - Finanças

struct FootballFinanceView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            let overview = career.bankOverview
            FactoryPanel(title: "Visão geral", systemImage: "gauge.with.dots.needle.50percent") {
                HStack(spacing: 12) {
                    FactoryMetric(label: "Saldo do clube", value: FootballFormat.money(overview.balance), symbol: "banknote.fill", tint: overview.balance < 0 ? .red : FootballTheme.accent)
                    FactoryMetric(label: "Fôlego", value: Self.breathText(overview.monthsOfBreath), symbol: "hourglass", tint: Self.tint(overview.risk))
                }
                HStack(spacing: 12) {
                    FactoryMetric(label: "Receitas do mês", value: FootballFormat.money(overview.monthIncome), symbol: "arrow.up.circle.fill", tint: .green)
                    FactoryMetric(label: "Despesas do mês", value: FootballFormat.money(overview.monthExpenses), symbol: "arrow.down.circle.fill", tint: .orange)
                }
                if let income = overview.incomeChange, let expenses = overview.expenseChange {
                    Text("Contra o mês anterior: receitas \(Self.changeText(income)), despesas \(Self.changeText(expenses)).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let alert = Self.alertText(overview) {
                    Label(alert, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(Self.tint(overview.risk))
                }
            }
            HStack(spacing: 12) {
                FactoryMetric(label: "Folha salarial", value: FootballFormat.money(career.wageBill), symbol: "person.3.fill", tint: .orange)
                FactoryMetric(label: "Teto da folha", value: FootballFormat.money(career.wageCap), symbol: "lock.fill", tint: .gray)
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

    /// Fôlego em meses, em texto curto.
    private static func breathText(_ months: Double?) -> String {
        guard let months else { return "Sem despesas" }
        if months < 1 { return "menos de 1 mês" }
        let whole = Int(months)
        return "\(whole) \(whole == 1 ? "mês" : "meses")"
    }

    private static func changeText(_ change: Int) -> String {
        if change == 0 { return "sem mudança" }
        let sign = change > 0 ? "+" : "−"
        return "\(sign)\(FootballFormat.money(abs(change)))"
    }

    private static func tint(_ risk: FootballBankOverview.Risk) -> Color {
        switch risk {
        case .stable: return .green
        case .watch: return .orange
        case .critical: return .red
        }
    }

    private static func alertText(_ overview: FootballBankOverview) -> String? {
        switch overview.risk {
        case .stable:
            return nil
        case .watch:
            return "Fôlego abaixo de três meses ou projeção de caixa negativa. Acompanhe as despesas."
        case .critical:
            return overview.balance < 0
                ? "Clube no vermelho: juros, risco de transfer ban e diretoria preocupada."
                : "Menos de um mês de fôlego no ritmo atual. Reduza despesas ou busque receita."
        }
    }
}
