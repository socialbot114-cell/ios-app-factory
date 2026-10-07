import SwiftUI

// MARK: - Carregamento

/// Primeira tela ao abrir o app: logo, barra de progresso e uma dica de jogo.
struct FootballLoadingView: View {
    private static let tips = [
        "Antes de jogar, confira a escalação: um titular lesionado custa pontos.",
        "A conversa do intervalo muda o segundo tempo.",
        "Contratos que vencem viram agentes livres: renove os importantes.",
        "O caixa no vermelho trava contratações. Olhe o Banco toda semana.",
        "Cada fim de temporada traz uma lenda para jogar com você.",
        "A torcida lembra de cada resultado. Cuide do humor dela.",
    ]

    @State private var progress = 0.0
    @State private var glow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tip: String {
        Self.tips[Int(Date().timeIntervalSince1970 / 60) % Self.tips.count]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.10, blue: 0.07), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 26) {
                Spacer()
                Image(systemName: "soccerball")
                    .font(.system(size: 72))
                    .foregroundStyle(FootballTheme.gold)
                    .shadow(color: FootballTheme.gold.opacity(glow ? 0.7 : 0.2), radius: glow ? 26 : 8)
                    .scaleEffect(glow ? 1.06 : 0.98)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: glow)
                Text("MANAGER DE FUTEBOL")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.white)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(LinearGradient(colors: [FootballTheme.gold.opacity(0.8), FootballTheme.gold], startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(width: 200, height: 6)
                Spacer()
                Text(tip)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 36)
            }
        }
        .onAppear {
            glow = !reduceMotion
            withAnimation(.easeInOut(duration: 1.1)) { progress = 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Carregando o Manager de Futebol")
        .accessibilityIdentifier("loading-screen")
    }
}

// MARK: - Tela de abertura

/// Menu de entrada, como num jogo: Continuar, Novo jogo e Opções.
struct FootballTitleScreen: View {
    /// Resumo da carreira que dá para continuar; nil quando não há carreira em andamento.
    let continueSubtitle: String?
    let onContinue: () -> Void
    let onNewGame: () -> Void
    let onOptions: () -> Void

    @State private var shown = false
    @State private var drift = false
    @State private var shine = -1.0
    @State private var taps = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Versão \(version) (\(build))"
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                Spacer(minLength: 36)
                logo
                Spacer(minLength: 24)
                VStack(spacing: 14) {
                    if let continueSubtitle {
                        menuButton(title: "Continuar", subtitle: continueSubtitle, symbol: "play.fill", primary: true,
                                   index: 0, identifier: "title-continue", action: onContinue)
                    }
                    menuButton(title: "Novo jogo", subtitle: nil, symbol: "plus.circle.fill", primary: continueSubtitle == nil,
                               index: 1, identifier: "title-new-game", action: onNewGame)
                    menuButton(title: "Opções", subtitle: nil, symbol: "gearshape.fill", primary: false,
                               index: 2, identifier: "title-options", action: onOptions)
                }
                .padding(.horizontal, 28)
                Spacer(minLength: 28)
                Text(versionText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 18)
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { shown = true }
            guard !reduceMotion else { return }
            drift = true
            withAnimation(.easeInOut(duration: 1.6).delay(0.5)) { shine = 1.4 }
        }
        .accessibilityIdentifier("title-screen")
    }

    private var background: some View {
        ZStack {
            Image("MatchSceneV2")
                .resizable()
                .scaledToFill()
                .scaleEffect(drift ? 1.16 : 1.0)
                .animation(.easeInOut(duration: 18).repeatForever(autoreverses: true), value: drift)
                .opacity(0.55)
            LinearGradient(colors: [Color.black.opacity(0.25), Color.black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [FootballTheme.gold.opacity(0.22), .clear], center: .top, startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
        .clipped()
    }

    private var logo: some View {
        VStack(spacing: 8) {
            Image(systemName: "soccerball")
                .font(.system(size: 54))
                .foregroundStyle(FootballTheme.gold)
                .shadow(color: FootballTheme.gold.opacity(0.6), radius: 18)
            Text("MANAGER")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .tracking(8)
                .foregroundStyle(.white.opacity(0.85))
            Text("DE FUTEBOL")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.89, blue: 0.55), FootballTheme.gold,
                                                         Color(red: 0.66, green: 0.45, blue: 0.10)], startPoint: .top, endPoint: .bottom))
                .overlay {
                    LinearGradient(colors: [.clear, .white.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 80)
                        .offset(x: CGFloat(shine) * 140)
                        .blendMode(.plusLighter)
                        .mask { Text("DE FUTEBOL").font(.system(size: 40, weight: .black, design: .rounded)) }
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
        }
        .scaleEffect(shown ? 1 : 0.8)
        .opacity(shown ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Manager de Futebol")
        .accessibilityAddTraits(.isHeader)
    }

    private func menuButton(title: String, subtitle: String?, symbol: String, primary: Bool, index: Int,
                            identifier: String, action: @escaping () -> Void) -> some View {
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title3).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title3.weight(.bold))
                    if let subtitle {
                        Text(subtitle).font(.caption).opacity(0.8).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).opacity(0.6)
            }
            .foregroundStyle(primary ? Color.black.opacity(0.88) : Color.white)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(primary ? AnyShapeStyle(FootballTheme.gold) : AnyShapeStyle(Color.white.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(primary ? Color.clear : Color.white.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(TitleButtonStyle())
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 24)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25 + Double(index) * 0.1), value: shown)
        .accessibilityIdentifier(identifier)
    }
}

private struct TitleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Opções

/// Opções da abertura: carreiras salvas e preferências de movimento.
struct FootballTitleOptionsSheet: View {
    @Binding var career: FootballCareer
    let activeSlot: Int
    let summaries: [SaveSlotSummary?]
    let onLoad: (Int) -> Void
    let onNew: (Int) -> Void
    let onDelete: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Versão \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                FootballSaveSlotsView(activeSlot: activeSlot, summaries: summaries, onLoad: onLoad, onNew: onNew, onDelete: onDelete)
                FactoryPanel(title: "Preferências", systemImage: "slider.horizontal.3") {
                    Toggle("Reduzir movimento", isOn: Binding(
                        get: { career.world.phone.preferences.reduceMotion },
                        set: { career.world.phone.preferences.reduceMotion = $0 }
                    ))
                    .accessibilityIdentifier("title-reduce-motion")
                    Text(versionText).font(.caption).foregroundStyle(.secondary)
                }
            }
            .factoryPage()
            .navigationTitle("Opções")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fechar") { dismiss() }.accessibilityIdentifier("title-options-close") }
            }
        }
    }
}
