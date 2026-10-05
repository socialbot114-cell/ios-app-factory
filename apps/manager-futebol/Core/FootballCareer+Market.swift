import Foundation

extension FootballCareer {
    static let squadSize = 16
    static let positionMinimums: [FootballPosition: Int] = [.goalkeeper: 2, .defender: 5, .midfielder: 5, .forward: 4]
    /// Mínimo por posição que um clube precisa manter depois de vender alguém.
    static let positionFloors: [FootballPosition: Int] = [.goalkeeper: 2, .defender: 4, .midfielder: 4, .forward: 3]

    // MARK: - Janelas de transferência

    var transferWindow: TransferWindow? {
        guard !isSeasonComplete else { return nil }
        let day = matchDayIndex
        if (TransferWindow.preseason.start...TransferWindow.preseason.end).contains(day) {
            return TransferWindow(kind: .preseason, startDay: TransferWindow.preseason.start, endDay: TransferWindow.preseason.end, currentDay: day)
        }
        if (TransferWindow.midseason.start...TransferWindow.midseason.end).contains(day) {
            return TransferWindow(kind: .midseason, startDay: TransferWindow.midseason.start, endDay: TransferWindow.midseason.end, currentDay: day)
        }
        return nil
    }

    var isTransferWindowOpen: Bool { transferWindow != nil }

    // MARK: - Preços e disposição dos clubes

    /// Posição do atleta no elenco do próprio clube (0 é o melhor).
    func squadRank(of player: FootballPlayer) -> Int {
        guard let teamID = player.teamID else { return 99 }
        return players(forTeam: teamID).sorted { $0.overall > $1.overall }.firstIndex { $0.id == player.id } ?? 99
    }

    /// Preço pedido por um atleta de outro clube: valor × importância no elenco × situação do contrato.
    func askingPrice(for player: FootballPlayer) -> Int {
        guard player.teamID != nil, player.teamID != selectedClubID else { return player.marketValue }
        let rank = squadRank(of: player)
        var factor = rank < 3 ? 1.7 : (rank < 11 ? 1.3 : 1.0)
        if player.contract.endSeason != 0 && player.contract.endSeason <= season { factor *= 0.7 }
        if player.age >= 33 { factor *= 0.8 }
        if player.potential - player.overall >= 10 && player.age <= 21 { factor *= 1.15 }
        factor *= 1 - agentDiscount
        return Int((Double(player.marketValue) * factor * difficulty.priceFactor) / 10_000) * 10_000
    }

    func positionCount(teamID: Int, position: FootballPosition) -> Int {
        players.filter { $0.teamID == teamID && !$0.isYouth && $0.position == position }.count
    }

    /// O clube vendedor mantém o elenco mínimo e as posições essenciais.
    func sellerCanSell(_ player: FootballPlayer) -> Bool {
        guard let teamID = player.teamID else { return false }
        let squad = players.filter { $0.teamID == teamID && !$0.isYouth }
        let samePosition = squad.filter { $0.position == player.position }.count
        return squad.count > 14 && samePosition > (Self.positionFloors[player.position] ?? 3)
    }

    /// Pedido de salário e papel no elenco para quem chega de fora.
    func joiningAsk(for player: FootballPlayer) -> ContractAsk {
        let ranking = clubRoster.filter { $0.overall > player.overall }.count
        let status: SquadStatus
        switch ranking {
        case 0...2: status = .key
        case 3...10: status = .starter
        case 11...14: status = .rotation
        default: status = .backup
        }
        var wage = Double(PlayerContract.wage(forValue: player.marketValue)) * status.wageFactor
        if player.age >= 33 { wage *= 0.9 }
        let years = player.age <= 24 ? 4 : (player.age <= 29 ? 3 : (player.age <= 32 ? 2 : 1))
        return ContractAsk(wage: Int((wage / 5_000).rounded()) * 5_000, years: years, status: status)
    }

    // MARK: - Propostas a clubes da IA

