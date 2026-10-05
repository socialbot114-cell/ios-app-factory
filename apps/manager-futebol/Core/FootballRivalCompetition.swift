import Foundation

// MARK: - Concorrência por uma contratação e alternativas (F3-05)

struct TransferRace: Codable, Equatable, Identifiable {
    enum Status: String, Codable { case open, userWon, rivalWon, rivalGaveUp, windowClosed, cancelled }

    let id: Int
    let playerID: Int
    let sellerID: Int
    let rivalID: Int
    let season: Int
    let startWorldDay: Int
    let deadlineWorldDay: Int
    /// Proposta que o rival prepara, para o jogador saber quanto precisa cobrir.
    let rivalOffer: Int
    let factID: String
    let commitmentID: Int
    var status: Status = .open
    /// Atletas da mesma posição sugeridos quando a disputa é perdida.
    var alternativeIDs: [Int] = []

    var isOpen: Bool { status == .open }
}

extension FootballCareer {
    static let raceDays = 3
    static let maxOpenRaces = 2
    static let raceHistoryLimit = 12

    var transferRaces: [TransferRace] { world.projects.transferRaces }
    var openTransferRaces: [TransferRace] { world.projects.transferRaces.filter(\.isOpen) }

    func openRace(for playerID: Int) -> TransferRace? { world.projects.transferRaces.first { $0.playerID == playerID && $0.isOpen } }

    /// Clube que entra na disputa: mais forte possível, sem ser o vendedor nem o usuário, e com espaço na posição.
    func rivalBidder(for athlete: FootballPlayer, using random: inout FootballRandom) -> Int? {
        guard let sellerID = athlete.teamID else { return nil }
        let candidates = FootballSeason.teams.filter { team in
            team.id != sellerID && team.id != selectedClubID
                && positionCount(teamID: team.id, position: athlete.position) <= (Self.positionMinimums[athlete.position] ?? 4) + 1
                && clubPrestige(team.id) >= clubPrestige(sellerID) - 4
        }.sorted { clubPrestige($0.id) > clubPrestige($1.id) }
        guard !candidates.isEmpty else { return nil }
        return candidates[random.int(in: 0...min(2, candidates.count - 1))].id
    }

    /// Abre disputas por atletas observados durante a janela. Chamado uma vez por dia de jogo.
    mutating func progressTransferRaces() {
        stampScoutReports()
        resolveTransferRaces()
        progressTransferTalks()
        // O prazo termina no máximo no último dia da janela; sem ao menos um dia pela frente, não há disputa.
        guard let clubID = selectedClubID, !isFired, let window = transferWindow, openTransferRaces.count < Self.maxOpenRaces else { return }
        let days = min(Self.raceDays, window.endDay - matchDayIndex)
        guard days >= 1 else { return }
        var random = FootballRandom(seed: matchSeed(stream: .transfers, id: 60_000 + worldDay))
        for id in watchlist {
            guard openTransferRaces.count < Self.maxOpenRaces,
                  let athlete = player(id), let sellerID = athlete.teamID, sellerID != clubID, !athlete.onLoan,
                  !world.projects.transferRaces.contains(where: { $0.playerID == id && $0.season == season }) else { continue }
            // Atletas melhores atraem mais gente.
            guard random.chance(min(0.35, 0.08 + Double(max(0, athlete.overall - 60)) * 0.01)),
                  let rivalID = rivalBidder(for: athlete, using: &random) else { continue }
            startTransferRace(athlete: athlete, sellerID: sellerID, rivalID: rivalID, days: days, using: &random)
        }
    }

    private mutating func startTransferRace(athlete: FootballPlayer, sellerID: Int, rivalID: Int, days: Int, using random: inout FootballRandom) {
        let id = world.projects.nextRaceID
        world.projects.nextRaceID += 1
        let offer = Int(Double(askingPrice(for: athlete)) * (1 + random.unit() * 0.15) / 10_000) * 10_000
        let rival = FootballSeason.teamName(rivalID)
        let factID = "race-\(id)"
        recordFact(WorldFact(id: factID, source: .market, worldDay: worldDay, title: "\(rival) também quer \(athlete.name)",
                             detail: "Fontes do mercado dizem que o \(rival) prepara cerca de \(FootballFormat.money(offer)) pelo \(athlete.name), do \(FootballSeason.teamName(sellerID)). Se quiser o atleta, feche antes.",
                             playerIDs: [athlete.id], clubIDs: [rivalID, sellerID], reliability: .rumor, isPublic: true,
                             nextEvents: ["O \(rival) deve formalizar a proposta em \(days) dia(s) de jogo."]))
        deliverFact(factID, inbox: .transfer, social: true)
        let commitment = openCommitment(kind: .transferRace, playerID: athlete.id, factID: factID, days: days,
                                        title: "Disputa por \(athlete.name)",
                                        detail: "O \(rival) prepara \(FootballFormat.money(offer)). Feche a contratação antes do prazo ou perca o atleta.")
        world.projects.transferRaces.append(TransferRace(id: id, playerID: athlete.id, sellerID: sellerID, rivalID: rivalID, season: season,
                                                         startWorldDay: worldDay, deadlineWorldDay: worldDay + days,
                                                         rivalOffer: offer, factID: factID, commitmentID: commitment.id))
    }

