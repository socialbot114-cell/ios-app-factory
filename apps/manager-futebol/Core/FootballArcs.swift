import Foundation

// MARK: - Arcos de acontecimentos (ALE-01..05)

enum ArcStage: String, Codable, Equatable {
    case start, update, decision, ended
}

enum ArcStepKind: String, Codable, Equatable {
    case opened, update, info, delegated, decision, omission, outcome
}

/// O que o treinador pode fazer num arco. `ignore` também é o desfecho de quem não responde a tempo.
enum ArcChoice: String, Codable, CaseIterable, Equatable, Identifiable {
    case talk, deny, delegate, ignore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .talk: return "Conversar com o atleta"
        case .deny: return "Desmentir em público"
        case .delegate: return "Delegar ao empresário"
        case .ignore: return "Deixar passar"
        }
    }

    var hint: String {
        switch self {
        case .talk: return "Mostra interesse e reconstrói confiança. Custa um dia de atenção."
        case .deny: return "Derruba o boato se for falso; se for verdade, queima sua credibilidade."
        case .delegate: return "O empresário resolve, com resultado mais fraco e dependente da sua relação com ele."
        case .ignore: return "Sem custo agora; se o boato for verdadeiro, o atleta pede para sair."
        }
    }
}

struct ArcStep: Codable, Equatable, Identifiable {
    var id: Int
    let worldDay: Int
    let kind: ArcStepKind
    let text: String
}

struct StoryArc: Codable, Equatable, Identifiable {
    let id: Int
    let templateID: String
    var title: String
    var playerID: Int?
    var participants: [String]
    var origin: String
    var reliability: FactReliability
    var stage: ArcStage
    let startedWorldDay: Int
    var deadlineWorldDay: Int
    /// Verdade oculta do boato: não aparece na interface; só os desfechos a revelam.
    var truth: Bool
    var infoAsked = false
    var choice: ArcChoice? = nil
    var outcome: String? = nil
    var commitmentID: Int? = nil
    var steps: [ArcStep] = []

    var isOpen: Bool { stage != .ended }
}

extension FootballCareer {
    static let rumorTemplateID = "rumor-star-leaving"
    static let arcLifetimeDays = 4
    static let arcUpdateDay = 2

    var openArcs: [StoryArc] { arcs.filter(\.isOpen) }

    func arc(_ id: Int) -> StoryArc? { arcs.first { $0.id == id } }

    /// Cadeia de acontecimentos de um arco, em ordem (ALE-05).
    func arcChain(_ id: Int) -> [ArcStep] { arc(id)?.steps ?? [] }

    func arcs(involving playerID: Int) -> [StoryArc] { arcs.filter { $0.playerID == playerID } }