    func evaluateBid(_ bid: TransferBid) -> BidResponse {
        guard let player = player(bid.playerID) else { return .notAllowed("Atleta inexistente.") }
        guard selectedClubID != nil, !isFired, liveMatch == nil else { return .notAllowed("Não é possível negociar agora.") }
        guard player.teamID != nil, player.teamID != selectedClubID else { return .notAllowed("Este atleta já está no seu clube ou está sem clube.") }
        guard !player.onLoan else { return .notAllowed("Atleta emprestado: negocie a compra com o clube dono.") }
        guard isTransferWindowOpen else { return .notAllowed("A janela de transferências está fechada.") }
        guard !isTransferBanned else { return .notAllowed("O clube está proibido de contratar por causa da dívida (transfer ban).") }
        guard clubRoster.count < Self.rosterLimit || bid.swapPlayerID != nil else { return .notAllowed("Elenco completo.") }
        guard sellerCanSell(player) else { return .clubRefuses("\(FootballSeason.teamName(player.teamID ?? 0)) não vende: precisa deste atleta para manter o elenco.") }

        var swapValue = 0
        if let swapID = bid.swapPlayerID {
            guard let swap = self.player(swapID), swap.teamID == selectedClubID, canRelease(playerID: swapID) else {
                return .notAllowed("O atleta oferecido na troca não pode sair.")
            }
            swapValue = Int(Double(swap.marketValue) * 0.9)
        }
        let ask = askingPrice(for: player)
        let effective = bid.fee + swapValue + Int(Double(bid.goalBonus) * 0.5)
        let upfront = bid.fee / max(1, bid.installments)
        if transferBudget < upfront { return .notAllowed("Caixa insuficiente para a entrada.") }

        if effective < Int(Double(ask) * 0.85) {
            return .clubRefuses("\(FootballSeason.teamName(player.teamID ?? 0)) recusou: pede cerca de \(FootballFormat.money(ask)).")
        }
        if effective < ask {
            let missing = ask - swapValue - Int(Double(bid.goalBonus) * 0.5)
            return .counter(fee: max(0, Int((Double(missing + bid.fee) / 2 / 10_000).rounded(.up)) * 10_000))
        }
        let personal = joiningAsk(for: player)
        let incomingWage = bid.wage
        if !wageCapAllows(extra: incomingWage - (bid.swapPlayerID.flatMap { self.player($0)?.contract.wage } ?? 0)) {
            return .notAllowed("A folha salarial passaria do teto definido pela diretoria.")
        }
        if Double(bid.wage) < Double(personal.wage) * 0.95 {
            return .playerRefuses(askWage: personal.wage)
        }
        return .accepted
    }

    @discardableResult
    mutating func submitBid(_ bid: TransferBid) -> BidResponse {
        let response = evaluateBid(bid)
        guard response == .accepted, let selectedClubID,
              let index = players.firstIndex(where: { $0.id == bid.playerID }), let sellerID = players[index].teamID else { return response }
        let name = players[index].name
        let upfront = bid.fee / max(1, bid.installments)
        book(.playerPurchases, -upfront, "Entrada por \(name)")
        if bid.installments > 1 {
            let installment = (bid.fee - upfront) / (bid.installments - 1)
            for step in 1..<bid.installments {
                pendingPayments.append(PendingPayment(id: nextPaymentID, amount: installment, dueMatchDay: matchDayIndex + step * 2,
                                                      season: season, note: "Parcela \(step + 1)/\(bid.installments) por \(name)"))
                nextPaymentID += 1
            }
        }
        if bid.goalBonus > 0 {
            goalBonuses.append(GoalBonus(id: nextPaymentID, playerID: bid.playerID, clubID: sellerID, goals: 10, amount: bid.goalBonus, season: season))
            nextPaymentID += 1
        }
        let status = joiningAsk(for: players[index]).status
        players[index].teamID = selectedClubID
        players[index].contract = PlayerContract(wage: bid.wage, endSeason: season + max(1, bid.years) - 1, status: status)
        players[index].morale = 72
        players[index].benchStreak = 0
        players[index].form = PlayerForm()
        players[index].isListed = false
        scoutKnowledge[bid.playerID] = nil
        bump("signings")
        logTransfer(playerID: bid.playerID, name: name, from: sellerID, to: selectedClubID, fee: bid.fee)

        if let swapID = bid.swapPlayerID, let swapIndex = players.firstIndex(where: { $0.id == swapID }) {
            players[swapIndex].teamID = sellerID
            players[swapIndex].isListed = false
            players[swapIndex].morale = 60
            offers.removeAll { $0.playerID == swapID }
            logTransfer(playerID: swapID, name: players[swapIndex].name, from: selectedClubID, to: sellerID, fee: 0)
        }
        var random = FootballRandom(seed: matchSeed(stream: .transfers, id: 500 + bid.playerID))
        normalizeSquad(teamID: sellerID, using: &random)
        repairLineup()
        return .accepted
    }

    mutating func logTransfer(playerID: Int, name: String, from: Int?, to: Int?, fee: Int, isLoan: Bool = false) {
        transferLog.append(TransferRecord(id: nextTransferID, season: season, matchDay: matchDayIndex, playerName: name, playerID: playerID,
                                          fromClubID: from, toClubID: to, fee: fee, isLoan: isLoan))
        nextTransferID += 1
        if transferLog.count > 80 { transferLog.removeFirst(transferLog.count - 80) }
    }

