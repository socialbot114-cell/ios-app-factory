import SwiftUI

// MARK: - Apps do celular

/// Cada app é uma micro-realidade do jogo; todos leem e escrevem na mesma carreira.
enum PhoneApp: String, CaseIterable, Identifiable {
    case manager, squad, league, market, club, messages, social, betting, fantasy
    case life, business, quests, trophies, alerts, brand, bank, contacts, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manager: return "Gestor"
        case .squad: return "Tática"
        case .league: return "Liga"
        case .market: return "Transfer"
        case .club: return "Clube"
        case .messages: return "Mensagens"
        case .social: return "Chuteira"
        case .betting: return "Palpite+"
        case .fantasy: return "Rodada"
        case .life: return "Vida"
        case .business: return "Negócios"
        case .quests: return "Metas"
        case .trophies: return "Troféus"
        case .alerts: return "Alertas"
        case .brand: return "Marca"
        case .bank: return "Banco"
        case .contacts: return "Contatos"
        case .settings: return "Ajustes"
        }
    }

    var symbol: String {
        switch self {
        case .manager: return "house.fill"
        case .squad: return "person.3.fill"
        case .league: return "list.number"
        case .market: return "arrow.left.arrow.right"
        case .club: return "trophy.fill"
        case .messages: return "tray.full.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .betting: return "ticket.fill"
        case .fantasy: return "sportscourt.fill"
        case .life: return "figure.walk"
        case .business: return "building.2.crop.circle.fill"
        case .quests: return "checklist"
        case .trophies: return "medal.fill"
        case .alerts: return "exclamationmark.bubble.fill"
        case .brand: return "tv.and.mediabox.fill"
        case .bank: return "banknote.fill"
        case .contacts: return "person.crop.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var tint: Color {
        switch self {
        case .manager: return Color(red: 0.06, green: 0.55, blue: 0.34)
        case .squad: return .blue
        case .league: return .indigo
        case .market: return .orange
        case .club: return Color(red: 0.80, green: 0.58, blue: 0.10)
        case .messages: return .green
        case .social: return .pink
        case .betting: return .purple
        case .fantasy: return Color(red: 0.20, green: 0.62, blue: 0.30)
        case .life: return .teal
        case .business: return Color(red: 0.35, green: 0.35, blue: 0.80)
        case .quests: return Color(red: 0.20, green: 0.45, blue: 0.85)
        case .trophies: return Color(red: 0.85, green: 0.64, blue: 0.16)
        case .alerts: return .red
        case .brand: return Color(red: 0.85, green: 0.25, blue: 0.45)
        case .bank: return Color(red: 0.10, green: 0.50, blue: 0.40)
        case .contacts: return Color(red: 0.25, green: 0.55, blue: 0.65)
        case .settings: return Color(red: 0.45, green: 0.47, blue: 0.52)
        }
    }

    static let dock: [PhoneApp] = [.manager, .messages, .social, .club]
    static var grid: [PhoneApp] { allCases.filter { !dock.contains($0) } }
}

// MARK: - Notificações derivadas do estado do jogo

struct PhoneNotification: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let app: PhoneApp
}

