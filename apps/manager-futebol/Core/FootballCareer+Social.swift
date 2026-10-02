import Foundation

enum CrisisResponse: String, CaseIterable, Identifiable {
    case apologize, ignore, legal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apologize: return "Pedir desculpas"
        case .ignore: return "Ignorar"
        case .legal: return "Acionar a assessoria jurídica"
        }
    }

    var hint: String {
        switch self {
        case .apologize: return "Acalma a polêmica, custa um pouco de seguidores."
        case .ignore: return "Grátis, mas a diretoria não gosta e a reputação pode cair."
        case .legal: return "Custa dinheiro e pode virar contra você, mas derruba a polêmica."
        }
    }
}

extension FootballCareer {
    static let socialPostLimit = 60
    static let fanNames = ["Marcão da Geral", "Dona Neide", "Tiago Torcedor", "Juliana FC", "Seu Zé do Bar", "Bia Arquibancada", "Capitão Raça", "Rafa Coral", "Vovô Fiel", "Lu da Torcida"]
    static let journalistNames = ["Carlos Pauta", "Renata Bastidores", "Jorge Manchete", "Ana Placar", "Beto Furo"]
    static let punditNames = ["Professor Xavier", "Mestre Lima", "Comentarista Soares"]

    var socialState: SocialState { world.social }

    // MARK: - Início

    mutating func setupSocial() {
        world.social = SocialState()
        world.social.clubFollowers = fanBase * 4
        world.social.coachFollowers = 3_000 + reputation * 300
        refreshBrandOffers()
    }

    private func handle(_ name: String) -> String {
        "@" + name.lowercased().folding(options: .diacriticInsensitive, locale: nil).filter { $0.isLetter || $0.isNumber }
    }

    // MARK: - Feed

    private mutating func addPost(author: SocialAuthor, name: String, text: String, sentiment: Int, audience: Int, tag: String? = nil,
                                  isUser: Bool = false, using random: inout FootballRandom, boost: Double = 1) -> SocialPost {
        let reach = Double(audience) * (0.004 + random.unit() * 0.02) * boost
        let post = SocialPost(id: world.social.nextPostID, season: season, matchDay: matchDayIndex, author: author, name: name, handle: handle(name),
                              text: text, likes: Int(reach), shares: Int(reach * 0.18), replies: Int(reach * 0.07), sentiment: sentiment,
                              isUser: isUser, tag: tag)
        world.social.nextPostID += 1
        world.social.posts.insert(post, at: 0)
        if world.social.posts.count > Self.socialPostLimit { world.social.posts.removeLast(world.social.posts.count - Self.socialPostLimit) }
        return post
    }