    // MARK: - Dispensa e venda

    /// O clube consegue abrir mão do atleta sem perder o elenco mínimo nem a formação.
    func canRelease(playerID: Int) -> Bool {
        guard let selectedClubID, liveMatch == nil, !isFired,
              let player = player(playerID), player.teamID == selectedClubID else { return false }
        if player.isYouth { return true }
        guard clubRoster.count > Self.minimumRoster else { return false }
        let remaining = clubRoster.filter { $0.id != playerID }
        let healthyCount = remaining.filter { !$0.isInjured && !$0.isYouth }.count
        return healthyCount >= 11 && FootballSeason.canFill(roster: remaining.map { member in
            var healthy = member
            healthy.injuryRounds = 0
            return healthy
        }, formation: formation)
    }

    mutating func setListed(playerID: Int, listed: Bool, loan: Bool = false) {
        guard let index = players.firstIndex(where: { $0.id == playerID }), players[index].teamID == selectedClubID else { return }
        if loan { players[index].isLoanListed = listed } else { players[index].isListed = listed }
    }

    // MARK: - Empréstimos

    func loanFee(for player: FootballPlayer) -> Int { Int(Double(player.marketValue) * 0.08 / 10_000) * 10_000 }

    func canLoanIn(playerID: Int) -> String? {
        guard let player = player(playerID), let teamID = player.teamID, teamID != selectedClubID, !player.onLoan else { return "Atleta indisponível." }
        guard !isFired, liveMatch == nil, isTransferWindowOpen else { return "A janela de transferências está fechada." }
        guard !isTransferBanned else { return "O clube está proibido de contratar por causa da dívida (transfer ban)." }
        guard clubRoster.count < Self.rosterLimit else { return "Elenco completo." }
        guard sellerCanSell(player) else { return "O clube não empresta este atleta agora." }
        guard squadRank(of: player) >= 4 else { return "O clube não empresta uma de suas estrelas." }
        guard transferBudget >= loanFee(for: player) else { return "Caixa insuficiente." }
        guard wageCapAllows(extra: player.contract.wage) else { return "A folha salarial passaria do teto." }
        return nil
    }

    @discardableResult
    mutating func loanIn(playerID: Int) -> Bool {
        guard canLoanIn(playerID: playerID) == nil, let selectedClubID,
              let index = players.firstIndex(where: { $0.id == playerID }), let owner = players[index].teamID else { return false }
        let fee = loanFee(for: players[index])
        let option = Int(Double(askingPrice(for: players[index])) * 1.1 / 10_000) * 10_000
        book(.loans, -fee, "Empréstimo de \(players[index].name)")
        players[index].parentTeamID = owner
        players[index].teamID = selectedClubID
        players[index].purchaseOption = option
        players[index].contract.endSeason = season
        players[index].contract.status = joiningAsk(for: players[index]).status
        players[index].morale = 70
        logTransfer(playerID: playerID, name: players[index].name, from: owner, to: selectedClubID, fee: fee, isLoan: true)
        var random = FootballRandom(seed: matchSeed(stream: .transfers, id: 600 + playerID))
        normalizeSquad(teamID: owner, using: &random)
        return true
    }

    func canBuyOutLoan(playerID: Int) -> Bool {
        guard let player = player(playerID), player.teamID == selectedClubID, player.onLoan, let option = player.purchaseOption else { return false }
        return transferBudget >= option && !isFired
    }

    @discardableResult
    mutating func buyOutLoan(playerID: Int) -> Bool {
        guard canBuyOutLoan(playerID: playerID), let index = players.firstIndex(where: { $0.id == playerID }),
              let option = players[index].purchaseOption else { return false }
        book(.playerPurchases, -option, "Compra de \(players[index].name) após o empréstimo")
        players[index].parentTeamID = nil
        players[index].purchaseOption = nil
        players[index].contract.endSeason = season + 2
        return true
    }

    /// Destinos possíveis para emprestar um atleta do clube.
    func loanDestinations(for player: FootballPlayer) -> [LeagueTeam] {
        FootballSeason.teams.filter { team in
            team.id != selectedClubID && positionCount(teamID: team.id, position: player.position) < (Self.positionMinimums[player.position] ?? 3) + 2
        }
    }

