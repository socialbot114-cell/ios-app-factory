import SwiftUI

// MARK: - Modos: dificuldade, desafios e tutorial

struct FootballModesView: View {
    @Binding var career: FootballCareer
    let onStartChallenge: (ChallengeScenario) -> Void
    var onAlert: (String) -> Void = { _ in }
    var saveSlots: FootballSaveSlotsView? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FootballDifficultyRulesPanel(career: $career)
            if let saveSlots { saveSlots }
            FootballPhonePreferencesPanel(career: $career)
            FootballAdvancePausesPanel(career: $career)
            FootballActionHistoryPanel(career: career)
            if let challenge = career.challenge, let scenario = ChallengeScenario.scenario(id: challenge.scenarioID) {
                FactoryPanel(title: "Desafio ativo", systemImage: "flag.checkered") {
                    Text(scenario.title).font(.subheadline.weight(.bold))
                    Text(scenario.summary).font(.caption).foregroundStyle(.secondary)
                    switch challenge.status {
                    case .active: Label("Em andamento · \(scenario.seasonsAllowed) temporada(s)", systemImage: "hourglass").font(.caption)
                    case .won: Label("Vencido!", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.green)
                    case .failed: Label(challenge.failureReason ?? "Falhou", systemImage: "xmark.seal.fill").font(.caption).foregroundStyle(.red)
                    }
                }
            }
            FactoryPanel(title: "Cenários de desafio", systemImage: "target") {
                Text("Começam uma carreira nova (a carreira atual continua salva no espaço).").font(.caption).foregroundStyle(.secondary)
                ForEach(ChallengeScenario.all) { scenario in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(scenario.title).font(.subheadline.weight(.bold))
                        Text(scenario.summary).font(.caption).foregroundStyle(.secondary)
                        Button("Aceitar desafio") { onStartChallenge(scenario) }
                            .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                            .accessibilityIdentifier("challenge-\(scenario.id)")
                    }
                    if scenario.id != ChallengeScenario.all.last?.id { Divider() }
                }
            }
            FactoryPanel(title: "Primeiros passos · \(career.tutorialProgress.done)/\(career.tutorialProgress.total)", systemImage: "graduationcap.fill") {
                ForEach(career.tutorialSteps) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: step.done ? "checkmark.circle.fill" : "circle").foregroundStyle(step.done ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title).font(.subheadline.weight(.semibold))
                            Text(step.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Toggle("Mostrar dicas no painel", isOn: Binding(get: { !career.tutorialDismissed }, set: { career.tutorialDismissed = !$0 }))
                    .font(.subheadline)
                if career.selectedClubID != nil {
                    Divider()
                    Text("Roteiro da primeira partida")
                        .font(.subheadline.weight(.semibold))
                    Text("Reveja como conferir o time, iniciar a partida e chegar ao resumo.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(career.isFirstCareerGuideActive ? "Recomeçar roteiro" : "Ver roteiro da primeira partida") {
                        career.replayFirstCareerGuide()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("first-run-guide-replay")
                }
            }
        }
        .factoryPage()
        .navigationTitle("Modos de jogo")
    }
}
