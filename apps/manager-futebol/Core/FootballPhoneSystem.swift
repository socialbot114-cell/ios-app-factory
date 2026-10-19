import Foundation

// MARK: - Modos de Foco

/// Modo de Foco do celular: filtra os avisos por assunto. Avisos urgentes (coletiva, crise) passam sempre.
enum PhoneFocusMode: String, Codable, CaseIterable, Identifiable {
    case none, game, rest, business

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Nenhum"
        case .game: return "Dia de jogo"
        case .rest: return "Descanso"
        case .business: return "Negócios"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "bell.fill"
        case .game: return "sportscourt.fill"
        case .rest: return "moon.fill"
        case .business: return "briefcase.fill"
        }
    }

    var summary: String {
        switch self {
        case .none: return "Todos os avisos chegam."
        case .game: return "Só tática, partida, mercado, liga e acontecimentos."
        case .rest: return "Só o que é urgente."
        case .business: return "Só clube, banco, marca, negócios, contatos e mensagens."
        }
    }

    /// Apps que podem avisar neste modo; nil deixa todos.
    var allowedAppIDs: Set<String>? {
        switch self {
        case .none: return nil
        case .game: return ["manager", "squad", "league", "market", "alerts", "club"]
        case .rest: return []
        case .business: return ["club", "bank", "brand", "business", "contacts", "messages"]
        }
    }
}

// MARK: - Pastas na tela inicial

struct PhoneFolder: Codable, Equatable, Identifiable {
    /// "folder:1", "folder:2"... Os ids de pasta e de app dividem a mesma lista de ordem da tela inicial.
    var id: String
    var name: String
    var appIDs: [String]
}

extension PhonePreferences {
    static let folderPrefix = "folder:"
    static let folderNameLimit = 18

    static func isFolder(_ id: String) -> Bool { id.hasPrefix(folderPrefix) }

    func folder(_ id: String) -> PhoneFolder? { homeFolders?.first { $0.id == id } }

    /// Itens da grade da tela inicial na ordem escolhida: apps fora de pastas e as pastas.
    func homeItemIDs(factory: [String]) -> [String] {
        let folders = (homeFolders ?? []).filter { !$0.appIDs.isEmpty }
        let foldered = Set(folders.flatMap(\.appIDs))
        let base = factory.filter { !foldered.contains($0) } + folders.map(\.id)
        return Self.ordered(base, custom: homeOrder)
    }

    /// Cria uma pasta com os apps indicados, no lugar do primeiro deles. Devolve o id, ou nil se nenhum app serve.
    @discardableResult
    mutating func createFolder(with apps: [String], factory: [String], name: String? = nil) -> String? {
        let alreadyFiled = Set((homeFolders ?? []).flatMap(\.appIDs))
        let valid = apps.filter { factory.contains($0) && !alreadyFiled.contains($0) }
        guard let first = valid.first else { return nil }
        let items = homeItemIDs(factory: factory)
        var folders = homeFolders ?? []
        let number = (folders.compactMap { Int($0.id.dropFirst(Self.folderPrefix.count)) }.max() ?? 0) + 1
        let id = "\(Self.folderPrefix)\(number)"
        folders.append(PhoneFolder(id: id, name: Self.cleanName(name) ?? "Pasta \(number)", appIDs: valid))
        // A pasta ocupa o lugar do primeiro app; os demais saem da grade.
        var order = items.map { $0 == first ? id : $0 }.filter { !valid.contains($0) || $0 == id }
        if !order.contains(id) { order.append(id) }
        homeFolders = folders
        homeOrder = order
        return id
    }

    mutating func addToFolder(app: String, folder id: String, factory: [String]) {
        guard factory.contains(app), var folders = homeFolders, let index = folders.firstIndex(where: { $0.id == id }) else { return }
        for other in folders.indices { folders[other].appIDs.removeAll { $0 == app } }
        folders[index].appIDs.append(app)
        homeFolders = folders.filter { !$0.appIDs.isEmpty }
        homeOrder = (homeOrder ?? []).filter { $0 != app }
    }

    /// Tira o app da pasta: ele volta à grade, no fim.
    mutating func removeFromFolder(app: String) {
        guard var folders = homeFolders else { return }
        for index in folders.indices { folders[index].appIDs.removeAll { $0 == app } }
        let emptied = folders.filter(\.appIDs.isEmpty).map(\.id)
        folders.removeAll { $0.appIDs.isEmpty }
        homeFolders = folders.isEmpty ? nil : folders
        homeOrder = (homeOrder ?? []).filter { !emptied.contains($0) }
        if !(homeOrder ?? []).isEmpty { homeOrder = (homeOrder ?? []) + [app] }
    }

    mutating func renameFolder(_ id: String, to name: String) {
        guard let cleaned = Self.cleanName(name), var folders = homeFolders, let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = cleaned
        homeFolders = folders
    }

    /// Desfaz a pasta: os apps voltam à grade.
    mutating func deleteFolder(_ id: String) {
        guard var folders = homeFolders, let folder = folders.first(where: { $0.id == id }) else { return }
        folders.removeAll { $0.id == id }
        homeFolders = folders.isEmpty ? nil : folders
        let order = (homeOrder ?? []).filter { $0 != id }
        homeOrder = order.isEmpty ? nil : order + folder.appIDs
    }

    private static func cleanName(_ name: String?) -> String? {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(folderNameLimit))
    }
}

// MARK: - Notas do treinador

