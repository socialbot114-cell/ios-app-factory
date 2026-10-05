import Foundation

// MARK: - Avaliação da diretoria em três frentes (CLB-01)

/// Uma frente da avaliação: nota de 0 a 100 e as razões que a explicam.
struct BoardFront: Equatable, Identifiable {
    let title: String
    let score: Int
    let reasons: [String]

    var id: String { title }
    var verdict: String { score >= 65 ? "Satisfeita" : (score >= 40 ? "Atenta" : "Preocupada") }
}

struct BoardEvaluation: Equatable {
    let sporting: BoardFront
    let financial: BoardFront
    let institutional: BoardFront

    var fronts: [BoardFront] { [sporting, financial, institutional] }
    /// A frente mais fraca: é o que a diretoria vai cobrar primeiro.
    var weakest: BoardFront { fronts.min { $0.score < $1.score } ?? sporting }
}

extension FootballCareer {
    /// Avaliação separada: esportiva (tabela e forma), financeira (caixa, dívida, folha) e institucional (imagem, torcida, promessas).
    var boardEvaluation: BoardEvaluation {
        BoardEvaluation(sporting: sportingFront(), financial: financialFront(), institutional: institutionalFront())
    }

    private func clamp(_ value: Double) -> Int { min(100, max(0, Int(value.rounded()))) }

    private func sportingFront() -> BoardFront {
        var score = 60.0
        var reasons: [String] = []
        if let position = userPosition, matchDayIndex >= 3 {
            let gap = boardTarget - position
            score += Double(gap) * 6
            reasons.append(gap >= 0 ? "\(position)º lugar, dentro da meta (\(boardTarget)º)" : "\(position)º lugar, \(-gap) posição(ões) abaixo da meta (\(boardTarget)º)")
        } else {
            reasons.append("Temporada no começo: meta de \(boardTarget)º lugar")
        }
        if let clubID = selectedClubID {
            let recent = form(teamID: clubID).suffix(5)
            let wins = recent.filter { $0 == .win }.count
            let losses = recent.filter { $0 == .loss }.count
            if !recent.isEmpty {
                score += Double(wins - losses) * 4
                reasons.append("Últimos \(recent.count) jogos: \(wins) vitória(s), \(losses) derrota(s)")
            }
        }
        return BoardFront(title: "Esportiva", score: clamp(score), reasons: reasons)
    }

    private func financialFront() -> BoardFront {
        var score = 70.0
        var reasons: [String] = []
        if isInDebt {
            score -= 30
            reasons.append("Caixa negativo há \(redMatchDays) dia(s): juros e risco de transfer ban")
        }
        let projection = cashProjection()
        if let shortfall = projection.firstContractedShortfall {
            score -= 15
            reasons.append("Projeção mostra falta de caixa no dia \(shortfall.matchDay + 1)")
        } else if projection.endingExpected > transferBudget {
            score += 8
            reasons.append("Projeção de caixa em alta nos próximos jogos")
        }
        if wageCap > 0 {
            let usage = Double(wageBill) / Double(wageCap)
            if usage > 0.95 { score -= 10; reasons.append("Folha em \(Int(usage * 100))% do teto") }
            else { reasons.append("Folha em \(Int(usage * 100))% do teto") }
        }
        if coachLoanOutstanding > 0 {
            reasons.append("Clube deve \(FootballFormat.money(coachLoanOutstanding)) ao treinador")
        }
        return BoardFront(title: "Financeira", score: clamp(score), reasons: reasons)
    }

    private func institutionalFront() -> BoardFront {
        var score = 40.0
        var reasons: [String] = []
        score += Double(fanMood - 50) * 0.4
        reasons.append("Humor da torcida em \(fanMood)")
        score += Double(coachImage - 40) * 0.3
        reasons.append("Imagem do treinador em \(coachImage)")
        score += Double(presidentBoardWeight) * 3
        if presidentBoardWeight != 0 { reasons.append("Relação com o presidente: \(presidentBoardWeight > 0 ? "+" : "")\(presidentBoardWeight)") }
        if world.social.crisis != nil { score -= 15; reasons.append("Crise de imagem em aberto") }
        let promisesBroken = commitments.filter { $0.state == .broken && worldDay - ($0.resolvedWorldDay ?? 0) <= 20 }.count
        if promisesBroken > 0 { score -= Double(promisesBroken) * 6; reasons.append("\(promisesBroken) compromisso(s) quebrado(s) recentemente") }
        if let meeting = boardMeetings.last(where: { $0.status == .conditionFailed && $0.season == season }) {
            score -= 10
            reasons.append("Condição da verba de \(FootballFormat.money(meeting.amount)) descumprida")
        }
        return BoardFront(title: "Institucional", score: clamp(score), reasons: reasons)
    }
}