    /// Posts gerados depois de cada dia de jogo: torcida, imprensa, atletas, rivais e boatos.
    mutating func generateSocialFeed(fixture: LeagueFixture?, using random: inout FootballRandom) {
        guard let selectedClubID, let club = selectedClub else { return }
        let clubName = club.name
        if let fixture, let result = fixture.result(for: selectedClubID) {
            let opponentID = fixture.opponent(of: selectedClubID)
            let opponent = FootballSeason.teamName(opponentID)
            let own = fixture.home == selectedClubID ? fixture.homeGoals ?? 0 : fixture.awayGoals ?? 0
            let other = fixture.home == selectedClubID ? fixture.awayGoals ?? 0 : fixture.homeGoals ?? 0
            let derby = FootballSeason.isDerby(fixture.home, fixture.away)
            let fan = Self.fanNames[random.int(in: 0...(Self.fanNames.count - 1))]
            let fanText: String
            switch result {
            case .win:
                fanText = random.pick([
                    "\(own) a \(other) no \(opponent)! É por isso que a gente não desiste do \(clubName)!",
                    "Que noite! Dormi de camisa. Vamos, \(clubName)!",
                    "Se o time joga assim, o título é nosso. Parabéns, professor!"
                ]) ?? ""
            case .draw:
                fanText = random.pick([
                    "Empate com o \(opponent)... faltou um pouco de sorte, mas o time lutou.",
                    "Ponto na bagagem. Podia ter sido melhor, mas seguimos."
                ]) ?? ""
            case .loss:
                fanText = random.pick([
                    "\(other) a \(own). Assim não dá, diretoria! Precisamos de reforços já.",
                    "Que vergonha contra o \(opponent). Professor, abre o olho.",
                    "Perdemos de novo... a torcida merece mais."
                ]) ?? ""
            }
            _ = addPost(author: .fan, name: fan, text: fanText, sentiment: result == .win ? 1 : (result == .loss ? -1 : 0),
                        audience: 1_500, using: &random)

            let journalist = Self.journalistNames[random.int(in: 0...(Self.journalistNames.count - 1))]
            let headline = result == .win
                ? "\(clubName) vence o \(opponent) por \(own) a \(other) e embala na \(fixture.competition.name)."
                : (result == .draw ? "\(clubName) e \(opponent) empatam em \(own) a \(other)." : "\(opponent) surpreende e derrota o \(clubName) por \(other) a \(own).")
            _ = addPost(author: .journalist, name: journalist, text: headline, sentiment: result == .win ? 1 : (result == .loss ? -1 : 0), audience: 80_000, using: &random)

            if let best = FootballRatings.manOfTheMatch(fixture.userStats), best.rating >= 7.8, let athlete = player(best.playerID) {
                let line = best.goals > 0
                    ? "\(athlete.name): Que felicidade marcar de novo! Obrigado, torcida, essa vitória é nossa. 🙌"
                    : "\(athlete.name): Foi um jogo duro, mas o time foi gigante. Seguimos juntos!"
                _ = addPost(author: .player, name: athlete.name, text: line, sentiment: 1, audience: 60_000 + athlete.overall * 2_000, using: &random)
            }
            if derby || (result == .loss && random.chance(0.5)) {
                let rival = FootballSeason.team(opponentID)?.name ?? opponent
                let text = result == .loss ? "Hoje o \(rival) mostrou quem manda! #\(rival.filter(\.isLetter))" : "Fim de papo: o \(rival) ficou no quase. Respeitem o \(clubName)."
                _ = addPost(author: .rival, name: "Torcida \(rival)", text: text, sentiment: result == .loss ? -1 : 0, audience: 40_000,
                            tag: derby ? "#clássico" : nil, using: &random)
            }
            if random.chance(0.3) {
                let pundit = Self.punditNames[random.int(in: 0...(Self.punditNames.count - 1))]
                let texts = [
                    "A estratégia do \(clubName) tem chamado a atenção. O professor sabe o que faz.",
                    "Os números do \(clubName) em casa são de time grande. Vale acompanhar.",
                    "Esse \(clubName) lembra campeões antigos: intensidade e compromisso."
                ]
                if result != .loss { _ = addPost(author: .pundit, name: pundit, text: random.pick(texts) ?? "", sentiment: 1, audience: 200_000, using: &random) }
            }
        }
        // Boatos de mercado sobre as estrelas do clube.
        if random.chance(isTransferWindowOpen ? 0.3 : 0.08),
           let star = clubRoster.filter({ $0.overall >= 76 && !$0.onLoan }).randomElement(using: &random),
           let suitor = random.pick(FootballSeason.teams.filter { $0.id != selectedClubID }) {
            let journalist = Self.journalistNames[random.int(in: 0...(Self.journalistNames.count - 1))]
            _ = addPost(author: .journalist, name: journalist, text: "Fontes: \(suitor.name) monitora \(star.name), do \(clubName), e prepara proposta.",
                        sentiment: -1, audience: 90_000, tag: "#rumor", using: &random)
            if let index = players.firstIndex(where: { $0.id == star.id }), players[index].morale > 60 {
                players[index].morale -= 2
            }
            addInbox(.social, title: "Boato sobre \(star.name)", body: "A imprensa diz que o \(suitor.name) quer \(star.name). Fique de olho no moral dele e na renovação.", playerID: star.id)
        }
        updateFollowers(result: fixture.flatMap { $0.result(for: selectedClubID) }, using: &random)
    }

