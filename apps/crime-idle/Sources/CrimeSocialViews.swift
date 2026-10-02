import SwiftUI

// MARK: - Retratos noir

struct CrimePortraitStyle {
    enum Hat { case none, fedora, cap }
    enum Hair { case none, bun, short, bob, sides }
    enum Extra { case glasses, monocle, mustache, beard, cigar, earrings, lipstick }

    let skin: Color
    let hairColor: Color
    let coat: Color
    let hat: Hat
    let hair: Hair
    let extras: Set<Extra>

    static func forMember(_ id: Int) -> CrimePortraitStyle {
        let ebony = Color(red: 0.36, green: 0.23, blue: 0.17)
        let brown = Color(red: 0.55, green: 0.36, blue: 0.24)
        let tan = Color(red: 0.78, green: 0.58, blue: 0.42)
        let pale = Color(red: 0.92, green: 0.76, blue: 0.64)
        let black = Color(red: 0.08, green: 0.07, blue: 0.08)
        let gray = Color(white: 0.78)
        switch id {
        case 0: return .init(skin: brown, hairColor: gray, coat: Color(red: 0.3, green: 0.16, blue: 0.24), hat: .none, hair: .bun, extras: [.glasses, .earrings])
        case 1: return .init(skin: tan, hairColor: black, coat: Color(red: 0.16, green: 0.25, blue: 0.3), hat: .cap, hair: .none, extras: [.mustache])
        case 2: return .init(skin: pale, hairColor: Color(red: 0.3, green: 0.2, blue: 0.12), coat: Color(red: 0.14, green: 0.14, blue: 0.22), hat: .none, hair: .short, extras: [.glasses])
        case 3: return .init(skin: ebony, hairColor: black, coat: Color(red: 0.1, green: 0.1, blue: 0.12), hat: .none, hair: .none, extras: [.beard])
        case 4: return .init(skin: tan, hairColor: Color(red: 0.55, green: 0.12, blue: 0.16), coat: Color(red: 0.42, green: 0.08, blue: 0.2), hat: .none, hair: .bob, extras: [.earrings, .lipstick])
        case 5: return .init(skin: pale, hairColor: gray, coat: Color(red: 0.24, green: 0.2, blue: 0.14), hat: .none, hair: .sides, extras: [.glasses, .beard])
        case 6: return .init(skin: brown, hairColor: black, coat: Color(red: 0.07, green: 0.07, blue: 0.1), hat: .fedora, hair: .none, extras: [])
        default: return .init(skin: tan, hairColor: gray, coat: Color(red: 0.12, green: 0.18, blue: 0.14), hat: .fedora, hair: .none, extras: [.cigar, .mustache])
        }
    }
}

/// Busto desenhado em vetor: luz de contorno na cor do personagem, como num cartaz de filme noir.
struct CrimePortrait: View {
    let memberID: Int
    let tint: Color
    var revealed = true

