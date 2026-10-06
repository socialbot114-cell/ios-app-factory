import SwiftUI

/// Aportes do treinador como empréstimo: saldo, parcelas, adiamentos e perdão (BAN-05).
struct FootballCoachLoanPanel: View {
    @Binding var career: FootballCareer

    var body: some View {
        let loans = career.coachLoans.filter { $0.clubID == career.selectedClubID }.suffix(4).reversed()
        if !loans.isEmpty {
            FactoryPanel(title: "Aportes a devolver", systemImage: "arrow.uturn.backward.circle.fill") {
                Text("Cada aporte volta ao seu bolso em \(FootballCareer.coachLoanInstallments) parcelas, depois de \(FootballCareer.coachLoanGraceDays) dias de carência, e só quando o caixa do clube aguenta.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(loans)) { loan in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Aporte de \(FootballFormat.money(loan.principal))").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(statusText(loan)).font(.caption2.weight(.bold)).foregroundStyle(loan.status == .active ? Color.indigo : Color.secondary)
                        }
                        ProgressView(value: Double(loan.repaid), total: Double(max(1, loan.principal)))
                        Text("Devolvido \(FootballFormat.money(loan.repaid)) · falta \(FootballFormat.money(loan.outstanding)) · parcela \(FootballFormat.money(loan.installment))"
                             + (loan.postponed > 0 ? " · adiada \(loan.postponed)× por falta de caixa" : ""))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        if loan.status == .active {
                            Button("Perdoar o saldo") { career.forgiveCoachLoan(loan.id) }
                                .buttonStyle(.bordered).font(.caption.weight(.semibold))
                                .accessibilityIdentifier("forgive-loan-\(loan.id)")
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
            }
            .accessibilityIdentifier("coach-loans")
        }
    }

    private func statusText(_ loan: CoachLoan) -> String {
        switch loan.status {
        case .active: return career.worldDay < loan.firstPaymentWorldDay ? "Em carência" : "Devolvendo"
        case .repaid: return "Devolvido"
        case .forgiven: return "Perdoado"
        case .settled: return "Quitado na saída"
        }
    }
}