extension FootballCareer {
    var phoneNotifications: [PhoneNotification] {
        var list: [PhoneNotification] = []
        if pendingPress != nil {
            list.append(PhoneNotification(id: "press", title: "Coletiva de imprensa", detail: "Os jornalistas esperam suas respostas.", symbol: "mic.fill", app: .manager))
        }
        if let crisis = world.social.crisis {
            list.append(PhoneNotification(id: "crisis", title: "Crise de imagem", detail: crisis.title, symbol: "exclamationmark.triangle.fill", app: .social))
        }
        for event in world.events.pending {
            list.append(PhoneNotification(id: "event-\(event.id)", title: event.title, detail: "Decida até o dia \(event.expiresWorldDay).", symbol: "exclamationmark.bubble.fill", app: .alerts))
        }
        if unreadCount > 0 {
            list.append(PhoneNotification(id: "inbox", title: "\(unreadCount) mensagem(ns) nova(s)", detail: inbox.last?.title ?? "", symbol: "tray.full.fill", app: .messages))
        }
        if !offers.isEmpty {
            list.append(PhoneNotification(id: "offers", title: "\(offers.count) proposta(s) por seus atletas", detail: "Responda antes que expirem.", symbol: "envelope.badge.fill", app: .market))
        }
        if !invitations.isEmpty {
            list.append(PhoneNotification(id: "invites", title: "Convite de outro clube", detail: FootballSeason.teamName(invitations[0].clubID), symbol: "envelope.open.fill", app: .club))
        }
        if dailyBonusAvailable && !isSelfExcluded {
            list.append(PhoneNotification(id: "bonus", title: "Bônus de fichas disponível", detail: "Resgate no Palpite+.", symbol: "gift.fill", app: .betting))
        }
        if world.growth.tv == nil {
            list.append(PhoneNotification(id: "tv", title: "Escolha o contrato de TV", detail: "Se não escolher, o clube assina a cota fixa.", symbol: "tv.fill", app: .brand))
        }
        if world.coach.energy < 25 {
            list.append(PhoneNotification(id: "energy", title: "Bateria baixa", detail: "Sua energia está em \(world.coach.energy)%. Descanse na Vida.", symbol: "battery.25percent", app: .life))
        }
        return list
    }

    func badge(for app: PhoneApp) -> Int {
        switch app {
        case .manager: return pendingPress != nil ? 1 : 0
        case .market: return offers.count
        case .club: return invitations.count
        case .messages: return unreadCount
        case .social: return world.social.crisis != nil ? 1 : 0
        case .betting: return world.betting.bets.filter { $0.status == .open }.count
        case .quests: return world.quests.active.filter { !$0.completed }.count
        case .alerts: return world.events.pending.count
        case .brand: return world.growth.tv == nil ? 1 : 0
        default: return 0
        }
    }
}

// MARK: - Inicialização do sistema

struct PhoneBootView: View {
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Image(systemName: "soccerball.inverse").font(.system(size: 64)).foregroundStyle(.white)
                Text("FutOS").font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                ProgressView(value: progress).tint(.white).frame(width: 160)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.1)) { progress = 1 } }
        .accessibilityLabel("Iniciando o FutOS")
    }
}

// MARK: - Barra de status

struct PhoneStatusBar: View {
    let career: FootballCareer

    var body: some View {
        HStack(spacing: 10) {
            Text("T\(career.season) · J\(min(career.matchDayIndex + 1, FootballSeason.matchDaysPerSeason))")
                .font(.caption.weight(.bold).monospacedDigit())
            Spacer()
            if let club = career.selectedClub { ClubCrest(team: club, size: 16) }
            Spacer()
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule().fill(Color.white.opacity(career.fanMood >= 25 * (index + 1) - 10 ? 1 : 0.3)).frame(width: 3, height: CGFloat(5 + index * 3))
                }
            }
            Image(systemName: career.world.coach.energy >= 60 ? "battery.100" : (career.world.coach.energy >= 30 ? "battery.50" : "battery.25"))
                .font(.caption)
            Text("\(career.world.coach.energy)%").font(.caption2.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Temporada \(career.season), energia \(career.world.coach.energy) por cento")
    }
}

// MARK: - Tela de bloqueio

