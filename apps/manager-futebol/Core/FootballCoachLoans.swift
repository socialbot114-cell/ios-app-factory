import Foundation

// MARK: - Aporte formal do treinador, com devolução (BAN-05)

struct CoachLoan: Codable, Equatable, Identifiable {
    enum Status: String, Codable { case active, repaid, forgiven, settled }

    let id: Int
    let clubID: Int
    let principal: Int
    let startWorldDay: Int
    let installment: Int
    var outstanding: Int
    var status: Status = .active
    /// Dias em que a parcela foi adiada por falta de caixa.
    var postponed = 0

    var firstPaymentWorldDay: Int { startWorldDay + FootballCareer.coachLoanGraceDays }
    var repaid: Int { principal - outstanding }
}

extension FootballCareer {
    static let coachLoanGraceDays = 3
    static let coachLoanInstallments = 12

    var coachLoans: [CoachLoan] { world.projects.coachLoans }
    var activeCoachLoans: [CoachLoan] { world.projects.coachLoans.filter { $0.status == .active && $0.clubID == selectedClubID } }
    var coachLoanOutstanding: Int { activeCoachLoans.reduce(0) { $0 + $1.outstanding } }

    /// Registra o aporte como empréstimo; chamado por `lendToClub` depois de mover o dinheiro.
    mutating func registerCoachLoan(amount: Int) {
        guard let clubID = selectedClubID else { return }
        let installment = max(10_000, Int((Double(amount) / Double(Self.coachLoanInstallments) / 1_000).rounded(.up)) * 1_000)
        world.projects.coachLoans.append(CoachLoan(id: world.projects.nextLoanID, clubID: clubID, principal: amount,
                                                   startWorldDay: worldDay, installment: installment, outstanding: amount))
        world.projects.nextLoanID += 1
    }

    /// Parcela de hoje de cada empréstimo, se a carência acabou e o caixa do clube continua positivo depois de pagar.
    mutating func repayCoachLoans() {
        for index in world.projects.coachLoans.indices {
            let loan = world.projects.coachLoans[index]
            guard loan.status == .active, loan.clubID == selectedClubID, worldDay >= loan.firstPaymentWorldDay else { continue }
            let payment = min(loan.installment, loan.outstanding)
            guard transferBudget - payment >= 0 else {
                world.projects.coachLoans[index].postponed += 1
                continue
            }
            book(.other, -payment, "Devolução do aporte ao treinador")
            world.coach.personalCash += payment
            world.projects.coachLoans[index].outstanding -= payment
            if world.projects.coachLoans[index].outstanding <= 0 {
                world.projects.coachLoans[index].status = .repaid
                addInbox(.finance, title: "Aporte devolvido", body: "O clube terminou de devolver os \(FootballFormat.money(loan.principal)) que você emprestou.")
            }
        }
    }

    /// Transforma o saldo em doação: o clube não deve mais nada e a diretoria reconhece uma vez.
    @discardableResult
    mutating func forgiveCoachLoan(_ id: Int) -> Bool {
        guard let index = world.projects.coachLoans.firstIndex(where: { $0.id == id && $0.status == .active && $0.clubID == selectedClubID })
        else { return false }
        let outstanding = world.projects.coachLoans[index].outstanding
        world.projects.coachLoans[index].status = .forgiven
        world.projects.coachLoans[index].outstanding = 0
        if Double(outstanding) >= Double(world.projects.coachLoans[index].principal) * 0.25 {
            boardConfidence = min(100, boardConfidence + 3)
        }
        addInbox(.board, title: "Aporte perdoado", body: "Você abriu mão de \(FootballFormat.money(outstanding)) que o clube ainda devia. A diretoria agradece.")
        return true
    }

    /// Ao deixar o clube, o saldo devedor é quitado na rescisão: o dinheiro volta ao bolso do treinador.
    mutating func settleCoachLoansOnDeparture() {
        for index in world.projects.coachLoans.indices where world.projects.coachLoans[index].status == .active {
            world.coach.personalCash += world.projects.coachLoans[index].outstanding
            world.projects.coachLoans[index].outstanding = 0
            world.projects.coachLoans[index].status = .settled
        }
    }
}