    var body: some View {
        Canvas { context, size in
            draw(context: &context, size: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(tint.opacity(revealed ? 0.9 : 0.3), lineWidth: 2))
        .overlay {
            if !revealed {
                Text("?").font(.system(size: 28, weight: .black, design: .serif)).foregroundStyle(tint.opacity(0.8))
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
        let unit = size.width / 100
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: x * unit, y: y * unit, width: w * unit, height: h * unit)
        }
        let style = CrimePortraitStyle.forMember(memberID)
        let shadow = Color.black
        let skin = revealed ? style.skin : shadow
        let hairColor = revealed ? style.hairColor : shadow
        let coat = revealed ? style.coat : shadow

        context.fill(Path(rect(0, 0, 100, 100)), with: .radialGradient(
            Gradient(colors: [tint.opacity(revealed ? 0.55 : 0.2), Noir.ink]),
            center: CGPoint(x: 50 * unit, y: 40 * unit), startRadius: 0, endRadius: 70 * unit))

        // Cabelo atrás da cabeça.
        if style.hair == .bob {
            context.fill(Path(roundedRect: rect(27, 22, 46, 46), cornerRadius: 18 * unit), with: .color(hairColor))
        }
        if style.hair == .bun {
            context.fill(Path(ellipseIn: rect(41, 9, 18, 16)), with: .color(hairColor))
        }

        // Ombros e casaco.
        let shoulders = Path(ellipseIn: rect(10, 70, 80, 64))
        context.fill(shoulders, with: .color(coat))
        context.stroke(shoulders, with: .color(tint.opacity(revealed ? 0.8 : 0.4)), lineWidth: 1.5 * unit)
        var collar = Path()
        collar.move(to: CGPoint(x: 42 * unit, y: 71 * unit))
        collar.addLine(to: CGPoint(x: 50 * unit, y: 86 * unit))
        collar.addLine(to: CGPoint(x: 58 * unit, y: 71 * unit))
        collar.closeSubpath()
        context.fill(collar, with: .color(revealed ? Color(white: 0.9) : shadow))
        context.fill(Path(rect(48, 75, 4, 12)), with: .color(revealed ? tint : shadow))

        // Pescoço e cabeça.
        context.fill(Path(rect(43, 56, 14, 16)), with: .color(skin.opacity(0.85)))
        context.fill(Path(ellipseIn: rect(32, 22, 36, 42)), with: .color(skin))
        // Sombra lateral dura, típica de luz noir.
        var side = context
        side.clip(to: Path(ellipseIn: rect(32, 22, 36, 42)))
        side.fill(Path(rect(52, 18, 20, 50)), with: .color(.black.opacity(0.28)))

        switch style.hair {
        case .short:
            context.fill(Path(roundedRect: rect(31, 19, 38, 14), cornerRadius: 7 * unit), with: .color(hairColor))
        case .bun, .bob:
            context.fill(Path(roundedRect: rect(31, 20, 38, 13), cornerRadius: 8 * unit), with: .color(hairColor))
        case .sides:
            context.fill(Path(ellipseIn: rect(29, 34, 8, 14)), with: .color(hairColor))
            context.fill(Path(ellipseIn: rect(63, 34, 8, 14)), with: .color(hairColor))
        case .none:
            break
        }

        guard revealed else {
            drawHat(style.hat, context: &context, rect: rect, color: shadow)
            return
        }

        // Olhos com brilho.
        let eyeY: CGFloat = style.hat == .fedora ? 40 : 41
        context.fill(Path(ellipseIn: rect(40, eyeY, 5, 3)), with: .color(.white))
        context.fill(Path(ellipseIn: rect(55, eyeY, 5, 3)), with: .color(.white))
        context.fill(Path(ellipseIn: rect(41.5, eyeY + 0.3, 2.4, 2.4)), with: .color(.black))
        context.fill(Path(ellipseIn: rect(56.5, eyeY + 0.3, 2.4, 2.4)), with: .color(.black))

        let mouthColor = style.extras.contains(.lipstick) ? Noir.neon : Color.black.opacity(0.55)
        context.fill(Path(roundedRect: rect(44, 54, 12, style.extras.contains(.lipstick) ? 3.5 : 2), cornerRadius: 1.5 * unit), with: .color(mouthColor))

        if style.extras.contains(.mustache) {
            context.fill(Path(roundedRect: rect(42, 50, 16, 3.5), cornerRadius: 2 * unit), with: .color(hairColor))
        }
        if style.extras.contains(.beard) {
            var beard = Path()
            beard.addArc(center: CGPoint(x: 50 * unit, y: 50 * unit), radius: 17 * unit, startAngle: .degrees(15), endAngle: .degrees(165), clockwise: false)
            context.stroke(beard, with: .color(hairColor), lineWidth: 5 * unit)
        }
        if style.extras.contains(.glasses) {
            let lens = Color.white.opacity(0.85)
            context.stroke(Path(ellipseIn: rect(37.5, eyeY - 3, 10, 9)), with: .color(lens), lineWidth: 1.4 * unit)
            context.stroke(Path(ellipseIn: rect(52.5, eyeY - 3, 10, 9)), with: .color(lens), lineWidth: 1.4 * unit)
            context.fill(Path(rect(47.5, eyeY + 1, 5, 1.2)), with: .color(lens))
        }
        if style.extras.contains(.monocle) {
            context.stroke(Path(ellipseIn: rect(52.5, eyeY - 3, 10, 9)), with: .color(Noir.gold), lineWidth: 1.4 * unit)
        }
        if style.extras.contains(.earrings) {
            context.fill(Path(ellipseIn: rect(30, 47, 4, 4)), with: .color(Noir.gold))
            context.fill(Path(ellipseIn: rect(66, 47, 4, 4)), with: .color(Noir.gold))
        }
        if style.extras.contains(.cigar) {
            context.fill(Path(roundedRect: rect(55, 54, 14, 3), cornerRadius: 1 * unit), with: .color(Color(red: 0.45, green: 0.28, blue: 0.16)))
            var ember = context
            ember.addFilter(.shadow(color: Noir.ember, radius: 3 * unit))
            ember.fill(Path(ellipseIn: rect(68, 54, 3, 3)), with: .color(Noir.ember))
            var smoke = Path()
            smoke.move(to: CGPoint(x: 70 * unit, y: 52 * unit))
            smoke.addCurve(to: CGPoint(x: 74 * unit, y: 30 * unit), control1: CGPoint(x: 78 * unit, y: 46 * unit),
                           control2: CGPoint(x: 66 * unit, y: 38 * unit))
            context.stroke(smoke, with: .color(.white.opacity(0.35)), lineWidth: 1.2 * unit)
        }
        drawHat(style.hat, context: &context, rect: rect, color: Color(red: 0.12, green: 0.11, blue: 0.13))
    }

    private func drawHat(_ hat: CrimePortraitStyle.Hat, context: inout GraphicsContext,
                         rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect, color: Color) {
        switch hat {
        case .fedora:
            context.fill(Path(ellipseIn: rect(20, 28, 60, 10)), with: .color(color))
            context.fill(Path(roundedRect: rect(32, 10, 36, 23), cornerRadius: 8), with: .color(color))
            context.fill(Path(rect(32, 26, 36, 4)), with: .color(revealed ? tint : color))
        case .cap:
            context.fill(Path(roundedRect: rect(30, 17, 40, 15), cornerRadius: 9), with: .color(color))
            context.fill(Path(ellipseIn: rect(30, 27, 46, 7)), with: .color(color))
        case .none:
            break
        }
    }
}

// MARK: - Card para compartilhar

struct CrimeShareCard: View {
    let eyebrow: String
    let headline: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CitySkyline(lit: 0.8, heat: 0, districts: 5, animated: false)
            LinearGradient(colors: [.clear, Noir.ink.opacity(0.95)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 13, weight: .heavy)).tracking(2.5).foregroundStyle(tint)
                Text(headline)
                    .font(.system(size: 34, weight: .black, design: .serif)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(value)
                    .font(.system(size: 46, weight: .heavy, design: .rounded)).foregroundStyle(tint)
                    .minimumScaleFactor(0.5).lineLimit(1)
                Text(detail).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                HStack(spacing: 6) {
                    Image(systemName: "hat.widebrim.fill")
                    Text("CRIME IDLE · CIDADE NEBLINA").tracking(1.5)
                }
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Noir.gold)
                .padding(.top, 10)
            }
            .padding(26)
        }
        .frame(width: 360, height: 450)
        .background(Noir.ink)
        .environment(\.colorScheme, .dark)
    }
}

