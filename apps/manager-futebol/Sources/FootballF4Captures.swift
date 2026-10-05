import SwiftUI

/// Rotas de captura das telas da F4: cada uma abre o painel no topo com um estado de demonstração útil.
enum FootballF4Captures {
    static let names: Set<String> = ["cash-projection", "board-meeting", "collection-project", "personal-plan", "commercial-delegation",
                                     "transfer-talks", "recruitment-briefs", "coach-loans", "project-ledger", "contact-requests", "contact-dossier"]

    /// Monta o estado de demonstração sobre a carreira de prévia.
    static func prepare(_ name: String, career: inout FootballCareer) {
        guard let clubID = career.selectedClubID else { return }
        switch name {
        case "cash-projection":
            career.pendingPayments.append(PendingPayment(id: 9_001, amount: 1_200_000, dueMatchDay: career.matchDayIndex + 3,
                                                         season: career.season, note: "Parcela da contratação de verão"))
            career.transferBudget = 600_000
            _ = career.launchCollection(CollectionBrief(audience: .traditional, size: .capsule))
        case "board-meeting":
            career.world.projects.meetings = [
                BoardMeeting(id: 1, clubID: clubID, kind: .targetReview, season: career.season - 1, requestedWorldDay: 0, answerWorldDay: 2,
                             status: .closed, answer: "Meta revista de 4º para 6º lugar até o fim da temporada.", resolution: "Confiança -6 pela revisão."),
                BoardMeeting(id: 2, clubID: clubID, kind: .budgetBoost, season: career.season, requestedWorldDay: career.worldDay - 4,
                             answerWorldDay: career.worldDay - 2, status: .conditionRunning, amount: career.boardBoostAmount,
                             condition: BoardCondition(games: 6, winsNeeded: 3, startMatchDay: career.matchDayIndex - 2,
                                                       gamesCounted: 2, winsCounted: 1),
                             answer: "Verba de \(FootballFormat.money(career.boardBoostAmount)) aprovada. Condição: vencer 3 dos próximos 6 jogos.")
            ]
            career.world.projects.nextMeetingID = 3
        case "collection-project":
            career.transferBudget = max(career.transferBudget, 5_000_000)
            let past = CollectionBrief(audience: .youth, size: .capsule)
            var finished = CollectionProject(id: 1, clubID: clubID, brief: past, cost: career.collectionCost(past),
                                             startWorldDay: career.worldDay - 14, endWorldDay: career.worldDay - 8,
                                             forecast: career.collectionForecast(past))
            finished.dailySales = Array(repeating: career.collectionExtra(past), count: past.size.matchDays).enumerated().map { $1 + $0 * 400 }
            finished.verdict = .success
            career.world.commercial.collections = [finished]
            career.world.commercial.nextID = 2
            let brief = CollectionBrief(audience: .traditional, size: .season)
            if career.launchCollection(brief), let index = career.world.commercial.collections.indices.last {
                let extra = career.collectionExtra(brief)
                career.world.commercial.collections[index].dailySales = [extra, extra * 11 / 10, extra * 9 / 10]
            }
        case "personal-plan":
            career.world.coach.energy = 40
            let days = career.personalPlanDays
            if let first = days.first { _ = career.planActivity(.podcast, on: first.worldDay) }
            if days.count > 2 { _ = career.planActivity(.writeBook, on: days[2].worldDay) }
        case "commercial-delegation":
            career.transferBudget = max(career.transferBudget, 5_000_000)
            career.fanMood = max(career.fanMood, 80)
            _ = career.delegateCommercial(risk: .cautious, limit: .medium)
            career.runCommercialDelegation()
        case "transfer-talks", "recruitment-briefs":
            prepareRecruitment(name, career: &career)
        case "coach-loans":
            career.world.coach.personalCash = max(career.world.coach.personalCash, 1_000_000)
            career.transferBudget = max(career.transferBudget, 2_000_000)
            _ = career.lendToClub(amount: 120_000)
            _ = career.lendToClub(amount: 300_000)
            if career.world.projects.coachLoans.count >= 2 {
                let first = career.world.projects.coachLoans.count - 2
                career.world.projects.coachLoans[first].outstanding = 0
                career.world.projects.coachLoans[first].status = .repaid
                career.world.projects.coachLoans[first + 1].outstanding = 240_000
                career.world.projects.coachLoans[first + 1].postponed = 1
            }
        case "project-ledger":
            career.transferBudget = max(career.transferBudget, 30_000_000)
            var random = FootballRandom(seed: 4)
            career.refreshNamingOffers(using: &random)
            if let offer = career.world.business.namingOffers.first { _ = career.acceptNamingOffer(offer.id) }
            _ = career.upgradeShop()
            _ = career.toggle(.fanClubs)
            _ = career.toggle(.footballAcademy)
            for _ in 0..<4 { _ = career.simulateNextMatchDay() }
        case "contact-requests", "contact-dossier":
            let ids = Dictionary(uniqueKeysWithValues: career.world.contacts.contacts.map { ($0.role, $0.id) })
            career.world.coach.personalCash = max(career.world.coach.personalCash, 500_000)
            career.world.coach.energy = 80
            _ = career.talk(.familyPromise)
            let day = career.worldDay
            career.world.projects.contactRelations.requests.append(contentsOf: [
                ContactRequest(id: 900, contactID: ids[.friend] ?? 6, kind: .friendLoan, createdWorldDay: day, deadlineWorldDay: day + 3, amount: 50_000),
                ContactRequest(id: 901, contactID: ids[.president] ?? 3, kind: .presidentEvent, createdWorldDay: day, deadlineWorldDay: day + 1)
            ])
        default:
            break
        }
    }

