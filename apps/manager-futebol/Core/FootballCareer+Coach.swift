import Foundation

struct ActivityResult: Equatable {
    let text: String
    let cashChange: Int
    let followersChange: Int
}

extension FootballCareer {
    /// Dia corrido da carreira: cresce a cada dia de jogo, atravessando as temporadas.
    var worldDay: Int { (season - 1) * FootballSeason.matchDaysPerSeason + matchDayIndex }

    // MARK: - Salário e patrimônio

    var coachSalaryPerSeason: Int {
        guard let selectedClubID else { return 0 }
        let base = Double(max(5, clubPrestige(selectedClubID) - 55)) * 20_000
        let factor = world.coach.contract?.salaryFactor ?? 1.0
        return Int((base + Double(reputation) * 1_000) * factor / 5_000) * 5_000
    }

    /// Salário, manutenção de bens, rendimento de investimentos e royalties de cada dia de jogo.
    mutating func tickCoachFinances(using random: inout FootballRandom) {
        guard selectedClubID != nil, !isFired else { return }
        let days = FootballSeason.matchDaysPerSeason
        world.coach.personalCash += coachSalaryPerSeason / days
        let upkeep = world.coach.assets.reduce(0) { $0 + $1.kind.upkeep } / days
        world.coach.personalCash -= upkeep
        world.coach.personalCash += world.coach.booksPublished * 4_000 / days
        for index in world.coach.investments.indices {
            let kind = world.coach.investments[index].kind
            let noise = (random.unit() * 2 - 1) * kind.volatility * 1.7
            let value = Double(world.coach.investments[index].value) * (1 + kind.drift + noise)
            world.coach.investments[index].value = max(0, Int(value))
            if kind == .realEstate { world.coach.personalCash += Int(Double(world.coach.investments[index].value) * 0.0015) }
        }
    }

    /// Energia e estresse depois de cada dia de jogo.
    mutating func tickCoachWellbeing(result: FootballResult?, derby: Bool) {
        var energy = world.coach.energy + 3
        var stress = world.coach.stress - 2
        switch result {
        case .win?: stress -= 2
        case .loss?: stress += derby ? 8 : 4
        case .draw?: stress += 1
        default: break
        }
        if boardConfidence < 30 { stress += 2 }
        if isInDebt { stress += 2 }
        if world.coach.stress >= 85 {
            boardConfidence = max(0, boardConfidence - 1)
            energy -= 4
        }
        world.coach.energy = min(100, max(0, energy))
        world.coach.stress = min(100, max(0, stress))
    }

    func canBuyAsset(_ kind: AssetKind) -> String? {
        if world.coach.personalCash < kind.price { return "Faltam \(FootballFormat.money(kind.price - world.coach.personalCash))." }
        if world.coach.assets.contains(where: { $0.kind == kind }) && kind != .watch { return "Você já possui este bem." }
        return nil
    }

    @discardableResult
    mutating func buyAsset(_ kind: AssetKind) -> Bool {
        guard canBuyAsset(kind) == nil else { return false }
        world.coach.personalCash -= kind.price
        world.coach.assets.append(OwnedAsset(id: world.coach.nextItemID, kind: kind, boughtSeason: season))
        world.coach.nextItemID += 1
        world.coach.stress = max(0, world.coach.stress - 5)
        bump("assets")
        return true
    }

    @discardableResult
    mutating func sellAsset(id: Int) -> Bool {
        guard let index = world.coach.assets.firstIndex(where: { $0.id == id }) else { return false }
        let asset = world.coach.assets.remove(at: index)
        world.coach.personalCash += Int(Double(asset.kind.price) * 0.7)
        return true
    }

    @discardableResult
    mutating func invest(_ kind: InvestmentKind, amount: Int) -> Bool {
        guard amount >= 10_000, world.coach.personalCash >= amount else { return false }
        world.coach.personalCash -= amount
        world.coach.investments.append(Investment(id: world.coach.nextItemID, kind: kind, principal: amount, value: amount, startedWorldDay: worldDay))
        world.coach.nextItemID += 1
        bump("investments")
        return true
    }

    @discardableResult
    mutating func withdrawInvestment(id: Int) -> Bool {
        guard let index = world.coach.investments.firstIndex(where: { $0.id == id }) else { return false }
        world.coach.personalCash += world.coach.investments[index].value
        world.coach.investments.remove(at: index)
        return true
    }

    var investmentsValue: Int { world.coach.investments.reduce(0) { $0 + $1.value } }

    var coachNetWorth: Int {
        world.coach.personalCash + investmentsValue + world.coach.assets.reduce(0) { $0 + Int(Double($1.kind.price) * 0.7) }
    }

    // MARK: - Licenças

