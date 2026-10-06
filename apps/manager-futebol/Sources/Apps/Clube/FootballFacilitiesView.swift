import SwiftUI

// MARK: - Estrutura e ingressos

struct FootballFacilitiesView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let project = career.upgradeProject {
                FactoryPanel(title: "Obra em andamento", systemImage: "hammer.fill") {
                    Text("\(project.kind.title) → nível \(project.targetLevel)").font(.subheadline.weight(.bold))
                    Text("Entrega na temporada \(project.dueSeason), jogo \(project.dueMatchDay + 1).").font(.caption).foregroundStyle(.secondary)
                }
            }
            FootballConstructionPanel(career: career)
            ForEach(FacilityKind.allCases) { kind in
                FactoryPanel(title: "\(kind.title) · nível \(career.facilityLevel(kind))/\(FootballCareer.maxFacilityLevel)", systemImage: kind.symbol) {
                    Text(kind.effect).font(.caption).foregroundStyle(.secondary)
                    FootballUpgradeSimulationRow(career: career, kind: kind)
                    if let cost = career.upgradeCost(for: kind) {
                        Button {
                            if !career.startUpgrade(kind) { onAlert(career.canStartUpgrade(kind) ?? "Não foi possível iniciar a obra.") }
                        } label: {
                            Label("Melhorar · \(FootballFormat.money(cost)) · \(career.upgradeDuration(for: kind)) jogos", systemImage: "arrow.up.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("upgrade-\(kind.rawValue)")
                    } else {
                        Label("Nível máximo", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.green)
                    }
                }
            }
            FactoryPanel(title: "Estádio e bilheteria", systemImage: "ticket.fill") {
                Text("\(career.stadiumDisplayName) · capacidade \(career.stadiumCapacity.formatted(.number.locale(Locale(identifier: "pt_BR"))))")
                    .font(.subheadline.weight(.semibold))
                Picker("Preço dos ingressos", selection: $career.ticketPrice) {
                    ForEach(TicketPrice.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Ingresso caro rende mais por torcedor e enche menos o estádio. Sócios: \(career.members.formatted(.number.locale(Locale(identifier: "pt_BR")))).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .factoryPage()
        .navigationTitle("Estrutura")
    }
}
