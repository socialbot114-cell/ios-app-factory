import SwiftUI

/// Recrutamento no Mercado: negociações por etapas, briefings, candidatos e lista comparativa (TRF-01…06).
struct FootballRecruitmentHub: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    let onOpenPlayer: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !career.openTransferTalks.isEmpty {
                FootballTransferTalksPanel(career: $career, onAlert: onAlert)
            }
            FootballBriefsPanel(career: $career, onAlert: onAlert, onOpenPlayer: onOpenPlayer)
        }
    }
}

// MARK: - Negociações

struct FootballTransferTalksPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var installments = 1
    @State private var years = 3
    @State private var role: SquadStatus = .rotation

    var body: some View {
        FactoryPanel(title: "Negociações", systemImage: "arrow.left.arrow.right.circle.fill") {
            ForEach(career.openTransferTalks) { talk in
                VStack(alignment: .leading, spacing: 8) {
                    header(talk)
                    controls(talk)
                    if let last = talk.log.last { Text(last).font(.caption2).foregroundStyle(.secondary) }
                }
                if talk.id != career.openTransferTalks.last?.id { Divider() }
            }
        }
        .accessibilityIdentifier("transfer-talks")
    }

    private func header(_ talk: TransferTalk) -> some View {
        let name = career.player(talk.playerID)?.name ?? "Atleta"
        let days = talk.deadlineWorldDay.map { max(0, $0 - career.worldDay) }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.semibold))
                Text("\(FootballSeason.teamName(talk.sellerID)) · \(stageTitle(talk.stage))").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let days { Text(days <= 1 ? "Vence ao avançar" : "\(days) dias").font(.caption2.weight(.bold)).foregroundStyle(.orange) }
        }
    }

    @ViewBuilder
    private func controls(_ talk: TransferTalk) -> some View {
        switch talk.stage {
        case .clubOffer:
            let base = career.player(talk.playerID).map { career.askingPrice(for: $0) } ?? 0
            // Mesmo acréscimo do motor: +3% por parcela extra.
            let ask = Int(Double(base) * (1 + 0.03 * Double(installments - 1)) / 10_000) * 10_000
            Stepper("Parcelas: \(installments)x", value: $installments, in: 1...4).font(.caption)
            Text("O clube pede \(FootballFormat.money(ask))\(installments > 1 ? " (+3% por parcela extra)" : "").")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach([0.9, 1.0], id: \.self) { share in
                    let fee = Int(Double(ask) * share / 10_000) * 10_000
                    Button(FootballFormat.money(fee)) { report(career.proposeFee(talkID: talk.id, fee: fee, installments: installments)) }
                        .buttonStyle(.bordered).font(.caption.weight(.semibold))
                }
            }
            walkAway(talk)
        case .clubCounter:
            Text("O clube pede \(FootballFormat.money(talk.clubCounterFee ?? 0)) em \(talk.installments)x.").font(.caption)
            HStack {
                Button("Aceitar") { report(career.acceptClubCounter(talkID: talk.id)) }.buttonStyle(.borderedProminent)
                walkAway(talk)
            }
        case .personalTerms:
            let needed = career.wageNeeded(talk: talk, years: years, role: role) ?? talk.wage
            Picker("Papel", selection: $role) {
                ForEach(SquadStatus.allCases.reversed(), id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            Stepper("Contrato: \(years) ano(s)", value: $years, in: 1...5).font(.caption)
            Text("Para esse papel e duração, o atleta espera cerca de \(FootballFormat.money(needed))/temporada.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach([0.85, 1.0], id: \.self) { share in
                    let wage = Int(Double(needed) * share / 5_000) * 5_000
                    Button(FootballFormat.money(wage)) { report(career.proposeTerms(talkID: talk.id, wage: wage, years: years, role: role)) }
                        .buttonStyle(.bordered).font(.caption.weight(.semibold))
                }
            }
            walkAway(talk)
        case .playerCounter:
            Text("O atleta pede \(FootballFormat.money(talk.playerCounterWage ?? 0))/temporada como \(talk.role.title.lowercased()).").font(.caption)
            HStack {
                Button("Aceitar") { report(career.acceptPlayerCounter(talkID: talk.id)) }.buttonStyle(.borderedProminent)
                walkAway(talk)
            }
        case .agreed:
            if let summary = career.costSummary(talkID: talk.id) {
                Text("Entrada \(FootballFormat.money(summary.upfront)) · parcelas \(FootballFormat.money(summary.laterInstallments)) · salários \(FootballFormat.money(summary.totalWages)) em \(talk.years) ano(s)")
                    .font(.caption.monospacedDigit())
                Text("Custo total \(FootballFormat.money(summary.total)). Menor caixa garantido depois: \(FootballFormat.money(summary.lowestProjectedCash)).")
                    .font(.caption2).foregroundStyle(summary.lowestProjectedCash < 0 ? .red : .secondary)
                if !summary.fitsWageCap { Text("A folha passaria do teto da diretoria.").font(.caption2).foregroundStyle(.red) }
            }
            HStack {
                Button("Assinar") { report(career.signTalk(talkID: talk.id)) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("talk-sign-\(talk.id)")
                walkAway(talk)
            }
        default:
            EmptyView()
        }
    }

    private func walkAway(_ talk: TransferTalk) -> some View {
        Button("Desistir", role: .destructive) { career.walkAwayFromTransferTalk(talkID: talk.id) }
            .buttonStyle(.bordered).font(.caption)
    }

    private func report(_ outcome: TalkOutcome) {
        switch outcome {
        case .accepted: break
        case .counter(let text), .refused(let text), .notAllowed(let text): onAlert(text)
        }
    }

    private func stageTitle(_ stage: TransferTalk.Stage) -> String {
        switch stage {
        case .clubOffer: return "proposta ao clube"
        case .clubCounter: return "contraproposta do clube"
        case .personalTerms: return "condições com o atleta"
        case .playerCounter: return "pedido do atleta"
        case .agreed: return "pronto para assinar"
        case .signed: return "assinado"
        case .collapsed: return "encerrada"
        case .expired: return "expirada"
        }
    }
}

