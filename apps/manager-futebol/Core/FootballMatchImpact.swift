import Foundation

// MARK: - Repercussão da partida

/// O que o jogo provocou fora de campo: nota do time, torcida, bilheteria, camisas, reputação e diretoria.
struct MatchImpact: Codable, Equatable {
    var score = 0
    var teamGrade = 6.0
    var verdict = ""
    var highlights: [String] = []
    /// Marcas internas usadas por missões e conquistas (comeback, thrashing, upset...).
    var tags: [String] = []
    var fanMoodChange = 0
    var hypeChange = 0
    var hypeAfter = 0
    var newFans = 0
    var reputationChange = 0
    var boardChange = 0
    var shirtsSold = 0
    var shirtRevenue = 0
    var attendance = 0
    var gateRevenue = 0
    /// Bônus de público e de loja que o embalo da torcida já dava neste jogo.
    var crowdBonusPercent = 0
}

extension FootballCareer {
    static let shirtPrice = 229

    /// Embalo da torcida: 0 a 100. Sobe com vitórias e espetáculo, cai com o tempo e com maus resultados.
    var hypeAttendanceFactor: Double { 1 + 0.0035 * Double(clubHype) }
    var hypeMerchFactor: Double { 1 + 0.006 * Double(clubHype) }

    var hypeTitle: String {
        switch clubHype {
        case 80...: return "Torcida em chamas"
        case 60..<80: return "Torcida empolgada"
        case 35..<60: return "Clima animado"
        case 15..<35: return "Clima morno"
        default: return "Torcida fria"
        }
    }

