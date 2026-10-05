import Foundation

// MARK: - Negociação de contratação por etapas (TRF-04 / TRF-05 / TRF-06)

struct TransferTalk: Codable, Equatable, Identifiable {
    enum Stage: String, Codable {
        /// Proposta ao clube vendedor.
        case clubOffer
        /// O clube respondeu com o preço dele; vale até o prazo.
        case clubCounter
        /// Taxa acertada; falta combinar salário, duração e papel com o atleta.
        case personalTerms
        /// O atleta pediu outro salário; vale até o prazo.
        case playerCounter
        /// Tudo acertado; falta assinar.
        case agreed
        case signed, collapsed, expired

        var isOpen: Bool { ![.signed, .collapsed, .expired].contains(self) }
    }

    let id: Int
    let playerID: Int
    let sellerID: Int
    let season: Int
    let startedWorldDay: Int
    var stage: Stage = .clubOffer
    var fee = 0
    var installments = 1
    var wage = 0
    var years = 3
    var role: SquadStatus = .rotation
    var clubCounterFee: Int? = nil
    var playerCounterWage: Int? = nil
    var deadlineWorldDay: Int? = nil
    var commitmentID: Int? = nil
    var clubRefusals = 0
    var playerRefusals = 0
    var log: [String] = []
}

/// Custo total antes de assinar: o que sai agora, depois e por temporada.
struct TransferCostSummary: Equatable {
    let upfront: Int
    let laterInstallments: Int
    let wagePerSeason: Int
    let totalWages: Int
    let fitsBudget: Bool
    let fitsWageCap: Bool
    /// Menor saldo garantido no horizonte da projeção depois da entrada.
    let lowestProjectedCash: Int

    var total: Int { upfront + laterInstallments + totalWages }
}

enum TalkOutcome: Equatable {
    case accepted(String)
    case counter(String)
    case refused(String)
    case notAllowed(String)
}

extension FootballCareer {
    static let maxOpenTalks = 3
    static let counterValidityDays = 2
    static let maxRefusals = 3

    var transferTalks: [TransferTalk] { world.projects.transferTalks }
    var openTransferTalks: [TransferTalk] { world.projects.transferTalks.filter { $0.stage.isOpen } }
    func openTalk(forPlayer playerID: Int) -> TransferTalk? { world.projects.transferTalks.first { $0.playerID == playerID && $0.stage.isOpen } }

    func transferTalkBlocker(playerID: Int) -> String? {
        guard let athlete = player(playerID), let sellerID = athlete.teamID else { return "Atleta sem clube: contrate direto." }
        guard selectedClubID != nil, !isFired, liveMatch == nil else { return "Não é possível negociar agora." }
        if sellerID == selectedClubID { return "Este atleta já é seu." }
        if athlete.onLoan { return "Atleta emprestado: negocie com o clube dono." }
        if !isTransferWindowOpen { return "A janela de transferências está fechada." }
        if isTransferBanned { return "O clube está proibido de contratar (transfer ban)." }
        if openTalk(forPlayer: playerID) != nil { return "Já existe uma negociação aberta com este atleta." }
        if openTransferTalks.count >= Self.maxOpenTalks { return "No máximo \(Self.maxOpenTalks) negociações ao mesmo tempo." }
        if !sellerCanSell(athlete) { return "\(FootballSeason.teamName(sellerID)) não vende este atleta agora." }
        return nil
    }

    @discardableResult
    mutating func startTransferTalk(playerID: Int) -> TransferTalk? {
        guard transferTalkBlocker(playerID: playerID) == nil, let athlete = player(playerID), let sellerID = athlete.teamID else { return nil }
        let ask = joiningAsk(for: athlete)
        var talk = TransferTalk(id: world.projects.nextTalkID, playerID: playerID, sellerID: sellerID, season: season, startedWorldDay: worldDay)
        talk.wage = ask.wage
        talk.years = ask.years
        talk.role = ask.status
        talk.log.append("Consulta ao \(FootballSeason.teamName(sellerID)) por \(athlete.name).")
        world.projects.nextTalkID += 1
        world.projects.transferTalks.append(talk)
        return talk
    }

    private func talkIndex(_ id: Int) -> Int? { world.projects.transferTalks.firstIndex { $0.id == id && $0.stage.isOpen } }

    // MARK: Etapa 1 — clube vendedor

