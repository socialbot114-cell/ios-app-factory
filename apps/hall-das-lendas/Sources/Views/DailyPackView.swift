import SwiftUI

/// Cartão do dia: pacote dourado que treme, vira e mostra uma lenda emprestada por 24 horas (gratuito, sem compra).
struct DailyPackView: View {
    @Environment(CollectionStore.self) private var collection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case sealed, opening, revealed }

    @State private var phase = Phase.sealed
    @State private var card: LegendCard?
    @State private var flip = 0.0
    @State private var showFront = false
    @State private var wiggle = 0.0
    @State private var scale = 1.0
    @State private var flash = 0.0
    @State private var impact = 0

    private let width: CGFloat = 250
    private var height: CGFloat { width * 880 / 660 }

    var body: some View {
        ZStack {
            HallBackground()
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title).symbolRenderingMode(.hierarchical).foregroundStyle(.white)
                    }
                    .accessibilityLabel("Fechar")
                    .accessibilityIdentifier("pack-close")
                }
                Spacer(minLength: 0)
                stage
                bottom
                Spacer(minLength: 0)
            }
            .padding(20)
            if phase == .revealed, let card, !reduceMotion {
                ConfettiBurst(colors: card.rarity.glow + [.white, HallColor.gold]).ignoresSafeArea()
            }
            Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: impact)
        .sensoryFeedback(.success, trigger: phase == .revealed)
    }

    private var stage: some View {
        ZStack {
            sealedPack
                .opacity(showFront ? 0 : 1)
                .onTapGesture { open() }
                .accessibilityElement()
                .accessibilityLabel("Cartão do dia. Toque para abrir.")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("pack-open")
            if let card {
                TiltCard(card: card, width: width)
                    .opacity(showFront ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .allowsHitTesting(phase == .revealed)
                    .accessibilityIdentifier("pack-card")
            }
        }
        .rotationEffect(.degrees(wiggle))
        .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
        .scaleEffect(scale)
        .frame(height: height)
    }

    private var sealedPack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [HallColor.goldLight, HallColor.goldDeep, HallColor.goldLight], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.black.opacity(0.35), lineWidth: 2).padding(12)
            VStack(spacing: 10) {
                Image(systemName: "crown.fill").font(.system(size: 60))
                Text("CARTÃO\nDO DIA").font(.system(size: 26, weight: .black, design: .serif)).multilineTextAlignment(.center)
                Text("Toque para abrir").font(.caption.weight(.bold))
            }
            .foregroundStyle(Color.black.opacity(0.8))
        }
        .frame(width: width, height: height)
        .shadow(color: HallColor.gold.opacity(0.55), radius: 22)
    }

    @ViewBuilder private var bottom: some View {
        switch phase {
        case .sealed:
            Text("Uma lenda que você ainda não tem fica disponível por 24 horas.")
                .font(.footnote).foregroundStyle(HallColor.muted).multilineTextAlignment(.center).frame(minHeight: 60)
        case .opening:
            Color.clear.frame(height: 60)
        case .revealed:
            VStack(spacing: 10) {
                if let card {
                    Text(card.name).font(.system(size: 22, weight: .bold, design: .serif)).foregroundStyle(.white)
                    RarityBadge(rarity: card.rarity)
                    Text("Ela é sua por 24 horas. Desbloqueie na loja para ficar com ela para sempre.")
                        .font(.footnote).foregroundStyle(HallColor.muted).multilineTextAlignment(.center)
                }
                Button { dismiss() } label: {
                    Text("Ver na vitrine").font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(Color.black.opacity(0.88))
                        .background(HallColor.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pack-continue")
            }
        }
    }

    private func open() {
        guard phase == .sealed else { return }
        guard let opened = collection.openDailyPack() else {
            dismiss()
            return
        }
        card = opened
        phase = .opening
        Task { @MainActor in
            if reduceMotion {
                showFront = true
                flip = 180
                phase = .revealed
                return
            }
            impact += 1
            for angle in [-6.0, 6.0, -4.0, 4.0, 0.0] {
                withAnimation(.easeInOut(duration: 0.07)) { wiggle = angle }
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
            withAnimation(.easeIn(duration: 0.2)) { flip = 90; scale = 1.12 }
            try? await Task.sleep(nanoseconds: 200_000_000)
            showFront = true
            flash = 0.8
            impact += 1
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { flip = 180; scale = 1 }
            withAnimation(.easeOut(duration: 0.6)) { flash = 0 }
            phase = .revealed
        }
    }
}
