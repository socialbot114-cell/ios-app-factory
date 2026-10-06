import SwiftUI

/// Arcos em andamento e encerrados: origem, participantes, confiabilidade, prazo, ações e a cadeia de acontecimentos.
struct FootballStoryArcPanel: View {
    @Binding var career: FootballCareer
    @State private var message: String?

    var body: some View {
        let open = career.openArcs
        let closed = career.arcs.filter { !$0.isOpen }.suffix(3).reversed()
        if !open.isEmpty || !closed.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(open) { arc in openArc(arc) }
                if !closed.isEmpty {
                    FactoryPanel(title: "Arcos encerrados", systemImage: "checkmark.seal.fill") {
                        ForEach(Array(closed)) { arc in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(arc.title).font(.subheadline.weight(.semibold))
                                if let outcome = arc.outcome { Text(outcome).font(.caption).foregroundStyle(.secondary) }
                                chain(arc)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                if let message { Text(message).font(.caption.weight(.medium)).foregroundStyle(FootballTheme.accent) }
            }
            .accessibilityIdentifier("story-arcs")
        }
    }

    private func openArc(_ arc: StoryArc) -> some View {
        let daysLeft = max(0, arc.deadlineWorldDay - career.worldDay)
        return FactoryPanel(title: arc.title, systemImage: "newspaper.fill") {
            HStack(spacing: 8) {
                PillLabel(text: arc.reliability.label.uppercased(), tint: arc.reliability == .confirmed ? .red : .orange)
                PillLabel(text: daysLeft <= 1 ? "ÚLTIMO DIA" : "\(daysLeft) DIAS", tint: daysLeft <= 1 ? .red : .gray)
            }
            Text("Origem: \(arc.origin)").font(.caption).foregroundStyle(.secondary)
            Text("Participantes: \(arc.participants.joined(separator: " · "))").font(.caption).foregroundStyle(.secondary)
            chain(arc)
            Divider()
            if !arc.infoAsked {
                Button {
                    message = career.askArcInfo(arc.id)
                } label: { Label("Pedir informação ao empresário", systemImage: "questionmark.bubble.fill") }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("arc-info-\(arc.id)")
            }
            ForEach(ArcChoice.allCases.filter { $0 != .ignore }) { choice in
                Button {
                    career.decideArc(arc.id, choice)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(choice.title).font(.subheadline.weight(.bold))
                        Text(choice.hint).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("arc-\(choice.rawValue)-\(arc.id)")
            }
            Text("Sem decisão no prazo, o boato segue seu curso e o desfecho fica registrado.").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func chain(_ arc: StoryArc) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(arc.steps) { step in
                Label("Dia \(step.worldDay + 1): \(step.text)", systemImage: symbol(step.kind)).font(.caption)
            }
        }
    }

    private func symbol(_ kind: ArcStepKind) -> String {
        switch kind {
        case .opened: return "flag.fill"
        case .update: return "arrow.triangle.2.circlepath"
        case .info: return "questionmark.circle"
        case .delegated: return "person.crop.circle.badge.checkmark"
        case .decision: return "hand.tap.fill"
        case .omission: return "clock.badge.exclamationmark"
        case .outcome: return "checkmark.circle.fill"
        }
    }
}
