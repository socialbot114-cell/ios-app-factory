import SwiftUI

// MARK: - Liga

struct FootballTableView: View {
    let career: FootballCareer
    @State private var section: LeagueSection

    enum LeagueSection: String, CaseIterable, Identifiable {
        case serieA = "Série A"
        case serieB = "Série B"
        case cup = "Copa"
        case scorers = "Artilharia"

        var id: String { rawValue }
    }

    init(career: FootballCareer, initialSection: LeagueSection? = nil) {
        self.career = career
        let fallback: LeagueSection = career.userDivision == .serieB ? .serieB : .serieA
        _section = State(initialValue: initialSection ?? fallback)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Temporada \(career.season) · \(career.completedLeagueRounds) de \(FootballSeason.leagueRounds) rodadas",
                title: section == .cup ? "Copa Nacional" : (section == .scorers ? "Artilharia" : "Classificação"),
                subtitle: subtitle,
                accent: FootballTheme.accent
            )
            Picker("Seção", selection: $section) {
                ForEach(LeagueSection.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("league-section")
            switch section {
            case .serieA: divisionPanels(.serieA)
            case .serieB: divisionPanels(.serieB)
            case .cup: cupPanel
            case .scorers: scorersPanel
            }
        }
        .factoryPage()
        .navigationTitle("Liga")
    }

    private var subtitle: String {
        switch section {
        case .serieA: return "Os 2 últimos caem para a Série B. Pontos, vitórias, saldo e gols marcados definem a ordem."
        case .serieB: return "Os 2 primeiros sobem para a Série A."
        case .cup: return "Mata-mata em jogo único no meio de semana. Empate vai à prorrogação e aos pênaltis."
        case .scorers: return "Gols em todas as competições da temporada."
        }
    }

    // MARK: Divisões

    private func divisionPanels(_ division: Division) -> some View {
        let rows = career.standings(for: division)
        return VStack(alignment: .leading, spacing: 18) {
            FactoryPanel {
                HStack(spacing: 4) {
                    Text("#").frame(width: 20, alignment: .leading)
                    Text("CLUBE").frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(["J", "V", "E", "D", "SG"], id: \.self) { title in
                        Text(title).frame(width: Self.numberWidth, alignment: .trailing)
                    }
                    Text("PTS").frame(width: Self.pointsWidth, alignment: .trailing)
                }
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.secondary)
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    Divider()
                    standingRow(index: index, row: row, division: division)
                }
                HStack(spacing: 12) {
                    if division == .serieA {
                        legend(color: FootballTheme.gold, text: "Líder")
                        legend(color: .red, text: "Rebaixamento")
                    } else {
                        legend(color: .green, text: "Acesso")
                    }
                    legend(color: FootballTheme.accent, text: "Seu clube")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            let latestRound = career.fixtures
                .filter { $0.competition == .league(division) && $0.isPlayed }
                .map(\.round).max()
            if let latestRound {
                FactoryPanel(title: "Resultados · rodada \(latestRound)", systemImage: "checkmark.circle.fill") {
                    roundList(career.fixtures.filter { $0.competition == .league(division) && $0.round == latestRound })
                }
            }
        }
    }

    private static let numberWidth: CGFloat = 24
    private static let pointsWidth: CGFloat = 32

    private func zoneColor(index: Int, division: Division) -> Color? {
        let count = FootballSeason.teamsPerDivision
        if division == .serieA {
            if index == 0 { return FootballTheme.gold }
            if index >= count - FootballSeason.relegationSpots { return .red }
        } else if index < FootballSeason.relegationSpots {
            return .green
        }
        return nil
    }

