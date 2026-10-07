import Foundation

/// Resumo leve de um slot, lido sem decodificar a carreira inteira.
struct SaveSlotSummary: Codable, Equatable {
    let slot: Int
    let clubID: Int?
    let season: Int
    let matchDay: Int
    let division: Division?
    let updatedAt: Date
    /// Nome do treinador, para o perfil na sala de espera. Saves antigos não têm e mostram "Treinador".
    var coachName: String? = nil
}

/// Saves em arquivo (Application Support), com slots, resumo por slot e backup de arquivos ilegíveis.
struct FootballSaveStore {
    static let slotCount = 3
    static let activeSlotKey = "football.activeSlot"

    let directory: URL
    let defaults: UserDefaults

    init(directory: URL? = nil, defaults: UserDefaults = .standard) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ManagerFutebol", isDirectory: true)
        self.directory = base
        self.defaults = defaults
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    var activeSlot: Int {
        get {
            let value = defaults.integer(forKey: Self.activeSlotKey)
            return (0..<Self.slotCount).contains(value) ? value : 0
        }
        nonmutating set { defaults.set(newValue, forKey: Self.activeSlotKey) }
    }

    func careerURL(slot: Int) -> URL { directory.appendingPathComponent("career-\(slot).json") }
    func summaryURL(slot: Int) -> URL { directory.appendingPathComponent("career-\(slot).summary.json") }
    func backupURL(slot: Int) -> URL { directory.appendingPathComponent("career-\(slot).backup.json") }

    func hasCareer(slot: Int) -> Bool {
        FileManager.default.fileExists(atPath: careerURL(slot: slot).path)
    }

    /// Carrega um slot. Um arquivo ilegível é movido para backup e o slot fica vazio.
    func load(slot: Int) -> FootballCareer? {
        let url = careerURL(slot: slot)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(FootballCareer.self, from: data)
        } catch {
            try? FileManager.default.removeItem(at: backupURL(slot: slot))
            try? FileManager.default.moveItem(at: url, to: backupURL(slot: slot))
            try? FileManager.default.removeItem(at: summaryURL(slot: slot))
            return nil
        }
    }

    @discardableResult
    func save(_ career: FootballCareer, slot: Int, now: Date = Date()) -> Bool {
        guard let data = try? JSONEncoder().encode(career) else { return false }
        do {
            try data.write(to: careerURL(slot: slot), options: .atomic)
            let summary = SaveSlotSummary(slot: slot, clubID: career.selectedClubID, season: career.season,
                                          matchDay: career.matchDayIndex, division: career.userDivision, updatedAt: now,
                                          coachName: career.selectedClubID == nil ? nil : career.world.coach.name)
            if let summaryData = try? JSONEncoder().encode(summary) {
                try summaryData.write(to: summaryURL(slot: slot), options: .atomic)
            }
            return true
        } catch {
            return false
        }
    }

    func summary(slot: Int) -> SaveSlotSummary? {
        guard let data = try? Data(contentsOf: summaryURL(slot: slot)) else { return nil }
        return try? JSONDecoder().decode(SaveSlotSummary.self, from: data)
    }

    func delete(slot: Int) {
        for url in [careerURL(slot: slot), summaryURL(slot: slot)] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func deleteAll() {
        for slot in 0..<Self.slotCount { delete(slot: slot) }
    }

    /// Move o save antigo do UserDefaults (v1/v2) para o slot 1, uma única vez.
    @discardableResult
    func migrateLegacyDefaults() -> Bool {
        guard let data = defaults.data(forKey: FootballCareer.saveKey) else { return false }
        defer { defaults.removeObject(forKey: FootballCareer.saveKey) }
        guard !hasCareer(slot: 0) else { return false }
        guard let career = try? JSONDecoder().decode(FootballCareer.self, from: data) else {
            defaults.set(data, forKey: FootballCareer.backupKey)
            return false
        }
        return save(career, slot: 0)
    }
}
