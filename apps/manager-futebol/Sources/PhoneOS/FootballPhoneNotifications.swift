import SwiftUI

// MARK: - Notificações derivadas do estado do jogo

struct PhoneNotification: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let app: PhoneApp
    var priority: Int = 1
    var deadlineWorldDay: Int? = nil
    var messageID: Int? = nil
    var eventID: Int? = nil
}

extension FootballCareer {
    var phoneNotifications: [PhoneNotification] {
        var list: [PhoneNotification] = []
        if pendingPress != nil {
            list.append(PhoneNotification(id: "press", title: "Coletiva de imprensa", detail: "Os jornalistas esperam suas respostas.", symbol: "mic.fill", app: .manager, priority: 3))
        }
        if let crisis = world.social.crisis {
            list.append(PhoneNotification(id: "crisis", title: "Crise de imagem", detail: crisis.title, symbol: "exclamationmark.triangle.fill", app: .social, priority: 3))
        }
        for event in world.events.pending {
            list.append(PhoneNotification(id: "event-\(event.id)", title: event.title, detail: "Prazo: \(shortDate(worldDay: event.expiresWorldDay)).", symbol: "exclamationmark.bubble.fill", app: .alerts, priority: 2, deadlineWorldDay: event.expiresWorldDay, eventID: event.id))
        }
        for (index, message) in inbox.filter({ !$0.isRead }).sorted(by: { $0.id > $1.id }).enumerated() {
            list.append(PhoneNotification(id: index == 0 ? "inbox" : "inbox-\(message.id)", title: message.title, detail: "Mensagem não lida · \(shortDate(matchDay: message.matchDay, season: message.season))", symbol: "tray.full.fill", app: .messages, messageID: message.id))
        }
        if !offers.isEmpty {
            let deadline = offers.map(\.expiresAfterRound).min() ?? matchDayIndex
            list.append(PhoneNotification(id: "offers", title: "\(offers.count) proposta(s) por seus atletas", detail: "Primeiro vencimento em \(shortDate(matchDay: deadline)).", symbol: "envelope.badge.fill", app: .market, priority: 2, deadlineWorldDay: (season - 1) * FootballSeason.matchDaysPerSeason + deadline))
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
        list = list.filter { world.phone.preferences.allows(appID: $0.app.rawValue, priority: $0.priority) }
        return list.enumerated().sorted { lhs, rhs in
            // Prazos comparáveis usam o calendário do jogo, nunca o relógio real.
            let leftDue = lhs.element.deadlineWorldDay.map { $0 <= worldDay + 1 } ?? false
            let rightDue = rhs.element.deadlineWorldDay.map { $0 <= worldDay + 1 } ?? false
            if leftDue != rightDue { return leftDue }
            if lhs.element.priority != rhs.element.priority { return lhs.element.priority > rhs.element.priority }
            let leftDeadline = lhs.element.deadlineWorldDay ?? Int.max
            let rightDeadline = rhs.element.deadlineWorldDay ?? Int.max
            if leftDeadline != rightDeadline { return leftDeadline < rightDeadline }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    func badge(for app: PhoneApp) -> Int {
        switch app {
        case .manager: return pendingPress != nil ? 1 : 0
        case .market: return offers.count
        case .club: return invitations.count
        case .messages: return unreadMessageBadge
        case .social: return world.social.crisis != nil ? 1 : 0
        case .betting: return world.betting.bets.filter { $0.status == .open }.count
        case .quests: return world.quests.active.filter { !$0.completed }.count
        case .alerts: return world.events.pending.count
        case .brand: return world.growth.tv == nil ? 1 : 0
        default: return 0
        }
    }
}


// MARK: - Central de notificações

struct PhoneNotificationCenter: View {
    let career: FootballCareer
    let onOpen: (PhoneApp) -> Void
    var onOpenMessage: ((Int) -> Void)? = nil
    var onOpenEvent: ((Int) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let items = career.phoneNotifications
                if items.isEmpty {
                    Text("Nada novo por enquanto. Mensagens e acontecimentos da carreira aparecerão aqui conforme o jogo avança.").foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    Button {
                        dismiss()
                        if let id = item.messageID, let onOpenMessage { onOpenMessage(id) }
                        else if let id = item.eventID, let onOpenEvent { onOpenEvent(id) }
                        else { onOpen(item.app) }
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