    @discardableResult
    mutating func proposeFee(talkID: Int, fee: Int, installments: Int = 1) -> TalkOutcome {
        guard let index = talkIndex(talkID), [.clubOffer, .clubCounter].contains(world.projects.transferTalks[index].stage),
              let athlete = player(world.projects.transferTalks[index].playerID) else { return .notAllowed("Esta negociação não aceita proposta agora.") }
        let parts = max(1, min(4, installments))
        if transferBudget < fee / parts { return .notAllowed("Caixa insuficiente para a entrada.") }
        let ask = askingPrice(for: athlete)
        let seller = FootballSeason.teamName(world.projects.transferTalks[index].sellerID)
        world.projects.transferTalks[index].installments = parts
        // Parcelar custa: o clube quer 3% a mais por parcela extra.
        let needed = Int(Double(ask) * (1 + 0.03 * Double(parts - 1)) / 10_000) * 10_000
        if fee >= needed {
            world.projects.transferTalks[index].fee = fee
            world.projects.transferTalks[index].stage = .personalTerms
            world.projects.transferTalks[index].clubCounterFee = nil
            closeTalkCommitment(index: index, as: .fulfilled)
            world.projects.transferTalks[index].log.append("\(seller) aceitou \(FootballFormat.money(fee)) em \(parts)x.")
            return .accepted("\(seller) aceitou a proposta. Agora combine salário, duração e papel com \(athlete.name).")
        }
        if Double(fee) >= Double(needed) * 0.85 {
            world.projects.transferTalks[index].stage = .clubCounter
            world.projects.transferTalks[index].clubCounterFee = needed
            setTalkDeadline(index: index, title: "Resposta ao \(seller) por \(athlete.name)",
                            detail: "O clube pede \(FootballFormat.money(needed)). Aceite antes do prazo ou a contraproposta cai.")
            world.projects.transferTalks[index].log.append("\(seller) pediu \(FootballFormat.money(needed)).")
            return .counter("\(seller) pede \(FootballFormat.money(needed)). A contraproposta vale \(Self.counterValidityDays) dias de jogo.")
        }
        world.projects.transferTalks[index].clubRefusals += 1
        world.projects.transferTalks[index].log.append("\(seller) recusou \(FootballFormat.money(fee)).")
        if world.projects.transferTalks[index].clubRefusals >= Self.maxRefusals {
            collapseTalk(index: index, reason: "\(seller) encerrou a conversa depois de \(Self.maxRefusals) propostas baixas.")
            return .refused("\(seller) cansou das propostas e encerrou a negociação.")
        }
        return .refused("\(seller) recusou: a proposta ficou longe do valor do atleta.")
    }

    @discardableResult
    mutating func acceptClubCounter(talkID: Int) -> TalkOutcome {
        guard let index = talkIndex(talkID), world.projects.transferTalks[index].stage == .clubCounter,
              let counter = world.projects.transferTalks[index].clubCounterFee else { return .notAllowed("Não há contraproposta do clube.") }
        return proposeFee(talkID: talkID, fee: counter, installments: world.projects.transferTalks[index].installments)
    }

    // MARK: Etapa 2 — atleta

    /// Salário que o atleta exige para o papel e a duração oferecidos.
    func wageNeeded(talk: TransferTalk, years: Int, role: SquadStatus) -> Int? {
        guard let athlete = player(talk.playerID) else { return nil }
        let ask = joiningAsk(for: athlete)
        let interest = topInterest(of: athlete)
        var factor = 1.0
        if role < ask.status {
            let gap = Double(ask.status.rawValue - role.rawValue)
            factor += (interest == .minutes ? 0.2 : 0.1) * gap
        } else if role > ask.status {
            factor -= 0.04 // papel maior compensa um pouco do salário
        }
        if abs(years - ask.years) > 1 { factor += interest == .loyalty && years > ask.years ? -0.03 : 0.05 }
        if interest == .money { factor += 0.05 }
        let trust = trust(of: athlete.id)
        if trust < 0 { factor += Double(-trust) / 300 }
        // Nunca abaixo do mínimo que a assinatura aceita.
        let needed = max(Double(ask.wage) * factor, Double(ask.wage) * 0.95)
        return Int((needed / 5_000).rounded(.up)) * 5_000
    }

