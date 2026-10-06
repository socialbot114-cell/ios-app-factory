import SwiftUI

/// Conversa de vestiário, mostrada no intervalo da partida ao vivo.
struct FootballHalftimeTalkPanel: View {
    @Binding var career: FootballCareer
    var locked = false
    @State private var reaction: String?

    var body: some View {
        let recommended = career.recommendedHalftimeTalk()
        let difference = career.liveMatch?.userGoalDifference ?? 0
        FactoryPanel(title: "Vestiário · intervalo", systemImage: "person.2.wave.2.fill") {
            if let reaction {
                Label(reaction, systemImage: "checkmark.circle.fill").font(.subheadline.weight(.medium)).foregroundStyle(FootballTheme.accent)
            } else {
                Text(difference < 0 ? "Você perde por \(-difference). O que diz ao grupo?" : (difference > 0 ? "Você vence por \(difference). O que diz ao grupo?" : "Jogo empatado. O que diz ao grupo?"))
                    .font(.subheadline).foregroundStyle(.secondary)
                // Compacto: a conversa ocupa pouco espaço para os controles da partida continuarem à vista.
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(HalftimeTalk.allCases) { talk in
                        Button {
                            reaction = career.holdHalftimeTalk(talk)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: talk.symbol).font(.title3)
                                Text(talk.title).font(.subheadline.weight(.bold))
                                if talk == recommended { Text("sugerido").font(.caption2.weight(.heavy)).foregroundStyle(FootballTheme.accent) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(talk == recommended ? FootballTheme.accent.opacity(0.14) : Color.primary.opacity(0.05),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(locked)
                        .accessibilityLabel("\(talk.title). \(talk.summary)")
                        .accessibilityIdentifier("halftime-\(talk.rawValue)")
                    }
                }
                if let recommended { Text(recommended.summary).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .accessibilityIdentifier("halftime-talk")
    }
}

/// Fechamento do jogo: gols, destaque do seu time e números, antes do impacto na temporada.
struct FootballFullTimeCard: View {
    let digest: FullTimeDigest

    var body: some View {
        FactoryPanel(title: "Resumo do jogo", systemImage: "list.bullet.clipboard.fill") {
            if digest.goalLines.isEmpty {
                Text("Sem gols: jogo travado.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(digest.goalLines.enumerated()), id: \.offset) { _, line in
                        Label(line, systemImage: "soccerball").font(.subheadline)
                    }
                }
            }
            if let star = digest.starLine {
                Label("Destaque: \(star)", systemImage: "star.fill").font(.subheadline.weight(.semibold)).foregroundStyle(FootballTheme.gold)
            }
            HStack(spacing: 10) {
                stat("Posse", "\(digest.possessionUser)%")
                stat("Finalizações", "\(digest.shotsUser) × \(digest.shotsRival)")
            }
            if let cards = digest.cardsLine { Label(cards, systemImage: "rectangle.fill").font(.caption).foregroundStyle(.orange) }
        }
        .accessibilityIdentifier("fulltime-card")
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
