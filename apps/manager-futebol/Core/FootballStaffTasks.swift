import Foundation

// MARK: - Tarefas e relatórios da comissão técnica, com delegação inicial (CLB-05)

enum StaffTaskKind: String, Codable, CaseIterable, Identifiable {
    case studyRival, recoveryPlan, focusedScouting, medicalReview, performanceReport, youthAssessment

    var id: String { rawValue }

    var role: StaffRole {
        switch self {
        case .studyRival: return .assistant
        case .recoveryPlan: return .fitnessCoach
        case .focusedScouting: return .headScout
        case .medicalReview: return .doctor
        case .performanceReport: return .analyst
        case .youthAssessment: return .youthCoach
        }
    }

    var title: String {
        switch self {
        case .studyRival: return "Estudar o próximo rival"
        case .recoveryPlan: return "Plano de recuperação"
        case .focusedScouting: return "Observação dirigida da lista"
        case .medicalReview: return "Revisão médica do elenco"
        case .performanceReport: return "Relatório de desempenho"
        case .youthAssessment: return "Avaliar as promessas da base"
        }
    }

    var effect: String {
        switch self {
        case .studyRival: return "Erro na leitura do estilo do próximo rival cai pela metade."
        case .recoveryPlan: return "Titulares abaixo de 75 recuperam +3 por dia e o risco de lesão cai 10%."
        case .focusedScouting: return "+15 de conhecimento por dia nos atletas da lista de observação."
        case .medicalReview: return "Lesões em andamento ficam 1 rodada mais curtas no fim."
        case .performanceReport: return "Relatório com quem rende acima e abaixo e o que fazer."
        case .youthAssessment: return "Relatório das promessas com o potencial mais alto."
        }
    }

    var days: Int {
        switch self {
        case .studyRival, .medicalReview, .performanceReport: return 2
        case .recoveryPlan, .focusedScouting, .youthAssessment: return 3
        }
    }
}

struct StaffTask: Codable, Equatable, Identifiable {
    enum Status: String, Codable { case running, done, cancelled }

    let id: Int
    let kind: StaffTaskKind
    let staffName: String
    let startWorldDay: Int
    var status: Status = .running
    var delegated = false
    /// Partida a que o estudo do rival se refere.
    var fixtureID: Int? = nil
    var report = ""

    var endWorldDay: Int { startWorldDay + kind.days }
}

struct StaffTasksState: Codable, Equatable {
    var tasks: [StaffTask] = []
    var nextID = 1
    var autoDelegate = false
    /// Partidas cujo rival foi estudado pelo auxiliar.
    var studiedFixtureIDs: [Int] = []

    init() {}

    private enum CodingKeys: String, CodingKey { case tasks, nextID, autoDelegate, studiedFixtureIDs }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeIfPresent([StaffTask].self, forKey: .tasks) ?? []
        nextID = try container.decodeIfPresent(Int.self, forKey: .nextID) ?? 1
        autoDelegate = try container.decodeIfPresent(Bool.self, forKey: .autoDelegate) ?? false
        studiedFixtureIDs = try container.decodeIfPresent([Int].self, forKey: .studiedFixtureIDs) ?? []
    }
}

extension FootballCareer {
    static let maxStaffTasks = 2
    static let staffTaskHistoryLimit = 12

    var staffTasks: StaffTasksState { world.projects.staffTasks }
    var runningStaffTasks: [StaffTask] { staffTasks.tasks.filter { $0.status == .running } }

    func staffTaskBlocker(_ kind: StaffTaskKind) -> String? {
        guard selectedClubID != nil, !isFired else { return "Sem clube." }
        guard staffMember(kind.role) != nil else { return "Contrate um \(kind.role.title.lowercased()) para esta tarefa." }
        if runningStaffTasks.contains(where: { $0.kind.role == kind.role }) { return "O \(kind.role.title.lowercased()) já está ocupado." }
        if runningStaffTasks.count >= Self.maxStaffTasks { return "A comissão já tem \(Self.maxStaffTasks) tarefas em andamento." }
        if kind == .studyRival && nextUserFixture == nil && upcomingUserFixtures.isEmpty { return "Não há próximo jogo para estudar." }
        return nil
    }

    @discardableResult
    mutating func assignStaffTask(_ kind: StaffTaskKind, delegated: Bool = false) -> Bool {
        guard staffTaskBlocker(kind) == nil, let member = staffMember(kind.role) else { return false }
        var task = StaffTask(id: staffTasks.nextID, kind: kind, staffName: member.name, startWorldDay: worldDay, delegated: delegated)
        if kind == .studyRival { task.fixtureID = (nextUserFixture ?? upcomingUserFixtures.first)?.id }
        world.projects.staffTasks.nextID += 1
        world.projects.staffTasks.tasks.append(task)
        return true
    }

    mutating func setStaffAutoDelegate(_ on: Bool) { world.projects.staffTasks.autoDelegate = on }

    // MARK: Efeitos

    /// Plano de recuperação em curso reduz o risco de lesão.
    var staffInjuryFactor: Double { runningStaffTasks.contains { $0.kind == .recoveryPlan } ? 0.9 : 1 }

    /// O auxiliar estudou o rival desta partida.
    func rivalStudied(_ fixture: LeagueFixture) -> Bool { staffTasks.studiedFixtureIDs.contains(fixture.id) }

