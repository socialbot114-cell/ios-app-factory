import Foundation

// MARK: - "O que fazer agora?"

enum SuggestionCategory: String, Equatable {
    case matchday, squad, market, money, people, image, wellbeing, calendar

    var title: String {
        switch self {
        case .matchday: return "Jogo"
        case .squad: return "Elenco"
        case .market: return "Mercado"
        case .money: return "Dinheiro"
        case .people: return "Pessoas"
        case .image: return "Imagem"
        case .wellbeing: return "Bem-estar"
        case .calendar: return "Calendário"
        }
    }
}

/// Uma coisa que o jogo acha que o treinador deve fazer, e em qual app do celular.
/// `appID` é o `rawValue` de `PhoneApp` (o Core não conhece SwiftUI).
struct FootballSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let appID: String
    let symbol: String
    var category = SuggestionCategory.calendar
    /// Quanto mais alto, mais urgente (0 a 100+).
    var score = 0
    /// O que acontece se for ignorado; mostrado como "por quê".
    var why: String? = nil
    var messageID: Int? = nil
    var eventID: Int? = nil
    var actionTitle = "Ir agora"

    /// 3 = urgente, 2 = importante, 1 = bom fazer, 0 = rotina.
    var priority: Int {
        switch score {
        case 80...: return 3
        case 50...: return 2
        case 25...: return 1
        default: return 0
        }
    }
}

struct FootballTip: Equatable {
    let title: String
    let text: String
    let appID: String
    let symbol: String
}

extension FootballCareer {
    /// Bônus de urgência pelo prazo: quanto menos dias, mais alto.
    private func deadlineBonus(daysLeft: Int) -> Int {
        switch daysLeft {
        case ...0: return 30
        case 1: return 22
        case 2...3: return 12
        case 4...7: return 5
        default: return 0
        }
    }

