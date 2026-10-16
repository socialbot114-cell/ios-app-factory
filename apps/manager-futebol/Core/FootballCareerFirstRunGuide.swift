import Foundation

/// Progresso do roteiro mínimo que ensina o treinador a chegar à primeira partida.
/// Optional em FootballCareer para que saves anteriores não recebam o tutorial de novo.
enum FirstCareerGuideStep: String, Codable, Equatable {
    case welcome
    case manager
    case tactics
    case match
    case liveMatch
    case recap
    case finished
    case skipped

    var isActive: Bool { self != .finished && self != .skipped }

    var toastTitle: String {
        switch self {
        case .welcome: return "Roteiro iniciado"
        case .manager: return "Gestor aberto"
        case .tactics: return "Hora de conferir o time"
        case .match: return "Escalação pronta"
        case .liveMatch: return "Você está no comando"
        case .recap: return "Resumo da partida"
        case .finished: return "Roteiro concluído"
        case .skipped: return "Roteiro encerrado"
        }
    }

    var toastDetail: String {
        switch self {
        case .welcome: return "Seu primeiro jogo está a alguns passos."
        case .manager: return "O cartão do roteiro indica o próximo passo."
        case .tactics: return "Confira titulares e formação antes de voltar."
        case .match: return "Você pode preparar o rival ou jogar agora."
        case .liveMatch: return "Comece, pause ou avance o relógio no seu ritmo."
        case .recap: return "Confira o resultado e a repercussão no FutOS."
        case .finished: return "Boa temporada, treinador!"
        case .skipped: return "Você pode rever o roteiro em Ajustes."
        }
    }

    /// O FutOS usa este identificador para mostrar o cartão no contexto certo.
    var appID: String? {
        switch self {
        case .welcome: return nil
        case .manager, .match, .recap: return "manager"
        case .tactics: return "squad"
        case .liveMatch: return "manager"
        case .finished, .skipped: return nil
        }
    }
}

extension FootballCareer {
    /// Liga o guia de primeira carreira. O app desliga nos UI tests, exceto no teste do guia, para o guia não cobrir as telas testadas (como o onboarding).
    static var firstRunGuideEnabled = true

    var isFirstCareerGuideActive: Bool { firstCareerGuideStep?.isActive == true }

    /// Inicia só ao fechar o primeiro contrato; saves anteriores ficam sem guia até o jogador pedir.
    mutating func beginFirstCareerGuide() {
        guard Self.firstRunGuideEnabled, selectedClubID != nil, firstCareerGuideStep == nil else { return }
        firstCareerGuideStep = .welcome
    }

    /// Transições explícitas impedem toques repetidos de pular etapas.
    @discardableResult
    mutating func advanceFirstCareerGuide(from current: FirstCareerGuideStep, to next: FirstCareerGuideStep) -> Bool {
        guard firstCareerGuideStep == current, current.isActive else { return false }
        firstCareerGuideStep = next
        return true
    }

    mutating func skipFirstCareerGuide() {
        guard isFirstCareerGuideActive else { return }
        firstCareerGuideStep = .skipped
    }

    @discardableResult
    mutating func finishFirstCareerGuide() -> Bool {
        guard firstCareerGuideStep == .recap else { return false }
        firstCareerGuideStep = .finished
        return true
    }

    /// O calendário andou por simulação rápida antes de o roteiro chegar à partida ao vivo. O cartão do celular
    /// continuaria apontando para "Entre em campo" de um jogo que já passou, então o roteiro se encerra.
    mutating func closeStaleFirstCareerGuide() {
        guard let step = firstCareerGuideStep, [.welcome, .manager, .tactics, .match].contains(step) else { return }
        firstCareerGuideStep = .finished
    }

    mutating func replayFirstCareerGuide() {
        guard selectedClubID != nil else { return }
        firstCareerGuideStep = .welcome
    }
}
