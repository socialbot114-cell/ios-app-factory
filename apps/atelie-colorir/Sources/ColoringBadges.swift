import Foundation

// MARK: - Selos, sequência e obra do dia (tudo local)

struct AtelierBadge: Identifiable, Equatable {
    var id: String
    var title: String
    var systemImage: String
    var earned: Bool
}

enum AtelierBadges {
    static func earned(store: AtelierStore) -> [AtelierBadge] {
        let painted = store.instances.filter { !$0.fills.isEmpty }
        let fullMandala = painted.contains {
            let art = AtelierLibrary.artwork(id: $0.artworkId)
            return art.category == .mandalas && $0.fills.count >= art.regionCount
        }
        let fullVitral = painted.contains {
            let art = AtelierLibrary.artwork(id: $0.artworkId)
            return art.category == .vitral && $0.fills.count >= art.regionCount
        }
        return [
            AtelierBadge(id: "primeira", title: "Primeira arte", systemImage: "paintbrush.pointed.fill", earned: painted.count >= 1),
            AtelierBadge(id: "seis", title: "Seis cores vivas", systemImage: "square.stack.3d.up.fill", earned: painted.count >= 6),
            AtelierBadge(id: "doze", title: "Coleção completa", systemImage: "crown.fill", earned: painted.count >= 12),
            AtelierBadge(id: "mandala", title: "Mestre das mandalas", systemImage: "circle.hexagonpath.fill", earned: fullMandala),
            AtelierBadge(id: "vitral", title: "Luz do vitral", systemImage: "sun.max.fill", earned: fullVitral),
            AtelierBadge(id: "hora", title: "1 hora de ateliê", systemImage: "clock.fill", earned: store.totalMinutes >= 60),
            AtelierBadge(id: "streak7", title: "7 dias criando", systemImage: "flame.fill", earned: AtelierStreak.current() >= 7),
        ]
    }
}

enum AtelierStreak {
    private static var day: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static func current(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: "atelier.streak")
    }

    /// Chamado a cada atividade de pintura; injeta data p/ testes.
    static func touch(defaults: UserDefaults = .standard, today: String? = nil) {
        let now = today ?? day
        let last = defaults.string(forKey: "atelier.lastPaintDay")
        if last == now { return }
        var streak = defaults.integer(forKey: "atelier.streak")
        if let last, let lastDate = Self.date(last), let nowDate = Self.date(now) {
            let diff = Calendar.current.dateComponents([.day], from: lastDate, to: nowDate).day ?? 0
            streak = (diff == 1) ? streak + 1 : 1
        } else {
            streak = max(streak, 1)
        }
        defaults.set(now, forKey: "atelier.lastPaintDay")
        defaults.set(streak, forKey: "atelier.streak")
    }

    private static func date(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
}

extension AtelierLibrary {
    /// Arte rotativa do dia (determinística por data).
    static func artworkOfTheDay(today: Date = Date()) -> AtelierArtwork {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: today) ?? 1
        return artworks[day % artworks.count]
    }
}
