import Foundation

// MARK: - Metas (MET-01..05)

enum QuestOrigin: String, Codable, Equatable {
    case player, board, athlete, character

    var title: String {
        switch self {
        case .player: return "Você"
        case .board: return "Diretoria"
        case .athlete: return "Atleta"
        case .character: return "Personagem"
        }
    }
}

struct QuestContribution: Codable, Equatable {
    let season: Int
    let matchDay: Int
    let text: String
}

enum QuestOutcome: String, Codable, Equatable {
    case completed, failed, replaced

    var title: String {
        switch self {
        case .completed: return "Concluída"
        case .failed: return "Não cumprida"
        case .replaced: return "Substituída"
        }
    }
}

struct QuestRecord: Codable, Equatable, Identifiable {
    let id: Int
    let templateID: String
    let title: String
    let origin: QuestOrigin
    let sourceName: String
    let outcome: QuestOutcome
    let season: Int
    let matchDay: Int
    let progress: Int
    let target: Int
    let contributions: [QuestContribution]
}

extension FootballCareer {
    static let personalGoalLimit = 3
    static let questContributionLimit = 12
    static let questHistoryLimit = 60

    /// Metas que dependem de atividade opcional (apostas, Rodada, redes, agenda) ou premiariam
    /// cliques: só entram na lista se o jogador escolher adotá-las.
    static let questOptInIDs: Set<String> = ["w-bets", "s-bets", "w-fantasy", "w-posts", "s-posts", "w-activities"]

    static func questOrigin(for templateID: String) -> (origin: QuestOrigin, source: String) {
        switch templateID {
        case "w-press": return (.character, "Imprensa")
        case "w-posts", "s-posts": return (.character, "Torcida")
        case "w-hype": return (.character, "Torcida")
        case "w-events": return (.character, "Acontecimentos")
        case "w-signing", "w-friendly", "w-cleansheet", "w-comeback", "s-wins", "s-matches", "s-bigwins", "s-upsets": return (.board, "Diretoria")
        default: return (.player, "Você")
        }
    }

    /// App do celular que ajuda a cumprir a meta (MET-03), pelo identificador de `PhoneApp`.
    static func questActionApp(counter: String) -> String? {
        switch counter {
        case "wins", "matches", "cleanSheets", "comebacks", "bigWins", "upsets", "hypeMatches", "friendlies": return "squad"
        case "press": return "manager"
        case "posts": return "social"
        case "bets": return "betting"
        case "fantasyLineups": return "fantasy"
        case "signings": return "market"
        case "events": return "alerts"
        case "activities": return "life"
        default: return nil
        }
    }

    static func questActionTitle(counter: String) -> String? {
        questActionApp(counter: counter).map {
            switch $0 {
            case "squad": return "Preparar o time"
            case "manager": return "Abrir o Gestor"
            case "social": return "Abrir a Chuteira"
            case "betting": return "Abrir o Palpite+"
            case "fantasy": return "Abrir a Rodada"
            case "market": return "Abrir o Transfer"
            case "alerts": return "Ver acontecimentos"
            default: return "Abrir a Vida"
            }
        }
    }

    static func questContributionLabel(counter: String) -> String {
        switch counter {
        case "wins": return "vitória"
        case "matches": return "jogo disputado"
        case "cleanSheets": return "jogo sem sofrer gol"
        case "comebacks": return "virada"
        case "bigWins": return "goleada"
        case "upsets": return "vitória sobre um favorito"
        case "hypeMatches": return "jogo com a torcida empolgada"
        case "friendlies": return "amistoso"
        case "press": return "resposta na coletiva"
        case "posts": return "publicação"
        case "bets": return "palpite"
        case "fantasyLineups": return "escalação da Rodada"
        case "signings": return "contratação"
        case "events": return "acontecimento decidido"
        case "activities": return "atividade cumprida"
        default: return counter
        }
    }

    // MARK: Histórico

    mutating func recordQuest(_ quest: Quest, outcome: QuestOutcome) {
        var history = world.quests.history ?? []
        guard !history.contains(where: { $0.id == quest.id && $0.outcome == outcome }) else { return }
        history.insert(QuestRecord(id: quest.id, templateID: quest.templateID, title: quest.title,
                                   origin: quest.origin ?? .player, sourceName: quest.sourceName ?? quest.origin?.title ?? "Você",
                                   outcome: outcome, season: season, matchDay: matchDayIndex,
                                   progress: outcome == .completed ? quest.target : progress(of: quest), target: quest.target,
                                   contributions: quest.contributions ?? []), at: 0)
        if history.count > Self.questHistoryLimit { history.removeLast(history.count - Self.questHistoryLimit) }
        world.quests.history = history
    }

    // MARK: Contribuições

    /// Resume as contribuições sem repetir: "acontecimento decidido ×7, vitória ×2", no máximo `limit` itens distintos.
    static func compactContributions(_ list: [QuestContribution], limit: Int = 3) -> String {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for item in list {
            if counts[item.text] == nil { order.append(item.text) }
            counts[item.text, default: 0] += 1
        }
        let shown = order.suffix(limit)
        let text = shown.map { counts[$0]! > 1 ? "\($0) ×\(counts[$0]!)" : $0 }.joined(separator: ", ")
        return order.count > limit ? text + " e mais \(order.count - limit)" : text
    }

    /// Registra o evento que fez progredir cada meta aberta que usa este contador.
    mutating func logQuestContribution(counter: String, amount: Int) {
        guard amount > 0 else { return }
        for index in world.quests.active.indices where world.quests.active[index].counter == counter && !world.quests.active[index].completed {
            let quest = world.quests.active[index]
            // O contador já subiu: conta o evento se a meta ainda estava aberta antes dele.
            guard (counters[counter] ?? 0) - amount - quest.baseline < quest.target else { continue }
            var list = quest.contributions ?? []
            let label = Self.questContributionLabel(counter: counter)
            list.append(QuestContribution(season: season, matchDay: matchDayIndex, text: amount > 1 ? "\(amount) × \(label)" : label))
            if list.count > Self.questContributionLimit { list.removeFirst(list.count - Self.questContributionLimit) }
            world.quests.active[index].contributions = list
        }
    }

    // MARK: Metas pessoais (MET-02)

    var personalGoals: [Quest] {
        world.quests.active.filter { $0.origin == .player && !$0.completed }
    }

    /// Metas que o jogador pode adotar agora.
    var adoptableGoals: [QuestTemplate] {
        let active = Set(world.quests.active.filter { !$0.completed }.map(\.templateID))
        return Self.questTemplates.filter { !active.contains($0.id) }
    }

    @discardableResult
    mutating func adoptGoal(templateID: String) -> Bool {
        guard personalGoals.count < Self.personalGoalLimit, adoptableGoals.contains(where: { $0.id == templateID }),
              let template = Self.questTemplates.first(where: { $0.id == templateID }) else { return false }
        addQuest(template, adopted: true)
        return true
    }

    /// Troca uma meta pessoal por outra e guarda a anterior no histórico.
    @discardableResult
    mutating func replaceGoal(questID: Int, with templateID: String) -> Bool {
        guard let index = world.quests.active.firstIndex(where: { $0.id == questID && $0.origin == .player && !$0.completed }),
              adoptableGoals.contains(where: { $0.id == templateID }),
              let template = Self.questTemplates.first(where: { $0.id == templateID }) else { return false }
        recordQuest(world.quests.active[index], outcome: .replaced)
        world.quests.active.remove(at: index)
        addQuest(template, adopted: true)
        return true
    }
}
