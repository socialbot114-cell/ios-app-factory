import SwiftUI

// MARK: - História, recordes e lendas

struct FootballStoryView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var confirmResign = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                FactoryMetric(label: "Reputação", value: "\(career.reputation)", symbol: "star.circle.fill", tint: FootballTheme.gold)
                FactoryMetric(label: "Máx. prestígio de clube", value: "\(career.maxPrestige)", symbol: "building.columns.fill", tint: .indigo)
            }
            if !career.invitations.isEmpty {
                FactoryPanel(title: "Convites", systemImage: "envelope.open.fill") {
                    ForEach(career.invitations) { invitation in
                        HStack {
                            if let team = FootballSeason.team(invitation.clubID) { ClubCrest(team: team, size: 30) }
                            Text(FootballSeason.teamName(invitation.clubID)).font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Aceitar") {
                                if !career.acceptInvitation(invitation.clubID) { onAlert("Não é possível mudar de clube agora.") }
                            }
                            .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                        }
                    }
                    Text("Aceitar troca o seu clube, mantendo reputação e patrimônio.").font(.caption).foregroundStyle(.secondary)
                }
            }
            recordsPanel
            legendsPanel
            FactoryPanel(title: "Carreira", systemImage: "figure.walk.departure") {
                Button(role: .destructive) { confirmResign = true } label: {
                    Label("Pedir demissão", systemImage: "door.left.hand.open").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Text("Você deixa o clube e escolhe entre propostas. Custa reputação.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .factoryPage()
        .navigationTitle("História")
        .confirmationDialog("Pedir demissão?", isPresented: $confirmResign, titleVisibility: .visible) {
            Button("Pedir demissão", role: .destructive) { career.resign() }
            Button("Cancelar", role: .cancel) { }
        }
    }

    private var recordsPanel: some View {
        let records = career.records
        return FactoryPanel(title: "Recordes do clube", systemImage: "list.star") {
            row("Maior artilheiro", "\(records.topScorerName) · \(records.topScorerGoals)")
            row("Mais jogos", "\(records.mostAppearancesName) · \(records.mostAppearances)")
            row("Maior vitória", records.biggestWin)
            row("Maior derrota", records.biggestLoss)
            row("Maior invencibilidade", "\(records.longestUnbeaten) jogos")
            row("Maior sequência de vitórias", "\(records.longestWinStreak)")
            row("Maior público", records.highestAttendance.formatted(.number.locale(Locale(identifier: "pt_BR"))))
            row("Mais pontos numa temporada", "\(records.mostPointsInSeason)")
        }
    }

    private var legendsPanel: some View {
        FactoryPanel(title: "Galeria de lendas", systemImage: "laurel.leading") {
            if career.legends.isEmpty { Text("Atletas históricos entram aqui ao se aposentar.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(career.legends) { legend in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(legend.name).font(.subheadline.weight(.semibold))
                        Text("\(legend.position.title) · \(legend.appearances) jogos · \(legend.goals) gols").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("T\(legend.lastSeason)").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).multilineTextAlignment(.trailing)
        }
    }
}
