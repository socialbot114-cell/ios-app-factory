import SwiftUI

// MARK: - Caixa de entrada

struct FootballInboxView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    let onOpenApp: (PhoneApp) -> Void
    var focusedMessageID: Int? = nil
    @State private var selected: Selection?
    @State private var renewal: Selection?
    @State private var grouped = false
    @State private var openConversation: String?

    struct Selection: Identifiable { let id: Int }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if career.inbox.isEmpty {
                FactoryPanel(title: "Tudo em dia", systemImage: "tray.fill") {
                    Text("Atletas, diretoria, olheiros e mercado vão escrever para você aqui.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if focusedMessageID == nil && !career.inbox.isEmpty {
                Picker("Ver", selection: $grouped) {
                    Text("Linha do tempo").tag(false)
                    Text("Por conversa").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("inbox-grouping")
                if grouped && openConversation == nil { conversationList }
            }
            let focused = focusedMessageID.flatMap { id in career.inbox.first { $0.id == id } }
            if focusedMessageID != nil && focused == nil {
                Text("Esta mensagem não está mais na caixa de entrada.").font(.subheadline).foregroundStyle(.secondary)
            }
            let visible = focused.map { [$0] } ?? visibleMessages
            if grouped, let openConversation, focusedMessageID == nil {
                Button { self.openConversation = nil } label: { Label("Todas as conversas", systemImage: "chevron.left") }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("inbox-back")
                    .onAppear { career.markConversationRead(openConversation) }
            }
            ForEach(visible) { message in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: message.kind.symbol).foregroundStyle(message.isRead ? Color.secondary : FootballTheme.accent)
                        Text(message.title).font(.subheadline.weight(.bold))
                        Spacer()
                        let state = career.messageState(message)
                        if state != .unread && state != .read { PillLabel(text: state.title, tint: state == .expired ? .orange : .gray) }
                        Text("T\(message.season) · J\(message.matchDay + 1)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(message.body).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let reply = message.coachReply {
                        Label(reply, systemImage: "arrowshape.turn.up.left.fill")
                            .font(.subheadline).foregroundStyle(FootballTheme.accent)
                    }
                    attachmentRow(message)
                    if let playerID = message.playerID {
                        ForEach(career.promises.filter { $0.playerID == playerID }) { promise in
                            Text("Compromisso: \(promise.startsDone)/\(promise.requiredStarts) titularidades · prazo J\(promise.deadlineMatchDay + 1)")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    if !message.isRead {
                        Button("Marcar como lida") { career.markMessageRead(id: message.id) }
                            .font(.caption).accessibilityIdentifier("msg-read-\(message.id)")
                    }
                    if !message.isResolved { actions(for: message) }
                }
                .padding(14)
                .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .factoryPage()
        .navigationTitle("Mensagens")
        .onAppear {
            career.markTutorialSeen("inbox")
            if let focusedMessageID { career.markMessageRead(id: focusedMessageID) }
        }
        .sheet(item: $selected) { selection in
            FootballPlayerDetailView(career: $career, playerID: selection.id, onAlert: onAlert)
        }
        .sheet(item: $renewal) { selection in
            FootballRenewalSheet(career: $career, playerID: selection.id)
        }
    }

    // MARK: Conversas e anexos

    private var visibleMessages: [InboxMessage] {
        if grouped {
            guard let openConversation, let group = career.conversations().first(where: { $0.id == openConversation }) else { return [] }
            return group.messageIDs.compactMap { id in career.inbox.first { $0.id == id } }
        }
        return Array(career.inbox.reversed().prefix(60))
    }

    private var conversationList: some View {
        VStack(spacing: 10) {
            ForEach(career.conversations()) { group in
                Button { openConversation = group.id } label: {
                    HStack(spacing: 10) {
                        Image(systemName: group.playerID == nil ? "tray.full.fill" : "person.crop.circle.fill").foregroundStyle(FootballTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.title).font(.subheadline.weight(.bold))
                            Text("\(group.messageIDs.count) mensagem(ns)" + (group.open > 0 ? " · \(group.open) aguardando resposta" : "")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if group.unread > 0 { PillLabel(text: "\(group.unread) NOVA(S)", tint: FootballTheme.accent) }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("conversation-\(group.id)")
            }
        }
    }

    @ViewBuilder
    private func attachmentRow(_ message: InboxMessage) -> some View {
        let attachments = career.attachments(for: message)
        if !attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(attachments) { attachment in
                        switch attachment {
                        case .fact:
                            Label(attachment.title, systemImage: attachment.symbol).font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                        default:
                            Button { open(attachment) } label: {
                                Label(attachment.title, systemImage: attachment.symbol).font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(FootballTheme.accent.opacity(0.14), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("msg-attachment-\(message.id)-\(attachment.id)")
                        }
                    }
                }
            }
        }
    }

    private func open(_ attachment: MessageAttachment) {
        switch attachment {
        case .playerSheet(let id): selected = Selection(id: id)
        case .lineup, .commitment: onOpenApp(.squad)
        case .offer: onOpenApp(.market)
        case .contract(let id): renewal = Selection(id: id)
        case .contact: onOpenApp(.contacts)
        case .fact: break
        }
    }

    // MARK: Ações por tipo de mensagem

    @ViewBuilder
    private func actions(for message: InboxMessage) -> some View {
        let playerID = message.playerID.flatMap { career.player($0) != nil ? $0 : nil }
        HStack(spacing: 8) {
            switch message.kind {
            case .playerPlayingTime:
                if let playerID {
                    action("Prometer 3 jogos", "hand.thumbsup.fill", prominent: true, id: "msg-promise-\(message.id)") {
                        if !career.promiseStarts(playerID: playerID) { onAlert("Já existe um compromisso ou a conversa não está disponível agora.") }
                    }
                    action("Sem garantia", "xmark", id: "msg-dismiss-\(message.id)") { career.dismissRequest(playerID: playerID) }
                    action("Conversar em 2 dias", "calendar.badge.plus", id: "msg-schedule-\(message.id)") {
                        if career.replyWithMeeting(playerID: playerID) == nil { onAlert("Já há uma conversa marcada com este atleta ou o pedido não está mais aberto.") }
                    }
                    action("Ver atleta", "person.text.rectangle", id: "msg-sheet-\(message.id)") { selected = Selection(id: playerID) }
                    action("Escalação", "list.number", id: "msg-lineup-\(message.id)") { onOpenApp(.squad) }
                }
            case .playerWantsOut:
                if let playerID {
                    action("Listar para venda", "tag.fill", prominent: true, id: "msg-list-\(message.id)") {
                        career.setListed(playerID: playerID, listed: true)
                        career.resolveMessages(for: playerID, kinds: [.playerWantsOut])
                    }
                    action("Convencer a ficar", "hand.thumbsup.fill", id: "msg-stay-\(message.id)") { career.promiseStarts(playerID: playerID, starts: 2) }
                    action("Ignorar", "xmark", id: "msg-dismiss-\(message.id)") { career.dismissRequest(playerID: playerID) }
                }
            case .playerContract:
                if let playerID {
                    action("Renovar", "signature", prominent: true, id: "msg-renew-\(message.id)") { renewal = Selection(id: playerID) }
                    action("Ver ficha", "person.text.rectangle", id: "msg-sheet-\(message.id)") { selected = Selection(id: playerID) }
                }
            case .offer:
                if let offerID = message.offerID, career.offers.contains(where: { $0.id == offerID }) {
                    action("Aceitar", "checkmark", prominent: true, id: "msg-accept-\(message.id)") {
                        if career.acceptOffer(offerID) { career.resolveInboxMessage(id: message.id) } else { onAlert("Venda bloqueada: o elenco precisa continuar preenchendo a formação.") }
                    }
                    action("Recusar", "xmark", id: "msg-reject-\(message.id)") {
                        career.rejectOffer(offerID)
                        career.resolveInboxMessage(id: message.id)
                    }
                } else {
                    action("Abrir Transfer", "arrow.left.arrow.right", id: "msg-open-\(message.id)") { onOpenApp(.market) }
                }
            case .event: link("Decidir", .alerts, message)
            case .social: link("Abrir Chuteira", .social, message)
            case .agent: link("Ver propostas", .business, message)
            case .bet: link("Abrir Palpite+", .betting, message)
            case .scouting: link("Ver relatórios", .market, message)
            case .finance: link("Abrir Banco", .bank, message)
            case .injury: link("Rever escalação", .squad, message)
            case .board, .staff: link("Abrir Clube", .club, message)
            default:
                if let meeting = career.openMeetingCommitment(for: message) {
                    action("Ter a conversa", "bubble.left.and.bubble.right.fill", prominent: true, id: "msg-meeting-\(message.id)") {
                        if career.holdMeeting(commitmentID: meeting.id) { career.resolveInboxMessage(id: message.id) }
                    }
                }
                if let playerID { action("Ver ficha", "person.text.rectangle", id: "msg-sheet-\(message.id)") { selected = Selection(id: playerID) } }
            }
        }
        .font(.caption.weight(.bold))
    }

    private func action(_ title: String, _ symbol: String, prominent: Bool = false, id: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) { Label(title, systemImage: symbol).lineLimit(1).minimumScaleFactor(0.8) }
            .buttonStyle(.borderedProminent)
            .tint(prominent ? FootballTheme.accent : Color.gray)
            .accessibilityIdentifier(id)
    }

    private func link(_ title: String, _ app: PhoneApp, _ message: InboxMessage) -> some View {
        action(title, app.symbol, prominent: true, id: "msg-app-\(message.id)") { onOpenApp(app) }
    }
}

// MARK: - Coletiva de imprensa

struct FootballPressView: View {
    @Binding var career: FootballCareer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let press = career.pendingPress {
                        Text("Os jornalistas esperam suas respostas. O tom que você escolhe mexe com o vestiário, a torcida e o rival.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ForEach(press.questions) { question in
                            FactoryPanel(title: question.prompt, systemImage: "mic.fill") {
                                if let answered = question.answered {
                                    Label("Você respondeu: \(answered.title)", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.subheadline)
                                } else {
                                    ForEach(PressTone.allCases) { tone in
                                        Button { career.answerPress(questionID: question.id, tone: tone) } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(tone.title).font(.subheadline.weight(.bold))
                                                Text(question.topic?.hint(for: tone) ?? tone.summary).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(12)
                                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("press-\(question.id)-\(tone.rawValue)")
                                    }
                                }
                            }
                        }
                        Button("Pular coletiva") { career.skipPress(); dismiss() }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("press-skip")
                    }
                }
                .padding(20)
            }
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle("Coletiva")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: career.pendingPress == nil) { _, isGone in if isGone { dismiss() } }
        }
        .tint(FootballTheme.accent)
    }
}

