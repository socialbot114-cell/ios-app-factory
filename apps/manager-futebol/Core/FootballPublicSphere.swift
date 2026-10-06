import Foundation

// MARK: - Esfera pública da Chuteira (CHU-01..06)

enum ProfileKind: String, Codable, Equatable {
    case club, journalist, pundit, player, fans
}

/// Perfil persistente de uma pessoa ou clube na Chuteira.
struct PublicProfile: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var handle: String
    let kind: ProfileKind
    var bio: String
    var followers: Int
    /// 0 a 100: sobe quando acerta (boato confirmado), cai quando erra.
    var credibility: Int
    /// -100 a 100: postura em relação ao treinador.
    var stance: Int
    var teamID: Int?
}

enum PostSubject: Codable, Equatable {
    case team
    case player(Int)
    case rival(Int)
    case journalist(String)
}

struct PostDraft: Equatable {
    var tone: PostTone
    var subject: PostSubject = .team
    var photo: SocialPhoto? = nil
}

struct PostPreview: Equatable {
    var text: String
    var reachLow: Int
    var reachHigh: Int
    var risk: String
    var effects: [String]
    var blocked: String?
}

struct PostReply: Codable, Equatable, Identifiable {
    let id: Int
    let postID: Int
    var profileID: String?
    var name: String
    var text: String
    var sentiment: Int
    let worldDay: Int
    /// Resposta do treinador a este comentário: "calm" ou "firm".
    var answer: String? = nil
}

enum PublicMemoryKind: String, Codable, Equatable {
    case controversy, praise, sponsored, crisis
}

/// O que a esfera pública lembra do treinador e pode voltar mais tarde.
struct PublicMemoryEntry: Codable, Equatable, Identifiable {
    let id: String
    let worldDay: Int
    let kind: PublicMemoryKind
    let text: String
    var weight: Int
    var postID: Int?
}

extension FootballCareer {
    static let publicMemoryLimit = 20
    static let repliesPerPostLimit = 6

    private func stableHash(_ text: String) -> Int {
        text.unicodeScalars.reduce(11) { ($0 &* 33 &+ Int($1.value)) % 1_000_003 }
    }

    // MARK: CHU-01 · perfis

    mutating func ensureProfiles() {
        guard let userClubID = selectedClubID else { return }
        func exists(_ id: String) -> Bool { profiles.contains { $0.id == id } }
        func handle(_ name: String) -> String {
            "@" + name.lowercased().folding(options: .diacriticInsensitive, locale: nil).filter { $0.isLetter || $0.isNumber }
        }
        for team in FootballSeason.teams where !exists("club-\(team.id)") {
            profiles.append(PublicProfile(id: "club-\(team.id)", name: team.name, handle: handle(team.name), kind: .club,
                                          bio: "Perfil oficial do \(team.name) · \(team.city)", followers: team.capacity * 9,
                                          credibility: 80, stance: team.id == userClubID ? 40 : 0, teamID: team.id))
        }
        for (index, name) in Self.journalistNames.enumerated() where !exists("journalist-\(index)") {
            profiles.append(PublicProfile(id: "journalist-\(index)", name: name, handle: handle(name), kind: .journalist,
                                          bio: "Repórter de futebol · bastidores e mercado", followers: 60_000 + stableHash(name) % 90_000,
                                          credibility: 50 + stableHash(name) % 30, stance: 0, teamID: nil))
        }
        for (index, name) in Self.punditNames.enumerated() where !exists("pundit-\(index)") {
            profiles.append(PublicProfile(id: "pundit-\(index)", name: name, handle: handle(name), kind: .pundit,
                                          bio: "Comentarista · análise tática", followers: 150_000 + stableHash(name) % 120_000,
                                          credibility: 60 + stableHash(name) % 25, stance: 5, teamID: nil))
        }
        if !exists("fans-\(userClubID)"), let club = selectedClub {
            profiles.append(PublicProfile(id: "fans-\(userClubID)", name: "Torcida \(club.name)", handle: handle("Torcida \(club.name)"), kind: .fans,
                                          bio: "A voz da arquibancada", followers: fanBase * 3, credibility: 50, stance: fanMood - 50, teamID: userClubID))
        }
        for athlete in clubRoster.sorted(by: { $0.overall != $1.overall ? $0.overall > $1.overall : $0.id < $1.id }).prefix(3) where !exists("player-\(athlete.id)") {
            profiles.append(PublicProfile(id: "player-\(athlete.id)", name: athlete.name, handle: handle(athlete.name), kind: .player,
                                          bio: "\(athlete.position.title) · \(FootballSeason.teamName(athlete.teamID ?? userClubID))", followers: 40_000 + athlete.overall * 3_000,
                                          credibility: 60, stance: 20, teamID: athlete.teamID))
        }
    }

