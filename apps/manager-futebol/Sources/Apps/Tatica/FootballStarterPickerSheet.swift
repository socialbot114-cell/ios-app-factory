import SwiftUI

/// Escolha dos titulares: quem começa, quem fica no banco e quem troca quem. Só salva escalação que a formação aceita.
struct FootballStarterPickerSheet: View {
    @Binding var career: FootballCareer
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [Int]
    @State private var selectedStarter: Int?

    init(career: Binding<FootballCareer>) {
        _career = career
        _draft = State(initialValue: career.wrappedValue.startingXI)
    }

    private var problem: String? { career.lineupProblem(draft) }

    private var starters: [FootballPlayer] {
        draft.compactMap { career.player($0) }.sorted { Self.order($0) < Self.order($1) }
    }

    private var reserves: [FootballPlayer] {
        career.clubRoster
            .filter { !draft.contains($0.id) }
            .sorted { (Self.order($0), -$0.overall) < (Self.order($1), -$1.overall) }
    }

    /// Goleiro primeiro, depois defesa, meio e ataque: a lista segue a ordem do campo.
    private static func order(_ player: FootballPlayer) -> Int {
        FootballPosition.allCases.firstIndex(of: player.position) ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summary
                    FactoryPanel(title: "Titulares · \(draft.count)/11", systemImage: "sportscourt.fill") {
                        ForEach(starters) { player in starterRow(player) }
                        if let selectedStarter, let player = career.player(selectedStarter) {
                            Button {
                                draft.removeAll { $0 == selectedStarter }
                                self.selectedStarter = nil
                            } label: {
                                Label("Tirar \(player.name) da escalação", systemImage: "person.badge.minus").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FootballSecondaryButtonStyle())
                            .accessibilityIdentifier("starter-remove")
                        }
                    }
                    FactoryPanel(title: "Banco e reservas · \(reserves.count)", systemImage: "person.2.fill") {
                        if reserves.isEmpty {
                            Text("Todo o elenco já está na escalação.").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(reserves) { player in reserveRow(player) }
                    }
                }
                .padding(16)
            }
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle("Titulares")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                        .disabled(problem != nil)
                        .accessibilityIdentifier("starters-save")
                }
            }
        }
        .tint(FootballTheme.accent)
        .accessibilityIdentifier("starter-picker")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Formação \(career.formation.rawValue)").font(.subheadline.weight(.bold))
            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(.orange)
                    .accessibilityIdentifier("starter-problem")
            } else {
                Label("Escalação pronta para o próximo jogo.", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(.green)
            }
            Text("Toque em um titular para selecioná-lo e depois em um reserva para trocar. Com vaga livre, um reserva entra direto.")
                .font(.caption).foregroundStyle(.secondary)
            rotationHint
            Button {
                draft = career.eligibleLineup()
                selectedStarter = nil
            } label: {
                Label("Usar a escalação ideal", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
            }
            .buttonStyle(FootballSecondaryButtonStyle())
        }
    }

    /// Titulares com pouca energia e a troca sugerida por um reserva descansado. Um toque aplica todas.
    @ViewBuilder
    private var rotationHint: some View {
        let tiredCount = draft.compactMap { career.player($0) }.filter { $0.condition < FootballCareer.tiredCondition }.count
        let swaps = career.rotationSwaps(for: draft)
        if tiredCount > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Label(FootballFormat.plural(tiredCount, "titular cansado", "titulares cansados") + " (energia abaixo de \(FootballCareer.tiredCondition))",
                      systemImage: "battery.25percent")
                    .font(.caption.weight(.medium)).foregroundStyle(.orange)
                    .accessibilityIdentifier("starter-tired")
                if swaps.isEmpty {
                    Text("Nenhum reserva descansado da mesma função rende parecido. Vale o descanso do meio da semana.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(swaps, id: \.outgoingID) { swap in
                        if let out = career.player(swap.outgoingID), let incoming = career.player(swap.incomingID) {
                            Text("\(out.name) (energia \(out.condition)) sai para \(incoming.name) (energia \(incoming.condition))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        for swap in swaps {
                            if let index = draft.firstIndex(of: swap.outgoingID) { draft[index] = swap.incomingID }
                        }
                        selectedStarter = nil
                    } label: {
                        Label("Aplicar rodízio sugerido", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FootballSecondaryButtonStyle())
                    .accessibilityIdentifier("starter-rotation-apply")
                }
            }
        }
    }

    private func starterRow(_ player: FootballPlayer) -> some View {
        let isSelected = selectedStarter == player.id
        return Button {
            selectedStarter = isSelected ? nil : player.id
        } label: {
            playerLine(player, trailing: isSelected ? "Selecionado" : (player.condition < FootballCareer.tiredCondition ? "Cansado" : nil))
                .padding(10)
                .background(isSelected ? FootballTheme.accent.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("starter-\(player.id)")
    }

    private func reserveRow(_ player: FootballPlayer) -> some View {
        let available = player.isAvailable(matchDay: career.matchDayIndex)
        return Button {
            takeReserve(player)
        } label: {
            playerLine(player, trailing: available ? nil : "Indisponível")
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .opacity(available ? 1 : 0.5)
        .accessibilityIdentifier("reserve-\(player.id)")
    }

    private func playerLine(_ player: FootballPlayer, trailing: String?) -> some View {
        HStack(spacing: 12) {
            RatingBadge(value: player.overall)
            VStack(alignment: .leading, spacing: 3) {
                Text(player.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(player.position.title) · energia \(player.condition)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if let trailing { PillLabel(text: trailing, systemImage: "exclamationmark.circle") }
        }
        .contentShape(Rectangle())
    }

    /// Com um titular selecionado, o reserva entra no lugar dele. Sem seleção, entra só se houver vaga.
    private func takeReserve(_ player: FootballPlayer) {
        if let outgoing = selectedStarter, let index = draft.firstIndex(of: outgoing) {
            draft[index] = player.id
            selectedStarter = nil
        } else if draft.count < 11 {
            draft.append(player.id)
        }
    }

    private func save() {
        if career.saveStartingXI(draft) == nil { dismiss() }
    }
}
