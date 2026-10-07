import Foundation

struct QuestTemplate {
    let id: String
    let title: String
    let detail: String
    let counter: String
    let target: Int
    let reward: QuestReward
    let seasonal: Bool
}

extension FootballCareer {
    static let questTemplates: [QuestTemplate] = [
        QuestTemplate(id: "w-wins", title: "Embalo", detail: "Vença 2 jogos.", counter: "wins", target: 2, reward: QuestReward(fichas: 150, reputation: 1), seasonal: false),
        QuestTemplate(id: "w-press", title: "Imprensa em dia", detail: "Responda 3 perguntas de coletiva.", counter: "press", target: 3, reward: QuestReward(fichas: 100, followers: 1_500), seasonal: false),
        QuestTemplate(id: "w-posts", title: "Voz nas redes", detail: "Publique 2 vezes na Chuteira.", counter: "posts", target: 2, reward: QuestReward(followers: 2_500), seasonal: false),
        QuestTemplate(id: "w-bets", title: "Palpite do dia", detail: "Faça 2 palpites no Palpite+.", counter: "bets", target: 2, reward: QuestReward(fichas: 80), seasonal: false),
        QuestTemplate(id: "w-activities", title: "Agenda cheia", detail: "Cumpra 3 atividades da agenda pessoal.", counter: "activities", target: 3, reward: QuestReward(cash: 20_000), seasonal: false),
        QuestTemplate(id: "w-signing", title: "Reforço à vista", detail: "Contrate 1 atleta.", counter: "signings", target: 1, reward: QuestReward(fichas: 120, reputation: 1), seasonal: false),
        QuestTemplate(id: "w-events", title: "Resolva a situação", detail: "Decida 1 acontecimento.", counter: "events", target: 1, reward: QuestReward(fichas: 100), seasonal: false),
        QuestTemplate(id: "w-fantasy", title: "Time dos sonhos", detail: "Atualize a escalação da Rodada Mágica.", counter: "fantasyLineups", target: 1, reward: QuestReward(fichas: 120), seasonal: false),
        QuestTemplate(id: "w-friendly", title: "Bola rolando", detail: "Dispute 1 amistoso.", counter: "friendlies", target: 1, reward: QuestReward(cash: 15_000, reputation: 1), seasonal: false),
        QuestTemplate(id: "w-comeback", title: "Nunca desista", detail: "Vire 1 jogo que estava perdendo.", counter: "comebacks", target: 1, reward: QuestReward(fichas: 200, reputation: 1, followers: 3_000), seasonal: false),
        QuestTemplate(id: "w-cleansheet", title: "Defesa de ferro", detail: "Fique sem sofrer gol em 2 jogos.", counter: "cleanSheets", target: 2, reward: QuestReward(fichas: 150, cash: 20_000), seasonal: false),
        QuestTemplate(id: "w-hype", title: "Casa cheia", detail: "Termine 2 jogos com a torcida empolgada (embalo 70+).", counter: "hypeMatches", target: 2, reward: QuestReward(fichas: 180, followers: 2_000), seasonal: false),
        QuestTemplate(id: "s-bigwins", title: "Goleador coletivo", detail: "Vença 3 jogos por 3 gols de diferença ou mais.", counter: "bigWins", target: 3, reward: QuestReward(fichas: 500, reputation: 2, followers: 8_000), seasonal: true),
        QuestTemplate(id: "s-upsets", title: "Matador de gigantes", detail: "Vença 3 jogos contra adversários mais fortes.", counter: "upsets", target: 3, reward: QuestReward(fichas: 500, reputation: 2), seasonal: true),
        QuestTemplate(id: "s-wins", title: "Temporada vitoriosa", detail: "Vença 10 jogos na temporada.", counter: "wins", target: 10, reward: QuestReward(fichas: 600, reputation: 2), seasonal: true),
        QuestTemplate(id: "s-matches", title: "Maratona", detail: "Dispute 20 jogos oficiais.", counter: "matches", target: 20, reward: QuestReward(fichas: 400, cash: 50_000), seasonal: true),
        QuestTemplate(id: "s-posts", title: "Influenciador", detail: "Publique 12 vezes nas redes.", counter: "posts", target: 12, reward: QuestReward(cash: 30_000, followers: 15_000), seasonal: true),
        QuestTemplate(id: "s-events", title: "Homem de decisões", detail: "Resolva 8 acontecimentos.", counter: "events", target: 8, reward: QuestReward(fichas: 500, reputation: 2), seasonal: true),
        QuestTemplate(id: "s-bets", title: "Palpiteiro", detail: "Faça 15 palpites.", counter: "bets", target: 15, reward: QuestReward(fichas: 300), seasonal: true)
    ]

