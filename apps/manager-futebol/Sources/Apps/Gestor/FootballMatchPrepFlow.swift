import SwiftUI

/// Preparação do jogo em passos: do Gestor ao apito em poucos toques, sem sair do fluxo.
struct FootballMatchPrepFlow: View {
    @Binding var career: FootballCareer
    let onOpenSquad: () -> Void
    let onPlay: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    private var steps: [PreparationItem] { career.matchPreparation().filter { $0.id != "press" } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                if let fixture = career.nextUserFixture {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PREPARAÇÃO · \(fixture.title.uppercased())").font(.caption2.weight(.heavy)).tracking(1.2).foregroundStyle(.secondary)
                        MatchupHeader(home: FootballSeason.team(fixture.home), away: FootballSeason.team(fixture.away), homeScore: nil, awayScore: nil, crestSize: 34)
                    }
                }
                progress
                if steps.indices.contains(index) { stepCard(steps[index]) } else { readyCard }
                Spacer(minLength: 0)
                controls
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle("Preparar a partida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
        }
        .accessibilityIdentifier("prep-flow")
    }

    private var progress: some View {
        let total = steps.count + 1
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { position in
                    let isLast = position == steps.count
                    let done = !isLast && steps.indices.contains(position) && steps[position].done
                    Capsule()
                        .fill(position == index ? FootballTheme.accent : (done ? FootballTheme.accent.opacity(0.4) : Color.primary.opacity(0.12)))
                        .frame(height: 6)
                }
            }
            Text(index < steps.count ? "Passo \(index + 1) de \(steps.count)" : "Tudo pronto")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private func stepCard(_ step: PreparationItem) -> some View {
        FactoryPanel(title: step.title, systemImage: step.done ? "checkmark.circle.fill" : "exclamationmark.circle.fill") {
            Text(step.detail).font(.subheadline).foregroundStyle(.secondary)
            if step.done {
                Label("Em dia", systemImage: "checkmark").font(.subheadline.weight(.semibold)).foregroundStyle(FootballTheme.accent)
            } else {
                action(for: step)
            }
        }
        .accessibilityIdentifier("prep-step-\(step.id)")
    }

    @ViewBuilder
    private func action(for step: PreparationItem) -> some View {
        switch step.id {
        case "scout":
            Button { career.setOpponentPrep(true) } label: { Label("Preparar o rival", systemImage: "binoculars.fill").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("prep-do-scout")
        case "lineup":
            Button { career.repairLineup() } label: { Label("Corrigir a escalação", systemImage: "wand.and.stars").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("prep-do-lineup")
            openSquadButton
        case "style":
            if let opponent = career.predictedOpponentStyle {
                Button { career.setPlayStyle(FootballPlayStyle.bestAnswer(to: opponent)) } label: {
                    Label("Aplicar a sugestão do auxiliar", systemImage: "lightbulb.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("prep-do-style")
            }
        default:
            openSquadButton
        }
    }

    private var openSquadButton: some View {
        Button { dismiss(); onOpenSquad() } label: { Label("Abrir Tática", systemImage: "person.3.fill").frame(maxWidth: .infinity) }
            .buttonStyle(.bordered)
    }

    private var readyCard: some View {
        FactoryPanel(title: "Pronto para o estádio", systemImage: "sportscourt.fill") {
            ForEach(steps) { step in
                Label(step.title, systemImage: step.done ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline).foregroundStyle(step.done ? Color.primary : Color.orange)
            }
            Text("Você pode jogar mesmo com itens em aberto; eles só deixam o time um pouco menos preparado.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if index > 0 {
                Button { withAnimation { index -= 1 } } label: { Label("Voltar", systemImage: "chevron.left").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).accessibilityIdentifier("prep-back")
            }
            if index < steps.count {
                Button { withAnimation { index += 1 } } label: { Label(index == steps.count - 1 ? "Revisar" : "Próximo", systemImage: "chevron.right").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("prep-next")
            } else {
                Button { dismiss(); onPlay() } label: { Label("Ir ao estádio", systemImage: "play.fill") }
                    .buttonStyle(FactoryPrimaryButtonStyle()).accessibilityIdentifier("prep-go")
            }
        }
    }
}
