import SwiftUI

// MARK: - Inicialização do sistema

struct PhoneBootView: View {
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Image(systemName: "soccerball.inverse").font(.system(size: 64)).foregroundStyle(.white)
                Text("FutOS").font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                ProgressView(value: progress).tint(.white).frame(width: 160)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.1)) { progress = 1 } }
        .accessibilityLabel("Iniciando o FutOS")
    }
}

// MARK: - Barra de status

struct PhoneStatusBar: View {
    let career: FootballCareer

    var body: some View {
        HStack(spacing: 10) {
            Text("\(FootballCalendarClock.shortDate(career.gameDay)) · \(FootballCalendarClock.clock(career.gameMoment))")
                .font(.caption.weight(.bold).monospacedDigit())
                .accessibilityIdentifier("status-date")
            Spacer()
            if let club = career.selectedClub { ClubCrest(team: club, size: 16) }
            Spacer()
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule().fill(Color.white.opacity(career.fanMood >= 25 * (index + 1) - 10 ? 1 : 0.3)).frame(width: 3, height: CGFloat(5 + index * 3))
                }
            }
            Image(systemName: career.world.coach.energy >= 60 ? "battery.100" : (career.world.coach.energy >= 30 ? "battery.50" : "battery.25"))
                .font(.caption)
            Text("\(career.world.coach.energy)%").font(.caption2.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(FootballCalendarClock.longDate(career.gameDay)), temporada \(career.season), energia \(career.world.coach.energy) por cento, humor da torcida \(career.fanMood) de 100")
        .accessibilityHint("A bateria é a sua energia: conversas, agenda e compromissos gastam. As barras de sinal mostram o humor da torcida.")
    }
}


struct PhoneWallpaper: View {
    let team: LeagueTeam?

    var body: some View {
        let color = team?.primaryColor ?? FootballTheme.accent
        ZStack {
            Color.black
            LinearGradient(colors: [color, color.opacity(0.55), Color.black.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: team?.crestSymbol ?? "soccerball").font(.system(size: 220)).foregroundStyle(.white.opacity(0.06))
                .offset(x: 90, y: -230)
        }
        .ignoresSafeArea()
    }
}