    private func hash(_ text: String) -> Int {
        text.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) % 100_003 }
    }

    // MARK: Início

    /// Procura um craque descontente e abre o arco do boato. Um arco por vez, com sorteio determinístico por dia de jogo.
    @discardableResult
    mutating func maybeStartRumorArc() -> StoryArc? {
        guard selectedClubID != nil, !isFired, matchDayIndex >= 4, !arcs.contains(where: { $0.templateID == Self.rumorTemplateID && $0.isOpen }) else { return nil }
        var random = FootballRandom(seed: matchSeed(stream: .world, id: matchDayIndex + 900))
        let stars = clubRoster.filter { isStar($0) }
        let candidates = stars.filter { athlete in
            !arcs.contains { $0.playerID == athlete.id && $0.templateID == Self.rumorTemplateID && worldDay - $0.startedWorldDay < 20 }
                && (athlete.morale < 60 || trust(of: athlete.id) < 0)
        }
        guard !candidates.isEmpty, random.chance(0.35), let athlete = random.pick(candidates) else { return nil }
        // Quanto mais desmotivado e menos confiante, maior a chance de o boato ser verdadeiro.
        let pressure = Double(60 - athlete.morale) / 60 - Double(trust(of: athlete.id)) / 200
        return openRumorArc(playerID: athlete.id, truth: random.chance(min(0.85, max(0.2, 0.35 + pressure))))
    }

    @discardableResult
    mutating func openRumorArc(playerID: Int, truth: Bool) -> StoryArc? {
        guard let athlete = player(playerID), athlete.teamID == selectedClubID else { return nil }
        let id = nextArcID
        nextArcID += 1
        let reporter = Self.journalistNames[hash("arc-\(id)") % Self.journalistNames.count]
        let rival = FootballSeason.teamName((hash("club-\(id)-\(playerID)") % FootballSeason.teams.count))
        let agent = world.contacts.contacts.first { $0.role == .agent }?.name ?? "Empresário"
        let factID = "arc-\(id)-open"
        var arc = StoryArc(id: id, templateID: Self.rumorTemplateID, title: "Boato: \(athlete.name) quer sair", playerID: playerID,
                           participants: ["\(athlete.name) (atleta)", "\(reporter) (jornalista)", "\(agent) (empresário)", "\(rival) (clube citado)"],
                           origin: "\(reporter), citando fontes ligadas ao jogador", reliability: .rumor, stage: .start,
                           startedWorldDay: worldDay, deadlineWorldDay: worldDay + Self.arcLifetimeDays, truth: truth)
        recordFact(WorldFact(id: factID, source: .press, worldDay: worldDay, title: arc.title,
                             detail: "\(arc.origin) afirma que \(athlete.name) negocia com o \(rival). Sem confirmação oficial.",
                             playerIDs: [playerID], reliability: .rumor, isPublic: true))
        deliverFact(factID, inbox: .news, social: true)
        let commitment = openCommitment(kind: .storyArc, playerID: playerID, factID: factID, days: Self.arcLifetimeDays,
                                        title: "Responder ao boato sobre \(athlete.name)", detail: "Prazo do arco; sem decisão, o boato segue seu curso.")
        arc.commitmentID = commitment.id
        arc.steps.append(ArcStep(id: 0, worldDay: worldDay, kind: .opened, text: "\(arc.origin) publica que \(athlete.name) negocia com o \(rival)."))
        arcs.append(arc)
        return arc
    }

    // MARK: Atualização e prazo

    /// Atualiza os arcos abertos: no segundo dia chega uma novidade; no prazo, a omissão tem desfecho registrado.
    mutating func advanceArcs() {
        for index in arcs.indices where arcs[index].isOpen {
            var arc = arcs[index]
            if arc.stage == .start, worldDay - arc.startedWorldDay >= Self.arcUpdateDay {
                arc.stage = .decision
                let name = arc.playerID.flatMap { player($0)?.name } ?? "O atleta"
                if arc.truth {
                    arc.reliability = .confirmed
                    arc.steps.append(ArcStep(id: arc.steps.count, worldDay: worldDay, kind: .update, text: "Um segundo veículo confirma conversas de \(name) com outro clube."))
                } else {
                    arc.steps.append(ArcStep(id: arc.steps.count, worldDay: worldDay, kind: .update, text: "Nenhum clube confirma interesse em \(name); o boato perde força."))
                }
                arcs[index] = arc
            }
        }
        for index in arcs.indices where arcs[index].isOpen && worldDay >= arcs[index].deadlineWorldDay {
            resolveArc(at: index, choice: .ignore, omitted: true)
        }
    }

    // MARK: Pedir informação, delegar e decidir

    /// Pede informação ao empresário: uma vez por arco. A leitura dele acerta mais quando a relação é boa.
    @discardableResult
    mutating func askArcInfo(_ id: Int) -> String? {
        guard let index = arcs.firstIndex(where: { $0.id == id }), arcs[index].isOpen, !arcs[index].infoAsked else { return nil }
        let relation = relationship(.agent)
        let accuracy = 0.55 + min(0.4, Double(relation) / 250)
        var random = FootballRandom(seed: matchSeed(stream: .world, id: 5_000 + id))
        let correct = random.chance(accuracy)
        let reads = correct ? arcs[index].truth : !arcs[index].truth
        let text = reads ? "O empresário acha que há fundo de verdade: o atleta anda ouvindo propostas." : "O empresário acha que é ruído: nada concreto aconteceu."
        arcs[index].infoAsked = true
        arcs[index].steps.append(ArcStep(id: arcs[index].steps.count, worldDay: worldDay, kind: .info, text: text + " (leitura dele, não confirmação)"))
        adjustRelationship(.agent, by: 1)
        return text
    }

    @discardableResult
    mutating func decideArc(_ id: Int, _ choice: ArcChoice) -> Bool {
        guard let index = arcs.firstIndex(where: { $0.id == id }), arcs[index].isOpen else { return false }
        resolveArc(at: index, choice: choice, omitted: false)
        return true
    }

    private mutating func resolveArc(at index: Int, choice: ArcChoice, omitted: Bool) {
        var arc = arcs[index]
        guard arc.isOpen, let athleteID = arc.playerID, let athleteIndex = players.firstIndex(where: { $0.id == athleteID }) else {
            arcs[index].stage = .ended
            if let commitment = arcs[index].commitmentID { resolveCommitment(id: commitment, as: .cancelled) }
            return
        }
        let name = players[athleteIndex].name
        var effects: [String] = []
        let kind: ArcStepKind = omitted ? .omission : (choice == .delegate ? .delegated : .decision)
        var narration: String
        switch choice {
        case .talk:
            players[athleteIndex].morale = min(100, players[athleteIndex].morale + (arc.truth ? 8 : 2))
            recordMemory(playerID: athleteID, kind: .meetingHeld, id: "arc-\(arc.id)-talk")
            narration = arc.truth ? "\(name) admite que ouviu propostas, mas prefere ficar depois da conversa." : "\(name) estranha o boato, mas gosta de ver o treinador por perto."
            effects = ["Moral \(arc.truth ? "+8" : "+2")", "Confiança do atleta sobe"]
        case .deny:
            if arc.truth {
                fanMood = max(0, fanMood - 2)
                changeReputation(-1)
                recordMemory(playerID: athleteID, kind: .requestRefused, id: "arc-\(arc.id)-deny")
                narration = "A negativa pública cai por terra quando o clube interessado é confirmado. A credibilidade do treinador sofre."
                effects = ["Torcida -2", "Reputação -1", "\(name) se sente exposto"]
            } else {
                fanMood = min(100, fanMood + 2)
                narration = "O desmentido derruba o boato. A torcida aprova a firmeza."
                effects = ["Torcida +2"]
            }
        case .delegate:
            let relation = relationship(.agent)
            if relation >= 40 {
                players[athleteIndex].morale = min(100, players[athleteIndex].morale + (arc.truth ? 4 : 1))
                narration = "O empresário conversa com \(name) e com o clube interessado e acalma a situação."
                effects = ["Moral \(arc.truth ? "+4" : "+1")"]
            } else {
                narration = "A relação com o empresário é fraca e a mediação não adianta."
                effects = ["Sem efeito"]
            }
            adjustRelationship(.agent, by: relation >= 40 ? 2 : -1)
        case .ignore:
            if arc.truth {
                players[athleteIndex].morale = max(0, players[athleteIndex].morale - 6)
                recordMemory(playerID: athleteID, kind: .requestIgnored, id: "arc-\(arc.id)-ignored")
                if !hasOpenMessage(.playerWantsOut, playerID: athleteID) {
                    addInbox(.playerWantsOut, title: "\(name) quer sair", body: "Sem resposta ao boato, \(name) pediu para ser negociado.", playerID: athleteID)
                }
                narration = omitted ? "Sem resposta no prazo, \(name) pede para sair." : "O treinador deixa passar e \(name) pede para sair."
                effects = ["Moral -6", "\(name) pede para sair"]
            } else {
                fanMood = max(0, fanMood - 1)
                narration = "O boato se esvazia sozinho, mas a torcida ficou um dia na dúvida."
                effects = ["Torcida -1"]
            }
        }
        arc.choice = choice
        arc.stage = .ended
        arc.outcome = narration
        arc.steps.append(ArcStep(id: arc.steps.count, worldDay: worldDay, kind: kind,
                                 text: (omitted ? "Sem resposta no prazo: " : "Decisão: \(choice.title). ") + narration))
        arc.steps.append(ArcStep(id: arc.steps.count, worldDay: worldDay, kind: .outcome, text: "Efeitos: " + effects.joined(separator: ", ") + "."))
        arcs[index] = arc
        if let commitment = arc.commitmentID { resolveCommitment(id: commitment, as: omitted ? .expired : .fulfilled) }
        let factID = "arc-\(arc.id)-closed"
        recordFact(WorldFact(id: factID, source: .press, worldDay: worldDay, title: "Desfecho: \(arc.title)", detail: narration, playerIDs: [athleteID],
                             reliability: .confirmed, isPublic: false, effects: effects))
        deliverFact(factID, inbox: .general)
    }
}
