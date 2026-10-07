import SwiftUI

// MARK: - App Academia

/// A base num app só: categorias, promessas com potencial estimado, peneira e programa de formação.
struct FootballAcademyView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var selected: YouthSelection?
    @State private var tryoutRegion: Int?

    struct YouthSelection: Identifiable {
        let id: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Categoria de base",
                title: "Academia",
                subtitle: "Descubra promessas, acompanhe a evolução e decida quem sobe para o elenco principal. O potencial é uma estimativa: observar os jovens deixa o número mais preciso.",
                accent: FootballTheme.accent
            )
            HStack(spacing: 12) {
                FactoryMetric(label: "Nível", value: "\(career.youthAcademyLevel)", symbol: "building.columns.fill", tint: FootballTheme.accent, animatesValue: true)
                FactoryMetric(label: "Ações", value: "\(career.academy.points)/\(career.academyPointsMax)", symbol: "bolt.fill", tint: .orange, animatesValue: true)
                FactoryMetric(label: "Jovens", value: "\(career.youthRoster.count)/\(FootballCareer.youthRosterLimit)", symbol: "person.3.fill", tint: .blue, animatesValue: true)
            }
            .accessibilityIdentifier("academy-metrics")
            programPanel
            tryoutPanel
            scoutingPanel
            competitionPanel
            ForEach(YouthCategory.allCases) { category in categoryPanel(category) }
            ForEach(career.youthCupHistory.suffix(3).reversed()) { result in
                Text("Copinha T\(result.season): \(result.userResult) · campeão \(FootballSeason.teamName(result.winnerID))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .factoryPage()
        .navigationTitle("Academia")
        .sheet(item: $selected) { selection in
            FootballYouthDetailView(career: $career, playerID: selection.id, onAlert: onAlert)
        }
        .accessibilityIdentifier("academy-app")
    }

    // MARK: Painéis

    private var programPanel: some View {
        FactoryPanel(title: "Programa de formação", systemImage: "graduationcap.fill") {
            Picker("Programa", selection: Binding(get: { career.world.growth.youthProgram }, set: { career.setYouthProgram($0) })) {
                ForEach(YouthProgram.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(career.world.growth.youthProgram.summary).font(.caption).foregroundStyle(.secondary)
            Text("Cada jovem pode ter um foco próprio na ficha. Sem foco, vale este programa.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var tryoutPanel: some View {
        FactoryPanel(title: "Peneira", systemImage: "figure.soccer") {
            Picker("Região", selection: $tryoutRegion) {
                Text("Qualquer região").tag(Int?.none)
                ForEach(Array(LeagueTeam.regionNames.enumerated()), id: \.offset) { index, name in
                    Text(name).tag(Int?.some(index))
                }
            }
            .pickerStyle(.menu)
            Button {
                if career.holdTryout(region: tryoutRegion).isEmpty {
                    onAlert(career.canHoldTryout() ?? "Não foi possível realizar a peneira.")
                }
            } label: {
                Label("Fazer peneira · \(FootballFormat.money(career.tryoutCost))", systemImage: "figure.soccer").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("academy-tryout")
            Text("Uma peneira por temporada traz 2 jovens da região escolhida.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var scoutingPanel: some View {
        FactoryPanel(title: "Captação e parcerias", systemImage: "map.fill") {
            if career.academy.partnerships.isEmpty {
                Text("Sem parcerias ainda. Uma escola (\(FootballFormat.money(PartnershipKind.school.signCost))) ou um clube parceiro (\(FootballFormat.money(PartnershipKind.club.signCost))) traz candidatos da região a cada chegada anual. Sem parceria, a base recebe só os candidatos da região do clube.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(career.academy.partnerships) { partnership in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(partnership.kind.title).font(.subheadline.weight(.semibold))
                        Text("\(LeagueTeam.regionNames[partnership.region]) · manutenção \(FootballFormat.money(partnership.kind.upkeep)) por ano")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Encerrar", role: .destructive) { career.cancelPartnership(id: partnership.id) }
                        .buttonStyle(.bordered)
                        .font(.caption.weight(.bold))
                }
            }
            ForEach(PartnershipKind.allCases) { kind in
                Menu {
                    ForEach(Array(LeagueTeam.regionNames.enumerated()), id: \.offset) { index, name in
                        Button("\(name) · \(FootballFormat.money(kind.signCost))") {
                            if let reason = career.canSignPartnership(kind: kind, region: index) {
                                onAlert(reason)
                            } else {
                                career.signPartnership(kind: kind, region: index)
                            }
                        }
                    }
                } label: {
                    Label("Nova parceria: \(kind.title)", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("academy-partner-\(kind.rawValue)")
            }
            Text("Cada parceria traz candidatos da sua região a cada chegada anual. \(PartnershipKind.school.summary) \(PartnershipKind.club.summary)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var competitionPanel: some View {
        FactoryPanel(title: "Campeonatos de base", systemImage: "trophy.fill") {
            let results = Array(career.academy.leagueResults.suffix(6).reversed())
            if results.isEmpty {
                Text("Ainda sem campeonato. Cada categoria joga na metade da temporada, com oito equipes, todos contra todos. O resultado aparece aqui.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(results) { result in
                HStack {
                    Text("\(result.category.title) · temporada \(result.season)").font(.subheadline)
                    Spacer()
                    Text(result.champion ? "Campeão" : "\(result.position)º · \(result.wins) vitórias")
                        .font(.caption.weight(.bold))
                }
            }
            Text("Os 11 melhores de cada categoria jogam 900 minutos e evoluem mais. Quem fica no banco joga 150.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func categoryPanel(_ category: YouthCategory) -> some View {
        let players = career.youth(in: category).sorted { $0.overall > $1.overall }
        return FactoryPanel(title: "\(category.title) · \(players.count)", systemImage: category == .under17 ? "person.crop.circle" : "person.crop.circle.fill") {
            if players.isEmpty {
                Text(Self.emptyHint(category)).font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(players) { player in
                Button { selected = YouthSelection(id: player.id) } label: { row(player) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("academy-row-\(player.id)")
                if player.id != players.last?.id { Divider() }
            }
        }
    }

    /// O que esperar numa categoria vazia: quem chega a cada faixa de idade.
    private static func emptyHint(_ category: YouthCategory) -> String {
        switch category {
        case .under15: return "Ainda sem atletas de até 15 anos. Algumas chegadas anuais trazem jovens dessa idade."
        case .under17: return "Ainda sem atletas de 16 e 17 anos. Eles chegam nas janelas anuais de captação."
        case .under20: return "Ainda sem atletas de 18 e 19 anos. Eles chegam nas janelas anuais de captação."
        }
    }

    private func row(_ player: FootballPlayer) -> some View {
        let estimate = career.potentialEstimate(for: player)
        let traits = career.revealedTraits(for: player)
        return HStack(spacing: 12) {
            RatingBadge(value: player.overall)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(player.age) anos · \(player.detail.title) · \(career.academyProfile(for: player).hometown)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if !traits.isEmpty || player.has(.prodigy) {
                    HStack(spacing: 4) {
                        if player.has(.prodigy) { PillLabel(text: "Promessa precoce", systemImage: "sparkles", tint: FootballTheme.gold) }
                        ForEach(traits) { PillLabel(text: $0.title, systemImage: $0.symbol) }
                    }
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text("Potencial").font(.caption2).foregroundStyle(.secondary)
                Text("\(estimate.lowerBound)–\(estimate.upperBound)").font(.subheadline.weight(.bold).monospacedDigit())
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Ficha do jovem

struct FootballYouthDetailView: View {
    @Binding var career: FootballCareer
    let playerID: Int
    let onAlert: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsRelease = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let player = career.player(playerID), player.isYouth {
                    content(player)
                } else {
                    Text("Este jovem deixou a base.").foregroundStyle(.secondary).padding(24)
                }
            }
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle(career.player(playerID)?.name ?? "Jovem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fechar") { dismiss() } } }
        }
        .accessibilityIdentifier("academy-detail")
    }

    private func content(_ player: FootballPlayer) -> some View {
        let profile = career.academyProfile(for: player)
        let estimate = career.potentialEstimate(for: player)
        let weeks = career.observedWeeks(for: player.id)
        let followUp = career.academyFollowUp(for: player.id)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                RatingBadge(value: player.overall, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.name).font(.title3.bold())
                    Text("\(player.age) anos · \(player.detail.title) · \(profile.hometown)").font(.caption).foregroundStyle(.secondary)
                }
            }
            FactoryPanel(title: "Potencial estimado", systemImage: "scope") {
                Text("\(estimate.lowerBound)–\(estimate.upperBound)").font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                rangeBar(estimate)
                Text("Observado há \(weeks) semana(s) · margem de erro de até \(career.potentialMargin(for: player)) ponto(s). Quanto mais você acompanha, mais preciso fica.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            traitsPanel(player, profile: profile)
            FactoryPanel(title: "Formação", systemImage: "figure.run") {
                Picker("Foco", selection: Binding<YouthProgram?>(
                    get: { followUp?.focus },
                    set: { career.setYouthFocus(playerID: player.id, focus: $0) }
                )) {
                    Text("Programa geral").tag(YouthProgram?.none)
                    ForEach(YouthProgram.allCases.filter { $0 != .balanced }) { Text($0.title).tag(YouthProgram?.some($0)) }
                }
                .pickerStyle(.menu)
                mentorRow(player, followUp: followUp)
                Text("Minutos de jogo nesta temporada: \(career.academy.minutes[player.id, default: 0]).")
                    .font(.caption.weight(.semibold))
                Text("Mentor e observação gastam ações (\(career.academy.points)/\(career.academyPointsMax)). Uma ação volta a cada dia de jogo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            actions(player)
        }
        .padding(16)
    }

    private func rangeBar(_ range: ClosedRange<Int>) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let low = CGFloat(max(40, min(99, range.lowerBound)) - 40) / 59
            let high = CGFloat(max(40, min(99, range.upperBound)) - 40) / 59
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule().fill(FootballTheme.accent)
                    .frame(width: max(8, width * (high - low)))
                    .offset(x: width * low)
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }

    private func traitsPanel(_ player: FootballPlayer, profile: YouthProfile) -> some View {
        let revealed = career.revealedTraits(for: player)
        return FactoryPanel(title: "Perfil", systemImage: "person.text.rectangle") {
            if revealed.isEmpty && !player.has(.prodigy) {
                Text("Ainda sem traços descobertos. Observe o jovem para conhecê-lo melhor.").font(.subheadline).foregroundStyle(.secondary)
            }
            if player.has(.prodigy) {
                Label("Promessa precoce: potencial muito acima do atual.", systemImage: "sparkles").font(.subheadline.weight(.semibold))
            }
            ForEach(revealed) { trait in
                VStack(alignment: .leading, spacing: 2) {
                    Label(trait.title, systemImage: trait.symbol).font(.subheadline.weight(.semibold))
                    Text(trait.summary).font(.caption).foregroundStyle(.secondary)
                }
            }
            let hidden = profile.traits.count - revealed.count
            if hidden > 0 {
                Text("\(hidden) traço(s) por descobrir.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func mentorRow(_ player: FootballPlayer, followUp: YouthFollowUp?) -> some View {
        let mentor = followUp?.mentorID.flatMap { career.player($0) }
        if let mentor, career.isValidMentor(mentor.id) {
            HStack {
                Label("Mentor: \(mentor.name)", systemImage: "person.2.fill").font(.subheadline)
                Spacer()
                Button("Remover") { career.clearMentor(playerID: player.id) }.font(.caption.weight(.bold))
            }
        } else {
            Menu {
                ForEach(career.mentorCandidates.prefix(8)) { veteran in
                    Button("\(veteran.name) · \(veteran.age) anos") {
                        if let reason = career.canAssignMentor(playerID: player.id, mentorID: veteran.id) {
                            onAlert(reason)
                        } else {
                            career.assignMentor(playerID: player.id, mentorID: veteran.id)
                        }
                    }
                }
            } label: {
                Label("Escolher mentor entre os veteranos", systemImage: "person.2")
            }
            .disabled(career.mentorCandidates.isEmpty)
            .accessibilityIdentifier("academy-mentor")
            if career.mentorCandidates.isEmpty {
                Text("Nenhum veterano de 27 anos ou mais disponível para ser mentor.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func actions(_ player: FootballPlayer) -> some View {
        VStack(spacing: 10) {
            Button {
                if let reason = career.canObserve(playerID: player.id) { onAlert(reason) } else { career.observeYouth(playerID: player.id) }
            } label: {
                Label("Observar de perto · \(FootballFormat.money(FootballCareer.academyObserveCost)) · 1 ação", systemImage: "binoculars.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("academy-observe")
            Button {
                if career.promoteYouth(playerID: player.id) { dismiss() } else { onAlert("Sem vaga no elenco ou folha salarial no teto.") }
            } label: {
                Label("Promover ao elenco principal", systemImage: "arrow.up.circle.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .disabled(!career.canPromote(playerID: player.id))
            .accessibilityIdentifier("academy-promote")
            Button(role: .destructive) { confirmsRelease = true } label: {
                Label("Dispensar", systemImage: "xmark.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .confirmationDialog("Dispensar \(player.name)?", isPresented: $confirmsRelease, titleVisibility: .visible) {
                Button("Dispensar", role: .destructive) {
                    career.releaseYouth(playerID: player.id)
                    dismiss()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("O jovem sai do clube e vai para o mercado.")
            }
            .accessibilityIdentifier("academy-release")
        }
    }
}
