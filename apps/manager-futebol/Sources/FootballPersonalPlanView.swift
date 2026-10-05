import SwiftUI

/// Agenda pessoal no app Vida: planejar os próximos dias vendo jogo, viagem, energia e prazos (F4-04 / VID-01).
struct FootballPersonalPlanPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var selectedDay: Int?
    @State private var activity: CoachActivity = .rest

    var body: some View {
        let days = career.personalPlanDays
        FactoryPanel(title: "Planejar os próximos dias", systemImage: "calendar") {
            if days.isEmpty {
                Text("Sem dias de jogo pela frente nesta temporada.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(days) { day in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        selectedDay = selectedDay == day.worldDay ? nil : day.worldDay
                        if let planned = day.planned { activity = planned.activity }
                    } label: { dayRow(day) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("plan-day-\(day.matchDay)")
                    if selectedDay == day.worldDay { editor(day) }
                }
                if day.id != days.last?.id { Divider() }
            }
            let history = career.world.projects.personalPlan.filter { $0.status != .planned }.suffix(3).reversed()
            if !history.isEmpty {
                Divider()
                Text("Últimos compromissos").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(Array(history)) { entry in
                    Label("\(entry.activity.title): \(entry.note)", systemImage: entry.status == .done ? "checkmark.circle" : "xmark.circle")
                        .font(.caption).foregroundStyle(entry.status == .done ? Color.secondary : Color.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("personal-plan")
    }

    private func dayRow(_ day: PersonalPlanDay) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.worldDay == career.worldDay ? "Hoje · dia \(day.matchDay + 1)" : "Dia \(day.matchDay + 1)")
                    .font(.subheadline.weight(.semibold))
                Text(matchText(day)).font(.caption).foregroundStyle(day.isDerby ? Color.red : Color.secondary)
                if !day.deadlines.isEmpty {
                    Label("\(day.deadlines.count) prazo(s) do clube", systemImage: "exclamationmark.circle.fill")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let planned = day.planned {
                    Label(planned.activity.title, systemImage: planned.activity.symbol)
                        .font(.caption.weight(.semibold)).foregroundStyle(FootballTheme.accent).lineLimit(1)
                } else {
                    Text("Livre").font(.caption).foregroundStyle(.secondary)
                }
                Text("energia \(day.energyAtStart)").font(.caption2.monospacedDigit())
                    .foregroundStyle(day.energyAtStart < 20 ? Color.red : Color.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func matchText(_ day: PersonalPlanDay) -> String {
        guard let opponent = day.opponentID else { return "Sem jogo do clube" }
        let place = day.isHome ? "em casa" : "fora · viagem"
        return "\(day.isDerby ? "Clássico · " : "")\(FootballSeason.teamName(opponent)) \(place)"
    }

    private func editor(_ day: PersonalPlanDay) -> some View {
        let conflicts = career.planConflicts(activity, on: day.worldDay)
        let blocked = conflicts.contains { $0.severity == .blocking }
        return VStack(alignment: .leading, spacing: 8) {
            Picker("Atividade", selection: $activity) {
                ForEach(CoachActivity.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.menu)
            Text(activity.summary + (activity.isInPerson ? " Presencial." : " Pode ser feito à distância."))
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Array(conflicts.enumerated()), id: \.offset) { _, conflict in
                Label(conflict.text, systemImage: conflict.severity == .blocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(conflict.severity == .blocking ? Color.red : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button("Marcar") {
                    if !career.planActivity(activity, on: day.worldDay) {
                        onAlert(conflicts.first { $0.severity == .blocking }?.text ?? "Não foi possível marcar.")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(blocked)
                .accessibilityIdentifier("plan-confirm")
                if day.planned != nil {
                    Button("Desmarcar", role: .destructive) { career.unplanActivity(on: day.worldDay) }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
