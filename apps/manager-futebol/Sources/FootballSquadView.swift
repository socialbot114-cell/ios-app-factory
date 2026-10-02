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

// MARK: - Ficha do atleta

struct FootballPlayerDetailView: View {
    @Binding var career: FootballCareer
    let playerID: Int
    let onAlert: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmSale = false
    @State private var showSubstitution = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let player = career.player(playerID) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 16) {
                            RatingBadge(value: player.overall, size: 64)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.name).font(.title2.bold())
                                Text("\(player.position.singularTitle) · \(player.age) anos").font(.subheadline).foregroundStyle(.secondary)
                                if player.isInjured {
                                    PillLabel(text: "Lesionado · \(player.injuryRounds) rodada(s)", systemImage: "cross.case.fill", tint: .red)
                                }
                            }
                        }
                        FactoryPanel(title: "Perfil", systemImage: "person.text.rectangle") {
                            detailRow("Geral", "\(player.overall)")
                            detailRow("Potencial", "\(player.potential)")
                            VStack(alignment: .leading, spacing: 6) {
                                detailRow("Energia", "\(player.condition)%")
                                ConditionBar(value: player.condition)
                            }
                            detailRow("Valor de mercado", FootballFormat.money(player.marketValue))
                        }
                        FactoryPanel(title: "Temporada", systemImage: "chart.bar.fill") {
                            detailRow("Jogos", "\(player.appearances)")
                            detailRow("Gols", "\(player.goals)")
                            detailRow("Assistências", "\(player.assists)")
                            detailRow("Gols na carreira", "\(player.careerGoals)")
                        }
                        actions(for: player)
                    }
                    .padding(20)
                } else {
                    Text("Este atleta não está mais no elenco.").padding(20)
                }
            }
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle("Ficha do atleta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
            }
        }
        .tint(FootballTheme.accent)
        .sheet(isPresented: $showSubstitution) {
            FootballSubstitutionSheet(career: $career, outgoingID: career.startingXI.contains(playerID) ? playerID : nil)
        }
    }

    @ViewBuilder
    private func actions(for player: FootballPlayer) -> some View {
        let price = career.quickSalePrice(playerID: player.id)
        FactoryPanel(title: "Ações", systemImage: "hand.tap.fill") {
            if career.startingXI.contains(player.id) {
                Button { showSubstitution = true } label: {
                    Label("Substituir este titular", systemImage: "arrow.left.arrow.right").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Button(role: .destructive) { confirmSale = true } label: {
                Label("Vender agora por \(FootballFormat.money(price))", systemImage: "banknote").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!career.canSell(playerID: player.id))
            .accessibilityIdentifier("sell-player-\(player.id)")
            Text("Venda imediata paga \(Int(FootballCareer.quickSaleRate * 100))% do valor de mercado. Propostas de outros clubes costumam pagar mais. O elenco precisa manter pelo menos \(FootballCareer.minimumRoster) atletas.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .confirmationDialog("Vender \(player.name)?", isPresented: $confirmSale, titleVisibility: .visible) {
            Button("Vender por \(FootballFormat.money(price))", role: .destructive) {
                if career.sellPlayer(playerID: player.id) {
                    dismiss()
                } else {
                    onAlert("Venda bloqueada: o elenco precisa continuar preenchendo a formação.")
                }
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("O atleta vai para o mercado de agentes livres.")
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }
}
