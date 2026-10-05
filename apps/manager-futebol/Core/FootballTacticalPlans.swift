import Foundation

// MARK: - Planos táticos A/B (TAC-01)

enum PlanSlot: String, Codable, CaseIterable, Identifiable, Equatable {
    case a, b

    var id: String { rawValue }
    var title: String { self == .a ? "Plano A" : "Plano B" }
}

/// Formação, estilo, instruções, funções e escalação salvos para trocar de plano com um toque.
struct TacticalPlan: Codable, Equatable, Identifiable {
    var id: String { slot.rawValue }
    let slot: PlanSlot
    var formation: FootballFormation
    var style: FootballPlayStyle
    var instructions: TeamInstructions
    var roles: [Int: PlayerRole]
    var lineup: [Int]
    var penaltyTakerID: Int?
    var savedWorldDay: Int
}

struct TacticalPlanReport: Equatable {
    var applied: Bool
    var message: String
    /// Titulares do plano que não podem jogar agora e foram trocados.
    var replaced: [Int]
}

extension FootballCareer {
    func tacticalPlan(_ slot: PlanSlot) -> TacticalPlan? { tacticalPlans.first { $0.slot == slot } }

    /// Guarda o que está em uso agora no plano escolhido.
    @discardableResult
    mutating func saveTacticalPlan(_ slot: PlanSlot) -> TacticalPlan? {
        guard selectedClubID != nil, liveMatch == nil else { return nil }
        let plan = TacticalPlan(slot: slot, formation: formation, style: playStyle, instructions: teamInstructions,
                                roles: playerRoles.filter { startingXI.contains($0.key) }, lineup: startingXI,
                                penaltyTakerID: penaltyTakerID, savedWorldDay: worldDay)
        tacticalPlans.removeAll { $0.slot == slot }
        tacticalPlans.append(plan)
        tacticalPlans.sort { $0.slot.rawValue < $1.slot.rawValue }
        return plan
    }

    /// Titulares de um plano que hoje não jogam (lesão, suspensão, convocação ou saída do clube).
    func unavailableStarters(in plan: TacticalPlan) -> [Int] {
        plan.lineup.filter { id in
            guard let athlete = player(id), athlete.teamID == selectedClubID else { return true }
            return !athlete.isAvailable(matchDay: matchDayIndex)
        }
    }

    /// Antes do jogo: troca tudo. Quem não pode jogar é substituído pelos melhores disponíveis da mesma posição.
    @discardableResult
    mutating func applyTacticalPlan(_ slot: PlanSlot) -> TacticalPlanReport {
        guard liveMatch == nil else { return TacticalPlanReport(applied: false, message: "Durante a partida use a troca rápida de plano.", replaced: []) }
        guard let plan = tacticalPlan(slot) else { return TacticalPlanReport(applied: false, message: "\(slot.title) ainda não foi salvo.", replaced: []) }
        guard FootballSeason.canFill(roster: clubRoster, formation: plan.formation) else {
            return TacticalPlanReport(applied: false, message: "O elenco de hoje não preenche o \(plan.formation.rawValue) do \(slot.title).", replaced: [])
        }
        let replaced = unavailableStarters(in: plan)
        formation = plan.formation
        playStyle = plan.style
        teamInstructions = plan.instructions
        startingXI = rebuiltLineup(keeping: plan.lineup, formation: plan.formation)
        playerRoles = plan.roles.filter { startingXI.contains($0.key) }
        penaltyTakerID = plan.penaltyTakerID.flatMap { startingXI.contains($0) ? $0 : nil } ?? penaltyTakerID
        let note = replaced.isEmpty ? "" : " \(replaced.count) titular(es) do plano não podem jogar e foram substituídos."
        return TacticalPlanReport(applied: true, message: "\(slot.title) aplicado: \(plan.formation.rawValue), \(plan.style.rawValue).\(note)", replaced: replaced)
    }

    /// Durante o jogo só dá para mudar a parte tática; a escalação muda com substituições.
    @discardableResult
    mutating func liveApplyTacticalPlan(_ slot: PlanSlot) -> TacticalPlanReport {
        guard let live = liveMatch, !live.sim.finished else { return TacticalPlanReport(applied: false, message: "Não há partida em andamento.", replaced: []) }
        guard let plan = tacticalPlan(slot) else { return TacticalPlanReport(applied: false, message: "\(slot.title) ainda não foi salvo.", replaced: []) }
        liveSetFormation(plan.formation)
        liveSetStyle(plan.style)
        liveSetInstructions(plan.instructions)
        let onPitch = Set(liveMatch?.userSide.onPitch ?? [])
        for (id, role) in plan.roles where onPitch.contains(id) { liveSetRole(playerID: id, role: role) }
        return TacticalPlanReport(applied: true, message: "\(slot.title) em campo: \(plan.formation.rawValue), \(plan.style.rawValue). A escalação só muda com substituições.", replaced: [])
    }

    /// Compara os dois planos com o que dá para verificar: formação, estilo, instruções e disponibilidade.
    func compareTacticalPlans() -> [String] {
        guard let a = tacticalPlan(.a), let b = tacticalPlan(.b) else { return ["Salve os dois planos para compará-los."] }
        var lines: [String] = []
        if a.formation != b.formation { lines.append("Formação: \(a.formation.rawValue) × \(b.formation.rawValue).") }
        if a.style != b.style { lines.append("Estilo: \(a.style.rawValue) × \(b.style.rawValue).") }
        if a.instructions != b.instructions {
            let ma = a.instructions.modifiers, mb = b.instructions.modifiers
            lines.append("Instruções: ataque \(Self.signed(ma.attack)) × \(Self.signed(mb.attack)), defesa \(Self.signed(ma.defense)) × \(Self.signed(mb.defense)), controle \(Self.signed(ma.control)) × \(Self.signed(mb.control)); desgaste ×\(String(format: "%.2f", a.instructions.fatigueFactor).replacingOccurrences(of: ".", with: ",")) contra ×\(String(format: "%.2f", b.instructions.fatigueFactor).replacingOccurrences(of: ".", with: ",")).")
        }
        let shared = Set(a.lineup).intersection(b.lineup).count
        lines.append("Titulares em comum: \(shared) de 11.")
        for plan in [a, b] {
            let missing = unavailableStarters(in: plan)
            if !missing.isEmpty { lines.append("\(plan.slot.title): \(missing.count) titular(es) indisponíveis hoje.") }
        }
        return lines
    }

    private static func signed(_ value: Double) -> String {
        let text = String(format: "%.1f", abs(value)).replacingOccurrences(of: ".", with: ",")
        return value >= 0 ? "+\(text)" : "−\(text)"
    }
}