    /// Avalia o que a partida do usuário provocou. Só depende do jogo já registrado, então é reproduzível.
    func evaluateImpact(fixture: LeagueFixture) -> MatchImpact? {
        guard let userID = selectedClubID, let result = fixture.result(for: userID) else { return nil }
        let isHome = fixture.home == userID
        let goalsFor = (isHome ? fixture.homeGoals : fixture.awayGoals) ?? 0
        let goalsAgainst = (isHome ? fixture.awayGoals : fixture.homeGoals) ?? 0
        let xgFor = (isHome ? fixture.homeExpectedGoals : fixture.awayExpectedGoals) ?? Double(goalsFor)
        let xgAgainst = (isHome ? fixture.awayExpectedGoals : fixture.homeExpectedGoals) ?? Double(goalsAgainst)
        let userReds = (isHome ? fixture.homeRed : fixture.awayRed) ?? 0
        let rivalReds = (isHome ? fixture.awayRed : fixture.homeRed) ?? 0
        let opponentID = fixture.opponent(of: userID)
        let derby = FootballSeason.isDerby(fixture.home, fixture.away)
        let margin = goalsFor - goalsAgainst

        var score = 0
        var highlights: [String] = []
        var tags: [String] = []

        switch result {
        case .win: score += 30
        case .draw: score += 8
        case .loss: score -= 10
        }
        if result == .win && margin >= 2 {
            score += min(3, margin - 1) * 8
            if margin >= 3 { highlights.append("Goleada por \(goalsFor) × \(goalsAgainst)"); tags.append("thrashing") }
        }
        if result == .loss && margin <= -3 {
            score -= 12
            highlights.append("Atuação para esquecer")
            tags.append("humiliation")
        }

        var difference = 0
        var worst = 0
        for event in fixture.events where event.kind == .goal {
            difference += event.teamID == userID ? 1 : -1
            worst = min(worst, difference)
        }
        if result == .win && worst <= -1 {
            score += worst <= -2 ? 35 : 25
            highlights.append(worst <= -2 ? "Virada épica depois de estar perdendo por \(-worst)" : "Virada no placar")
            tags.append("comeback")
        } else if result == .draw && worst <= -2 {
            score += 12
            highlights.append("Empate heroico depois de estar perdendo por \(-worst)")
        }
        if result == .win, margin == 1, let lastGoal = fixture.events.last(where: { $0.kind == .goal }),
           lastGoal.teamID == userID, lastGoal.minute >= 85 {
            score += 15
            highlights.append("Gol da vitória aos \(lastGoal.minute) minutos")
            tags.append("lateWinner")
        }
        let expectation = teamRating(userID) - teamRating(opponentID) + (isHome ? 1.5 : -1.5)
        if result == .win && expectation < -2 {
            score += 15
            highlights.append("Vitória contra um adversário mais forte")
            tags.append("upset")
        }
        if derby {
            if result == .win { score += 20; highlights.append("Clássico vencido"); tags.append("derbyWin") }
            else if result == .loss { score -= 10; highlights.append("Clássico perdido") }
        }
        if fixture.competition.isCup && fixture.winner == userID {
            score += 8
            highlights.append("Classificação na copa")
        }
        if fixture.homePenalties != nil && fixture.winner == userID { score += 10 }
        score += max(-12, min(12, Int(((xgFor - xgAgainst) * 6).rounded())))
        if goalsAgainst == 0 && result != .loss {
            score += 6
            highlights.append("Sem sofrer gols")
            tags.append("cleanSheet")
        }
        if fixture.userStats.contains(where: { $0.goals >= 3 }) {
            score += 10
            highlights.append("Hat-trick no jogo")
            tags.append("hatTrick")
        }
        if let best = FootballRatings.manOfTheMatch(fixture.userStats), best.rating >= 8.5, let name = player(best.playerID)?.name {
            score += 5
            highlights.append("\(name), craque do jogo, nota \(String(format: "%.1f", best.rating))")
        }
        if userReds > 0 { score -= 4 * userReds; highlights.append("Expulsão prejudicou o time") }
        if rivalReds > 0 { score += 2 * rivalReds }
        score += min(6, goalsFor * 2)
        score = max(-60, min(100, score))

        var impact = MatchImpact()
        impact.score = score
        impact.teamGrade = (max(2.5, min(10, 6.0 + Double(score) / 18.0)) * 10).rounded() / 10
        switch score {
        case 70...: impact.verdict = "Noite histórica"
        case 45..<70: impact.verdict = "Grande atuação"
        case 20..<45: impact.verdict = "Bom resultado"
        case 0..<20: impact.verdict = "Resultado discreto"
        case -20..<0: impact.verdict = "Tarde ruim"
        default: impact.verdict = "Desastre"
        }
        impact.highlights = highlights
        impact.tags = tags
        impact.hypeChange = max(-6, min(14, Int((Double(score) / 5).rounded())))
        impact.fanMoodChange = max(-3, min(4, score / 12))
        impact.boardChange = max(-1, min(2, score / 30))
        impact.reputationChange = score >= 60 ? 1 : (score <= -25 ? -1 : 0)
        if score > 20 {
            impact.newFans = Int(Double(fanBase) * Double(min(score, 80) - 20) / 60 * 0.004)
        }
        if score > 0 {
            impact.shirtsSold = Int(Double(fanBase) * 0.0025 * (1 + Double(score) / 40))
            impact.shirtRevenue = impact.shirtsSold * Self.shirtPrice
        }
        impact.crowdBonusPercent = Int((hypeAttendanceFactor - 1) * 100)
        impact.hypeAfter = max(0, min(100, clubHype - 2 + impact.hypeChange))
        impact.attendance = fixture.attendance ?? 0
        return impact
    }

    /// Aplica a repercussão: torcida, embalo, reputação, diretoria, camisas e contadores de missões.
    mutating func applyImpact(_ impact: MatchImpact, fixtureIndex: Int) {
        var impact = impact
        fanMood = min(100, max(0, fanMood + impact.fanMoodChange))
        clubHype = impact.hypeAfter
        fanBase += impact.newFans
        if impact.reputationChange != 0 { changeReputation(impact.reputationChange) }
        boardConfidence = min(100, max(0, boardConfidence + impact.boardChange))
        if impact.shirtRevenue > 0 {
            book(.merchandise, impact.shirtRevenue, "\(impact.shirtsSold) camisas vendidas depois do jogo")
        }
        impact.gateRevenue = lastRoundRevenue
        for tag in impact.tags {
            switch tag {
            case "comeback": bump("comebacks")
            case "thrashing": bump("bigWins")
            case "cleanSheet": bump("cleanSheets")
            case "upset": bump("upsets")
            default: break
            }
        }
        if clubHype >= 70 { bump("hypeMatches") }
        fixtures[fixtureIndex].impact = impact
    }

