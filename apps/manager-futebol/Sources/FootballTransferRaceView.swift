import SwiftUI

/// Disputas com clubes rivais e alternativas de recrutamento no Mercado (F3-05).
struct FootballTransferRacePanel: View {
    @Binding var career: FootballCareer
    let onOpenPlayer: (Int) -> Void

    var body: some View {
        let open = career.openTransferRaces
        let lost = career.transferRaces.last { $0.status == .rivalWon && $0.season == career.season && !$0.alternativeIDs.isEmpty }
        if !open.isEmpty || lost != nil {
            FactoryPanel(title: "Disputas no mercado", systemImage: "figure.run.square.stack.fill") {
                ForEach(open) { race in openRow(race) }
                if let lost { alternatives(lost) }
            }
            .accessibilityIdentifier("transfer-races")
        }
    }

    private func openRow(_ race: TransferRace) -> some View {
        let name = career.player(race.playerID)?.name ?? "Atleta"
        let days = max(0, race.deadlineWorldDay - career.worldDay)
        return Button { onOpenPlayer(race.playerID) } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(days <= 1 ? "Decide ao avançar" : "\(days) dias").font(.caption2.weight(.bold)).foregroundStyle(days <= 1 ? .red : .orange)
                }
                Text("\(FootballSeason.teamName(race.rivalID)) prepara \(FootballFormat.money(race.rivalOffer)) ao \(FootballSeason.teamName(race.sellerID)). Feche antes para ficar com ele.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("race-\(race.id)")
    }

    private func alternatives(_ race: TransferRace) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(career.player(race.playerID)?.name ?? "O atleta") foi para o \(FootballSeason.teamName(race.rivalID)). Alternativas na mesma posição:")
                .font(.caption.weight(.semibold))
            ForEach(race.alternativeIDs, id: \.self) { id in
                if let athlete = career.player(id) {
                    HStack {
                        Button { onOpenPlayer(id) } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(athlete.name).font(.subheadline)
                                Text("\(athlete.age) anos · \(FootballSeason.teamName(athlete.teamID ?? 0)) · pede \(FootballFormat.money(career.askingPrice(for: athlete)))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button(career.watchlist.contains(id) ? "Observando" : "Observar") { career.toggleWatch(playerID: id) }
                            .buttonStyle(.bordered).font(.caption.weight(.semibold))
                    }
                }
            }
        }
    }
}
