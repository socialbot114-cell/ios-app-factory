import SwiftUI

// MARK: - Segmento e categoria

enum AtelierSegment: String, Codable, CaseIterable, Identifiable {
    case infantil
    case relaxar

    var id: String { rawValue }
    var title: String {
        switch self {
        case .infantil: return "Crianças"
        case .relaxar: return "Relaxar"
        }
    }
    var systemImage: String {
        switch self {
        case .infantil: return "balloon.fill"
        case .relaxar: return "leaf.fill"
        }
    }
}

enum AtelierCategory: String, Codable, CaseIterable, Identifiable {
    case natureza
    case mandalas
    case brasilia
    case animais
    case aventura
    case vitral

    var id: String { rawValue }
    var title: String {
        switch self {
        case .natureza: return "Natureza"
        case .mandalas: return "Mandalas"
        case .brasilia: return "Brasília"
        case .animais: return "Animais"
        case .aventura: return "Aventura"
        case .vitral: return "Vitral"
        }
    }
}

// MARK: - Kind (cada case = 1 arte do catálogo, sem licenciamento)

enum AtelierArtKind: String, Codable, CaseIterable {
    case flower9
    case sunburst8
    case mosaic44
    case mosaic36
    case mosaic28
    case radial10x2
    case radial16x3
    case radial12x5
    case radial8x5
    case mosaic67
    case mosaic66
    case radial13x4

    var regionCount: Int {
        switch self {
        case .flower9: return 9
        case .sunburst8: return 11
        case .mosaic44: return 16
        case .mosaic36: return 18
        case .mosaic28: return 16
        case .radial10x2: return 21
        case .radial16x3: return 49
        case .radial12x5: return 61
        case .radial8x5: return 41
        case .mosaic67: return 42
        case .mosaic66: return 36
        case .radial13x4: return 53
        }
    }

    var mosaicRows: Int {
        switch self {
        case .mosaic44: return 4
        case .mosaic36: return 3
        case .mosaic28: return 2
        case .mosaic67: return 6
        case .mosaic66: return 6
        default: return 0
        }
    }

    var mosaicCols: Int {
        switch self {
        case .mosaic44: return 4
        case .mosaic36: return 6
        case .mosaic28: return 8
        case .mosaic67: return 7
        case .mosaic66: return 6
        default: return 0
        }
    }

    var radialPetals: Int {
        switch self {
        case .radial10x2: return 10
        case .radial16x3: return 16
        case .radial12x5: return 12
        case .radial8x5: return 8
        case .radial13x4: return 13
        default: return 0
        }
    }

    var radialRings: Int {
        switch self {
        case .radial10x2: return 2
        case .radial16x3: return 3
        case .radial12x5: return 5
        case .radial8x5: return 5
        case .radial13x4: return 4
        default: return 0
        }
    }

    var isMosaic: Bool { mosaicRows > 0 }
    var isRadial: Bool { radialPetals > 0 }
}

// MARK: - Definição da arte

struct AtelierArtwork: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var subtitle: String
    var category: AtelierCategory
    var segment: AtelierSegment
    var kind: AtelierArtKind

    var regionCount: Int { kind.regionCount }
}

// MARK: - Cor custom codificável

struct AtelierCodableColor: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(_ color: Color) {
        let ui = UIColor(color)
        var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 1
        ui.getRed(&rr, green: &gg, blue: &bb, alpha: &aa)
        self.init(r: Double(rr), g: Double(gg), b: Double(bb), a: Double(aa))
    }

    var color: Color { Color(red: r, green: g, blue: b, opacity: a) }
}

// MARK: - Evento de pintura (base do timelapse)

struct AtelierPaintEvent: Codable, Equatable {
    var region: Int
    var color: Int
    var at: Date

    init(region: Int, color: Int, at: Date = Date()) {
        self.region = region
        self.color = color
        self.at = at
    }
}

// MARK: - Instância (obra do usuário)

struct AtelierArtInstance: Identifiable, Equatable {
    var id: UUID
    var artworkId: String
    var customTitle: String?
    var fills: [Int: Int]
    var customColor: AtelierCodableColor?
    var customColors: [AtelierCodableColor]
    var album: String?
    var history: [[Int: Int]]
    var redoStack: [[Int: Int]]
    var events: [AtelierPaintEvent]
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    var totalSeconds: Double

    init(
        id: UUID = UUID(),
        artworkId: String,
        customTitle: String? = nil,
        fills: [Int: Int] = [:],
        customColor: AtelierCodableColor? = nil,
        customColors: [AtelierCodableColor] = [],
        album: String? = nil,
        history: [[Int: Int]] = [],
        redoStack: [[Int: Int]] = [],
        events: [AtelierPaintEvent] = [],
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        totalSeconds: Double = 0
    ) {
        self.id = id
        self.artworkId = artworkId
        self.customTitle = customTitle
        self.fills = fills
        self.customColor = customColor
        self.customColors = customColors
        self.album = album
        self.history = history
        self.redoStack = redoStack
        self.events = events
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.totalSeconds = totalSeconds
    }

