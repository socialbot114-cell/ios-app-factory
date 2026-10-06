import SwiftUI

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