    @discardableResult
    mutating func loanOut(playerID: Int, to clubID: Int) -> Bool {
        guard isTransferWindowOpen, canRelease(playerID: playerID), clubID != selectedClubID,
              let index = players.firstIndex(where: { $0.id == playerID }), !players[index].onLoan else { return false }
        let fee = Int(Double(players[index].marketValue) * 0.05 / 10_000) * 10_000
        book(.loans, fee, "Empréstimo de \(players[index].name) ao \(FootballSeason.teamName(clubID))")
        players[index].parentTeamID = selectedClubID
        players[index].teamID = clubID
        players[index].isListed = false
        players[index].isLoanListed = false
        offers.removeAll { $0.playerID == playerID }
        logTransfer(playerID: playerID, name: players[index].name, from: selectedClubID, to: clubID, fee: fee, isLoan: true)
        var random = FootballRandom(seed: matchSeed(stream: .transfers, id: 700 + playerID))
        normalizeSquad(teamID: clubID, using: &random)
        repairLineup()
        return true
    }

    /// Fim da temporada: todos os empréstimos terminam. Jovens que jogaram voltam melhores.
    mutating func returnLoans(using random: inout FootballRandom) {
        for index in players.indices {
            guard let owner = players[index].parentTeamID else { continue }
            let wasOutLoan = owner == selectedClubID
            if wasOutLoan && players[index].age <= 23 && players[index].overall < players[index].potential && random.chance(0.55) {
                players[index].setOverall(players[index].overall + random.int(in: 1...2))
            }
            players[index].teamID = owner
            players[index].parentTeamID = nil
            players[index].purchaseOption = nil
        }
    }

    // MARK: - Propostas recebidas

    mutating func generateOffers(using random: inout FootballRandom) {
        guard let selectedClubID, let window = transferWindow else { return }
        let capacity = window.isLastDay ? 4 : 2
        guard offers.count < capacity else { return }
        let base = 0.3 * (window.isLastDay ? 2.2 : 1.0)
        let available = clubRoster.filter { candidate in !candidate.onLoan && !offers.contains { $0.playerID == candidate.id } }

        let listed = available.filter(\.isListed)
        if !listed.isEmpty, random.chance(min(0.9, base * 2.5)), let target = random.pick(listed) {
            appendOffer(for: target, multiplier: Double(random.int(in: 100...135)) / 100, kind: .purchase, using: &random)
            return
        }
        let loanListed = available.filter(\.isLoanListed)
        if !loanListed.isEmpty, random.chance(0.35), let target = random.pick(loanListed) {
            appendOffer(for: target, multiplier: 0.05, kind: .loan, using: &random)
            return
        }
        guard random.chance(base) else { return }
        let candidates = available.sorted { $0.marketValue > $1.marketValue }.prefix(8)
        guard let target = random.pick(Array(candidates)) else { return }
        _ = selectedClubID
        appendOffer(for: target, multiplier: Double(random.int(in: 95...125)) / 100, kind: .purchase, using: &random)
    }

    private mutating func appendOffer(for target: FootballPlayer, multiplier: Double, kind: OfferKind, using random: inout FootballRandom) {
        guard let selectedClubID else { return }
        let buyers = FootballSeason.teams.filter { $0.id != selectedClubID && $0.startingBudget >= target.marketValue / 2 }
        guard let buyer = random.pick(buyers) else { return }
        let amount = Int(Double(target.marketValue) * multiplier / 10_000) * 10_000
        offers.append(TransferOffer(id: nextOfferID, playerID: target.id, clubID: buyer.id, amount: max(amount, 50_000),
                                    expiresAfterRound: matchDayIndex + 2, kind: kind))
        nextOfferID += 1
    }

    /// Aceita um empréstimo pedido por outro clube.
    @discardableResult
    mutating func acceptLoanOffer(_ offerID: Int) -> Bool {
        guard let offer = offers.first(where: { $0.id == offerID }), offer.kind == .loan, isTransferWindowOpen,
              canRelease(playerID: offer.playerID), let index = players.firstIndex(where: { $0.id == offer.playerID }) else { return false }
        book(.loans, offer.amount, "Empréstimo de \(players[index].name) ao \(FootballSeason.teamName(offer.clubID))")
        players[index].parentTeamID = selectedClubID
        players[index].teamID = offer.clubID
        players[index].isLoanListed = false
        players[index].isListed = false
        logTransfer(playerID: offer.playerID, name: players[index].name, from: selectedClubID, to: offer.clubID, fee: offer.amount, isLoan: true)
        offers.removeAll { $0.id == offerID || $0.playerID == offer.playerID }
        var random = FootballRandom(seed: matchSeed(stream: .transfers, id: 800 + offer.playerID))
        normalizeSquad(teamID: offer.clubID, using: &random)
        repairLineup()
        return true
    }

    // MARK: - Pagamentos pendentes e bônus

