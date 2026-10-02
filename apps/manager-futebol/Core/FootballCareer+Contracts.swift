import Foundation

extension FootballCareer {
    static let youthRosterLimit = 12

    // MARK: - Finanças

    /// Toda movimentação de dinheiro passa por aqui: atualiza o caixa e registra no livro financeiro.
    mutating func book(_ category: FinanceCategory, _ amount: Int, _ note: String) {
        guard amount != 0 else { return }
        transferBudget += amount
        finance.add(FinanceEntry(season: season, matchDay: matchDayIndex, category: category, amount: amount, note: note))
    }

    // MARK: - Salários

    /// Folha salarial anual do elenco (principal, base e emprestados a este clube).
    var wageBill: Int {
        guard let selectedClubID else { return 0 }
        return players.filter { $0.teamID == selectedClubID }.reduce(0) { $0 + $1.contract.wage }
    }

    var wageHeadroom: Int { wageCap - wageBill }

    func wageCapAllows(extra: Int) -> Bool { wageBill + extra <= wageCap }

    /// Folha cobrada a cada dia de jogo.
    mutating func chargeMatchDayWages() {
        guard selectedClubID != nil else { return }
        let share = wageBill / FootballSeason.matchDaysPerSeason
        book(.wages, -share, "Folha salarial do dia de jogo")
    }

    // MARK: - Status esperado

    /// Status que o atleta espera ter, pela posição dele no elenco.
    func expectedStatus(of player: FootballPlayer) -> SquadStatus {
        guard let teamID = player.teamID else { return .rotation }
        let squad = players.filter { $0.teamID == teamID && !$0.isYouth }
        if player.isYouth { return .prospect }
        let rank = squad.sorted { $0.overall > $1.overall }.firstIndex { $0.id == player.id } ?? squad.count
        if player.age <= 21 && player.potential - player.overall >= 10 && rank >= 11 { return .prospect }
        switch rank {
        case 0...2: return .key
        case 3...10: return .starter
        case 11...14: return .rotation
        default: return .backup
        }
    }

    // MARK: - Contratos

    func contractAsk(playerID: Int) -> ContractAsk? {
        guard let player = player(playerID) else { return nil }
        var wage = Double(PlayerContract.wage(forValue: player.marketValue))
        if player.morale < 45 { wage *= 1.15 } else if player.morale >= 75 { wage *= 0.95 }
        let status = expectedStatus(of: player)
        wage *= status.wageFactor
        if player.age >= 33 { wage *= 0.9 }
        let years = player.age <= 24 ? 4 : (player.age <= 29 ? 3 : (player.age <= 32 ? 2 : 1))
        return ContractAsk(wage: Int((wage / 5_000).rounded()) * 5_000, years: years, status: status)
    }

    func canRenew(playerID: Int) -> Bool {
        guard let player = player(playerID), player.teamID == selectedClubID, !isFired else { return false }
        return !player.onLoan
    }

    /// Renovação com negociação: aceita, contraproposta ou recusa.
    @discardableResult
    mutating func offerRenewal(playerID: Int, wage: Int, years: Int, status: SquadStatus) -> NegotiationOutcome {
        guard canRenew(playerID: playerID), let index = players.firstIndex(where: { $0.id == playerID }),
              let ask = contractAsk(playerID: playerID) else { return .notAllowed("Este atleta não pode renovar agora.") }
        let player = players[index]
        if player.morale < 20 { return .refused("\(player.name) está insatisfeito demais para renovar.") }
        let current = player.contract.wage
        if !wageCapAllows(extra: wage - current) { return .overWageCap }

        let effectiveAsk = Double(ask.wage) * (status >= ask.status ? 1.0 : 1.1)
        if Double(wage) >= effectiveAsk {
            let base = max(player.contract.endSeason, season)
            players[index].contract = PlayerContract(wage: wage, endSeason: base + years, status: status)
            players[index].morale = min(100, player.morale + 8)
            addInbox(.general, title: "Renovação concluída", body: "\(player.name) assinou por mais \(years) temporada(s).", playerID: playerID)
            resolveMessages(for: playerID, kinds: [.playerContract])
            return .accepted
        }
        if Double(wage) >= effectiveAsk * 0.88 {
            let counter = Int(((Double(wage) + effectiveAsk) / 2 / 5_000).rounded(.up)) * 5_000
            return .counter(wage: counter)
        }
        return .refused("\(player.name) quer algo próximo de \(FootballFormat.money(ask.wage)) por temporada.")
    }

    // MARK: - Moral e notas pós-jogo

