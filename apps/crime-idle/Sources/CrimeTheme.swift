import SwiftUI

enum Noir {
    static let ink = Color(red: 0.035, green: 0.04, blue: 0.07)
    static let night = Color(red: 0.075, green: 0.085, blue: 0.135)
    static let raised = Color(red: 0.12, green: 0.13, blue: 0.2)
    static let gold = Color(red: 0.96, green: 0.75, blue: 0.34)
    static let neon = Color(red: 1.0, green: 0.25, blue: 0.45)
    static let cyan = Color(red: 0.32, green: 0.86, blue: 0.96)
    static let violet = Color(red: 0.66, green: 0.48, blue: 1.0)
    static let money = Color(red: 0.38, green: 0.92, blue: 0.56)
    static let ember = Color(red: 1.0, green: 0.55, blue: 0.2)
    static let muted = Color.white.opacity(0.6)

    static let districtTints: [Color] = [gold, cyan, violet, neon, money]

    static func tint(district: Int) -> Color { districtTints[district % districtTints.count] }

    static func heatColor(_ heat: Double) -> Color {
        heat < 35 ? money : (heat < 65 ? ember : neon)
    }
}

struct NoirCard<Content: View>: View {
    var tint: Color = Noir.gold
    var highlighted = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Noir.raised.opacity(0.95), Noir.night], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [tint.opacity(highlighted ? 0.85 : 0.28), Color.white.opacity(0.04)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: highlighted ? 1.5 : 1
                    )
            }
            .shadow(color: highlighted ? tint.opacity(0.28) : .clear, radius: 16)
    }
}

struct NoirButtonStyle: ButtonStyle {
    var tint: Color = Noir.gold
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .footnote.weight(.bold) : .headline.weight(.bold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, compact ? 12 : 18)
            .frame(minHeight: compact ? 40 : 52)
            .frame(maxWidth: compact ? nil : .infinity)
            .foregroundStyle(isEnabled ? Color.black.opacity(0.85) : Color.white.opacity(0.35))
            .background {
                RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
                    .fill(isEnabled
                          ? AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.white.opacity(0.07)))
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct NoirBar: View {
    let progress: Double
    var tint: Color = Noir.gold
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(proxy.size.width * min(max(progress, 0), 1), progress > 0 ? height : 0))
                    .shadow(color: tint.opacity(0.6), radius: 6)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue(CrimeFormat.percent(min(max(progress, 0), 1)))
    }
}

struct NoirChip: View {
    let symbol: String
    let text: String
    var tint: Color = Noir.muted

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            Text(text).font(.caption2.weight(.semibold)).monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

struct NoirSectionTitle: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.heavy)).tracking(2)
                .foregroundStyle(Noir.gold)
            Text(title)
                .font(.system(size: 30, weight: .heavy, design: .serif))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Noir.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Barra superior fixa com os recursos do jogador.
struct NoirResourceBar: View {
    let state: CrimeState

    var body: some View {
        HStack(spacing: 8) {
            resource("dollarsign.circle.fill", CrimeFormat.cash(state.cash), Noir.money, id: "cash-balance")
            resource("star.circle.fill", CrimeFormat.short(state.respect), Noir.gold, id: "respect-balance")
            resource("flame.circle.fill", "\(Int(state.heat))", Noir.heatColor(state.heat), id: "heat-level")
        }
    }

    private func resource(_ symbol: String, _ value: String, _ tint: Color, id: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}

extension View {
    func noirPage(maxWidth: CGFloat = 760) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { self }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(NoirBackdrop().ignoresSafeArea())
    }
}

struct NoirBackdrop: View {
    var body: some View {
        ZStack {
            Noir.ink
            RadialGradient(colors: [Noir.violet.opacity(0.18), .clear], center: .topTrailing, startRadius: 10, endRadius: 420)
            RadialGradient(colors: [Noir.gold.opacity(0.08), .clear], center: .bottomLeading, startRadius: 10, endRadius: 380)
        }
    }
}

/// Medidor semicircular de calor policial.
struct HeatGauge: View {
    let heat: Double

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.5, to: 1)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            Circle()
                .trim(from: 0.5, to: 0.5 + 0.5 * min(max(heat, 0), 100) / 100)
                .stroke(AngularGradient(colors: [Noir.money, Noir.ember, Noir.neon], center: .center,
                                        startAngle: .degrees(180), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .shadow(color: Noir.heatColor(heat).opacity(0.6), radius: 6)
            VStack(spacing: 0) {
                Text("\(Int(heat))")
                    .font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                Text("CALOR").font(.system(size: 9, weight: .heavy)).tracking(1.5).foregroundStyle(Noir.muted)
            }
            .offset(y: -8)
        }
        .frame(width: 96, height: 96)
        .padding(.bottom, -36)
        .accessibilityElement()
        .accessibilityLabel("Calor policial")
        .accessibilityValue("\(Int(heat)) de 100")
    }
}

