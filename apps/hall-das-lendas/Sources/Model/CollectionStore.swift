import Foundation
import Observation

/// Coleção do usuário: cartas compradas, número de série do exemplar e o cartão do dia (gratuito e temporário).
@Observable
final class CollectionStore {
    enum Source: String, Codable {
        case purchase, restored, preview
    }

    struct OwnedCard: Codable, Equatable, Identifiable {
        var cardID: String
        var serial: Int
        var acquired: Date
        var source: Source
        var id: String { cardID }
    }

    /// Cartão do dia: o usuário pode ver e girar a carta até a validade, mas ela não entra na coleção.
    struct DailyLoan: Codable, Equatable {
        var cardID: String
        var expires: Date
    }

    private struct Snapshot: Codable {
        var owned: [OwnedCard] = []
        var nextSerial = 1
        var loan: DailyLoan?
        var lastPackDay: Date?
    }

    private(set) var owned: [OwnedCard]
    private(set) var loan: DailyLoan?
    private(set) var lastPackDay: Date?
    private var nextSerial: Int

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar
    static let storageKey = "hall.collection.v1"
    static let loanDuration: TimeInterval = 24 * 60 * 60

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        let snapshot = defaults.data(forKey: Self.storageKey).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) } ?? Snapshot()
        owned = snapshot.owned
        nextSerial = snapshot.nextSerial
        loan = snapshot.loan
        lastPackDay = snapshot.lastPackDay
    }

    // MARK: Consulta

    func isOwned(_ cardID: String) -> Bool {
        owned.contains { $0.cardID == cardID }
    }

    func ownedCard(_ cardID: String) -> OwnedCard? {
        owned.first { $0.cardID == cardID }
    }

    var activeLoan: DailyLoan? {
        guard let loan, loan.expires > now() else { return nil }
        return loan
    }

    /// Dá para ver a carta inteira: ela é do usuário ou é o cartão do dia ainda válido.
    func hasAccess(_ cardID: String) -> Bool {
        isOwned(cardID) || activeLoan?.cardID == cardID
    }

    var ownedCount: Int { owned.count }
    var isComplete: Bool { owned.count >= LegendCatalog.all.count }

    var canOpenDailyPack: Bool {
        guard !isComplete else { return false }
        guard let lastPackDay else { return true }
        return !calendar.isDate(lastPackDay, inSameDayAs: now())
    }

    // MARK: Mudanças

    /// Entrega a carta ao usuário. Devolve nil se ela já era dele (compra restaurada duas vezes, por exemplo).
    @discardableResult
    func grant(_ cardID: String, source: Source) -> OwnedCard? {
        guard LegendCatalog.card(id: cardID) != nil, !isOwned(cardID) else { return nil }
        let card = OwnedCard(cardID: cardID, serial: nextSerial, acquired: now(), source: source)
        nextSerial += 1
        owned.append(card)
        if loan?.cardID == cardID { loan = nil }
        save()
        return card
    }

    /// Abre o pacote diário gratuito: sorteia entre as cartas que o usuário ainda não tem e a empresta por 24 horas.
    @discardableResult
    func openDailyPack<G: RandomNumberGenerator>(using generator: inout G) -> LegendCard? {
        guard canOpenDailyPack else { return nil }
        let missing = LegendCatalog.all.filter { !isOwned($0.id) }
        guard let card = missing.randomElement(using: &generator) else { return nil }
        loan = DailyLoan(cardID: card.id, expires: now().addingTimeInterval(Self.loanDuration))
        lastPackDay = now()
        save()
        return card
    }

    @discardableResult
    func openDailyPack() -> LegendCard? {
        var generator = SystemRandomNumberGenerator()
        return openDailyPack(using: &generator)
    }

    /// Só para capturas de tela e testes de interface.
    func seedForDemo(ownedIDs: [String]) {
        for id in ownedIDs { grant(id, source: .preview) }
    }

    private func save() {
        let snapshot = Snapshot(owned: owned, nextSerial: nextSerial, loan: loan, lastPackDay: lastPackDay)
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: Self.storageKey) }
    }
}