    func progress(of quest: Quest) -> Int { min(quest.target, max(0, (counters[quest.counter] ?? 0) - quest.baseline)) }

    mutating func refreshQuests(using random: inout FootballRandom) {
        let today = worldDay
        for quest in world.quests.active where !quest.completed && quest.expiresWorldDay < today {
            recordQuest(quest, outcome: .failed)
        }
        world.quests.active.removeAll { $0.completed || $0.expiresWorldDay < today }
        let activeIDs = Set(world.quests.active.map(\.templateID))
        var pool = Self.questTemplates.filter { template in !template.seasonal && !activeIDs.contains(template.id) && !Self.questOptInIDs.contains(template.id) }
        while world.quests.active.filter({ !$0.seasonal }).count < 3, !pool.isEmpty {
            let template = pool.remove(at: random.int(in: 0...(pool.count - 1)))
            addQuest(template)
        }
        let seasonalCount = world.quests.active.filter(\.seasonal).count
        if seasonalCount < 2 {
            let seasonalIDs = Set(world.quests.active.map(\.templateID))
            var seasonalPool = Self.questTemplates.filter { template in template.seasonal && !seasonalIDs.contains(template.id) && !Self.questOptInIDs.contains(template.id) }
            for _ in 0..<(2 - seasonalCount) where !seasonalPool.isEmpty {
                addQuest(seasonalPool.remove(at: random.int(in: 0...(seasonalPool.count - 1))))
            }
        }
        world.quests.lastRefreshWorldDay = worldDay
    }

    mutating func addQuest(_ template: QuestTemplate, adopted: Bool = false) {
        let expiry = worldDay + (template.seasonal ? FootballSeason.matchDaysPerSeason - matchDayIndex : 6)
        world.quests.active.append(Quest(id: world.quests.nextQuestID, templateID: template.id, title: template.title, detail: template.detail,
                                         counter: template.counter, baseline: counters[template.counter] ?? 0, target: template.target,
                                         reward: template.reward, expiresWorldDay: expiry, seasonal: template.seasonal,
                                         origin: adopted ? .player : Self.questOrigin(for: template.id).origin,
                                         sourceName: adopted ? "Você" : Self.questOrigin(for: template.id).source))
        world.quests.nextQuestID += 1
    }

    /// Conclui as missões cumpridas e paga as recompensas.
    mutating func updateQuests() {
        for index in world.quests.active.indices where !world.quests.active[index].completed {
            let quest = world.quests.active[index]
            guard progress(of: quest) >= quest.target else { continue }
            world.quests.active[index].completed = true
            recordQuest(world.quests.active[index], outcome: .completed)
            world.quests.completedCount += 1
            world.betting.fichas += quest.reward.fichas
            world.coach.personalCash += quest.reward.cash
            if quest.reward.reputation > 0 { changeReputation(quest.reward.reputation) }
            world.social.coachFollowers += quest.reward.followers
            addInbox(.general, title: "Missão cumprida: \(quest.title)", body: "Recompensa: \(quest.reward.text).")
            queueQuestUnlock(quest)
        }
    }
}
