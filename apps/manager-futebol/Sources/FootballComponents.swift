import SwiftUI

enum FootballTheme {
    static let accent = Color(red: 0.06, green: 0.47, blue: 0.30)
    static let pitchTop = Color(red: 0.13, green: 0.50, blue: 0.29)
    static let pitchBottom = Color(red: 0.08, green: 0.39, blue: 0.22)
    static let gold = Color(red: 0.85, green: 0.64, blue: 0.16)
}

extension LeagueTeam {
    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red, green: green, blue: blue)
    }

    var primaryColor: Color {
        switch id {
        case 0: return Self.rgb(0.95, 0.55, 0.10)
        case 1: return Self.rgb(0.72, 0.11, 0.14)
        case 2: return Self.rgb(0.05, 0.42, 0.70)
        case 3: return Self.rgb(0.16, 0.18, 0.22)
        case 4: return Self.rgb(0.10, 0.25, 0.55)
        case 5: return Self.rgb(0.00, 0.50, 0.48)
        case 6: return Self.rgb(0.45, 0.20, 0.55)
        case 7: return Self.rgb(0.16, 0.55, 0.24)
        case 8: return Self.rgb(0.00, 0.62, 0.78)
        case 9: return Self.rgb(0.62, 0.36, 0.16)
        case 10: return Self.rgb(0.33, 0.47, 0.18)
        case 11: return Self.rgb(0.92, 0.72, 0.05)
        case 12: return Self.rgb(0.18, 0.36, 0.78)
        case 13: return Self.rgb(0.50, 0.12, 0.16)
        case 14: return Self.rgb(0.85, 0.30, 0.10)
        case 15: return Self.rgb(0.10, 0.30, 0.42)
        case 16: return Self.rgb(0.30, 0.30, 0.32)
        case 17: return Self.rgb(0.70, 0.55, 0.20)
        case 18: return Self.rgb(0.12, 0.40, 0.30)
        default: return Self.rgb(0.55, 0.15, 0.40)
        }
    }

    var secondaryColor: Color {
        switch id {
        case 0, 3, 13, 16: return Self.rgb(0.98, 0.86, 0.40)
        case 1, 4, 5, 8, 12, 14, 19: return .white
        case 2, 15: return Self.rgb(0.55, 0.85, 0.95)
        case 6: return Self.rgb(0.95, 0.78, 0.20)
        case 9: return Self.rgb(0.98, 0.92, 0.75)
        case 11: return Self.rgb(0.20, 0.30, 0.15)
        case 17: return Self.rgb(0.20, 0.18, 0.12)
        default: return Self.rgb(0.92, 0.96, 0.88)
        }
    }

    var crestSymbol: String {
        switch id {
        case 0: return "sun.max.fill"
        case 1: return "leaf.fill"
        case 2: return "water.waves"
        case 3: return "mountain.2.fill"
        case 4: return "star.fill"
        case 5: return "ferry.fill"
        case 6: return "tree.fill"
        case 7: return "laurel.leading"
        case 8: return "sailboat.fill"
        case 9: return "sun.dust.fill"
        case 10: return "fish.fill"
        case 11: return "camera.macro"
        case 12: return "drop.fill"
        case 13: return "flame.fill"
        case 14: return "bolt.fill"
        case 15: return "wind"
        case 16: return "bird.fill"
        case 17: return "diamond.fill"
        case 18: return "tree.circle.fill"
        default: return "crown.fill"
        }
    }
}

extension Division {
    var tint: Color { self == .serieA ? FootballTheme.accent : .indigo }
}

struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        path.move(to: CGPoint(x: rect.minX + width * 0.5, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + height * 0.12))
        path.addCurve(to: CGPoint(x: rect.minX + width * 0.5, y: rect.maxY),
                      control1: CGPoint(x: rect.maxX, y: rect.minY + height * 0.62),
                      control2: CGPoint(x: rect.minX + width * 0.78, y: rect.minY + height * 0.86))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + height * 0.12),
                      control1: CGPoint(x: rect.minX + width * 0.22, y: rect.minY + height * 0.86),
                      control2: CGPoint(x: rect.minX, y: rect.minY + height * 0.62))
        path.closeSubpath()
        return path
    }
}

struct ClubCrest: View {
    let team: LeagueTeam
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            ShieldShape()
                .fill(LinearGradient(colors: [team.primaryColor, team.primaryColor.opacity(0.78)], startPoint: .top, endPoint: .bottom))
            ShieldShape()
                .strokeBorderCompat(team.secondaryColor, lineWidth: max(1.5, size * 0.06))
            VStack(spacing: size * 0.02) {
                Image(systemName: team.crestSymbol)
                    .font(.system(size: size * 0.3, weight: .bold))
                Text(team.shortName)
                    .font(.system(size: size * 0.2, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(team.secondaryColor)
            .offset(y: -size * 0.04)
        }
        .frame(width: size, height: size * 1.12)
        .accessibilityHidden(true)
    }
}

private extension Shape {
    func strokeBorderCompat(_ color: Color, lineWidth: CGFloat) -> some View {
        stroke(color, lineWidth: lineWidth)
            .padding(lineWidth / 2)
    }
}

struct RatingBadge: View {
    let value: Int
    var size: CGFloat = 34

    private var tint: Color {
        switch value {
        case 82...: return FootballTheme.gold
        case 75..<82: return FootballTheme.accent
        case 68..<75: return .blue
        default: return .gray
        }
    }

