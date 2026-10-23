import Foundation

// MARK: - Economia viva (build 31)
//
// Três respostas do mundo ao que o jogador faz, todas calibradas para não mexer na média de quem joga "no automático":
// o astro puxa a loja (ECV-02), o jogo grande aguenta ingresso mais caro (ECV-03) e o patrocinador reage ao desempenho (PAT-02).

/// Por que um jogo aguenta preço maior.
enum MatchStakes: Equatable {
    case ordinary, bigOpponent, decisive, cup, derby

    var title: String {
        switch self {
        case .ordinary: return "Jogo comum"
        case .bigOpponent: return "Adversário grande"
        case .decisive: return "Jogo decisivo"
        case .cup: return "Mata-mata"
        case .derby: return "Clássico"
        }
    }

    /// Quanto da perda de público causada por um ingresso caro é perdoada neste jogo (0 a 1).
    var priceTolerance: Double {
        switch self {
        case .ordinary: return 0
        case .bigOpponent: return 0.20
        case .decisive: return 0.30
        case .cup: return 0.30
        case .derby: return 0.45
        }
    }
}

extension FootballCareer {
    // MARK: Ingresso dinâmico (ECV-03)

    func matchStakes(for fixture: LeagueFixture) -> MatchStakes {
        guard let club = selectedClub else { return .ordinary }
        if FootballSeason.isDerby(fixture.home, fixture.away) { return .derby }
        if fixture.competition.isCup { return .cup }
        if isTitleOrRelegationRace(for: club.id, division: fixture.competition.division) { return .decisive }
        if let opponent = FootballSeason.team(fixture.opponent(of: club.id)), opponent.strength >= club.strength + 6 { return .bigOpponent }
        return .ordinary
    }

    /// Nas últimas rodadas, o jogo pesa para quem está perto do título ou do rebaixamento.
    private func isTitleOrRelegationRace(for clubID: Int, division: Division?) -> Bool {
        guard let division, matchDayIndex >= FootballSeason.matchDaysPerSeason - 8 else { return false }
        let table = standings(for: division)
        guard let position = table.firstIndex(where: { $0.team.id == clubID }), table.count > 6 else { return false }
        return position <= 2 || position >= table.count - 3
    }

    /// Fator de público do preço escolhido neste jogo: o ingresso caro assusta menos num clássico, mas o barato não rende bônus extra.
    func priceDemandFactor(for fixture: LeagueFixture) -> Double {
        let base = ticketPrice.demandFactor
        guard base < 1 else { return base }
        return 1 - (1 - base) * (1 - matchStakes(for: fixture).priceTolerance)
    }

    /// O preço mais alto que ainda enche o estádio no jogo, para sugerir ao jogador.
    func suggestedTicketPrice(for fixture: LeagueFixture) -> TicketPrice {
        var best = TicketPrice.popular
        var bestRevenue = -1
        for price in TicketPrice.allCases {
            var trial = self
            trial.ticketPrice = price
            let crowd = trial.attendance(for: fixture)
            let revenue = Int(Double(crowd) * price.revenueMultiplier * 1000)
            if revenue > bestRevenue { bestRevenue = revenue; best = price }
        }
        return best
    }

    // MARK: Astro e vendas de camisa (ECV-02)

    /// O jogador que mais chama atenção do elenco principal: nível acima do resto, fase e gols.
    var starPlayer: FootballPlayer? {
        guard let selectedClubID else { return nil }
        let squad = players.filter { $0.teamID == selectedClubID && !$0.isYouth }
        return squad.max { starScore($0, in: squad) < starScore($1, in: squad) }
    }

    private func starScore(_ player: FootballPlayer, in squad: [FootballPlayer]) -> Double {
        Double(player.overall) + ((player.form.recentAverage ?? 6.5) - 6.5) * 3 + Double(min(player.goals, 10)) * 0.15
    }

    /// Efeito do astro na loja: de -6% a +15%. Fica em zero quando o melhor jogador é só 6 pontos acima do resto do time,
    /// que é o que os clubes têm no começo; sobe com a distância, a fase boa e os gols, e cai quando ele sai ou se machuca.
    var starMerchFactor: Double {
        guard let selectedClubID, let star = starPlayer else { return 1 }
        let squad = players.filter { $0.teamID == selectedClubID && !$0.isYouth }.sorted { $0.overall > $1.overall }
        let topEleven = squad.prefix(11)
        guard !topEleven.isEmpty else { return 1 }
        let average = Double(topEleven.map(\.overall).reduce(0, +)) / Double(topEleven.count)
        let gap = Double(star.overall) - average - 6
        let form = ((star.form.recentAverage ?? 6.5) - 6.5) * 0.06
        let scorer = Double(min(star.goals, 10)) * 0.004
        var pull = gap * 0.015 + form + scorer
        if star.injuryRounds > 0 { pull *= 0.5 }
        return 1 + min(0.15, max(-0.06, pull))
    }

    // MARK: Patrocinador (PAT-02)

    /// Pagamento do patrocinador em relação ao contrato: de 0,92 (insatisfeito) a 1,08 (muito satisfeito).
    var sponsorExposureFactor: Double {
        guard let deal = sponsorDeal else { return 1 }
        return 0.92 + 0.0016 * Double(min(100, max(0, deal.satisfaction)))
    }