    /// Janela aberta, um briefing com comparação e, para as negociações, uma contraproposta e um acordo pronto.
    private static func prepareRecruitment(_ name: String, career: inout FootballCareer) {
        var guardDays = 0
        while !career.isTransferWindowOpen, guardDays < 20, career.simulateNextMatchDay() { guardDays += 1 }
        career.transferBudget = max(career.transferBudget, 60_000_000)
        career.wageCap = max(career.wageCap, career.wageBill * 2)
        guard let brief = career.createBrief(position: .midfielder, maxAge: 28, minOverall: 60, maxFee: career.transferBudget,
                                             maxWage: max(0, career.wageHeadroom), role: .starter) else { return }
        let candidates = career.candidates(for: brief)
        for row in candidates.prefix(3) {
            career.observe(row.playerID, gain: 40)
            career.toggleShortlist(briefID: brief.id, playerID: row.playerID)
        }
        career.stampScoutReports()
        let negotiable = candidates.filter { career.transferTalkBlocker(playerID: $0.playerID) == nil }
        guard name == "transfer-talks", negotiable.count >= 2 else { return }
        if let first = career.player(negotiable[0].playerID), let talk = career.startTransferTalk(playerID: first.id) {
            _ = career.proposeFee(talkID: talk.id, fee: Int(Double(career.askingPrice(for: first)) * 0.9))
        }
        if let second = career.player(negotiable[1].playerID), let talk = career.startTransferTalk(playerID: second.id) {
            let withInstallment = Int((Double(career.askingPrice(for: second)) * 1.03 / 10_000).rounded(.up)) * 10_000
            _ = career.proposeFee(talkID: talk.id, fee: withInstallment, installments: 2)
            if let open = career.openTalk(forPlayer: second.id), let wage = career.wageNeeded(talk: open, years: 3, role: .starter) {
                _ = career.proposeTerms(talkID: talk.id, wage: wage, years: 3, role: .starter)
            }
        }
    }
}

/// Tela de captura: o painel da F4 no topo, sem precisar rolar.
struct FootballF4CaptureView: View {
    let name: String
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        if name == "contact-requests" || name == "contact-dossier" {
            FootballContactsView(career: $career, onAlert: onAlert,
                                 focusedContactID: name == "contact-dossier" ? career.contact(.family)?.id : nil)
        } else {
            panels
        }
    }

    private var panels: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch name {
            case "cash-projection":
                FootballCashProjectionPanel(career: career)
            case "board-meeting":
                FootballBoardMeetingPanel(career: $career, onAlert: onAlert)
            case "collection-project":
                FootballCollectionProjectPanel(career: $career, onAlert: onAlert)
            case "commercial-delegation":
                FootballCommercialDelegationPanel(career: $career)
            case "transfer-talks", "recruitment-briefs":
                FootballRecruitmentHub(career: $career, onAlert: onAlert) { _ in }
            case "coach-loans":
                FootballCoachLoanPanel(career: $career)
            case "project-ledger":
                FootballProjectLedgerPanel(career: career)
            default:
                FootballPersonalPlanPanel(career: $career, onAlert: onAlert, initialSelection: awayLecture)
            }
        }
        .factoryPage()
        .navigationTitle(title)
    }

    /// Palestra num dia de jogo fora: mostra o conflito de viagem no editor.
    private var awayLecture: (day: Int, activity: CoachActivity)? {
        guard let away = career.personalPlanDays.first(where: \.isAway) else { return nil }
        return (away.worldDay, .lecture)
    }

    private var title: String {
        switch name {
        case "cash-projection": return "Banco"
        case "board-meeting": return "Clube"
        case "collection-project", "commercial-delegation", "project-ledger": return "Negócios do clube"
        case "transfer-talks", "recruitment-briefs": return "Mercado"
        case "coach-loans": return "Banco"
        default: return "Vida"
        }
    }
}