/// Skyline noir desenhada em Canvas: janelas acendem com o império, chove sempre e o giroflex aparece com calor alto.
struct CitySkyline: View {
    let lit: Double
    let heat: Double
    let districts: Int
    var animated = true

    private static let buildings: [(x: CGFloat, width: CGFloat, height: CGFloat)] = {
        var rng = CrimeRNG(seed: 1931)
        var list: [(x: CGFloat, width: CGFloat, height: CGFloat)] = []
        var x: CGFloat = -0.02
        while x < 1.02 {
            let width = CGFloat(0.06 + rng.unit() * 0.07)
            let height = CGFloat(0.28 + rng.unit() * 0.55)
            list.append((x: x, width: width, height: height))
            x += width + 0.004
        }
        return list
    }()

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    Canvas { context, size in
                        draw(context: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            } else {
                Canvas { context, size in draw(context: &context, size: size, time: 1_000) }
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(context: inout GraphicsContext, size: CGSize, time: Double) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [Color(red: 0.08, green: 0.06, blue: 0.2), Color(red: 0.32, green: 0.12, blue: 0.3), Color(red: 0.95, green: 0.45, blue: 0.3).opacity(0.7)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

        let moon = CGRect(x: size.width * 0.74, y: size.height * 0.1, width: 44, height: 44)
        context.fill(Path(ellipseIn: moon.insetBy(dx: -18, dy: -18)), with: .color(Noir.gold.opacity(0.12)))
        context.fill(Path(ellipseIn: moon), with: .color(Color(red: 1, green: 0.92, blue: 0.75)))

        let litFraction = min(max(lit, 0.04), 1)
        for (index, building) in Self.buildings.enumerated() {
            let height: CGFloat = building.height * size.height * 0.82
            let frame = CGRect(x: building.x * size.width, y: size.height - height, width: building.width * size.width, height: height)
            let shade = 0.05 + Double(index % 3) * 0.02
            context.fill(Path(frame), with: .color(Color(red: shade, green: shade, blue: shade + 0.06)))

            let columns = max(Int(frame.width / 9), 1)
            let rows = max(Int(frame.height / 12), 1)
            for row in 0..<rows {
                for column in 0..<columns {
                    let hash = (index &* 73 &+ row &* 31 &+ column &* 17) % 100
                    guard Double(hash) / 100 < litFraction else { continue }
                    let flicker: Double = sin(time * 0.7 + Double(hash)) > 0.97 ? 0.35 : 1
                    let windowX: CGFloat = frame.minX + 4 + CGFloat(column) * 9
                    let windowY: CGFloat = frame.minY + 6 + CGFloat(row) * 12
                    let window = CGRect(x: windowX, y: windowY, width: 4, height: 6)
                    let color = hash % 7 == 0 ? Noir.cyan : Noir.gold
                    context.fill(Path(window), with: .color(color.opacity(0.85 * flicker)))
                }
            }
        }

        // Letreiro de neon que pisca.
        let neonOn = sin(time * 2.4) > -0.6
        var neon = context
        neon.addFilter(.shadow(color: Noir.neon, radius: neonOn ? 8 : 0))
        neon.draw(Text("NEBLINA").font(.system(size: 15, weight: .black, design: .serif)).foregroundStyle(Noir.neon.opacity(neonOn ? 1 : 0.25)),
                  at: CGPoint(x: size.width * 0.27, y: size.height * 0.36))

        // Giroflex quando a polícia está em cima.
        if heat >= 60 {
            let blue = sin(time * 9) > 0
            let glow = CGRect(x: -size.width * 0.2, y: size.height * 0.55, width: size.width * 1.4, height: size.height * 0.7)
            let strength: Double = 0.18 * min((heat - 50) / 50, 1)
            context.fill(Path(ellipseIn: glow), with: .color((blue ? Color.blue : Color.red).opacity(strength)))
        }

        // Chuva.
        var rain = Path()
        for drop in 0..<70 {
            let seed = Double(drop) * 12.9898
            let x: Double = (sin(seed) * 43_758.5453).truncatingRemainder(dividingBy: 1)
            let speed: Double = 0.6 + (cos(seed) * 0.5 + 0.5) * 0.6
            let y: Double = (time * speed + x * 3).truncatingRemainder(dividingBy: 1)
            let startX: CGFloat = CGFloat(abs(x)) * size.width + CGFloat(y) * 12
            let start = CGPoint(x: startX, y: CGFloat(y) * size.height)
            rain.move(to: start)
            rain.addLine(to: CGPoint(x: start.x - 3, y: start.y + 12))
        }
        context.stroke(rain, with: .color(.white.opacity(0.22)), lineWidth: 1)

        // Névoa no pé dos prédios.
        context.fill(Path(CGRect(x: 0, y: size.height * 0.72, width: size.width, height: size.height * 0.28)),
                     with: .linearGradient(Gradient(colors: [.clear, Noir.ink]), startPoint: CGPoint(x: 0, y: size.height * 0.72),
                                           endPoint: CGPoint(x: 0, y: size.height)))
    }
}