    var sponsorMood: String {
        guard let deal = sponsorDeal else { return "Sem patrocinador" }
        switch deal.satisfaction {
        case 75...: return "Muito satisfeito"
        case 55..<75: return "Satisfeito"
        case 35..<55: return "Neutro"
        default: return "Insatisfeito"
        }
    }

    /// Chamado depois de cada jogo do usuário. Vitória e clássico ganho contam mais; a torcida em alta e o estádio cheio ajudam.
    mutating func updateSponsorSatisfaction(fixture: LeagueFixture, result: FootballResult) {
        guard var deal = sponsorDeal else { return }
        var delta = result == .win ? 3 : (result == .loss ? -3 : 0)
        if FootballSeason.isDerby(fixture.home, fixture.away), result != .draw { delta += result == .win ? 2 : -1 }
        if clubHype >= 70 { delta += 1 } else if clubHype < 20 { delta -= 1 }
        if let crowd = fixture.attendance, fixture.home == selectedClubID, crowd >= effectiveStadiumCapacity * 95 / 100 { delta += 1 }
        deal.satisfaction = min(100, max(0, deal.satisfaction + delta))
        let tier = deal.satisfaction >= 75 ? 1 : (deal.satisfaction <= 30 ? -1 : 0)
        if tier != deal.notifiedTier {
            deal.notifiedTier = tier
            if tier == 1 {
                addInbox(.finance, title: "\(deal.sponsor) está satisfeito",
                         body: "A marca aparece em cada vitória e em estádio cheio. O pagamento sobe cerca de 8% e, no fim do contrato, ela quer renovar em condições melhores.")
            } else if tier == -1 {
                addInbox(.finance, title: "\(deal.sponsor) reclama do momento",
                         body: "Sequência ruim e pouca exposição. O pagamento caiu cerca de 8% e a marca avisa que pode não renovar.")
            }
        }
        sponsorDeal = deal
    }

    /// Fim de contrato: o patrocinador satisfeito oferece renovação melhor; o insatisfeito vai embora.
    mutating func settleSponsorRenewal(for deal: SponsorDeal) {
        sponsorRenewal = nil
        if deal.satisfaction >= 70 {
            sponsorRenewal = SponsorOffer(id: season * 10 + 4, sponsor: deal.sponsor, fixedPerSeason: Int(Double(deal.fixedPerSeason) * 1.10 / 10_000) * 10_000,
                                          bonusPerWin: deal.bonusPerWin, titleBonus: deal.titleBonus, seasons: 2, profile: "Renovação")
            addInbox(.finance, title: "\(deal.sponsor) quer renovar", body: "Pela temporada que fez, a marca oferece mais 10% no valor fixo para continuar por mais duas temporadas.")
        } else if deal.satisfaction <= 30 {
            addInbox(.finance, title: "\(deal.sponsor) não renova", body: "O contrato acabou e a marca saiu insatisfeita. As novas propostas vêm de outras empresas.")
        }
    }

    /// Fase do mercado de patrocínio nesta temporada: de 0,92 a 1,10, em média 1,0, pela fase da torcida e por um sorteio da temporada.
    func sponsorMarketHeat(using random: inout FootballRandom) -> Double {
        let luck = 0.93 + 0.14 * random.unit()
        return min(1.10, max(0.92, luck + Double(clubHype - 25) * 0.0006))
    }
}

// MARK: - Textos para as telas

extension FootballCareer {
    /// Dica do próximo jogo em casa: o tipo de jogo e o preço que ainda enche o estádio.
    var nextHomeTicketNote: String? {
        guard let selectedClubID, let fixture = upcomingUserFixtures.first(where: { $0.home == selectedClubID }) else { return nil }
        let stakes = matchStakes(for: fixture)
        let rival = FootballSeason.teamName(fixture.away)
        let advice = suggestedTicketPrice(for: fixture)
        guard stakes != .ordinary else { return "Próximo jogo em casa: \(rival). Jogo comum; o preço \(advice.title) rende mais sem esvaziar o estádio." }
        return "Próximo jogo em casa: \(rival). \(stakes.title): aguenta ingresso mais caro; o preço \(advice.title) rende mais sem esvaziar o estádio."
    }

    /// Frase da loja sobre o astro do elenco.
    var starShopNote: String? {
        guard let star = starPlayer else { return nil }
        let percent = Int(((starMerchFactor - 1) * 100).rounded())
        let sign = percent > 0 ? "+" : ""
        return "Astro: \(star.name) (\(star.overall)) muda as vendas em \(sign)\(percent)%. Vender ou perder o craque derruba esse efeito."
    }

    /// Frase do patrocinador: humor e efeito no pagamento.
    var sponsorMoodNote: String? {
        guard let deal = sponsorDeal else { return nil }
        let percent = Int(((sponsorExposureFactor - 1) * 100).rounded())
        let sign = percent > 0 ? "+" : ""
        return "\(sponsorMood) (\(deal.satisfaction)/100): paga \(sign)\(percent)% sobre o fixo. Vitórias, clássicos ganhos, torcida em alta e estádio cheio sobem esse número."
    }
}
