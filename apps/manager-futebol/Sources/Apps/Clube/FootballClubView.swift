import SwiftUI

struct FootballClubView: View {
    /// O estádio muda de ilustração conforme a capacidade: pequeno, médio, grande e grande à noite.
    static func stadiumImageName(capacity: Int) -> String {
        switch capacity {
        case ..<30_000: return "StadiumPequeno"
        case ..<42_000: return "StadiumMedio"
        case ..<50_000: return "StadiumGrande"
        default: return "StadiumGrandeNoite"
        }
    }

    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    /// Abre outro app do celular (Banco, Marca, Negócios, Ajustes) sem duplicar o que ele já mostra.
    var onOpenApp: (PhoneApp) -> Void = { _ in }

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
                FactoryPanel(title: "Estádio", systemImage: "sportscourt.fill") {
                    Image(Self.stadiumImageName(capacity: career.stadiumCapacity))
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel("Ilustração do estádio do clube")
                    HStack {
                        Label(career.stadiumDisplayName, systemImage: "mappin.and.ellipse")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(career.stadiumCapacity.formatted(.number.locale(Locale(identifier: "pt_BR")))) lugares")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
                FootballBoardEvaluationPanel(career: career)
                FootballBoardMeetingPanel(career: $career, onAlert: onAlert)
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
                otherAppsPanel
                FactoryDemoNotice(message: "Clubes, atletas e competições fictícios")
            }
        }
        .factoryPage()
        .navigationTitle("Clube")
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

    /// O que é do clube como instituição. Dinheiro, marca e negócios têm app próprio; aqui só há atalhos.
    private var managementPanel: some View {
        FactoryPanel(title: "Gestão do clube", systemImage: "briefcase.fill") {
            link("Estrutura e ingressos", "building.2.fill", id: "club-facilities") { FootballFacilitiesView(career: $career, onAlert: onAlert) }
            Divider()
            link("Comissão técnica", "person.2.fill", id: "club-staff") { FootballStaffView(career: $career, onAlert: onAlert) }
            Divider()
            link("História, recordes e convites", "list.star", badge: career.invitations.count, id: "club-story") { FootballStoryView(career: $career, onAlert: onAlert) }
        }
        .accessibilityIdentifier("club-management")
    }

    private var otherAppsPanel: some View {
        FactoryPanel(title: "Em outros apps", systemImage: "square.grid.2x2.fill") {
            Text("Cada assunto mora em um só lugar do FutOS.").font(.caption).foregroundStyle(.secondary)
            shortcut(.bank, "Caixa, folha salarial e extratos")
            Divider()
            shortcut(.brand, "Marketing, TV, torcida e patrocínio")
            Divider()
            shortcut(.business, "Loja, estádio, projetos sociais e amistosos")
            Divider()
            shortcut(.settings, "Carreiras salvas, desafios e tutorial")
        }
    }

    private func shortcut(_ app: PhoneApp, _ detail: String) -> some View {
        Button { onOpenApp(app) } label: {
            HStack(spacing: 12) {
                Image(systemName: app.symbol).frame(width: 28).foregroundStyle(app.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.forward.app").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("club-shortcut-\(app.rawValue)")
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