struct PhoneLockScreen: View {
    let career: FootballCareer
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            PhoneWallpaper(team: career.selectedClub)
            VStack(spacing: 18) {
                PhoneStatusBar(career: career).padding(.top, 8)
                Spacer(minLength: 20)
                Text("Semana \(career.currentSlot?.week ?? 0)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                Text(career.currentSlot?.dayName ?? "Fim de temporada")
                    .font(.system(size: 64, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                Text(career.world.coach.name).font(.headline).foregroundStyle(.white.opacity(0.85))
                VStack(spacing: 8) {
                    ForEach(career.phoneNotifications.prefix(3)) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol).frame(width: 28).foregroundStyle(item.app.tint)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                Spacer()
                Button(action: onUnlock) {
                    VStack(spacing: 6) {
                        Image(systemName: "chevron.compact.up").font(.title)
                        Text("Toque para abrir").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("phone-unlock")
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 16)
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { value in if value.translation.height < -60 { onUnlock() } })
    }
}

struct PhoneWallpaper: View {
    let team: LeagueTeam?

    var body: some View {
        let color = team?.primaryColor ?? FootballTheme.accent
        LinearGradient(colors: [color, color.opacity(0.55), Color.black.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(alignment: .topTrailing) {
                Image(systemName: team?.crestSymbol ?? "soccerball").font(.system(size: 220)).foregroundStyle(.white.opacity(0.06)).offset(x: 50, y: 60)
            }
            .ignoresSafeArea()
    }
}

// MARK: - Tela inicial

struct PhoneHomeScreen: View {
    let career: FootballCareer
    let onOpen: (PhoneApp) -> Void
    let onNotifications: () -> Void
    let onSearch: () -> Void

    var body: some View {
        ZStack {
            PhoneWallpaper(team: career.selectedClub)
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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        Button(action: onSearch) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                Text("Buscar atletas, clubes, contatos e apps")
                                Spacer()
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(12)
                            .background(.white.opacity(0.16), in: Capsule())
                            .contentShape(Capsule())
                        }
                        .accessibilityIdentifier("phone-search")
                        widgets
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 18) {
                            ForEach(PhoneApp.grid) { app in icon(app, id: "app-\(app.rawValue)") }
                        }
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
        }
        .overlay(alignment: .bottom) { dock }
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
                MatchupHeader(home: FootballSeason.team(fixture.home), away: FootballSeason.team(fixture.away), homeScore: nil, awayScore: nil, crestSize: 36)
                    .environment(\.colorScheme, .dark)
            } else if career.isSeasonComplete {
                Text("TEMPORADA ENCERRADA").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.white.opacity(0.75))
                Text("Abra o Gestor para virar a temporada.").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            } else {
                Text("DIA LIVRE").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.white.opacity(0.75))
                Text("Seu clube não joga agora. Aproveite para cuidar da vida fora de campo.").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
        }
        .padding(14)
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
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: app.symbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(LinearGradient(colors: [app.tint, app.tint.opacity(0.7)], startPoint: .top, endPoint: .bottom),
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    let badge = career.badge(for: app)
                    if badge > 0 {
                        Text(badge > 9 ? "9+" : "\(badge)").font(.caption2.weight(.heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.red, in: Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
                Text(app.title).font(.caption2.weight(.medium)).foregroundStyle(.white).lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(app.title + (career.badge(for: app) > 0 ? ", \(career.badge(for: app)) novidade(s)" : ""))
        .accessibilityIdentifier(id)
    }

    private var dock: some View {
        HStack(spacing: 14) {
            ForEach(PhoneApp.dock) { app in icon(app, id: "dock-\(app.rawValue)").frame(maxWidth: .infinity) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}

// MARK: - Central de notificações

struct PhoneNotificationCenter: View {
    let career: FootballCareer
    let onOpen: (PhoneApp) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let items = career.phoneNotifications
                if items.isEmpty {
                    Text("Nada novo por enquanto.").foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    Button {
                        dismiss()
                        onOpen(item.app)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol).frame(width: 30).foregroundStyle(item.app.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text(item.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.app.title).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityIdentifier("notification-\(item.id)")
                }
            }
            .navigationTitle("Notificações")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
        }
        .tint(FootballTheme.accent)
    }
}

// MARK: - Busca (Spotlight)

struct PhoneSpotlight: View {
    let career: FootballCareer
    let initialQuery: String
    let onApp: (PhoneApp) -> Void
    let onPlayer: (Int) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var term: String { query.trimmingCharacters(in: .whitespaces).lowercased() }

    private var apps: [PhoneApp] { term.isEmpty ? [] : PhoneApp.allCases.filter { $0.title.lowercased().contains(term) } }

    private var players: [FootballPlayer] {
        guard term.count >= 2 else { return [] }
        return Array(career.players.filter { !$0.isYouth || $0.teamID == career.selectedClubID }
            .filter { $0.name.lowercased().contains(term) }.sorted { $0.overall > $1.overall }.prefix(8))
    }

    private var clubs: [LeagueTeam] {
        guard term.count >= 2 else { return [] }
        return FootballSeason.teams.filter { $0.name.lowercased().contains(term) || $0.city.lowercased().contains(term) }
    }

    private var contacts: [Contact] {
        guard term.count >= 2 else { return [] }
        return career.world.contacts.contacts.filter { $0.name.lowercased().contains(term) || $0.role.title.lowercased().contains(term) }
    }

    var body: some View {
        NavigationStack {
            List {
                if term.isEmpty {
                    Text("Digite um nome: atleta, clube, contato ou app. Tudo no celular se encontra aqui.").font(.subheadline).foregroundStyle(.secondary)
                }
                if !apps.isEmpty {
                    Section("Apps") {
                        ForEach(apps) { app in
                            Button { dismiss(); onApp(app) } label: { Label(app.title, systemImage: app.symbol) }
                        }
                    }
                }
                if !players.isEmpty {
                    Section("Atletas") {
                        ForEach(players) { player in
                            Button { dismiss(); onPlayer(player.id) } label: {
                                HStack {
                                    RatingBadge(value: player.overall, size: 28)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(player.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                        Text("\(player.position.title) · \(player.teamID.flatMap { FootballSeason.team($0)?.name } ?? "Livre")")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .accessibilityIdentifier("search-player-\(player.id)")
                        }
                    }
                }
                if !clubs.isEmpty {
                    Section("Clubes") {
                        ForEach(clubs) { team in
                            Button { dismiss(); onApp(.league) } label: {
                                HStack { ClubCrest(team: team, size: 22); Text(team.name); Spacer(); Text(team.city).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                if !contacts.isEmpty {
                    Section("Contatos") {
                        ForEach(contacts) { contact in
                            Button { dismiss(); onApp(.contacts) } label: { Label("\(contact.name) · \(contact.role.title)", systemImage: contact.role.symbol) }
                        }
                    }
                }
                if !term.isEmpty && apps.isEmpty && players.isEmpty && clubs.isEmpty && contacts.isEmpty {
                    Text("Nada encontrado para \"\(query)\".").foregroundStyle(.secondary)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar no celular")
            .navigationTitle("Busca")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
            .onAppear { if query.isEmpty { query = initialQuery } }
        }
        .tint(FootballTheme.accent)
    }
}

// MARK: - App Contatos

struct FootballContactsView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Seis pessoas que acompanham a sua carreira. Conversar custa energia e só dá para uma conversa por dia de jogo. Quem fica sem atenção esfria.")
                .font(.subheadline).foregroundStyle(.secondary)
            if let note {
                Label(note, systemImage: "checkmark.circle.fill").font(.subheadline.weight(.medium)).foregroundStyle(FootballTheme.accent)
            }
            ForEach(career.world.contacts.contacts) { contact in
                FactoryPanel {
                    HStack(spacing: 12) {
                        Image(systemName: contact.role.symbol).font(.title3).foregroundStyle(.white)
                            .frame(width: 44, height: 44).background(Color.teal.gradient, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name).font(.headline)
                            Text(contact.role.title).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(contact.relationship)").font(.title3.weight(.heavy).monospacedDigit())
                    }
                    ConditionBar(value: contact.relationship)
                    Text(contact.role.perk).font(.caption).foregroundStyle(.secondary)
                    let block = career.canContact(contact.role)
                    Button {
                        if let text = career.contactAction(contact.role) { note = text } else { onAlert(block ?? "Indisponível.") }
                    } label: {
                        Label(contact.role.action, systemImage: "phone.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .opacity(block == nil ? 1 : 0.45)
                    .accessibilityIdentifier("contact-\(contact.role.rawValue)")
                }
            }
        }
        .factoryPage()
        .navigationTitle("Contatos")
    }
}
