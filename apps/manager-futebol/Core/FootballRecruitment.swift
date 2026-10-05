import Foundation

// MARK: - Briefing, lista comparativa e relatórios de observação (TRF-01 / TRF-02 / TRF-03)

/// O que o clube procura: posição, perfil, orçamento e papel esperado.
struct RecruitmentBrief: Codable, Equatable, Identifiable {
    let id: Int
    var position: FootballPosition
    var maxAge: Int
    /// Nível mínimo percebido (pelo teto da faixa que o olheiro enxerga).
    var minOverall: Int
    var maxFee: Int
    var maxWage: Int
    var role: SquadStatus
    /// Lista comparativa salva para este briefing.
    var shortlist: [Int] = []

    var title: String { "\(position.title) · até \(maxAge) anos · \(role.title.lowercased())" }
}

enum ReportReliability: String, Equatable {
    case high, medium, low, none

    var title: String {
        switch self {
        case .high: return "Confiável"
        case .medium: return "Razoável"
        case .low: return "Pouco confiável"
        case .none: return "Sem relatório"
        }
    }
}

/// Relatório do olheiro: quanto se sabe, desde quando e quanto confiar.
struct RecruitmentScoutReport: Equatable {
    let playerID: Int
    let knowledge: Int
    let observedWorldDay: Int?
    let ageInDays: Int?
    let reliability: ReportReliability
    let overallRange: ClosedRange<Int>
}

/// Linha da comparação entre candidatos de um briefing.
struct CandidateComparison: Equatable, Identifiable {
    let playerID: Int
    let name: String
    let age: Int
    let clubID: Int?
    let overallRange: ClosedRange<Int>
    let askingPrice: Int
    let wageAsk: Int
    let expectedRole: SquadStatus
    let report: RecruitmentScoutReport
    /// Quantos critérios do briefing o candidato cumpre (0…5).
    let fit: Int
    let warnings: [String]

    var id: Int { playerID }
}

struct RecruitmentState: Codable, Equatable {
    var briefs: [RecruitmentBrief] = []
    var nextBriefID = 1
    /// Último conhecimento visto e o dia em que subiu, para datar os relatórios.
    var knowledgeSnapshot: [Int: Int] = [:]
    var reportDates: [Int: Int] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey { case briefs, nextBriefID, knowledgeSnapshot, reportDates }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        briefs = try container.decodeIfPresent([RecruitmentBrief].self, forKey: .briefs) ?? []
        nextBriefID = try container.decodeIfPresent(Int.self, forKey: .nextBriefID) ?? 1
        knowledgeSnapshot = try container.decodeIfPresent([Int: Int].self, forKey: .knowledgeSnapshot) ?? [:]
        reportDates = try container.decodeIfPresent([Int: Int].self, forKey: .reportDates) ?? [:]
    }
}

extension FootballCareer {
    static let maxBriefs = 3
    static let shortlistLimit = 6

    var recruitmentBriefs: [RecruitmentBrief] { world.projects.recruitment.briefs }

    @discardableResult
    mutating func createBrief(position: FootballPosition, maxAge: Int, minOverall: Int, maxFee: Int, maxWage: Int, role: SquadStatus) -> RecruitmentBrief? {
        guard selectedClubID != nil, world.projects.recruitment.briefs.count < Self.maxBriefs else { return nil }
        let brief = RecruitmentBrief(id: world.projects.recruitment.nextBriefID, position: position, maxAge: maxAge, minOverall: minOverall,
                                     maxFee: maxFee, maxWage: maxWage, role: role)
        world.projects.recruitment.nextBriefID += 1
        world.projects.recruitment.briefs.append(brief)
        return brief
    }

    mutating func deleteBrief(_ id: Int) {
        world.projects.recruitment.briefs.removeAll { $0.id == id }
    }

    /// Fixa ou tira um candidato da lista comparativa do briefing.
    @discardableResult
    mutating func toggleShortlist(briefID: Int, playerID: Int) -> Bool {
        guard let index = world.projects.recruitment.briefs.firstIndex(where: { $0.id == briefID }) else { return false }
        if let position = world.projects.recruitment.briefs[index].shortlist.firstIndex(of: playerID) {
            world.projects.recruitment.briefs[index].shortlist.remove(at: position)
            return true
        }
        guard world.projects.recruitment.briefs[index].shortlist.count < Self.shortlistLimit else { return false }
        world.projects.recruitment.briefs[index].shortlist.append(playerID)
        return true
    }

