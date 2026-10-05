import SwiftUI

/// Planos A/B: salvar o que está em uso, trocar com um toque e comparar o que dá para verificar.
struct FootballTacticalPlansPanel: View {
    @Binding var career: FootballCareer
    @State private var message: String?

    var body: some View {
        FactoryPanel(title: "Planos A/B", systemImage: "square.on.square") {
            ForEach(PlanSlot.allCases) { slot in
                VStack(alignment: .leading, spacing: 6) {
                    if let plan = career.tacticalPlan(slot) {
                        Text("\(slot.title) · \(plan.formation.rawValue) · \(plan.style.rawValue)").font(.subheadline.weight(.semibold))
                        let missing = career.unavailableStarters(in: plan).count
                        Text(missing == 0 ? "Todos os titulares disponíveis." : "\(missing) titular(es) indisponíveis hoje; serão substituídos.")
                            .font(.caption).foregroundStyle(missing == 0 ? Color.secondary : Color.orange)
                    } else {
                        Text("\(slot.title) ainda não foi salvo").font(.subheadline.weight(.semibold))
                    }
                    HStack(spacing: 8) {
                        Button("Salvar o atual") {
                            career.saveTacticalPlan(slot)
                            message = "\(slot.title) salvo com a tática e a escalação de agora."
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("plan-save-\(slot.rawValue)")
                        Button("Aplicar") { message = career.applyTacticalPlan(slot).message }
                            .buttonStyle(.borderedProminent)
                            .disabled(career.tacticalPlan(slot) == nil || career.liveMatch != nil)
                            .accessibilityIdentifier("plan-apply-\(slot.rawValue)")
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            if career.tacticalPlan(.a) != nil, career.tacticalPlan(.b) != nil {
                Divider()
                ForEach(career.compareTacticalPlans(), id: \.self) { line in
                    Label(line, systemImage: "arrow.left.and.right").font(.caption)
                }
            }
            if let message { Text(message).font(.caption.weight(.medium)).foregroundStyle(FootballTheme.accent) }
        }
        .accessibilityIdentifier("tactical-plans")
    }
}