    /// Andamento diário e relatórios no fim. Uma vez por dia de jogo.
    mutating func progressStaffTasks() {
        if staffTasks.autoDelegate { delegateStaffRoutines() }
        for index in staffTasks.tasks.indices where staffTasks.tasks[index].status == .running {
            let task = staffTasks.tasks[index]
            guard staffMember(task.kind.role) != nil else {
                world.projects.staffTasks.tasks[index].status = .cancelled
                world.projects.staffTasks.tasks[index].report = "Cancelada: o profissional saiu do clube."
                continue
            }
            switch task.kind {
            case .recoveryPlan:
                for playerIndex in players.indices where startingXI.contains(players[playerIndex].id) && players[playerIndex].condition < 75 {
                    players[playerIndex].condition = min(100, players[playerIndex].condition + 3)
                }
            case .focusedScouting:
                for id in watchlist { observe(id, gain: 15) }
            default:
                break
            }
            guard worldDay >= task.endWorldDay else { continue }
            let report = staffReport(for: task)
            world.projects.staffTasks.tasks[index].status = .done
            world.projects.staffTasks.tasks[index].report = report
            addInbox(.staff, title: "Relatório: \(task.kind.title)", body: "\(task.staffName): \(report)")
        }
        let finished = staffTasks.tasks.filter { $0.status != .running }
        if finished.count > Self.staffTaskHistoryLimit {
            let keep = Set(finished.suffix(Self.staffTaskHistoryLimit).map(\.id))
            world.projects.staffTasks.tasks.removeAll { $0.status != .running && !keep.contains($0.id) }
        }
    }

    private mutating func staffReport(for task: StaffTask) -> String {
        switch task.kind {
        case .studyRival:
            guard let fixtureID = task.fixtureID, let fixture = fixtures.first(where: { $0.id == fixtureID }) else { return "O jogo estudado já passou." }
            if !world.projects.staffTasks.studiedFixtureIDs.contains(fixtureID) { world.projects.staffTasks.studiedFixtureIDs.append(fixtureID) }
            if staffTasks.studiedFixtureIDs.count > 10 { world.projects.staffTasks.studiedFixtureIDs.removeFirst() }
            let rival = FootballSeason.teamName(fixture.home == selectedClubID ? fixture.away : fixture.home)
            let threats = matchupReport()?.threats.map(\.title).joined(separator: "; ") ?? "sem ameaças claras"
            return "Estudo do \(rival) pronto. Ameaças: \(threats). A leitura do estilo dele fica mais confiável."
        case .recoveryPlan:
            let tired = starters.filter { $0.condition < 75 }.count
            return "Plano encerrado. \(tired) titular(es) ainda abaixo de 75 de condição."
        case .focusedScouting:
            let known = watchlist.filter { scoutKnowledge(of: $0) >= 80 }.count
            return "Observação concluída: \(known) de \(watchlist.count) atleta(s) da lista com relatório confiável."
        case .medicalReview:
            var treated = 0
            for index in players.indices where players[index].teamID == selectedClubID && players[index].injuryRounds > 1 {
                players[index].injuryRounds -= 1
                treated += 1
            }
            return treated > 0 ? "Revisão concluída: \(treated) lesão(ões) encurtada(s) em 1 rodada." : "Revisão concluída: elenco sem lesões a tratar."
        case .performanceReport:
            let squad = clubRoster.filter { !$0.isYouth }
            let low = squad.filter { $0.morale < 45 }.map(\.name).prefix(3)
            let tired = squad.filter { $0.condition < 65 }.map(\.name).prefix(3)
            var parts: [String] = []
            if !low.isEmpty { parts.append("moral baixa: \(low.joined(separator: ", "))") }
            if !tired.isEmpty { parts.append("desgaste: \(tired.joined(separator: ", "))") }
            return parts.isEmpty ? "Elenco em bom momento físico e emocional." : "Atenção — " + parts.joined(separator: "; ") + "."
        case .youthAssessment:
            let youth = clubRoster.filter(\.isYouth).sorted { $0.potential > $1.potential }.prefix(3)
            return youth.isEmpty ? "A base não tem promessas no momento." : "Destaques: " + youth.map { "\($0.name) (potencial \($0.potential))" }.joined(separator: ", ") + "."
        }
    }

    /// Delegação inicial: a comissão escolhe sozinha a tarefa mais necessária, sem passar do limite.
    mutating func delegateStaffRoutines() {
        var needs: [StaffTaskKind] = []
        if starters.filter({ $0.condition < 70 }).count >= 3 { needs.append(.recoveryPlan) }
        if clubRoster.contains(where: { $0.injuryRounds > 1 }) { needs.append(.medicalReview) }
        if let fixture = nextUserFixture ?? upcomingUserFixtures.first, !rivalStudied(fixture),
           !runningStaffTasks.contains(where: { $0.fixtureID == fixture.id }) { needs.append(.studyRival) }
        if !watchlist.isEmpty, watchlist.contains(where: { scoutKnowledge(of: $0) < 80 }) { needs.append(.focusedScouting) }
        for kind in needs where runningStaffTasks.count < Self.maxStaffTasks && staffTaskBlocker(kind) == nil {
            assignStaffTask(kind, delegated: true)
        }
    }
}
