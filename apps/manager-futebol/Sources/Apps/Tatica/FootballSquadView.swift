import SwiftUI

struct FootballSquadView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    @State private var substitutionTarget: SubstitutionTarget?
    @State private var selectedPlayer: PlayerSelection?

    struct SubstitutionTarget: Identifiable {
        let id: Int
    }

    struct PlayerSelection: Identifiable {
        let id: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let club = career.selectedClub {
                FactoryHeader(
                    eyebrow: "Elenco · \(career.clubRoster.count)/\(FootballCareer.rosterLimit) atletas",
                    title: club.name,
                    subtitle: "Toque em um titular no campo para trocá-lo. A energia aparece no anel de cada atleta.",
                    accent: FootballTheme.accent
                )
                tacticsPanel
                FactoryPanel(title: "Escalação · \(career.formation.rawValue)", systemImage: "sportscourt.fill") {
                    PitchView(formation: career.formation, starters: career.starters) { player in
                        substitutionTarget = SubstitutionTarget(id: player.id)
                    }
                    .accessibilityIdentifier("squad-pitch")
                    HStack(spacing: 10) {
                        Button {
                            career.autoSelectLineup()
                        } label: {
                            Label("Escalação ideal", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("auto-lineup")
                        Button {
                            substitutionTarget = SubstitutionTarget(id: -1)
                        } label: {
                            Label("Trocar titular", systemImage: "arrow.left.arrow.right").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.subheadline.weight(.semibold))
                    ForEach(career.lineupWarnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.medium)).foregroundStyle(.orange)
                    }
                }
                FootballTacticalPlansPanel(career: $career)
                FootballMatchPrepHub(career: $career)
                instructionsPanel
                rolesPanel
                trainingPanel
                ForEach(FootballPosition.allCases, id: \.self) { position in
                    let group = career.clubRoster.filter { $0.position == position }
                    if !group.isEmpty {
                        FactoryPanel(title: "\(position.title) · \(group.count)", systemImage: symbol(for: position)) {
                            ForEach(group) { player in
                                Button { selectedPlayer = PlayerSelection(id: player.id) } label: {
                                    PlayerRow(player: player, isStarter: career.startingXI.contains(player.id))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("player-\(player.id)")
                                if player.id != group.last?.id { Divider() }
                            }
                        }
                    }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Elenco e tática")
        .onAppear { career.markTutorialSeen("squad") }
        .sheet(item: $substitutionTarget) { target in
            FootballSubstitutionSheet(career: $career, outgoingID: target.id >= 0 ? target.id : nil)
        }
        .sheet(item: $selectedPlayer) { selection in
            FootballPlayerDetailView(career: $career, playerID: selection.id, onAlert: onAlert)
        }
    }

    private var tacticsPanel: some View {
        FactoryPanel(title: "Plano de jogo", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
            Picker("Formação", selection: Binding(
                get: { career.formation },
                set: { newValue in
                    if !career.setFormation(newValue) {
                        onAlert("O elenco não tem atletas saudáveis suficientes para jogar no \(newValue.rawValue).")
                    }
                }
            )) {
                ForEach(FootballFormation.allCases) { formation in
                    Text(formation.rawValue).tag(formation)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("formation-picker")
            Text(career.formation.summary).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("Estilo").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Estilo de jogo", selection: Binding(
                    get: { career.playStyle },
                    set: { career.setPlayStyle($0) }
                )) {
                    ForEach(FootballPlayStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("play-style-picker")
            }
            Text(career.playStyle.summary).font(.caption).foregroundStyle(.secondary)
            Label("Desgaste por jogo: \(career.playStyle.fatigueCost) pontos de energia", systemImage: "bolt.heart.fill")
                .font(.caption.weight(.medium)).foregroundStyle(.orange)
        }
    }

    private var instructionsPanel: some View {
        FactoryPanel(title: "Instruções de equipe", systemImage: "slider.horizontal.3") {
            instructionPicker("Altura da linha", TeamInstructions.lineHeightTitles, $career.teamInstructions.lineHeight)
            instructionPicker("Ritmo", TeamInstructions.tempoTitles, $career.teamInstructions.tempo)
            instructionPicker("Largura", TeamInstructions.widthTitles, $career.teamInstructions.width)
            instructionPicker("Pressão", TeamInstructions.pressingTitles, $career.teamInstructions.pressing)
            Toggle("Fazer cera quando estiver ganhando", isOn: $career.teamInstructions.timeWasting).font(.subheadline)
            HStack {
                Text("Batedor de pênaltis").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Batedor", selection: $career.penaltyTakerID) {
                    Text("Automático").tag(Int?.none)
                    ForEach(career.starters) { Text($0.name).tag(Int?.some($0.id)) }
                }
                .pickerStyle(.menu)
            }
            Text("Valem do início da partida; você ajusta tudo de novo ao vivo.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func instructionPicker(_ title: String, _ names: [String], _ binding: Binding<Level3>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Picker(title, selection: binding) {
                ForEach(Level3.allCases) { Text(names[$0.rawValue]).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var rolesPanel: some View {
        FactoryPanel(title: "Funções dos titulares", systemImage: "person.crop.rectangle.stack.fill") {
            ForEach(career.starters.filter { $0.position != .goalkeeper }) { player in
                HStack {
                    Text(player.name).font(.subheadline).lineLimit(1)
                    Spacer()
                    Picker("Função", selection: Binding(
                        get: { career.playerRoles[player.id] ?? .balanced },
                        set: { career.playerRoles[player.id] = $0 == .balanced ? nil : $0 }
                    )) {
                        ForEach(PlayerRole.options(for: player.detail)) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var trainingPanel: some View {
        FactoryPanel(title: "Treino semanal", systemImage: "figure.run") {
            HStack {
                Text("Foco").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Foco do treino", selection: Binding(
                    get: { career.trainingFocus },
                    set: { career.setTrainingFocus($0) }
                )) {
                    ForEach(FootballTrainingFocus.allCases) { focus in
                        Text(focus.rawValue).tag(focus)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("training-focus-picker")
            }
            Text(career.trainingFocus.summary).font(.caption).foregroundStyle(.secondary)
            Picker("Intensidade", selection: Binding(
                get: { career.trainingIntensity },
                set: { career.setTrainingIntensity($0) }
            )) {
                ForEach(FootballTrainingIntensity.allCases) { intensity in
                    Text(intensity.rawValue).tag(intensity)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("training-intensity-picker")
            HStack {
                Text("Foco secundário").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Foco secundário", selection: Binding(
                    get: { career.secondaryTrainingFocus },
                    set: { career.setSecondaryTrainingFocus($0) }
                )) {
                    Text("Nenhum").tag(FootballTrainingFocus?.none)
                    ForEach(FootballTrainingFocus.allCases) { Text($0.rawValue).tag(FootballTrainingFocus?.some($0)) }
                }
                .pickerStyle(.menu)
            }
            Toggle("Preparar para o próximo rival", isOn: Binding(get: { career.opponentPrep }, set: { career.setOpponentPrep($0) }))
                .font(.subheadline)
            Text("Aplicado antes de cada partida. Intensidade maior desenvolve mais atletas, mas recupera menos energia.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func symbol(for position: FootballPosition) -> String {
        switch position {
        case .goalkeeper: return "hand.raised.fill"
        case .defender: return "shield.lefthalf.filled"
        case .midfielder: return "arrow.triangle.branch"
        case .forward: return "scope"
        }
    }
}
