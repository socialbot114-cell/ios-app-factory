import SwiftUI

// MARK: - Acontecimentos

struct FootballEventsView: View {
    @Binding var career: FootballCareer
    /// Abre o acontecimento escolhido num aviso no topo da lista.
    var focusedEventID: Int? = nil
    @State private var resultText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let resultText {
                Label(resultText, systemImage: "checkmark.circle.fill").font(.subheadline.weight(.medium)).foregroundStyle(FootballTheme.accent)
            }
            FootballStoryArcPanel(career: $career)
            if career.pendingEvents.isEmpty && career.openArcs.isEmpty {
                FactoryPanel(title: "Tudo calmo", systemImage: "leaf.fill") {
                    Text("Nenhum acontecimento esperando decisão. Eles surgem conforme o clube vive bons e maus momentos.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            ForEach(career.pendingEvents.sorted { $0.id == focusedEventID ? $1.id != focusedEventID : ($1.id == focusedEventID ? false : $0.id < $1.id) }) { event in
                FactoryPanel(title: event.title, systemImage: "exclamationmark.bubble.fill") {
                    Text(event.body).font(.subheadline)
                    ForEach(Array(event.choices.enumerated()), id: \.offset) { index, choice in
                        Button {
                            resultText = career.resolveEvent(id: event.id, choice: index)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(choice.label).font(.subheadline.weight(.bold))
                                Text(choice.hint).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("event-\(event.id)-choice-\(index)")
                    }
                    Text("Se você não decidir até o dia \(event.expiresWorldDay), vale a opção padrão.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if !career.world.events.history.isEmpty {
                FactoryPanel(title: "Histórico", systemImage: "clock.arrow.circlepath") {
                    ForEach(career.world.events.history.prefix(10)) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title).font(.subheadline.weight(.semibold))
                            if let text = event.resultText { Text(text).font(.caption).foregroundStyle(.secondary) }
                        }
                        if event.id != career.world.events.history.prefix(10).last?.id { Divider() }
                    }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Acontecimentos")
    }
}
