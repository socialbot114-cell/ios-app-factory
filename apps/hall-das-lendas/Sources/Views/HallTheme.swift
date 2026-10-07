import SwiftUI

// MARK: - Paleta

enum HallColor {
    static let ink = Color(red: 0.03, green: 0.06, blue: 0.05)
    static let emerald = Color(red: 0.05, green: 0.20, blue: 0.14)
    static let gold = Color(red: 0.93, green: 0.74, blue: 0.30)
    static let goldLight = Color(red: 1.00, green: 0.89, blue: 0.55)
    static let goldDeep = Color(red: 0.66, green: 0.45, blue: 0.10)
    static let muted = Color.white.opacity(0.62)
    static let panel = Color.white.opacity(0.06)
}

struct HallBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [HallColor.ink, HallColor.emerald, HallColor.ink], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [HallColor.gold.opacity(0.18), .clear], center: .top, startRadius: 10, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func goldText() -> some View {
        foregroundStyle(LinearGradient(colors: [HallColor.goldLight, HallColor.gold, HallColor.goldDeep], startPoint: .top, endPoint: .bottom))
    }

    func hallPanel() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HallColor.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
    }
}

/// Gerador determinístico: os confetes saem iguais em toda abertura da tela, sem depender do sistema.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Selos

struct RarityBadge: View {
    let rarity: LegendRarity

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<rarity.stars, id: \.self) { _ in
                Image(systemName: "star.fill").font(.system(size: 8))
            }
            Text(rarity.title.uppercased()).font(.caption2.weight(.heavy)).tracking(1.2)
        }
        .foregroundStyle(rarity.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(rarity.tint.opacity(0.14), in: Capsule())
        .overlay { Capsule().strokeBorder(rarity.tint.opacity(0.5), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Raridade \(rarity.title)")
    }
}

// MARK: - Carta

/// A carta na vitrine: cheia de brilho quando é do usuário, em silhueta com cadeado quando ainda está bloqueada.
struct LegendCardFace: View {
    let card: LegendCard
    var width: CGFloat? = nil
    var locked = false

    var body: some View {
        ZStack {
            Image(card.assetName)
                .resizable()
                .scaledToFit()
                .saturation(locked ? 0 : 1)
                .brightness(locked ? -0.5 : 0)
                .blur(radius: locked ? 5 : 0)
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .shadow(color: .black.opacity(0.6), radius: 6)
            }
        }
        .frame(width: width)
        .shadow(color: card.rarity.glow[0].opacity(locked ? 0 : 0.42), radius: 24, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(locked ? "\(card.shortName), carta bloqueada" : card.accessibilityText)
    }
}

/// Carta que inclina em 3D com o dedo e deixa um brilho holográfico acompanhar o movimento.
struct TiltCard: View {
    let card: LegendCard
    var width: CGFloat

    @State private var drag = CGSize.zero
    @State private var pressing = false

    var body: some View {
        let maxTilt = 14.0
        let rotateX = min(maxTilt, max(-maxTilt, Double(-drag.height) / 8))
        let rotateY = min(maxTilt, max(-maxTilt, Double(drag.width) / 8))
        let shift = CGFloat(rotateY / maxTilt) * 0.6
        LegendCardFace(card: card, width: width)
            .overlay {
                LinearGradient(colors: [.clear, .white.opacity(0.55), card.rarity.glow[0].opacity(0.25), .clear],
                               startPoint: UnitPoint(x: shift, y: 0), endPoint: UnitPoint(x: 0.6 + shift, y: 1))
                    .opacity(0.35 + Double(abs(shift)))
                    .blendMode(.plusLighter)
                    .mask { Image(card.assetName).resizable().scaledToFit() }
                    .allowsHitTesting(false)
            }
            .rotation3DEffect(.degrees(rotateX), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(rotateY), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .scaleEffect(pressing ? 1.03 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        withAnimation(.interactiveSpring()) {
                            drag = value.translation
                            pressing = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) {
                            drag = .zero
                            pressing = false
                        }
                    }
            )
            .sensoryFeedback(.selection, trigger: pressing)
    }
}

// MARK: - Confete

struct ConfettiBurst: View {
    private struct Piece: Identifiable {
        let id: Int
        let x: CGFloat
        let delay: Double
        let duration: Double
        let size: CGFloat
        let color: Color
        let spin: Double
    }

    private let pieces: [Piece]
    @State private var fall = false

    init(colors: [Color], count: Int = 44) {
        var generator = SeededGenerator(seed: 7)
        pieces = (0..<count).map { index in
            Piece(id: index,
                  x: CGFloat.random(in: -1...1, using: &generator),
                  delay: Double.random(in: 0...0.35, using: &generator),
                  duration: Double.random(in: 1.4...2.4, using: &generator),
                  size: CGFloat.random(in: 6...12, using: &generator),
                  color: colors[index % max(1, colors.count)],
                  spin: Double.random(in: 180...720, using: &generator))
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.5)
                        .rotationEffect(.degrees(fall ? piece.spin : 0))
                        .offset(x: piece.x * proxy.size.width / 2, y: fall ? proxy.size.height + 40 : -40)
                        .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: fall)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { fall = true }
    }
}

/// Comemoração de uma carta recém-desbloqueada, com confete e vibração. Some sozinha ou ao toque.
struct CelebrationLayer: View {
    @Environment(StoreModel.self) private var store

    var body: some View {
        if let card = store.celebration {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                ConfettiBurst(colors: card.rarity.glow + [.white, HallColor.gold]).ignoresSafeArea()
                VStack(spacing: 14) {
                    Text("NOVA LENDA NA COLEÇÃO").font(.caption.weight(.heavy)).tracking(2).goldText()
                    LegendCardFace(card: card, width: 200)
                    Text(card.name).font(.title2.weight(.bold)).foregroundStyle(.white)
                    Text("Toque para continuar").font(.footnote).foregroundStyle(HallColor.muted)
                }
                .padding()
            }
            .contentShape(Rectangle())
            .onTapGesture { store.celebration = nil }
            .sensoryFeedback(.success, trigger: card.id)
            .task(id: card.id) {
                try? await Task.sleep(nanoseconds: 3_200_000_000)
                if store.celebration?.id == card.id { store.celebration = nil }
            }
            .accessibilityIdentifier("celebration-layer")
            .transition(.opacity)
        }
    }
}