struct CrimeShareButton: View {
    let card: CrimeShareCard
    var tint: Color = Noir.gold
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview(card.headline, image: image)) {
                    Label("Compartilhar", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(NoirButtonStyle(tint: tint, compact: true))
                .accessibilityIdentifier("share-card")
            } else {
                ProgressView().frame(height: 40)
            }
        }
        .task { render() }
    }

    @MainActor private func render() {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let uiImage = renderer.uiImage { image = Image(uiImage: uiImage) }
    }
}

// MARK: - Celebração de patente

struct CrimeRankUpView: View {
    let rankIndex: Int
    let dismiss: () -> Void
    @State private var revealed = false

    private var rank: CrimeRank { CrimeRank.ladder[rankIndex] }

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea().onTapGesture(perform: dismiss)
            VStack(spacing: 14) {
                ZStack {
                    ForEach(0..<12, id: \.self) { ray in
                        Capsule()
                            .fill(Noir.gold.opacity(0.35))
                            .frame(width: 4, height: revealed ? 70 : 10)
                            .offset(y: -78)
                            .rotationEffect(.degrees(Double(ray) * 30))
                    }
                    Image(systemName: "seal.fill")
                        .font(.system(size: 92))
                        .foregroundStyle(LinearGradient(colors: [Noir.gold, Noir.ember], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Noir.gold.opacity(0.7), radius: 24)
                    Text("\(rankIndex + 1)")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Noir.ink)
                }
                .frame(height: 200)
                .scaleEffect(revealed ? 1 : 0.4)
                .rotationEffect(.degrees(revealed ? 0 : -40))
                Text("NOVA PATENTE").font(.caption.weight(.heavy)).tracking(3).foregroundStyle(Noir.gold)
                Text(rank.title)
                    .font(.system(size: 38, weight: .black, design: .serif))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("rank-up-title")
                Text("A cidade inteira já sussurra seu nome.").foregroundStyle(Noir.muted)
                HStack(spacing: 10) {
                    CrimeShareButton(card: CrimeShareCard(eyebrow: "Nova patente", headline: rank.title,
                                                          value: "Nível \(rankIndex + 1)", detail: "Subi na hierarquia da Cidade Neblina.",
                                                          tint: Noir.gold))
                    Button("Continuar", action: dismiss)
                        .buttonStyle(NoirButtonStyle(tint: Color.white.opacity(0.8), compact: true))
                        .accessibilityIdentifier("dismiss-rank-up")
                }
            }
            .padding(28)
            .frame(maxWidth: 420)
            .background(Noir.night, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Noir.gold.opacity(0.6), lineWidth: 1.5))
            .padding(24)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { revealed = true } }
    }
}

