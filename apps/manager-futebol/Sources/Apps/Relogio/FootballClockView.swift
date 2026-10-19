import SwiftUI

/// App Relógio: a data do jogo e as contagens até a próxima partida, a janela de transferências e o fim da temporada.
struct FootballClockView: View {
    let career: FootballCareer

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FootballScreenHeader(career: career, title: "Calendário do jogo",
                                 subtitle: "O tempo só anda de jogo em jogo. Aqui estão as próximas datas.")
            FactoryPanel(title: "Agora", systemImage: "clock.fill") {
                Text(FootballCalendarClock.clock(career.gameMoment))
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                Text(FootballCalendarClock.longDate(career.gameMoment).capitalized)
                    .font(.headline)
                Text("Temporada \(career.season) · \(career.isSeasonComplete ? "campanha encerrada" : "dia de jogo \(career.matchDayIndex + 1) de \(FootballSeason.matchDaysPerSeason)")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("clock-now")
            ForEach(career.clockItems) { item in
                FactoryPanel {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.symbol).font(.title3).foregroundStyle(FootballTheme.accent).frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.headline)
                            Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        if item.days != nil {
                            Text(item.whenText).font(.subheadline.weight(.bold)).foregroundStyle(FootballTheme.accent)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("clock-\(item.id)")
            }
        }
        .factoryPage()
        .navigationTitle("Relógio")
        .accessibilityIdentifier("clock-app")
    }
}
