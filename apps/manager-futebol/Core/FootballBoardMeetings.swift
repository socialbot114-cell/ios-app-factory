import Foundation

// MARK: - Reunião de diretoria (F4-03 / CLB-02 / CLB-03)

/// O que o treinador leva à diretoria.
enum BoardRequestKind: String, Codable, CaseIterable, Identifiable {
    /// Verba extra agora, em troca de uma meta de curto prazo.
    case budgetBoost
    /// Meta da temporada menos ambiciosa, ao custo de confiança.
    case targetReview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .budgetBoost: return "Pedir verba extra"
        case .targetReview: return "Rever a meta da temporada"
        }
    }

    var pitch: String {
        switch self {
        case .budgetBoost: return "A diretoria libera dinheiro para reforços, mas cobra resultado nos jogos seguintes."
        case .targetReview: return "A meta fica mais realista até o fim da temporada, mas a diretoria passa a confiar menos em você."
        }
    }
}

enum BoardMeetingStatus: String, Codable {
    /// Pedido feito; a diretoria responde depois de alguns dias de jogo.
    case awaitingAnswer
    case rejected
    /// Aprovado com uma condição em andamento.
    case conditionRunning
    case conditionMet
    case conditionFailed
    /// Aprovado sem condição, ou encerrado por troca de clube.
    case closed
}

/// Meta de curto prazo cobrada em troca da verba: vitórias mínimas num bloco de jogos do clube.
struct BoardCondition: Codable, Equatable {
    let games: Int
    let winsNeeded: Int
    /// Primeiro dia de jogo que conta: o seguinte à aprovação.
    let startMatchDay: Int
    var gamesCounted = 0
    var winsCounted = 0
    /// Partidas já contadas, para nunca contar o mesmo jogo duas vezes.
    var countedFixtureIDs: [Int] = []

    var isComplete: Bool { gamesCounted >= games }
    var text: String { "Vencer \(winsNeeded) dos próximos \(games) jogos (\(winsCounted)/\(winsNeeded) vitórias em \(gamesCounted)/\(games) jogos)" }
}

struct BoardMeeting: Codable, Equatable, Identifiable {
    let id: Int
    let clubID: Int
    let kind: BoardRequestKind
    let season: Int
    let requestedWorldDay: Int
    let answerWorldDay: Int
    var status: BoardMeetingStatus = .awaitingAnswer
    var amount = 0
    var condition: BoardCondition? = nil
    var answer = ""
    var resolution = ""

    var isOpen: Bool { status == .awaitingAnswer || status == .conditionRunning }
}

struct ProjectsState: Codable, Equatable {
    var meetings: [BoardMeeting] = []
    var nextMeetingID = 1
    /// Agenda pessoal do treinador (F4-04).
    var personalPlan: [PlannedActivity] = []
    var nextPlanID = 1
    /// Último dia em que um aporte do treinador rendeu confiança (F4-06).
    var lastLoanBonusWorldDay = -1
    /// Aportes do treinador com devolução (BAN-05).
    var coachLoans: [CoachLoan] = []
    var nextLoanID = 1
    /// Disputas com clubes rivais por atletas observados (F3-05).
    var transferRaces: [TransferRace] = []
    var nextRaceID = 1
    /// Briefings, listas comparativas e relatórios (TRF-01/02/03).
    var recruitment = RecruitmentState()
    /// Negociações de contratação por etapas (TRF-04/05/06).
    var transferTalks: [TransferTalk] = []
    var nextTalkID = 1
    /// Histórico, pedidos e promessas dos contatos (CON-02…06).
    var contactRelations = ContactRelationsState()
    /// Continuidade da vida pessoal e histórico de bem-estar (VID-02…06).
    var life = LifeState()
    /// Campanhas com briefing, contrato de imagem e evolução da marca (MAR-01…05).
    var brand = BrandState()
    /// Plano por etapas da obra em curso (CLB-04).
    var construction: ConstructionPlan? = nil
    /// Extrato da conta pessoal do treinador (BAN-01).
    var personalLedger = PersonalLedgerState()

    init() {}

