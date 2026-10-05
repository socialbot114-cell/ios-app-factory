import Foundation

// MARK: - Agenda pessoal do treinador (F4-04 / VID-01)

extension CoachActivity {
    /// Exige presença física na cidade do clube; impossível em dia de jogo fora de casa.
    var isInPerson: Bool {
        switch self {
        case .tvPunditry, .lecture, .schoolVisit, .sponsorShoot: return true
        case .rest, .study, .writeBook, .podcast: return false
        }
    }
}

struct PlannedActivity: Codable, Equatable, Identifiable {
    enum Status: String, Codable { case planned, done, skipped }

    let id: Int
    let worldDay: Int
    let activity: CoachActivity
    var status: Status = .planned
    var note = ""
}

/// Um conflito explicado ao jogador antes de confirmar o plano.
struct PlanConflict: Equatable {
    enum Severity { case blocking, warning }
    let severity: Severity
    let text: String
}

/// Um dia da agenda pessoal, já cruzado com o calendário do clube.
struct PersonalPlanDay: Equatable, Identifiable {
    let worldDay: Int
    let matchDay: Int
    let opponentID: Int?
    let isHome: Bool
    let isDerby: Bool
    /// Prazos do clube que vencem ao avançar este dia.
    let deadlines: [String]
    let planned: PlannedActivity?
    /// Energia estimada no começo do dia, considerando o que já está planejado.
    let energyAtStart: Int

    var id: Int { worldDay }
    var isAway: Bool { opponentID != nil && !isHome }
}

extension FootballCareer {
    static let personalPlanHorizon = 6
    static let personalPlanHistoryLimit = 12

    private var seasonStartWorldDay: Int { (season - 1) * FootballSeason.matchDaysPerSeason }

    private func restGain(onWorldDay day: Int) -> Int { 30 + assetRestBonus(onWorldDay: day) }

    /// Energia no começo de cada dia do horizonte: gasto do plano e +3 de recuperação por dia de jogo.
    func projectedCoachEnergy(through lastDay: Int) -> [Int: Int] {
        var energy = world.coach.energy
        var result: [Int: Int] = [:]
        guard lastDay >= worldDay else { return result }
        for day in worldDay...lastDay {
            result[day] = energy
            let activity: CoachActivity?
            if day == worldDay && world.coach.lastActivityWorldDay == worldDay {
                activity = nil // a atividade de hoje já foi feita e descontada
            } else {
                activity = world.projects.personalPlan.first { $0.worldDay == day && $0.status == .planned }?.activity
            }
            if let activity { energy = activity == .rest ? min(100, energy + restGain(onWorldDay: day)) : energy - activity.energyCost }
            energy = min(100, max(0, energy + 3))
        }
        return result
    }

    /// Próximos dias da temporada com jogo, prazos, plano e energia estimada.
    var personalPlanDays: [PersonalPlanDay] {
        guard let clubID = selectedClubID, !isFired else { return [] }
        let last = min(worldDay + Self.personalPlanHorizon - 1, seasonStartWorldDay + FootballSeason.matchDaysPerSeason - 1)
        guard last >= worldDay else { return [] }
        let energy = projectedCoachEnergy(through: last)
        let items = agenda
        return (worldDay...last).map { day in
            let matchDay = day - seasonStartWorldDay
            let fixture = fixtures.first { $0.matchDay == matchDay && $0.involves(clubID) }
            let opponent = fixture.map { $0.home == clubID ? $0.away : $0.home }
            return PersonalPlanDay(
                worldDay: day, matchDay: matchDay, opponentID: opponent, isHome: fixture?.home == clubID,
                isDerby: fixture.map { FootballSeason.isDerby($0.home, $0.away) } ?? false,
                deadlines: items.filter { $0.expiresOnCalendarAdvance && $0.deadlineWorldDay == day + 1 }.map(\.title),
                planned: world.projects.personalPlan.first { $0.worldDay == day && $0.status == .planned },
                energyAtStart: energy[day] ?? world.coach.energy)
        }
    }

