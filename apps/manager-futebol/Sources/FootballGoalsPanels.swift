import SwiftUI

/// Escolha das metas pessoais (MET-02): até `personalGoalLimit`, sempre opcionais.
struct FootballGoalsPlannerPanel: View {
    @Binding var career: FootballCareer
    var onOpenApp: ((String) -> Void)? = nil

    var body: some View {
        let goals = career.personalGoals
        FactoryPanel(title: "Suas metas · \(goals.count)/\(FootballCareer.personalGoalLimit)", systemImage: "target") {
            if goals.isEmpty {
                Text("Escolha até \(FootballCareer.personalGoalLimit) metas que importam para você. Nenhuma é obrigatória.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(goals) { quest in
                VStack(alignment: .leading, spacing: 6) {
                    FootballGoalRow(career: career, quest: quest, onOpenApp: onOpenApp)
                    Menu {
                        ForEach(career.adoptableGoals, id: \.id) { template in
                            Button(template.title) { career.replaceGoal(questID: quest.id, with: template.id) }
                        }
                    } label: {
                        Label("Trocar por outra", systemImage: "arrow.triangle.2.circlepath").font(.caption.weight(.bold))
                    }
                    .accessibilityIdentifier("goal-replace-\(quest.id)")
                }
                Divider()
            }
            if goals.count < FootballCareer.personalGoalLimit {
                Menu {
                    ForEach(career.adoptableGoals, id: \.id) { template in
                        Button("\(template.title) · \(template.detail)") { career.adoptGoal(templateID: template.id) }
                    }
                } label: {
                    Label("Adotar uma meta", systemImage: "plus.circle.fill").font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("goal-adopt")
            }
        }
    }
}

/// Linha de meta com origem, eventos que contaram e ação contextual (MET-01, 03, 04).
struct FootballGoalRow: View {
    let career: FootballCareer
    let quest: Quest
    var onOpenApp: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(quest.title).font(.subheadline.weight(.bold))
                Spacer()
                Text("\(career.progress(of: quest))/\(quest.target)").font(.caption.weight(.bold).monospacedDigit())
            }
            Text("Origem: \(quest.sourceName ?? quest.origin?.title ?? "Você") · \(quest.detail)")
                .font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("goal-origin-\(quest.id)")
            ProgressView(value: Double(career.progress(of: quest)), total: Double(max(1, quest.target))).tint(.blue)
            Label(quest.reward.text, systemImage: "gift.fill").font(.caption).foregroundStyle(FootballTheme.gold)
            if let contributions = quest.contributions, !contributions.isEmpty {
                Text("Contou: " + FootballCareer.compactContributions(contributions))
                    .font(.caption2).foregroundStyle(.secondary)
                    .accessibilityIdentifier("goal-contributions-\(quest.id)")
            }
            if let title = FootballCareer.questActionTitle(counter: quest.counter),
               let app = FootballCareer.questActionApp(counter: quest.counter), let onOpenApp {
                Button { onOpenApp(app) } label: {
                    Label(title, systemImage: "arrow.right.circle").font(.caption.weight(.bold))
                }
                .accessibilityIdentifier("goal-action-\(quest.id)")
            }
        }
    }
}

/// Histórico de metas concluídas, não cumpridas e substituídas (MET-05).
struct FootballGoalsHistoryPanel: View {
    let career: FootballCareer

    var body: some View {
        FactoryPanel(title: "Histórico de metas", systemImage: "clock.arrow.circlepath") {
            let history = career.world.quests.history ?? []
            if history.isEmpty { Text("Metas concluídas, não cumpridas e trocadas ficam registradas aqui.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(history.prefix(10)) { record in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(record.title).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(record.outcome.title).font(.caption.weight(.bold))
                            .foregroundStyle(record.outcome == .completed ? .green : (record.outcome == .failed ? .red : .secondary))
                    }
                    Text("T\(record.season) · dia \(record.matchDay + 1) · \(record.sourceName) · \(record.progress)/\(record.target)")
                        .font(.caption2).foregroundStyle(.secondary)
                    if !record.contributions.isEmpty {
                        Text("Contou: " + FootballCareer.compactContributions(record.contributions)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityIdentifier("goals-history")
    }
}
