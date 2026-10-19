import Foundation

// MARK: - Relatar problema

extension FootballCareer {
    /// Texto curto para o jogador enviar junto com um relato: versão, ponto da carreira e as últimas ações.
    /// Não leva o save inteiro nem dados pessoais; só números e nomes do jogo.
    func supportReport(version: String, build: String) -> String {
        var lines = ["Manager de Futebol \(version) (\(build))"]
        if let club = selectedClub {
            lines.append("Clube: \(club.name) · \(userDivision?.name ?? "—")")
        } else {
            lines.append("Sem clube escolhido")
        }
        lines.append("Temporada \(season), dia de jogo \(min(matchDayIndex + 1, FootballSeason.matchDaysPerSeason)) de \(FootballSeason.matchDaysPerSeason)")
        lines.append("Dificuldade: \(difficulty.title) · Ritmo: \(world.phone.preferences.rhythmMode.title)")
        lines.append("Caixa \(FootballFormat.money(transferBudget)) · Diretoria \(boardConfidence) · Torcida \(fanMood)")
        lines.append("Partida ao vivo: \(liveMatch == nil ? "não" : "sim") · Fim de temporada: \(isSeasonComplete ? "sim" : "não")")
        let recent = world.phone.actionLog.prefix(5)
        if !recent.isEmpty {
            lines.append("Últimas ações:")
            for item in recent { lines.append("- T\(item.season) D\(item.matchDay + 1): \(item.text)") }
        }
        lines.append("")
        lines.append("O que aconteceu e o que você esperava:")
        return lines.joined(separator: "\n")
    }
}
