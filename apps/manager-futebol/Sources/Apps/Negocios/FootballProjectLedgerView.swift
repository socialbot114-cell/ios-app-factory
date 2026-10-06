import SwiftUI

/// Previsto × realizado de cada projeto do clube, no mesmo período (NEG-06).
struct FootballProjectLedgerPanel: View {
    let career: FootballCareer

    private struct Row: Identifiable {
        let id: String
        let title: String
        let detail: String
        let forecast: String
        let realized: String
        let ratio: Double?
        let running: Bool
    }

    private var rows: [Row] {
        let collections = career.world.commercial.collections.filter { $0.clubID == career.selectedClubID }.map { project in
            let days = project.dailySales.count
            let forecastToDate = project.brief.size.matchDays > 0 ? project.forecast * days / project.brief.size.matchDays : 0
            return Row(id: "collection-\(project.id)", title: project.name,
                       detail: "Coleção · investimento \(FootballFormat.money(project.cost)) · \(days)/\(project.brief.size.matchDays) jogos",
                       forecast: FootballFormat.money(forecastToDate), realized: FootballFormat.money(project.realized),
                       ratio: forecastToDate > 0 ? Double(project.realized) / Double(forecastToDate) : nil, running: project.isActive)
        }
        let ledger = career.projectLedger.map { entry in
            var detail = "\(entry.daysElapsed) jogo(s)"
            if let horizon = entry.horizonDays { detail += " de \(horizon)" }
            if entry.invested > 0 { detail = "Investimento \(FootballFormat.money(entry.invested)) · " + detail }
            return Row(id: "ledger-\(entry.id)", title: entry.title, detail: detail,
                       forecast: entry.unit.format(entry.forecastToDate), realized: entry.unit.format(entry.realized),
                       ratio: entry.ratio, running: entry.isRunning)
        }
        return (collections + ledger).sorted { $0.running && !$1.running }
    }

    var body: some View {
        FactoryPanel(title: "Retorno dos projetos", systemImage: "chart.bar.doc.horizontal.fill") {
            let items = rows
            if items.isEmpty {
                Text("Coleções, naming rights, ampliações da loja e programas sociais aparecem aqui com o previsto e o realizado.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(items) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Spacer()
                        Text(verdict(row)).font(.caption2.weight(.bold)).foregroundStyle(tint(row))
                    }
                    Text(row.detail).font(.caption2).foregroundStyle(.secondary)
                    Text("Previsto \(row.forecast) · realizado \(row.realized)").font(.caption.monospacedDigit())
                }
                .accessibilityElement(children: .combine)
                if row.id != items.last?.id { Divider() }
            }
            Text("O previsto é proporcional ao tempo decorrido, para comparar no mesmo período.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("project-ledger")
    }

    private func verdict(_ row: Row) -> String {
        guard let ratio = row.ratio else { return row.running ? "Em andamento" : "Encerrado" }
        let percent = "\(Int((ratio * 100).rounded()))%"
        if ratio >= 1.1 { return "Acima · \(percent)" }
        if ratio >= 0.85 { return "No previsto · \(percent)" }
        return "Abaixo · \(percent)"
    }

    private func tint(_ row: Row) -> Color {
        guard let ratio = row.ratio else { return .secondary }
        if ratio >= 1.1 { return .green }
        if ratio >= 0.85 { return .secondary }
        return .red
    }
}