    mutating func settlePendingPayments() {
        var remaining: [PendingPayment] = []
        for payment in pendingPayments {
            if payment.dueMatchDay <= matchDayIndex { book(.playerPurchases, -payment.amount, payment.note) } else { remaining.append(payment) }
        }
        pendingPayments = remaining
        var open: [GoalBonus] = []
        for bonus in goalBonuses {
            if let athlete = player(bonus.playerID), athlete.goals >= bonus.goals, athlete.teamID == selectedClubID {
                book(.playerPurchases, -bonus.amount, "Bônus por gols de \(athlete.name) ao \(FootballSeason.teamName(bonus.clubID))")
            } else {
                open.append(bonus)
            }
        }
        goalBonuses = open
    }

    // MARK: - IA ativa no mercado

    /// Mantém o elenco de um clube da IA com 16 atletas e pelo menos o mínimo em cada posição.
    mutating func normalizeSquad(teamID: Int, using random: inout FootballRandom) {
        guard teamID != selectedClubID, FootballSeason.team(teamID) != nil else { return }
        func squadIndices() -> [Int] { players.indices.filter { players[$0].teamID == teamID && !players[$0].isYouth } }
        var indices = squadIndices()
        while indices.count > Self.squadSize {
            var counts: [FootballPosition: Int] = [:]
            for index in indices { counts[players[index].position, default: 0] += 1 }
            let victims = indices.filter { index in
                players[index].parentTeamID == nil && counts[players[index].position, default: 0] > (Self.positionMinimums[players[index].position] ?? 3)
            }
            guard let victim = victims.min(by: { players[$0].marketValue < players[$1].marketValue }) else { break }
            players[victim].teamID = nil
            players[victim].contract.endSeason = 0
            indices = squadIndices()
        }
        while indices.count < Self.squadSize {
            var counts: [FootballPosition: Int] = [:]
            for index in indices { counts[players[index].position, default: 0] += 1 }
            let position = FootballPosition.allCases.min {
                Double(counts[$0, default: 0]) / Double(Self.positionMinimums[$0] ?? 1) < Double(counts[$1, default: 0]) / Double(Self.positionMinimums[$1] ?? 1)
            } ?? .midfielder
            if let free = players.indices.filter({ players[$0].teamID == nil && players[$0].position == position && !players[$0].isYouth })
                .max(by: { players[$0].overall < players[$1].overall }) {
                players[free].teamID = teamID
                players[free].contract.endSeason = season + random.int(in: 1...3)
            } else {
                let strength = (FootballSeason.team(teamID)?.strength ?? 65) + (division(of: teamID) == .serieA ? 2 : -2)
                var youth = FootballSeason.makeYouth(id: nextPlayerID, position: position, teamStrength: strength, teamID: teamID,
                                                     season: season, using: &random)
                youth.isYouth = false
                players.append(youth)
                nextPlayerID += 1
            }
            indices = squadIndices()
        }
    }

    /// Movimentação entre clubes da IA: reposição de lacunas e transferências entre eles.
    mutating func runAIMarket(using random: inout FootballRandom, intensity: Int) {
        let aiTeams = FootballSeason.teams.map(\.id).filter { $0 != selectedClubID }
        for teamID in aiTeams { normalizeSquad(teamID: teamID, using: &random) }
        var done = 0
        var attempts = 0
        while done < intensity && attempts < intensity * 6 {
            attempts += 1
            guard let sellerID = random.pick(aiTeams), let buyerID = random.pick(aiTeams.filter { $0 != sellerID }) else { continue }
            let roster = players(forTeam: sellerID).sorted { $0.overall > $1.overall }
            guard roster.count > 5 else { continue }
            let candidates = roster.dropFirst(3).prefix(10).filter { $0.parentTeamID == nil }
            guard let target = random.pick(Array(candidates)), sellerCanSell(target) else { continue }
            let buyerRoster = players(forTeam: buyerID).filter { $0.position == target.position }.sorted { $0.overall < $1.overall }
            guard let weakestStarter = buyerRoster.dropLast(max(0, buyerRoster.count - (FootballFormation.fourFourTwo.requiredPlayers[target.position] ?? 2))).first,
                  target.overall >= weakestStarter.overall + 2 else { continue }
            let fee = Int(Double(askingPrice(for: target)) * Double(random.int(in: 100...125)) / 100 / 10_000) * 10_000
            guard let buyer = FootballSeason.team(buyerID), Double(fee) <= Double(buyer.startingBudget) * 0.4 else { continue }
            guard let index = players.firstIndex(where: { $0.id == target.id }) else { continue }
            players[index].teamID = buyerID
            players[index].contract.endSeason = season + random.int(in: 2...4)
            players[index].morale = 65
            logTransfer(playerID: target.id, name: target.name, from: sellerID, to: buyerID, fee: fee)
            if target.overall >= 74 || watchlist.contains(target.id) {
                addInbox(.transfer, title: "\(target.name) mudou de clube",
                         body: "\(FootballSeason.teamName(buyerID)) contratou \(target.name) (\(target.position.rawValue), geral \(target.overall)) do \(FootballSeason.teamName(sellerID)) por \(FootballFormat.money(fee)).",
                         playerID: target.id)
            }
            normalizeSquad(teamID: sellerID, using: &random)
            normalizeSquad(teamID: buyerID, using: &random)
            done += 1
        }
    }

