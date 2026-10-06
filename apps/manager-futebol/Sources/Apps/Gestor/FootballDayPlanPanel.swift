import SwiftUI

/// Roteiro do dia: o que o jogo recomenda fazer, na ordem, terminando com a rotina do calendário.
struct FootballDayPlanPanel: View {
    let career: FootballCareer
    var onShowPress: () -> Void = {}
    var onNavigate: (PhoneApp) -> Void = { _ in }

    var body: some View {
        let plan = career.dayPlan()
        if plan.count > 1 && !career.isFired {
            FactoryPanel(title: "Plano do dia", systemImage: "sparkles") {
                ForEach(Array(plan.enumerated()), id: \.element.id) { index, item in
                    Button {
                        if item.id == "press" { onShowPress() }
                        else if let app = PhoneApp(rawValue: item.appID) { onNavigate(app) }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)").font(.caption.weight(.heavy)).foregroundStyle(.white)
                                .frame(width: 22, height: 22).background(item.priority >= 3 ? Color.red : FootballTheme.accent, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text(item.detail).font(.caption).foregroundStyle(.secondary)
                                if let why = item.why { Text(why).font(.caption2).foregroundStyle(.orange) }
                            }
                            Spacer()
                            Image(systemName: item.symbol).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("plan-\(item.id)")
                    if index < plan.count - 1 { Divider() }
                }
            }
            .accessibilityIdentifier("day-plan")
        }
    }
}
