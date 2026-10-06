import SwiftUI

/// Assuntos contextuais e pedidos de um contato, no cartão do app Contatos (CON-03 / CON-04).
struct FootballContactTopicsView: View {
    @Binding var career: FootballCareer
    let contact: Contact
    let onNote: (String) -> Void

    var body: some View {
        let requests = career.openContactRequests(contact.id)
        let topics = career.availableTopics(for: contact.role).filter { $0 != ContactTopic.social(for: contact.role) }
        VStack(alignment: .leading, spacing: 8) {
            ForEach(requests) { request in requestRow(request) }
            if !topics.isEmpty {
                Menu {
                    ForEach(topics) { topic in
                        let block = career.topicBlocker(topic)
                        Button {
                            if let text = career.talk(topic) { onNote(text) } else { onNote(block ?? "Indisponível agora.") }
                        } label: {
                            Label(block == nil ? topic.title : "\(topic.title) — \(block!)", systemImage: block == nil ? "bubble.left.fill" : "lock.fill")
                        }
                        .disabled(block != nil)
                    }
                } label: {
                    Label("Outros assuntos", systemImage: "ellipsis.bubble.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("contact-topics-\(contact.role.rawValue)")
            }
        }
    }

    private func requestRow(_ request: ContactRequest) -> some View {
        let days = max(0, request.deadlineWorldDay - career.worldDay)
        let block = career.contactRequestBlocker(request.id)
        return VStack(alignment: .leading, spacing: 6) {
            Label(requestTitle(request), systemImage: "envelope.badge.fill").font(.caption.weight(.semibold))
            Text(days <= 1 ? "Responda até o próximo dia de jogo." : "Responda em \(days) dias de jogo.")
                .font(.caption2).foregroundStyle(.orange)
            if let block { Text(block).font(.caption2).foregroundStyle(.secondary) }
            HStack {
                Button("Aceitar") { onNote(career.answerContactRequest(request.id, accept: true) ?? (block ?? "Não foi possível.")) }
                    .buttonStyle(.borderedProminent).disabled(block != nil)
                Button("Recusar") { onNote(career.answerContactRequest(request.id, accept: false) ?? "") }
                    .buttonStyle(.bordered)
            }
            .font(.caption)
        }
        .padding(8)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func requestTitle(_ request: ContactRequest) -> String {
        switch request.kind {
        case .agentOpportunity: return "Dica de atleta: \(request.playerID.flatMap { career.player($0)?.name } ?? "atleta")"
        case .journalistInterview: return "Pedido de entrevista"
        case .presidentEvent: return "Convite para evento com patrocinadores"
        case .friendLoan: return "Pedido de empréstimo de \(FootballFormat.money(request.amount))"
        case .familyEvent: return "Aniversário em família"
        case .mentorLecture: return "Aula no curso de treinadores"
        case .familyPromise: return "Folga prometida"
        }
    }
}

/// Ficha do contato: interesses, efeitos da relação, promessas e histórico (CON-02 / CON-05).
struct FootballContactDossier: View {
    let career: FootballCareer
    let contact: Contact

    var body: some View {
        Section("Interesses") {
            Text(career.contactInterests(contact).joined(separator: " · ")).font(.subheadline)
        }
        Section("O que a relação muda hoje") {
            ForEach(career.relationshipEffects(contact.role), id: \.self) { Text($0).font(.subheadline) }
        }
        let promises = career.pendingContactPromises(contact.id)
        if !promises.isEmpty {
            Section("Combinados em aberto") {
                ForEach(promises) { promise in
                    Text(promiseText(promise)).font(.subheadline)
                }
            }
        }
        let history = career.contactHistory(contact.id).suffix(8).reversed()
        Section("Histórico") {
            if history.isEmpty { Text("Ainda não há conversas registradas.").foregroundStyle(.secondary) }
            ForEach(Array(history)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.title).font(.subheadline.weight(.semibold))
                        Spacer()
                        if entry.delta != 0 {
                            Text(entry.delta > 0 ? "+\(entry.delta)" : "\(entry.delta)").font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(entry.delta > 0 ? Color.green : Color.red)
                        }
                    }
                    if !entry.summary.isEmpty { Text(entry.summary).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
    }

    private func promiseText(_ promise: ContactRequest) -> String {
        let seasonStart = (career.season - 1) * FootballSeason.matchDaysPerSeason
        switch promise.kind {
        case .friendLoan:
            return "Empréstimo de \(FootballFormat.money(promise.amount)) a devolver no dia \((promise.eventWorldDay ?? 0) - seasonStart + 1)."
        case .familyEvent, .familyPromise:
            return "Folga marcada para o dia \((promise.eventWorldDay ?? 0) - seasonStart + 1). Faltar custa caro."
        default:
            return "Combinado em andamento."
        }
    }
}
