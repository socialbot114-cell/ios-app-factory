import SwiftUI

/// Rotas de captura das telas da F4: cada uma abre o painel no topo com um estado de demonstração útil.
enum FootballF4Captures {
    static let names: Set<String> = ["cash-projection", "board-meeting", "collection-project", "personal-plan", "commercial-delegation"]

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
        default:
            break
        }
    }
}

/// Tela de captura: o painel da F4 no topo, sem precisar rolar.
struct FootballF4CaptureView: View {
    let name: String
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
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
        case "collection-project", "commercial-delegation": return "Negócios do clube"
        default: return "Vida"
        }
    }
}
