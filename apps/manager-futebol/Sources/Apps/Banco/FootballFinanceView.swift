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
            let entries = career.finance.entries(season: career.season)
            FactoryPanel(title: "Receita por origem", systemImage: "chart.bar.fill") {
                Self.barRows(FootballBankBreakdown.income(entries), empty: "Sem receitas registradas nesta temporada.")
            }
            FactoryPanel(title: "Despesas por categoria", systemImage: "chart.bar.xaxis") {
                Self.barRows(FootballBankBreakdown.expenses(entries), empty: "Sem despesas registradas nesta temporada.")
            }
            let totals = FootballBankTrends.seasonTotals(summaries: career.finance.summaries, book: career.finance, currentSeason: career.season)
            FactoryPanel(title: "Temporadas em comparação", systemImage: "arrow.left.arrow.right") {
                Self.barRows(FootballBankTrends.seasonBars(totals), empty: "A comparação aparece quando alguma temporada tiver receitas ou despesas.")
            }
            FactoryPanel(title: "Evolução do saldo", systemImage: "chart.line.uptrend.xyaxis") {
                Self.balanceTrail(career.monthReports(season: career.season))
            }
            let budgetReference = FootballBudgetSplit.reference(summaries: career.finance.summaries, book: career.finance, currentSeason: career.season)
            let budgetBuckets = FootballBudgetSplit.buckets(reference: budgetReference, entries: career.finance.entries(season: career.season))
            FactoryPanel(title: "Orçamento da temporada", systemImage: "chart.pie.fill") {
                Self.budgetRows(budgetBuckets, reference: budgetReference)
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

    /// As quatro áreas do orçamento, cada uma com gasto, meta e aviso ao chegar perto de 80% ou ao estourar.
    @ViewBuilder
    private static func budgetRows(_ buckets: [FootballBudgetBucket], reference: Int) -> some View {
        if reference <= 0 {
            Text("O orçamento aparece depois da primeira temporada com receita.").font(.subheadline).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(buckets) { bucket in
                    let status = budgetStatus(bucket)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(bucket.area.title).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(status.text).font(.caption.weight(.bold)).foregroundStyle(status.tint)
                        }
                        Text("Gasto \(FootballFormat.money(bucket.spent)) de \(FootballFormat.money(bucket.target))")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private static func budgetStatus(_ bucket: FootballBudgetBucket) -> (text: String, tint: Color) {
        if bucket.isOver { return ("Estourou", .red) }
        if bucket.isNear { return ("Perto do limite", .orange) }
        return ("Dentro da meta", .green)
    }

    /// Linha do saldo de fechamento de cada mês. Precisa de dois meses fechados para ter inclinação.
    @ViewBuilder
    private static func balanceTrail(_ reports: [MonthReport]) -> some View {
        if reports.count < 2 {
            Text("A linha aparece depois de dois meses fechados.").font(.subheadline).foregroundStyle(.secondary)
        } else {
            let values = reports.map(\.closingCash)
            let top = max(values.max() ?? 0, 0)
            let bottom = min(values.min() ?? 0, 0)
            let span = CGFloat(max(top - bottom, 1))
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    let points: [CGPoint] = values.indices.map { index in
                        CGPoint(x: width * CGFloat(index) / CGFloat(values.count - 1),
                                y: height * CGFloat(top - values[index]) / span)
                    }
                    ZStack(alignment: .topLeading) {
                        // Linha do zero: traço fino e discreto, para ver quando o saldo fica negativo.
                        Rectangle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(height: 1)
                            .offset(y: height * CGFloat(top) / span)
                        Path { path in
                            path.move(to: points[0])
                            for point in points.dropFirst() { path.addLine(to: point) }
                        }
                        .stroke(FootballTheme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        ForEach(points.indices, id: \.self) { index in
                            Circle()
                                .fill(FootballTheme.accent)
                                .frame(width: 8, height: 8)
                                .position(points[index])
                        }
                    }
                }
                .frame(height: 120)
                HStack {
                    Text("Início: \(FootballFormat.money(values.first ?? 0))")
                    Spacer()
                    Text("Agora: \(FootballFormat.money(values.last ?? 0))")
                }
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Evolução do saldo: de \(FootballFormat.money(values.first ?? 0)) para \(FootballFormat.money(values.last ?? 0)) em \(values.count) meses")
        }
    }

    /// Barras horizontais com o valor ao lado. Uma série só, na cor de destaque; a lista de categorias abaixo continua sendo a tabela.
    @ViewBuilder
    private static func barRows(_ bars: [FootballBankBar], empty: String) -> some View {
        if bars.isEmpty {
            Text(empty).font(.subheadline).foregroundStyle(.secondary)
        } else {
            let largest = max(bars.map(\.amount).max() ?? 1, 1)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(bars) { bar in
                    HStack(spacing: 10) {
                        Text(bar.title)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(width: 118, alignment: .leading)
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(FootballTheme.accent)
                                .frame(width: max(4, proxy.size.width * CGFloat(bar.amount) / CGFloat(largest)))
                        }
                        .frame(height: 12)
                        Text(FootballFormat.money(bar.amount))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .frame(width: 92, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
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
