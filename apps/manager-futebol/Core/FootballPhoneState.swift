import Foundation

// MARK: - Preferências e histórico do FutOS (OS-06, AJU-02..06)

/// Resultado de uma ação do jogador, guardado para consulta depois que o aviso some.
struct ActionResult: Codable, Equatable, Identifiable {
    let id: Int
    let season: Int
    let matchDay: Int
    /// Identificador do app aberto quando a ação aconteceu (PhoneApp.rawValue).
    let appID: String?
    let text: String
}

struct DifficultyChange: Codable, Equatable {
    let season: Int
    let matchDay: Int
    let from: Difficulty
    let to: Difficulty
}

/// Eventos que interrompem o avanço rápido (AJU-03).
struct AdvancePauses: Codable, Equatable {
    var decisions = true
    var injuries = true
    /// Desligado por padrão: o avanço rápido sempre dispensou a coletiva; ligue para pausar nela.
    var press = false
    var offers = true
}

/// Ritmo do FutOS. "Clássico" pede animações curtas e rituais resumidos; "Imersivo" mantém as cenas completas, como sempre foi.
/// A comemoração de vitória já respeita o ritmo; o ritual de virada e a tela de bloqueio ainda não.
enum FootballRhythm: String, Codable, CaseIterable, Identifiable {
    case classic, immersive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Clássico"
        case .immersive: return "Imersivo"
        }
    }

    var detail: String {
        switch self {
        case .classic: return "Animações curtas e rituais resumidos."
        case .immersive: return "Cenas completas, como sempre foi."
        }
    }

    /// Partículas de uma comemoração: o Clássico mostra metade, sem zerar o efeito.
    func celebrationCount(_ count: Int) -> Int {
        self == .classic ? max(1, count / 2) : count
    }

    /// Duração de uma comemoração, em segundos: o Clássico termina mais cedo.
    func celebrationSeconds(_ seconds: Double) -> Double {
        self == .classic ? seconds * 0.6 : seconds
    }
}

struct PhonePreferences: Codable, Equatable {
    /// 1 = todos os avisos, 2 = importantes e urgentes, 3 = só urgentes.
    var minimumPriority = 1
    var mutedApps: [String] = []
    var reduceMotion = false
    var pauses = AdvancePauses()
    /// Ritmo escolhido; opcional para saves antigos, que ficam em Imersivo.
    var rhythm: FootballRhythm? = nil

    var rhythmMode: FootballRhythm { rhythm ?? .immersive }

    /// Avisos urgentes (prioridade 3) nunca são silenciados: perder uma coletiva ou crise tem custo no jogo.
    func allows(appID: String, priority: Int) -> Bool {
        if priority >= 3 { return true }
        if priority < minimumPriority { return false }
        return !mutedApps.contains(appID)
    }
}

struct PhoneState: Codable, Equatable {
    static let actionLogLimit = 40
    var preferences = PhonePreferences()
    var actionLog: [ActionResult] = []
    var nextActionID = 1
    var difficultyChanges: [DifficultyChange] = []
    /// Mensagens livres do chat; opcional para saves antigos.
    var chat: ChatState? = nil
    /// Sugestões adiadas: id → último dia de jogo em que ficam escondidas; opcional para saves antigos.
    var snoozedSuggestions: [String: Int]? = nil
}

extension FootballCareer {
    mutating func logActionResult(_ text: String, appID: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // O mesmo aviso repetido em sequência não polui o histórico.
        if let last = world.phone.actionLog.first, last.text == trimmed, last.matchDay == matchDayIndex, last.season == season { return }
        world.phone.actionLog.insert(ActionResult(id: world.phone.nextActionID, season: season, matchDay: matchDayIndex, appID: appID, text: trimmed), at: 0)
        world.phone.nextActionID += 1
        if world.phone.actionLog.count > PhoneState.actionLogLimit {
            world.phone.actionLog.removeLast(world.phone.actionLog.count - PhoneState.actionLogLimit)
        }
    }

    // MARK: Dificuldade e desafios (AJU-06)

    /// Durante um desafio ativo a dificuldade é uma regra do cenário, não uma preferência.
    var canChangeDifficulty: Bool { challenge?.status != .active }

    var difficultyLockReason: String? {
        guard !canChangeDifficulty, let challenge, let scenario = ChallengeScenario.scenario(id: challenge.scenarioID) else { return nil }
        return "Travada em \(difficulty.title) pelo desafio \"\(scenario.title)\"."
    }

    @discardableResult
    mutating func changeDifficulty(to newValue: Difficulty) -> Bool {
        guard canChangeDifficulty, newValue != difficulty else { return false }
        world.phone.difficultyChanges.insert(DifficultyChange(season: season, matchDay: matchDayIndex, from: difficulty, to: newValue), at: 0)
        difficulty = newValue
        return true
    }

    /// Regras do desafio ativo, em texto, para o jogador conferir (AJU-06).
    var activeChallengeRules: [String] {
        guard let challenge, challenge.status == .active, let scenario = ChallengeScenario.scenario(id: challenge.scenarioID) else { return [] }
        var rules = ["Dificuldade: \(difficulty.title) (fixa)",
                     "Prazo: \(scenario.seasonsAllowed) temporada(s), desde a temporada \(challenge.startSeason)"]
        if let age = scenario.maxStarterAge { rules.append("Titulares com até \(age) anos") }
        if let cap = scenario.wageCapFactor { rules.append("Folha limitada a \(Int((cap * 100).rounded()))% do referencial") }
        for goal in scenario.goals { rules.append("Meta: \(goal.text)") }
        return rules
    }
}