    var body: some View {
        Text("\(value)")
            .font(.system(size: size * 0.44, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityLabel("Geral \(value)")
    }
}

struct ConditionBar: View {
    let value: Int

    static func color(for value: Int) -> Color {
        switch value {
        case 80...: return .green
        case 65..<80: return .yellow
        case 50..<65: return .orange
        default: return .red
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule().fill(Self.color(for: value))
                    .frame(width: proxy.size.width * CGFloat(max(0, min(100, value))) / 100)
            }
        }
        .frame(height: 5)
        .accessibilityLabel("Energia \(value)%")
    }
}

struct FormBadges: View {
    let results: [FootballResult]

    var body: some View {
        HStack(spacing: 3) {
            if results.isEmpty {
                Text("sem jogos").font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                Text(result.rawValue)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
                    .background(color(result), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(results.isEmpty ? "Sem jogos" : "Forma: " + results.map(\.rawValue).joined(separator: " "))
    }

    private func color(_ result: FootballResult) -> Color {
        switch result {
        case .win: return .green
        case .draw: return .gray
        case .loss: return .red
        }
    }
}

struct StatComparisonRow: View {
    let title: String
    let home: Double
    let away: Double
    let homeText: String
    let awayText: String
    var homeColor: Color = FootballTheme.accent
    var awayColor: Color = .gray

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(homeText).font(.subheadline.weight(.bold).monospacedDigit())
                Spacer()
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(awayText).font(.subheadline.weight(.bold).monospacedDigit())
            }
            GeometryReader { proxy in
                let total = max(home + away, 0.0001)
                HStack(spacing: 3) {
                    Capsule().fill(homeColor).frame(width: max(4, (proxy.size.width - 3) * home / total))
                    Capsule().fill(awayColor.opacity(0.7))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(homeText) contra \(awayText)")
    }
}

struct PillLabel: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = FootballTheme.accent

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

/// Campinho tático com os titulares distribuídos pelas linhas da formação.
struct PitchView: View {
    let formation: FootballFormation
    let starters: [FootballPlayer]
    var onTap: ((FootballPlayer) -> Void)? = nil

    private var rows: [[FootballPlayer?]] {
        var remaining = starters
        var slots: [[FootballPlayer?]] = formation.pitchRows.map { row in
            row.map { position -> FootballPlayer? in
                guard let index = remaining.firstIndex(where: { $0.position == position }) else { return nil }
                return remaining.remove(at: index)
            }
        }
        for rowIndex in slots.indices {
            for slotIndex in slots[rowIndex].indices where slots[rowIndex][slotIndex] == nil && !remaining.isEmpty {
                slots[rowIndex][slotIndex] = remaining.removeFirst()
            }
        }
        return slots
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [FootballTheme.pitchTop, FootballTheme.pitchBottom], startPoint: .top, endPoint: .bottom))
            PitchMarkings()
                .stroke(Color.white.opacity(0.28), lineWidth: 1.5)
                .padding(10)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated().reversed()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 4) {
                        ForEach(Array(row.enumerated()), id: \.offset) { slotIndex, player in
                            PitchToken(player: player, expectedPosition: formation.pitchRows[rowIndex][slotIndex]) {
                                if let player { onTap?(player) }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
        }
        .frame(height: 400)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Campo tático, formação \(formation.rawValue)")
    }
}

private struct PitchToken: View {
    let player: FootballPlayer?
    let expectedPosition: FootballPosition
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(player == nil ? Color.white.opacity(0.15) : Color.white)
                        .frame(width: 42, height: 42)
                    Circle()
                        .trim(from: 0, to: CGFloat(player?.condition ?? 0) / 100)
                        .stroke(ConditionBar.color(for: player?.condition ?? 0), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 48, height: 48)
                    if let player {
                        Text("\(player.overall)")
                            .font(.system(size: 15, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(FootballTheme.pitchBottom)
                    } else {
                        Image(systemName: "plus").foregroundStyle(.white)
                    }
                    if let player, player.position != expectedPosition {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                            .offset(x: 18, y: -18)
                    }
                    if player?.isInjured == true {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .offset(x: -18, y: -18)
                    }
                }
                Text(player?.lastName ?? expectedPosition.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.28), in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.map { "\($0.name), \($0.position.rawValue), geral \($0.overall), energia \($0.condition)%" } ?? "Vaga vazia")
    }
}

private struct PitchMarkings: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: 12, height: 12))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        let radius = min(rect.width, rect.height) * 0.12
        path.addEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2))
        let boxWidth = rect.width * 0.5
        let boxHeight = rect.height * 0.12
        path.addRect(CGRect(x: rect.midX - boxWidth / 2, y: rect.minY, width: boxWidth, height: boxHeight))
        path.addRect(CGRect(x: rect.midX - boxWidth / 2, y: rect.maxY - boxHeight, width: boxWidth, height: boxHeight))
        return path
    }
}

/// Linha padrão de atleta usada em elenco, mercado e substituições.
struct PlayerRow: View {
    let player: FootballPlayer
    var isStarter = false
    var showValue = false

    var body: some View {
        HStack(spacing: 12) {
            RatingBadge(value: player.overall)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(player.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if player.isInjured {
                        PillLabel(text: "\(player.injuryRounds)R", systemImage: "cross.case.fill", tint: .red)
                    }
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                ConditionBar(value: player.condition).frame(maxWidth: 140)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                if isStarter { PillLabel(text: "TITULAR") }
                if showValue {
                    Text(FootballFormat.money(player.marketValue)).font(.caption.weight(.semibold)).foregroundStyle(FootballTheme.accent)
                } else {
                    Text("\(player.condition)%").font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(ConditionBar.color(for: player.condition))
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        "\(player.position.rawValue) · \(player.age) anos · POT \(player.potential)"
    }
}
