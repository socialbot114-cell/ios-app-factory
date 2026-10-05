import SwiftUI

/// Contexto histórico de uma conquista (TRO-02), com destaque do perfil e marco compartilhável (TRO-05).
struct FootballTrophyDetailView: View {
    @Binding var career: FootballCareer
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: career.isUnlocked(achievement) ? "Conquista desbloqueada" : "Conquista em andamento",
                          title: achievement.title, subtitle: achievement.detail, accent: FootballTheme.gold)
            if let record = career.trophyRecord(for: achievement) {
                FactoryPanel(title: "Contexto original", systemImage: "scroll") {
                    LabeledContent("Clube", value: record.clubName)
                    LabeledContent("Temporada", value: "\(record.season) · dia \(record.matchDay + 1)")
                    Text(record.context).font(.subheadline)
                    if !record.participantNames.isEmpty {
                        LabeledContent("Participantes", value: record.participantNames.joined(separator: ", "))
                    }
                }
                .accessibilityIdentifier("trophy-context")
            } else if career.isUnlocked(achievement) {
                FactoryPanel(title: "Contexto original", systemImage: "scroll") {
                    Text("Esta conquista foi desbloqueada antes do registro de contexto. Só a temporada \(career.achievements[achievement.rawValue] ?? 0) é conhecida.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            } else if let progress = career.achievementProgress(achievement) {
                FactoryPanel(title: "Progresso", systemImage: "chart.bar.fill") {
                    ProgressView(value: Double(progress.current), total: Double(progress.target)).tint(FootballTheme.gold)
                    Text("\(progress.current) de \(progress.target)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            } else {
                Text("Evento pontual: não há contagem, ela abre quando acontecer.").font(.subheadline).foregroundStyle(.secondary)
            }
            if career.isUnlocked(achievement) {
                let highlighted = career.world.legacy.highlights.contains(achievement.rawValue)
                Button {
                    career.setHighlight(achievement, on: !highlighted)
                } label: {
                    Label(highlighted ? "Remover dos destaques" : "Destacar no perfil", systemImage: highlighted ? "star.slash" : "star")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("trophy-highlight")
                if !highlighted && career.world.legacy.highlights.count >= FootballCareer.legacyHighlightLimit {
                    Text("Máximo de \(FootballCareer.legacyHighlightLimit) destaques. Remova um para escolher outro.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let text = career.shareText(for: achievement) {
                    ShareLink(item: text) { Label("Compartilhar marco", systemImage: "square.and.arrow.up") }
                        .accessibilityIdentifier("trophy-share")
                }
            }
        }
        .factoryPage()
        .navigationTitle("Conquista")
    }
}

/// Títulos, recordes e temporadas em ordem cronológica inversa (TRO-04).
struct FootballTimelinePanel: View {
    let career: FootballCareer

    var body: some View {
        FactoryPanel(title: "Linha do tempo", systemImage: "clock.arrow.circlepath") {
            let entries = career.careerTimeline
            if entries.isEmpty {
                Text("Títulos, recordes e temporadas aparecem aqui conforme a carreira avança.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(entries.prefix(20)) { entry in
                HStack(alignment: .top, spacing: 10) {
                    Text("T\(entry.season)").font(.caption.weight(.heavy).monospacedDigit()).frame(width: 28, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title).font(.subheadline.weight(.semibold))
                        Text(entry.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("career-timeline")
    }
}