    private mutating func updateFollowers(result: FootballResult?, using random: inout FootballRandom) {
        var coachDelta = 0.0
        var clubDelta = 0.0
        switch result {
        case .win?: coachDelta = 0.006; clubDelta = 0.004
        case .loss?: coachDelta = -0.004; clubDelta = -0.002
        case .draw?: coachDelta = 0.0005
        default: coachDelta = 0.0
        }
        coachDelta += (random.unit() - 0.4) * 0.002
        world.social.coachFollowers = max(500, Int(Double(world.social.coachFollowers) * (1 + coachDelta)))
        world.social.clubFollowers = max(5_000, Int(Double(world.social.clubFollowers) * (1 + clubDelta)))
        world.social.controversy = max(0, world.social.controversy - 3)
        if world.social.coachFollowers >= 250_000 { world.social.verified = true }
    }

    // MARK: - Postar

    func canPost(_ tone: PostTone) -> String? {
        guard selectedClubID != nil, !isFired else { return "Sem clube." }
        guard world.social.lastPostWorldDay != worldDay else { return "Uma publicação por dia de jogo." }
        guard world.social.crisis == nil else { return "Resolva a crise de imagem antes de postar." }
        if tone == .sponsored {
            guard world.social.brandDeals.contains(where: { $0.postsDone < $0.postsRequired }) else { return "Sem contrato de marca com publis pendentes." }
        }
        return nil
    }