    private enum CodingKeys: String, CodingKey { case meetings, nextMeetingID, personalPlan, nextPlanID, lastLoanBonusWorldDay, coachLoans, nextLoanID, transferRaces, nextRaceID, recruitment, transferTalks, nextTalkID, contactRelations, life, brand, construction, personalLedger }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meetings = try container.decodeIfPresent([BoardMeeting].self, forKey: .meetings) ?? []
        nextMeetingID = try container.decodeIfPresent(Int.self, forKey: .nextMeetingID) ?? 1
        personalPlan = try container.decodeIfPresent([PlannedActivity].self, forKey: .personalPlan) ?? []
        nextPlanID = try container.decodeIfPresent(Int.self, forKey: .nextPlanID) ?? 1
        lastLoanBonusWorldDay = try container.decodeIfPresent(Int.self, forKey: .lastLoanBonusWorldDay) ?? -1
        coachLoans = try container.decodeIfPresent([CoachLoan].self, forKey: .coachLoans) ?? []
        nextLoanID = try container.decodeIfPresent(Int.self, forKey: .nextLoanID) ?? 1
        transferRaces = try container.decodeIfPresent([TransferRace].self, forKey: .transferRaces) ?? []
        nextRaceID = try container.decodeIfPresent(Int.self, forKey: .nextRaceID) ?? 1
        recruitment = try container.decodeIfPresent(RecruitmentState.self, forKey: .recruitment) ?? RecruitmentState()
        transferTalks = try container.decodeIfPresent([TransferTalk].self, forKey: .transferTalks) ?? []
        nextTalkID = try container.decodeIfPresent(Int.self, forKey: .nextTalkID) ?? 1
        contactRelations = try container.decodeIfPresent(ContactRelationsState.self, forKey: .contactRelations) ?? ContactRelationsState()
        life = try container.decodeIfPresent(LifeState.self, forKey: .life) ?? LifeState()
        brand = try container.decodeIfPresent(BrandState.self, forKey: .brand) ?? BrandState()
        construction = try container.decodeIfPresent(ConstructionPlan.self, forKey: .construction)
        personalLedger = try container.decodeIfPresent(PersonalLedgerState.self, forKey: .personalLedger) ?? PersonalLedgerState()
    }
}

extension FootballCareer {
    static let boardAnswerDelay = 2
    static let boardMeetingCooldown = 8
    static let boardHistoryLimit = 20

    var boardMeetings: [BoardMeeting] { world.projects.meetings }
    var openBoardMeeting: BoardMeeting? { world.projects.meetings.last { $0.isOpen && $0.clubID == selectedClubID } }

    /// Verba que a diretoria considera liberar: 8% do orçamento inicial do clube, em múltiplos de 50 mil.
    var boardBoostAmount: Int {
        guard let club = selectedClub else { return 0 }
        return max(50_000, Int(Double(club.startingBudget) * 0.08 / 50_000) * 50_000)
    }

    /// Motivo pelo qual não é possível marcar reunião agora; nil quando pode.
    func boardMeetingBlocker(_ kind: BoardRequestKind) -> String? {
        guard let selectedClubID, !isFired else { return "Você está sem clube." }
        if openBoardMeeting != nil { return "Já existe um assunto em aberto com a diretoria." }
        if let last = world.projects.meetings.last(where: { $0.clubID == selectedClubID }),
           worldDay - last.requestedWorldDay < Self.boardMeetingCooldown {
            return "A diretoria só recebe um novo pedido \(Self.boardMeetingCooldown) dias de jogo depois do anterior."
        }
        let remaining = FootballSeason.matchDaysPerSeason - matchDayIndex
        if remaining <= Self.boardAnswerDelay + 1 { return "A temporada está no fim; leve o pedido na próxima." }
        switch kind {
        case .budgetBoost:
            if world.projects.meetings.contains(where: { $0.clubID == selectedClubID && $0.season == season && $0.kind == .budgetBoost && $0.status != .rejected }) {
                return "A verba extra desta temporada já foi concedida."
            }
        case .targetReview:
            if matchDayIndex > FootballSeason.matchDaysPerSeason / 2 { return "A meta só pode ser revista na primeira metade da temporada." }
            if boardTarget >= teamsInUserDivision { return "A meta já é a mais modesta possível." }
            if world.projects.meetings.contains(where: { $0.clubID == selectedClubID && $0.season == season && $0.kind == .targetReview && $0.status != .rejected }) {
                return "A meta desta temporada já foi revista."
            }
        }
        return nil
    }

