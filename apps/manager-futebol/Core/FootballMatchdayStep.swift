import Foundation

// MARK: - Próximo passo do dia de jogo (FLX-03)

/// O que falta no dia de jogo, na ordem em que o treinador precisa resolver. O botão "Próximo passo" leva até ele.
enum MatchdayStep: Equatable {
    /// Coletiva pendente: responder antes de o dia andar.
    case press
    /// Escalação com alertas (titular lesionado, cansado ou improvisado): revisar antes do jogo.
    case prepare
    /// Escalação sem alertas e jogo marcado: jogar a partida.
    case play
    /// Dia sem jogo do clube: avançar o calendário.
    case advance

    /// Decide o passo a partir do que já se sabe. Função pura, para testar sem montar uma carreira inteira.
    static func next(hasPendingPress: Bool, hasUserMatch: Bool, lineupWarnings: Int, canAdvanceWithoutPlaying: Bool) -> MatchdayStep? {
        if hasPendingPress { return .press }
        if hasUserMatch { return lineupWarnings == 0 ? .play : .prepare }
        if canAdvanceWithoutPlaying { return .advance }
        return nil
    }
}

extension FootballCareer {
    /// O próximo passo do dia de jogo. Nil quando não há nada a fazer agora (sem clube, temporada encerrada, demissão ou entressafra).
    var matchdayStep: MatchdayStep? {
        // Partida em andamento tem a própria faixa de retomada: não é um passo do dia.
        guard liveMatch == nil else { return nil }
        return MatchdayStep.next(hasPendingPress: pendingPress != nil,
                          hasUserMatch: canPlay,
                          lineupWarnings: lineupWarnings.count,
                          canAdvanceWithoutPlaying: canAdvanceWithoutPlaying)
    }
}
