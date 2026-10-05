import Foundation

// MARK: - Vida: continuidade, contexto, bens, vida sem clube e histórico (VID-02…06)

/// Contrato de comentarista: aparições agendadas que entram na agenda pessoal (VID-02).
struct MediaContract: Codable, Equatable {
    enum Status: String, Codable { case active, completed, cancelled }

    let startWorldDay: Int
    var appearanceDays: [Int]
    let bonusPerAppearance: Int
    var done: [Int] = []
    var missed: [Int] = []
    var status: Status = .active

    var remaining: [Int] { appearanceDays.filter { !done.contains($0) && !missed.contains($0) } }
}

/// Um bem com o custo e a explicação de quando a vantagem vale.
struct AssetNote: Equatable, Identifiable {
    let asset: OwnedAsset
    let note: String

    var id: Int { asset.id }
}

struct LifeLogEntry: Codable, Equatable, Identifiable {
    let id: Int
    let worldDay: Int
    let title: String
    let detail: String
}

struct WellbeingPoint: Codable, Equatable, Identifiable {
    let worldDay: Int
    let energy: Int
    let stress: Int

    var id: Int { worldDay }
}

struct LifeState: Codable, Equatable {
    var mediaContract: MediaContract? = nil
    var mediaContractsDone = 0
    var bookDeadlineWorldDay: Int? = nil
    var bookDeadlineExtended = false
    var lastBooksPublished = 0
    var lastStudyWorldDay: Int? = nil
    var courseStallWarned = false
    var log: [LifeLogEntry] = []
    var wellbeing: [WellbeingPoint] = []
    var nextID = 1

    init() {}

    private enum CodingKeys: String, CodingKey {
        case mediaContract, mediaContractsDone, bookDeadlineWorldDay, bookDeadlineExtended, lastBooksPublished
        case lastStudyWorldDay, courseStallWarned, log, wellbeing, nextID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mediaContract = try container.decodeIfPresent(MediaContract.self, forKey: .mediaContract)
        mediaContractsDone = try container.decodeIfPresent(Int.self, forKey: .mediaContractsDone) ?? 0
        bookDeadlineWorldDay = try container.decodeIfPresent(Int.self, forKey: .bookDeadlineWorldDay)
        bookDeadlineExtended = try container.decodeIfPresent(Bool.self, forKey: .bookDeadlineExtended) ?? false
        lastBooksPublished = try container.decodeIfPresent(Int.self, forKey: .lastBooksPublished) ?? 0
        lastStudyWorldDay = try container.decodeIfPresent(Int.self, forKey: .lastStudyWorldDay)
        courseStallWarned = try container.decodeIfPresent(Bool.self, forKey: .courseStallWarned) ?? false
        log = try container.decodeIfPresent([LifeLogEntry].self, forKey: .log) ?? []
        wellbeing = try container.decodeIfPresent([WellbeingPoint].self, forKey: .wellbeing) ?? []
        nextID = try container.decodeIfPresent(Int.self, forKey: .nextID) ?? 1
    }
}

extension FootballCareer {
    static let lifeLogLimit = 40
    static let wellbeingLimit = 30
    static let bookDeadlineDays = 12
    static let courseStallDays = 10

    var life: LifeState { world.projects.life }

    // MARK: VID-06 — histórico de decisões e bem-estar

    mutating func logLife(_ title: String, _ detail: String) {
        world.projects.life.log.append(LifeLogEntry(id: life.nextID, worldDay: worldDay, title: title, detail: detail))
        world.projects.life.nextID += 1
        if life.log.count > Self.lifeLogLimit { world.projects.life.log.removeFirst(life.log.count - Self.lifeLogLimit) }
    }

    /// Ponto de energia e estresse do dia; chamado depois do bem-estar de cada dia de jogo.
    mutating func recordWellbeing() {
        let today = worldDay
        let point = WellbeingPoint(worldDay: today, energy: world.coach.energy, stress: world.coach.stress)
        world.projects.life.wellbeing.removeAll { $0.worldDay == today }
        world.projects.life.wellbeing.append(point)
        if life.wellbeing.count > Self.wellbeingLimit { world.projects.life.wellbeing.removeFirst(life.wellbeing.count - Self.wellbeingLimit) }
    }

    // MARK: VID-03 — descanso no contexto da semana

    /// Bônus do descanso conforme a semana: apoio da família, derrota recente e estresse alto.
    func restContext(onWorldDay day: Int) -> (energy: Int, stress: Int, reasons: [String]) {
        var energy = 0
        var stress = 0
        var reasons: [String] = []
        if relationship(.family) >= 70 {
            energy += 5
            reasons.append("apoio da família (+5 de energia)")
        }
        if let clubID = selectedClubID,
           let last = fixtures.filter({ $0.involves(clubID) && $0.isPlayed }).max(by: { $0.matchDay < $1.matchDay }),
           last.result(for: clubID) == .loss {
            stress += 8
            reasons.append("descanso depois da derrota (−8 de estresse)")
        }
        if world.coach.stress >= 80 {
            stress += 5
            reasons.append("estresse no limite (−5 extra)")
        }
        let leisure = assetRestBonus(onWorldDay: day)
        if leisure > 0 { energy += leisure; reasons.append("bens de lazer (+\(leisure) de energia)") }
        return (energy, stress, reasons)
    }