    /// Atualiza moral, sequência no banco, forma, disciplina e promessas depois de um dia de jogo.
    mutating func processUserPlayers(stats: [PlayerMatchStats], result: FootballResult?, derby: Bool, started: Set<Int>, teamPlayed: Bool = true) {
        guard let selectedClubID else { return }
        let playedIDs = Set(stats.filter { $0.minutes > 0 }.map(\.playerID))
        let statsByID = Dictionary(uniqueKeysWithValues: stats.map { ($0.playerID, $0) })
        let multiplier = derby ? 2 : 1
        let squadIDs = players.indices.filter { players[$0].teamID == selectedClubID && !players[$0].isYouth }

        for index in squadIDs {
            let status = expectedStatus(of: players[index])
            let played = playedIDs.contains(players[index].id)
            var delta = 0
            if let stat = statsByID[players[index].id], stat.minutes > 0 {
                players[index].benchStreak = 0
                players[index].form.add(stat.rating)
                if stat.rating >= 7.5 { delta += 2 } else if stat.rating <= 5.2 { delta -= 1 }
                switch result {
                case .win?: delta += 1 * multiplier
                case .loss?: if started.contains(players[index].id) { delta -= 1 * multiplier }
                default: break
                }
                if status <= .backup { delta += 1 }
            } else if teamPlayed && players[index].isAvailable(matchDay: matchDayIndex) {
                players[index].benchStreak += 1
                if status >= .starter { delta -= 3 } else if status == .rotation && players[index].benchStreak >= 4 { delta -= 2 }
            }
            // O moral volta devagar para o nível normal.
            if delta == 0 { delta = players[index].morale > 60 ? -1 : (players[index].morale < 60 ? 1 : 0) }
            players[index].morale = min(100, max(0, players[index].morale + delta))
            _ = played
        }

        // Um líder em campo anima o elenco.
        let leaders = squadIDs.filter { players[$0].has(.leader) && playedIDs.contains(players[$0].id) }
        if !leaders.isEmpty, result == .win {
            for index in squadIDs { players[index].morale = min(100, players[index].morale + 1) }
        }
        evaluatePromises(started: started)
    }

    // MARK: - Promessas

    mutating func evaluatePromises(started: Set<Int>) {
        var remaining: [PlayerPromise] = []
        for var promise in promises {
            if started.contains(promise.playerID) { promise.startsDone += 1 }
            if let index = players.firstIndex(where: { $0.id == promise.playerID }) {
                if promise.startsDone >= promise.requiredStarts {
                    players[index].morale = min(100, players[index].morale + 8)
                    addInbox(.general, title: "Promessa cumprida", body: "\(players[index].name) ficou satisfeito por ter jogado como prometido.", playerID: promise.playerID)
                    continue
                }
                if matchDayIndex >= promise.deadlineMatchDay {
                    players[index].morale = max(0, players[index].morale - 18)
                    boardConfidence = max(0, boardConfidence - 1)
                    addInbox(.general, title: "Promessa quebrada", body: "\(players[index].name) não gostou de não ter jogado como prometido.", playerID: promise.playerID)
                    continue
                }
            } else {
                continue
            }
            remaining.append(promise)
        }
        promises = remaining
    }

    /// Responde ao pedido de um atleta para jogar mais: promete começar alguns jogos.
    @discardableResult
    mutating func promiseStarts(playerID: Int, starts: Int = 3) -> Bool {
        guard let index = players.firstIndex(where: { $0.id == playerID }), players[index].teamID == selectedClubID else { return false }
        promises.removeAll { $0.playerID == playerID }
        promises.append(PlayerPromise(id: nextPromiseID, playerID: playerID, requiredStarts: starts, startsDone: 0,
                                      deadlineMatchDay: matchDayIndex + starts + 2, season: season))
        nextPromiseID += 1
        players[index].morale = min(100, players[index].morale + 10)
        players[index].benchStreak = 0
        resolveMessages(for: playerID, kinds: [.playerPlayingTime])
        return true
    }