    /// Tudo o que o plano afeta ou impede, para o jogador decidir sabendo o que sacrifica.
    func planConflicts(_ activity: CoachActivity, on day: Int) -> [PlanConflict] {
        guard let planDay = personalPlanDays.first(where: { $0.worldDay == day }) else {
            return [PlanConflict(severity: .blocking, text: "Só dá para planejar os próximos \(Self.personalPlanHorizon) dias de jogo desta temporada.")]
        }
        var conflicts: [PlanConflict] = []
        if day == worldDay && world.coach.lastActivityWorldDay == worldDay {
            conflicts.append(PlanConflict(severity: .blocking, text: "Você já fez uma atividade hoje."))
        }
        if activity.isInPerson && planDay.isAway, let opponent = planDay.opponentID {
            conflicts.append(PlanConflict(severity: .blocking, text: "Dia de viagem: o time joga fora contra o \(FootballSeason.teamName(opponent))."))
        }
        if activity == .study && world.coach.course == nil {
            conflicts.append(PlanConflict(severity: .blocking, text: "Inicie um curso de licença antes de planejar aulas."))
        }
        if activity != .rest {
            // Energia do dia sem contar o que já estava marcado nele, que seria substituído.
            var energy = planDay.energyAtStart
            if day == worldDay { energy = world.coach.energy }
            if energy < max(5, activity.energyCost) {
                conflicts.append(PlanConflict(severity: .blocking, text: "Energia prevista para o dia: \(energy). \(activity.title) exige \(activity.energyCost)."))
            } else {
                let after = energy - activity.energyCost
                let later = world.projects.personalPlan.filter { $0.status == .planned && $0.worldDay > day && $0.activity != .rest }
                if let starved = later.first(where: { after + 3 * ($0.worldDay - day) < $0.activity.energyCost }) {
                    conflicts.append(PlanConflict(severity: .warning, text: "Pode faltar energia para \(starved.activity.title.lowercased()) no dia \(starved.worldDay - seasonStartWorldDay + 1)."))
                }
            }
        }
        if let current = planDay.planned, current.activity != activity {
            conflicts.append(PlanConflict(severity: .warning, text: "Substitui \(current.activity.title.lowercased()) já marcado para este dia."))
        }
        for deadline in planDay.deadlines {
            conflicts.append(PlanConflict(severity: .warning, text: "No mesmo dia vence: \(deadline)."))
        }
        if planDay.isDerby && activity != .rest {
            conflicts.append(PlanConflict(severity: .warning, text: "Dia de clássico: compromisso extra aumenta o estresse (+5)."))
        }
        return conflicts
    }

    /// Marca a atividade no dia; substitui o que estava marcado. Recusa se houver conflito bloqueante.
    @discardableResult
    mutating func planActivity(_ activity: CoachActivity, on day: Int) -> Bool {
        guard !planConflicts(activity, on: day).contains(where: { $0.severity == .blocking }) else { return false }
        world.projects.personalPlan.removeAll { $0.worldDay == day && $0.status == .planned }
        world.projects.personalPlan.append(PlannedActivity(id: world.projects.nextPlanID, worldDay: day, activity: activity))
        world.projects.nextPlanID += 1
        world.projects.personalPlan.sort { $0.worldDay < $1.worldDay }
        return true
    }

    mutating func unplanActivity(on day: Int) {
        world.projects.personalPlan.removeAll { $0.worldDay == day && $0.status == .planned }
    }

    /// Executa o plano do dia que acabou de ser jogado. Chamado depois do avanço do calendário.
    mutating func runPersonalPlan() {
        let day = worldDay - 1
        for index in world.projects.personalPlan.indices where world.projects.personalPlan[index].status == .planned
            && world.projects.personalPlan[index].worldDay <= day {
            let entry = world.projects.personalPlan[index]
            var reason: String?
            if entry.worldDay < day { reason = "o dia passou sem execução" }
            else if world.coach.lastActivityWorldDay == day { reason = "você fez outra atividade no dia" }
            else if entry.activity == .study && world.coach.course == nil { reason = "não havia curso em andamento" }
            else if entry.activity != .rest && world.coach.energy < max(5, entry.activity.energyCost) { reason = "faltou energia" }
            else if entry.activity.isInPerson, isAwayDay(day) { reason = "o time jogou fora de casa" }
            if let reason {
                world.projects.personalPlan[index].status = .skipped
                world.projects.personalPlan[index].note = "Não aconteceu: \(reason)."
                addInbox(.general, title: "Agenda: \(entry.activity.title) cancelado", body: "\(entry.activity.title) não aconteceu porque \(reason).")
                continue
            }
            let result = performActivity(entry.activity, onWorldDay: day)
            if entry.activity != .rest, isDerbyDay(day) { world.coach.stress = min(100, world.coach.stress + 5) }
            world.projects.personalPlan[index].status = .done
            world.projects.personalPlan[index].note = result.text
        }
        let finished = world.projects.personalPlan.filter { $0.status != .planned }
        if finished.count > Self.personalPlanHistoryLimit {
            let keep = Set(finished.suffix(Self.personalPlanHistoryLimit).map(\.id))
            world.projects.personalPlan.removeAll { $0.status != .planned && !keep.contains($0.id) }
        }
    }

    private func userFixture(onWorldDay day: Int) -> LeagueFixture? {
        guard let clubID = selectedClubID else { return nil }
        let matchDay = day - seasonStartWorldDay
        return fixtures.first { $0.matchDay == matchDay && $0.involves(clubID) }
    }

    private func isAwayDay(_ day: Int) -> Bool {
        guard let fixture = userFixture(onWorldDay: day) else { return false }
        return fixture.away == selectedClubID
    }

    private func isDerbyDay(_ day: Int) -> Bool {
        userFixture(onWorldDay: day).map { FootballSeason.isDerby($0.home, $0.away) } ?? false
    }

    /// Na virada de temporada, o plano que sobrou é arquivado como não realizado.
    mutating func closePersonalPlanSeason() {
        for index in world.projects.personalPlan.indices where world.projects.personalPlan[index].status == .planned {
            world.projects.personalPlan[index].status = .skipped
            world.projects.personalPlan[index].note = "Não aconteceu: a temporada terminou."
        }
    }
}