    @discardableResult
    mutating func publishPost(tone: PostTone) -> SocialPost? {
        guard canPost(tone) == nil, let selectedClubID else { return nil }
        var random = FootballRandom(seed: matchSeed(stream: .social, id: worldDay * 7 + (PostTone.allCases.firstIndex(of: tone) ?? 0)))
        world.social.lastPostWorldDay = worldDay
        let result = latestUserFixture.flatMap { $0.result(for: selectedClubID) }
        let base: Double
        switch tone {
        case .motivational: base = 1.0
        case .humor: base = 1.3
        case .thanks: base = 0.9
        case .provocative: base = 1.6
        case .serious: base = 0.7
        case .sponsored: base = 0.8
        }
        let moodFactor = 0.7 + 0.006 * Double(fanMood)
        let audience = Double(world.social.coachFollowers) * 0.035 + Double(world.social.clubFollowers) * 0.004
        var viralChance = 0.03 + (tone == .provocative ? 0.07 : 0) + (tone == .humor ? 0.04 : 0)
        if world.social.verified { viralChance += 0.02 }
        let viral = random.chance(viralChance)
        let engagement = audience * base * moodFactor * (0.8 + 0.4 * random.unit()) * (viral ? 6 : 1)

        let texts: [PostTone: [String]] = [
            .motivational: ["Semana de trabalho duro. Quem acredita, trabalha. Vamos juntos! 💪", "A gente cai, levanta e volta mais forte. Rumo ao próximo jogo."],
            .humor: ["Se o VAR existisse nos treinos, o Seu Zé da lanchonete tinha sido expulso hoje. 😅", "Meu auxiliar disse que 'só falta o título'. Aí já é pedir demais, né?"],
            .thanks: ["Obrigado, torcida! Vocês fazem o estádio tremer. Isso é do tamanho de vocês.", "Cada mensagem de apoio chegou até o vestiário. Gratidão!"],
            .provocative: ["Quem duvida do nosso trabalho vai ter que engolir. Resposta é em campo.", "Falam muito, mas a tabela não mente."],
            .serious: ["Análise fria do último jogo: erramos na transição e vamos corrigir. Sem desculpas.", "Foco total na próxima partida. Cada ponto conta."],
            .sponsored: ["Dia de treino com energia total! #publi", "Para acompanhar a rotina de quem vive futebol: conheça! #publi"]
        ]
        var text = random.pick(texts[tone] ?? ["..."]) ?? "..."
        if viral { text += " (viralizou!)" }
        var post = addPost(author: .coach, name: world.coach.name, text: text, sentiment: tone == .provocative ? -1 : 1,
                           audience: Int(audience * 100), tag: tone == .sponsored ? "#publi" : nil, isUser: true, using: &random, boost: 1)
        post.likes = Int(engagement)
        post.shares = Int(engagement * (viral ? 0.35 : 0.1))
        post.replies = Int(engagement * 0.05)
        post.viral = viral
        if let index = world.social.posts.firstIndex(where: { $0.id == post.id }) { world.social.posts[index] = post }
        world.social.totalLikes += post.likes
        if viral { world.social.viralPosts += 1 }

        var followerGain = Double(post.likes) * 0.06 * (viral ? 1.5 : 1)
        var backlashChance: Double
        switch tone {
        case .provocative: backlashChance = 0.35 * (result == .loss ? 1.6 : 1.0)
        case .humor: backlashChance = 0.12
        default: backlashChance = 0.03
        }
        if world.social.controversy > 40 { backlashChance += 0.1 }
        switch tone {
        case .motivational: fanMood = min(100, fanMood + 1)
        case .thanks:
            fanMood = min(100, fanMood + 2)
            for index in players.indices where players[index].teamID == selectedClubID && !players[index].isYouth {
                players[index].morale = min(100, players[index].morale + 1)
            }
        case .serious: boardConfidence = min(100, boardConfidence + 1)
        case .provocative: fanMood = min(100, max(0, fanMood + (result == .win ? 2 : -3)))
        case .humor, .sponsored: break
        }
        if tone == .sponsored, let dealIndex = world.social.brandDeals.firstIndex(where: { $0.postsDone < $0.postsRequired }) {
            world.social.brandDeals[dealIndex].postsDone += 1
            world.coach.personalCash += world.social.brandDeals[dealIndex].payPerPost
            world.social.sponsoredStreak += 1
            if world.social.sponsoredStreak > 3 { followerGain = -Double(world.social.coachFollowers) * 0.015 }
        } else {
            world.social.sponsoredStreak = 0
        }
        if random.chance(backlashChance) {
            world.social.controversy = min(100, world.social.controversy + 12)
            boardConfidence = max(0, boardConfidence - 2)
            fanMood = max(0, fanMood - 2)
            followerGain -= Double(world.social.coachFollowers) * 0.02
            addInbox(.social, title: "Sua publicação gerou polêmica", body: "Parte da torcida e da imprensa reagiu mal ao post. A diretoria acompanha.")
        }
        world.social.coachFollowers = max(500, world.social.coachFollowers + Int(followerGain))
        bump("posts")
        maybeTriggerCrisis(using: &random)
        return post
    }

    @discardableResult
    mutating func replyToFan(postID: Int) -> Bool {
        guard let index = world.social.posts.firstIndex(where: { $0.id == postID }), world.social.posts[index].author == .fan,
              world.social.posts[index].replies >= 0, world.social.posts[index].tag != "#respondido" else { return false }
        world.social.posts[index].tag = "#respondido"
        world.social.coachFollowers += 120
        if world.social.posts[index].sentiment < 0 { fanMood = min(100, fanMood + 1) }
        bump("replies")
        return true
    }

    // MARK: - Crises de imagem

