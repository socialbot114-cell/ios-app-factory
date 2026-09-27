import Foundation
import SwiftUI

// MARK: - Store: múltiplas obras, CRUD, persistência versionada, migração v1

final class AtelierStore: ObservableObject {
    @Published private(set) var instances: [AtelierArtInstance] = []

    static let fileName = "instances-v2.json"
    static let legacyEngineKey = "atelier.engine"

    private var localFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Atelier", isDirectory: true)
    }

    private var documentsFolder: URL { activeFolder() }

    private var useiCloud: Bool { UserDefaults.standard.bool(forKey: "atelier.icloud") }

    private var iCloudFolder: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents/Atelier", isDirectory: true)
    }

    static func iCloudAvailable() -> Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }

    private func activeFolder() -> URL {
        if useiCloud, let ub = iCloudFolder { return ub }
        return localFolder
    }

    /// Liga/desliga iCloud movendo o arquivo (volta ao local se indisponível).
    @discardableResult
    func setiCloudEnabled(_ enabled: Bool) -> Bool {
        let current = storeFile
        UserDefaults.standard.set(enabled, forKey: "atelier.icloud")
        let target = activeFolder().appendingPathComponent(Self.fileName)
        guard current != target else { return true }
        do {
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: current.path) {
                if FileManager.default.fileExists(atPath: target.path) {
                    try FileManager.default.removeItem(at: target)
                }
                try FileManager.default.moveItem(at: current, to: target)
            }
            return true
        } catch {
            UserDefaults.standard.set(!enabled, forKey: "atelier.icloud")
            return false
        }
    }

    private var storeFile: URL { documentsFolder.appendingPathComponent(Self.fileName) }

    init(loadImmediately: Bool = true) {
        if loadImmediately { load() }
    }

    // MARK: load / save

    func load() {
        if let data = try? Data(contentsOf: storeFile),
           let decoded = try? JSONDecoder().decode([AtelierArtInstance].self, from: data) {
            instances = decoded.sorted { $0.updatedAt > $1.updatedAt }
            return
        }
        instances = []
        migrateLegacyIfNeeded()
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: documentsFolder, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(instances)
            try data.write(to: storeFile, options: .atomic)
        } catch {
            // offline-first: falha de disco não derruba a sessão
        }
    }

    // MARK: migração do MVP (1 rascunho em UserDefaults -> 1 instância)

    func migrateLegacyIfNeeded(defaults: UserDefaults = .standard) {
        guard instances.isEmpty else { return }
        guard let data = defaults.data(forKey: Self.legacyEngineKey) else { return }
        struct Legacy: Codable { var fills: [Int: Int] }
        guard let legacy = try? JSONDecoder().decode(Legacy.self, from: data),
              !legacy.fills.isEmpty else { return }
        let mapped = legacy.fills.filter { $0.key >= 0 && $0.key < 9 }
        let instance = AtelierArtInstance(
            artworkId: "jardim-tracos",
            fills: mapped,
            createdAt: Date(),
            updatedAt: Date()
        )
        instances = [instance]
        save()
    }

    // MARK: consultas

    func artwork(for instance: AtelierArtInstance) -> AtelierArtwork {
        AtelierLibrary.artwork(id: instance.artworkId)
    }

    func latestInstance(for artworkId: String) -> AtelierArtInstance? {
        instances.filter { $0.artworkId == artworkId }.max { $0.updatedAt < $1.updatedAt }
    }

    var completedCount: Int {
        instances.filter { !$0.fills.isEmpty }.count
    }

    var favoriteCount: Int { instances.filter { $0.isFavorite }.count }

    var totalMinutes: Int {
        Int(instances.reduce(0) { $0 + $1.totalSeconds } / 60)
    }

    // MARK: mutações

    @discardableResult
    func createInstance(artworkId: String) -> AtelierArtInstance {
        let instance = AtelierArtInstance(artworkId: artworkId)
        instances.insert(instance, at: 0)
        save()
        return instance
    }

    @discardableResult
    func openOrCreate(artworkId: String) -> AtelierArtInstance {
        if let open = instances
            .filter({ $0.artworkId == artworkId })
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first(where: { $0.fills.count < AtelierLibrary.artwork(id: artworkId).regionCount }) {
            return open
        }
        return createInstance(artworkId: artworkId)
    }

    func updateFills(id: UUID, fills: [Int: Int]) {
        guard let i = instances.firstIndex(where: { $0.id == id }) else { return }
        instances[i].fills = fills
        instances[i].updatedAt = Date()
        AtelierStreak.touch()
        save()
    }

    func updateCustomColor(id: UUID, slot: Int, color: Color) {
        guard let i = instances.firstIndex(where: { $0.id == id }) else { return }
        var customs = instances[i].effectiveCustomColors()
        guard (0..<customs.count).contains(slot) else { return }
        customs[slot] = color
        instances[i].customColors = customs.map { AtelierCodableColor($0) }
        instances[i].updatedAt = Date()
        save()
    }

    /// Histórico de undo/redo persistido (cap 20 p/ não inflar o JSON).
    func saveHistory(id: UUID, undo: [[Int: Int]], redo: [[Int: Int]]) {
        guard let i = instances.firstIndex(where: { $0.id == id }) else { return }
        instances[i].history = Array(undo.suffix(20))
        instances[i].redoStack = Array(redo.suffix(20))
        save()
    }

    func history(id: UUID) -> (undo: [[Int: Int]], redo: [[Int: Int]]) {
        guard let inst = instances.first(where: { $0.id == id }) else { return ([], []) }
        return (inst.history, inst.redoStack)
    }

    /// Registra pincelada (base do timelapse; cap 500).
    func addEvent(id: UUID, region: Int, color: Int) {
        guard let i = instances.firstIndex(where: { $0.id == id }) else { return }
        instances[i].events.append(AtelierPaintEvent(region: region, color: color))
        if instances[i].events.count > 500 {
            instances[i].events.removeFirst(instances[i].events.count - 500)
        }
        save()
    }

    func setAlbum(id: UUID, album: String?) {
        guard let i = instances.firstIndex(where: { $0.id == id }) else { return }
        let t = (album ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        instances[i].album = t.isEmpty ? nil : String(t.prefix(40))
        instances[i].updatedAt = Date()
        save()
    }

    var albums: [String] {
        Array(Set(instances.compactMap { $0.album })).sorted()
    }

    func addSeconds(id: UUID, seconds: Double) {
        guard let i = instances.firstIndex(where: { $0.id == id }) else { return }
        instances[i].totalSeconds += max(0, seconds)
        save()
    }

    func rename(id: UUID, title: String) {
        guard let i = instances.firstIndex(where: { $0.id == id }) else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        instances[i].customTitle = t.isEmpty ? nil : String(t.prefix(60))
        instances[i].updatedAt = Date()
        save()
    }

    func toggleFavorite(id: UUID) {
        guard let i = instances.firstIndex(where: { $0.id == id }) else { return }
        instances[i].isFavorite.toggle()
        instances[i].updatedAt = Date()
        save()
    }

    @discardableResult
    func duplicate(id: UUID) -> AtelierArtInstance? {
        guard let src = instances.first(where: { $0.id == id }) else { return nil }
        let copy = AtelierArtInstance(
            artworkId: src.artworkId,
            customTitle: (src.displayTitle(fallback: AtelierLibrary.artwork(id: src.artworkId).title)) + " (cópia)",
            fills: src.fills,
            customColors: src.customColors.isEmpty ? (src.customColor.map { [$0] } ?? []) : src.customColors
        )
        instances.insert(copy, at: 0)
        save()
        return copy
    }

    func delete(id: UUID) {
        instances.removeAll { $0.id == id }
        AtelierThumbCache.remove(id: id)
        save()
    }

    func deleteAll() {
        for inst in instances { AtelierThumbCache.remove(id: inst.id) }
        instances = []
        save()
    }

    // MARK: exports legados (PNGs já salvos no aparelho)

    static var legacyExportedArtURLs: [URL] {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ColoringExports", isDirectory: true)
        return ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}

// MARK: - Sessão de edição (undo/redo ilimitados, testável sem SwiftUI)

struct AtelierEditingSession: Equatable {
    private(set) var fills: [Int: Int] = [:]
    private var undoStack: [[Int: Int]] = []
    private var redoStack: [[Int: Int]] = []
    let regionCount: Int
    let colorCount: Int

    init(regionCount: Int, colorCount: Int = AtelierPalette.totalCount, fills: [Int: Int] = [:]) {
        self.regionCount = regionCount
        self.colorCount = colorCount
        self.fills = fills.filter { $0.key >= 0 && $0.key < regionCount }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var undoHistory: [[Int: Int]] { undoStack }
    var redoHistory: [[Int: Int]] { redoStack }

    mutating func restore(undo: [[Int: Int]], redo: [[Int: Int]]) {
        undoStack = Array(undo.suffix(100))
        redoStack = Array(redo.suffix(100))
    }

    mutating func fill(region: Int, color: Int) {
        guard (0..<regionCount).contains(region), (0..<colorCount).contains(color) else { return }
        guard fills[region] != color else { return }
        pushHistory()
        fills[region] = color
    }

    mutating func clear() {
        guard !fills.isEmpty else { return }
        pushHistory()
        fills = [:]
    }

    mutating func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(fills)
        fills = previous
    }

    mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(fills)
        fills = next
    }

    private mutating func pushHistory() {
        undoStack.append(fills)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack = []
    }
}