struct CoachNote: Codable, Equatable, Identifiable {
    let id: Int
    let season: Int
    let matchDay: Int
    var text: String
}

extension FootballCareer {
    static let noteLimit = 50
    static let noteCharacterLimit = 280

    var coachNotes: [CoachNote] { (world.phone.notes ?? []).sorted { $0.id > $1.id } }

    /// Guarda uma anotação (a mais nova primeiro). Texto vazio não vira nota.
    @discardableResult
    mutating func addNote(_ text: String) -> CoachNote? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let id = world.phone.nextNoteID ?? 1
        let note = CoachNote(id: id, season: season, matchDay: matchDayIndex, text: String(trimmed.prefix(Self.noteCharacterLimit)))
        var notes = world.phone.notes ?? []
        notes.append(note)
        if notes.count > Self.noteLimit { notes.removeFirst(notes.count - Self.noteLimit) }
        world.phone.notes = notes
        world.phone.nextNoteID = id + 1
        return note
    }

    mutating func deleteNote(id: Int) {
        guard var notes = world.phone.notes else { return }
        notes.removeAll { $0.id == id }
        world.phone.notes = notes.isEmpty ? nil : notes
    }
}

// MARK: - Clima da partida

/// Clima de um jogo. Por enquanto é só apresentação: não muda o resultado nem nenhuma regra.
enum MatchWeather: String, Codable, CaseIterable {
    case clear, cloudy, rain

    var title: String {
        switch self {
        case .clear: return "Céu aberto"
        case .cloudy: return "Nublado"
        case .rain: return "Chuva"
        }
    }

    var symbol: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        }
    }

    /// Chance de chuva por região do mandante (0 Norte, 1 Nordeste, 2 Centro-Oeste, 3 Sudeste, 4 Sul), na estação dos jogos.
    static func rainChance(region: Int) -> Double {
        switch region {
        case 0: return 0.42
        case 1: return 0.20
        case 2: return 0.32
        case 3: return 0.30
        default: return 0.26
        }
    }
}

extension FootballCareer {
    /// O clima de cada jogo é sorteado uma vez, pela partida e pela região do mandante: o mesmo jogo tem sempre o mesmo clima.
    func weather(for fixture: LeagueFixture) -> MatchWeather {
        var random = FootballRandom(seed: matchSeed(stream: .world, id: 91_000 + fixture.id))
        let roll = random.unit()
        let region = FootballSeason.team(fixture.home)?.region ?? 3
        let rain = MatchWeather.rainChance(region: region)
        if roll < rain { return .rain }
        if roll < rain + 0.25 { return .cloudy }
        return .clear
    }
}

// MARK: - Relógio

/// Uma contagem do app Relógio.
struct ClockItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    /// Dias de calendário até o evento, quando faz sentido.
    let days: Int?

    var whenText: String {
        guard let days else { return "" }
        return days <= 0 ? "Hoje" : "em \(FootballFormat.plural(days, "dia", "dias"))"
    }
}

extension FootballCareer {
    /// As próximas contagens do calendário do jogo: partida, janela de transferências e fim da temporada.
    var clockItems: [ClockItem] {
        guard selectedClubID != nil else { return [] }
        var items: [ClockItem] = []
        let today = gameDay
        if let fixture = nextUserFixture, let selectedClubID {
            let kickoff = FootballCalendarClock.kickoff(season: season, matchDay: fixture.matchDay)
            let rival = FootballSeason.teamName(fixture.opponent(of: selectedClubID))
            let days = FootballCalendarClock.daysBetween(today, FootballCalendarClock.day(season: season, matchDay: fixture.matchDay))
            items.append(ClockItem(id: "match", title: "Próximo jogo",
                                   detail: "\(rival) · \(FootballCalendarClock.shortDate(kickoff)) · \(FootballCalendarClock.clock(kickoff))",
                                   symbol: "sportscourt.fill", days: days))
        }
        if let window = transferWindow {
            let closes = FootballCalendarClock.day(season: season, matchDay: window.endDay)
            items.append(ClockItem(id: "window", title: "Janela aberta",
                                   detail: "\(window.title) fecha em \(FootballCalendarClock.shortDate(closes))",
                                   symbol: "arrow.left.arrow.right", days: FootballCalendarClock.daysBetween(today, closes)))
        } else if !isSeasonComplete {
            let next = TransferWindow.midseason.start
            if matchDayIndex < next {
                let opens = FootballCalendarClock.day(season: season, matchDay: next)
                items.append(ClockItem(id: "window", title: "Próxima janela",
                                       detail: "Meio do ano, a partir de \(FootballCalendarClock.shortDate(opens))",
                                       symbol: "arrow.left.arrow.right", days: FootballCalendarClock.daysBetween(today, opens)))
            } else {
                items.append(ClockItem(id: "window", title: "Próxima janela",
                                       detail: "Pré-temporada, no começo da próxima temporada", symbol: "arrow.left.arrow.right", days: nil))
            }
        }
        if !isSeasonComplete, let last = FootballSeason.calendar.last {
            let end = FootballCalendarClock.day(season: season, matchDay: last.index)
            let left = FootballSeason.matchDaysPerSeason - matchDayIndex
            items.append(ClockItem(id: "season", title: "Fim da temporada",
                                   detail: "\(FootballFormat.plural(left, "dia de jogo", "dias de jogo")) até \(FootballCalendarClock.shortDate(end))",
                                   symbol: "flag.checkered", days: FootballCalendarClock.daysBetween(today, end)))
        }
        return items
    }
}
