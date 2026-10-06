import Foundation

// MARK: - Fotos, histórias e curtidas da Chuteira

/// Tipos de foto que um post pode ter. A imagem é desenhada pelo app a partir do tipo (sem arquivos).
enum SocialPhoto: String, Codable, CaseIterable, Identifiable {
    case training, matchday, stadium, trophy, family, crowd, travel, press

    var id: String { rawValue }

    var title: String {
        switch self {
        case .training: return "Treino"
        case .matchday: return "Dia de jogo"
        case .stadium: return "Estádio"
        case .trophy: return "Troféu"
        case .family: return "Família"
        case .crowd: return "Torcida"
        case .travel: return "Viagem"
        case .press: return "Coletiva"
        }
    }

    var symbol: String {
        switch self {
        case .training: return "figure.run"
        case .matchday: return "sportscourt.fill"
        case .stadium: return "building.2.fill"
        case .trophy: return "trophy.fill"
        case .family: return "house.fill"
        case .crowd: return "person.3.fill"
        case .travel: return "airplane"
        case .press: return "mic.fill"
        }
    }
}

struct SocialStory: Identifiable, Equatable {
    let id: String
    let name: String
    let caption: String
    let photo: SocialPhoto
    let authorSymbol: String
}

extension SocialPost {
    /// Foto da publicação: a escolhida pelo treinador ou, nas de outras pessoas, uma foto coerente com o autor.
    var shownPhoto: SocialPhoto? {
        if let photo { return photo }
        guard !isUser, id % 2 == 0 else { return nil }
        let options: [SocialPhoto]
        switch author {
        case .club: options = [.matchday, .stadium, .trophy]
        case .player: options = [.training, .matchday, .family]
        case .fan: options = [.crowd, .stadium]
        case .journalist, .pundit: options = [.press, .stadium]
        case .rival: options = [.matchday, .crowd]
        case .coach: options = [.training]
        case .brand: options = [.travel, .training]
        }
        return options[id % options.count]
    }
}

extension FootballCareer {
    func hasLiked(_ postID: Int) -> Bool { world.social.likedPostIDs?.contains(postID) ?? false }

    @discardableResult
    mutating func toggleLike(postID: Int) -> Bool {
        guard let index = world.social.posts.firstIndex(where: { $0.id == postID }) else { return false }
        var liked = world.social.likedPostIDs ?? []
        if let at = liked.firstIndex(of: postID) {
            liked.remove(at: at)
            world.social.posts[index].likes = max(0, world.social.posts[index].likes - 1)
        } else {
            liked.append(postID)
            world.social.posts[index].likes += 1
        }
        if liked.count > 200 { liked.removeFirst(liked.count - 200) }
        world.social.likedPostIDs = liked
        return liked.contains(postID)
    }

    /// Quem aparece nas histórias do dia: o clube, três atletas, um jornalista e a casa do treinador.
    func storyItems() -> [SocialStory] {
        guard let club = selectedClub else { return [] }
        var stories: [SocialStory] = []
        let latestClub = world.social.posts.first { $0.author == .club }
        stories.append(SocialStory(id: "club", name: club.shortName, caption: latestClub?.text ?? "Dia de trabalho no CT. Foco total!",
                                   photo: latestUserFixture == nil ? .training : .matchday, authorSymbol: "shield.fill"))
        for athlete in clubRoster.filter({ !$0.isYouth }).sorted(by: { $0.overall > $1.overall }).prefix(3) {
            let moods = athlete.morale >= 70 ? "Confiança lá em cima. Bora!" : (athlete.morale >= 45 ? "Mais um dia de evolução." : "Dias difíceis, mas seguimos.")
            let name = athlete.name.split(separator: " ").last.map(String.init) ?? athlete.name
            stories.append(SocialStory(id: "player-\(athlete.id)", name: name, caption: moods,
                                       photo: athlete.id % 2 == 0 ? .training : .family, authorSymbol: "figure.soccer"))
        }
        if let press = world.social.posts.first(where: { $0.author == .journalist || $0.author == .pundit }) {
            stories.append(SocialStory(id: "press", name: press.name, caption: press.text, photo: .press, authorSymbol: "newspaper.fill"))
        }
        stories.append(SocialStory(id: "coach", name: world.coach.name.split(separator: " ").first.map(String.init) ?? "Você",
                                   caption: "Seus bastidores. Publique com foto para a torcida acompanhar.", photo: .family, authorSymbol: "person.fill.checkmark"))
        return stories
    }
}
