import SwiftUI

/// Os slots pertencem ao FutOS; a raiz executa trocas para que todos os apps recebam a mesma carreira.
struct FootballSaveSlotsView: View {
    let activeSlot: Int
    let summaries: [SaveSlotSummary?]
    let onLoad: (Int) -> Void
    let onNew: (Int) -> Void
    let onDelete: (Int) -> Void
    @State private var pending: Action?

    private enum Action: Identifiable {
        case replace(Int), delete(Int)
        var slot: Int { switch self { case .replace(let slot), .delete(let slot): return slot } }
        var id: String { switch self { case .replace(let slot): return "replace-\(slot)"; case .delete(let slot): return "delete-\(slot)" } }
        var title: String { switch self {
        case .replace: return "Substituir a carreira do espaço \(slot + 1)?"
        case .delete: return "Apagar a carreira do espaço \(slot + 1)?"
        } }
    }

    var body: some View {
        FactoryPanel(title: "Carreiras do FutOS", systemImage: "externaldrive.fill") {
            Text("Três espaços locais. Antes de trocar, o FutOS salva a carreira atual. Todos os apps acompanham o espaço em uso.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(0..<FootballSaveStore.slotCount, id: \.self) { slot in
                let summary = summaries.indices.contains(slot) ? summaries[slot] : nil
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if let clubID = summary?.clubID, let club = FootballSeason.team(clubID) { ClubCrest(team: club, size: 30) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Espaço \(slot + 1) · \(summary?.clubID.map { FootballSeason.teamName($0) } ?? (summary == nil ? "Vazio" : "Sem clube"))")
                                .font(.subheadline.weight(.bold))
                            if let summary {
                                Text("Temporada \(summary.season) · J\(summary.matchDay + 1) · \(summary.division?.name ?? "Carreira")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if slot == activeSlot { PillLabel(text: "EM USO", tint: FootballTheme.accent).accessibilityIdentifier("settings-active-slot-\(slot)") }
                    }
                    HStack {
                        if slot != activeSlot && summary != nil {
                            Button("Carregar") { onLoad(slot) }.buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("settings-load-slot-\(slot)")
                            Button("Apagar", role: .destructive) { pending = .delete(slot) }.buttonStyle(.bordered)
                                .accessibilityIdentifier("settings-delete-slot-\(slot)")
                        }
                        Button(summary == nil && slot != activeSlot ? "Nova carreira" : "Recomeçar") {
                            if summary == nil && slot != activeSlot { onNew(slot) }
                            else { pending = .replace(slot) }
                        }.buttonStyle(.bordered)
                            .accessibilityIdentifier("settings-new-slot-\(slot)")
                    }.font(.caption.weight(.semibold))
                }
                if slot < FootballSaveStore.slotCount - 1 { Divider() }
            }
        }
        .accessibilityIdentifier("settings-save-slots")
        .confirmationDialog(pending?.title ?? "Carreiras", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
            if let pending {
                switch pending {
                case .replace(let slot): Button("Começar nova carreira", role: .destructive) { self.pending = nil; onNew(slot) }
                case .delete(let slot): Button("Apagar carreira", role: .destructive) { self.pending = nil; onDelete(slot) }
                }
            }
            Button("Cancelar", role: .cancel) { pending = nil }
        } message: { Text("Essa ação remove os dados desse espaço e não pode ser desfeita.") }
    }
}