    /// Tudo que precisa de atenção, do mais urgente para a rotina. Alimenta o botão "O que fazer agora",
    /// o resumo da noite na tela de bloqueio, o plano do dia e a conversa com a comissão técnica.
    /// Sugestões adiadas ("Depois") somem até o dia seguinte, exceto as urgentes.
    func suggestions(includeSnoozed: Bool = false) -> [FootballSuggestion] {
        guard selectedClubID != nil else { return [] }
        var list: [FootballSuggestion] = []

        if isFired {
            return [FootballSuggestion(id: "fired", title: "Você está sem clube", detail: "Escolha uma nova proposta para continuar a carreira.",
                                       appID: "club", symbol: "envelope.open.fill", category: .calendar, score: 100,
                                       why: "Sem clube, o calendário não avança.")]
        }
        let matchToday = canPlay
        let matchBoost = matchToday ? 18 : 0

        if pendingPress != nil {
            list.append(FootballSuggestion(id: "press", title: "Responder a coletiva", detail: "Os jornalistas esperam suas respostas.",
                                           appID: "manager", symbol: "mic.fill", category: .image, score: 95,
                                           why: "Ficar calado custa humor da torcida e confiança da diretoria.", actionTitle: "Responder"))
        }
        if let crisis = world.social.crisis {
            list.append(FootballSuggestion(id: "crisis", title: "Crise de imagem", detail: crisis.title,
                                           appID: "social", symbol: "exclamationmark.triangle.fill", category: .image, score: 90,
                                           why: "Enquanto a crise estiver aberta você não pode publicar e a polêmica cresce.", actionTitle: "Resolver"))
        }
        for event in world.events.pending {
            let left = event.expiresWorldDay - worldDay
            list.append(FootballSuggestion(id: "event-\(event.id)", title: event.title, detail: "Decida até \(shortDate(worldDay: event.expiresWorldDay)).",
                                           appID: "alerts", symbol: "exclamationmark.bubble.fill", category: .calendar,
                                           score: 62 + deadlineBonus(daysLeft: left),
                                           why: left <= 1 ? "Vence ao avançar o calendário." : "Some em \(left) dias de jogo.", eventID: event.id, actionTitle: "Decidir"))
        }

        // Escalação e preparação do jogo.
        if matchToday {
            let unavailable = startingXI.compactMap { player($0) }.filter { !$0.isAvailable(matchDay: matchDayIndex) }
            if let first = unavailable.first {
                list.append(FootballSuggestion(id: "lineup-out", title: "Titular indisponível: \(first.name)",
                                               detail: unavailable.count > 1 ? "\(unavailable.count) titulares fora. Refaça a escalação." : "Escolha quem entra no lugar dele.",
                                               appID: "squad", symbol: "cross.case.fill", category: .squad, score: 88,
                                               why: "Jogar com um desfalque na escalação enfraquece o time.", actionTitle: "Escalar"))
            } else if let warning = lineupWarnings.first {
                list.append(FootballSuggestion(id: "lineup-warning", title: "Ajuste a escalação", detail: warning,
                                               appID: "squad", symbol: "list.number", category: .squad, score: 66, actionTitle: "Escalar"))
            }
            let tired = startingXI.compactMap { player($0) }.filter { $0.condition < 60 }
            if !tired.isEmpty {
                list.append(FootballSuggestion(id: "lineup-tired", title: "Titulares cansados",
                                               detail: "\(tired.map(\.name).prefix(2).joined(separator: ", ")) estão abaixo de 60% de condição.",
                                               appID: "squad", symbol: "battery.25percent", category: .squad, score: 58 + matchBoost / 2,
                                               why: "Cansados rendem menos e se lesionam mais.", actionTitle: "Rotacionar"))
            }
            for item in matchPreparation() where !item.done && item.id != "lineup" && item.id != "condition" {
                list.append(FootballSuggestion(id: "prep-\(item.id)", title: item.title, detail: item.detail,
                                               appID: "manager", symbol: "checklist", category: .matchday, score: 30 + matchBoost / 2,
                                               why: "Pequeno bônus no jogo de hoje.", actionTitle: "Preparar"))
            }
        }

        // Compromissos com atletas: promessas perto do prazo e contratos acabando.
        for promise in promises where promise.startsDone < promise.requiredStarts {
            guard let athlete = player(promise.playerID), athlete.teamID == selectedClubID else { continue }
            let left = promise.deadlineMatchDay - matchDayIndex
            guard left <= 4 else { continue }
            let missing = promise.requiredStarts - promise.startsDone
            list.append(FootballSuggestion(id: "promise-\(promise.id)", title: "Promessa a \(athlete.name)",
                                           detail: "Faltam \(missing) titularidade(s) até \(shortDate(matchDay: promise.deadlineMatchDay)).",
                                           appID: "squad", symbol: "handshake.fill", category: .squad,
                                           score: 52 + deadlineBonus(daysLeft: left),
                                           why: "Promessa quebrada derruba a moral dele e a confiança do elenco.", actionTitle: "Escalar"))
        }
        for item in agenda where item.kind == .contract && item.daysRemaining <= 8 {
            list.append(FootballSuggestion(id: "contract-\(item.id)", title: item.title, detail: item.detail,
                                           appID: "squad", symbol: "signature", category: .squad, score: 44 + deadlineBonus(daysLeft: item.daysRemaining),
                                           why: "Sem renovar, ele sai de graça ao fim do contrato.", actionTitle: "Renovar"))
        }

        // Mensagens: agrupa quando são muitas; mais antigas pesam mais.
        let waiting = inbox.filter { $0.kind.needsResponse && $0.kind != .event && $0.kind != .offer && !$0.isResolved && $0.isDismissed != true }
        if waiting.count > 3, let first = waiting.last {
            list.append(FootballSuggestion(id: "msg-many", title: "\(waiting.count) mensagens esperando resposta", detail: "Atletas e empresários aguardam você.",
                                           appID: "messages", symbol: "tray.full.fill", category: .people, score: 56,
                                           why: "Atletas sem resposta ficam insatisfeitos.", messageID: first.id, actionTitle: "Responder"))
        } else {
            for message in waiting {
                let age = max(0, (season - message.season) * FootballSeason.matchDaysPerSeason + matchDayIndex - message.matchDay)
                list.append(FootballSuggestion(id: "msg-\(message.id)", title: message.title, detail: "Aguardando sua resposta em Mensagens.",
                                               appID: "messages", symbol: message.kind.symbol, category: .people, score: 46 + min(18, age * 4),
                                               why: age >= 2 ? "Já esperando há \(age) dias de jogo." : nil, messageID: message.id, actionTitle: "Responder"))
            }
        }
        if !offers.isEmpty {
            let deadline = offers.map(\.expiresAfterRound).min() ?? matchDayIndex
            list.append(FootballSuggestion(id: "offers", title: "\(offers.count) proposta(s) por seus atletas",
                                           detail: "A primeira vence em \(shortDate(matchDay: deadline)).",
                                           appID: "market", symbol: "envelope.badge.fill", category: .market,
                                           score: 50 + deadlineBonus(daysLeft: deadline - matchDayIndex),
                                           why: "Proposta ignorada expira e o clube perde a venda.", actionTitle: "Ver propostas"))
        }
        let unhappy = clubRoster.filter { !$0.isYouth && $0.morale < 40 && startingXI.contains($0.id) }
        if let first = unhappy.first {
            list.append(FootballSuggestion(id: "morale", title: "\(first.name) está desmotivado",
                                           detail: unhappy.count > 1 ? "\(unhappy.count) titulares com moral baixa. Converse no chat." : "Um elogio no chat ajuda.",
                                           appID: "messages", symbol: "face.dashed", category: .people, score: 40,
                                           why: "Moral baixa derruba o rendimento em campo.", actionTitle: "Conversar"))
        }

        // Elenco curto: hora de contratar.
        let senior = clubRoster.filter { !$0.isYouth }
        let shortage: [(FootballPosition, Int)] = [(.goalkeeper, 2), (.defender, 6), (.midfielder, 6), (.forward, 4)]
        if let missing = shortage.first(where: { position, minimum in senior.filter { $0.position == position }.count < minimum }) {
            list.append(FootballSuggestion(id: "hire-\(missing.0.rawValue)", title: "Faltam \(missing.0.title.lowercased())",
                                           detail: "O elenco tem poucos nomes nesta posição. Veja o mercado ou a base.",
                                           appID: "market", symbol: "person.badge.plus", category: .market, score: 36,
                                           why: "Uma lesão a mais e a escalação fica improvisada.", actionTitle: "Contratar"))
        }

        // Dinheiro.
        if isInDebt {
            list.append(FootballSuggestion(id: "debt", title: "Clube no vermelho", detail: "Caixa em \(FootballFormat.money(transferBudget)).",
                                           appID: "bank", symbol: "exclamationmark.triangle.fill", category: .money, score: 78,
                                           why: "Juros, risco de transfer ban e diretoria preocupada.", actionTitle: "Ver Banco"))
        } else if projectedSeasonEndCash < 0 {
            list.append(FootballSuggestion(id: "cash-projection", title: "Caixa projetado negativo", detail: "A projeção fecha a temporada em \(FootballFormat.money(projectedSeasonEndCash)).",
                                           appID: "bank", symbol: "chart.line.downtrend.xyaxis", category: .money, score: 48,
                                           why: "Segure contratações ou feche patrocínios antes do vermelho.", actionTitle: "Ver Banco"))
        }
        if wageCap > 0, Double(wageBill) > Double(wageCap) * 0.95 {
            list.append(FootballSuggestion(id: "wage-cap", title: "Folha no teto", detail: "Pouca folga para novos salários.",
                                           appID: "bank", symbol: "lock.fill", category: .money, score: 32, actionTitle: "Ver Banco"))
        }
        if world.growth.tv == nil {
            list.append(FootballSuggestion(id: "tv", title: "Escolher o contrato de TV", detail: "Se não escolher, o clube assina a cota fixa.",
                                           appID: "brand", symbol: "tv.fill", category: .money, score: 34))
        }
        if !world.growth.slotOffers.isEmpty {
            list.append(FootballSuggestion(id: "slot-offers", title: "Propostas de patrocínio", detail: "\(world.growth.slotOffers.count) cota(s) esperando resposta.",
                                           appID: "brand", symbol: "megaphone.fill", category: .money, score: 28, actionTitle: "Ver cotas"))
        }
        if !world.social.brandOffers.isEmpty {
            list.append(FootballSuggestion(id: "brand-offers", title: "Marcas querem você", detail: "Há contrato de publi na Chuteira.",
                                           appID: "social", symbol: "tag.fill", category: .image, score: 22, actionTitle: "Ver propostas"))
        }

        // Bem-estar e pessoas.
        if world.coach.energy < 30 || world.coach.stress >= 80 {
            list.append(FootballSuggestion(id: "rest", title: "Descansar", detail: "Energia em \(world.coach.energy)% e estresse em \(world.coach.stress).",
                                           appID: "life", symbol: "bed.double.fill", category: .wellbeing, score: 60 + (world.coach.energy < 15 ? 15 : 0),
                                           why: "Estresse no limite faz a diretoria perceber e o rendimento cair.", actionTitle: "Descansar"))
        }
        if !openContactRequests().isEmpty {
            list.append(FootballSuggestion(id: "contact-requests", title: "Alguém pediu sua atenção", detail: "Há pedidos abertos de contatos.",
                                           appID: "messages", symbol: "person.crop.circle.badge.exclamationmark", category: .people, score: 38,
                                           why: "Pedidos ignorados esfriam a relação.", actionTitle: "Ver pedidos"))
        }
        if relationship(.family) < 35 {
            list.append(FootballSuggestion(id: "family", title: "A família sente sua falta", detail: "Mande uma mensagem ou passe um dia em casa.",
                                           appID: "messages", symbol: "house.fill", category: .wellbeing, score: 30,
                                           why: "Sem atenção da família, o estresse sobe sozinho.", actionTitle: "Falar com a família"))
        }
        if dailyBonusAvailable && !isSelfExcluded {
            list.append(FootballSuggestion(id: "bonus", title: "Bônus de fichas disponível", detail: "Resgate no Palpite+.",
                                           appID: "betting", symbol: "gift.fill", category: .image, score: 8, actionTitle: "Resgatar"))
        }
        if world.coach.lastActivityWorldDay != worldDay && world.coach.energy >= 40 && !isSeasonComplete {
            list.append(FootballSuggestion(id: "life-activity", title: "Uma atividade do dia", detail: "Estudar, trabalhar fora ou descansar rendem dinheiro, fama e licenças.",
                                           appID: "life", symbol: "figure.walk", category: .wellbeing, score: 12))
        }
        let activeQuests = world.quests.active.filter { !$0.completed }.count
        if activeQuests > 0 {
            list.append(FootballSuggestion(id: "quests", title: "\(activeQuests) meta(s) ativa(s)", detail: "Metas rendem prêmios. Veja o que falta.",
                                           appID: "quests", symbol: "checklist", category: .calendar, score: 14, actionTitle: "Ver metas"))
        }

        // Rotina do calendário: sempre a última opção.
        if isSeasonComplete {
            list.append(FootballSuggestion(id: "season-end", title: "Encerrar a temporada", detail: "Abra o Gestor para virar o ano e ver o balanço.",
                                           appID: "manager", symbol: "flag.checkered", category: .calendar, score: 70, actionTitle: "Encerrar"))
        } else if let fixture = nextUserFixture {
            let opponent = FootballSeason.teamName(fixture.opponent(of: selectedClubID ?? 0))
            list.append(FootballSuggestion(id: "play", title: "Jogar contra \(opponent)",
                                           detail: "\(fixture.title) · \(FootballCalendarClock.shortDate(gameDay)) às \(FootballCalendarClock.clock(FootballCalendarClock.kickoff(season: season, matchDay: matchDayIndex))).",
                                           appID: "manager", symbol: "sportscourt.fill", category: .matchday, score: 5, actionTitle: "Ir ao jogo"))
        } else if canAdvanceWithoutPlaying {
            list.append(FootballSuggestion(id: "advance", title: "Avançar o calendário", detail: "Seu clube não joga hoje. Resolva o que falta e avance.",
                                           appID: "manager", symbol: "forward.fill", category: .calendar, score: 5, actionTitle: "Avançar"))
        }

        var seen = Set<String>()
        let unique = list.filter { seen.insert($0.id).inserted }
        let snoozed = world.phone.snoozedSuggestions ?? [:]
        let visible = includeSnoozed ? unique : unique.filter { item in
            guard let until = snoozed[item.id] else { return true }
            return until < worldDay || item.score >= 80
        }
        return visible.enumerated().sorted { lhs, rhs in
            lhs.element.score != rhs.element.score ? lhs.element.score > rhs.element.score : lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// A única coisa mais importante agora.
    func nextBestAction() -> FootballSuggestion? { suggestions().first }

    /// Pendências que realmente pedem ação (score ≥ 25), para o resumo da noite.
    func overnightItems(limit: Int = 5) -> [FootballSuggestion] {
        Array(suggestions().filter { $0.priority >= 1 }.prefix(limit))
    }

    /// Roteiro do dia: no máximo duas sugestões por assunto, para a lista não ficar monotemática,
    /// terminando com a rotina do calendário (jogar ou avançar).
    func dayPlan(limit: Int = 4) -> [FootballSuggestion] {
        let all = suggestions()
        var perCategory: [SuggestionCategory: Int] = [:]
        var plan: [FootballSuggestion] = []
        for item in all where item.priority >= 1 {
            guard perCategory[item.category, default: 0] < 2 else { continue }
            perCategory[item.category, default: 0] += 1
            plan.append(item)
            if plan.count >= limit - 1 { break }
        }
        if let routine = all.first(where: { $0.id == "play" || $0.id == "advance" || $0.id == "season-end" }), !plan.contains(routine) {
            plan.append(routine)
        }
        return plan
    }

    /// "Depois": a sugestão some até o próximo dia de jogo (as urgentes continuam aparecendo).
    mutating func snoozeSuggestion(_ id: String) {
        var snoozed = (world.phone.snoozedSuggestions ?? [:]).filter { $0.value >= worldDay }
        snoozed[id] = worldDay
        world.phone.snoozedSuggestions = snoozed
    }

    private static let tips: [FootballTip] = [
        FootballTip(title: "Cuide do elenco", text: "Antes de jogar, abra Tática: titulares cansados rendem menos e se lesionam mais.", appID: "squad", symbol: "person.3.fill"),
        FootballTip(title: "Converse com a comissão", text: "Em Mensagens, o auxiliar e o médico contam como o time está de verdade.", appID: "messages", symbol: "bubble.left.and.bubble.right.fill"),
        FootballTip(title: "Mercado nunca dorme", text: "Atletas livres custam só o salário. Procure reforços em Transfer.", appID: "market", symbol: "arrow.left.arrow.right"),
        FootballTip(title: "Dinheiro conta", text: "O Banco mostra a projeção do caixa. Fique de olho antes de contratar.", appID: "bank", symbol: "banknote.fill"),
        FootballTip(title: "Torcida na palma da mão", text: "Poste na Chuteira com uma foto: posts com imagem rendem mais curtidas.", appID: "social", symbol: "camera.fill"),
        FootballTip(title: "Descanse também", text: "Energia baixa derruba suas decisões. Em Vida há atividades para recarregar.", appID: "life", symbol: "bed.double.fill"),
        FootballTip(title: "Família importa", text: "Mande uma mensagem em Mensagens: a relação com a família reduz seu estresse.", appID: "messages", symbol: "house.fill"),
        FootballTip(title: "Metas do dia", text: "Metas ativas rendem prêmios. Confira o app Metas.", appID: "quests", symbol: "checklist"),
        FootballTip(title: "Prepare o próximo jogo", text: "O Gestor lista o que falta para a partida: observação do rival, bola parada e rotação.", appID: "manager", symbol: "checklist.checked"),
        FootballTip(title: "Marca forte", text: "Patrocínio e TV são renda fixa. A Marca mostra o que está aberto.", appID: "brand", symbol: "tv.and.mediabox.fill"),
        FootballTip(title: "Atletas da base", text: "Jovens crescem rápido com treino. Veja a base em Transfer.", appID: "market", symbol: "graduationcap.fill"),
        FootballTip(title: "Não deixe prazos vencerem", text: "O Gestor mostra a agenda com prazos. Propostas e promessas têm dia para acabar.", appID: "manager", symbol: "calendar.badge.clock")
    ]

    /// Dica que muda a cada dia de jogo.
    func dailyTip() -> FootballTip { Self.tips[abs(worldDay) % Self.tips.count] }

    /// A dica só aparece de vez em quando, para não virar ruído.
    var showsTipToday: Bool { worldDay % 3 == 0 }
}
