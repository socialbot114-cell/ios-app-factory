import SwiftUI

/// Tática: comparativo com o rival, rotação pelo calendário e bolas paradas (TAC-02 / TAC-03 / TAC-04).
struct FootballMatchPrepHub: View {
    @Binding var career: FootballCareer
    /// Recolhido por padrão: o Elenco abre leve e o conteúdo só é montado quando o jogador pede.
    @State private var expanded = false

    var body: some View {
        FactoryPanel(title: "Preparação para o próximo jogo", systemImage: "list.bullet.clipboard") {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                HStack {
                    Text(summary).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption.weight(.bold))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("match-prep-toggle")
        }
        if expanded {
            FootballMatchupPanel(career: career)
            FootballRotationPanel(career: $career)
            FootballSetPiecePanel(career: $career)
        }
    }

    /// Resumo barato: só o próximo adversário, sem cálculos.
    private var summary: String {
        guard let clubID = career.selectedClubID, let fixture = career.nextUserFixture ?? career.upcomingUserFixtures.first else {
            return "Comparativo com o rival, rotação e bolas paradas."
        }
        let rival = FootballSeason.teamName(fixture.home == clubID ? fixture.away : fixture.home)
        return "Contra o \(rival): comparativo, rotação dos próximos jogos e bolas paradas."
    }
}

struct FootballMatchupPanel: View {
    let career: FootballCareer

    var body: some View {
        if let report = career.matchupReport() {
            FactoryPanel(title: "Contra o \(FootballSeason.teamName(report.opponentID))", systemImage: "person.2.badge.gearshape.fill") {
                HStack(spacing: 10) {
                    FactoryMetric(label: "Seu preparo", value: "\(report.ownFitness)", symbol: "bolt.heart.fill",
                                  tint: report.ownFitness >= report.rivalFitness ? .green : .orange)
                    FactoryMetric(label: "Preparo do rival", value: "\(report.rivalFitness)", symbol: "bolt.heart", tint: .gray)
                }
                Text("Estilo do rival: \(report.rivalStyle?.rawValue ?? "desconhecido (ative a preparação)").\(report.isHome ? " Jogo em casa." : " Jogo fora.")")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Destaques: \(report.rivalKeyPlayers.joined(separator: ", "))").font(.caption)
                if !report.ownRoles.isEmpty {
                    Text("Suas funções: \(report.ownRoles.joined(separator: " · "))").font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                }
                ForEach(report.threats) { threat in
                    VStack(alignment: .leading, spacing: 1) {
                        Label(threat.title, systemImage: threat.observed ? "eye.fill" : "questionmark.circle").font(.caption.weight(.semibold))
                        Text("\(threat.detail) \(threat.observed ? "Observado pelos olheiros." : "Estimativa, sem observação.")")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                ForEach(report.suggestions, id: \.self) { Text("→ \($0)").font(.caption2).foregroundStyle(FootballTheme.accent) }
            }
            .accessibilityIdentifier("matchup-report")
        }
    }
}

struct FootballRotationPanel: View {
    @Binding var career: FootballCareer

    var body: some View {
        if let plan = career.rotationPlan() {
            FactoryPanel(title: "Rotação dos próximos \(plan.upcoming.count) jogos", systemImage: "arrow.triangle.2.circlepath") {
                ForEach(plan.reasons, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                if plan.suggestedFocus != career.trainingFocus {
                    Button("Treinar \(plan.suggestedFocus.rawValue.lowercased())") { career.setTrainingFocus(plan.suggestedFocus) }
                        .buttonStyle(.bordered).font(.caption.weight(.semibold))
                        .accessibilityIdentifier("rotation-focus")
                }
                ForEach(plan.rows.prefix(8)) { row in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text(row.name).font(.caption.weight(.semibold))
                            Spacer()
                            Text("\(row.condition) → \(row.projectedCondition)").font(.caption.monospacedDigit())
                                .foregroundStyle(row.projectedCondition < 60 ? Color.red : Color.secondary)
                        }
                        Text(row.promisedStartsLeft > 0 ? "\(row.advice) Promessa: faltam \(row.promisedStartsLeft) titularidade(s)." : row.advice)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .accessibilityIdentifier("rotation-plan")
        }
    }
}

struct FootballSetPiecePanel: View {
    @Binding var career: FootballCareer

    private var routine: SetPieceRoutine { career.setPieceRoutine }

    var body: some View {
        FactoryPanel(title: "Bolas paradas", systemImage: "flag.2.crossed.fill") {
            Picker("Escanteio", selection: Binding(get: { routine.corner }, set: { update(corner: $0) })) {
                ForEach(CornerRoutine.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(routine.corner.summary).font(.caption2).foregroundStyle(.secondary)
            Picker("Falta", selection: Binding(get: { routine.freeKick }, set: { update(freeKick: $0) })) {
                ForEach(FreeKickRoutine.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(routine.freeKick.summary).font(.caption2).foregroundStyle(.secondary)
            takerPicker("Cobrador de escanteio", selection: routine.cornerTakerID) { update(cornerTaker: $0) }
            takerPicker("Cobrador de falta", selection: routine.freeKickTakerID) { update(freeKickTaker: $0) }
            ForEach(career.setPieceAdvice(), id: \.self) { Text($0).font(.caption).foregroundStyle(FootballTheme.accent) }
        }
        .accessibilityIdentifier("set-pieces")
    }

    private func takerPicker(_ title: String, selection: Int?, onChange: @escaping (Int?) -> Void) -> some View {
        Picker(title, selection: Binding(get: { selection ?? -1 }, set: { onChange($0 == -1 ? nil : $0) })) {
            Text("Automático").tag(-1)
            ForEach(career.starters) { player in
                Text("\(player.name)\(player.has(.setPieceSpecialist) ? " ★" : "")").tag(player.id)
            }
        }
        .pickerStyle(.menu)
        .font(.caption)
    }

    private func update(corner: CornerRoutine? = nil, freeKick: FreeKickRoutine? = nil, cornerTaker: Int?? = nil, freeKickTaker: Int?? = nil) {
        var next = routine
        if let corner { next.corner = corner }
        if let freeKick { next.freeKick = freeKick }
        if let cornerTaker { next.cornerTakerID = cornerTaker }
        if let freeKickTaker { next.freeKickTakerID = freeKickTaker }
        career.setSetPieceRoutine(next)
    }
}