    private var teamsInUserDivision: Int {
        guard let division = userDivision else { return 20 }
        return divisionOfTeam.filter { $0 == division }.count
    }

    /// Clima da diretoria antes do pedido: dá contexto sem revelar o sorteio.
    func boardMood(for kind: BoardRequestKind) -> String {
        let score = boardScore(kind, noise: 0)
        if score >= 70 { return "Diretoria receptiva" }
        if score >= 55 { return "Diretoria dividida" }
        return "Diretoria resistente"
    }

    /// Pontuação da diretoria: confiança, saúde do caixa projetado, reputação e pedidos já feitos.
    func boardScore(_ kind: BoardRequestKind, noise: Int) -> Int {
        var score = Double(boardConfidence)
        let projection = cashProjection()
        if projection.firstContractedShortfall != nil { score -= 15 } else if projection.endingExpected > transferBudget { score += 8 }
        score += Double(reputation - 50) / 5
        score += Double(presidentBoardWeight) // relação com o presidente (CON-05)
        let earlier = world.projects.meetings.filter { $0.clubID == selectedClubID && $0.season == season }.count
        score -= Double(earlier) * 8
        if kind == .targetReview { score -= 5 }
        return Int(score.rounded()) + noise
    }

    /// Marca a reunião; a resposta chega em `boardAnswerDelay` dias de jogo.
    @discardableResult
    mutating func requestBoardMeeting(_ kind: BoardRequestKind) -> Bool {
        guard boardMeetingBlocker(kind) == nil, let selectedClubID else { return false }
        let meeting = BoardMeeting(id: world.projects.nextMeetingID, clubID: selectedClubID, kind: kind, season: season,
                                   requestedWorldDay: worldDay, answerWorldDay: worldDay + Self.boardAnswerDelay)
        world.projects.nextMeetingID += 1
        world.projects.meetings.append(meeting)
        addInbox(.board, title: "Reunião marcada", body: "Pedido levado à diretoria: \(kind.title.lowercased()). A resposta sai em \(Self.boardAnswerDelay) dias de jogo.")
        return true
    }

    /// Avança respostas e condições. Chamado uma vez por dia de jogo concluído.
    mutating func progressBoardMeetings() {
        for index in world.projects.meetings.indices where world.projects.meetings[index].isOpen {
            let meeting = world.projects.meetings[index]
            guard meeting.clubID == selectedClubID, !isFired else {
                world.projects.meetings[index].status = .closed
                world.projects.meetings[index].resolution = "Encerrado com a saída do clube."
                continue
            }
            if meeting.status == .awaitingAnswer, worldDay >= meeting.answerWorldDay {
                answerBoardMeeting(at: index)
            } else if meeting.status == .conditionRunning {
                countBoardCondition(at: index)
            }
        }
        if world.projects.meetings.count > Self.boardHistoryLimit {
            let closed = world.projects.meetings.filter { !$0.isOpen }
            let keep = Set(closed.suffix(Self.boardHistoryLimit).map(\.id))
            world.projects.meetings.removeAll { !$0.isOpen && !keep.contains($0.id) }
        }
    }

