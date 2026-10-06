import Foundation

// MARK: - O mundo reage: mensagens espontâneas depois do jogo

extension FootballCareer {
    /// Depois da partida do clube, pessoas próximas escrevem sem ser chamadas (no máximo duas por dia).
    /// Determinístico: o mesmo jogo gera as mesmas mensagens.
    mutating func generatePostMatchReactions(fixture: LeagueFixture) {
        guard let clubID = selectedClubID, !isFired, let result = fixture.result(for: clubID) else { return }
        ensureContacts()
        let mine = (fixture.home == clubID ? fixture.homeGoals : fixture.awayGoals) ?? 0
        let theirs = (fixture.home == clubID ? fixture.awayGoals : fixture.homeGoals) ?? 0
        let opponent = FootballSeason.teamName(fixture.opponent(of: clubID))
        let salt = abs(fixture.id &+ worldDay)
        var sent = 0

        func pick(_ options: [String], _ offset: Int) -> String { options[(salt &+ offset) % options.count] }

        // Presidente: cobra depois de derrota com a diretoria insatisfeita; elogia goleada.
        if result == .loss && boardConfidence < 55 {
            appendChat("contact-president", fromCoach: false,
                       pick(["Perder para o \(opponent) não estava nos planos. Quero conversar sobre os próximos jogos.",
                             "Resultado ruim. A diretoria espera uma reação já na próxima rodada."], 1), unread: true)
            sent += 1
        } else if result == .win && mine - theirs >= 3 {
            appendChat("contact-president", fromCoach: false, "Que atuação! \(mine) a \(theirs) no \(opponent). Parabéns a toda a comissão.", unread: true)
            sent += 1
        }

        // Autor de gol: agradece a confiança.
        let scorers = fixture.home == clubID ? fixture.homeScorerIDs : fixture.awayScorerIDs
        if sent < 2, result != .loss, let scorerID = scorers.first, let athlete = player(scorerID), athlete.teamID == clubID {
            appendChat("player-\(scorerID)", fromCoach: false,
                       pick(["Mister, obrigado pela confiança. Fico feliz de ter ajudado com o gol!",
                             "Foi um jogo especial pra mim. Vou continuar trabalhando duro."], 2), unread: true)
            if let index = players.firstIndex(where: { $0.id == scorerID }) { players[index].morale = min(100, players[index].morale + 2) }
            sent += 1
        }

        // Família: sempre acompanha.
        if sent < 2 {
            let text: String
            switch result {
            case .win: text = pick(["Vimos o jogo todo! Estamos muito orgulhosos de você.", "Que vitória! A casa inteira comemorou."], 3)
            case .draw: text = pick(["Empate dá para melhorar. Descansa e vai de novo.", "Jogo duro contra o \(opponent). Seguimos juntos."], 3)
            case .loss: text = pick(["Hoje não deu, mas amanhã é outro dia. Vem comer alguma coisa com a gente.", "Derrota faz parte. Cabeça erguida!"], 3)
            }
            appendChat("contact-family", fromCoach: false, text, unread: true)
            sent += 1
        }
    }
}
