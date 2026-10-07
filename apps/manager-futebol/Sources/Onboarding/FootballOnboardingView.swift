import SwiftUI

/// Mostra a introdução uma única vez por instalação; UI tests e capturas de tela nunca passam por ela.
enum FootballOnboardingGate {
    static let key = "football.onboarding.seen.v1"

    static var shouldShow: Bool {
        if FactoryCapture.isUITesting || FactoryCapture.screen != nil { return false }
        return !UserDefaults.standard.bool(forKey: key)
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: key)
    }
}

/// Introdução em cinco páginas antes da primeira proposta: o clima do jogo, o celular, o ritmo dos dias,
/// as decisões entre temporadas e a escolha da dificuldade.
struct FootballOnboardingView: View {
    @Binding var career: FootballCareer
    let onFinish: () -> Void

    @State private var page: Int
    @State private var shown: Set<Int> = []
    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Row: Identifiable {
        let symbol: String
        let title: String
        let detail: String
        var id: String { title }
    }

    private struct Page {
        let symbol: String
        let title: String
        let body: String
        let rows: [Row]
    }

    private let pages: [Page] = [
        Page(symbol: "soccerball", title: "Seja bem-vindo, professor",
             body: "Você é o treinador. A diretoria cobra resultado, a torcida pressiona e cada dia de jogo muda a história do clube.",
             rows: []),
        Page(symbol: "iphone.gen3", title: "O FutOS é o seu centro de comando",
             body: "Tudo acontece no seu celular, app por app.",
             rows: [Row(symbol: "person.3.fill", title: "Tática", detail: "Escalação, formação e treinos."),
                    Row(symbol: "trophy.fill", title: "Liga", detail: "Tabela, artilharia e rodadas."),
                    Row(symbol: "arrow.left.arrow.right", title: "Transfer", detail: "Contratos, empréstimos e mercado."),
                    Row(symbol: "bubble.left.and.bubble.right.fill", title: "Contatos", detail: "Família, comissão e jogadores falam com você.")]),
        Page(symbol: "calendar", title: "Um dia de cada vez",
             body: "O calendário só anda quando você decide. Nada passa de uma vez.",
             rows: [Row(symbol: "figure.run", title: "Treino e preparação", detail: "Prepare o time antes de entrar em campo."),
                    Row(symbol: "sportscourt.fill", title: "Partida ao vivo", detail: "Pause, substitua e mude a tática."),
                    Row(symbol: "person.2.wave.2.fill", title: "Intervalo", detail: "A conversa de vestiário muda o segundo tempo.")]),
        Page(symbol: "sun.horizon.fill", title: "Entre as temporadas, decisões",
             body: "Quando o campeonato acaba, o ritmo muda: uma etapa por vez, sem pular nenhuma.",
             rows: [Row(symbol: "crown.fill", title: "Craque eterno", detail: "Você começa a carreira com uma lenda e ganha outra a cada temporada. Cada uma joga o ano inteiro com você."),
                    Row(symbol: "beach.umbrella.fill", title: "Férias e pré-temporada", detail: "Descanso ou ritmo? Cada escolha tem preço."),
                    Row(symbol: "building.2.fill", title: "Patrocinador", detail: "Segurança ou risco na camisa do clube.")]),
        Page(symbol: "gauge.with.dots.needle.67percent", title: "Escolha o seu desafio",
             body: "Você pode mudar isso depois em Ajustes.", rows: []),
    ]

    init(career: Binding<FootballCareer>, startPage: Int = 0, onFinish: @escaping () -> Void) {
        _career = career
        _page = State(initialValue: min(max(0, startPage), 4))
        self.onFinish = onFinish
    }

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if !isLast {
                        Button("Pular") { page = pages.count - 1 }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .accessibilityIdentifier("onboarding-skip")
                    }
                }
                .frame(height: 36)
                .padding(.horizontal, 22)
                TabView(selection: $page) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageView(index).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                dots
                Button {
                    if isLast { onFinish() } else { withAnimation(.easeInOut(duration: 0.35)) { page += 1 } }
                } label: {
                    Label(isLast ? "Escolher meu clube" : "Continuar", systemImage: isLast ? "flag.checkered" : "arrow.right")
                }
                .buttonStyle(FactoryPrimaryButtonStyle())
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 20)
                .accessibilityIdentifier("onboarding-continue")
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: page)
        .onAppear {
            shown.insert(page)
            if !reduceMotion { drift = true }
        }
        .onChange(of: page) { _, newPage in
            shown.insert(newPage)
        }
        .accessibilityIdentifier("onboarding")
    }

    // MARK: Fundo

    private var background: some View {
        ZStack {
            Image("MatchSceneV2")
                .resizable()
                .scaledToFill()
                .scaleEffect(drift ? 1.14 : 1.0)
                .animation(.easeInOut(duration: 16).repeatForever(autoreverses: true), value: drift)
                .opacity(0.5)
            LinearGradient(colors: [Color.black.opacity(0.35), Color.black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [FootballTheme.gold.opacity(0.18), .clear], center: .top, startRadius: 10, endRadius: 380)
        }
        .ignoresSafeArea()
        .clipped()
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(index == page ? FootballTheme.gold : Color.white.opacity(0.3))
                    .frame(width: index == page ? 26 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: page)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Página \(page + 1) de \(pages.count)")
    }

    // MARK: Páginas

    private func pageView(_ index: Int) -> some View {
        let content = pages[index]
        let visible = shown.contains(index)
        return ScrollView {
            VStack(spacing: 18) {
                Spacer(minLength: 24)
                Image(systemName: content.symbol)
                    .font(.system(size: 64))
                    .foregroundStyle(FootballTheme.gold)
                    .shadow(color: FootballTheme.gold.opacity(0.5), radius: 20)
                    .symbolEffect(.bounce, value: page == index)
                    .scaleEffect(visible ? 1 : 0.6)
                    .opacity(visible ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.6), value: visible)
                Text(content.title)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: visible)
                Text(content.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: visible)
                VStack(spacing: 10) {
                    ForEach(Array(content.rows.enumerated()), id: \.element.id) { offset, row in
                        HStack(spacing: 14) {
                            Image(systemName: row.symbol).font(.title3).foregroundStyle(FootballTheme.gold).frame(width: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title).font(.headline).foregroundStyle(.white)
                                Text(row.detail).font(.caption).foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .opacity(visible ? 1 : 0)
                        .offset(y: visible ? 0 : 16)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3 + Double(offset) * 0.12), value: visible)
                    }
                    if index == pages.count - 1 { difficultyPicker(visible: visible) }
                }
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func difficultyPicker(visible: Bool) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(Difficulty.allCases.enumerated()), id: \.element.id) { offset, level in
                let selected = career.difficulty == level
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { career.difficulty = level }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(level.title).font(.headline)
                            Text(level.summary).font(.caption).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selected ? FootballTheme.gold : Color.white.opacity(0.4))
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(selected ? FootballTheme.gold.opacity(0.18) : Color.white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selected ? FootballTheme.gold : Color.white.opacity(0.1), lineWidth: selected ? 2 : 1)
                    }
                    .scaleEffect(selected ? 1.02 : 1)
                }
                .buttonStyle(.plain)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 16)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3 + Double(offset) * 0.12), value: visible)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("onboarding-difficulty-\(level.rawValue)")
            }
        }
    }
}
