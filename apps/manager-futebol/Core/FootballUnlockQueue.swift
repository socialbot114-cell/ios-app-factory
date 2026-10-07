import Foundation

// MARK: - Fila de desbloqueios (MRC-01)

/// Conquista ou meta recém-concluída, guardada até a faixa do celular mostrá-la.
struct UnlockNotice: Codable, Equatable, Identifiable {
    /// Único na fila: "conquista-<rawValue>" ou "meta-<id>".
    let id: String
    let title: String
    let detail: String
    /// Símbolo do SF Symbols.
    let symbol: String
    /// `PhoneApp.rawValue` do app que abre ao toque: "trophies" (Troféus) ou "quests" (Metas).
    let appID: String
}

/// Regras puras da fila, sem estado nem interface, para testar isoladamente.
enum FootballUnlockQueue {
    /// Quantos avisos a fila guarda; ao passar disso, sai o mais antigo.
    static let limit = 10

    /// Põe o aviso no fim da fila (ordem de chegada). Um aviso com o mesmo id sai da posição antiga e entra no fim.
    static func enqueue(_ notice: UnlockNotice, in queue: [UnlockNotice]) -> [UnlockNotice] {
        var updated = queue.filter { $0.id != notice.id }
        updated.append(notice)
        if updated.count > limit { updated.removeFirst(updated.count - limit) }
        return updated
    }

    /// Tira o primeiro aviso, o que estava na faixa.
    static func dequeue(_ queue: [UnlockNotice]) -> [UnlockNotice] {
        Array(queue.dropFirst())
    }
}

extension FootballCareer {
    /// Registra um desbloqueio para a faixa do celular; a regra que o concedeu não muda.
    mutating func enqueueUnlock(_ notice: UnlockNotice) {
        unlockQueue = FootballUnlockQueue.enqueue(notice, in: unlockQueue)
    }

    mutating func queueAchievementUnlock(_ achievement: Achievement) {
        enqueueUnlock(UnlockNotice(id: "conquista-\(achievement.rawValue)", title: achievement.title, detail: achievement.detail,
                                   symbol: achievement.symbol, appID: "trophies"))
    }

    mutating func queueQuestUnlock(_ quest: Quest) {
        enqueueUnlock(UnlockNotice(id: "meta-\(quest.id)", title: quest.title, detail: quest.detail,
                                   symbol: "checklist", appID: "quests"))
    }

    /// Tira da faixa o aviso que ela mostrava. Se ele já saiu (toque repetido), não mexe no seguinte.
    mutating func finishUnlock(id: String) {
        guard unlockQueue.first?.id == id else { return }
        unlockQueue = FootballUnlockQueue.dequeue(unlockQueue)
    }
}
