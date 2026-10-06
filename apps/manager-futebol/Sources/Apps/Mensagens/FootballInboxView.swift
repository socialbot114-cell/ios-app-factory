import SwiftUI

// MARK: - Mensagens: o chat do FutOS

/// Conversas com jogadores, comissão técnica, família e clube, no estilo de um app de mensagens.
/// As mensagens do sistema (pedidos, propostas, avisos) viram balões com botões de resposta.
struct FootballInboxView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    let onOpenApp: (PhoneApp) -> Void
    var focusedMessageID: Int? = nil
    /// Abre direto numa conversa (usado nas capturas de tela).
    var initialThreadID: String? = nil
    @State private var selected: Selection?
    @State private var renewal: Selection?
    @State private var group: ChatGroup = .all
    @State private var openThreadID: String?
    @State private var query = ""
    @State private var showNewChat = false

    struct Selection: Identifiable { let id: Int }

    private var activeThreadID: String? {
        if let openThreadID { return openThreadID }
        return focusedMessageID.flatMap { career.chatThreadID(forMessage: $0) }
    }

    var body: some View {
        Group {
            if let id = activeThreadID, let thread = career.chatThread(id) ?? fallbackThread(id) {
                threadView(thread)
            } else {
                listView
            }
        }
        .navigationTitle("Mensagens")
        .onAppear {
            career.markTutorialSeen("inbox")
            if openThreadID == nil, let initialThreadID { openThreadID = initialThreadID }
        }
        .onChange(of: initialThreadID) { _, newValue in
            if let newValue { openThreadID = newValue }
        }
        .sheet(item: $selected) { selection in
            FootballPlayerDetailView(career: $career, playerID: selection.id, onAlert: onAlert)
        }
        .sheet(item: $renewal) { selection in
            FootballRenewalSheet(career: $career, playerID: selection.id)
        }
        .sheet(isPresented: $showNewChat) { newChatSheet }
    }

    /// Conversa recém-aberta que ainda não aparece na lista (ex.: atleta sem mensagens).
    private func fallbackThread(_ id: String) -> ChatThread? {
        guard id.hasPrefix("player-"), let playerID = Int(id.dropFirst("player-".count)), let athlete = career.player(playerID) else { return nil }
        return ChatThread(id: id, title: athlete.name, subtitle: athlete.position.title, group: .players, symbol: "figure.soccer", playerID: playerID)
    }

    private func tint(_ group: ChatGroup) -> Color {
        switch group {
        case .all: return FootballTheme.accent
        case .players: return .blue
        case .staff: return .orange
        case .family: return .pink
        case .club: return .indigo
        }
    }

    // MARK: Lista de conversas

    private var filteredThreads: [ChatThread] {
        career.chatThreads().filter { thread in
            (group == .all || thread.group == group)
                && (query.isEmpty || thread.title.localizedCaseInsensitiveContains(query) || thread.subtitle.localizedCaseInsensitiveContains(query))
        }
    }

    private var listView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar conversa", text: $query).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button { showNewChat = true } label: { Image(systemName: "square.and.pencil").font(.headline) }
                    .accessibilityLabel("Nova conversa com atleta")
                    .accessibilityIdentifier("chat-new")
            }
            .padding(10)
            .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ChatGroup.allCases) { item in
                        let unread = career.chatThreads().filter { item == .all || $0.group == item }.reduce(0) { $0 + $1.unread }
                        Button { group = item } label: {
                            HStack(spacing: 5) {
                                Image(systemName: item.symbol).font(.caption)
                                Text(item.title).font(.subheadline.weight(.semibold))
                                if unread > 0 {
                                    Text("\(unread)").font(.caption2.weight(.heavy)).foregroundStyle(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2).background(Color.green, in: Capsule())
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(group == item ? tint(item).opacity(0.25) : Color.primary.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("chat-group-\(item.rawValue)")
                    }
                }
            }
            let threads = filteredThreads
            if threads.isEmpty {
                FactoryPanel(title: "Nenhuma conversa", systemImage: "bubble.left.and.bubble.right") {
                    Text("Toque no lápis para falar com um atleta. A comissão técnica e a família ficam nas abas.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 0) {
                ForEach(threads) { thread in
                    Button { openThreadID = thread.id } label: { row(thread) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("conversation-\(thread.id)")
                    if thread.id != threads.last?.id { Divider().padding(.leading, 66) }
                }
            }
            .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .factoryPage()
    }

    private func row(_ thread: ChatThread) -> some View {
        HStack(spacing: 12) {
            Image(systemName: thread.symbol).font(.title3).foregroundStyle(.white)
                .frame(width: 46, height: 46).background(tint(thread.group).gradient, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(thread.title).font(.subheadline.weight(thread.unread > 0 ? .heavy : .semibold)).foregroundStyle(.primary).lineLimit(1)
                    Spacer()
                    if thread.unread > 0 {
                        Text("\(thread.unread)").font(.caption2.weight(.heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3).background(Color.green, in: Capsule())
                    }
                }
                HStack(spacing: 6) {
                    if thread.open > 0 { PillLabel(text: "RESPONDER", tint: .orange) }
                    Text(thread.preview.isEmpty ? thread.subtitle : thread.preview).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var newChatSheet: some View {
        NavigationStack {
            List {
                ForEach(career.clubRoster.filter { !$0.isYouth }.sorted { $0.overall > $1.overall }) { athlete in
                    Button {
                        showNewChat = false
                        openThreadID = "player-\(athlete.id)"
                    } label: {
                        HStack {
                            RatingBadge(value: athlete.overall, size: 28)
                            VStack(alignment: .leading) {
                                Text(athlete.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text(athlete.position.title).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("chat-start-\(athlete.id)")
                }
            }
            .navigationTitle("Nova conversa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { showNewChat = false } } }
        }
    }

    // MARK: Conversa

    private func threadView(_ thread: ChatThread) -> some View {
        let bubbles = career.chatBubbles(threadID: thread.id)
        let pending = bubbles.compactMap { $0.messageID }.compactMap { id in career.inbox.first { $0.id == id } }
            .filter { !$0.isResolved && (![.news, .general, .press, .transfer].contains($0.kind) || career.openMeetingCommitment(for: $0) != nil) }
            .suffix(6)
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                if focusedMessageID == nil {
                    Button { openThreadID = nil } label: { Image(systemName: "chevron.left").font(.headline) }
                        .accessibilityLabel("Todas as conversas")
                        .accessibilityIdentifier("inbox-back")
                }
                Image(systemName: thread.symbol).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(tint(thread.group).gradient, in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text(thread.title).font(.subheadline.weight(.bold))
                    Text(thread.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let playerID = thread.playerID, career.player(playerID) != nil {
                    Button { selected = Selection(id: playerID) } label: { Image(systemName: "person.text.rectangle") }
                        .accessibilityLabel("Ver ficha")
                        .accessibilityIdentifier("chat-sheet")
                } else if thread.contactRole != nil {
                    Button { onOpenApp(.contacts) } label: { Image(systemName: "person.crop.circle") }
                        .accessibilityLabel("Abrir Contatos")
                } else if thread.staffRole != nil {
                    Button { onOpenApp(.club) } label: { Image(systemName: "person.2.fill") }
                        .accessibilityLabel("Abrir comissão técnica")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(FactoryColor.card)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        if bubbles.isEmpty { emptyThread(thread) }
                        ForEach(Array(bubbles.enumerated()), id: \.element.id) { index, bubble in
                            if index == 0 || bubbles[index - 1].matchDay != bubble.matchDay || bubbles[index - 1].season != bubble.season {
                                Text(career.shortDate(matchDay: bubble.matchDay, season: bubble.season))
                                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                                    .padding(.horizontal, 10).padding(.vertical, 3)
                                    .background(Color.primary.opacity(0.06), in: Capsule())
                                    .padding(.top, 6)
                            }
                            bubbleView(bubble, thread: thread).id(bubble.id)
                        }
                        ForEach(Array(pending)) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                attachmentRow(message)
                                if let playerID = message.playerID {
                                    ForEach(career.promises.filter { $0.playerID == playerID }) { promise in
                                        Text("Compromisso: \(promise.startsDone)/\(promise.requiredStarts) titularidades · prazo \(career.shortDate(matchDay: promise.deadlineMatchDay))")
                                            .font(.caption.weight(.semibold))
                                    }
                                }
                                actions(for: message)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .id("actions-\(message.id)")
                        }
                        if let role = thread.contactRole, let contact = career.contact(role) {
                            FootballContactTopicsView(career: $career, contact: contact) { onAlert($0) }
                                .padding(12)
                                .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        Color.clear.frame(height: 4).id("bottom")
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
                .onAppear {
                    career.markConversationRead(thread.id)
                    if let focusedMessageID { career.markMessageRead(id: focusedMessageID) }
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onChange(of: bubbles.count) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            .background(FactoryColor.canvas)
            composer(thread)
        }
        .background(FactoryColor.canvas.ignoresSafeArea())
        .accessibilityIdentifier("chat-thread-\(thread.id)")
    }

    private func emptyThread(_ thread: ChatThread) -> some View {
        VStack(spacing: 6) {
            Image(systemName: thread.symbol).font(.largeTitle).foregroundStyle(.secondary)
            Text("Comece a conversa com \(thread.title).").font(.subheadline).foregroundStyle(.secondary)
            if let role = thread.contactRole { Text(role.perk).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center) }
        }
        .padding(.top, 40)
    }

    private func bubbleView(_ bubble: ChatBubble, thread: ChatThread) -> some View {
        HStack {
            if bubble.fromCoach { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 3) {
                if let header = bubble.header {
                    Text(header).font(.caption.weight(.heavy)).foregroundStyle(bubble.fromCoach ? Color.white : tint(thread.group))
                }
                Text(bubble.text).font(.subheadline).foregroundStyle(bubble.fromCoach ? Color.white : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(bubble.fromCoach ? FootballTheme.accent : FactoryColor.card,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if !bubble.fromCoach { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
    }

    private func composer(_ thread: ChatThread) -> some View {
        let quick = career.chatQuickMessages(for: thread)
        let blocker = career.chatQuickBlocker(thread)
        return VStack(alignment: .leading, spacing: 6) {
            if quick.isEmpty {
                Text("Esta conversa é só leitura: responda pelos botões das mensagens.").font(.caption).foregroundStyle(.secondary)
            } else {
                if let blocker { Text(blocker).font(.caption).foregroundStyle(.orange) }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quick) { item in
                            Button {
                                if career.sendChatQuick(threadID: thread.id, quickID: item.id) == nil { onAlert(blocker ?? "Não foi possível enviar agora.") }
                            } label: {
                                Label(item.title, systemImage: item.symbol).font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(FootballTheme.accent.opacity(blocker == nil ? 0.18 : 0.06), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .opacity(blocker == nil ? 1 : 0.5)
                            .accessibilityIdentifier("chat-quick-\(item.id)")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FactoryColor.card)
        .padding(.bottom, 24)
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