    /// Mostra, no apito final, o que o jogo vai provocar. Roda o fechamento numa cópia, sem tocar na carreira.
    func previewMatchImpact() -> MatchImpact? {
        guard let live = liveMatch, live.sim.finished else { return nil }
        var copy = self
        guard copy.finishMatchDay() else { return nil }
        return copy.latestUserFixture?.impact
    }

    mutating func coolDownHype() {
        clubHype = max(0, clubHype - 2)
    }
}

// MARK: - Perguntas da coletiva

enum PressTopic: String, Codable {
    case general, star, comeback, lateGoal, thrashing, discipline, xg, board, fans, injuries, derby

    func hint(for tone: PressTone) -> String {
        switch (self, tone) {
        case (.star, .calm): return "Elogia sem criar cobrança. O atleta se sente valorizado."
        case (.star, .confident): return "Eleva o moral do atleta e a confiança do vestiário."
        case (.star, .provocative): return "Bota pressão no craque e chama atenção do rival."
        case (.comeback, .calm), (.lateGoal, .calm): return "Valoriza o grupo. Diretoria gosta da humildade."
        case (.comeback, .confident), (.lateGoal, .confident): return "Alimenta o embalo da torcida e vende mais camisas."
        case (.comeback, .provocative), (.lateGoal, .provocative): return "Anima a arquibancada, mas motiva o próximo adversário."
        case (.thrashing, .calm): return "Mantém os pés no chão e protege o vestiário."
        case (.thrashing, .confident): return "A torcida adora, o embalo cresce."
        case (.thrashing, .provocative): return "Humilha o rival, mas ele chega com sangue nos olhos."
        case (.discipline, .calm): return "Reconhece o erro e acalma a diretoria."
        case (.discipline, .confident): return "Defende o atleta: moral sobe, a diretoria torce o nariz."
        case (.discipline, .provocative): return "Critica a arbitragem: a torcida aprova, a diretoria não."
        case (.xg, .calm): return "Reconhece o que precisa melhorar. A diretoria gosta da análise."
        case (.xg, .confident): return "Confia nos números do trabalho. Funciona se o resultado ajudar."
        case (.xg, .provocative): return "Diz que os números mentem. Arriscado."
        case (.board, .calm): return "Mostra serenidade e ganha confiança da diretoria."
        case (.board, .confident): return "Cobra a si mesmo: bom com resultado, ruim sem ele."
        case (.board, .provocative): return "Diretoria não gosta de pressão em público."
        case (.fans, .calm): return "Agradece a torcida. Efeito discreto no clima."
        case (.fans, .confident): return "Chama a torcida para o estádio. Reforça o embalo."
        case (.fans, .provocative): return "Cobra a torcida. Pode esquentar ou azedar o clima."
        case (.injuries, .calm): return "Transmite tranquilidade ao grupo."
        case (.injuries, .confident): return "Promete solução rápida. O elenco confia mais."
        case (.injuries, .provocative): return "Culpa o calendário. Imprensa gosta, vestiário se divide."
        default: return tone.summary
        }
    }
}

