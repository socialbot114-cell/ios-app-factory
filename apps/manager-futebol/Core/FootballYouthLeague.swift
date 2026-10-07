import Foundation

// MARK: - Captação por parcerias e campeonato de base

/// Tipo de parceria de captação. A escola traz candidatos baratos; o clube parceiro, menos e de mais qualidade.
enum PartnershipKind: String, Codable, CaseIterable, Identifiable {
    case school, club

    var id: String { rawValue }

    var title: String { self == .school ? "Escola de futebol" : "Clube parceiro" }

    var signCost: Int { self == .school ? 20_000 : 40_000 }

    var upkeep: Int { self == .school ? 15_000 : 30_000 }

    /// Candidatos extras da região a cada chegada anual.
    var bonusCandidates: Int { self == .school ? 1 : 2 }

    var summary: String {
        self == .school ? "Escola: um candidato extra por ano." : "Clube parceiro: dois candidatos extras por ano."
    }
}

struct YouthPartnership: Codable, Equatable, Identifiable {
    let kind: PartnershipKind
    let region: Int

    var id: String { "\(kind.rawValue)-\(region)" }
}

struct YouthLeagueResult: Codable, Equatable, Identifiable {
    let season: Int
    let category: YouthCategory
    let position: Int
    let wins: Int

    var id: String { "\(season)-\(category.rawValue)" }
    var champion: Bool { position == 1 }
}

extension FootballCareer {
    static let maxPartnerships = 4
    static let youthMinutesStarter = 900
    static let youthMinutesBench = 150

    // MARK: Parcerias

    func canSignPartnership(kind: PartnershipKind, region: Int) -> String? {
        guard selectedClubID != nil, !isFired else { return "Sem clube." }
        if academy.partnerships.contains(where: { $0.kind == kind && $0.region == region }) {
            return "Essa parceria já existe nesta região."
        }
        if academy.partnerships.count >= Self.maxPartnerships { return "Limite de \(Self.maxPartnerships) parcerias." }
        if transferBudget < kind.signCost { return "Caixa insuficiente." }
        return nil
    }

    @discardableResult
    mutating func signPartnership(kind: PartnershipKind, region: Int) -> Bool {
        guard canSignPartnership(kind: kind, region: region) == nil else { return false }
        book(.academy, -kind.signCost, "Parceria: \(kind.title)")
        academy.partnerships.append(YouthPartnership(kind: kind, region: region))
        return true
    }

    @discardableResult
    mutating func cancelPartnership(id: String) -> Bool {
        guard academy.partnerships.contains(where: { $0.id == id }) else { return false }
        academy.partnerships.removeAll { $0.id == id }
        return true
    }

    // MARK: Campeonato de base

    /// Campeonato simulado de cada categoria, na metade da temporada: 8 equipes, todos contra todos.
    /// Os 11 melhores da categoria ganham minutos e evoluem mais; quem fica no banco ganha pouco tempo de jogo.
    mutating func runYouthLeague(using random: inout FootballRandom) {
        guard let selectedClubID else { return }
        for category in YouthCategory.allCases {
            guard !academy.leagueResults.contains(where: { $0.season == season && $0.category == category }) else { continue }
            let squad = youth(in: category)
            guard !squad.isEmpty else { continue }
            let ranked = squad.sorted { $0.overall > $1.overall }
            for (rank, player) in ranked.enumerated() {
                academy.minutes[player.id, default: 0] += rank < 11 ? Self.youthMinutesStarter : Self.youthMinutesBench
            }

            let top = ranked.prefix(11).map { Double($0.overall) }
            let padded = top + Array(repeating: 40.0, count: max(0, 11 - top.count))
            let userRating = padded.reduce(0, +) / Double(padded.count)

            var others = FootballSeason.teams.map(\.id).filter { $0 != selectedClubID }
            for index in stride(from: others.count - 1, to: 0, by: -1) { others.swapAt(index, random.int(in: 0...index)) }
            var table: [(id: Int, rating: Double)] = [(selectedClubID, userRating)]
            for id in others.prefix(7) {
                let strength = Double(FootballSeason.team(id)?.strength ?? 65) - 18 + Double(random.int(in: -40...40)) / 10
                table.append((id, strength))
            }

            var wins: [Int: Int] = [:]
            for i in table.indices {
                for j in table.indices where j > i {
                    let probability = 1 / (1 + exp(-(table[i].rating - table[j].rating) / 6))
                    if random.chance(probability) {
                        wins[table[i].id, default: 0] += 1
                    } else {
                        wins[table[j].id, default: 0] += 1
                    }
                }
            }

            let ratings = Dictionary(uniqueKeysWithValues: table.map { ($0.id, $0.rating) })
            let order = table.map { $0.id }.sorted { a, b in
                let winsA = wins[a] ?? 0
                let winsB = wins[b] ?? 0
                if winsA != winsB { return winsA > winsB }
                return (ratings[a] ?? 0) > (ratings[b] ?? 0)
            }
            let position = (order.firstIndex(of: selectedClubID) ?? 0) + 1
            academy.leagueResults.append(YouthLeagueResult(season: season, category: category, position: position, wins: wins[selectedClubID] ?? 0))
            addInbox(.news, title: "Campeonato \(category.title) encerrado",
                     body: position == 1 ? "Seu clube é campeão da categoria \(category.title)." : "Seu clube terminou em \(position)º na categoria \(category.title).")
        }
    }
}
