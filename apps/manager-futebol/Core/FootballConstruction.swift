import Foundation

// MARK: - Obra por etapas (CLB-04) e simulação antes de assumir (BAN-03)

/// Plano de pagamento e andamento da obra em curso.
struct ConstructionPlan: Codable, Equatable {
    let projectID: Int
    let kind: FacilityKind
    let totalCost: Int
    let startWorldDay: Int
    /// Custo de cada etapa: fundação, estrutura e acabamento.
    let stageCosts: [Int]
    /// Dia (relativo ao início) em que cada etapa começa e é paga.
    let stageOffsets: [Int]
    var stagesPaid = 1
    var pausedDays = 0

    static let stageNames = ["Fundação", "Estrutura", "Acabamento"]

    var paid: Int { stageCosts.prefix(stagesPaid).reduce(0, +) }
    var remaining: Int { totalCost - paid }
    var currentStage: String { Self.stageNames[min(stagesPaid, Self.stageNames.count) - 1] }
}

/// Um pagamento hipotético para simular na projeção de caixa.
struct ScenarioPayment: Equatable {
    /// Dia corrido em que o pagamento sai (no tick daquele dia).
    let worldDay: Int
    let amount: Int
    let title: String
}

extension FootballCareer {
    static let stageShares = [0.4, 0.35, 0.25]

    var constructionPlan: ConstructionPlan? {
        guard let plan = world.projects.construction, plan.projectID == upgradeProject?.id else { return nil }
        return plan
    }

    /// Divide o custo em três etapas ao longo da duração da obra.
    func stagePlan(cost: Int, duration: Int) -> (costs: [Int], offsets: [Int]) {
        let first = Int(Double(cost) * Self.stageShares[0] / 10_000) * 10_000
        let second = Int(Double(cost) * Self.stageShares[1] / 10_000) * 10_000
        let costs = [first, second, cost - first - second]
        let offsets = [0, max(1, duration / 3), max(2, duration * 2 / 3)]
        return (costs, offsets)
    }

    /// Custo da primeira etapa, exigido em caixa para começar.
    func firstStageCost(for kind: FacilityKind) -> Int? {
        upgradeCost(for: kind).map { stagePlan(cost: $0, duration: upgradeDuration(for: kind)).costs[0] }
    }

    /// Registra o plano por etapas para a obra que acabou de começar.
    mutating func registerConstruction(kind: FacilityKind, cost: Int, projectID: Int) {
        let plan = stagePlan(cost: cost, duration: upgradeDuration(for: kind))
        world.projects.construction = ConstructionPlan(projectID: projectID, kind: kind, totalCost: cost, startWorldDay: worldDay,
                                                       stageCosts: plan.costs, stageOffsets: plan.offsets)
    }

    /// Paga a etapa que começa hoje. Sem caixa, a obra para e o prazo anda junto.
    /// Devolve true quando a obra está parada neste dia.
    mutating func payDueConstructionStage() -> Bool {
        guard var plan = constructionPlan, let project = upgradeProject, plan.stagesPaid < plan.stageCosts.count else { return false }
        let elapsed = worldDay - plan.startWorldDay - plan.pausedDays
        guard elapsed >= plan.stageOffsets[plan.stagesPaid] else { return false }
        let cost = plan.stageCosts[plan.stagesPaid]
        guard transferBudget >= cost else {
            plan.pausedDays += 1
            world.projects.construction = plan
            // O prazo da obra anda um dia com a paralisação.
            var dueDay = project.dueMatchDay + 1
            var dueSeason = project.dueSeason
            if dueDay >= FootballSeason.matchDaysPerSeason { dueDay -= FootballSeason.matchDaysPerSeason; dueSeason += 1 }
            upgradeProject = UpgradeProject(id: project.id, kind: project.kind, targetLevel: project.targetLevel, cost: project.cost,
                                            dueSeason: dueSeason, dueMatchDay: dueDay)
            if plan.pausedDays == 1 {
                addInbox(.finance, title: "Obra parada", body: "Falta caixa para a etapa de \(ConstructionPlan.stageNames[plan.stagesPaid].lowercased()) (\(FootballFormat.money(cost))). A obra espera e o prazo anda junto.")
            }
            return true
        }
        let note = "Obra: \(project.kind.title) · \(ConstructionPlan.stageNames[plan.stagesPaid].lowercased())"
        book(.facilities, -cost, note)
        linkLastFinanceEntry(note: note, FinanceLink(kind: .construction, id: "\(project.id)", title: "Obra: \(project.kind.title)"))
        plan.stagesPaid += 1
        world.projects.construction = plan
        return false
    }

    // MARK: Impacto durante a execução

    /// Enquanto a obra do estádio acontece, um setor fica fechado: 15% de lugares a menos.
    var effectiveStadiumCapacity: Int {
        upgradeProject?.kind == .stadium ? Int(Double(stadiumCapacity) * 0.85) : stadiumCapacity
    }

    /// Obra no CT atrapalha o treino; obra no departamento médico alonga as lesões.
    var constructionTrainingPenalty: Double { upgradeProject?.kind == .trainingCenter ? 0.04 : 0 }
    var constructionInjuryPenalty: Double { upgradeProject?.kind == .medical ? 0.08 : 0 }

    func constructionImpact(for kind: FacilityKind) -> String {
        switch kind {
        case .stadium: return "Durante a obra, um setor fecha: 15% de lugares a menos nos jogos em casa."
        case .trainingCenter: return "Durante a obra, o treino rende 4% menos."
        case .medical: return "Durante a obra, as lesões duram 8% mais."
        case .youthAcademy: return "Sem impacto no time principal durante a obra."
        }
    }

    // MARK: BAN-03 — simular antes de assumir

    /// Pagamentos que uma obra faria, por etapa, se começasse hoje.
    func upgradeScenario(_ kind: FacilityKind) -> [ScenarioPayment] {
        guard let cost = upgradeCost(for: kind) else { return [] }
        let plan = stagePlan(cost: cost, duration: upgradeDuration(for: kind))
        return zip(plan.costs, plan.offsets).enumerated().map { index, item in
            ScenarioPayment(worldDay: worldDay + item.1, amount: item.0, title: "Obra: \(ConstructionPlan.stageNames[index].lowercased())")
        }
    }

    /// Pagamentos de uma contratação: entrada hoje, parcelas a cada 2 dias e salário por dia de jogo.
    func signingScenario(fee: Int, installments: Int, wagePerSeason: Int) -> [ScenarioPayment] {
        let parts = max(1, installments)
        let upfront = fee / parts
        var payments = [ScenarioPayment(worldDay: worldDay, amount: upfront, title: "Contratação: entrada")]
        if parts > 1 {
            let each = (fee - upfront) / (parts - 1)
            for step in 1..<parts { payments.append(ScenarioPayment(worldDay: worldDay + step * 2, amount: each, title: "Contratação: parcela")) }
        }
        let perDay = wagePerSeason / FootballSeason.matchDaysPerSeason
        for offset in 0..<Self.defaultProjectionHorizon {
            payments.append(ScenarioPayment(worldDay: worldDay + offset + 1, amount: perDay, title: "Contratação: salário"))
        }
        return payments
    }

    /// Projeção com e sem o compromisso, para decidir antes de assumir.
    func simulate(_ scenario: [ScenarioPayment], horizon: Int = defaultProjectionHorizon) -> (before: CashProjection, after: CashProjection) {
        (cashProjection(horizon: horizon), cashProjection(horizon: horizon, scenario: scenario))
    }
}