    mutating func dismissRequest(playerID: Int) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[index].morale = max(0, players[index].morale - 6)
        resolveMessages(for: playerID, kinds: [.playerPlayingTime, .playerWantsOut])
    }

    // MARK: - Pedidos dos atletas

    mutating func generatePlayerRequests() {
        guard let selectedClubID else { return }
        for player in players where player.teamID == selectedClubID && !player.isYouth && !player.onLoan {
            let hasPromise = promises.contains { $0.playerID == player.id }
            if !hasPromise, player.benchStreak >= 4, player.morale < 45, expectedStatus(of: player) >= .rotation,
               !hasOpenMessage(.playerPlayingTime, playerID: player.id) {
                addInbox(.playerPlayingTime, title: "\(player.name) quer jogar mais",
                         body: "\(player.name) está há \(player.benchStreak) jogos sem entrar em campo e pede minutos. Prometa que ele vai começar ou ele ficará mais insatisfeito.",
                         playerID: player.id)
            }
            if player.morale < 25, player.benchStreak >= 6, !hasOpenMessage(.playerWantsOut, playerID: player.id) {
                addInbox(.playerWantsOut, title: "\(player.name) quer sair",
                         body: "\(player.name) pediu para ser negociado. Você pode vendê-lo, emprestá-lo ou tentar convencê-lo a ficar.",
                         playerID: player.id)
            }
            if player.contract.endSeason == season, matchDayIndex >= 8,
               !inbox.contains(where: { $0.kind == .playerContract && $0.playerID == player.id && $0.season == season }) {
                addInbox(.playerContract, title: "Contrato de \(player.name) termina na temporada",
                         body: "O contrato de \(player.name) vence ao fim desta temporada. Renove agora ou ele sairá de graça.",
                         playerID: player.id)
            }
        }
    }

    func hasOpenMessage(_ kind: InboxKind, playerID: Int) -> Bool {
        inbox.contains { $0.kind == kind && $0.playerID == playerID && !$0.isResolved }
    }

    // MARK: - Caixa de entrada

    mutating func addInbox(_ kind: InboxKind, title: String, body: String, playerID: Int? = nil, offerID: Int? = nil) {
        inbox.append(InboxMessage(id: nextInboxID, season: season, matchDay: matchDayIndex, kind: kind,
                                  title: title, body: body, playerID: playerID, offerID: offerID))
        nextInboxID += 1
        if inbox.count > 80 {
            // Descarta as mensagens mais antigas já resolvidas ou lidas.
            if let index = inbox.firstIndex(where: { $0.isResolved || $0.isRead }) { inbox.remove(at: index) } else { inbox.removeFirst() }
        }
    }

    mutating func resolveMessages(for playerID: Int, kinds: [InboxKind]) {
        for index in inbox.indices where inbox[index].playerID == playerID && kinds.contains(inbox[index].kind) {
            inbox[index].isResolved = true
            inbox[index].isRead = true
        }
    }

    mutating func markInboxRead() {
        for index in inbox.indices { inbox[index].isRead = true }
    }

    var unreadCount: Int { inbox.filter { !$0.isRead }.count }

    var pendingRequestCount: Int { inbox.filter { $0.kind.needsResponse && !$0.isResolved }.count }

    // MARK: - Contratos no fim da temporada

    /// Contratos vencidos: os da IA são renovados; os do usuário viram agentes livres.
    mutating func expireContracts(using random: inout FootballRandom) -> [FootballPlayer] {
        var released: [FootballPlayer] = []
        for index in players.indices {
            guard let teamID = players[index].teamID, players[index].contract.endSeason != 0,
                  players[index].contract.endSeason <= season, !players[index].onLoan else { continue }
            if teamID == selectedClubID {
                var leaving = players[index]
                leaving.teamID = nil
                leaving.contract.endSeason = 0
                leaving.isYouth = false
                leaving.isListed = false
                leaving.isLoanListed = false
                released.append(leaving)
                players[index] = leaving
            } else {
                players[index].contract.endSeason = season + random.int(in: 2...4)
                players[index].contract.wage = PlayerContract.wage(forValue: players[index].marketValue)
            }
        }
        for leaving in released {
            addInbox(.general, title: "\(leaving.name) deixou o clube", body: "O contrato terminou sem renovação e ele agora é agente livre.", playerID: leaving.id)
        }
        return released
    }

    /// Garante um elenco mínimo jogável contratando agentes livres quando necessário.
    mutating func ensureMinimumRoster() {
        guard let selectedClubID else { return }
        var needed = 14 - players.filter({ $0.teamID == selectedClubID && !$0.isYouth }).count
        guard needed > 0 else { return }
        for position in [FootballPosition.goalkeeper, .defender, .midfielder, .forward] {
            let counts = players.filter { $0.teamID == selectedClubID && !$0.isYouth && $0.position == position }.count
            let wanted = position == .goalkeeper ? 2 : 3
            if counts >= wanted { continue }
            let pool = marketPlayers.filter { $0.position == position }.sorted { $0.marketValue < $1.marketValue }
            for candidate in pool.prefix(max(0, min(needed, wanted - counts))) {
                guard let index = players.firstIndex(where: { $0.id == candidate.id }) else { continue }
                players[index].teamID = selectedClubID
                players[index].contract.endSeason = season + 1
                needed -= 1
            }
        }
        if needed > 0 {
            for candidate in marketPlayers.sorted(by: { $0.marketValue < $1.marketValue }).prefix(needed) {
                guard let index = players.firstIndex(where: { $0.id == candidate.id }) else { continue }
                players[index].teamID = selectedClubID
                players[index].contract.endSeason = season + 1
            }
        }
    }
}
