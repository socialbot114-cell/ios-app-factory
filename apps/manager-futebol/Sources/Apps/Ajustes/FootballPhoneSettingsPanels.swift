import SwiftUI

/// Preferências do FutOS: avisos por prioridade e app, pausas do avanço rápido, movimento (AJU-02..04).
struct FootballPhonePreferencesPanel: View {
    @Binding var career: FootballCareer

    private var rhythm: Binding<FootballRhythm> {
        Binding(get: { career.world.phone.preferences.rhythmMode }, set: { career.world.phone.preferences.rhythm = $0 })
    }

    private var preferences: Binding<PhonePreferences> {
        Binding(get: { career.world.phone.preferences }, set: { career.world.phone.preferences = $0 })
    }

    var body: some View {
        FactoryPanel(title: "Avisos e movimento", systemImage: "bell.badge") {
            Picker("Avisos", selection: preferences.minimumPriority) {
                Text("Todos").tag(1)
                Text("Importantes").tag(2)
                Text("Só urgentes").tag(3)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings-notification-priority")
            Text("Coletivas e crises de imagem são urgentes e aparecem sempre: ignorá-las tem consequência no jogo.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(PhoneApp.allCases.filter { [.betting, .fantasy, .social, .market, .quests, .messages, .alerts, .brand, .life].contains($0) }) { app in
                Toggle(app.title, isOn: Binding(
                    get: { !preferences.wrappedValue.mutedApps.contains(app.rawValue) },
                    set: { on in
                        if on { preferences.wrappedValue.mutedApps.removeAll { $0 == app.rawValue } }
                        else if !preferences.wrappedValue.mutedApps.contains(app.rawValue) { preferences.wrappedValue.mutedApps.append(app.rawValue) }
                    }))
                    .font(.subheadline)
                    .accessibilityIdentifier("settings-notify-\(app.rawValue)")
            }
            Divider()
            Toggle("Reduzir movimento", isOn: preferences.reduceMotion).font(.subheadline)
                .accessibilityIdentifier("settings-reduce-motion")
            Divider()
            Picker("Ritmo", selection: rhythm) {
                ForEach(FootballRhythm.allCases) { option in Text(option.title).tag(option) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings-rhythm")
            Text(rhythm.wrappedValue.detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Em que situações o avanço rápido deve parar (AJU-03).
struct FootballAdvancePausesPanel: View {
    @Binding var career: FootballCareer

    var body: some View {
        FactoryPanel(title: "Pausas do avanço rápido", systemImage: "pause.circle") {
            toggle("Decisões pendentes", \.decisions)
            toggle("Lesões", \.injuries)
            toggle("Coletivas", \.press)
            toggle("Propostas por atletas", \.offers)
            Text("O avanço rápido para quando uma situação marcada surgir.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func toggle(_ title: String, _ keyPath: WritableKeyPath<AdvancePauses, Bool>) -> some View {
        Toggle(title, isOn: Binding(get: { career.world.phone.preferences.pauses[keyPath: keyPath] },
                                    set: { career.world.phone.preferences.pauses[keyPath: keyPath] = $0 }))
            .font(.subheadline)
    }
}

/// Dificuldade travada durante desafios e histórico de mudanças (AJU-06).
struct FootballDifficultyRulesPanel: View {
    @Binding var career: FootballCareer

    var body: some View {
        FactoryPanel(title: "Dificuldade e regras ativas", systemImage: "dial.medium.fill") {
            Picker("Dificuldade", selection: Binding(get: { career.difficulty }, set: { career.changeDifficulty(to: $0) })) {
                ForEach(Difficulty.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(!career.canChangeDifficulty)
            .accessibilityIdentifier("difficulty-picker")
            Text(career.difficulty.summary).font(.caption).foregroundStyle(.secondary)
            if let reason = career.difficultyLockReason {
                Label(reason, systemImage: "lock.fill").font(.caption.weight(.semibold)).accessibilityIdentifier("difficulty-lock")
            }
            let rules = career.activeChallengeRules
            if !rules.isEmpty {
                Divider()
                Text("Regras do desafio").font(.caption.weight(.bold))
                ForEach(rules, id: \.self) { Text("• \($0)").font(.caption) }
            }
            let changes = career.world.phone.difficultyChanges
            if !changes.isEmpty {
                Divider()
                Text("Mudanças de dificuldade").font(.caption.weight(.bold))
                ForEach(Array(changes.prefix(5).enumerated()), id: \.offset) { _, change in
                    Text("T\(change.season) · dia \(change.matchDay + 1): \(change.from.title) → \(change.to.title)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Resultado das últimas ações, que sobrevive ao fechamento do aviso (OS-06).
struct FootballActionHistoryPanel: View {
    let career: FootballCareer

    var body: some View {
        FactoryPanel(title: "Histórico de ações", systemImage: "list.bullet.clipboard") {
            let log = career.world.phone.actionLog
            if log.isEmpty { Text("Os resultados das suas ações ficam registrados aqui depois que o aviso some.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(log.prefix(10)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.text).font(.subheadline)
                    Text("T\(entry.season) · dia \(entry.matchDay + 1)" + (entry.appID.flatMap(PhoneApp.init(rawValue:)).map { " · \($0.title)" } ?? ""))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("action-history")
    }
}
