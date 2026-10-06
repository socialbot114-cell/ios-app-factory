import SwiftUI

// MARK: - App Contatos

struct FootballContactsView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var note: String?
    var focusedContactID: Int? = nil
    @State private var selectedContact: Contact?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Seis pessoas que acompanham a sua carreira. Conversar custa energia e só dá para uma conversa por dia de jogo. Quem fica sem atenção esfria.")
                .font(.subheadline).foregroundStyle(.secondary)
            if let note {
                Label(note, systemImage: "checkmark.circle.fill").font(.subheadline.weight(.medium)).foregroundStyle(FootballTheme.accent)
            }
            ForEach(career.world.contacts.contacts.sorted {
                if $0.id == focusedContactID { return $1.id != focusedContactID }
                if $1.id == focusedContactID { return false }
                return $0.id < $1.id
            }) { contact in
                FactoryPanel {
                    HStack(spacing: 12) {
                        Image(systemName: contact.role.symbol).font(.title3).foregroundStyle(.white)
                            .frame(width: 44, height: 44).background(Color.teal.gradient, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name).font(.headline)
                            Text(contact.role.title).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(contact.relationship)").font(.title3.weight(.heavy).monospacedDigit())
                    }
                    ConditionBar(value: contact.relationship)
                    Text(contact.role.perk).font(.caption).foregroundStyle(.secondary)
                    Button("Ver ficha") { selectedContact = contact }
                        .accessibilityIdentifier("contact-profile-\(contact.id)")
                    let block = career.canContact(contact.role)
                    Button {
                        if let text = career.contactAction(contact.role) { note = text } else { onAlert(block ?? "Indisponível.") }
                    } label: {
                        Label(contact.role.action, systemImage: "phone.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .opacity(block == nil ? 1 : 0.45)
                    .accessibilityIdentifier("contact-\(contact.role.rawValue)")
                    FootballContactTopicsView(career: $career, contact: contact) { note = $0 }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Contatos")
        .onAppear {
            selectedContact = career.world.contacts.contacts.first { $0.id == focusedContactID }
        }
        .onChange(of: focusedContactID) { _, id in
            selectedContact = career.world.contacts.contacts.first { $0.id == id }
        }
        .sheet(item: $selectedContact) { selection in
            NavigationStack {
                List {
                    if let contact = career.world.contacts.contacts.first(where: { $0.id == selection.id }) {
                        Section(contact.name) {
                            Label(contact.role.title, systemImage: contact.role.symbol)
                            LabeledContent("Relação", value: "\(contact.relationship)/100")
                            Text(contact.role.perk)
                            LabeledContent("Última conversa", value: contact.lastContactWorldDay < 0 ? "Ainda não conversaram" : "Dia \(contact.lastContactWorldDay) do jogo")
                            Text(career.canContact(contact.role) ?? "Conversa disponível no app Contatos.")
                                .foregroundStyle(.secondary)
                        }
                        FootballContactDossier(career: career, contact: contact)
                    }
                }
                .navigationTitle("Ficha do contato")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { selectedContact = nil } } }
            }
        }
    }
}
