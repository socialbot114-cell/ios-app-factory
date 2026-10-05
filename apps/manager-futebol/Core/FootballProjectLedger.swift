import Foundation

// MARK: - Retorno previsto × realizado de cada projeto (NEG-06)

enum ProjectLedgerKind: String, Codable {
    case naming, shopUpgrade, program
}

/// O que o projeto entrega: dinheiro, torcedores, talentos ou reputação.
enum ProjectLedgerUnit: String, Codable {
    case money, fans, talents, reputation

    func format(_ value: Double) -> String {
        switch self {
        case .money: return FootballFormat.money(Int(value.rounded()))
        case .fans: return "\(Int(value.rounded())) torcedores"
        case .talents: return String(format: "%.1f talento(s)", value)
        case .reputation: return String(format: "%.1f pt de reputação", value)
        }
    }
}

struct ProjectLedgerEntry: Codable, Equatable, Identifiable {
    let id: Int
    let clubID: Int
    let kind: ProjectLedgerKind
    /// Chave estável do projeto (ex.: o programa social), para fechar a entrada certa.
    let key: String
    let title: String
    let unit: ProjectLedgerUnit
    /// Dinheiro posto no início (obra); recorrentes aparecem no Banco.
    let invested: Int
    let forecastPerDay: Double
    let startWorldDay: Int
    /// Dias cobertos pela previsão; nil = enquanto o projeto existir.
    let horizonDays: Int?
    var realized = 0.0
    var daysElapsed = 0
    var closed = false

    var forecastToDate: Double { forecastPerDay * Double(daysElapsed) }
    var forecastTotal: Double? { horizonDays.map { forecastPerDay * Double($0) } }
    /// Realizado sobre previsto no mesmo período.
    var ratio: Double? { forecastToDate > 0 ? realized / forecastToDate : nil }
    var isRunning: Bool { !closed }
}

extension FootballCareer {
    static let ledgerHistoryLimit = 16

    var projectLedger: [ProjectLedgerEntry] { world.commercial.ledger.filter { $0.clubID == selectedClubID } }

    mutating func openLedger(_ kind: ProjectLedgerKind, key: String, title: String, unit: ProjectLedgerUnit,
                             invested: Int = 0, forecastPerDay: Double, horizonDays: Int? = nil) {
        guard let clubID = selectedClubID else { return }
        closeLedger(key: key)
        world.commercial.ledger.append(ProjectLedgerEntry(id: world.commercial.ledgerNextID, clubID: clubID, kind: kind, key: key, title: title,
                                                          unit: unit, invested: invested, forecastPerDay: forecastPerDay,
                                                          startWorldDay: worldDay, horizonDays: horizonDays))
        world.commercial.ledgerNextID += 1
        let closed = world.commercial.ledger.filter(\.closed)
        if closed.count > Self.ledgerHistoryLimit {
            let keep = Set(closed.suffix(Self.ledgerHistoryLimit).map(\.id))
            world.commercial.ledger.removeAll { $0.closed && !keep.contains($0.id) }
        }
    }

    mutating func closeLedger(key: String) {
        for index in world.commercial.ledger.indices where world.commercial.ledger[index].key == key && !world.commercial.ledger[index].closed {
            world.commercial.ledger[index].closed = true
        }
    }

    /// Soma o realizado do dia; chamado onde o efeito acontece.
    mutating func recordLedger(key: String, _ value: Double) {
        guard let index = world.commercial.ledger.lastIndex(where: { $0.key == key && !$0.closed }) else { return }
        world.commercial.ledger[index].realized += value
    }

    /// Conta um dia de previsão para todos os projetos abertos e fecha os que cumpriram o horizonte.
    mutating func advanceLedgerDay() {
        for index in world.commercial.ledger.indices where !world.commercial.ledger[index].closed
            && world.commercial.ledger[index].clubID == selectedClubID {
            world.commercial.ledger[index].daysElapsed += 1
            if let horizon = world.commercial.ledger[index].horizonDays, world.commercial.ledger[index].daysElapsed >= horizon {
                world.commercial.ledger[index].closed = true
            }
        }
    }

    // MARK: Ganho atribuível à ampliação da loja

    /// Parte das vendas-base de hoje que se deve à ampliação de `previous` para `level`.
    /// Cada ampliação conta só a própria fatia, mesmo depois de outras ampliações.
    func shopUpliftToday(fromLevel previous: Int, toLevel level: Int) -> Int {
        let factors = [0.0, 1.0, 1.4, 1.9, 2.5]
        let current = factors[min(max(world.business.shopLevel, 1), 4)]
        let slice = factors[min(max(level, 1), 4)] - factors[min(max(previous, 1), 4)]
        guard current > 0 else { return 0 }
        return Int(Double(baseMerchRevenuePerMatchDay) * slice / current)
    }

    static func shopUpgradeKey(level: Int) -> String { "shop-\(level)" }
}
