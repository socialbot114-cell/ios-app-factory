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

        // Família: acompanha nos jogos que marcam (derrota, vitória grande ou de vez em quando), sem encher a conversa.
        let notable = result == .loss || (result == .win && mine - theirs >= 2) || salt % 3 == 0
        let pending = (world.phone.chat?.log ?? []).filter { $0.threadID == "contact-family" && $0.unread == true }
        if sent < 2, notable, pending.count < 2 {
            let pool: [String]
            switch result {
            case .win: pool = ["Vimos o jogo todo! Estamos muito orgulhosos de você.", "Que vitória! A casa inteira comemorou.",
                               "Sua mãe chorou de emoção no segundo gol. Parabéns!", "Churrasco no domingo para comemorar?"]
            case .draw: pool = ["Empate dá para melhorar. Descansa e vai de novo.", "Jogo duro contra o \(opponent). Seguimos juntos.",
                                "O ponto pode valer ouro no fim do campeonato.", "Cuida do sono, que o próximo jogo vem aí."]
            case .loss: pool = ["Hoje não deu, mas amanhã é outro dia. Vem comer alguma coisa com a gente.", "Derrota faz parte. Cabeça erguida!",
                                "Não leia os comentários hoje. A gente confia em você.", "Liga quando puder. Ninguém aqui desistiu."]
            }
            let last = (world.phone.chat?.log ?? []).last { $0.threadID == "contact-family" && !$0.fromCoach }?.text
            let fresh = pool.filter { $0 != last }
            appendChat("contact-family", fromCoach: false, fresh[(salt &+ 3) % max(1, fresh.count)], unread: true)
            sent += 1
        }
    }
}