    /// Decide as disputas: quem contratou primeiro vence; no prazo, o rival tenta fechar.
    mutating func resolveTransferRaces() {
        for index in world.projects.transferRaces.indices where world.projects.transferRaces[index].isOpen {
            let race = world.projects.transferRaces[index]
            guard let athlete = player(race.playerID) else {
                world.projects.transferRaces[index].status = .cancelled
                continue
            }
            if athlete.teamID == selectedClubID {
                world.projects.transferRaces[index].status = .userWon
                resolveCommitment(id: race.commitmentID, as: .fulfilled)
                announceRace(race, title: "\(athlete.name) escolheu o seu clube",
                             detail: "Você fechou antes do \(FootballSeason.teamName(race.rivalID)), que ficou sem o atleta.", suffix: "won")
                continue
            }
            if athlete.teamID != race.sellerID {
                world.projects.transferRaces[index].status = .cancelled
                resolveCommitment(id: race.commitmentID, as: .cancelled)
                continue
            }
            // Janela fechada: ninguém contrata mais, a disputa acaba sem vencedor.
            guard isTransferWindowOpen else {
                world.projects.transferRaces[index].status = .windowClosed
                resolveCommitment(id: race.commitmentID, as: .cancelled)
                continue
            }
            guard worldDay >= race.deadlineWorldDay else { continue }
            var random = FootballRandom(seed: matchSeed(stream: .transfers, id: 61_000 + race.id))
            let userPrestige = selectedClubID.map { clubPrestige($0) } ?? 60
            let chance = min(0.85, max(0.3, 0.6 + Double(clubPrestige(race.rivalID) - userPrestige) * 0.015))
            if sellerCanSell(athlete), random.chance(chance) {
                completeRivalSigning(raceIndex: index, athlete: athlete)
            } else {
                world.projects.transferRaces[index].status = .rivalGaveUp
                announceRace(race, title: "\(FootballSeason.teamName(race.rivalID)) desiste de \(athlete.name)",
                             detail: "A proposta não convenceu o \(FootballSeason.teamName(race.sellerID)). O atleta continua disponível para você.", suffix: "gaveup")
            }
        }
        let closed = world.projects.transferRaces.filter { !$0.isOpen }
        if closed.count > Self.raceHistoryLimit {
            let keep = Set(closed.suffix(Self.raceHistoryLimit).map(\.id))
            world.projects.transferRaces.removeAll { !$0.isOpen && !keep.contains($0.id) }
        }
    }

    mutating func completeRivalSigning(raceIndex index: Int, athlete: FootballPlayer) {
        let race = world.projects.transferRaces[index]
        guard let playerIndex = players.firstIndex(where: { $0.id == athlete.id }) else { return }
        players[playerIndex].teamID = race.rivalID
        players[playerIndex].isListed = false
        players[playerIndex].contract = PlayerContract(wage: players[playerIndex].contract.wage, endSeason: season + 3,
                                                       status: players[playerIndex].contract.status)
        logTransfer(playerID: athlete.id, name: athlete.name, from: race.sellerID, to: race.rivalID, fee: race.rivalOffer)
        var random = FootballRandom(seed: matchSeed(stream: .transfers, id: 62_000 + race.id))
        normalizeSquad(teamID: race.sellerID, using: &random)
        normalizeSquad(teamID: race.rivalID, using: &random)
        watchlist.removeAll { $0 == athlete.id }
        // O atleta lembra que o clube o sondou e não fechou a tempo.
        recordMemory(playerID: athlete.id, kind: .lostToRival, id: "\(race.factID)-memory")
        let alternatives = recruitmentAlternatives(to: athlete)
        world.projects.transferRaces[index].status = .rivalWon
        world.projects.transferRaces[index].alternativeIDs = alternatives.map(\.id)
        var detail = "O \(FootballSeason.teamName(race.rivalID)) pagou \(FootballFormat.money(race.rivalOffer)) e levou \(athlete.name)."
        if !alternatives.isEmpty {
            detail += " Alternativas na mesma posição: " + alternatives.map { "\($0.name) (\(FootballSeason.teamName($0.teamID ?? 0)))" }.joined(separator: ", ") + "."
        }
        announceRace(race, title: "\(athlete.name) fecha com o \(FootballSeason.teamName(race.rivalID))", detail: detail, suffix: "lost")
    }

    /// Mesma posição, nível parecido, cabe no caixa e o clube vende: os três mais próximos do perfil perdido.
    func recruitmentAlternatives(to athlete: FootballPlayer, limit: Int = 3) -> [FootballPlayer] {
        players.filter { candidate in
            candidate.id != athlete.id && candidate.position == athlete.position && !candidate.isYouth && !candidate.onLoan
                && candidate.teamID != nil && candidate.teamID != selectedClubID && sellerCanSell(candidate)
                && Double(askingPrice(for: candidate)) <= Double(max(transferBudget, 0)) * 1.2
                && abs(candidate.overall - athlete.overall) <= 6
        }
        .sorted {
            let left = abs($0.overall - athlete.overall) * 2 + abs($0.age - athlete.age)
            let right = abs($1.overall - athlete.overall) * 2 + abs($1.age - athlete.age)
            return left != right ? left < right : $0.id < $1.id
        }
        .prefix(limit).map { $0 }
    }

    private mutating func announceRace(_ race: TransferRace, title: String, detail: String, suffix: String) {
        let factID = "\(race.factID)-\(suffix)"
        recordFact(WorldFact(id: factID, source: .market, worldDay: worldDay, title: title, detail: detail,
                             playerIDs: [race.playerID], clubIDs: [race.rivalID, race.sellerID], reliability: .confirmed, isPublic: true))
        deliverFact(factID, inbox: .transfer, social: suffix != "gaveup")
    }

    /// Ao trocar de clube, as disputas do clube antigo deixam de existir.
    mutating func cancelTransferRaces() {
        for index in world.projects.transferRaces.indices where world.projects.transferRaces[index].isOpen {
            world.projects.transferRaces[index].status = .cancelled
            resolveCommitment(id: world.projects.transferRaces[index].commitmentID, as: .cancelled)
        }
    }
}
