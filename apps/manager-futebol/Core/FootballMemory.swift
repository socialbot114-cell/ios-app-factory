import Foundation

// MARK: - Memória e interesses dos atletas (F3-01/F3-02)

enum MemoryKind: String, Codable, Equatable {
    case promiseKept, promisePartial, promiseBroken, requestRefused, requestIgnored, renewalAgreed, negotiationBroke, meetingHeld, lostToRival

    var weight: Int {
        switch self {
        case .promiseKept: return 12
        case .promisePartial: return -4
        case .promiseBroken: return -20
        case .requestRefused: return -6
        case .requestIgnored: return -4
        case .renewalAgreed: return 10
        case .negotiationBroke: return -8
        case .meetingHeld: return 6
        case .lostToRival: return -3
        }
    }

    var label: String {
        switch self {
        case .promiseKept: return "Cumpriu a promessa de minutos"
        case .promisePartial: return "Cumpriu só parte da promessa"
        case .promiseBroken: return "Quebrou a promessa de minutos"
        case .requestRefused: return "Recusou um pedido"
        case .requestIgnored: return "Ignorou um pedido"
        case .renewalAgreed: return "Fechou uma renovação"
        case .negotiationBroke: return "Rompeu uma negociação"
        case .meetingHeld: return "Conversou depois de um problema"
        case .lostToRival: return "Foi sondado, mas o clube não fechou a tempo"
        }
    }
}

struct PlayerMemory: Codable, Equatable, Identifiable {
    let id: String
    let playerID: Int
    let kind: MemoryKind
    let worldDay: Int
}

enum PlayerInterest: String, Codable, CaseIterable, Equatable {
    case minutes, money, titles, loyalty

    var label: String {
        switch self {
        case .minutes: return "minutos em campo"
        case .money: return "salário"
        case .titles: return "títulos"
        case .loyalty: return "estabilidade no clube"
        }
    }
}

extension FootballCareer {
    static let memoryPerPlayerLimit = 12
    static let commitmentLimit = 60

    /// Guarda uma lembrança uma única vez por ID, mantendo só as mais recentes de cada atleta.
    @discardableResult
    mutating func recordMemory(playerID: Int, kind: MemoryKind, id: String) -> Bool {
        guard !playerMemories.contains(where: { $0.id == id }) else { return false }
        playerMemories.append(PlayerMemory(id: id, playerID: playerID, kind: kind, worldDay: worldDay))
        let mine = playerMemories.filter { $0.playerID == playerID }
        if mine.count > Self.memoryPerPlayerLimit, let oldest = mine.first {
            playerMemories.removeAll { $0.id == oldest.id }
        }
        return true
    }

    func memories(of playerID: Int) -> [PlayerMemory] {
        playerMemories.filter { $0.playerID == playerID }.sorted { $0.worldDay > $1.worldDay }
    }

    /// Confiança do atleta no treinador, de -100 a 100. Memórias antigas pesam menos.
    func trust(of playerID: Int) -> Int {
        let total = playerMemories.filter { $0.playerID == playerID }.reduce(0.0) { sum, memory in
            let age = Double(max(0, worldDay - memory.worldDay))
            return sum + Double(memory.kind.weight) * max(0.25, 1 - age / 240)
        }
        return max(-100, min(100, Int(total.rounded())))
    }

    /// Interesses estáveis, derivados do atleta (idade, potencial, profissionalismo): não mudam a cada conversa.
    func interests(of athlete: FootballPlayer) -> [PlayerInterest: Int] {
        let professionalism = athlete.attributes[.professionalism]
        let headroom = max(0, athlete.potential - athlete.overall)
        var minutes = 40 + (athlete.age <= 23 ? 25 : 0) + headroom
        var money = 30 + (athlete.age >= 28 ? 20 : 0) + (20 - professionalism)
        var titles = 25 + max(0, athlete.overall - 70)
        var loyalty = 20 + professionalism * 3 + (athlete.age >= 30 ? 15 : 0)
        let seed = (athlete.id * 37) % 11
        minutes += seed; money += (seed * 3) % 7; titles += (seed * 5) % 9; loyalty += (seed * 7) % 5
        return [.minutes: minutes, .money: money, .titles: titles, .loyalty: loyalty]
    }

    func topInterest(of athlete: FootballPlayer) -> PlayerInterest {
        interests(of: athlete).max { $0.value != $1.value ? $0.value < $1.value : $0.key.rawValue > $1.key.rawValue }?.key ?? .minutes
    }
}
