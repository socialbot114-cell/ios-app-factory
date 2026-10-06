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
