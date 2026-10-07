import SwiftUI

// MARK: - Sala de espera

/// Tela de bloqueio do FutOS antes de entrar na carreira: o mesmo papel de parede, barra de status e relógio do celular,
/// com os perfis (carreiras salvas) como janelinhas. Escolha um perfil e segure a digital para desbloquear;
/// uma janelinha vazia cria uma carreira nova. Arrastar do topo para baixo (ou tocar na ilha) abre o centro de
/// notificações: os avisos reais da carreira ativa e avisos de ambiente (fictícios, sem efeito no jogo).
struct FootballProfileRoom: View {
    let activeSlot: Int
    let summaries: [SaveSlotSummary?]
    /// Notificações reais da carreira ativa (as mesmas do centro de notificações do celular).
    var pending: [PhoneNotification] = []
    var startsWithShade = false
    let onEnter: (Int) -> Void
    let onCreate: (Int) -> Void
    let onOptions: () -> Void

    @State private var selected: Int
    @State private var holdProgress = 0.0
    @State private var unlocked = false
    @State private var shadeOpen: Bool
    @State private var lineIndex = 0
    @State private var shown = false
    @State private var impact = 0
    @State private var streak = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ticker = Timer.publish(every: 6, on: .main, in: .common).autoconnect()
    private let holdSeconds = 0.7

    init(activeSlot: Int, summaries: [SaveSlotSummary?], pending: [PhoneNotification] = [], startsWithShade: Bool = false,
         onEnter: @escaping (Int) -> Void, onCreate: @escaping (Int) -> Void, onOptions: @escaping () -> Void) {
        self.activeSlot = activeSlot
        self.summaries = summaries
        self.pending = pending
        self.startsWithShade = startsWithShade
        self.onEnter = onEnter
        self.onCreate = onCreate
        self.onOptions = onOptions
        let filled = summaries.indices.filter { Self.isFilled(summaries[$0]) }
        let first = (filled.contains(activeSlot) ? activeSlot : filled.first) ?? 0
        _selected = State(initialValue: first)
        _shadeOpen = State(initialValue: startsWithShade)
    }

    // MARK: Dados

    private static func isFilled(_ summary: SaveSlotSummary?) -> Bool {
        summary?.clubID != nil
    }

    private func summary(_ slot: Int) -> SaveSlotSummary? {
        slot < summaries.count ? summaries[slot] : nil
    }

    private func team(_ slot: Int) -> LeagueTeam? {
        summary(slot)?.clubID.flatMap { FootballSeason.team($0) }
    }

    private var slots: [Int] { Array(0..<FootballSaveStore.slotCount) }
    private var selectedIsFilled: Bool { Self.isFilled(summary(selected)) }
    private var selectedName: String { summary(selected)?.coachName ?? "Treinador" }

    private var moment: PhoneMoment {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 17 { return .morning }
        if hour >= 17 && hour < 20 { return .matchAfternoon }
        return .matchNight
    }

    /// Notificações reais só valem para a carreira ativa.
    private var realPending: [PhoneNotification] { selected == activeSlot ? pending : [] }

    private struct Line: Identifiable {
        let id: String
        let symbol: String
        let tint: Color
        let app: String
        let title: String
        let detail: String
    }

    private var realLines: [Line] {
        realPending.prefix(3).map { Line(id: "real-\($0.id)", symbol: $0.symbol, tint: $0.app.tint, app: $0.app.title, title: $0.title, detail: $0.detail) }
    }

    private var ambientLines: [Line] {
        AmbientFeed.batch().map {
            Line(id: "ambient-\($0.id)", symbol: $0.symbol, tint: $0.tint, app: $0.app, title: $0.title,
                 detail: $0.hidden ? "Conteúdo oculto" : $0.body)
        }
    }

    /// A ilha alterna entre o que é real (primeiro) e o ambiente.
    private var islandLines: [Line] { realLines + ambientLines }

    // MARK: Corpo

