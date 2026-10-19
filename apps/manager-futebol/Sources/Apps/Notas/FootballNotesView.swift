import SwiftUI

/// App Notas: anotações curtas do treinador, a mais nova primeiro. Ficam na carreira.
struct FootballNotesView: View {
    @Binding var career: FootballCareer
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FootballScreenHeader(career: career, title: "Anotações do treinador",
                                 subtitle: "Lembretes que só você vê: quem renovar, o que dizer ao elenco, o plano da semana.")
            FactoryPanel(title: "Nova anotação", systemImage: "square.and.pencil") {
                TextField("Escreva um lembrete", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("note-field")
                HStack {
                    Text("\(draft.count)/\(FootballCareer.noteCharacterLimit)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        if career.addNote(draft) != nil { draft = "" }
                    } label: { Label("Guardar", systemImage: "plus.circle.fill") }
                        .buttonStyle(FootballSecondaryButtonStyle())
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("note-add")
                }
            }
            let notes = career.coachNotes
            FactoryPanel(title: "Suas notas · \(notes.count)", systemImage: "note.text") {
                if notes.isEmpty {
                    Text("Nenhuma anotação ainda. As notas ficam guardadas na carreira.").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(note.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Text("T\(note.season) · \(career.shortDate(matchDay: note.matchDay, season: note.season))")
                                .font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Button("Apagar", role: .destructive) { career.deleteNote(id: note.id) }
                                .font(.caption2.weight(.semibold))
                                .accessibilityIdentifier("note-delete-\(note.id)")
                        }
                    }
                    if note.id != notes.last?.id { Divider() }
                }
            }
            .accessibilityIdentifier("notes-list")
        }
        .factoryPage()
        .navigationTitle("Notas")
        .accessibilityIdentifier("notes-app")
    }
}