    func canStartCourse() -> String? {
        let next = world.coach.licenseLevel + 1
        guard next <= 4 else { return "Você já tem a licença máxima." }
        guard world.coach.course == nil else { return "Já há um curso em andamento." }
        guard reputation >= CoachProfile.courseMinimumReputation[next - 1] else {
            return "Reputação mínima: \(CoachProfile.courseMinimumReputation[next - 1])."
        }
        let cost = CoachProfile.courseCosts[next - 1]
        guard world.coach.personalCash >= cost else { return "Faltam \(FootballFormat.money(cost - world.coach.personalCash))." }
        return nil
    }

    @discardableResult
    mutating func startCourse() -> Bool {
        guard canStartCourse() == nil else { return false }
        let next = world.coach.licenseLevel + 1
        world.coach.personalCash -= CoachProfile.courseCosts[next - 1]
        world.coach.course = CoachCourse(targetLicense: next, sessionsDone: 0, sessionsNeeded: CoachProfile.courseSessions[next - 1])
        return true
    }

    // MARK: - Atividades

    func canDo(_ activity: CoachActivity) -> String? {
        guard selectedClubID != nil, !isFired else { return "Sem clube." }
        guard world.coach.lastActivityWorldDay != worldDay else { return "Uma atividade por dia de jogo." }
        if activity != .rest && world.coach.energy < max(5, activity.energyCost) { return "Energia insuficiente: descanse primeiro." }
        if activity == .study && world.coach.course == nil { return "Inicie um curso de licença antes." }
        return nil
    }

    @discardableResult
    mutating func doActivity(_ activity: CoachActivity) -> ActivityResult? {
        guard canDo(activity) == nil else { return nil }
        var random = FootballRandom(seed: matchSeed(stream: .world, id: worldDay * 10 + (CoachActivity.allCases.firstIndex(of: activity) ?? 0)))
        world.coach.lastActivityWorldDay = worldDay
        var text = ""
        var cash = 0
        var followers = 0
        let rep = reputation
        switch activity {
        case .rest:
            let bonus = world.coach.assets.reduce(0) { $0 + $1.kind.energyBonus }
            world.coach.energy = min(100, world.coach.energy + 30 + bonus)
            world.coach.stress = max(0, world.coach.stress - 25)
            text = "Um dia de descanso devolveu energia e aliviou o estresse."
        case .study:
            world.coach.energy -= activity.energyCost
            if var course = world.coach.course {
                course.sessionsDone += 1
                if course.sessionsDone >= course.sessionsNeeded {
                    world.coach.licenseLevel = course.targetLicense
                    world.coach.course = nil
                    changeReputation(3)
                    text = "Curso concluído! Você agora tem a \(world.coach.licenseName)."
                    addInbox(.general, title: "Nova licença: \(world.coach.licenseName)", body: "Clubes maiores passam a enxergar você como candidato.")
                } else {
                    world.coach.course = course
                    text = "Aula \(course.sessionsDone) de \(course.sessionsNeeded) concluída."
                }
            }
        case .tvPunditry:
            world.coach.energy -= activity.energyCost
            cash = 4_000 + rep * 400 + world.social.coachFollowers / 50
            followers = 200 + rep * 20
            changeReputation(1)
            if fanMood < 35 { world.social.controversy = min(100, world.social.controversy + 5) }
            text = "Participação no programa de TV: cachê de \(FootballFormat.money(cash))."
        case .lecture:
            world.coach.energy -= activity.energyCost
            cash = 10_000 + rep * 500
            if random.chance(0.4) { changeReputation(1) }
            text = "Palestra sobre liderança: cachê de \(FootballFormat.money(cash))."
        case .writeBook:
            world.coach.energy -= activity.energyCost
            world.coach.bookSessions += 1
            if world.coach.bookSessions >= 6 {
                world.coach.bookSessions = 0
                world.coach.booksPublished += 1
                cash = 25_000
                followers = 3_000
                changeReputation(3)
                text = "Livro publicado! Adiantamento de \(FootballFormat.money(cash)) e royalties a cada temporada."
            } else {
                text = "Capítulo \(world.coach.bookSessions) de 6 escrito."
            }
        case .schoolVisit:
            world.coach.energy -= activity.energyCost
            fanMood = min(100, fanMood + 2)
            changeReputation(1)
            followers = 400
            text = "A visita à escola rendeu fotos e carinho da comunidade."
        case .podcast:
            world.coach.energy -= activity.energyCost
            cash = 3_000
            followers = 800 + rep * 40
            if random.chance(0.3) { world.social.controversy = min(100, world.social.controversy + 4) }
            text = "O podcast bombou: \(followers) novos seguidores."
        case .sponsorShoot:
            world.coach.energy -= activity.energyCost
            cash = 8_000 + world.social.coachFollowers / 30
            followers = -Int(Double(world.social.coachFollowers) * 0.005)
            fanMood = max(0, fanMood - 1)
            text = "Comercial gravado: \(FootballFormat.money(cash)) no bolso."
        }
        world.coach.energy = min(100, max(0, world.coach.energy))
        world.coach.personalCash += cash
        world.social.coachFollowers = max(0, world.social.coachFollowers + followers)
        bump("activities")
        return ActivityResult(text: text, cashChange: cash, followersChange: followers)
    }
}