    var body: some View {
        VStack(spacing: 0) {
            statusBar.padding(.top, 8)
            island.padding(.top, 8)
            Spacer(minLength: 8)
            clock
            Spacer(minLength: 12)
            if streak >= 2 {
                Label("\(streak) dias seguidos", systemImage: "flame.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FootballTheme.gold)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(FootballTheme.gold.opacity(0.16), in: Capsule())
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("profile-streak")
            }
            Text("Quem vai entrar?")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack(alignment: .top, spacing: 10) {
                ForEach(slots, id: \.self) { slot in tile(slot) }
            }
            .frame(maxWidth: 520)
            .padding(.top, 14)
            Spacer(minLength: 12)
            action
            Spacer(minLength: 10)
            footer
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background { PhoneWallpaper(team: team(selected), moment: moment) }
        .overlay { if shadeOpen { shade } }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(.success, trigger: unlocked)
        .sensoryFeedback(.impact(weight: .light), trigger: impact)
        .simultaneousGesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                if value.translation.height > 60, value.startLocation.y < 200, !shadeOpen {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { shadeOpen = true }
                } else if value.translation.height < -40, shadeOpen {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { shadeOpen = false }
                }
            }
        )
        .onReceive(ticker) { _ in
            guard !shadeOpen else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { lineIndex += 1 }
        }
        .onAppear {
            streak = FootballVisitStreak.register()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { shown = true }
        }
        .accessibilityIdentifier("title-screen")
    }

    // MARK: Barra de status e relógio (mesmo visual do celular)