    mutating func maybeTriggerCrisis(using random: inout FootballRandom) {
        guard world.social.crisis == nil, world.social.controversy >= 60 else { return }
        let kinds: [(CrisisKind, String, String)] = [
            (.leakedChat, "Conversa vazada", "Um áudio seu no grupo da comissão técnica vazou e está circulando nas redes."),
            (.harshComment, "Declaração mal interpretada", "Um trecho da sua entrevista foi cortado e viralizou como ofensa ao rival."),
            (.oldPost, "Publicação antiga", "Um post de anos atrás voltou e está sendo cobrado pela torcida."),
            (.fakeNews, "Notícia falsa", "Um perfil espalhou que você teria brigado com um atleta do elenco.")
        ]
        guard let picked = random.pick(kinds) else { return }
        world.social.crisis = SocialCrisis(kind: picked.0, title: picked.1, body: picked.2, matchDay: matchDayIndex)
        addInbox(.social, title: "Crise de imagem: \(picked.1)", body: picked.2)
    }

    @discardableResult
    mutating func resolveCrisis(_ response: CrisisResponse) -> String? {
        guard world.social.crisis != nil else { return nil }
        var random = FootballRandom(seed: matchSeed(stream: .social, id: worldDay + 4_000))
        var text = ""
        switch response {
        case .apologize:
            world.social.controversy = max(0, world.social.controversy - 30)
            boardConfidence = min(100, boardConfidence + 1)
            world.social.coachFollowers = Int(Double(world.social.coachFollowers) * 0.99)
            text = "O pedido de desculpas acalmou os ânimos."
        case .ignore:
            world.social.controversy = max(0, world.social.controversy - 10)
            boardConfidence = max(0, boardConfidence - 2)
            if random.chance(0.4) { changeReputation(-1) }
            text = "Ignorar deixou a diretoria desconfortável."
        case .legal:
            guard world.coach.personalCash >= 20_000 else { return nil }
            world.coach.personalCash -= 20_000
            if random.chance(0.7) {
                world.social.controversy = max(0, world.social.controversy - 25)
                text = "A assessoria derrubou os posts e a polêmica esfriou."
            } else {
                world.social.controversy = min(100, world.social.controversy + 5)
                world.social.coachFollowers = Int(Double(world.social.coachFollowers) * 0.97)
                text = "A medida saiu pela culatra e virou assunto nas redes."
            }
        }
        world.social.crisis = nil
        bump("crises")
        return text
    }

    // MARK: - Contratos de marca

    static let brands = ["Sportline", "Água Cristal", "Moto Veloz", "Banco Aliado", "Óticas Visão", "Energético Raio", "Tênis Pisada", "App Entrega Já"]

    mutating func refreshBrandOffers() {
        var random = FootballRandom(seed: matchSeed(stream: .social, id: worldDay + 9_000))
        world.social.brandOffers = []
        let followers = world.social.coachFollowers
        let tiers = [(5_000, 1), (40_000, 2), (150_000, 3)]
        for (minimum, level) in tiers where followers >= minimum {
            let brand = Self.brands[random.int(in: 0...(Self.brands.count - 1))]
            guard !world.social.brandDeals.contains(where: { $0.brand == brand }), !world.social.brandOffers.contains(where: { $0.brand == brand }) else { continue }
            world.social.brandOffers.append(BrandDeal(id: world.social.nextPostID * 100 + level, brand: brand, payPerPost: 2_000 * level * level + followers / 200,
                                                      postsRequired: 3 + level, postsDone: 0, endSeason: season + 1, minFollowers: minimum))
        }
    }

    @discardableResult
    mutating func acceptBrandDeal(id: Int) -> Bool {
        guard world.social.brandDeals.count < 2, let index = world.social.brandOffers.firstIndex(where: { $0.id == id }) else { return false }
        world.social.brandDeals.append(world.social.brandOffers.remove(at: index))
        return true
    }

    /// Contratos vencidos cobram multa por publis não feitas.
    mutating func settleBrandDeals() {
        var open: [BrandDeal] = []
        for deal in world.social.brandDeals {
            if deal.endSeason < season {
                let missing = max(0, deal.postsRequired - deal.postsDone)
                if missing > 0 { world.coach.personalCash -= missing * 3_000 }
            } else {
                open.append(deal)
            }
        }
        world.social.brandDeals = open
    }
}
