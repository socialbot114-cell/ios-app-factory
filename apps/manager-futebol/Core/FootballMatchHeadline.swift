import Foundation

// MARK: - Manchete do jogo

/// Manchete de uma linha para o fim de jogo e a capa do dia seguinte. Só usa o que a partida registra:
/// placar, adversário, clássico, virada e copa. Várias frases por situação; a escolha é fixa para cada partida.
enum FootballHeadline {
    static func make(club: String, opponent: String, userGoals: Int, rivalGoals: Int,
                     isDerby: Bool, cameFromBehind: Bool, isCup: Bool, seed: Int) -> String {
        let margin = userGoals - rivalGoals
        let score = "\(userGoals) × \(rivalGoals)"
        let cup = isCup ? " na Copa" : ""
        let options: [String]
        if margin > 0 {
            if isDerby {
                options = ["Clássico para a história: \(club) vence o \(opponent) por \(score)",
                           "\(club) cala o rival e bate o \(opponent) por \(score)"]
            } else if cameFromBehind {
                options = ["Virada! \(club) supera o \(opponent) por \(score)\(cup)",
                           "\(club) sai de trás e vence o \(opponent) por \(score)"]
            } else if margin >= 3 {
                options = ["\(club) atropela o \(opponent): \(score)\(cup)",
                           "Goleada! \(club) passa o rolo no \(opponent)",
                           "Show do \(club): \(score) sobre o \(opponent)"]
            } else {
                options = ["\(club) bate o \(opponent) por \(score)\(cup)",
                           "Três pontos para o \(club) diante do \(opponent)",
                           "\(club) vence o \(opponent) por \(score) e segue na briga"]
            }
        } else if margin == 0 {
            if userGoals == 0 {
                options = ["Zero a zero: \(club) e \(opponent) não saem do lugar\(cup)",
                           "Sem gols entre \(club) e \(opponent)"]
            } else {
                options = ["\(club) e \(opponent) empatam em \(score)\(cup)",
                           "Ponto dividido: \(club) \(score) \(opponent)"]
            }
        } else {
            if isDerby {
                options = ["Clássico amargo: \(opponent) vence o \(club) por \(rivalGoals) × \(userGoals)",
                           "\(club) cai no clássico diante do \(opponent)"]
            } else if margin <= -3 {
                options = ["Noite para esquecer: \(club) perde de \(rivalGoals) × \(userGoals) para o \(opponent)",
                           "\(opponent) goleia o \(club) por \(rivalGoals) × \(userGoals)"]
            } else {
                options = ["\(opponent) vence o \(club) por \(rivalGoals) × \(userGoals)\(cup)",
                           "Tropeço do \(club) diante do \(opponent)",
                           "\(club) cai para o \(opponent) e precisa reagir"]
            }
        }
        return options[abs(seed) % options.count]
    }
}

extension FootballCareer {
    /// Manchete de uma partida já jogada, pelo ponto de vista do clube do usuário.
    func matchHeadline(for fixture: LeagueFixture) -> String? {
        guard let selectedClubID, let homeGoals = fixture.homeGoals, let awayGoals = fixture.awayGoals else { return nil }
        let isHome = fixture.home == selectedClubID
        let userGoals = isHome ? homeGoals : awayGoals
        let rivalGoals = isHome ? awayGoals : homeGoals
        // Virada: o clube chegou a perder e terminou vencendo, pelos gols com autor registrados.
        let userScored = fixture.events.filter { $0.kind == .goal }.compactMap { $0.teamID }
        let cameFromBehind = userGoals > rivalGoals && FootballVictory.wasBehind(scorers: userScored.map { $0 == selectedClubID })
        return FootballHeadline.make(club: FootballSeason.teamName(selectedClubID),
                                     opponent: FootballSeason.teamName(fixture.opponent(of: selectedClubID)),
                                     userGoals: userGoals, rivalGoals: rivalGoals,
                                     isDerby: FootballSeason.isDerby(fixture.home, fixture.away),
                                     cameFromBehind: cameFromBehind, isCup: fixture.competition.isCup, seed: fixture.id)
    }
}