    private mutating func answerBoardMeeting(at index: Int) {
        let meeting = world.projects.meetings[index]
        var random = FootballRandom(seed: matchSeed(stream: .world, id: 90_000 + meeting.id))
        let approved = boardScore(meeting.kind, noise: random.int(in: -10...10)) >= 60
        guard approved else {
            world.projects.meetings[index].status = .rejected
            world.projects.meetings[index].answer = "A diretoria negou o pedido: confiança e finanças não sustentam a mudança agora."
            boardConfidence = max(0, boardConfidence - 2)
            addInbox(.board, title: "Diretoria negou o pedido", body: world.projects.meetings[index].answer + " Confiança -2.")
            return
        }
        switch meeting.kind {
        case .budgetBoost:
            let amount = boardBoostAmount
            let condition = BoardCondition(games: 6, winsNeeded: 3, startMatchDay: matchDayIndex)
            world.projects.meetings[index].amount = amount
            world.projects.meetings[index].condition = condition
            world.projects.meetings[index].status = .conditionRunning
            world.projects.meetings[index].answer = "Verba de \(FootballFormat.money(amount)) aprovada. Condição: vencer \(condition.winsNeeded) dos próximos \(condition.games) jogos."
            book(.other, amount, "Verba extra da diretoria")
            linkLastFinanceEntry(note: "Verba extra da diretoria", FinanceLink(kind: .meeting, id: "\(meeting.id)", title: "Reunião com a diretoria"))
            addInbox(.board, title: "Verba aprovada", body: world.projects.meetings[index].answer + " Cumprir rende confiança +4; falhar custa confiança -10.")
        case .targetReview:
            let old = boardTarget
            boardTarget = min(teamsInUserDivision, boardTarget + 2)
            boardConfidence = max(0, boardConfidence - 6)
            world.projects.meetings[index].status = .closed
            world.projects.meetings[index].answer = "Meta revista de \(old)º para \(boardTarget)º lugar até o fim da temporada."
            world.projects.meetings[index].resolution = "Confiança -6 pela revisão."
            addInbox(.board, title: "Meta revista", body: world.projects.meetings[index].answer + " Confiança -6.")
        }
    }

    /// Conta as partidas do clube jogadas depois da aprovação, uma única vez cada.
    private mutating func countBoardCondition(at index: Int) {
        guard let clubID = selectedClubID, var condition = world.projects.meetings[index].condition else { return }
        guard world.projects.meetings[index].season == season else { return }
        let played = fixtures
            .filter { $0.involves(clubID) && $0.isPlayed && $0.matchDay >= condition.startMatchDay }
            .sorted { $0.matchDay < $1.matchDay }
        for fixture in played where !condition.countedFixtureIDs.contains(fixture.id) && !condition.isComplete {
            condition.countedFixtureIDs.append(fixture.id)
            condition.gamesCounted += 1
            if fixture.result(for: clubID) == .win { condition.winsCounted += 1 }
        }
        world.projects.meetings[index].condition = condition
        if condition.isComplete { settleBoardCondition(at: index, partial: false) }
    }

    private mutating func settleBoardCondition(at index: Int, partial: Bool) {
        guard let condition = world.projects.meetings[index].condition else { return }
        // Na virada de temporada, a exigência é proporcional aos jogos disputados.
        let needed = partial && condition.games > 0
            ? Int((Double(condition.winsNeeded) * Double(condition.gamesCounted) / Double(condition.games)).rounded(.up))
            : condition.winsNeeded
        let met = condition.winsCounted >= needed
        world.projects.meetings[index].status = met ? .conditionMet : .conditionFailed
        boardConfidence = met ? min(100, boardConfidence + 4) : max(0, boardConfidence - 10)
        let summary = "\(condition.winsCounted) vitória(s) em \(condition.gamesCounted) jogo(s)"
        world.projects.meetings[index].resolution = met ? "Condição cumprida: \(summary). Confiança +4." : "Condição descumprida: \(summary). Confiança -10."
        addInbox(.board, title: met ? "Diretoria satisfeita" : "Diretoria cobra o combinado", body: world.projects.meetings[index].resolution)
    }

    /// Fecha os assuntos da temporada. Deve rodar antes de o calendário novo ser montado ou com o progresso já contado.
    mutating func closeBoardSeason() {
        for index in world.projects.meetings.indices where world.projects.meetings[index].isOpen {
            switch world.projects.meetings[index].status {
            case .conditionRunning:
                settleBoardCondition(at: index, partial: true)
            case .awaitingAnswer:
                world.projects.meetings[index].status = .closed
                world.projects.meetings[index].resolution = "Pedido arquivado na virada da temporada."
            default:
                break
            }
        }
    }
}