    // MARK: VID-04 — bens: custo recorrente e vantagem contextual

    /// Casa de praia, sítio e lancha só rendem descanso extra em dias sem viagem com o time.
    func assetRestBonus(onWorldDay day: Int) -> Int {
        let travelling = isTravelDay(day)
        return world.coach.assets.reduce(0) { total, asset in
            let leisure = [AssetKind.beachHouse, .farm, .yacht].contains(asset.kind)
            return total + (leisure && travelling ? 0 : asset.kind.energyBonus)
        }
    }

    private func isTravelDay(_ day: Int) -> Bool {
        guard let clubID = selectedClubID, !isFired else { return false }
        let matchDay = day - (season - 1) * FootballSeason.matchDaysPerSeason
        return fixtures.contains { $0.matchDay == matchDay && $0.away == clubID }
    }

    var assetUpkeepPerSeason: Int { world.coach.assets.reduce(0) { $0 + $1.kind.upkeep } }

    /// Explicação de cada bem: custo por temporada e quando a vantagem vale.
    func assetNotes() -> [AssetNote] {
        world.coach.assets.map { asset in
            let leisure = [AssetKind.beachHouse, .farm, .yacht].contains(asset.kind)
            var note = "Custa \(FootballFormat.money(asset.kind.upkeep))/temporada."
            if asset.kind.energyBonus > 0 {
                note += leisure ? " +\(asset.kind.energyBonus) de energia ao descansar, só em dias sem viagem." : " +\(asset.kind.energyBonus) de energia em todo descanso."
            } else {
                note += " Só prestígio: \(asset.kind.prestige)."
            }
            return AssetNote(asset: asset, note: note)
        }
    }

    // MARK: VID-02 — mídia, livro e curso

    /// Proposta de comentarista: 3 aparições, uma a cada 4 dias, em dias sem viagem. Precisa de reputação 40.
    var mediaContractOffer: MediaContract? {
        guard life.mediaContract?.status != .active, reputation >= 40 else { return nil }
        let seasonEnd = season * FootballSeason.matchDaysPerSeason
        var days: [Int] = []
        var day = worldDay + 2
        while days.count < 3, day < seasonEnd {
            if !isTravelDay(day) { days.append(day); day += 4 } else { day += 1 }
        }
        guard days.count == 3 else { return nil }
        let bonus = Int(Double(4_000 + reputation * 400) * 0.5 / 1_000) * 1_000
        return MediaContract(startWorldDay: worldDay, appearanceDays: days, bonusPerAppearance: bonus)
    }

    @discardableResult
    mutating func acceptMediaContract() -> Bool {
        guard let offer = mediaContractOffer else { return false }
        world.projects.life.mediaContract = offer
        logLife("Contrato de comentarista", "3 aparições agendadas, bônus de \(FootballFormat.money(offer.bonusPerAppearance)) por programa.")
        schedulePendingAppearances()
        return true
    }

    /// Se o calendário do clube mudou (sorteio da copa) e um programa caiu em dia de viagem, a emissora remarca.
    mutating func rescheduleTravelAppearances() {
        guard var contract = life.mediaContract, contract.status == .active else { return }
        let seasonEnd = season * FootballSeason.matchDaysPerSeason
        for appearance in contract.remaining where appearance >= worldDay && isTravelDay(appearance) {
            var day = appearance + 1
            while day < seasonEnd && (isTravelDay(day) || contract.appearanceDays.contains(day)) { day += 1 }
            guard day < seasonEnd, let index = contract.appearanceDays.firstIndex(of: appearance) else { continue }
            contract.appearanceDays[index] = day
            world.projects.personalPlan.removeAll { $0.worldDay == appearance && $0.activity == .tvPunditry && $0.status == .planned }
            let seasonStart = (season - 1) * FootballSeason.matchDaysPerSeason
            addInbox(.general, title: "Programa remarcado",
                     body: "O time vai viajar no dia \(appearance - seasonStart + 1). A emissora passou o seu programa para o dia \(day - seasonStart + 1).")
        }
        contract.appearanceDays.sort()
        world.projects.life.mediaContract = contract
    }

    /// Põe na agenda as aparições que entraram no horizonte de planejamento.
    mutating func schedulePendingAppearances() {
        rescheduleTravelAppearances()
        guard let contract = life.mediaContract, contract.status == .active else { return }
        let horizon = Set(personalPlanDays.map(\.worldDay))
        for day in contract.remaining where horizon.contains(day)
            && !world.projects.personalPlan.contains(where: { $0.worldDay == day && $0.status == .planned && $0.activity == .tvPunditry }) {
            _ = planActivity(.tvPunditry, on: day)
        }
    }

