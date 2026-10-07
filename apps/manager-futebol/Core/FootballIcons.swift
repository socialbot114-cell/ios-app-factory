import Foundation

// MARK: - Craques eternos

/// Seis cartas lendárias: uma chega em pacote a cada fim de temporada (joga a temporada seguinte inteira) e, no modo Fácil,
/// o usuário também pode convidar uma delas para uma única partida.
enum IconCard: String, Codable, CaseIterable, Identifiable {
    case yashin, garrincha, zagallo, beckenbauer, charlton, eusebio

    var id: String { rawValue }

    /// Faixa de ids reservada para os craques; nenhum atleta gerado chega perto dela.
    static let playerIDBase = 900_000

    var playerID: Int { Self.playerIDBase + (Self.allCases.firstIndex(of: self) ?? 0) + 1 }

    static func card(forPlayerID id: Int) -> IconCard? {
        allCases.first { $0.playerID == id }
    }

    var name: String {
        switch self {
        case .yashin: return "Lev Yashin"
        case .garrincha: return "Mané Garrincha"
        case .zagallo: return "Mário Jorge Lobo Zagallo"
        case .beckenbauer: return "Franz Beckenbauer"
        case .charlton: return "Sir Bobby Charlton"
        case .eusebio: return "Eusébio"
        }
    }

    /// Nome curto para botões e avisos.
    var shortName: String {
        switch self {
        case .yashin: return "Yashin"
        case .garrincha: return "Garrincha"
        case .zagallo: return "Zagallo"
        case .beckenbauer: return "Beckenbauer"
        case .charlton: return "Charlton"
        case .eusebio: return "Eusébio"
        }
    }

    var country: String {
        switch self {
        case .yashin: return "Rússia"
        case .garrincha, .zagallo: return "Brasil"
        case .beckenbauer: return "Alemanha"
        case .charlton: return "Inglaterra"
        case .eusebio: return "Portugal"
        }
    }

    var position: FootballPosition {
        switch self {
        case .yashin: return .goalkeeper
        case .beckenbauer: return .defender
        case .zagallo, .charlton: return .midfielder
        case .garrincha, .eusebio: return .forward
        }
    }

    var detail: PositionDetail {
        switch self {
        case .yashin: return .goalkeeper
        case .beckenbauer: return .centreBack
        case .zagallo: return .attackingMid
        case .charlton: return .centralMid
        case .garrincha: return .winger
        case .eusebio: return .striker
        }
    }

    /// Geral impresso na carta.
    var overall: Int {
        switch self {
        case .yashin: return 94
        case .garrincha: return 95
        case .zagallo: return 91
        case .beckenbauer: return 93
        case .charlton: return 92
        case .eusebio: return 94
        }
    }

    /// Nome do imageset (já redimensionado) em Assets.xcassets.
    var assetName: String {
        switch self {
        case .yashin: return "LegendYashin"
        case .garrincha: return "LegendGarrincha"
        case .zagallo: return "LegendZagallo"
        case .beckenbauer: return "LegendBeckenbauer"
        case .charlton: return "LegendCharlton"
        case .eusebio: return "LegendEusebio"
        }
    }

    /// Rótulo e valor dos seis números da carta, na ordem impressa.
    var stats: [(label: String, value: Int)] {
        switch self {
        case .yashin: return [("DEF", 95), ("REF", 92), ("POS", 90), ("SAÍ", 91), ("COM", 88), ("LID", 93)]
        case .garrincha: return [("VEL", 96), ("DRI", 92), ("FIN", 90), ("PAS", 88), ("DEF", 54), ("FÍS", 82)]
        case .zagallo: return [("VEL", 88), ("FIN", 87), ("PAS", 92), ("DRI", 90), ("DEF", 86), ("FÍS", 89)]
        case .beckenbauer: return [("DEF", 92), ("FÍS", 88), ("PAS", 91), ("CON", 90), ("VEL", 87), ("LID", 92)]
        case .charlton: return [("FIN", 88), ("PAS", 91), ("CON", 87), ("DEF", 85), ("FÍS", 86), ("LID", 90)]
        case .eusebio: return [("FIN", 95), ("VEL", 92), ("DRI", 88), ("PAS", 87), ("DEF", 53), ("FÍS", 89)]
        }
    }

    var accessibilityText: String {
        "\(name), \(detail.title), \(country), geral \(overall)"
    }
}

/// Estado dos craques eternos na carreira.
struct IconState: Codable, Equatable {
    /// Carta de um pacote fechado, esperando o usuário abrir.
    var pendingPack: IconCard? = nil
    /// Craque da temporada atual (vem do pacote do fim da temporada anterior).
    var seasonIcon: IconCard? = nil
    /// Convidado de uma única partida (modo Fácil).
    var guest: IconCard? = nil
    /// Cartas que já passaram pelo clube, para o pacote priorizar as que faltam.
    var collected: [IconCard] = []
}

extension FootballPlayer {
    var isIcon: Bool { IconCard.card(forPlayerID: id) != nil }
}