// MARK: - Envelope diário

struct CrimeDailyView: View {
    let store: CrimeGameStore
    let dismiss: () -> Void

    private var today: Int { CrimeState.dayNumber(Date()) }

    var body: some View {
        let state = store.state
        let reward = state.nextDailyReward(today: today)
        let claim = store.dailyClaim
        return ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: claim == nil ? "envelope.fill" : "envelope.open.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Noir.gold)
                    .shadow(color: Noir.gold.opacity(0.6), radius: 18)
                    .symbolEffect(.bounce, value: claim != nil)
                Text("O ENVELOPE DO PADRINHO").font(.caption.weight(.heavy)).tracking(2).foregroundStyle(Noir.gold)
                Text(claim == nil ? "Dia \(reward.day) da sequência" : "Bom trabalho, afilhado.")
                    .font(.system(size: 26, weight: .black, design: .serif))
                HStack(spacing: 6) {
                    ForEach(CrimeDailyReward.cycle, id: \.day) { day in
                        let done = claim.map { day.day <= $0.reward.day } ?? (day.day < reward.day)
                        let current = day.day == reward.day
                        VStack(spacing: 4) {
                            Image(systemName: day.day == 7 ? "crown.fill" : (done ? "checkmark" : "envelope.fill"))
                                .font(.system(size: 13, weight: .bold))
                            Text("\(day.day)").font(.caption2.weight(.heavy))
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(done ? Noir.ink : (current ? Noir.gold : Noir.muted))
                        .background(done ? Noir.gold : Color.white.opacity(current ? 0.12 : 0.05),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(current && claim == nil ? Noir.gold : .clear, lineWidth: 1.5))
                    }
                }
                if let claim {
                    VStack(spacing: 6) {
                        Text("+" + CrimeFormat.cash(claim.cash)).font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(Noir.money)
                        Text("+\(CrimeFormat.short(claim.respect)) respeito" + (claim.reward.boostMinutes > 0 ? " · lucro ×2 por \(Int(claim.reward.boostMinutes)) min" : ""))
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Noir.gold)
                    }
                    Button("Voltar ao trabalho", action: dismiss)
                        .buttonStyle(NoirButtonStyle(tint: Noir.gold))
                        .accessibilityIdentifier("dismiss-daily")
                } else {
                    Text("Volte todo dia: a sequência cresce até o envelope dourado do 7º dia. Pular um dia zera tudo.")
                        .font(.footnote).foregroundStyle(Noir.muted).multilineTextAlignment(.center)
                    Button("Abrir envelope") { store.claimDaily() }
                        .buttonStyle(NoirButtonStyle(tint: Noir.gold))
                        .accessibilityIdentifier("claim-daily")
                }
            }
            .padding(26)
            .frame(maxWidth: 440)
            .background(Noir.night, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Noir.gold.opacity(0.5), lineWidth: 1.5))
            .padding(20)
        }
    }
}

// MARK: - Tutorial

struct CrimeCoachCard: View {
    let step: CrimeTutorialStep
    let isOnTargetTab: Bool
    let go: () -> Void
    let skip: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CrimePortrait(memberID: 7, tint: Noir.gold)
                .frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("O PADRINHO · \(step.rawValue + 1)/\(CrimeTutorialStep.allCases.count - 1)")
                        .font(.system(size: 10, weight: .heavy)).tracking(1.2).foregroundStyle(Noir.gold)
                    Spacer(minLength: 0)
                    Button("Pular", action: skip)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Noir.muted)
                        .accessibilityIdentifier("skip-tutorial")
                }
                Text(step.title).font(.subheadline.weight(.heavy))
                Text(step.message).font(.caption).foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !isOnTargetTab {
                Button("Ir", action: go)
                    .buttonStyle(NoirButtonStyle(tint: Noir.gold, compact: true))
                    .accessibilityIdentifier("tutorial-go")
            }
        }
        .padding(12)
        .background(Noir.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Noir.gold.opacity(0.55), lineWidth: 1.2))
        .shadow(color: Noir.gold.opacity(0.2), radius: 12)
        .padding(.horizontal, 12)
        .frame(maxWidth: 620)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tutorial-card")
    }
}
