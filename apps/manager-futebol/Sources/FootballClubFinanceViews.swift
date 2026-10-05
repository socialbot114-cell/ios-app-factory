import SwiftUI

/// Avaliação da diretoria em três frentes, com as razões de cada nota (CLB-01).
struct FootballBoardEvaluationPanel: View {
    let career: FootballCareer

    var body: some View {
        let evaluation = career.boardEvaluation
        FactoryPanel(title: "Como a diretoria avalia", systemImage: "list.clipboard.fill") {
            ForEach(evaluation.fronts) { front in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(front.title).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(front.score) · \(front.verdict)").font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(front.score >= 65 ? Color.green : (front.score >= 40 ? Color.orange : Color.red))
                    }
                    ConditionBar(value: front.score)
                    ForEach(front.reasons, id: \.self) { Text("• \($0)").font(.caption2).foregroundStyle(.secondary) }
                }
                .accessibilityElement(children: .combine)
            }
            Text("A cobrança começa pela frente mais fraca: \(evaluation.weakest.title.lowercased()).").font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("board-evaluation")
    }
}

/// Obra em curso por etapas, com impacto durante a execução (CLB-04).
struct FootballConstructionPanel: View {
    let career: FootballCareer

    var body: some View {
        if let plan = career.constructionPlan {
            FactoryPanel(title: "Etapas da obra", systemImage: "building.columns.fill") {
                ForEach(Array(plan.stageCosts.enumerated()), id: \.offset) { index, cost in
                    Label("\(ConstructionPlan.stageNames[index]) · \(FootballFormat.money(cost))",
                          systemImage: index < plan.stagesPaid ? "checkmark.circle.fill" : "circle")
                        .font(.caption).foregroundStyle(index < plan.stagesPaid ? Color.green : Color.secondary)
                }
                Text("Pago \(FootballFormat.money(plan.paid)) de \(FootballFormat.money(plan.totalCost)). \(career.constructionImpact(for: plan.kind))")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if plan.pausedDays > 0 {
                    Label("Parada \(plan.pausedDays) dia(s) por falta de caixa", systemImage: "pause.circle.fill").font(.caption).foregroundStyle(.orange)
                }
            }
            .accessibilityIdentifier("construction-stages")
        }
    }
}

/// Simulação da obra na projeção de caixa antes de começar (BAN-03).
struct FootballUpgradeSimulationRow: View {
    let career: FootballCareer
    let kind: FacilityKind

    var body: some View {
        if career.upgradeProject == nil, career.upgradeCost(for: kind) != nil {
            let result = career.simulate(career.upgradeScenario(kind), horizon: career.upgradeDuration(for: kind) + 1)
            let lowest = result.after.days.map(\.contractedBalance).min() ?? result.after.startingCash
            VStack(alignment: .leading, spacing: 2) {
                Text("Pago em 3 etapas. Caixa garantido no fim da obra: \(FootballFormat.money(result.after.endingContracted)) (sem a obra: \(FootballFormat.money(result.before.endingContracted))).")
                    .font(.caption2.monospacedDigit()).foregroundStyle(lowest < 0 ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(career.constructionImpact(for: kind)).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// Extratos do clube e do treinador, com a origem de cada lançamento (BAN-01 / BAN-06).
struct FootballStatementsPanel: View {
    let career: FootballCareer
    @State private var personal = false
    @State private var expanded: String?

    private struct Row: Identifiable {
        let id: String
        let amount: Int
        let note: String
        let day: String
        let link: FinanceLink?
    }

    private var rows: [Row] {
        if personal {
            return career.personalLedger.entries.suffix(25).reversed().map {
                Row(id: "p\($0.id)", amount: $0.amount, note: $0.note, day: "dia \($0.worldDay)", link: $0.link)
            }
        }
        return career.finance.entries.suffix(25).enumerated().reversed().map { index, entry in
            Row(id: "c\(index)-\(entry.season)-\(entry.matchDay)", amount: entry.amount, note: entry.note,
                day: "T\(entry.season) · jogo \(entry.matchDay + 1)", link: entry.link)
        }
    }

    var body: some View {
        FactoryPanel(title: "Extratos", systemImage: "list.bullet.rectangle.portrait.fill") {
            Picker("Conta", selection: $personal) {
                Text("Clube").tag(false)
                Text("Treinador").tag(true)
            }
            .pickerStyle(.segmented)
            Text(personal ? "Bolso do treinador: \(FootballFormat.money(career.world.coach.personalCash)). O extrato explica todo o saldo."
                          : "Caixa do clube: \(FootballFormat.money(career.transferBudget)). Toque num lançamento com origem para ver o que o gerou.")
                .font(.caption2).foregroundStyle(.secondary)
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 3) {
                    Button {
                        expanded = expanded == row.id ? nil : row.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.note).font(.caption).lineLimit(1)
                                Text(row.day + (row.link != nil ? " · ver origem" : "")).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(FootballFormat.money(row.amount)).font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(row.amount >= 0 ? Color.green : Color.red)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(row.link == nil)
                    if expanded == row.id, let link = row.link {
                        let origin = career.financeOrigin(link)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(origin.title).font(.caption.weight(.semibold))
                            Text(origin.detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .accessibilityIdentifier("bank-statements")
    }
}