// MARK: - Finanças

struct FootballFinanceView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                FactoryMetric(label: "Caixa", value: FootballFormat.money(career.transferBudget), symbol: "banknote.fill", tint: career.isInDebt ? .red : FootballTheme.accent)
                FactoryMetric(label: "Projeção fim de temporada", value: FootballFormat.money(career.projectedSeasonEndCash), symbol: "chart.line.uptrend.xyaxis", tint: .indigo)
            }
            HStack(spacing: 12) {
                FactoryMetric(label: "Folha salarial", value: FootballFormat.money(career.wageBill), symbol: "person.3.fill", tint: .orange)
                FactoryMetric(label: "Teto da folha", value: FootballFormat.money(career.wageCap), symbol: "lock.fill", tint: .gray)
            }
            if career.isInDebt {
                Label("Clube no vermelho: juros, risco de transfer ban e diretoria preocupada.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.red)
            }
            FootballCashProjectionPanel(career: career)
            FootballCoachLoanPanel(career: $career)
            FootballStatementsPanel(career: career)
            FactoryPanel(title: "Aporte do treinador", systemImage: "arrow.down.to.line.circle.fill") {
                Text("Seu bolso: \(FootballFormat.money(career.world.coach.personalCash)). Emprestar dinheiro ao clube alivia o caixa e, no vermelho, acalma a diretoria.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach([100_000, 250_000, 500_000], id: \.self) { amount in
                        Button("+ \(FootballFormat.money(amount))") {
                            if !career.lendToClub(amount: amount) { onAlert("Seu caixa pessoal não cobre este aporte.") }
                        }
                        .buttonStyle(.bordered).font(.caption.weight(.bold))
                        .accessibilityIdentifier("lend-\(amount)")
                    }
                }
            }
            FactoryPanel(title: "Temporada \(career.season) por categoria", systemImage: "chart.pie.fill") {
                let cats = FinanceCategory.allCases.map { ($0, career.finance.total(season: career.season, category: $0)) }.filter { $0.1 != 0 }
                if cats.isEmpty { Text("Os números aparecem depois dos primeiros jogos.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(cats, id: \.0) { category, amount in
                    HStack {
                        Image(systemName: category.symbol).frame(width: 24).foregroundStyle(amount >= 0 ? .green : .red)
                        Text(category.title).font(.subheadline)
                        Spacer()
                        Text(FootballFormat.money(amount)).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(amount >= 0 ? .green : .red)
                    }
                }
            }
            FactoryPanel(title: "Mês a mês", systemImage: "calendar") {
                let months = career.monthReports(season: career.season)
                if months.isEmpty { Text("Sem fechamento mensal ainda.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(months) { month in
                    HStack {
                        Text("Mês \(month.month)").font(.subheadline.weight(.semibold))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(FootballFormat.money(month.result)).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(month.result >= 0 ? .green : .red)
                            Text("caixa \(FootballFormat.money(month.closingCash))").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !career.finance.summaries.isEmpty {
                FactoryPanel(title: "Temporadas anteriores", systemImage: "clock.arrow.circlepath") {
                    ForEach(career.finance.summaries.reversed()) { summary in
                        HStack {
                            Text("T\(summary.season)").font(.caption.weight(.heavy))
                            Spacer()
                            Text("Receita \(FootballFormat.money(summary.income)) · Despesa \(FootballFormat.money(summary.expenses))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Finanças")
    }
}

// MARK: - Estrutura e ingressos

struct FootballFacilitiesView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let project = career.upgradeProject {
                FactoryPanel(title: "Obra em andamento", systemImage: "hammer.fill") {
                    Text("\(project.kind.title) → nível \(project.targetLevel)").font(.subheadline.weight(.bold))
                    Text("Entrega na temporada \(project.dueSeason), jogo \(project.dueMatchDay + 1).").font(.caption).foregroundStyle(.secondary)
                }
            }
            FootballConstructionPanel(career: career)
            ForEach(FacilityKind.allCases) { kind in
                FactoryPanel(title: "\(kind.title) · nível \(career.facilityLevel(kind))/\(FootballCareer.maxFacilityLevel)", systemImage: kind.symbol) {
                    Text(kind.effect).font(.caption).foregroundStyle(.secondary)
                    FootballUpgradeSimulationRow(career: career, kind: kind)
                    if let cost = career.upgradeCost(for: kind) {
                        Button {
                            if !career.startUpgrade(kind) { onAlert(career.canStartUpgrade(kind) ?? "Não foi possível iniciar a obra.") }
                        } label: {
                            Label("Melhorar · \(FootballFormat.money(cost)) · \(career.upgradeDuration(for: kind)) jogos", systemImage: "arrow.up.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("upgrade-\(kind.rawValue)")
                    } else {
                        Label("Nível máximo", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.green)
                    }
                }
            }
            FactoryPanel(title: "Estádio e bilheteria", systemImage: "ticket.fill") {
                Text("\(career.stadiumDisplayName) · capacidade \(career.stadiumCapacity.formatted(.number.locale(Locale(identifier: "pt_BR"))))")
                    .font(.subheadline.weight(.semibold))
                Picker("Preço dos ingressos", selection: $career.ticketPrice) {
                    ForEach(TicketPrice.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Ingresso caro rende mais por torcedor e enche menos o estádio. Sócios: \(career.members.formatted(.number.locale(Locale(identifier: "pt_BR")))).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .factoryPage()
        .navigationTitle("Estrutura")
    }
}

// MARK: - Comissão técnica

struct FootballStaffView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FootballStaffTasksPanel(career: $career, onAlert: onAlert)
            ForEach(StaffRole.allCases) { role in
                FactoryPanel(title: role.title, systemImage: role.symbol) {
                    Text(role.effect).font(.caption).foregroundStyle(.secondary)
                    if let member = career.staffMember(role) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name).font(.subheadline.weight(.bold))
                                Text("Habilidade \(member.ability)/20 · \(FootballFormat.money(member.wage))/temporada").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Demitir", role: .destructive) { career.fireStaff(id: member.id) }.buttonStyle(.bordered).font(.caption.weight(.bold))
                        }
                    } else {
                        Text("Vaga aberta").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    }
                    ForEach(career.staffCandidates(for: role)) { candidate in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.name).font(.subheadline)
                                Text("Habilidade \(candidate.ability) · \(FootballFormat.money(candidate.wage))/temp.").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Contratar") {
                                if !career.hireStaff(candidateID: candidate.id) { onAlert("Sem caixa para contratar.") }
                            }
                            .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                        }
                    }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Comissão técnica")
    }
}

// MARK: - Patrocínio

struct FootballSponsorView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryPanel(title: "Patrocinador master", systemImage: "megaphone.fill") {
                if let deal = career.sponsorDeal {
                    Text(deal.sponsor).font(.title3.bold())
                    Text("\(FootballFormat.money(deal.fixedPerSeason)) fixos · \(FootballFormat.money(deal.bonusPerWin)) por vitória · \(FootballFormat.money(deal.titleBonus)) pelo título · até a T\(deal.endSeason)")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Sem contrato. Escolha uma proposta abaixo.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            FactoryPanel(title: "Propostas", systemImage: "envelope.fill") {
                if career.sponsorOffers.isEmpty { Text("Novas propostas chegam no fim da temporada.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(career.sponsorOffers) { offer in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(offer.sponsor).font(.subheadline.weight(.bold))
                            Spacer()
                            PillLabel(text: offer.profile, tint: .indigo)
                        }
                        Text("\(FootballFormat.money(offer.fixedPerSeason)) fixos · \(FootballFormat.money(offer.bonusPerWin))/vitória · \(FootballFormat.money(offer.titleBonus)) pelo título · \(offer.seasons) temp.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Assinar") {
                            if !career.acceptSponsorOffer(offer.id) { onAlert("Não foi possível assinar esta proposta agora.") }
                        }
                        .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                    }
                    if offer.id != career.sponsorOffers.last?.id { Divider() }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Patrocínio")
    }
}

// MARK: - História, recordes e lendas

struct FootballStoryView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var confirmResign = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                FactoryMetric(label: "Reputação", value: "\(career.reputation)", symbol: "star.circle.fill", tint: FootballTheme.gold)
                FactoryMetric(label: "Máx. prestígio de clube", value: "\(career.maxPrestige)", symbol: "building.columns.fill", tint: .indigo)
            }
            if !career.invitations.isEmpty {
                FactoryPanel(title: "Convites", systemImage: "envelope.open.fill") {
                    ForEach(career.invitations) { invitation in
                        HStack {
                            if let team = FootballSeason.team(invitation.clubID) { ClubCrest(team: team, size: 30) }
                            Text(FootballSeason.teamName(invitation.clubID)).font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Aceitar") {
                                if !career.acceptInvitation(invitation.clubID) { onAlert("Não é possível mudar de clube agora.") }
                            }
                            .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                        }
                    }
                    Text("Aceitar troca o seu clube, mantendo reputação e patrimônio.").font(.caption).foregroundStyle(.secondary)
                }
            }
            recordsPanel
            legendsPanel
            FactoryPanel(title: "Carreira", systemImage: "figure.walk.departure") {
                Button(role: .destructive) { confirmResign = true } label: {
                    Label("Pedir demissão", systemImage: "door.left.hand.open").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Text("Você deixa o clube e escolhe entre propostas. Custa reputação.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .factoryPage()
        .navigationTitle("História")
        .confirmationDialog("Pedir demissão?", isPresented: $confirmResign, titleVisibility: .visible) {
            Button("Pedir demissão", role: .destructive) { career.resign() }
            Button("Cancelar", role: .cancel) { }
        }
    }

    private var recordsPanel: some View {
        let records = career.records
        return FactoryPanel(title: "Recordes do clube", systemImage: "list.star") {
            row("Maior artilheiro", "\(records.topScorerName) · \(records.topScorerGoals)")
            row("Mais jogos", "\(records.mostAppearancesName) · \(records.mostAppearances)")
            row("Maior vitória", records.biggestWin)
            row("Maior derrota", records.biggestLoss)
            row("Maior invencibilidade", "\(records.longestUnbeaten) jogos")
            row("Maior sequência de vitórias", "\(records.longestWinStreak)")
            row("Maior público", records.highestAttendance.formatted(.number.locale(Locale(identifier: "pt_BR"))))
            row("Mais pontos numa temporada", "\(records.mostPointsInSeason)")
        }
    }

    private var legendsPanel: some View {
        FactoryPanel(title: "Galeria de lendas", systemImage: "laurel.leading") {
            if career.legends.isEmpty { Text("Atletas históricos entram aqui ao se aposentar.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(career.legends) { legend in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(legend.name).font(.subheadline.weight(.semibold))
                        Text("\(legend.position.title) · \(legend.appearances) jogos · \(legend.goals) gols").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("T\(legend.lastSeason)").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Modos: dificuldade, desafios e tutorial

struct FootballModesView: View {
    @Binding var career: FootballCareer
    let onStartChallenge: (ChallengeScenario) -> Void
    var onAlert: (String) -> Void = { _ in }
    var saveSlots: FootballSaveSlotsView? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FootballDifficultyRulesPanel(career: $career)
            if let saveSlots { saveSlots }
            FootballPhonePreferencesPanel(career: $career)
            FootballAdvancePausesPanel(career: $career)
            FootballActionHistoryPanel(career: career)
            if let challenge = career.challenge, let scenario = ChallengeScenario.scenario(id: challenge.scenarioID) {
                FactoryPanel(title: "Desafio ativo", systemImage: "flag.checkered") {
                    Text(scenario.title).font(.subheadline.weight(.bold))
                    Text(scenario.summary).font(.caption).foregroundStyle(.secondary)
                    switch challenge.status {
                    case .active: Label("Em andamento · \(scenario.seasonsAllowed) temporada(s)", systemImage: "hourglass").font(.caption)
                    case .won: Label("Vencido!", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.green)
                    case .failed: Label(challenge.failureReason ?? "Falhou", systemImage: "xmark.seal.fill").font(.caption).foregroundStyle(.red)
                    }
                }
            }
            FactoryPanel(title: "Cenários de desafio", systemImage: "target") {
                Text("Começam uma carreira nova (a carreira atual continua salva no espaço).").font(.caption).foregroundStyle(.secondary)
                ForEach(ChallengeScenario.all) { scenario in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(scenario.title).font(.subheadline.weight(.bold))
                        Text(scenario.summary).font(.caption).foregroundStyle(.secondary)
                        Button("Aceitar desafio") { onStartChallenge(scenario) }
                            .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                            .accessibilityIdentifier("challenge-\(scenario.id)")
                    }
                    if scenario.id != ChallengeScenario.all.last?.id { Divider() }
                }
            }
            FactoryPanel(title: "Primeiros passos · \(career.tutorialProgress.done)/\(career.tutorialProgress.total)", systemImage: "graduationcap.fill") {
                ForEach(career.tutorialSteps) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: step.done ? "checkmark.circle.fill" : "circle").foregroundStyle(step.done ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title).font(.subheadline.weight(.semibold))
                            Text(step.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Toggle("Mostrar dicas no painel", isOn: Binding(get: { !career.tutorialDismissed }, set: { career.tutorialDismissed = !$0 }))
                    .font(.subheadline)
            }
        }
        .factoryPage()
        .navigationTitle("Modos de jogo")
    }
}
