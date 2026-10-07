import SwiftUI

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
            PhoneSignal(fanMood: career.fanMood)
            PhoneBattery(level: career.world.coach.energy)
            Text("\(career.world.coach.energy)%").font(.caption2.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(FootballCalendarClock.longDate(career.gameDay)), temporada \(career.season), energia \(career.world.coach.energy) por cento, humor da torcida \(career.fanMood) de 100")
        .accessibilityHint("A bateria é a sua energia: conversas, agenda e compromissos gastam. As barras de sinal mostram o humor da torcida.")
    }
}

/// Bateria do celular, desenhada com o nível real. No jogo, o nível é a energia do treinador.
struct PhoneBattery: View {
    /// De 0 a 100. Nil enquanto não há dado (perfil vazio ou save antigo): a bateria fica apagada e vazia.
    let level: Int?

    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.white.opacity(level == nil ? 0.3 : 0.6), lineWidth: 1)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Self.tint(level))
                    .frame(width: 18 * Self.fraction(level), height: 7)
                    .padding(.leading, 2)
            }
            .frame(width: 22, height: 11)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.white.opacity(level == nil ? 0.3 : 0.6))
                .frame(width: 2, height: 4)
        }
        .accessibilityHidden(true)
    }

    static func fraction(_ level: Int?) -> CGFloat {
        CGFloat(min(max(level ?? 0, 0), 100)) / 100
    }

    /// Verde acima de 60, amarelo de 30 a 59, vermelho abaixo de 30.
    static func tint(_ level: Int?) -> Color {
        guard let level else { return .white.opacity(0.3) }
        if level >= 60 { return .green }
        if level >= 30 { return .yellow }
        return .red
    }
}

/// Barras de sinal com o humor da torcida. Cada barra acende a partir de um degrau.
struct PhoneSignal: View {
    let fanMood: Int?

    var body: some View {
        let lit = Self.litBars(fanMood)
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(index < lit ? 1 : 0.3))
                    .frame(width: 3, height: CGFloat(5 + index * 3))
            }
        }
        .accessibilityHidden(true)
    }

    /// Degraus em 15, 40, 65 e 90: quantas barras acendem para um humor.
    static func litBars(_ fanMood: Int?) -> Int {
        guard let fanMood else { return 0 }
        return (0..<4).filter { fanMood >= 25 * ($0 + 1) - 10 }.count
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
