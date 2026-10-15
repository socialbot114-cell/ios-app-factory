import Foundation

extension FootballVisitStreak {
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
