import SwiftUI

/// Tarefas da comissão técnica, relatórios e delegação inicial (CLB-05).
struct FootballStaffTasksPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        FactoryPanel(title: "Tarefas da comissão", systemImage: "checklist") {
            Toggle("Deixar a comissão escolher as tarefas", isOn: Binding(get: { career.staffTasks.autoDelegate },
                                                                          set: { career.setStaffAutoDelegate($0) }))
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("staff-auto-delegate")
            Text("Até \(FootballCareer.maxStaffTasks) tarefas ao mesmo tempo. Cada profissional entrega um relatório no fim.")
                .font(.caption2).foregroundStyle(.secondary)
            ForEach(career.runningStaffTasks) { task in
                let left = max(0, task.endWorldDay - career.worldDay)
                Label("\(task.kind.title) · \(task.staffName) · \(left) dia(s)\(task.delegated ? " · delegada" : "")", systemImage: "hourglass")
                    .font(.caption)
            }
            ForEach(StaffTaskKind.allCases) { kind in
                let block = career.staffTaskBlocker(kind)
                VStack(alignment: .leading, spacing: 2) {
                    Button {
                        if !career.assignStaffTask(kind) { onAlert(block ?? "Indisponível agora.") }
                    } label: {
                        HStack {
                            Text(kind.title).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(kind.days) dias").font(.caption2).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(block != nil)
                    .accessibilityIdentifier("staff-task-\(kind.rawValue)")
                    Text(block ?? kind.effect).font(.caption2).foregroundStyle(block == nil ? Color.secondary : Color.orange)
                }
                .opacity(block == nil ? 1 : 0.6)
            }
            let reports = career.staffTasks.tasks.filter { $0.status == .done }.suffix(3).reversed()
            if !reports.isEmpty {
                Divider()
                ForEach(Array(reports)) { task in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(task.kind.title).font(.caption.weight(.semibold))
                        Text(task.report).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .accessibilityIdentifier("staff-tasks")
    }
}
