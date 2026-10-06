import Foundation

/// Datas e horários do mundo do jogo. O calendário de partidas (`FootballSeason.calendar`) guarda só índices;
/// aqui cada dia de jogo ganha uma data real fictícia, para o FutOS mostrar "quarta-feira, 20 de janeiro · 07:30".
/// Tudo é determinístico (sem fuso nem idioma do aparelho) para os saves e os testes serem estáveis.
enum FootballCalendarClock {
    /// Temporada 1 começa em 2027; a rodada 1 cai no primeiro domingo a partir de 17 de janeiro.
    static let firstSeasonYear = 2027
    static let morningHour = 7
    static let morningMinute = 30

    private static let weekdayNames = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"]
    private static let monthNames = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto",
                                     "setembro", "outubro", "novembro", "dezembro"]

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    /// Domingo da primeira rodada da temporada.
    static func seasonStart(season: Int) -> Date {
        let cal = calendar
        let year = firstSeasonYear + max(0, season - 1)
        var date = cal.date(from: DateComponents(year: year, month: 1, day: 17)) ?? Date(timeIntervalSince1970: 0)
        while cal.component(.weekday, from: date) != 1 {
            date = cal.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }

    /// Meia-noite do dia do jogo. Rodadas de liga caem no domingo; fases da copa, na quarta seguinte.
    /// Índices além do calendário (temporada encerrada) seguem uma semana após o último dia de jogo.
    static func day(season: Int, matchDay index: Int) -> Date {
        let slots = FootballSeason.calendar
        let cal = calendar
        let start = seasonStart(season: season)
        guard let last = slots.last else { return start }
        let slot = slots.indices.contains(index) ? slots[index] : last
        var offset = (slot.week - 4) * 7
        if slot.isMidweek { offset -= 4 }
        if index >= slots.count { offset += 7 * (index - slots.count + 1) }
        return cal.date(byAdding: .day, value: offset, to: start) ?? start
    }

    /// Dia com horário. `hour`/`minute` padrão: início da manhã, quando o treinador abre o celular.
    static func moment(season: Int, matchDay index: Int, hour: Int = morningHour, minute: Int = morningMinute) -> Date {
        let cal = calendar
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day(season: season, matchDay: index))
            ?? day(season: season, matchDay: index)
    }

    /// Horário da bola rolando: domingo à tarde, quarta à noite.
    static func kickoff(season: Int, matchDay index: Int) -> Date {
        let midweek = FootballSeason.calendar.indices.contains(index) ? FootballSeason.calendar[index].isMidweek : false
        return moment(season: season, matchDay: index, hour: midweek ? 21 : 16, minute: midweek ? 30 : 0)
    }

    static func daysBetween(_ from: Date, _ to: Date) -> Int {
        let cal = calendar
        return cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: to)).day ?? 0
    }

    // MARK: Texto

    static func weekdayName(_ date: Date) -> String { weekdayNames[(calendar.component(.weekday, from: date) - 1) % 7] }

    /// "Qua", "Dom"…
    static func weekdayShort(_ date: Date) -> String {
        let name = weekdayName(date)
        return String(name.prefix(3)).capitalized
    }

    static func monthShort(_ date: Date) -> String { String(monthNames[calendar.component(.month, from: date) - 1].prefix(3)) }

    /// "quarta-feira, 20 de janeiro"
    static func longDate(_ date: Date) -> String {
        let cal = calendar
        return "\(weekdayName(date)), \(cal.component(.day, from: date)) de \(monthNames[cal.component(.month, from: date) - 1])"
    }

    /// "Qua, 20 jan"
    static func shortDate(_ date: Date) -> String {
        "\(weekdayShort(date)), \(calendar.component(.day, from: date)) \(monthShort(date))"
    }

    /// "20/01/2027"
    static func numericDate(_ date: Date) -> String {
        let cal = calendar
        return String(format: "%02d/%02d/%04d", cal.component(.day, from: date), cal.component(.month, from: date), cal.component(.year, from: date))
    }

    /// "07:30"
    static func clock(_ date: Date) -> String {
        let cal = calendar
        return String(format: "%02d:%02d", cal.component(.hour, from: date), cal.component(.minute, from: date))
    }
}

extension FootballCareer {
    /// Dia do jogo (meia-noite) em que a carreira está agora.
    var gameDay: Date { FootballCalendarClock.day(season: season, matchDay: matchDayIndex) }

    /// Momento exibido no celular: início da manhã do dia atual.
    var gameMoment: Date { FootballCalendarClock.moment(season: season, matchDay: matchDayIndex) }

    /// Data de um dia de jogo da temporada atual (ex.: prazos e mensagens).
    func gameDate(matchDay index: Int, season ofSeason: Int? = nil) -> Date {
        FootballCalendarClock.day(season: ofSeason ?? season, matchDay: index)
    }

    /// Data curta de um "dia do jogo" absoluto (prazos): `worldDay` conta os dias de jogo desde a temporada 1.
    func shortDate(worldDay day: Int) -> String {
        let perSeason = FootballSeason.matchDaysPerSeason
        let safe = max(0, day)
        return FootballCalendarClock.shortDate(FootballCalendarClock.day(season: safe / perSeason + 1, matchDay: safe % perSeason))
    }

    /// Data curta de um dia de jogo, para listas ("Qua, 20 jan").
    func shortDate(matchDay index: Int, season ofSeason: Int? = nil) -> String {
        FootballCalendarClock.shortDate(gameDate(matchDay: index, season: ofSeason))
    }
}
