import SwiftUI

// MARK: - Vida do treinador

struct FootballCoachLifeView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var lastResult: String?
    @State private var investAmount = 50_000

    private var coach: CoachProfile { career.world.coach }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                FactoryMetric(label: "Caixa pessoal", value: FootballFormat.money(coach.personalCash), symbol: "wallet.bifold.fill", tint: FootballTheme.gold)
                FactoryMetric(label: "Salário/temporada", value: FootballFormat.money(career.coachSalaryPerSeason), symbol: "briefcase.fill", tint: .teal)
            }
            FactoryPanel(title: "Condição", systemImage: "heart.text.square.fill") {
                gauge("Energia", coach.energy, good: true)
                gauge("Estresse", coach.stress, good: false)
                Text("\(coach.licenseName) · reputação \(career.reputation)").font(.caption).foregroundStyle(.secondary)
                if coach.stress >= 85 {
                    Label("Estresse no limite: a diretoria percebe e o rendimento cai.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.red)
                }
            }
            if let lastResult {
                Label(lastResult, systemImage: "checkmark.circle.fill").font(.subheadline.weight(.medium)).foregroundStyle(FootballTheme.accent)
            }
            FactoryPanel(title: "Agenda do dia", systemImage: "calendar.badge.clock") {
                Text("Uma atividade por dia de jogo. Descansar recupera energia; as outras rendem dinheiro, fama ou licenças.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(CoachActivity.allCases) { activity in
                    let block = career.canDo(activity)
                    Button {
                        if let result = career.doActivity(activity) { lastResult = result.text } else { onAlert(block ?? "Indisponível.") }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: activity.symbol).frame(width: 28).foregroundStyle(FootballTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text(activity.summary).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Text(activity.energyCost < 0 ? "+\(-activity.energyCost)" : "-\(activity.energyCost)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(activity.energyCost < 0 ? .green : .orange)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(block == nil ? 1 : 0.4)
                    .accessibilityIdentifier("activity-\(activity.rawValue)")
                    if activity != CoachActivity.allCases.last { Divider() }
                }
            }
            FootballPersonalPlanPanel(career: $career, onAlert: onAlert)
            licensePanel
            assetsPanel
            investmentsPanel
        }
        .factoryPage()
        .navigationTitle("Vida do treinador")
    }

    private func gauge(_ title: String, _ value: Int, good: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(value)").font(.subheadline.weight(.bold).monospacedDigit())
            }
            ConditionBar(value: good ? value : 100 - value)
        }
    }

    private var licensePanel: some View {
        FactoryPanel(title: "Licenças de treinador", systemImage: "graduationcap.fill") {
            Text("Licença atual: \(coach.licenseName)").font(.subheadline.weight(.semibold))
            if let course = coach.course {
                ProgressView(value: Double(course.sessionsDone), total: Double(course.sessionsNeeded))
                Text("Curso para \(CoachProfile.licenseNames[course.targetLicense - 1]): \(course.sessionsDone)/\(course.sessionsNeeded) aulas. Use a atividade \"Estudar\".")
                    .font(.caption).foregroundStyle(.secondary)
            } else if coach.licenseLevel < 4 {
                let next = coach.licenseLevel + 1
                Text("Próxima: \(CoachProfile.licenseNames[next - 1]) · \(FootballFormat.money(CoachProfile.courseCosts[next - 1])) · reputação \(CoachProfile.courseMinimumReputation[next - 1])+")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    if !career.startCourse() { onAlert(career.canStartCourse() ?? "Não foi possível iniciar o curso.") }
                } label: {
                    Label("Matricular-se", systemImage: "book.closed.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("start-course")
            } else {
                Label("Licença máxima conquistada", systemImage: "checkmark.seal.fill").foregroundStyle(.green).font(.subheadline)
            }
            if coach.booksPublished > 0 {
                Label("\(coach.booksPublished) livro(s) publicado(s): royalties a cada temporada", systemImage: "book.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var assetsPanel: some View {
        FactoryPanel(title: "Bens e conforto", systemImage: "house.fill") {
            ForEach(AssetKind.allCases) { kind in
                let owned = coach.assets.first { $0.kind == kind }
                HStack(spacing: 12) {
                    Image(systemName: kind.symbol).frame(width: 28).foregroundStyle(owned == nil ? Color.secondary : FootballTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title).font(.subheadline.weight(.semibold))
                        Text(kind.summary).font(.caption).foregroundStyle(.secondary)
                        Text("\(FootballFormat.money(kind.price)) · manutenção \(FootballFormat.money(kind.upkeep))/temp.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let owned {
                        Button("Vender") { career.sellAsset(id: owned.id) }.buttonStyle(.bordered).font(.caption.weight(.bold))
                    } else {
                        Button("Comprar") {
                            if !career.buyAsset(kind) { onAlert(career.canBuyAsset(kind) ?? "Compra indisponível.") }
                        }
                        .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                        .accessibilityIdentifier("buy-\(kind.rawValue)")
                    }
                }
                if kind != AssetKind.allCases.last { Divider() }
            }
        }
    }

    private var investmentsPanel: some View {
        FactoryPanel(title: "Investimentos", systemImage: "chart.line.uptrend.xyaxis") {
            Text("Valor aplicado: \(FootballFormat.money(career.investmentsValue))").font(.subheadline.weight(.semibold))
            Stepper("Aporte: \(FootballFormat.money(investAmount))", value: $investAmount, in: 10_000...500_000, step: 10_000)
                .font(.subheadline)
            ForEach(InvestmentKind.allCases) { kind in
                Button {
                    if !career.invest(kind, amount: investAmount) { onAlert("Caixa pessoal insuficiente para este aporte.") }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: kind.symbol).frame(width: 28).foregroundStyle(FootballTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text(kind.summary).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill").foregroundStyle(FootballTheme.accent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            ForEach(coach.investments) { investment in
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(investment.kind.title).font(.subheadline.weight(.semibold))
                        let delta = investment.value - investment.principal
                        Text("\(FootballFormat.money(investment.value)) · \(delta >= 0 ? "+" : "-")\(FootballFormat.money(abs(delta)))")
                            .font(.caption).foregroundStyle(delta >= 0 ? .green : .red)
                    }
                    Spacer()
                    Button("Resgatar") { career.withdrawInvestment(id: investment.id) }.buttonStyle(.bordered).font(.caption.weight(.bold))
                }
            }
        }
    }
}

// MARK: - Acontecimentos

struct FootballEventsView: View {
    @Binding var career: FootballCareer
    /// Abre o acontecimento escolhido num aviso no topo da lista.
    var focusedEventID: Int? = nil
    @State private var resultText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let resultText {
                Label(resultText, systemImage: "checkmark.circle.fill").font(.subheadline.weight(.medium)).foregroundStyle(FootballTheme.accent)
            }
            if career.pendingEvents.isEmpty {
                FactoryPanel(title: "Tudo calmo", systemImage: "leaf.fill") {
                    Text("Nenhum acontecimento esperando decisão. Eles surgem conforme o clube vive bons e maus momentos.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            ForEach(career.pendingEvents.sorted { $0.id == focusedEventID ? $1.id != focusedEventID : ($1.id == focusedEventID ? false : $0.id < $1.id) }) { event in
                FactoryPanel(title: event.title, systemImage: "exclamationmark.bubble.fill") {
                    Text(event.body).font(.subheadline)
                    ForEach(Array(event.choices.enumerated()), id: \.offset) { index, choice in
                        Button {
                            resultText = career.resolveEvent(id: event.id, choice: index)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(choice.label).font(.subheadline.weight(.bold))
                                Text(choice.hint).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("event-\(event.id)-choice-\(index)")
                    }
                    Text("Se você não decidir até o dia \(event.expiresWorldDay), vale a opção padrão.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if !career.world.events.history.isEmpty {
                FactoryPanel(title: "Histórico", systemImage: "clock.arrow.circlepath") {
                    ForEach(career.world.events.history.prefix(10)) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title).font(.subheadline.weight(.semibold))
                            if let text = event.resultText { Text(text).font(.caption).foregroundStyle(.secondary) }
                        }
                        if event.id != career.world.events.history.prefix(10).last?.id { Divider() }
                    }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Acontecimentos")
    }
}

// MARK: - Missões

struct FootballQuestsView: View {
    @Binding var career: FootballCareer
    var onOpenApp: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryMetric(label: "Missões concluídas", value: "\(career.world.quests.completedCount)", symbol: "checkmark.seal.fill", tint: .blue)
            FootballGoalsPlannerPanel(career: $career, onOpenApp: onOpenApp)
            let weekly = career.world.quests.active.filter { !$0.seasonal && !$0.completed && $0.origin != .player }
            let seasonal = career.world.quests.active.filter { $0.seasonal && !$0.completed && $0.origin != .player }
            questPanel("Missões rápidas", "bolt.fill", weekly)
            questPanel("Missões de temporada", "calendar", seasonal)
            FootballGoalsHistoryPanel(career: career)
            Text("As recompensas caem sozinhas, uma única vez, quando a meta é batida.").font(.caption).foregroundStyle(.secondary)
        }
        .factoryPage()
        .navigationTitle("Missões")
    }

    @ViewBuilder
    private func questPanel(_ title: String, _ symbol: String, _ quests: [Quest]) -> some View {
        FactoryPanel(title: title, systemImage: symbol) {
            if quests.isEmpty { Text("Nenhuma missão ativa agora.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(quests) { quest in
                FootballGoalRow(career: career, quest: quest, onOpenApp: onOpenApp)
                if quest.id != quests.last?.id { Divider() }
            }
        }
    }
}

// MARK: - Conquistas

struct FootballAchievementsView: View {
    @Binding var career: FootballCareer

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryMetric(label: "Conquistas", value: "\(career.unlockedAchievementCount)/\(Achievement.allCases.count)", symbol: "medal.fill", tint: FootballTheme.gold)
            let highlights = career.highlightedAchievements
            if !highlights.isEmpty {
                FactoryPanel(title: "Destaques do perfil", systemImage: "star.fill") {
                    ForEach(highlights) { achievement in
                        Label(achievement.title, systemImage: achievement.symbol).font(.subheadline.weight(.semibold))
                    }
                }
            }
            FootballTimelinePanel(career: career)
            FactoryPanel(title: "Galeria", systemImage: "medal.fill") {
                ForEach(Achievement.allCases) { achievement in
                    let unlocked = career.isUnlocked(achievement)
                    NavigationLink {
                        FootballTrophyDetailView(career: $career, achievement: achievement)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: achievement.symbol)
                                .font(.title3)
                                .frame(width: 34, height: 34)
                                .foregroundStyle(unlocked ? FootballTheme.gold : Color.secondary)
                                .background((unlocked ? FootballTheme.gold : Color.secondary).opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title).font(.subheadline.weight(.semibold))
                                Text(achievement.detail).font(.caption).foregroundStyle(.secondary)
                                if !unlocked, let progress = career.achievementProgress(achievement) {
                                    ProgressView(value: Double(progress.current), total: Double(progress.target)).tint(FootballTheme.gold)
                                    Text("\(progress.current) de \(progress.target)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if unlocked { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        }
                        .opacity(unlocked ? 1 : 0.7)
                        .accessibilityElement(children: .combine)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("trophy-\(achievement.rawValue)")
                    if achievement != Achievement.allCases.last { Divider() }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Conquistas")
    }
}
