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
            LinearGradient(colors: [Color(red: 0.02, green: 0.05, blue: 0.22).opacity(0.78), .clear], startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                var state: UInt64 = 0x9E3779B97F4A7C15
                func next() -> CGFloat {
                    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    return CGFloat((state >> 33) % 1000) / 1000
                }
                for _ in 0..<46 {
                    let radius = 0.6 + next() * 1.4
                    context.fill(Path(ellipseIn: CGRect(x: next() * size.width, y: next() * size.height * 0.45, width: radius, height: radius)),
                                 with: .color(.white.opacity(0.35 + next() * 0.5)))
                }
                for x in [size.width * 0.18, size.width * 0.82] {
                    var beam = Path()
                    beam.move(to: CGPoint(x: x, y: 0))
                    beam.addLine(to: CGPoint(x: x - 70, y: size.height * 0.5))
                    beam.addLine(to: CGPoint(x: x + 70, y: size.height * 0.5))
                    beam.closeSubpath()
                    context.fill(beam, with: .color(.white.opacity(0.07)))
                }
            }
            Image(systemName: "moon.stars.fill").font(.system(size: 70)).foregroundStyle(.white.opacity(0.22)).offset(x: 120, y: -270)
        }
    }
}