extension FootballCareer {
    /// Perguntas que dependem do que aconteceu no jogo: craque, virada, expulsão, números, diretoria e torcida.
    func makeMatchQuestions(fixture: LeagueFixture, result: FootballResult?, opponent: String) -> [(prompt: String, topic: PressTopic, playerID: Int?)] {
        guard let userID = selectedClubID else { return [] }
        var extra: [(prompt: String, topic: PressTopic, playerID: Int?)] = []
        let impact = fixture.impact
        let isHome = fixture.home == userID
        let xgFor = (isHome ? fixture.homeExpectedGoals : fixture.awayExpectedGoals) ?? 0
        let xgAgainst = (isHome ? fixture.awayExpectedGoals : fixture.homeExpectedGoals) ?? 0

        if impact?.tags.contains("comeback") == true {
            extra.append(("O time estava perdendo e virou. O que o senhor disse para a equipe para mudar o jogo?", .comeback, nil))
        } else if impact?.tags.contains("lateGoal") == true || impact?.tags.contains("lateWinner") == true {
            extra.append(("Gol decisivo nos minutos finais. O time acredita até o apito?", .lateGoal, nil))
        } else if impact?.tags.contains("thrashing") == true {
            extra.append(("Uma goleada contra o \(opponent). O recado está dado para a competição?", .thrashing, nil))
        }
        if let red = fixture.events.first(where: { $0.kind == .redCard && $0.teamID == userID }), let id = red.playerID, let name = player(id)?.name {
            extra.append(("A expulsão de \(name) pesou no resultado. Como o senhor avalia a atitude dele?", .discipline, id))
        }
        if let best = FootballRatings.manOfTheMatch(fixture.userStats), best.rating >= 7.5, let name = player(best.playerID)?.name {
            extra.append(("\(name) foi o grande nome, com nota \(String(format: "%.1f", best.rating)). Ele é peça intocável no time?", .star, best.playerID))
        }
        if result == .win && xgAgainst - xgFor >= 0.8 {
            extra.append(("Os números mostram que o \(opponent) criou mais. A vitória foi com sorte?", .xg, nil))
        } else if result == .loss && xgFor - xgAgainst >= 0.8 {
            extra.append(("Os números dizem que o time merecia mais. Faltou eficiência na frente?", .xg, nil))
        }
        if let hurt = fixture.events.first(where: { $0.kind == .injury && $0.teamID == userID }), let id = hurt.playerID, let name = player(id)?.name {
            extra.append(("\(name) saiu lesionado. Preocupa o departamento médico?", .injuries, id))
        }
        if boardConfidence < 35 {
            extra.append(("A diretoria já fala em mudanças. O senhor sente o cargo ameaçado?", .board, nil))
        } else if clubHype >= 70 {
            extra.append(("A torcida está empolgada e o estádio vai lotar. Isso muda a responsabilidade?", .fans, nil))
        } else if fanMood < 35 {
            extra.append(("A torcida está insatisfeita. O que o senhor tem a dizer para ela?", .fans, nil))
        }
        return extra
    }

    /// Efeito extra de cada resposta, conforme o assunto da pergunta.
    mutating func applyPressTopicEffect(topic: PressTopic, tone: PressTone, result: FootballResult, playerID: Int?) {
        func moodOf(_ id: Int?, _ delta: Int) {
            guard let id, let index = players.firstIndex(where: { $0.id == id }) else { return }
            players[index].morale = min(100, max(0, players[index].morale + delta))
        }
        func hype(_ delta: Int) { clubHype = min(100, max(0, clubHype + delta)) }
        switch topic {
        case .star:
            switch tone {
            case .calm: moodOf(playerID, 3)
            case .confident: moodOf(playerID, 5); hype(1)
            case .provocative: moodOf(playerID, -1)
            }
        case .comeback, .lateGoal, .thrashing:
            switch tone {
            case .calm: boardConfidence += 1
            case .confident: hype(3); fanMood += 1
            case .provocative: hype(2); fanMood += 1
            }
        case .discipline:
            switch tone {
            case .calm: boardConfidence += 1
            case .confident: moodOf(playerID, 5); boardConfidence -= 1
            case .provocative: fanMood += 1; boardConfidence -= 2
            }
        case .xg:
            switch tone {
            case .calm: boardConfidence += 1
            case .confident: if result == .win { boardConfidence += 1 } else { boardConfidence -= 1 }
            case .provocative: boardConfidence -= 1
            }
        case .board:
            switch tone {
            case .calm: boardConfidence += 2
            case .confident: boardConfidence += result == .loss ? -2 : 2
            case .provocative: boardConfidence -= 2
            }
        case .fans:
            switch tone {
            case .calm: fanMood += 1
            case .confident: hype(3)
            case .provocative: if result == .win { hype(1); fanMood += 1 } else { hype(-2); fanMood -= 2 }
            }
        case .injuries:
            switch tone {
            case .calm: break
            case .confident: moodOf(playerID, 2)
            case .provocative: moodOf(playerID, -1)
            }
        case .general, .derby:
            break
        }
        boardConfidence = min(100, max(0, boardConfidence))
        fanMood = min(100, max(0, fanMood))
    }
}