// MARK: - Briefings e comparação

struct FootballBriefsPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    let onOpenPlayer: (Int) -> Void
    @State private var creating = false
    @State private var position: FootballPosition = .midfielder
    @State private var maxAge = 26
    @State private var minOverall = 65
    @State private var role: SquadStatus = .starter

    var body: some View {
        FactoryPanel(title: "Briefings de contratação", systemImage: "list.bullet.clipboard.fill") {
            if career.recruitmentBriefs.isEmpty && !creating {
                Text("Diga o que procura (posição, idade, nível, orçamento e papel) e o olheiro mostra quem se encaixa, com a confiabilidade de cada relatório.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(career.recruitmentBriefs) { brief in briefSection(brief) }
            if creating { form } else if career.recruitmentBriefs.count < FootballCareer.maxBriefs {
                Button { creating = true } label: { Label("Novo briefing", systemImage: "plus.circle.fill") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("brief-new")
            }
        }
        .accessibilityIdentifier("recruitment-briefs")
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Posição", selection: $position) {
                ForEach(FootballPosition.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Stepper("Até \(maxAge) anos", value: $maxAge, in: 18...36).font(.caption)
            Stepper("Nível mínimo \(minOverall)", value: $minOverall, in: 40...90).font(.caption)
            Picker("Papel", selection: $role) {
                ForEach(SquadStatus.allCases.reversed(), id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            Text("Orçamento: até \(FootballFormat.money(max(0, career.transferBudget))) de taxa e \(FootballFormat.money(max(0, career.wageHeadroom))) de folha livre.")
                .font(.caption2).foregroundStyle(.secondary)
            HStack {
                Button("Salvar") {
                    let saved = career.createBrief(position: position, maxAge: maxAge, minOverall: minOverall,
                                                   maxFee: max(0, career.transferBudget), maxWage: max(0, career.wageHeadroom), role: role)
                    if saved == nil { onAlert("No máximo \(FootballCareer.maxBriefs) briefings.") }
                    creating = false
                }
                .buttonStyle(.borderedProminent)
                Button("Cancelar") { creating = false }.buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func briefSection(_ brief: RecruitmentBrief) -> some View {
        let shortlist = career.shortlistComparison(for: brief)
        let candidates = career.candidates(for: brief, limit: 5).filter { !brief.shortlist.contains($0.playerID) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(brief.title).font(.subheadline.weight(.semibold))
                Spacer()
                Button(role: .destructive) { career.deleteBrief(brief.id) } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
            if !shortlist.isEmpty {
                Text("Comparação").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(shortlist) { row in candidateRow(row, brief: brief, pinned: true) }
            }
            Text(candidates.isEmpty ? "Ninguém conhecido cumpre o briefing. Mande olheiros ou afrouxe os critérios." : "Sugestões do olheiro")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(candidates) { row in candidateRow(row, brief: brief, pinned: false) }
        }
    }

    private func candidateRow(_ row: CandidateComparison, brief: RecruitmentBrief, pinned: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button { onOpenPlayer(row.playerID) } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.name).font(.subheadline)
                        Text("\(row.age) anos · geral \(row.overallRange.lowerBound)–\(row.overallRange.upperBound) · \(FootballSeason.teamName(row.clubID ?? 0))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Text("\(row.fit)/5").font(.caption.weight(.bold).monospacedDigit()).foregroundStyle(row.fit == 5 ? .green : .orange)
            }
            Text("Pede \(FootballFormat.money(row.askingPrice)) · salário \(FootballFormat.money(row.wageAsk)) · chega como \(row.expectedRole.title.lowercased())")
                .font(.caption2.monospacedDigit())
            Text(reportText(row.report)).font(.caption2).foregroundStyle(row.report.reliability == .high ? Color.secondary : Color.orange)
            if !row.warnings.isEmpty { Text(row.warnings.joined(separator: " · ")).font(.caption2).foregroundStyle(.orange) }
            HStack(spacing: 8) {
                Button(pinned ? "Tirar da comparação" : "Comparar") { career.toggleShortlist(briefID: brief.id, playerID: row.playerID) }
                    .buttonStyle(.bordered).font(.caption)
                Button("Negociar") {
                    if career.startTransferTalk(playerID: row.playerID) == nil {
                        onAlert(career.transferTalkBlocker(playerID: row.playerID) ?? "Não foi possível abrir a negociação.")
                    }
                }
                .buttonStyle(.bordered).font(.caption)
                .accessibilityIdentifier("talk-start-\(row.playerID)")
            }
        }
        .padding(.vertical, 4)
    }

    private func reportText(_ report: RecruitmentScoutReport) -> String {
        var text = "Relatório \(report.reliability.title.lowercased()) · conhecimento \(report.knowledge)%"
        if let age = report.ageInDays { text += age == 0 ? " · visto hoje" : " · visto há \(age) dia(s)" }
        return text
    }
}
