import SwiftUI

/// Marca: indicadores separados, evolução explicada, campanha com briefing e contrato de imagem (MAR-01…05).
struct FootballBrandHub: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FootballBrandIndicatorsPanel(career: career)
            FootballCampaignBriefPanel(career: $career, onAlert: onAlert)
            FootballImageContractPanel(career: $career, onAlert: onAlert)
        }
    }
}

struct FootballBrandIndicatorsPanel: View {
    let career: FootballCareer

    var body: some View {
        let indicators = career.brandIndicators
        FactoryPanel(title: "Imagem, marca e torcida", systemImage: "chart.xyaxis.line") {
            HStack(spacing: 10) {
                FactoryMetric(label: "Imagem do treinador", value: "\(indicators.coachImage)", symbol: "person.crop.circle.fill", tint: .indigo)
                FactoryMetric(label: "Marca do clube", value: "\(indicators.clubBrand)", symbol: "seal.fill", tint: FootballTheme.gold)
                FactoryMetric(label: "Humor da torcida", value: "\(indicators.fanMood)", symbol: "face.smiling.inverse", tint: .green)
            }
            ForEach(BrandIndicators.definitions.keys.sorted(), id: \.self) { name in
                Text("\(name): \(BrandIndicators.definitions[name] ?? "")").font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let movements = career.brandState.movements.suffix(8).reversed()
            if !movements.isEmpty {
                Divider()
                Text("O que mudou e por quê").font(.caption.weight(.semibold))
                ForEach(Array(movements)) { movement in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text("Dia \(movement.worldDay - (career.season - 1) * FootballSeason.matchDaysPerSeason) · \(movement.indicator)")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(movement.delta > 0 ? "+\(movement.delta)" : "\(movement.delta)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(movement.delta > 0 ? Color.green : Color.red)
                        }
                        Text(movement.causes.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .accessibilityIdentifier("brand-indicators")
    }
}

struct FootballCampaignBriefPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var channel: MarketingCampaign = .localMedia
    @State private var objective: CampaignObjective = .fans
    @State private var audience: CampaignAudience = .local
    @State private var budget: CampaignBudget = .standard

    var body: some View {
        FactoryPanel(title: "Campanhas de marketing", systemImage: "megaphone.fill") {
            if let record = career.brandState.campaigns.last(where: \.isRunning) {
                running(record)
            } else {
                briefing
            }
            let history = career.brandState.campaigns.filter { !$0.isRunning }.suffix(3).reversed()
            if !history.isEmpty {
                Divider()
                ForEach(Array(history)) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(record.brief.channel.title) · \(record.brief.objective.title.lowercased())").font(.caption.weight(.semibold))
                            Text("Previsto \(FootballCareer.formatObjective(record.forecast, record.brief.objective)) · realizado \(FootballCareer.formatObjective(record.realized, record.brief.objective))")
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(verdictText(record.verdict)).font(.caption2.weight(.bold)).foregroundStyle(verdictTint(record.verdict))
                    }
                }
            }
        }
        .accessibilityIdentifier("campaign-brief")
    }

    private var briefing: some View {
        let brief = CampaignBrief(channel: channel, objective: objective, audience: audience, budget: budget)
        let block = career.campaignBlocker(brief)
        return VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MarketingCampaign.allCases) { kind in
                        Button { channel = kind } label: {
                            Label(kind.title, systemImage: kind.symbol).font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(channel == kind ? FootballTheme.accent : .secondary)
                        .accessibilityIdentifier("campaign-\(kind.rawValue)")
                    }
                }
            }
            Text(channel.summary).font(.caption).foregroundStyle(.secondary)
            Picker("Objetivo", selection: $objective) { ForEach(CampaignObjective.allCases) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented)
            Picker("Público", selection: $audience) { ForEach(CampaignAudience.allCases) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented)
            Picker("Orçamento", selection: $budget) { ForEach(CampaignBudget.allCases) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented)
            HStack(spacing: 12) {
                FactoryMetric(label: "Custo · \(channel.days) jogos", value: FootballFormat.money(career.campaignCost(brief)), symbol: "banknote", tint: .orange)
                FactoryMetric(label: "Previsão", value: FootballCareer.formatObjective(career.campaignForecast(brief), objective), symbol: "chart.bar.fill", tint: .indigo)
            }
            Text("Combinação canal × público: \(Int((FootballCareer.audienceFit(channel, audience) * 100).rounded()))%. A resposta real varia a cada jogo; a avaliação compara previsto e realizado.")
                .font(.caption2).foregroundStyle(.secondary)
            if let block { Text(block).font(.caption2).foregroundStyle(.orange) }
            Button {
                if !career.launchCampaign(brief) { onAlert(block ?? "Não foi possível lançar a campanha.") }
            } label: {
                Label("Lançar campanha", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(block != nil)
            .accessibilityIdentifier("campaign-launch")
        }
    }

    private func running(_ record: CampaignRecord) -> some View {
        let total = max(1, record.endWorldDay - record.startWorldDay)
        let elapsed = min(total, max(0, career.worldDay - record.startWorldDay))
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(record.brief.channel.title) para \(record.brief.audience.title.lowercased()) · \(record.brief.objective.title.lowercased())")
                .font(.subheadline.weight(.semibold))
            ProgressView(value: Double(elapsed), total: Double(total))
            Text("Realizado até agora \(FootballCareer.formatObjective(record.realized, record.brief.objective)) de \(FootballCareer.formatObjective(record.forecast, record.brief.objective)) previstos.")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func verdictText(_ verdict: CampaignRecord.Verdict?) -> String {
        switch verdict {
        case .success: return "Sucesso"
        case .onTarget: return "No previsto"
        case .below: return "Abaixo"
        case nil: return "No ar"
        }
    }

    private func verdictTint(_ verdict: CampaignRecord.Verdict?) -> Color {
        switch verdict {
        case .success: return .green
        case .below: return .red
        default: return .secondary
        }
    }
}

struct FootballImageContractPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        FactoryPanel(title: "Contrato de imagem", systemImage: "signature") {
            if let contract = career.activeImageContract {
                let days = max(0, contract.deadlineWorldDay - career.worldDay)
                Text("\(contract.brand) · prazo em \(days) dia(s) de jogo").font(.subheadline.weight(.semibold))
                obligation("Comerciais gravados: \(contract.shootsDone)/\(contract.shootsRequired)", met: contract.shootsDone >= contract.shootsRequired)
                obligation("Imagem do treinador ≥ \(contract.minimumImage) (hoje \(career.coachImage))", met: career.coachImage >= contract.minimumImage)
                obligation(contract.hadCrisis ? "Houve crise de imagem" : "Nenhuma crise de imagem", met: !contract.hadCrisis)
                Text("Grave os comerciais pela agenda da Vida (\"Gravar comercial\").").font(.caption2).foregroundStyle(.secondary)
            } else if let offer = career.imageContractOffer {
                Text("\(offer.brand) oferece \(FootballFormat.money(offer.payment)) adiantados.").font(.subheadline.weight(.semibold))
                Text("Obrigações em 10 dias de jogo: \(offer.shootsRequired) comerciais, imagem ≥ \(offer.minimumImage) e nenhuma crise. Cumprir rende bônus de 50%; descumprir devolve metade e custa reputação.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Assinar") { if !career.signImageContract() { onAlert("A proposta não está mais disponível.") } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("image-contract-sign")
            } else {
                Text("Marcas procuram treinadores com imagem a partir de 35. A sua está em \(career.coachImage).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let last = career.brandState.contracts.last(where: { $0.status != .active }) {
                Divider()
                Text(last.status == .fulfilled ? "\(last.brand): contrato cumprido." : "\(last.brand): \(last.failures.joined(separator: "; ")).")
                    .font(.caption2).foregroundStyle(last.status == .fulfilled ? Color.green : Color.red)
            }
        }
        .accessibilityIdentifier("image-contract")
    }

    private func obligation(_ text: String, met: Bool) -> some View {
        Label(text, systemImage: met ? "checkmark.circle.fill" : "circle").font(.caption)
            .foregroundStyle(met ? Color.green : Color.secondary)
    }
}
