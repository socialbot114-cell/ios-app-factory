import SwiftUI

// MARK: - Conquistas

struct FootballAchievementsView: View {
    @Binding var career: FootballCareer

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryMetric(label: "Conquistas", value: "\(career.unlockedAchievementCount)/\(Achievement.allCases.count)", symbol: "medal.fill", tint: FootballTheme.gold)
            let highlights = career.highlightedAchievements
            if !highlights.isEmpty {
                FactoryPanel(title: "Destaques do perfil", systemImage: "star.fill") {
                    ForEach(highlights) { achievement in
                        Label(achievement.title, systemImage: achievement.symbol).font(.subheadline.weight(.semibold))
                    }
                }
            }
            FootballTimelinePanel(career: career)
            FactoryPanel(title: "Galeria", systemImage: "medal.fill") {
                ForEach(Achievement.allCases) { achievement in
                    let unlocked = career.isUnlocked(achievement)
                    NavigationLink {
                        FootballTrophyDetailView(career: $career, achievement: achievement)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: achievement.symbol)
                                .font(.title3)
                                .frame(width: 34, height: 34)
                                .foregroundStyle(unlocked ? FootballTheme.gold : Color.secondary)
                                .background((unlocked ? FootballTheme.gold : Color.secondary).opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title).font(.subheadline.weight(.semibold))
                                Text(achievement.detail).font(.caption).foregroundStyle(.secondary)
                                if !unlocked, let progress = career.achievementProgress(achievement) {
                                    ProgressView(value: Double(progress.current), total: Double(progress.target)).tint(FootballTheme.gold)
                                    Text("\(progress.current) de \(progress.target)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if unlocked { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        }
                        .opacity(unlocked ? 1 : 0.7)
                        .accessibilityElement(children: .combine)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("trophy-\(achievement.rawValue)")
                    if achievement != Achievement.allCases.last { Divider() }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Conquistas")
    }
}