    @discardableResult
    mutating func proposeTerms(talkID: Int, wage: Int, years: Int, role: SquadStatus) -> TalkOutcome {
        guard let index = talkIndex(talkID), [.personalTerms, .playerCounter].contains(world.projects.transferTalks[index].stage),
              let athlete = player(world.projects.transferTalks[index].playerID),
              let needed = wageNeeded(talk: world.projects.transferTalks[index], years: years, role: role) else {
            return .notAllowed("Combine a taxa com o clube antes.")
        }
        let ask = joiningAsk(for: athlete)
        if topInterest(of: athlete) == .minutes, ask.status >= .starter, role <= .backup {
            world.projects.transferTalks[index].playerRefusals += 1
            return .refused("\(athlete.name) não aceita chegar como \(role.title.lowercased()): quer jogar.")
        }
        world.projects.transferTalks[index].years = max(1, min(5, years))
        world.projects.transferTalks[index].role = role
        if wage >= needed {
            world.projects.transferTalks[index].wage = wage
            world.projects.transferTalks[index].stage = .agreed
            world.projects.transferTalks[index].playerCounterWage = nil
            closeTalkCommitment(index: index, as: .fulfilled)
            world.projects.transferTalks[index].log.append("\(athlete.name) aceitou \(FootballFormat.money(wage))/temporada por \(years) ano(s) como \(role.title.lowercased()).")
            return .accepted("\(athlete.name) aceitou. Confira o custo total e assine.")
        }
        if Double(wage) >= Double(needed) * 0.8 {
            world.projects.transferTalks[index].stage = .playerCounter
            world.projects.transferTalks[index].playerCounterWage = needed
            setTalkDeadline(index: index, title: "Resposta a \(athlete.name)",
                            detail: "O atleta pede \(FootballFormat.money(needed))/temporada. Aceite antes do prazo.")
            world.projects.transferTalks[index].log.append("\(athlete.name) pediu \(FootballFormat.money(needed)).")
            return .counter("\(athlete.name) pede \(FootballFormat.money(needed))/temporada para esse papel e duração.")
        }
        world.projects.transferTalks[index].playerRefusals += 1
        world.projects.transferTalks[index].log.append("\(athlete.name) recusou \(FootballFormat.money(wage)).")
        if world.projects.transferTalks[index].playerRefusals >= Self.maxRefusals {
            collapseTalk(index: index, reason: "\(athlete.name) desistiu depois de \(Self.maxRefusals) propostas ruins.")
            recordMemory(playerID: athlete.id, kind: .negotiationBroke, id: "talk-\(talkID)-collapsed")
            return .refused("\(athlete.name) desistiu da negociação.")
        }
        return .refused("\(athlete.name) recusou: o salário ficou muito abaixo do que espera.")
    }

    @discardableResult
    mutating func acceptPlayerCounter(talkID: Int) -> TalkOutcome {
        guard let index = talkIndex(talkID), world.projects.transferTalks[index].stage == .playerCounter,
              let counter = world.projects.transferTalks[index].playerCounterWage else { return .notAllowed("Não há contraproposta do atleta.") }
        let talk = world.projects.transferTalks[index]
        return proposeTerms(talkID: talkID, wage: counter, years: talk.years, role: talk.role)
    }

    // MARK: Etapa 3 — custo total e assinatura

    func costSummary(talkID: Int) -> TransferCostSummary? {
        guard let talk = world.projects.transferTalks.first(where: { $0.id == talkID }) else { return nil }
        let upfront = talk.fee / max(1, talk.installments)
        let later = talk.fee - upfront
        let lowest = projectionAfterSpending(upfront).lowestContracted - later
        return TransferCostSummary(upfront: upfront, laterInstallments: later, wagePerSeason: talk.wage, totalWages: talk.wage * talk.years,
                                   fitsBudget: transferBudget >= upfront, fitsWageCap: wageCapAllows(extra: talk.wage),
                                   lowestProjectedCash: lowest)
    }

