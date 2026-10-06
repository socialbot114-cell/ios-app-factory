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
    var moment: PhoneMoment = .morning

    var body: some View {
        let color = team?.primaryColor ?? FootballTheme.accent
        ZStack {
            Color.black
            LinearGradient(colors: [color, color.opacity(0.55), Color.black.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: team?.crestSymbol ?? "soccerball").font(.system(size: 220)).foregroundStyle(.white.opacity(0.06))
                .offset(x: 90, y: -230)
            atmosphere
        }
        .animation(.easeInOut(duration: 1.2), value: moment)
        .ignoresSafeArea()
        .accessibilityIdentifier("wallpaper-\(moment.rawValue)")
    }

    @ViewBuilder
    private var atmosphere: some View {
        switch moment {
        case .morning:
            LinearGradient(colors: [Color.white.opacity(0.24), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.5))
            Image(systemName: "sun.horizon.fill").font(.system(size: 120)).foregroundStyle(.white.opacity(0.10)).offset(x: -110, y: -260)
        case .matchAfternoon:
            RadialGradient(colors: [Color.yellow.opacity(0.38), .clear], center: .topTrailing, startRadius: 10, endRadius: 420)
            Image(systemName: "sun.max.fill").font(.system(size: 110)).foregroundStyle(.yellow.opacity(0.22)).offset(x: 120, y: -270)
        case .matchNight:
            // Jogo à noite: luzes do estádio ligadas, mesmo com o relógio na manhã.
            LinearGradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.24).opacity(0.62), .clear], startPoint: .top, endPoint: .center)
            Canvas { context, size in
                for x in [size.width * 0.16, size.width * 0.84] {
                    var beam = Path()
                    beam.move(to: CGPoint(x: x, y: 70))
                    beam.addLine(to: CGPoint(x: x - 55, y: size.height * 0.42))
                    beam.addLine(to: CGPoint(x: x + 55, y: size.height * 0.42))
                    beam.closeSubpath()
                    context.fill(beam, with: .linearGradient(Gradient(colors: [.white.opacity(0.16), .clear]),
                                                             startPoint: CGPoint(x: x, y: 70), endPoint: CGPoint(x: x, y: size.height * 0.42)))
                    context.fill(Path(ellipseIn: CGRect(x: x - 9, y: 62, width: 18, height: 18)), with: .color(.white.opacity(0.85)))
                }
            }
            Image(systemName: "sportscourt.fill").font(.system(size: 80)).foregroundStyle(.white.opacity(0.12)).offset(x: 110, y: -265)
        }
    }
}