extension FootballCareer {
    /// Cartas que o usuário pode chamar como convidado agora (o craque da temporada já está no elenco).
    var guestChoices: [IconCard] {
        IconCard.allCases.filter { $0 != iconState.seasonIcon }
    }

    /// Só no modo Fácil, com o clube ativo e fora de uma partida em andamento.
    var canPickGuest: Bool {
        difficulty == .easy && selectedClubID != nil && liveMatch == nil && !isFired
    }

    // MARK: Elenco

    func makeIconPlayer(_ card: IconCard, teamID: Int?) -> FootballPlayer {
        var random = FootballRandom(seed: UInt64(card.playerID) &* 0x9E37_79B9_7F4A_7C15)
        var player = FootballSeason.makePlayer(id: card.playerID, position: card.position, detail: card.detail, age: 31,
                                               overall: card.overall, potential: card.overall, teamID: teamID,
                                               season: season, using: &random)
        player.name = card.name
        player.setOverall(card.overall)
        player.condition = 100
        player.morale = 92
        player.marketValue = 0
        player.contract = PlayerContract(wage: 0, endSeason: season, status: .key)
        return player
    }

    /// Põe o craque no elenco e no lugar do titular mais fraco da mesma posição.
    private mutating func installIcon(_ card: IconCard) {
        guard let selectedClubID else { return }
        if let index = players.firstIndex(where: { $0.id == card.playerID }) {
            players[index].teamID = selectedClubID
            players[index].condition = 100
            players[index].injuryRounds = 0
        } else {
            players.append(makeIconPlayer(card, teamID: selectedClubID))
        }
        guard !startingXI.contains(card.playerID) else { return }
        let sameGroup = startingXI.compactMap { player($0) }.filter { $0.position == card.position }
        if let weakest = sameGroup.min(by: { $0.overall < $1.overall }),
           let slot = startingXI.firstIndex(of: weakest.id) {
            startingXI[slot] = card.playerID
        } else {
            repairLineup()
        }
    }

    private mutating func removeIcon(_ card: IconCard) {
        let id = card.playerID
        players.removeAll { $0.id == id }
        startingXI.removeAll { $0 == id }
        startingXIAtKickoff.remove(id)
        playerRoles[id] = nil
        if leaderID == id { leaderID = nil }
        offers.removeAll { $0.playerID == id }
        repairLineup()
    }

    // MARK: Pacote de fim de temporada

    /// Sorteia a carta do pacote, priorizando as que o clube ainda não teve.
    mutating func grantIconPack() {
        var random = FootballRandom(seed: matchSeed(stream: .offseason, id: 700 + season))
        let missing = IconCard.allCases.filter { !iconState.collected.contains($0) }
        iconState.pendingPack = random.pick(missing.isEmpty ? IconCard.allCases : missing)
        if let card = iconState.pendingPack {
            addInbox(.news, title: "Pacote de craque eterno", body: "Um pacote com \(card.name) chegou ao clube. Abra no painel do Gestor: ele joga a temporada inteira com você.")
        }
    }

    /// Abre o pacote: o craque entra no elenco pela temporada.
    @discardableResult
    mutating func openIconPack() -> IconCard? {
        guard let card = iconState.pendingPack, selectedClubID != nil, liveMatch == nil, !isFired else { return nil }
        iconState.pendingPack = nil
        iconState.seasonIcon = card
        if !iconState.collected.contains(card) { iconState.collected.append(card) }
        if iconState.guest == card { iconState.guest = nil }
        installIcon(card)
        return card
    }

    /// Fim da temporada: o craque do pacote se despede antes do envelhecimento e das aposentadorias.
    mutating func expireSeasonIcon() {
        if let guest = iconState.guest {
            iconState.guest = nil
            removeIcon(guest)
        }
        if let card = iconState.seasonIcon {
            iconState.seasonIcon = nil
            removeIcon(card)
        }
    }

    // MARK: Convidado de uma partida (modo Fácil)

    /// Escolhe (ou troca, ou tira com `nil`) o craque convidado da próxima partida.
    @discardableResult
    mutating func selectGuest(_ card: IconCard?) -> Bool {
        guard canPickGuest else { return false }
        if let card, card == iconState.seasonIcon { return false }
        if let current = iconState.guest {
            iconState.guest = nil
            removeIcon(current)
        }
        guard let card else { return true }
        iconState.guest = card
        if !iconState.collected.contains(card) { iconState.collected.append(card) }
        installIcon(card)
        return true
    }

    /// Troca de clube: o convidado vai embora e o craque da temporada acompanha o treinador.
    mutating func followManager(toClub clubID: Int) {
        if let guest = iconState.guest {
            iconState.guest = nil
            players.removeAll { $0.id == guest.playerID }
        }
        if let card = iconState.seasonIcon, let index = players.firstIndex(where: { $0.id == card.playerID }) {
            players[index].teamID = clubID
        }
    }

    /// O convidado vale uma partida: sai do elenco quando o dia de jogo termina.
    mutating func expireGuestIcon() {
        guard let guest = iconState.guest else { return }
        iconState.guest = nil
        removeIcon(guest)
    }
}