    /// Barra de status com o último estado salvo do perfil selecionado (o mesmo HUD do celular dentro da carreira).
    /// Perfil vazio mostra a data do aparelho e a bateria apagada, porque ainda não há carreira.
    private var statusBar: some View {
        let info = summary(selected)
        return HStack(spacing: 10) {
            Text(statusDate)
                .font(.caption.weight(.bold).monospacedDigit())
            Spacer()
            if selectedIsFilled, let club = team(selected) {
                ClubCrest(team: club, size: 16)
            } else {
                Text("FutOS").font(.caption.weight(.heavy)).tracking(1.5)
            }
            Spacer()
            PhoneSignal(fanMood: info?.fanMood)
            PhoneBattery(level: info?.energy)
            Text(info?.energy.map { "\($0)%" } ?? "—")
                .font(.caption2.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .accessibilityHidden(true)
    }

    /// Dia e hora do jogo no último save. Save antigo, sem esses dados, mostra traço.
    private var statusDate: String {
        guard selectedIsFilled else { return Date().formatted(.dateTime.day().month(.abbreviated)) }
        guard let info = summary(selected), let day = info.gameDay, let moment = info.gameMoment else { return "—" }
        return "\(FootballCalendarClock.shortDate(day)) · \(FootballCalendarClock.clock(moment))"
    }

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 20)) { context in
            VStack(spacing: 2) {
                Text(context.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 76, weight: .thin, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                if let info = summary(selected), selectedIsFilled {
                    Text("Temporada \(info.season) · rodada \(info.matchDay + 1)")
                        .font(.footnote.weight(.medium)).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Perfis

    private func avatar(team: LeagueTeam?, name: String) -> some View {
        ZStack {
            if let team {
                Circle().fill(LinearGradient(colors: [team.primaryColor, team.primaryColor.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                ClubCrest(team: team, size: 24).offset(x: 24, y: 24)
            } else {
                Circle().fill(Color.white.opacity(0.08))
                Image(systemName: "plus").font(.title2.weight(.light)).foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(width: 64, height: 64)
    }

    @ViewBuilder private func tile(_ slot: Int) -> some View {
        let info = summary(slot)
        let filled = Self.isFilled(info)
        let isSelected = selected == slot
        let club = team(slot)
        Button {
            impact += 1
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selected = slot; holdProgress = 0 }
        } label: {
            VStack(spacing: 8) {
                avatar(team: club, name: info?.coachName ?? "T")
                    .overlay {
                        Circle().strokeBorder(isSelected ? FootballTheme.gold : Color.white.opacity(0.2),
                                              style: StrokeStyle(lineWidth: isSelected ? 3 : 1, dash: filled ? [] : [5, 4]))
                    }
                Text(filled ? (info?.coachName ?? "Treinador") : "Novo perfil")
                    .font(.footnote.weight(.bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                Text(filled ? (club?.name ?? "") : "Criar carreira")
                    .font(.caption2).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(isSelected ? 0.4 : 0.26), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 20)
        .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.1 + Double(slot) * 0.08), value: shown)
        .accessibilityLabel(filled ? "Perfil \(info?.coachName ?? "Treinador"), \(club?.name ?? ""), temporada \(info?.season ?? 1)" : "Perfil vazio para uma nova carreira")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("profile-slot-\(slot)")
    }

    // MARK: Desbloquear

    @ViewBuilder private var action: some View {
        if selectedIsFilled {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color.black.opacity(0.28))
                    Circle().stroke(Color.white.opacity(0.18), lineWidth: 4)
                    Circle().trim(from: 0, to: unlocked ? 1 : holdProgress)
                        .stroke(FootballTheme.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: unlocked ? "checkmark" : "touchid")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(unlocked ? FootballTheme.gold : Color.white)
                }
                .frame(width: 80, height: 80)
                .contentShape(Circle())
                .onLongPressGesture(minimumDuration: holdSeconds, maximumDistance: 60, perform: unlock, onPressingChanged: { pressing in
                    guard !unlocked else { return }
                    if pressing {
                        withAnimation(.linear(duration: holdSeconds)) { holdProgress = 1 }
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
                    }
                })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Impressão digital")
                .accessibilityHint("Segure para entrar como \(selectedName)")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { unlock() }
                .accessibilityIdentifier("profile-fingerprint")
                Text(unlocked ? "Bem-vindo, \(selectedName)" : "Segure o dedo para entrar")
                    .font(.footnote).foregroundStyle(.white.opacity(0.8))
            }
        } else {
            Button {
                guard !unlocked else { return }
                unlocked = true
                finish { onCreate(selected) }
            } label: {
                Label("Criar carreira aqui", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.black.opacity(0.88))
                    .padding(.horizontal, 24)
                    .frame(minHeight: 52)
                    .background(FootballTheme.gold, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile-create")
        }
    }

    private var footer: some View {
        HStack {
            Text("Arraste do topo para ver as notificações")
                .font(.caption2).foregroundStyle(.white.opacity(0.5))
            Spacer()
            Button(action: onOptions) {
                Label("Opções", systemImage: "gearshape.fill").font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.85))
            .accessibilityIdentifier("title-options")
        }
        .padding(.bottom, 12)
    }

    private func unlock() {
        guard !unlocked, selectedIsFilled else { return }
        withAnimation(.easeOut(duration: 0.2)) { holdProgress = 1; unlocked = true }
        finish { onEnter(selected) }
    }

    private func finish(_ action: @escaping () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: reduceMotion ? 50_000_000 : 450_000_000)
            action()
        }
    }

    // MARK: Ilha e centro de notificações

    private var island: some View {
        let lines = islandLines
        let line = lines.isEmpty ? nil : lines[lineIndex % lines.count]
        return Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { shadeOpen = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: line?.symbol ?? "bell.fill").font(.footnote).foregroundStyle(line?.tint ?? .white)
                Text(line.map { "\($0.title): \($0.detail)" } ?? "Sem novidades")
                    .font(.caption.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1) }
            .id(line?.id ?? "none")
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(line.map { "Notificação: \($0.title)" } ?? "Sem notificações")
        .accessibilityHint("Toque para abrir o centro de notificações")
        .accessibilityIdentifier("profile-island")
    }

    private var shade: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { shadeOpen = false } }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    HStack {
                        Text("Notificações").font(.headline).foregroundStyle(.white)
                        Spacer()
                        Button("Fechar") { withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { shadeOpen = false } }
                            .font(.subheadline.weight(.semibold))
                            .accessibilityIdentifier("profile-shade-close")
                    }
                    if !realLines.isEmpty {
                        sectionTitle("Da sua carreira")
                        ForEach(realLines) { row($0) }
                        Text("Entre na carreira para responder.")
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                    }
                    sectionTitle("No celular hoje")
                    ForEach(ambientLines) { row($0) }
                    Text("Avisos de ambiente: não fazem parte da sua carreira.")
                        .font(.caption2).foregroundStyle(.white.opacity(0.5))
                }
                .padding(16)
            }
            .frame(maxWidth: 520, maxHeight: 560)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 56)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .accessibilityIdentifier("profile-shade")
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption2.weight(.heavy)).tracking(1)
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ line: Line) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: line.symbol)
                .font(.footnote).foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(line.tint.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(line.app.uppercased()).font(.caption2.weight(.heavy)).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("agora").font(.caption2).foregroundStyle(.white.opacity(0.45))
                }
                Text(line.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(line.detail).font(.caption).foregroundStyle(.white.opacity(0.8)).lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
