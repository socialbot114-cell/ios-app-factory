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
            FootballLifeContinuityPanel(career: $career, onAlert: onAlert)
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
