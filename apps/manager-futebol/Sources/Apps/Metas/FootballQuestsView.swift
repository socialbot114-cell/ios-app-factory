import SwiftUI

// MARK: - Missões

struct FootballQuestsView: View {
    @Binding var career: FootballCareer
    var onOpenApp: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryMetric(label: "Missões concluídas", value: "\(career.world.quests.completedCount)", symbol: "checkmark.seal.fill", tint: .blue)
            FootballGoalsPlannerPanel(career: $career, onOpenApp: onOpenApp)
            let weekly = career.world.quests.active.filter { !$0.seasonal && !$0.completed && $0.origin != .player }
            let seasonal = career.world.quests.active.filter { $0.seasonal && !$0.completed && $0.origin != .player }
            questPanel("Missões rápidas", "bolt.fill", weekly)
            questPanel("Missões de temporada", "calendar", seasonal)
            FootballGoalsHistoryPanel(career: career)
            Text("As recompensas caem sozinhas, uma única vez, quando a meta é batida.").font(.caption).foregroundStyle(.secondary)
        }
        .factoryPage()
        .navigationTitle("Missões")
    }

    @ViewBuilder
    private func questPanel(_ title: String, _ symbol: String, _ quests: [Quest]) -> some View {
        FactoryPanel(title: title, systemImage: symbol) {
            if quests.isEmpty { Text("Nenhuma missão ativa agora.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(quests) { quest in
                FootballGoalRow(career: career, quest: quest, onOpenApp: onOpenApp)
                if quest.id != quests.last?.id { Divider() }
            }
        }
    }
}