    // MARK: Relatórios

    /// Data cada aumento de conhecimento. Chamado uma vez por dia de jogo.
    mutating func stampScoutReports() {
        for (id, known) in scoutKnowledge where known > (world.projects.recruitment.knowledgeSnapshot[id] ?? 0) {
            world.projects.recruitment.knowledgeSnapshot[id] = known
            world.projects.recruitment.reportDates[id] = worldDay
        }
        // Retenção: só atletas ainda conhecidos.
        world.projects.recruitment.knowledgeSnapshot = world.projects.recruitment.knowledgeSnapshot.filter { scoutKnowledge[$0.key] != nil }
        world.projects.recruitment.reportDates = world.projects.recruitment.reportDates.filter { scoutKnowledge[$0.key] != nil }
    }

    /// Conhecimento, data e confiabilidade. Relatórios envelhecem: depois de 10 dias, valem um degrau a menos.
    func recruitmentReport(for playerID: Int) -> RecruitmentScoutReport {
        let known = scoutKnowledge(of: playerID)
        let date = world.projects.recruitment.reportDates[playerID]
        let age = date.map { max(0, worldDay - $0) }
        var reliability: ReportReliability
        if scoutKnowledge[playerID] == nil && player(playerID)?.teamID != nil && player(playerID)?.teamID != selectedClubID {
            reliability = .none
        } else if known >= 80 {
            reliability = .high
        } else if known >= 50 {
            reliability = .medium
        } else {
            reliability = .low
        }
        if let age, age > 10 {
            reliability = reliability == .high ? .medium : (reliability == .medium ? .low : reliability)
        }
        return RecruitmentScoutReport(playerID: playerID, knowledge: known, observedWorldDay: date, ageInDays: age, reliability: reliability,
                           overallRange: visibleOverallRange(of: playerID))
    }

    // MARK: Candidatos e comparação

    func comparison(for athlete: FootballPlayer, brief: RecruitmentBrief) -> CandidateComparison {
        let report = recruitmentReport(for: athlete.id)
        let price = askingPrice(for: athlete)
        let ask = joiningAsk(for: athlete)
        var fit = 0
        var warnings: [String] = []
        if athlete.position == brief.position { fit += 1 }
        if athlete.age <= brief.maxAge { fit += 1 } else { warnings.append("Acima da idade do briefing") }
        if report.overallRange.upperBound >= brief.minOverall { fit += 1 } else { warnings.append("Nível percebido abaixo do pedido") }
        if price <= brief.maxFee { fit += 1 } else { warnings.append("Taxa acima do orçamento") }
        if ask.wage <= brief.maxWage { fit += 1 } else { warnings.append("Salário acima do teto") }
        if ask.status < brief.role { warnings.append("Chega como \(ask.status.title.lowercased()), não como \(brief.role.title.lowercased())") }
        if report.reliability == .low || report.reliability == .none { warnings.append("Relatório \(report.reliability.title.lowercased())") }
        return CandidateComparison(playerID: athlete.id, name: athlete.name, age: athlete.age, clubID: athlete.teamID,
                                   overallRange: report.overallRange, askingPrice: price, wageAsk: ask.wage,
                                   expectedRole: ask.status, report: report, fit: fit, warnings: warnings)
    }

    /// Candidatos que cumprem posição e idade, ordenados por aderência e nível percebido.
    func candidates(for brief: RecruitmentBrief, limit: Int = 8) -> [CandidateComparison] {
        players.filter { $0.position == brief.position && $0.age <= brief.maxAge && !$0.isYouth && $0.teamID != selectedClubID && !$0.onLoan }
            .map { comparison(for: $0, brief: brief) }
            .filter { $0.fit >= 4 }
            .sorted {
                if $0.fit != $1.fit { return $0.fit > $1.fit }
                if $0.overallRange.upperBound != $1.overallRange.upperBound { return $0.overallRange.upperBound > $1.overallRange.upperBound }
                return $0.playerID < $1.playerID
            }
            .prefix(limit).map { $0 }
    }

    func shortlistComparison(for brief: RecruitmentBrief) -> [CandidateComparison] {
        brief.shortlist.compactMap { player($0) }.map { comparison(for: $0, brief: brief) }
    }
}