    /// Assina usando o mesmo caminho das propostas diretas: nada é cobrado duas vezes.
    @discardableResult
    mutating func signTalk(talkID: Int) -> TalkOutcome {
        guard let index = talkIndex(talkID), world.projects.transferTalks[index].stage == .agreed else {
            return .notAllowed("Só dá para assinar com taxa e condições acertadas.")
        }
        let talk = world.projects.transferTalks[index]
        guard let summary = costSummary(talkID: talkID), summary.fitsBudget else { return .notAllowed("Caixa insuficiente para a entrada.") }
        guard summary.fitsWageCap else { return .notAllowed("A folha passaria do teto da diretoria.") }
        let bid = TransferBid(playerID: talk.playerID, fee: talk.fee, installments: talk.installments, wage: talk.wage, years: talk.years)
        let response = submitBid(bid)
        guard response == .accepted, let playerIndex = players.firstIndex(where: { $0.id == talk.playerID }) else {
            switch response {
            case .notAllowed(let reason), .clubRefuses(let reason): return .notAllowed(reason)
            case .playerRefuses: return .notAllowed("O atleta mudou de ideia sobre o salário.")
            case .counter: return .notAllowed("O clube mudou o preço; refaça a proposta.")
            case .accepted: return .notAllowed("A assinatura não foi concluída.")
            }
        }
        players[playerIndex].contract.status = talk.role
        world.projects.transferTalks[index].stage = .signed
        world.projects.transferTalks[index].log.append("Contrato assinado.")
        let name = players[playerIndex].name
        let factID = "talk-\(talkID)-signed"
        recordFact(WorldFact(id: factID, source: .negotiation, worldDay: worldDay, title: "\(name) assina com o \(FootballSeason.teamName(selectedClubID ?? 0))",
                             detail: "Taxa de \(FootballFormat.money(talk.fee)) em \(talk.installments)x, salário de \(FootballFormat.money(talk.wage))/temporada por \(talk.years) ano(s), chegando como \(talk.role.title.lowercased()).",
                             playerIDs: [talk.playerID], clubIDs: [talk.sellerID], reliability: .confirmed, isPublic: true,
                             effects: ["Entrada de \(FootballFormat.money(summary.upfront))", "Folha +\(FootballFormat.money(talk.wage))"]))
        deliverFact(factID, inbox: .transfer, social: true)
        return .accepted("\(name) é do clube.")
    }

    mutating func walkAwayFromTransferTalk(talkID: Int) {
        guard let index = talkIndex(talkID) else { return }
        collapseTalk(index: index, reason: "Você encerrou a negociação.")
    }

    // MARK: Calendário

    /// Contrapropostas vencidas expiram; janela fechada ou atleta vendido encerram a conversa. Uma vez por dia de jogo.
    mutating func progressTransferTalks() {
        for index in world.projects.transferTalks.indices where world.projects.transferTalks[index].stage.isOpen {
            let talk = world.projects.transferTalks[index]
            if player(talk.playerID)?.teamID != talk.sellerID {
                collapseTalk(index: index, reason: "O atleta saiu do \(FootballSeason.teamName(talk.sellerID)).")
            } else if !isTransferWindowOpen {
                collapseTalk(index: index, reason: "A janela fechou antes do acordo.")
            } else if let deadline = talk.deadlineWorldDay, worldDay >= deadline, [.clubCounter, .playerCounter].contains(talk.stage) {
                world.projects.transferTalks[index].stage = .expired
                world.projects.transferTalks[index].log.append("A contraproposta venceu sem resposta.")
                closeTalkCommitment(index: index, as: .expired)
            }
        }
        let closed = world.projects.transferTalks.filter { !$0.stage.isOpen }
        if closed.count > 12 {
            let keep = Set(closed.suffix(12).map(\.id))
            world.projects.transferTalks.removeAll { !$0.stage.isOpen && !keep.contains($0.id) }
        }
    }

    private mutating func setTalkDeadline(index: Int, title: String, detail: String) {
        closeTalkCommitment(index: index, as: .cancelled)
        let commitment = openCommitment(kind: .transferTalk, playerID: world.projects.transferTalks[index].playerID,
                                        days: Self.counterValidityDays, title: title, detail: detail)
        world.projects.transferTalks[index].commitmentID = commitment.id
        world.projects.transferTalks[index].deadlineWorldDay = commitment.deadlineWorldDay
    }

    private mutating func closeTalkCommitment(index: Int, as state: CommitmentState) {
        if let id = world.projects.transferTalks[index].commitmentID { resolveCommitment(id: id, as: state) }
        world.projects.transferTalks[index].commitmentID = nil
        world.projects.transferTalks[index].deadlineWorldDay = nil
    }

    private mutating func collapseTalk(index: Int, reason: String) {
        world.projects.transferTalks[index].stage = .collapsed
        world.projects.transferTalks[index].log.append(reason)
        closeTalkCommitment(index: index, as: .cancelled)
    }

    mutating func cancelTransferTalks() {
        for index in world.projects.transferTalks.indices where world.projects.transferTalks[index].stage.isOpen {
            collapseTalk(index: index, reason: "Encerrada com a saída do clube.")
        }
    }
}