    /// Eventos de mercado que dependem do calendário: início e último dia das janelas.
    mutating func marketCalendarEvents() {
        progressTransferRaces()
        guard let window = transferWindow else { return }
        guard matchDayIndex == window.startDay || window.isLastDay else { return }
        var random = FootballRandom(seed: matchSeed(stream: .transfers, id: 900 + matchDayIndex))
        runAIMarket(using: &random, intensity: window.isLastDay ? 5 : 3)
        if window.isLastDay {
            addInbox(.transfer, title: "Último dia da janela", body: "A janela de transferências fecha hoje. Propostas, compras e empréstimos só podem ser concluídos agora.")
        }
        for id in watchlist {
            if let athlete = player(id), athlete.contract.endSeason != 0, athlete.contract.endSeason <= season, athlete.teamID != selectedClubID,
               window.isLastDay == false {
                addInbox(.transfer, title: "\(athlete.name) está de contrato curto",
                         body: "O contrato de \(athlete.name), da sua lista de observados, termina nesta temporada.", playerID: id)
            }
        }
    }

    // MARK: - Observação (scouting)

    /// Habilidade do olheiro-chefe (1 a 20). A comissão técnica da Fase 5 sobrescreve este valor.
    var scoutAbility: Int { staffAbility(.headScout) ?? 10 }

    func scoutKnowledge(of playerID: Int) -> Int {
        guard let player = player(playerID) else { return 0 }
        if player.teamID == selectedClubID { return 100 }
        if let known = scoutKnowledge[playerID] { return known }
        return player.teamID == nil ? 70 : 20
    }

    mutating func observe(_ playerID: Int, gain: Int) {
        guard player(playerID)?.teamID != selectedClubID else { return }
        scoutKnowledge[playerID] = min(100, (scoutKnowledge[playerID] ?? scoutKnowledge(of: playerID)) + gain)
    }

    /// Faixa em que o geral aparece para o treinador: quanto menos se sabe, mais larga.
    func visibleOverallRange(of playerID: Int) -> ClosedRange<Int> {
        guard let player = player(playerID) else { return 0...0 }
        let known = scoutKnowledge(of: playerID)
        guard known < 100 else { return player.overall...player.overall }
        let width = Int((100.0 - Double(known)) / 100.0 * 12.0)
        let offset = (player.id &* 31 &+ season &* 7) % (width + 1)
        let low = max(30, player.overall - offset)
        return low...(low + width)
    }

    func visibleAttribute(playerID: Int, kind: AttributeKind) -> ClosedRange<Int> {
        guard let player = player(playerID) else { return 1...1 }
        let known = scoutKnowledge(of: playerID)
        guard known < 100 else { return player.attributes[kind]...player.attributes[kind] }
        let width = Int((100.0 - Double(known)) / 100.0 * 8.0)
        let offset = (player.id &* 17 &+ kind.index &* 5) % (width + 1)
        let low = max(1, min(20 - width, player.attributes[kind] - offset))
        return low...(low + width)
    }

    mutating func toggleWatch(playerID: Int) {
        if let index = watchlist.firstIndex(of: playerID) { watchlist.remove(at: index) } else { watchlist.append(playerID) }
    }

    static let maxScoutMissions = 2

    var activeScoutMissions: [ScoutMission] { scoutMissions.filter { !$0.completed } }

    @discardableResult
    mutating func startScoutMission(region: Int?, position: FootballPosition?, maxAge: Int, maxValue: Int) -> Bool {
        guard selectedClubID != nil, activeScoutMissions.count < scoutSlots else { return false }
        scoutMissions.append(ScoutMission(id: nextScoutID, region: region, position: position, maxAge: maxAge, maxValue: maxValue,
                                          startedMatchDay: matchDayIndex, season: season, durationMatchDays: 3))
        nextScoutID += 1
        return true
    }

    var scoutSlots: Int { Self.maxScoutMissions }

    func stars(for value: Int) -> Int { min(5, max(1, Int(((Double(value) - 50) / 8).rounded()) + 1)) }

