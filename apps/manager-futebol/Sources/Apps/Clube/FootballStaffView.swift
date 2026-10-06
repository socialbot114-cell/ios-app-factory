import SwiftUI

// MARK: - Comissão técnica

struct FootballStaffView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FootballStaffTasksPanel(career: $career, onAlert: onAlert)
            ForEach(StaffRole.allCases) { role in
                FactoryPanel(title: role.title, systemImage: role.symbol) {
                    Text(role.effect).font(.caption).foregroundStyle(.secondary)
                    if let member = career.staffMember(role) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name).font(.subheadline.weight(.bold))
                                Text("Habilidade \(member.ability)/20 · \(FootballFormat.money(member.wage))/temporada").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Demitir", role: .destructive) { career.fireStaff(id: member.id) }.buttonStyle(.bordered).font(.caption.weight(.bold))
                        }
                    } else {
                        Text("Vaga aberta").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    }
                    ForEach(career.staffCandidates(for: role)) { candidate in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.name).font(.subheadline)
                                Text("Habilidade \(candidate.ability) · \(FootballFormat.money(candidate.wage))/temp.").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Contratar") {
                                if !career.hireStaff(candidateID: candidate.id) { onAlert("Sem caixa para contratar.") }
                            }
                            .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                        }
                    }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Comissão técnica")
    }
}