    private func standingRow(index: Int, row: FootballStanding, division: Division) -> some View {
        let isUser = row.team.id == career.selectedClubID
        let numbers = [row.played, row.wins, row.draws, row.losses]
        let zone = zoneColor(index: index, division: division)
        return HStack(spacing: 4) {
            Text("\(index + 1)")
                .font(.caption.weight(.heavy).monospacedDigit())
                .foregroundStyle(zone ?? .secondary)
                .frame(width: 20, alignment: .leading)
            HStack(spacing: 8) {
                ClubCrest(team: row.team, size: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.team.name)
                        .font(.subheadline.weight(isUser ? .heavy : .semibold))
                        .foregroundStyle(isUser ? FootballTheme.accent : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    FormBadges(results: row.form)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(numbers.enumerated()), id: \.offset) { _, value in
                Text("\(value)").frame(width: Self.numberWidth, alignment: .trailing)
            }
            Text(FootballFormat.signed(row.goalDifference)).frame(width: Self.numberWidth, alignment: .trailing)
            Text("\(row.points)")
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .frame(width: Self.pointsWidth, alignment: .trailing)
        }
        .font(.caption.monospacedDigit())
        .padding(.vertical, 2)
        .overlay(alignment: .leading) {
            if let zone {
                Capsule().fill(zone).frame(width: 3).offset(x: -8)
            }
        }
        .background(isUser ? FootballTheme.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(index + 1)º \(row.team.name), \(row.points) pontos, \(row.played) jogos, saldo \(row.goalDifference)")
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
    }

    // MARK: Copa

    private var cupPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let winner = career.cupWinnerThisSeason, let team = FootballSeason.team(winner) {
                HStack(spacing: 12) {
                    ClubCrest(team: team, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Campeão da Copa").font(.caption.weight(.bold)).foregroundStyle(FootballTheme.gold)
                        Text(team.name).font(.title3.bold())
                    }
                    Spacer()
                    Image(systemName: "trophy.fill").font(.title).foregroundStyle(FootballTheme.gold)
                }
                .padding(16)
                .background(FootballTheme.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            Label(career.userCupStatus, systemImage: "flag.fill")
                .font(.subheadline.weight(.semibold))
            ForEach(CupRound.allCases.reversed(), id: \.self) { round in
                let ties = career.cupFixtures.filter { $0.competition == .cup(round) }
                if !ties.isEmpty {
                    FactoryPanel(title: round.name, systemImage: round == .final ? "trophy" : "rectangle.split.2x1") {
                        roundList(ties)
                    }
                }
            }
            let pending = CupRound.allCases.filter { round in !career.cupFixtures.contains { $0.competition == .cup(round) } }
            if !pending.isEmpty {
                Text("Próximas fases: \(pending.map(\.name).joined(separator: ", ")). O sorteio acontece ao fim de cada fase.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("cup-bracket")
    }

    // MARK: Listas

    private var scorersPanel: some View {
        let scorers = career.topScorers(limit: 15)
        return FactoryPanel(title: "Artilheiros", systemImage: "soccerball") {
            if scorers.isEmpty {
                Text("Ninguém marcou ainda nesta temporada.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(Array(scorers.enumerated()), id: \.element.id) { index, player in
                HStack(spacing: 10) {
                    Text("\(index + 1)").font(.caption.weight(.heavy).monospacedDigit()).foregroundStyle(.secondary).frame(width: 20)
                    if let teamID = player.teamID, let team = FootballSeason.team(teamID) {
                        ClubCrest(team: team, size: 22)
                    } else {
                        Image(systemName: "person.crop.circle.badge.questionmark").foregroundStyle(.secondary).frame(width: 22)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name).font(.subheadline.weight(.semibold))
                            .foregroundStyle(player.teamID == career.selectedClubID ? FootballTheme.accent : .primary)
                        Text("\(player.position.rawValue) · \(player.appearances) jogos · \(player.assists) assist.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(player.goals)").font(.title3.weight(.heavy).monospacedDigit())
                }
                .accessibilityElement(children: .combine)
                if index < scorers.count - 1 { Divider() }
            }
        }
    }

    private func roundList(_ fixtures: [LeagueFixture]) -> some View {
        VStack(spacing: 12) {
            ForEach(fixtures) { fixture in
                VStack(spacing: 3) {
                    HStack(spacing: 8) {
                        teamLabel(fixture.home, alignment: .trailing, isWinner: fixture.competition.isCup && fixture.winner == fixture.home)
                        Group {
                            if let home = fixture.homeGoals, let away = fixture.awayGoals {
                                Text("\(home) – \(away)")
                            } else {
                                Text("×").foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline.weight(.heavy).monospacedDigit())
                        .frame(width: 56)
                        teamLabel(fixture.away, alignment: .leading, isWinner: fixture.competition.isCup && fixture.winner == fixture.away)
                    }
                    if let penalties = fixture.penaltySummary {
                        Text(penalties).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    } else if fixture.wentToExtraTime {
                        Text("após prorrogação").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .background(fixture.involves(career.selectedClubID ?? -1) ? FootballTheme.accent.opacity(0.08) : .clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func teamLabel(_ teamID: Int, alignment: HorizontalAlignment, isWinner: Bool) -> some View {
        let team = FootballSeason.team(teamID)
        return HStack(spacing: 6) {
            if alignment == .trailing { Spacer(minLength: 0) }
            if alignment == .leading, let team { ClubCrest(team: team, size: 20) }
            Text(team?.name ?? "—")
                .font(isWinner ? Font.caption.weight(.heavy) : Font.caption.weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.7)
            if alignment == .trailing, let team { ClubCrest(team: team, size: 20) }
            if alignment == .leading { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Clube

struct FootballClubView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    let onStartChallenge: (ChallengeScenario) -> Void
    let activeSlot: Int
    let slotSummaries: [SaveSlotSummary?]
    let onLoadSlot: (Int) -> Void
    let onNewCareer: (Int) -> Void
    let onDeleteSlot: (Int) -> Void
    @State private var pendingAction: SlotAction?

    enum SlotAction: Identifiable {
        case replace(Int)
        case delete(Int)

        var id: String {
            switch self {
            case .replace(let slot): return "replace-\(slot)"
            case .delete(let slot): return "delete-\(slot)"
            }
        }
    }

    private var leagueTitles: Int {
        career.history.filter { $0.championID == $0.clubID }.count
    }

    private var cupTitles: Int {
        career.history.filter { $0.cupWinnerID == $0.clubID }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let club = career.selectedClub {
                HStack(spacing: 16) {
                    ClubCrest(team: club, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(club.name).font(.title.bold())
                        Text("\(club.city) · \(club.stadium) · \(club.capacity.formatted(.number.locale(Locale(identifier: "pt_BR")))) lugares")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if let division = career.userDivision {
                            PillLabel(text: division.name, tint: division.tint)
                        }
                    }
                }
                HStack(spacing: 12) {
                    FactoryMetric(label: "Títulos da Série A", value: "\(leagueTitles)", symbol: "trophy.fill", tint: FootballTheme.gold)
                    FactoryMetric(label: "Copas", value: "\(cupTitles)", symbol: "trophy", tint: FootballTheme.gold)
                    FactoryMetric(label: "Temporadas", value: "\(career.history.count)", symbol: "calendar", tint: FootballTheme.accent)
                }
                managementPanel
                FactoryPanel(title: "Diretoria", systemImage: "building.columns.fill") {
                    HStack {
                        Text("Meta").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text(career.objectiveText).font(.subheadline.weight(.semibold))
                    }
                    HStack {
                        Text("Confiança").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(career.boardConfidence)%").font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    ConditionBar(value: career.boardConfidence)
                    Text("Vitórias acima do esperado e clássicos vencidos aumentam a confiança. Terminar abaixo da meta com confiança baixa leva à demissão.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                FactoryPanel(title: "Histórico do treinador", systemImage: "clock.arrow.circlepath") {
                    if career.history.isEmpty {
                        Text("Sua primeira temporada ainda está em andamento.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(career.history.reversed()) { record in
                        historyRow(record)
                        if record.id != career.history.first?.id { Divider() }
                    }
                }
                FactoryPanel(title: "Galeria de campeões", systemImage: "trophy") {
                    if career.history.isEmpty {
                        Text("Os primeiros campeões serão conhecidos ao fim da temporada.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(career.history.reversed()) { record in
                        HStack(spacing: 10) {
                            Text("T\(record.season)").font(.caption.weight(.heavy).monospacedDigit()).foregroundStyle(.secondary).frame(width: 30)
                            championLabel(title: "Série A", teamID: record.championID, isUser: record.championID == record.clubID)
                            Spacer(minLength: 4)
                            if let cupWinner = record.cupWinnerID {
                                championLabel(title: "Copa", teamID: cupWinner, isUser: cupWinner == record.clubID)
                            }
                        }
                    }
                }
                savesPanel
                FactoryDemoNotice(message: "Clubes, atletas e competições fictícios")
            }
        }
        .factoryPage()
        .navigationTitle("Clube")
        .confirmationDialog(dialogTitle, isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }),
                            titleVisibility: .visible) {
            switch pendingAction {
            case .replace(let slot):
                Button("Começar nova carreira", role: .destructive) { onNewCareer(slot) }
            case .delete(let slot):
                Button("Apagar carreira", role: .destructive) { onDeleteSlot(slot) }
            case .none:
                EmptyView()
            }
            Button("Cancelar", role: .cancel) { pendingAction = nil }
        } message: {
            Text("Essa ação não pode ser desfeita.")
        }
    }

    private func link<Destination: View>(_ title: String, _ symbol: String, badge: Int = 0, id: String,
                                          @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 28).foregroundStyle(FootballTheme.accent)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer()
                if badge > 0 {
                    Text("\(badge)").font(.caption2.weight(.heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3).background(Color.red, in: Capsule())
                }
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var managementPanel: some View {
        FactoryPanel(title: "Gestão do clube", systemImage: "briefcase.fill") {
            link("Caixa de entrada", "tray.full.fill", badge: career.unreadCount, id: "club-inbox") { FootballInboxView(career: $career, onAlert: onAlert) }
            Divider()
            link("Finanças", "banknote.fill", id: "club-finance") { FootballFinanceView(career: career) }
            Divider()
            link("Estrutura e ingressos", "building.2.fill", id: "club-facilities") { FootballFacilitiesView(career: $career, onAlert: onAlert) }
            Divider()
            link("Comissão técnica", "person.2.fill", id: "club-staff") { FootballStaffView(career: $career, onAlert: onAlert) }
            Divider()
            link("Patrocínio", "megaphone.fill", id: "club-sponsor") { FootballSponsorView(career: $career, onAlert: onAlert) }
            Divider()
            link("História, recordes e convites", "list.star", badge: career.invitations.count, id: "club-story") { FootballStoryView(career: $career, onAlert: onAlert) }
            Divider()
            link("Modos de jogo e tutorial", "dial.medium.fill", id: "club-modes") { FootballModesView(career: $career, onStartChallenge: onStartChallenge) }
        }
    }

    private var dialogTitle: String {
        switch pendingAction {
        case .replace(let slot): return "Substituir a carreira do espaço \(slot + 1)?"
        case .delete(let slot): return "Apagar a carreira do espaço \(slot + 1)?"
        case .none: return ""
        }
    }

    private var savesPanel: some View {
        FactoryPanel(title: "Carreiras salvas", systemImage: "externaldrive.fill") {
            Text("Até \(FootballSaveStore.slotCount) carreiras ao mesmo tempo. O progresso é salvo automaticamente.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(0..<FootballSaveStore.slotCount, id: \.self) { slot in
                slotRow(slot)
                if slot < FootballSaveStore.slotCount - 1 { Divider() }
            }
        }
    }

    private func slotRow(_ slot: Int) -> some View {
        let summary = slotSummaries.indices.contains(slot) ? slotSummaries[slot] : nil
        let team = summary?.clubID.flatMap { FootballSeason.team($0) }
        let isActive = slot == activeSlot
        return HStack(spacing: 12) {
            if let team {
                ClubCrest(team: team, size: 30)
            } else {
                Image(systemName: "plus.circle").font(.title2).foregroundStyle(.secondary).frame(width: 30)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(team?.name ?? (summary == nil ? "Espaço \(slot + 1) vazio" : "Carreira sem clube"))
                    .font(.subheadline.weight(.semibold))
                if let summary {
                    Text("Temporada \(summary.season) · \(summary.division?.name ?? "—") · \(summary.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if isActive {
                PillLabel(text: "EM JOGO", systemImage: "gamecontroller.fill")
                Button { pendingAction = .replace(slot) } label: { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Começar nova carreira neste espaço")
                    .accessibilityIdentifier("new-career")
            } else if summary != nil {
                Button("Carregar") { onLoadSlot(slot) }
                    .buttonStyle(.borderedProminent)
                    .font(.caption.weight(.bold))
                    .accessibilityIdentifier("load-slot-\(slot)")
                Button(role: .destructive) { pendingAction = .delete(slot) } label: { Image(systemName: "trash") }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Apagar carreira do espaço \(slot + 1)")
            } else {
                Button("Nova") { onNewCareer(slot) }
                    .buttonStyle(.bordered)
                    .font(.caption.weight(.bold))
                    .accessibilityIdentifier("new-slot-\(slot)")
            }
        }
    }

    private func championLabel(title: String, teamID: Int, isUser: Bool) -> some View {
        HStack(spacing: 6) {
            if let team = FootballSeason.team(teamID) { ClubCrest(team: team, size: 20) }
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(FootballSeason.teamName(teamID)).font(.caption.weight(isUser ? .heavy : .semibold))
                    .foregroundStyle(isUser ? FootballTheme.gold : .primary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    private func historyRow(_ record: SeasonRecord) -> some View {
        HStack(spacing: 12) {
            Text("T\(record.season)").font(.caption.weight(.heavy).monospacedDigit()).foregroundStyle(.secondary).frame(width: 30)
            if let team = FootballSeason.team(record.clubID) { ClubCrest(team: team, size: 26) }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(record.position)º na \(record.division.name) · \(record.points) pts").font(.subheadline.weight(.semibold))
                Text(historyNote(record))
                    .font(.caption)
                    .foregroundStyle(record.objectiveMet ? .green : .red)
                Text("Copa: \(record.cupResult)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if record.championID == record.clubID || record.cupWinnerID == record.clubID {
                Image(systemName: "trophy.fill").foregroundStyle(FootballTheme.gold)
            } else if record.promoted {
                Image(systemName: "arrow.up.circle.fill").foregroundStyle(.green)
            } else if record.relegated {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.red)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func historyNote(_ record: SeasonRecord) -> String {
        var parts = [record.objectiveMet ? "Meta cumprida" : "Meta não cumprida"]
        if record.promoted { parts.append("acesso") }
        if record.relegated { parts.append("rebaixado") }
        if record.wasFired { parts.append("demitido") }
        return parts.joined(separator: " · ")
    }
}