    /// Conclui as missões prontas e gera relatórios com estrelas para o atleta atual e o potencial.
    mutating func progressScouting(using random: inout FootballRandom) {
        for index in scoutMissions.indices where !scoutMissions[index].completed {
            let mission = scoutMissions[index]
            let elapsed = mission.season == season ? matchDayIndex - mission.startedMatchDay : matchDayIndex + FootballSeason.matchDaysPerSeason - mission.startedMatchDay
            guard elapsed >= mission.durationMatchDays else { continue }
            scoutMissions[index].completed = true
            let pool = players.filter { candidate in
                guard candidate.teamID != selectedClubID, !candidate.onLoan else { return false }
                if let position = mission.position, candidate.position != position { return false }
                if let region = mission.region, candidate.region != region { return false }
                return candidate.age <= mission.maxAge && candidate.marketValue <= mission.maxValue
            }
            let ranked = pool.map { ($0, Double($0.potential) + Double(random.int(in: -30...30)) / 10) }.sorted { $0.1 > $1.1 }.prefix(3)
            var titles: [String] = []
            for (candidate, _) in ranked {
                let accuracy = Double(20 - scoutAbility) / 20
                let currentNoise = random.chance(accuracy * 0.5) ? random.int(in: -1...1) : 0
                let potentialNoise = random.chance(accuracy * 0.5) ? random.int(in: -1...1) : 0
                let current = min(5, max(1, stars(for: candidate.overall) + currentNoise))
                let potential = min(5, max(1, stars(for: candidate.potential) + potentialNoise))
                scoutKnowledge[candidate.id] = max(scoutKnowledge[candidate.id] ?? 0, 70 + random.int(in: 0...15))
                let club = candidate.teamID.map { FootballSeason.teamName($0) } ?? "sem clube"
                scoutReports.append(ScoutReport(id: nextScoutID, missionID: mission.id, playerID: candidate.id, currentStars: current, potentialStars: potential,
                                                note: "\(candidate.position.title), \(candidate.age) anos, \(club). Valor estimado \(FootballFormat.money(candidate.marketValue)).",
                                                season: season))
                nextScoutID += 1
                titles.append(candidate.name)
            }
            if scoutReports.count > 40 { scoutReports.removeFirst(scoutReports.count - 40) }
            addInbox(.scouting, title: "Relatório do olheiro pronto",
                     body: titles.isEmpty ? "Nenhum atleta encontrado com esse perfil." : "Perfil: \(mission.summary). Destaques: \(titles.joined(separator: ", ")).")
        }
    }

    // MARK: - Categoria de base

    /// Chegada anual da base. Retorna os ids dos jovens promovidos à categoria.
    mutating func runYouthIntake(using random: inout FootballRandom) {
        guard let selectedClubID else { return }
        let count = 3 + (youthAcademyLevel >= 4 ? 1 : 0) + random.int(in: 0...2)
        lastYouthIntake = []
        // Abre espaço removendo os mais fracos quando a base está cheia.
        var current = youthRoster
        while current.count + count > Self.youthRosterLimit, let weakest = current.min(by: { $0.potential < $1.potential }) {
            if let index = players.firstIndex(where: { $0.id == weakest.id }) {
                players[index].teamID = nil
                players[index].isYouth = false
                players[index].contract.endSeason = 0
            }
            current = youthRoster
        }
        let strength = (selectedClub?.strength ?? 65) + (division(of: selectedClubID) == .serieA ? 2 : -2)
        let template: [FootballPosition] = [.goalkeeper, .defender, .defender, .midfielder, .midfielder, .forward, .forward, .defender]
        for offset in 0..<count {
            let position = template[(offset + random.int(in: 0...3)) % template.count]
            var youth = FootballSeason.makeYouth(id: nextPlayerID, position: position, teamStrength: strength, teamID: selectedClubID,
                                                 season: season, quality: youthAcademyLevel + staffBonus(.youthCoach), using: &random)
            if random.chance(0.04 + 0.02 * Double(youthAcademyLevel)) {
                // Joia da base.
                let overall = random.int(in: 55...63)
                youth.attributes = PlayerAttributes.derive(overall: overall, position: position, detail: youth.detail, random: &random)
                youth.overall = youth.attributes.overall(for: position)
                youth.potential = random.int(in: 86...94)
                youth.marketValue = FootballSeason.marketValue(overall: youth.overall, age: youth.age, potential: youth.potential)
                youth.traits = [.prodigy]
            }
            youth.isYouth = true
            players.append(youth)
            lastYouthIntake.append(youth.id)
            nextPlayerID += 1
        }
        if !lastYouthIntake.isEmpty {
            addInbox(.general, title: "Nova leva da base", body: "\(lastYouthIntake.count) jovens chegaram à categoria de base. Veja o potencial de cada um na aba Clube.")
        }
    }

