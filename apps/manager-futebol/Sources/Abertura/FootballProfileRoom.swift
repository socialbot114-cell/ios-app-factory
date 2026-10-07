import SwiftUI

// MARK: - Sala de espera

/// Primeira tela depois do carregamento: o celular bloqueado com os perfis (carreiras salvas) como janelinhas.
/// Escolha um perfil e segure a digital para entrar; um espaço vazio cria uma carreira nova.
/// Arrastar do topo para baixo abre um centro de notificações de ambiente (avisos fictícios, não da carreira).
struct FootballProfileRoom: View {
    let activeSlot: Int
    let summaries: [SaveSlotSummary?]
    var startsWithShade = false
    let onEnter: (Int) -> Void
    let onCreate: (Int) -> Void
    let onOptions: () -> Void

    @State private var selected: Int
    @State private var holdProgress = 0.0
    @State private var unlocked = false
    @State private var shadeOpen: Bool
    @State private var noticeIndex = 0
    @State private var drift = false
    @State private var shown = false
    @State private var impact = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ticker = Timer.publish(every: 6, on: .main, in: .common).autoconnect()
    private let holdSeconds = 0.7

    init(activeSlot: Int, summaries: [SaveSlotSummary?], startsWithShade: Bool = false,
         onEnter: @escaping (Int) -> Void, onCreate: @escaping (Int) -> Void, onOptions: @escaping () -> Void) {
        self.activeSlot = activeSlot
        self.summaries = summaries
        self.startsWithShade = startsWithShade
        self.onEnter = onEnter
        self.onCreate = onCreate
        self.onOptions = onOptions
        let filled = summaries.indices.filter { Self.isFilled(summaries[$0]) }
        let first = (filled.contains(activeSlot) ? activeSlot : filled.first) ?? 0
        _selected = State(initialValue: first)
        _shadeOpen = State(initialValue: startsWithShade)
    }

    private static func isFilled(_ summary: SaveSlotSummary?) -> Bool {
        summary?.clubID != nil
    }

    private func summary(_ slot: Int) -> SaveSlotSummary? {
        slot < summaries.count ? summaries[slot] : nil
    }

    private var slots: [Int] { Array(0..<FootballSaveStore.slotCount) }
    private var selectedIsFilled: Bool { Self.isFilled(summary(selected)) }
    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "FutOS · versão \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 56)
            clock
            Spacer(minLength: 16)
            Text("Quem vai entrar?")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack(alignment: .top, spacing: 12) {
                ForEach(slots, id: \.self) { slot in tile(slot) }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: 520)
            .padding(.top, 18)
            Spacer(minLength: 16)
            action
            Spacer(minLength: 12)
            HStack {
                Text(versionText).font(.caption2).foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button(action: onOptions) {
                    Label("Opções", systemImage: "gearshape.fill").font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityIdentifier("title-options")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background { FootballBackdrop(drift: drift, imageOpacity: 0.5, zoom: 1.14, topShade: 0.3, glow: 0.2, seconds: 18) }
        .overlay(alignment: .top) { island }
        .overlay { if shadeOpen { shade } }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(.success, trigger: unlocked)
        .sensoryFeedback(.impact(weight: .light), trigger: impact)
        .simultaneousGesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                if value.translation.height > 60, value.startLocation.y < 180 {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { shadeOpen = true }
                } else if value.translation.height < -40, shadeOpen {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { shadeOpen = false }
                }
            }
        )
        .onReceive(ticker) { _ in
            guard !shadeOpen else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { noticeIndex += 1 }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { shown = true }
            if !reduceMotion { drift = true }
        }
        .accessibilityIdentifier("title-screen")
    }

    // MARK: Relógio

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 20)) { context in
            VStack(spacing: 2) {
                Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.8))
                Text(context.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 68, weight: .thin, design: .rounded)).foregroundStyle(.white)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Perfis

    @ViewBuilder private func tile(_ slot: Int) -> some View {
        let info = summary(slot)
        let filled = Self.isFilled(info)
        let isSelected = selected == slot
        let team = info?.clubID.flatMap { FootballSeason.team($0) }
        Button {
            impact += 1
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selected = slot; holdProgress = 0 }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 74, height: 74)
                    if let team {
                        ClubCrest(team: team, size: 54)
                    } else {
                        Image(systemName: "plus").font(.title.weight(.light)).foregroundStyle(.white.opacity(0.7))
                    }
                }
                .overlay {
                    Circle().strokeBorder(isSelected ? FootballTheme.gold : Color.white.opacity(0.2),
                                          style: StrokeStyle(lineWidth: isSelected ? 3 : 1, dash: filled ? [] : [5, 4]))
                        .frame(width: 74, height: 74)
                }
                Text(team?.name ?? "Espaço livre")
                    .font(.footnote.weight(.bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                Text(filled ? "Temporada \(info?.season ?? 1)" : "Nova carreira")
                    .font(.caption2).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(isSelected ? 0.16 : 0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 20)
        .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.1 + Double(slot) * 0.08), value: shown)
        .accessibilityLabel(filled ? "Perfil \(team?.name ?? ""), temporada \(info?.season ?? 1)" : "Espaço livre para uma nova carreira")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("profile-slot-\(slot)")
    }

    // MARK: Entrar

    @ViewBuilder private var action: some View {
        if selectedIsFilled {
            VStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.18), lineWidth: 4)
                    Circle().trim(from: 0, to: unlocked ? 1 : holdProgress)
                        .stroke(FootballTheme.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: unlocked ? "checkmark" : "touchid")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(unlocked ? FootballTheme.gold : Color.white)
                }
                .frame(width: 84, height: 84)
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
                .accessibilityHint("Segure para entrar na carreira selecionada")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { unlock() }
                .accessibilityIdentifier("profile-fingerprint")
                Text(unlocked ? "Bem-vindo de volta" : "Segure o dedo para entrar")
                    .font(.footnote).foregroundStyle(.white.opacity(0.75))
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

    private var batch: [AmbientNotice] { AmbientFeed.batch() }

    private var island: some View {
        let list = batch
        let notice = list[noticeIndex % list.count]
        return Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { shadeOpen = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: notice.symbol).font(.footnote).foregroundStyle(notice.tint)
                Text(notice.hidden ? "\(notice.title) · nova notificação" : "\(notice.title): \(notice.body)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .frame(maxWidth: 300)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1) }
            .id(notice.id)
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
        .accessibilityLabel("Notificação de ambiente: \(notice.title)")
        .accessibilityHint("Toque para abrir o centro de notificações")
        .accessibilityIdentifier("profile-island")
    }

    private var shade: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { shadeOpen = false } }
            VStack(spacing: 10) {
                HStack {
                    Text("Notificações").font(.headline).foregroundStyle(.white)
                    Spacer()
                    Button("Fechar") { withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { shadeOpen = false } }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("profile-shade-close")
                }
                ForEach(batch) { notice in row(notice) }
                Text("Avisos de ambiente. Não fazem parte da sua carreira.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            .padding(16)
            .frame(maxWidth: 520)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 56)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .accessibilityIdentifier("profile-shade")
    }

    private func row(_ notice: AmbientNotice) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: notice.symbol)
                .font(.footnote).foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(notice.tint.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(notice.app.uppercased()).font(.caption2.weight(.heavy)).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("agora").font(.caption2).foregroundStyle(.white.opacity(0.45))
                }
                Text(notice.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(notice.hidden ? "Conteúdo oculto" : notice.body)
                    .font(.caption).foregroundStyle(.white.opacity(notice.hidden ? 0.45 : 0.8))
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
