import Foundation

// MARK: - Contas separadas com extratos (BAN-01) e origem de cada lançamento (BAN-06)

/// De onde veio um lançamento: abre o fato, contrato ou projeto que o explica.
struct FinanceLink: Codable, Equatable {
    enum Kind: String, Codable { case fact, loan, collection, campaign, construction, meeting, delegation, contract, media }

    let kind: Kind
    let id: String
    let title: String
}

struct PersonalEntry: Codable, Equatable, Identifiable {
    let id: Int
    let worldDay: Int
    let amount: Int
    let note: String
    var link: FinanceLink? = nil
}

struct PersonalLedgerState: Codable, Equatable {
    var entries: [PersonalEntry] = []
    var nextID = 1
    /// Saldo do bolso quando o extrato começou (saves antigos começam no primeiro lançamento).
    var openingBalance: Int? = nil
    /// Soma de tudo o que saiu do extrato por retenção, para o saldo continuar batendo.
    var archivedTotal = 0

    init() {}

    private enum CodingKeys: String, CodingKey { case entries, nextID, openingBalance, archivedTotal }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entries = try container.decodeIfPresent([PersonalEntry].self, forKey: .entries) ?? []
        nextID = try container.decodeIfPresent(Int.self, forKey: .nextID) ?? 1
        openingBalance = try container.decodeIfPresent(Int.self, forKey: .openingBalance)
        archivedTotal = try container.decodeIfPresent(Int.self, forKey: .archivedTotal) ?? 0
    }
}

/// Explicação de um lançamento a partir do vínculo.
struct FinanceOrigin: Equatable {
    let title: String
    let detail: String
}

extension FootballCareer {
    static let personalEntryLimit = 200

    var personalLedger: PersonalLedgerState { world.projects.personalLedger }

    /// Saldo que o extrato explica: abertura + arquivados + lançamentos.
    var personalLedgerBalance: Int {
        (personalLedger.openingBalance ?? world.coach.personalCash) + personalLedger.archivedTotal + personalLedger.entries.reduce(0) { $0 + $1.amount }
    }

    private mutating func ensurePersonalLedger() {
        if world.projects.personalLedger.openingBalance == nil { world.projects.personalLedger.openingBalance = world.coach.personalCash }
    }

    /// Movimenta o bolso do treinador e registra no extrato pessoal.
    mutating func bookPersonal(_ amount: Int, _ note: String, link: FinanceLink? = nil) {
        guard amount != 0 else { return }
        ensurePersonalLedger()
        world.coach.personalCash += amount
        appendPersonal(amount, note, link: link)
    }

    private mutating func appendPersonal(_ amount: Int, _ note: String, link: FinanceLink?) {
        world.projects.personalLedger.entries.append(PersonalEntry(id: personalLedger.nextID, worldDay: worldDay, amount: amount, note: note, link: link))
        world.projects.personalLedger.nextID += 1
        if personalLedger.entries.count > Self.personalEntryLimit {
            let overflow = personalLedger.entries.count - Self.personalEntryLimit
            world.projects.personalLedger.archivedTotal += personalLedger.entries.prefix(overflow).reduce(0) { $0 + $1.amount }
            world.projects.personalLedger.entries.removeFirst(overflow)
        }
    }

    /// O que mexeu no bolso fora do extrato (eventos, redes, missões) vira um lançamento explícito: saldo e extrato sempre batem.
    mutating func reconcilePersonalLedger() {
        ensurePersonalLedger()
        let difference = world.coach.personalCash - personalLedgerBalance
        if difference != 0 { appendPersonal(difference, "Outras movimentações (eventos, redes, missões)", link: nil) }
    }

    /// Liga o último lançamento do clube com esta nota à sua origem.
    mutating func linkLastFinanceEntry(note: String, _ link: FinanceLink) {
        guard let index = finance.entries.lastIndex(where: { $0.note == note }) else { return }
        finance.entries[index].link = link
    }

    /// Liga todos os lançamentos recentes cujo texto começa com o prefixo (ex.: entrada e parcelas de uma contratação).
    mutating func linkRecentFinanceEntries(prefix: String, _ link: FinanceLink) {
        for index in finance.entries.indices.reversed().prefix(12) where finance.entries[index].note.hasPrefix(prefix) && finance.entries[index].link == nil {
            finance.entries[index].link = link
        }
    }

    /// O que está por trás de um lançamento, a partir do vínculo (BAN-06).
    func financeOrigin(_ link: FinanceLink) -> FinanceOrigin {
        switch link.kind {
        case .fact:
            if let fact = fact(link.id) {
                var detail = fact.detail
                if let effects = fact.effects, !effects.isEmpty { detail += " Efeitos: " + effects.joined(separator: "; ") + "." }
                return FinanceOrigin(title: fact.title, detail: detail)
            }
        case .loan:
            if let loan = coachLoans.first(where: { "\($0.id)" == link.id }) {
                return FinanceOrigin(title: "Aporte de \(FootballFormat.money(loan.principal))",
                                     detail: "Devolvido \(FootballFormat.money(loan.repaid)), falta \(FootballFormat.money(loan.outstanding)). Parcela de \(FootballFormat.money(loan.installment)).")
            }
        case .collection:
            if let project = world.commercial.collections.first(where: { "\($0.id)" == link.id }) {
                return FinanceOrigin(title: project.name,
                                     detail: "Investimento \(FootballFormat.money(project.cost)); previsto \(FootballFormat.money(project.forecast)), vendido \(FootballFormat.money(project.realized)).")
            }
        case .campaign:
            if let record = brandState.campaigns.first(where: { "\($0.id)" == link.id }) {
                return FinanceOrigin(title: "Campanha \(record.brief.channel.title)",
                                     detail: "Objetivo \(record.brief.objective.title.lowercased()) para \(record.brief.audience.title.lowercased()); previsto \(Self.formatObjective(record.forecast, record.brief.objective)).")
            }
        case .construction:
            if let plan = world.projects.construction, "\(plan.projectID)" == link.id {
                return FinanceOrigin(title: "Obra: \(plan.kind.title)",
                                     detail: "Etapa atual: \(plan.currentStage.lowercased()). Pago \(FootballFormat.money(plan.paid)) de \(FootballFormat.money(plan.totalCost)).")
            }
            return FinanceOrigin(title: link.title, detail: "Obra concluída.")
        case .meeting:
            if let meeting = boardMeetings.first(where: { "\($0.id)" == link.id }) {
                return FinanceOrigin(title: "Reunião com a diretoria", detail: [meeting.answer, meeting.resolution].filter { !$0.isEmpty }.joined(separator: " "))
            }
        case .delegation:
            if let delegation = commercialDelegation {
                return FinanceOrigin(title: "Gerente comercial", detail: "Perfil \(delegation.risk.title.lowercased()); teto usado \(FootballFormat.money(delegation.spentThisSeason)).")
            }
        case .contract:
            if let contract = brandState.contracts.first(where: { "\($0.id)" == link.id }) {
                return FinanceOrigin(title: "Contrato de imagem com \(contract.brand)",
                                     detail: contract.failures.isEmpty ? "Comerciais \(contract.shootsDone)/\(contract.shootsRequired)." : contract.failures.joined(separator: "; "))
            }
        case .media:
            if let contract = life.mediaContract {
                return FinanceOrigin(title: "Contrato de comentarista", detail: "\(contract.done.count) programa(s) feitos, \(contract.missed.count) falta(s).")
            }
        }
        return FinanceOrigin(title: link.title, detail: "Registro original não está mais no histórico.")
    }
}