    /// Jovens com 20 anos ou mais deixam a base se não forem promovidos.
    mutating func retireOverageYouth() {
        for index in players.indices where players[index].isYouth && players[index].teamID == selectedClubID && players[index].age >= 20 {
            players[index].isYouth = false
            players[index].teamID = nil
            players[index].contract.endSeason = 0
            addInbox(.general, title: "\(players[index].name) deixou a base", body: "Passou da idade da categoria sem ser promovido e foi para o mercado.", playerID: players[index].id)
        }
    }

    func canPromote(playerID: Int) -> Bool {
        guard let player = player(playerID), player.isYouth, player.teamID == selectedClubID else { return false }
        return clubRoster.count < Self.rosterLimit && wageCapAllows(extra: promotedWage(player) - player.contract.wage)
    }

    private func promotedWage(_ player: FootballPlayer) -> Int {
        max(player.contract.wage, Int(Double(PlayerContract.wage(forValue: player.marketValue)) * 0.6 / 5_000) * 5_000)
    }

    @discardableResult
    mutating func promoteYouth(playerID: Int) -> Bool {
        guard canPromote(playerID: playerID), let index = players.firstIndex(where: { $0.id == playerID }) else { return false }
        players[index].isYouth = false
        players[index].contract.wage = promotedWage(players[index])
        players[index].contract.endSeason = max(players[index].contract.endSeason, season + 2)
        players[index].contract.status = .prospect
        players[index].morale = 75
        return true
    }

    @discardableResult
    mutating func releaseYouth(playerID: Int) -> Bool {
        guard let index = players.firstIndex(where: { $0.id == playerID }), players[index].isYouth, players[index].teamID == selectedClubID else { return false }
        players[index].isYouth = false
        players[index].teamID = nil
        players[index].contract.endSeason = 0
        return true
    }

    // MARK: - Copinha (torneio de base)

    static let youthCupMatchDay = 14

    mutating func runYouthCup(using random: inout FootballRandom) {
        guard let selectedClubID, !youthCupHistory.contains(where: { $0.season == season }) else { return }
        func userRating() -> Double {
            let top = youthRoster.sorted { $0.overall > $1.overall }.prefix(11)
            guard !top.isEmpty else { return 40 }
            let padded = top.map { Double($0.overall) } + Array(repeating: 40.0, count: max(0, 11 - top.count))
            return padded.reduce(0, +) / Double(padded.count)
        }
        var others = FootballSeason.teams.map(\.id).filter { $0 != selectedClubID }
        for index in stride(from: others.count - 1, to: 0, by: -1) { others.swapAt(index, random.int(in: 0...index)) }
        var field: [(id: Int, rating: Double)] = [(selectedClubID, userRating())]
        for id in others.prefix(7) {
            let strength = Double(FootballSeason.team(id)?.strength ?? 65) - 18 + Double(random.int(in: -40...40)) / 10
            field.append((id, strength))
        }
        for index in stride(from: field.count - 1, to: 0, by: -1) { field.swapAt(index, random.int(in: 0...index)) }
        var round = 0
        var userRound = "Eliminado nas quartas de final"
        let names = ["Eliminado nas quartas de final", "Eliminado na semifinal", "Vice-campeão"]
        while field.count > 1 {
            var next: [(id: Int, rating: Double)] = []
            for pair in stride(from: 0, to: field.count, by: 2) {
                let a = field[pair]
                let b = field[pair + 1]
                let probability = 1 / (1 + exp(-(a.rating - b.rating) / 6))
                let winner = random.chance(probability) ? a : b
                if (a.id == selectedClubID || b.id == selectedClubID) && winner.id != selectedClubID { userRound = names[min(round, 2)] }
                next.append(winner)
            }
            field = next
            round += 1
        }
        let winnerID = field[0].id
        if winnerID == selectedClubID { userRound = "Campeão da Copinha" }
        let reachedSemi = userRound == "Campeão da Copinha" || userRound == "Vice-campeão" || userRound == "Eliminado na semifinal"
        var topScorer = "—"
        if reachedSemi, let striker = youthRoster.filter({ $0.position == .forward || $0.position == .midfielder }).max(by: { $0.overall < $1.overall }) {
            topScorer = striker.name
        }
        for index in players.indices where players[index].isYouth && players[index].teamID == selectedClubID {
            if random.chance(reachedSemi ? 0.6 : 0.3), players[index].overall < players[index].potential {
                players[index].setOverall(players[index].overall + 1)
            }
        }
        youthCupHistory.append(YouthCupResult(season: season, winnerID: winnerID, userResult: userRound, topScorerName: topScorer))
        addInbox(.news, title: "Copinha encerrada", body: "\(FootballSeason.teamName(winnerID)) é o campeão da Copinha. Seu clube: \(userRound.lowercased()).")
    }
}