    /// Diário da vida: aparições cumpridas ou perdidas, prazo do livro e curso parado. Uma vez por dia de jogo.
    mutating func progressLife() {
        let day = worldDay - 1
        if var contract = life.mediaContract, contract.status == .active {
            for appearance in contract.remaining where appearance <= day {
                let showed = world.projects.personalPlan.contains { $0.worldDay == appearance && $0.activity == .tvPunditry && $0.status == .done }
                if showed {
                    contract.done.append(appearance)
                    bookPersonal(contract.bonusPerAppearance, "Bônus do programa de TV", link: FinanceLink(kind: .media, id: "media", title: "Comentarista"))
                } else {
                    contract.missed.append(appearance)
                    changeReputation(-1)
                    addInbox(.general, title: "Faltou ao programa", body: "A emissora reclamou da sua ausência. Reputação -1.")
                }
            }
            if contract.missed.count >= 2 {
                contract.status = .cancelled
                logLife("Contrato de comentarista cancelado", "Duas faltas: a emissora encerrou o contrato.")
            } else if contract.remaining.isEmpty {
                contract.status = .completed
                world.projects.life.mediaContractsDone += 1
                changeReputation(1)
                logLife("Contrato de comentarista cumprido", "\(contract.done.count) programas no ar. Reputação +1.")
            }
            world.projects.life.mediaContract = contract
            schedulePendingAppearances()
        }
        // Livro: prazo da editora a partir do segundo capítulo.
        if world.coach.booksPublished > life.lastBooksPublished {
            if let deadline = life.bookDeadlineWorldDay, worldDay <= deadline {
                bookPersonal(15_000, "Bônus da editora")
                logLife("Livro entregue no prazo", "A editora pagou bônus de \(FootballFormat.money(15_000)).")
            } else {
                logLife("Livro publicado", "Saiu depois do prazo combinado, sem bônus.")
            }
            world.projects.life.lastBooksPublished = world.coach.booksPublished
            world.projects.life.bookDeadlineWorldDay = nil
            world.projects.life.bookDeadlineExtended = false
        } else if world.coach.bookSessions >= 2, life.bookDeadlineWorldDay == nil {
            world.projects.life.bookDeadlineWorldDay = worldDay + Self.bookDeadlineDays
            addInbox(.general, title: "Editora marca prazo", body: "Entregue os capítulos que faltam em \(Self.bookDeadlineDays) dias de jogo para ganhar bônus.")
        } else if let deadline = life.bookDeadlineWorldDay, worldDay > deadline, !life.bookDeadlineExtended {
            world.projects.life.bookDeadlineWorldDay = worldDay + 8
            world.projects.life.bookDeadlineExtended = true
            addInbox(.general, title: "Livro atrasado", body: "A editora deu mais 8 dias, mas o bônus de entrega no prazo já era.")
        }
        // Curso: avisa uma vez quando fica parado.
        if world.coach.course != nil, life.lastStudyWorldDay == nil { world.projects.life.lastStudyWorldDay = worldDay }
        if world.coach.course != nil, let last = life.lastStudyWorldDay, worldDay - last >= Self.courseStallDays, !life.courseStallWarned {
            world.projects.life.courseStallWarned = true
            addInbox(.general, title: "Curso parado", body: "Faz \(worldDay - last) dias que você não estuda. O curso continua esperando.")
        }
    }

    /// Chamado pela execução de atividades para manter a continuidade e o histórico.
    mutating func noteActivity(_ activity: CoachActivity, text: String, onWorldDay day: Int) {
        if activity == .study {
            world.projects.life.lastStudyWorldDay = day
            world.projects.life.courseStallWarned = false
        }
        logLife(activity.title, text)
        noteImageActivity(activity)
    }

    /// Sessões que faltam no curso e no livro, para mostrar o caminho.
    var personalProjectsSummary: [String] {
        var lines: [String] = []
        if let course = world.coach.course {
            let left = course.sessionsNeeded - course.sessionsDone
            lines.append("Curso para \(CoachProfile.licenseNames[min(max(course.targetLicense, 1), 4) - 1]): faltam \(left) aula(s).")
        }
        if world.coach.bookSessions > 0 {
            var line = "Livro: capítulo \(world.coach.bookSessions) de 6"
            if let deadline = life.bookDeadlineWorldDay { line += ", prazo da editora em \(max(0, deadline - worldDay)) dia(s)" }
            lines.append(line + ".")
        }
        if let contract = life.mediaContract, contract.status == .active {
            lines.append("Comentarista: \(contract.done.count) de \(contract.appearanceDays.count) programas, \(contract.missed.count) falta(s).")
        }
        return lines
    }
}
