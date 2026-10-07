import Foundation

/// Sequência de dias em que o app foi aberto: vira um selo pequeno na sala de espera.
enum FootballVisitStreak {
    static let streakKey = "football.visit.streak.v1"
    static let dayKey = "football.visit.lastDay.v1"

    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Regra pura: mesmo dia mantém, dia seguinte soma, qualquer outro recomeça em 1.
    static func next(streak: Int, lastDay: String?, today: String, yesterday: String) -> Int {
        guard let lastDay else { return 1 }
        if lastDay == today { return max(1, streak) }
        if lastDay == yesterday { return max(1, streak) + 1 }
        return 1
    }

    /// Registra a abertura de hoje e devolve a sequência atual. Capturas e UI tests não registram nada.
    @discardableResult
    static func register(now: Date = Date(), defaults: UserDefaults = .standard, calendar: Calendar = .current) -> Int {
        if FactoryCapture.isUITesting || FactoryCapture.screen != nil { return 1 }
        let today = key(for: now, calendar: calendar)
        let before = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let streak = next(streak: defaults.integer(forKey: streakKey), lastDay: defaults.string(forKey: dayKey),
                          today: today, yesterday: key(for: before, calendar: calendar))
        defaults.set(streak, forKey: streakKey)
        defaults.set(today, forKey: dayKey)
        return streak
    }
}
