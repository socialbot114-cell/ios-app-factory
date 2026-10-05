import SwiftUI

/// Análise do campeonato para o clube do jogador: cenários matemáticos, dificuldade do
/// calendário restante e confronto direto com o próximo adversário (LIG-04, LIG-05).
struct FootballLeagueInsightPanel: View {
    let career: FootballCareer
    let division: Division

    var body: some View {
        if let clubID = career.selectedClubID, career.division(of: clubID) == division, !career.isSeasonComplete {
            let table = career.standings(for: division)
            let fixtures = career.fixtures.filter { $0.competition == .league(division) }
            let scenarios = FootballLeagueAnalysis.scenarios(table: table, division: division, teamID: clubID)
            let difficulty = FootballLeagueAnalysis.difficulty(of: clubID, among: career.teamIDs(in: division), fixtures: fixtures)
            FactoryPanel(title: "Análise do seu clube", systemImage: "chart.bar.doc.horizontal") {
                ForEach(scenarios, id: \.goal.title) { scenario in
                    HStack {
                        Text(scenario.goal.title).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(label(scenario.status)).font(.caption.weight(.bold)).foregroundStyle(color(scenario.status))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("league-scenario-\(scenario.goal.title)")
                }
                Text("Empates de pontos contam contra você ao garantir e a seu favor ao descartar; o desempate só se define no fim.")
                    .font(.caption2).foregroundStyle(.secondary)
                Divider()
                if let rank = difficulty.rank, let strength = difficulty.averageOpponentStrength {
                    LabeledContent("Calendário restante",
                                   value: "\(difficulty.remainingMatches) jogos · força média \(Int(strength.rounded())) · \(rank)º mais difícil")
                        .font(.subheadline)
                        .accessibilityIdentifier("league-difficulty")
                } else {
                    Text("Sem jogos de liga pendentes.").font(.subheadline).foregroundStyle(.secondary)
                }
                if let next = fixtures.filter({ !$0.isPlayed && $0.involves(clubID) }).min(by: { $0.matchDay < $1.matchDay }),
                   let opponent = FootballSeason.team(next.home == clubID ? next.away : next.home) {
                    let record = FootballLeagueAnalysis.headToHead(clubID, against: opponent.id, fixtures: fixtures)
                    LabeledContent("Próximo: \(opponent.name)",
                                   value: record.meetings == 0 ? "sem confronto na temporada"
                                   : "\(record.wins)V \(record.draws)E \(record.losses)D · \(record.goalsFor)–\(record.goalsAgainst)")
                        .font(.subheadline)
                        .accessibilityIdentifier("league-head-to-head")
                }
            }
        }
    }

    private func label(_ status: FootballLeagueAnalysis.Status) -> String {
        switch status {
        case .clinched: return "Garantido"
        case .impossible: return "Fora de alcance"
        case .open(let points?): return points == 0 ? "Em aberto" : "Faltam \(points) pts para garantir"
        case .open(nil): return "Depende de rivais"
        }
    }

    private func color(_ status: FootballLeagueAnalysis.Status) -> Color {
        switch status {
        case .clinched: return .green
        case .impossible: return .red
        case .open: return .secondary
        }
    }
}
