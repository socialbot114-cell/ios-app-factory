import SwiftUI

// MARK: - Carta

struct FootballIconCardImage: View {
    let card: IconCard
    var width: CGFloat = 200

    var body: some View {
        Image(card.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityElement()
            .accessibilityLabel(card.accessibilityText)
    }
}

// MARK: - Abertura do pacote

/// Cerimônia curta: o pacote dourado treme, estoura em faíscas, vira e revela a carta com brilho e os seis números.
struct FootballIconPackView: View {
    @Binding var career: FootballCareer
    let onClose: () -> Void

    private enum Phase { case sealed, opening, revealed }

    @State private var phase = Phase.sealed
    @State private var card: IconCard?
    @State private var showFront = false
    @State private var flip = 0.0
    @State private var cardScale = 1.0
    @State private var breathing = false
    @State private var rays = false
    @State private var flash = 0.0
    @State private var sparks = false
    @State private var sparkOpacity = 0.0
    @State private var statsShown = 0
    @State private var shimmer = -1.0
    @State private var impact = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardWidth: CGFloat = 250
    private var cardHeight: CGFloat { cardWidth * 880 / 660 }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 18) {
                Spacer(minLength: 8)
                stage
                statChips.frame(height: 56)
                Spacer(minLength: 4)
                bottom
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: impact)
        .sensoryFeedback(.success, trigger: phase == .revealed)
        .sensoryFeedback(.selection, trigger: statsShown)
        .onAppear { if !reduceMotion { breathing = true } }
    }

    // MARK: Cena

    private var background: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 0.10, green: 0.30, blue: 0.20), Color.black],
                           center: .center, startRadius: 20, endRadius: 520)
            if phase == .revealed && !reduceMotion {
                AngularGradient(colors: [FootballTheme.gold.opacity(0), FootballTheme.gold.opacity(0.35), FootballTheme.gold.opacity(0),
                                         FootballTheme.gold.opacity(0.35), FootballTheme.gold.opacity(0)], center: .center)
                    .rotationEffect(.degrees(rays ? 360 : 0))
                    .animation(.linear(duration: 14).repeatForever(autoreverses: false), value: rays)
                    .mask { RadialGradient(colors: [.white, .clear], center: .center, startRadius: 40, endRadius: 420) }
            }
        }
        .ignoresSafeArea()
    }

    private var stage: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                let angle = Double(index) / 18 * 2 * Double.pi
                let distance = 120 + Double(index % 3) * 40
                Circle()
                    .fill(FootballTheme.gold)
                    .frame(width: index.isMultiple(of: 3) ? 10 : 6, height: index.isMultiple(of: 3) ? 10 : 6)
                    .offset(x: sparks ? CGFloat(cos(angle) * distance) : 0, y: sparks ? CGFloat(sin(angle) * distance) : 0)
                    .opacity(sparkOpacity)
            }
            ZStack {
                back
                    .opacity(showFront ? 0 : 1)
                    .onTapGesture { open() }
                    .accessibilityElement()
                    .accessibilityLabel("Pacote de craque eterno. Toque para abrir.")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("icon-pack-open")
                if let card {
                    FootballIconCardImage(card: card, width: cardWidth)
                        .overlay(shimmerOverlay(card))
                        .shadow(color: FootballTheme.gold.opacity(0.7), radius: 26)
                        .opacity(showFront ? 1 : 0)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        .accessibilityIdentifier("icon-pack-card")
                }
            }
            .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            .scaleEffect(cardScale)
        }
        .frame(height: cardHeight)
    }

    private var back: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.99, green: 0.84, blue: 0.40), Color(red: 0.72, green: 0.48, blue: 0.10),
                                              Color(red: 0.99, green: 0.84, blue: 0.40)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
                .padding(12)
            VStack(spacing: 10) {
                Image(systemName: "crown.fill").font(.system(size: 64))
                Text("CRAQUE\nETERNO")
                    .font(.system(size: 26, weight: .black, design: .serif))
                    .multilineTextAlignment(.center)
                Text("Toque para abrir").font(.caption.weight(.bold))
            }
            .foregroundStyle(Color.black.opacity(0.8))
        }
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: FootballTheme.gold.opacity(0.55), radius: 22)
        .scaleEffect(breathing && phase == .sealed ? 1.04 : 1)
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: breathing)
    }

    private func shimmerOverlay(_ card: IconCard) -> some View {
        LinearGradient(colors: [.clear, .white.opacity(0.65), .clear], startPoint: .leading, endPoint: .trailing)
            .frame(width: cardWidth * 0.5)
            .offset(x: CGFloat(shimmer) * cardWidth)
            .blendMode(.plusLighter)
            .mask { Image(card.assetName).resizable().scaledToFit().frame(width: cardWidth) }
            .allowsHitTesting(false)
    }

    private var statChips: some View {
        HStack(spacing: 8) {
            if let card {
                ForEach(Array(card.stats.enumerated()), id: \.offset) { index, stat in
                    VStack(spacing: 2) {
                        Text("\(stat.value)").font(.headline.monospacedDigit().weight(.heavy)).foregroundStyle(FootballTheme.gold)
                        Text(stat.label).font(.caption2.weight(.bold)).foregroundStyle(.white.opacity(0.75))
                    }
                    .frame(minWidth: 44)
                    .scaleEffect(statsShown > index ? 1 : 0.2)
                    .opacity(statsShown > index ? 1 : 0)
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private var bottom: some View {
        switch phase {
        case .sealed:
            Text("Um craque lendário joga a próxima temporada inteira com você.")
                .font(.footnote).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
                .frame(minHeight: 54)
        case .opening:
            Color.clear.frame(height: 54)
        case .revealed:
            VStack(spacing: 10) {
                if let card {
                    Text("\(card.detail.title) · \(card.country) · geral \(card.overall)")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                }
                Button { onClose() } label: {
                    Label("Escalar o craque", systemImage: "checkmark.seal.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(FactoryPrimaryButtonStyle())
                .accessibilityIdentifier("icon-pack-continue")
            }
        }
    }

    // MARK: Abertura

    private func open() {
        guard phase == .sealed else { return }
        guard let opened = career.openIconPack() else {
            onClose()
            return
        }
        card = opened
        phase = .opening
        Task { @MainActor in
            if reduceMotion {
                showFront = true
                flip = 180
                phase = .revealed
                statsShown = 6
                return
            }
            impact += 1
            withAnimation(.easeIn(duration: 0.22)) { cardScale = 1.18 }
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(.easeIn(duration: 0.2)) { flip = 90 }
            try? await Task.sleep(nanoseconds: 200_000_000)
            showFront = true
            flash = 0.85
            impact += 1
            sparkOpacity = 1
            withAnimation(.spring(response: 0.55, dampingFraction: 0.58)) {
                flip = 180
                cardScale = 1
            }
            withAnimation(.easeOut(duration: 0.7)) { flash = 0 }
            withAnimation(.easeOut(duration: 1.0)) {
                sparks = true
                sparkOpacity = 0
            }
            phase = .revealed
            rays = true
            withAnimation(.easeInOut(duration: 1.1).delay(0.5)) { shimmer = 1.2 }
            for index in 1...6 {
                try? await Task.sleep(nanoseconds: 110_000_000)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { statsShown = index }
            }
        }
    }
}

// MARK: - Painel do Gestor

/// Aparece só quando há algo a fazer: pacote fechado ou craque da temporada.
struct FootballIconPanel: View {
    @Binding var career: FootballCareer
    let onOpenPack: () -> Void

    var body: some View {
        Group {
            if career.iconState.pendingPack != nil && !career.isFired { packPanel }
            if let icon = career.iconState.seasonIcon { seasonPanel(icon) }
        }
    }

    private var packPanel: some View {
        FactoryPanel(title: "Pacote de craque eterno", systemImage: "gift.fill") {
            Text("Chegou um pacote de craque eterno. Abra para descobrir quem joga a temporada inteira com você.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { onOpenPack() } label: {
                Label("Abrir pacote", systemImage: "sparkles").frame(maxWidth: .infinity)
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .accessibilityIdentifier("icon-pack-open-panel")
        }
    }

    private func seasonPanel(_ icon: IconCard) -> some View {
        FactoryPanel(title: "Craque eterno da temporada", systemImage: "crown.fill") {
            HStack(alignment: .center, spacing: 14) {
                FootballIconCardImage(card: icon, width: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text(icon.name).font(.headline)
                    Text("\(icon.detail.title) · geral \(icon.overall)").font(.caption).foregroundStyle(.secondary)
                    Text("Joga com você até o fim desta temporada. Não pode ser vendido nem dispensado.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("icon-season-panel")
    }
}