    /// Cores personalizadas efetivas (sempre 4 slots).
    func effectiveCustomColors() -> [Color] {
        var out = customColors.map { $0.color }
        if out.isEmpty, let legacy = customColor { out = [legacy.color] }
        while out.count < AtelierPalette.customCount { out.append(AtelierPalette.defaultCustom) }
        return Array(out.prefix(AtelierPalette.customCount))
    }

    func customColorAt(_ slot: Int) -> Color {
        let all = effectiveCustomColors()
        guard (0..<all.count).contains(slot) else { return AtelierPalette.defaultCustom }
        return all[slot]
    }

    func progress(regionCount: Int) -> Double {
        guard regionCount > 0 else { return 0 }
        return min(1, Double(fills.count) / Double(regionCount))
    }

    var isComplete: Bool { !fills.isEmpty }

    func displayTitle(fallback: String) -> String {
        let t = (customTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallback : t
    }
}

// Arquivos v2 antigos não têm as chaves novas — decode tolerante.
extension AtelierArtInstance: Codable {
    enum CodingKeys: String, CodingKey {
        case id, artworkId, customTitle, fills, customColor, customColors, album
        case history, redoStack, events, isFavorite, createdAt, updatedAt, totalSeconds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        artworkId = try c.decode(String.self, forKey: .artworkId)
        customTitle = try c.decodeIfPresent(String.self, forKey: .customTitle)
        fills = try c.decodeIfPresent([Int: Int].self, forKey: .fills) ?? [:]
        customColor = try c.decodeIfPresent(AtelierCodableColor.self, forKey: .customColor)
        customColors = try c.decodeIfPresent([AtelierCodableColor].self, forKey: .customColors) ?? []
        album = try c.decodeIfPresent(String.self, forKey: .album)
        history = try c.decodeIfPresent([[Int: Int]].self, forKey: .history) ?? []
        redoStack = try c.decodeIfPresent([[Int: Int]].self, forKey: .redoStack) ?? []
        events = try c.decodeIfPresent([AtelierPaintEvent].self, forKey: .events) ?? []
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        totalSeconds = try c.decodeIfPresent(Double.self, forKey: .totalSeconds) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(artworkId, forKey: .artworkId)
        try c.encodeIfPresent(customTitle, forKey: .customTitle)
        try c.encode(fills, forKey: .fills)
        try c.encodeIfPresent(customColor, forKey: .customColor)
        try c.encode(customColors, forKey: .customColors)
        try c.encodeIfPresent(album, forKey: .album)
        try c.encode(history, forKey: .history)
        try c.encode(redoStack, forKey: .redoStack)
        try c.encode(events, forKey: .events)
        try c.encode(isFavorite, forKey: .isFavorite)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(totalSeconds, forKey: .totalSeconds)
    }
}

// MARK: - Paleta (12 cores — cumpre o brief sem licença)

enum AtelierPalette {
    static let customCount = 4
    static let fixedCount = 12
    /// Índices 12-15 são os 4 slots personalizados.
    static var customIndices: Range<Int> { fixedCount..<(fixedCount + customCount) }
    static var totalCount: Int { fixedCount + customCount }

    static let colors: [Color] = [
        Color(red: 0.99, green: 0.42, blue: 0.33), // 0 Coral
        Color(red: 0.10, green: 0.43, blue: 0.48), // 1 Azul petróleo
        Color(red: 0.98, green: 0.75, blue: 0.28), // 2 Amarelo
        Color(red: 0.56, green: 0.40, blue: 0.72), // 3 Violeta
        Color(red: 0.38, green: 0.67, blue: 0.48), // 4 Verde
        Color(red: 0.98, green: 0.57, blue: 0.32), // 5 Laranja
        Color(red: 0.94, green: 0.42, blue: 0.62), // 6 Rosa
        Color(red: 0.32, green: 0.62, blue: 0.94), // 7 Azul céu
        Color(red: 0.55, green: 0.38, blue: 0.25), // 8 Marrom cerrado
        Color(red: 0.16, green: 0.45, blue: 0.30), // 9 Verde mata
        Color(red: 0.45, green: 0.52, blue: 0.60), // 10 Cinza azulado
        Color(red: 0.20, green: 0.20, blue: 0.22), // 11 Grafite
    ]

    static let names = [
        "Coral", "Azul petróleo", "Amarelo", "Violeta", "Verde", "Laranja",
        "Rosa", "Azul céu", "Marrom cerrado", "Verde mata", "Cinza azulado", "Grafite",
    ]

    static let defaultCustom = Color(red: 0.85, green: 0.25, blue: 0.55)

    static func color(for index: Int, customs: [Color]) -> Color {
        if customIndices.contains(index) {
            let slot = index - fixedCount
            guard (0..<customs.count).contains(slot) else { return defaultCustom }
            return customs[slot]
        }
        guard (0..<colors.count).contains(index) else { return .white }
        return colors[index]
    }

    static func color(for index: Int, custom: Color) -> Color {
        if customIndices.contains(index) { return custom }
        guard (0..<colors.count).contains(index) else { return .white }
        return colors[index]
    }

    static func name(for index: Int) -> String {
        if customIndices.contains(index) { return "Personalizada \(index - fixedCount + 1)" }
        guard (0..<names.count).contains(index) else { return "Branco" }
        return names[index]
    }

    static var maxFixedIndex: Int { colors.count - 1 }
}
