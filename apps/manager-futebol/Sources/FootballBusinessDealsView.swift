import SwiftUI

/// Negócios: naming negociado, projeto social em etapas e agenda de amistosos e turnê (NEG-03 / NEG-04 / NEG-05).
struct FootballBusinessDealsHub: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FootballNamingTalkPanel(career: $career, onAlert: onAlert)
            FootballSocialProjectPanel(career: $career, onAlert: onAlert)
            FootballFriendlyAgendaPanel(career: $career, onAlert: onAlert)
        }
    }
}

struct FootballNamingTalkPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var ask = 1.1
    @State private var seasons = 3
    @State private var keepName = true

    var body: some View {
        if career.world.business.naming == nil, !career.world.business.namingOffers.isEmpty || career.openNamingTalk != nil {
            FactoryPanel(title: "Negociar o nome do estádio", systemImage: "signature") {
                if let talk = career.openNamingTalk {
                    let value = Int(Double(talk.offer.perSeason) * ask / 10_000) * 10_000
                    Text("\(talk.offer.sponsor) oferece \(FootballFormat.money(talk.offer.perSeason))/temporada.").font(.subheadline.weight(.semibold))
                    Stepper("Pedido: \(FootballFormat.money(value))/temporada", value: $ask, in: 0.9...1.6, step: 0.05).font(.caption)
                    Stepper("Duração: \(seasons) temporada(s)", value: $seasons, in: 1...6).font(.caption)
                    Toggle("Manter o nome tradicional junto (−15% no valor)", isOn: $keepName).font(.caption)
                    Text("Reação esperada da torcida: humor −\(career.namingBacklash(keepTraditionalName: keepName)).")
                        .font(.caption2).foregroundStyle(.secondary)
                    if let counter = talk.counterPerSeason {
                        Text("Última contraproposta da marca: \(FootballFormat.money(counter))/temporada.").font(.caption2).foregroundStyle(.orange)
                    }
                    Button("Enviar proposta") {
                        switch career.proposeNaming(talkID: talk.id, perSeason: value, seasons: seasons, keepTraditionalName: keepName) {
                        case .agreed(let text), .counter(_, let text), .refused(let text), .notAllowed(let text): onAlert(text)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("naming-propose")
                    ForEach(talk.log.suffix(3), id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
                } else {
                    Text("Em vez de aceitar a primeira oferta, abra uma negociação: valor, duração e se o nome tradicional fica.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(career.world.business.namingOffers) { offer in
                        Button("Negociar com \(offer.sponsor)") { career.startNamingTalk(offerID: offer.id) }
                            .buttonStyle(.bordered).font(.caption.weight(.semibold))
                    }
                }
            }
            .accessibilityIdentifier("naming-talk")
        }
    }
}

struct FootballSocialProjectPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var program: CommunityProgram = .schoolProject

    var body: some View {
        FactoryPanel(title: "Projeto social em etapas", systemImage: "hands.and.sparkles.fill") {
            if let project = career.activeSocialProject {
                Text("\(project.program.title) · \(project.stage.title)").font(.subheadline.weight(.semibold))
                ProgressView(value: Double(project.stage.rawValue), total: 3)
                Text("\(project.peopleReached) pessoas atendidas · \(project.fansGained) torcedores · investido \(FootballFormat.money(project.spent))")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                ForEach(project.reports.suffix(3), id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
            } else {
                Picker("Programa", selection: $program) { ForEach(CommunityProgram.allCases) { Text($0.title).tag($0) } }
                    .pickerStyle(.menu)
                Text("Planejamento (\(SocialProject.Stage.planning.days) jogos, \(FootballFormat.money(career.socialStageCost(program, stage: .planning)))) → execução (\(SocialProject.Stage.execution.days) jogos, \(FootballFormat.money(career.socialStageCost(program, stage: .execution)))) → balanço público.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                let block = career.socialProjectBlocker(program)
                if let block { Text(block).font(.caption2).foregroundStyle(.orange) }
                Button("Começar projeto") { if !career.startSocialProject(program) { onAlert(block ?? "Indisponível.") } }
                    .buttonStyle(.bordered).disabled(block != nil)
                    .accessibilityIdentifier("social-project-start")
            }
            if let last = career.deals.socialProjects.last(where: { !$0.isRunning }), let report = last.reports.last {
                Divider()
                Text(report).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("social-project")
    }
}

struct FootballFriendlyAgendaPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var opponent: Int = -1
    @State private var home = true

    var body: some View {
        FactoryPanel(title: "Agenda de amistosos", systemImage: "calendar.badge.plus") {
            let dates = career.freeFriendlyDates
            let rivals = FootballSeason.teams.filter { $0.id != career.selectedClubID }
            if let date = dates.first {
                Picker("Adversário", selection: $opponent) {
                    Text("Escolha").tag(-1)
                    ForEach(rivals) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.menu)
                Toggle("Em casa", isOn: $home).font(.caption)
                if opponent >= 0 {
                    let estimate = career.friendlyEstimate(opponentID: opponent, home: home)
                    Text("Próxima data livre: dia \(date + 1). Receita prevista \(FootballFormat.money(estimate.revenue)), desgaste de ~\(estimate.fatigue) de condição nos titulares.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Agendar amistoso") {
                        if career.scheduleFriendly(opponentID: opponent, home: home, matchDay: date) == nil {
                            onAlert(career.friendlyBlocker(matchDay: date) ?? "Não foi possível agendar.")
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("friendly-schedule")
                }
            } else {
                Text("Sem datas livres nesta temporada.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(career.deals.friendlies.suffix(4).reversed()) { friendly in
                HStack {
                    Text("Dia \(friendly.matchDay + 1) · \(FootballSeason.teamName(friendly.opponentID))").font(.caption)
                    Spacer()
                    if friendly.status == .scheduled {
                        Button("Cancelar", role: .destructive) { career.cancelFriendly(friendly.id) }.font(.caption2)
                    } else {
                        Text(friendly.result).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
            Divider()
            if let target = career.deals.tourScheduledForSeason {
                Label("Excursão agendada para a pré-temporada \(target).", systemImage: "airplane").font(.caption)
            } else {
                Button("Agendar excursão para a próxima pré-temporada") { if !career.scheduleTour() { onAlert("Não foi possível agendar.") } }
                    .buttonStyle(.bordered).font(.caption)
                    .accessibilityIdentifier("tour-schedule")
            }
        }
        .accessibilityIdentifier("friendly-agenda")
    }
}