    func profile(_ id: String) -> PublicProfile? { profiles.first { $0.id == id } }

    func profileID(forName name: String) -> String? { profiles.first { $0.name == name }?.id }

    private mutating func adjustProfile(_ id: String?, stance: Int = 0, credibility: Int = 0) {
        guard let id, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].stance = max(-100, min(100, profiles[index].stance + stance))
        profiles[index].credibility = max(0, min(100, profiles[index].credibility + credibility))
    }

    // MARK: CHU-02 · fonte e confiabilidade

    /// Quem diz o quê e com que confiabilidade, a partir do fato de origem. Sem fato, é opinião.
    func postSource(_ post: SocialPost) -> (label: String, reliability: String?) {
        if let reliability = post.reliability {
            let text: String
            switch reliability {
            case "confirmed": text = "confirmado"
            case "denied": text = "desmentido"
            default: text = "boato"
            }
            return ("Fonte: \(post.name) · \(text)", reliability)
        }
        switch post.author {
        case .journalist: return ("Reportagem de \(post.name)", nil)
        case .pundit: return ("Opinião de \(post.name)", nil)
        case .fan, .rival: return ("Comentário de torcedor", nil)
        default: return ("Perfil de \(post.name)", nil)
        }
    }

    /// Liga um post a um fato e à confiabilidade dele (usado nos boatos de mercado e nos arcos).
    mutating func attachFact(toPost postID: Int, factID: String, reliability: FactReliability) {
        guard let index = world.social.posts.firstIndex(where: { $0.id == postID }) else { return }
        world.social.posts[index].sourceFactID = factID
        world.social.posts[index].reliability = reliability.rawValue
        if world.social.posts[index].profileID == nil { world.social.posts[index].profileID = profileID(forName: world.social.posts[index].name) }
    }

    /// Fecha a confiabilidade de um boato: o veículo ganha ou perde credibilidade.
    mutating func settleRumor(factID: String, wasTrue: Bool, reporter: String? = nil) {
        var credited = false
        for index in world.social.posts.indices where world.social.posts[index].sourceFactID == factID && world.social.posts[index].reliability == "rumor" {
            world.social.posts[index].reliability = wasTrue ? "confirmed" : "denied"
            if world.social.posts[index].author == .journalist {
                adjustProfile(world.social.posts[index].profileID ?? profileID(forName: world.social.posts[index].name), credibility: wasTrue ? 4 : -6)
                credited = true
            }
        }
        if !credited, let reporter { adjustProfile(profileID(forName: reporter), credibility: wasTrue ? 4 : -6) }
    }

    // MARK: CHU-03 · composição com prévia

    private func composedText(_ draft: PostDraft) -> String {
        let pick = stableHash("\(draft.tone.rawValue)-\(worldDay)-\(draft.subject)")
        func choose(_ options: [String]) -> String { options[pick % options.count] }
        switch draft.subject {
        case .team:
            return choose(draft.tone == .provocative ? ["Falam muito, mas a tabela não mente.", "Quem duvida do nosso trabalho vai ter que engolir. A resposta é em campo."]
                          : (draft.tone == .serious ? ["Foco total na próxima partida. Cada ponto conta.", "Análise fria do último jogo: vamos corrigir sem desculpas."]
                             : ["Semana de trabalho duro. Quem acredita, trabalha. Vamos juntos!", "Obrigado, torcida! Vocês fazem o estádio tremer."]))
        case .player(let id):
            let name = player(id)?.name ?? "O atleta"
            switch draft.tone {
            case .provocative: return "\(name), é hora de mostrar serviço. Cobrança faz parte do jogo."
            case .serious: return "Conversei com \(name) sobre o que esperamos dele. Exigência e confiança andam juntas."
            case .humor: return "\(name) treinou tanto que o massagista pediu aumento. 😄"
            default: return "\(name) é o retrato do nosso grupo. Orgulho de treinar esse atleta."
            }
        case .rival(let id):
            let name = FootballSeason.teamName(id)
            switch draft.tone {
            case .provocative: return "O \(name) fala muito. A resposta é em campo."
            case .humor: return "Dizem que o \(name) vem forte. Também dizem que a lua cai no domingo. 😅"
            case .serious: return "Respeito total ao \(name). Jogo difícil e preparação máxima."
            default: return "Boa sorte ao \(name). Que vença o melhor."
            }
        case .journalist(let id):
            let name = profile(id)?.name ?? "o jornalista"
            switch draft.tone {
            case .provocative: return "\(name), antes de opinar, vale assistir ao treino. Informação primeiro."
            case .thanks: return "Obrigado, \(name), pela cobertura justa."
            default: return "Respondo \(name): números primeiro, opinião depois."
            }
        }
    }

    private func subjectEffects(_ draft: PostDraft) -> [String] {
        switch draft.subject {
        case .team: return []
        case .player(let id):
            let name = player(id)?.name ?? "atleta"
            switch draft.tone {
            case .thanks: return ["Moral de \(name) +4"]
            case .motivational: return ["Moral de \(name) +3"]
            case .provocative: return ["Moral de \(name) -4 (pressão pública)"]
            case .serious: return ["Moral de \(name) +1"]
            default: return []
            }
        case .rival(let id):
            let name = FootballSeason.teamName(id)
            switch draft.tone {
            case .provocative: return ["\(name) chega motivado no próximo confronto", "Polêmica +4"]
            case .humor: return ["Polêmica +2"]
            default: return ["Torcida +1"]
            }
        case .journalist(let id):
            let name = profile(id)?.name ?? "o jornalista"
            switch draft.tone {
            case .thanks: return ["Postura de \(name) +6"]
            case .serious: return ["Postura de \(name) +3"]
            case .provocative: return ["Postura de \(name) -12"]
            default: return ["Postura de \(name) -2"]
            }
        }
    }

    /// Prévia determinística: texto, alcance esperado, risco e efeitos. Nada é sorteado aqui.
    func previewPost(_ draft: PostDraft) -> PostPreview {
        let blocked = canPost(draft.tone)
        let base: Double
        switch draft.tone {
        case .motivational: base = 1.0
        case .humor: base = 1.3
        case .thanks: base = 0.9
        case .provocative: base = 1.6
        case .serious: base = 0.7
        case .sponsored: base = 0.8
        }
        let moodFactor = 0.7 + 0.006 * Double(fanMood)
        let audience = Double(world.social.coachFollowers) * 0.035 + Double(world.social.clubFollowers) * 0.004
        let reach = audience * base * moodFactor
        var backlash: Double
        switch draft.tone {
        case .provocative: backlash = 0.35
        case .humor: backlash = 0.12
        default: backlash = 0.03
        }
        if world.social.controversy > 40 { backlash += 0.1 }
        if case .rival = draft.subject, draft.tone == .provocative { backlash += 0.1 }
        let risk = backlash >= 0.3 ? "alto" : (backlash >= 0.1 ? "médio" : "baixo")
        var effects = subjectEffects(draft)
        switch draft.tone {
        case .motivational: effects.append("Torcida +1")
        case .thanks: effects.append("Torcida +2, moral do elenco +1")
        case .serious: effects.append("Diretoria +1")
        case .provocative: effects.append("Torcida +2 se vencer, -3 se não")
        case .sponsored: effects.append("Paga o contrato de marca; cansa se repetir")
        case .humor: break
        }
        return PostPreview(text: composedText(draft), reachLow: Int(reach * 0.8), reachHigh: Int(reach * 1.2), risk: risk, effects: effects, blocked: blocked)
    }

    /// Publica com assunto e alvo: o texto e os efeitos do alvo valem além do tom.
    @discardableResult
    mutating func publishPost(draft: PostDraft) -> SocialPost? {
        guard canPost(draft.tone) == nil else { return nil }
        ensureProfiles()
        let text = composedText(draft)
        guard let published = publishPost(tone: draft.tone), let index = world.social.posts.firstIndex(where: { $0.id == published.id }) else { return nil }
        world.social.posts[index].text = text
        world.social.posts[index].profileID = profileID(forName: world.coach.name)
        if let photo = draft.photo {
            // Post com foto engaja mais: +15% das curtidas, agora e no resto do engajamento.
            world.social.posts[index].photo = photo
            let boosted = Int(Double(world.social.posts[index].likes) * 1.15)
            world.social.totalLikes += max(0, boosted - world.social.posts[index].likes)
            world.social.posts[index].likes = boosted
            if let final = world.social.posts[index].finalLikes { world.social.posts[index].finalLikes = Int(Double(final) * 1.15) }
        }
        let tone = draft.tone
        switch draft.subject {
        case .team:
            world.social.posts[index].targetID = nil
        case .player(let id):
            world.social.posts[index].targetID = "player-\(id)"
            if let athleteIndex = players.firstIndex(where: { $0.id == id }), players[athleteIndex].teamID == selectedClubID {
                let delta: Int
                switch tone {
                case .thanks: delta = 4
                case .motivational: delta = 3
                case .provocative: delta = -4
                case .serious: delta = 1
                default: delta = 0
                }
                players[athleteIndex].morale = max(0, min(100, players[athleteIndex].morale + delta))
            }
        case .rival(let id):
            world.social.posts[index].targetID = "club-\(id)"
            if tone == .provocative {
                rivalMotivation[id] = max(rivalMotivation[id] ?? 0, 1.5)
                world.social.controversy = min(100, world.social.controversy + 4)
            } else if tone == .humor {
                world.social.controversy = min(100, world.social.controversy + 2)
            } else {
                fanMood = min(100, fanMood + 1)
            }
        case .journalist(let id):
            world.social.posts[index].targetID = id
            let delta: Int
            switch tone {
            case .thanks: delta = 6
            case .serious: delta = 3
            case .provocative: delta = -12
            default: delta = -2
            }
            adjustProfile(id, stance: delta)
        }
        let post = world.social.posts[index]
        if tone == .provocative {
            recordPublicMemory(id: "post-\(post.id)", kind: .controversy, text: text, weight: 2, postID: post.id)
        } else if tone == .thanks || tone == .motivational {
            recordPublicMemory(id: "post-\(post.id)", kind: .praise, text: text, weight: 1, postID: post.id)
        }
        let factID = "post-\(post.id)"
        recordFact(WorldFact(id: factID, source: .press, worldDay: worldDay, title: "Publicação do treinador",
                             detail: text, playerIDs: { if case .player(let id) = draft.subject { return [id] } else { return [] } }(), isPublic: true))
        return post
    }

    // MARK: CHU-05 · engajamento por etapas e respostas em thread

    /// Reduz o engajamento da publicação recém-feita; o restante chega nos dias seguintes, sem novo sorteio.
    mutating func stageEngagement(postID: Int, tone: PostTone) {
        guard let index = world.social.posts.firstIndex(where: { $0.id == postID }) else { return }
        var post = world.social.posts[index]
        post.finalLikes = post.likes
        post.finalShares = post.shares
        post.finalReplies = post.replies
        post.stage = 0
        post.tone = tone.rawValue
        let held = post.likes - Int(Double(post.likes) * 0.45)
        post.likes = Int(Double(post.likes) * 0.45)
        post.shares = Int(Double(post.shares) * 0.45)
        post.replies = Int(Double(post.replies) * 0.45)
        world.social.totalLikes = max(0, world.social.totalLikes - held)
        world.social.posts[index] = post
    }

    /// Roda todo dia de jogo: perfis, engajamento por etapa e respostas.
    mutating func advancePublicSphere() {
        guard selectedClubID != nil, !isFired else { return }
        ensureProfiles()
        if let fans = profiles.firstIndex(where: { $0.kind == .fans }) { profiles[fans].stance = fanMood - 50 }
        for index in world.social.posts.indices {
            let post = world.social.posts[index]
            guard post.isUser, let final = post.finalLikes, let stage = post.stage, stage < 2 else { continue }
            let age = worldDay - ((post.season - 1) * FootballSeason.matchDaysPerSeason + post.matchDay)
            let target = age >= 3 ? 2 : (age >= 1 ? 1 : 0)
            guard target > stage else { continue }
            let factor = target == 2 ? 1.0 : 0.75
            let newLikes = Int(Double(final) * factor)
            world.social.totalLikes += max(0, newLikes - post.likes)
            world.social.posts[index].likes = newLikes
            world.social.posts[index].shares = Int(Double(post.finalShares ?? post.shares) * factor)
            world.social.posts[index].replies = Int(Double(post.finalReplies ?? post.replies) * factor)
            world.social.posts[index].stage = target
            generateReplies(postID: post.id, stage: target)
        }
    }

    func replies(for postID: Int) -> [PostReply] { postReplies.filter { $0.postID == postID }.sorted { $0.id < $1.id } }

    private mutating func generateReplies(postID: Int, stage: Int) {
        guard let post = world.social.posts.first(where: { $0.id == postID }), replies(for: postID).count < Self.repliesPerPostLimit else { return }
        let tone = post.tone.flatMap { PostTone(rawValue: $0) } ?? .motivational
        let count = stage == 1 ? 2 : 1
        var candidates: [PublicProfile] = []
        if let target = post.targetID, let targeted = profile(target) { candidates.append(targeted) }
        if let fans = profiles.first(where: { $0.kind == .fans }) { candidates.append(fans) }
        let journalists = profiles.filter { $0.kind == .journalist }
        if !journalists.isEmpty { candidates.append(journalists[stableHash("\(postID)-\(stage)") % journalists.count]) }
        if tone == .provocative, let rival = profiles.filter({ $0.kind == .club && $0.teamID != selectedClubID }).sorted(by: { $0.id < $1.id })
            .dropFirst(stableHash("\(postID)") % 5).first { candidates.append(rival) }
        var made = 0
        for candidate in candidates where made < count {
            let (text, sentiment) = replyText(from: candidate, tone: tone, post: post)
            guard !text.isEmpty else { continue }
            postReplies.append(PostReply(id: nextReplyID, postID: postID, profileID: candidate.id, name: candidate.name, text: text, sentiment: sentiment, worldDay: worldDay))
            nextReplyID += 1
            made += 1
        }
        if postReplies.count > 120 { postReplies.removeFirst(postReplies.count - 120) }
    }

    private func replyText(from profile: PublicProfile, tone: PostTone, post: SocialPost) -> (String, Int) {
        switch profile.kind {
        case .fans:
            if tone == .provocative { return fanMood >= 65 ? ("Fala, professor! Vamos pra cima!", 1) : ("Cuidado com o tom, professor. A torcida está tensa.", -1) }
            return fanMood >= 55 ? ("Estamos juntos, professor!", 1) : ("Mais resultado e menos palavra, professor.", -1)
        case .journalist:
            switch tone {
            case .provocative: return ("\(profile.name): o treinador precisa explicar o tom dessa publicação.", -1)
            case .serious: return profile.stance >= 0 ? ("\(profile.name): análise coerente do treinador.", 1) : ("\(profile.name): discurso certo, resultado ainda por vir.", 0)
            default: return ("", 0)
            }
        case .club:
            return tone == .provocative || post.targetID == profile.id ? ("\(profile.name) responde: \"Conversa de quem está nervoso.\"", -1) : ("", 0)
        case .player:
            return tone == .provocative ? ("", 0) : ("\(profile.name): Obrigado, professor. Vamos trabalhar!", 1)
        case .pundit:
            return ("", 0)
        }
    }

    /// O treinador responde um comentário: conciliar acalma, rebater custa polêmica.
    @discardableResult
    mutating func answerReply(_ id: Int, firm: Bool) -> Bool {
        guard let index = postReplies.firstIndex(where: { $0.id == id }), postReplies[index].answer == nil, canAnswerPublicly else { return false }
        postReplies[index].answer = firm ? "firm" : "calm"
        let sentiment = postReplies[index].sentiment
        if firm {
            world.social.controversy = min(100, world.social.controversy + (sentiment < 0 ? 3 : 1))
            adjustProfile(postReplies[index].profileID, stance: sentiment < 0 ? -5 : -1)
        } else {
            world.social.controversy = max(0, world.social.controversy - (sentiment < 0 ? 2 : 0))
            adjustProfile(postReplies[index].profileID, stance: 3)
            world.social.coachFollowers += 60
        }
        bump("replies")
        return true
    }

    var canAnswerPublicly: Bool { selectedClubID != nil && !isFired }

    // MARK: CHU-06 · memória pública e consequências

    @discardableResult
    mutating func recordPublicMemory(id: String, kind: PublicMemoryKind, text: String, weight: Int, postID: Int? = nil) -> Bool {
        guard !publicMemory.contains(where: { $0.id == id }) else { return false }
        publicMemory.append(PublicMemoryEntry(id: id, worldDay: worldDay, kind: kind, text: text, weight: weight, postID: postID))
        if publicMemory.count > Self.publicMemoryLimit { publicMemory.removeFirst(publicMemory.count - Self.publicMemoryLimit) }
        return true
    }

    /// Fator das propostas de marca: excesso recente de publis desvaloriza o perfil.
    var brandOfferFactor: Double {
        publicMemory.contains { $0.kind == .sponsored && worldDay - $0.worldDay <= 20 } ? 0.9 : 1.0
    }

    /// Um post polêmico antigo que pode voltar numa crise.
    var resurfacingPost: PublicMemoryEntry? {
        publicMemory.filter { $0.kind == .controversy && worldDay - $0.worldDay >= 8 }.min { $0.worldDay < $1.worldDay }
    }
}
