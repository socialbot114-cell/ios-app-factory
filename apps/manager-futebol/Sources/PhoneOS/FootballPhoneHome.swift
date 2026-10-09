import SwiftUI

// MARK: - Tela inicial

struct PhoneHomeScreen: View {
    let career: FootballCareer
    let onOpen: (PhoneApp) -> Void
    let onNotifications: () -> Void
    let onSearch: () -> Void
    var onGuide: () -> Void = {}
    var firstRunGuideStep: FirstCareerGuideStep? = nil
    var onFirstRunGuideContinue: () -> Void = {}
    var onFirstRunGuideSkip: () -> Void = {}
    var firstRunToastStep: FirstCareerGuideStep? = nil
    var onFirstRunToastDismiss: (FirstCareerGuideStep) -> Void = { _ in }
    /// Só para capturas de tela: força o clima do papel de parede.
    var momentOverride: PhoneMoment? = nil

    var body: some View {
        ZStack {
            PhoneWallpaper(team: career.selectedClub, moment: momentOverride ?? career.phoneMoment)
            VStack(spacing: 14) {
                HStack {
                    PhoneStatusBar(career: career)
                    Button(action: onNotifications) {
                        Image(systemName: career.phoneNotifications.isEmpty ? "bell" : "bell.badge.fill")
                            .foregroundStyle(.white).frame(width: 36, height: 28)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Central de notificações, \(career.phoneNotifications.count) itens")
                    .accessibilityIdentifier("phone-notifications")
                }
                .padding(.top, 4)
                if let firstRunToastStep {
                    FirstCareerGuideToast(step: firstRunToastStep) { onFirstRunToastDismiss(firstRunToastStep) }
                        .padding(.horizontal, 16)
                }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        // Guia e busca na mesma linha: sobra espaço para todos os ícones caberem sem rolar.
                        HStack(spacing: 10) {
                            guideButton
                            Button(action: onSearch) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 52, height: 52)
                                    .background(.white.opacity(0.16), in: Circle())
                                    .contentShape(Circle())
                            }
                            .accessibilityLabel("Buscar atletas, clubes, contatos e apps")
                            .accessibilityIdentifier("phone-search")
                        }
                        if let firstRunGuideStep, firstRunGuideStep.isActive {
                            FirstCareerGuideCard(step: firstRunGuideStep, onContinue: onFirstRunGuideContinue, onSkip: onFirstRunGuideSkip)
                        }
                        widgets
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(PhoneApp.grid) { app in icon(app, id: "app-\(app.rawValue)") }
                        }
                        Color.clear.frame(height: 16)
                    }
                    .padding(.horizontal, 4)
                }
                dock
            }
            .padding(.horizontal, 16)
        }
        // Puxar do topo para baixo abre o centro de notificações, como no iPhone.
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.startLocation.y < 70, value.translation.height > 70 { onNotifications() }
            }
        )
    }

    // MARK: O que fazer agora

    private var guideButton: some View {
        let top = career.nextBestAction()
        let count = career.overnightItems().count
        return Button(action: onGuide) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("O QUE FAZER AGORA").font(.caption2.weight(.heavy)).tracking(1)
                    Text(top?.title ?? "Tudo em dia").font(.subheadline.weight(.bold)).lineLimit(1)
                }
                Spacer()
                if count > 0 {
                    Text("\(count)").font(.caption.weight(.heavy)).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.white.opacity(0.28), in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(FootballTheme.accent.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("phone-guide")
    }

    // MARK: Widgets

    private var widgets: some View {
        VStack(spacing: 10) {
            Button { onOpen(.manager) } label: { matchWidget }
                .buttonStyle(.plain)
                .accessibilityIdentifier("widget-match")
            HStack(spacing: 10) {
                smallWidget("Diretoria", "\(career.boardConfidence)%", "building.columns.fill", .app(.club))
                smallWidget("Pressão", career.pressureLabel, "flame.fill", .app(.brand))
                smallWidget("Caixa", FootballFormat.money(career.transferBudget), "banknote.fill", .app(.bank))
            }
        }
    }

    private enum Target { case app(PhoneApp) }

    private var matchWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let fixture = career.nextUserFixture {
                Text("PRÓXIMO JOGO · \(fixture.title.uppercased())").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.white.opacity(0.75))
                MatchupHeader(home: FootballSeason.team(fixture.home), away: FootballSeason.team(fixture.away), homeScore: nil, awayScore: nil, crestSize: 28)
                    .environment(\.colorScheme, .dark)
            } else if career.isSeasonComplete {
                Text("TEMPORADA ENCERRADA").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.white.opacity(0.75))
                Text("Abra o Gestor para virar a temporada.").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            } else {
                Text("DIA LIVRE").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.white.opacity(0.75))
                Text("Seu clube não joga agora. Aproveite para cuidar da vida fora de campo.").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func smallWidget(_ title: String, _ value: String, _ symbol: String, _ target: Target) -> some View {
        Button {
            if case .app(let app) = target { onOpen(app) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: symbol).font(.caption).foregroundStyle(.white.opacity(0.8))
                Text(value).font(.subheadline.weight(.heavy).monospacedDigit()).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.5), value: value)
                Text(title).font(.caption2).foregroundStyle(.white.opacity(0.75))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Ícones e dock

    private func icon(_ app: PhoneApp, id: String) -> some View {
        Button { onOpen(app) } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: app.symbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(LinearGradient(colors: [app.tint, app.tint.opacity(0.7)], startPoint: .top, endPoint: .bottom),
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    let badge = career.badge(for: app)
                    if badge > 0 {
                        // Tarefas ativas (checklist, azul) não se confundem com novidades (número, vermelho).
                        HStack(spacing: 2) {
                            if app == .quests { Image(systemName: "checklist") }
                            Text(badge > 9 ? "9+" : "\(badge)")
                        }
                        .font(.caption2.weight(.heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(app == .quests ? app.tint : Color.red, in: Capsule())
                        .offset(x: 6, y: -6)
                    }
                }
                Text(app.title).font(.caption2.weight(.medium)).foregroundStyle(.white).lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(app.title + (career.badge(for: app) > 0 ? ", \(career.badge(for: app)) \(app == .quests ? "tarefa(s) ativa(s)" : "novidade(s)")" : ""))
        .accessibilityIdentifier(id)
    }

    private var dock: some View {
        HStack(spacing: 14) {
            ForEach(PhoneApp.dock) { app in icon(app, id: "dock-\(app.rawValue)").frame(maxWidth: .infinity) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.bottom, 6)
    }
}
