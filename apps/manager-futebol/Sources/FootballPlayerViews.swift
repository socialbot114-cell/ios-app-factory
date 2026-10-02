import SwiftUI

// MARK: - Ficha do atleta

struct FootballPlayerDetailView: View {
    @Binding var career: FootballCareer
    let playerID: Int
    let onAlert: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmSale = false
    @State private var showSubstitution = false
    @State private var showRenewal = false
    @State private var showBid = false
    @State private var showLoanOut = false

    private var isOwn: Bool { career.player(playerID)?.teamID == career.selectedClubID }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let player = career.player(playerID) {
                    VStack(alignment: .leading, spacing: 18) {
                        header(player)
                        profilePanel(player)
                        if isOwn { contractPanel(player) }
                        attributesPanel(player)
                        traitsPanel(player)
                        seasonPanel(player)
                        if isOwn { trainingPanel(player) }
                        actions(for: player)
                    }
                    .padding(20)
                } else {
                    Text("Este atleta não está mais disponível.").padding(20)
                }
            }
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle("Ficha do atleta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
        }
        .tint(FootballTheme.accent)
        .sheet(isPresented: $showSubstitution) {
            FootballSubstitutionSheet(career: $career, outgoingID: career.startingXI.contains(playerID) ? playerID : nil)
        }
        .sheet(isPresented: $showRenewal) { FootballRenewalSheet(career: $career, playerID: playerID) }
        .sheet(isPresented: $showBid) { FootballBidSheet(career: $career, playerID: playerID, onAlert: onAlert) }
        .sheet(isPresented: $showLoanOut) { FootballLoanOutSheet(career: $career, playerID: playerID, onAlert: onAlert) }
    }

    // MARK: Cabeçalho

    private func header(_ player: FootballPlayer) -> some View {
        let range = career.visibleOverallRange(of: player.id)
        return HStack(spacing: 16) {
            if range.lowerBound == range.upperBound {
                RatingBadge(value: player.overall, size: 64)
            } else {
                Text("\(range.lowerBound)–\(range.upperBound)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 64)
                    .background(Color.gray, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name).font(.title2.bold())
                Text("\(player.detail.title) · \(player.age) anos").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if let teamID = player.teamID, let team = FootballSeason.team(teamID) { PillLabel(text: team.shortName, tint: team.primaryColor) }
                    if player.isInjured { PillLabel(text: "Lesionado · \(player.injuryRounds)", systemImage: "cross.case.fill", tint: .red) }
                    if player.discipline.suspensionGames > 0 { PillLabel(text: "Suspenso · \(player.discipline.suspensionGames)", tint: .orange) }
                    if player.onLoan { PillLabel(text: "Emprestado", tint: .indigo) }
                }
            }
        }
    }

    private func profilePanel(_ player: FootballPlayer) -> some View {
        FactoryPanel(title: "Perfil", systemImage: "person.text.rectangle") {
            detailRow("Potencial", isOwn || career.scoutKnowledge(of: player.id) >= 60 ? "\(player.potential)" : "?")
            VStack(alignment: .leading, spacing: 6) {
                detailRow("Energia", "\(player.condition)%")
                ConditionBar(value: player.condition)
            }
            detailRow("Valor de mercado", FootballFormat.money(player.marketValue))
            detailRow("Origem", LeagueTeam.regionNames[min(player.region, LeagueTeam.regionNames.count - 1)])
            if isOwn {
                detailRow("Moral", "\(MoraleLevel(value: player.morale).title) (\(player.morale))")
                if let average = player.form.recentAverage { detailRow("Nota média recente", String(format: "%.1f", average)) }
            } else {
                detailRow("Conhecimento do olheiro", "\(career.scoutKnowledge(of: player.id))%")
            }
        }
    }

    private func contractPanel(_ player: FootballPlayer) -> some View {
        FactoryPanel(title: "Contrato", systemImage: "doc.text.fill") {
            detailRow("Salário", "\(FootballFormat.money(player.contract.wage))/temporada")
            detailRow("Até a temporada", player.contract.endSeason == 0 ? "—" : "\(player.contract.endSeason)")
            detailRow("Papel esperado", player.contract.status.title)
            if player.contract.endSeason != 0 && player.contract.endSeason <= career.season {
                Label("Contrato termina neste ano: renove antes que ele saia de graça.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.orange)
            }
            if career.canRenew(playerID: player.id) {
                Button { showRenewal = true } label: {
                    Label("Negociar renovação", systemImage: "signature").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("renew-\(player.id)")
            }
        }
    }

    private func attributesPanel(_ player: FootballPlayer) -> some View {
        FactoryPanel(title: "Atributos", systemImage: "chart.bar.xaxis") {
            let groups = AttributeGroup.allCases.filter { group in
                (group != .goalkeeping || player.position == .goalkeeper) && (group != .hidden || isOwn)
            }
            ForEach(groups, id: \.self) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.rawValue.uppercased()).font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.secondary)
                    ForEach(AttributeKind.allCases.filter { $0.group == group }) { kind in
                        let range = career.visibleAttribute(playerID: player.id, kind: kind)
                        HStack(spacing: 10) {
                            Text(kind.title).font(.caption).frame(width: 118, alignment: .leading)
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.primary.opacity(0.08))
                                    Capsule().fill(attributeColor(range.upperBound))
                                        .frame(width: proxy.size.width * CGFloat(range.upperBound) / 20)
                                        .opacity(range.lowerBound == range.upperBound ? 1 : 0.45)
                                }
                            }
                            .frame(height: 6)
                            Text(range.lowerBound == range.upperBound ? "\(range.lowerBound)" : "\(range.lowerBound)–\(range.upperBound)")
                                .font(.caption.weight(.bold).monospacedDigit()).frame(width: 38, alignment: .trailing)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            if !isOwn {
                Text("Atributos com faixa são estimativas do olheiro. Observar o atleta estreita as faixas.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func attributeColor(_ value: Int) -> Color {
        switch value {
        case 17...: return FootballTheme.gold
        case 14..<17: return .green
        case 10..<14: return .blue
        default: return .gray
        }
    }

    private func traitsPanel(_ player: FootballPlayer) -> some View {
        FactoryPanel(title: "Características", systemImage: "sparkles") {
            if player.traits.isEmpty || (!isOwn && career.scoutKnowledge(of: player.id) < 50) {
                Text(player.traits.isEmpty ? "Sem características marcantes." : "Observe mais para descobrir as características.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(player.traits) { trait in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: trait.isPositive ? "plus.circle.fill" : "minus.circle.fill").foregroundStyle(trait.isPositive ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trait.title).font(.subheadline.weight(.semibold))
                            Text(trait.summary).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func seasonPanel(_ player: FootballPlayer) -> some View {
        FactoryPanel(title: "Temporada", systemImage: "chart.bar.fill") {
            detailRow("Jogos", "\(player.appearances)")
            detailRow("Gols", "\(player.goals)")
            detailRow("Assistências", "\(player.assists)")
            detailRow("Gols na carreira", "\(player.careerGoals)")
        }
    }

    // MARK: Treino individual

    @ViewBuilder
    private func trainingPanel(_ player: FootballPlayer) -> some View {
        FactoryPanel(title: "Treino individual", systemImage: "figure.strengthtraining.traditional") {
            Text("Até \(FootballCareer.individualProgramLimit) atletas com programa individual (\(career.individualProgramCount) em uso).")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("Foco em").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Foco", selection: Binding(
                    get: { player.individualFocus },
                    set: { value in if !career.setIndividualFocus(playerID: player.id, kind: value) { onAlert("Limite de programas individuais atingido.") } }
                )) {
                    Text("Nenhum").tag(AttributeKind?.none)
                    ForEach(AttributeKind.allCases.filter { $0.group != .hidden && ($0.group != .goalkeeping || player.position == .goalkeeper) }) {
                        Text($0.title).tag(AttributeKind?.some($0))
                    }
                }
                .pickerStyle(.menu)
            }
            if let learning = player.learningPosition {
                Label("Aprendendo \(learning.title.lowercased()): \(player.learningProgress)/6 sessões", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.semibold))
            } else {
                Menu {
                    ForEach(FootballPosition.allCases.filter { $0 != player.position && !player.learnedPositions.contains($0) }, id: \.self) { position in
                        Button(position.title) {
                            if !career.startLearning(playerID: player.id, position: position) { onAlert("Limite de programas individuais atingido.") }
                        }
                    }
                } label: {
                    Label("Aprender nova posição", systemImage: "arrow.triangle.branch")
                }
            }
            if !player.learnedPositions.isEmpty {
                Text("Também joga de: " + player.learnedPositions.map(\.title).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Ações

    @ViewBuilder
    private func actions(for player: FootballPlayer) -> some View {
        FactoryPanel(title: "Ações", systemImage: "hand.tap.fill") {
            if isOwn {
                ownActions(player)
            } else if player.teamID != nil {
                Button { showBid = true } label: {
                    Label("Fazer proposta", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("bid-\(player.id)")
                if let reason = career.canLoanIn(playerID: player.id) {
                    Text("Empréstimo: \(reason)").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button {
                        if career.loanIn(playerID: player.id) { dismiss() }
                    } label: {
                        Label("Pedir por empréstimo · \(FootballFormat.money(career.loanFee(for: player)))", systemImage: "arrow.left.arrow.right").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                watchButton(player)
            } else {
                Text("Agente livre: contrate pela aba Mercado.").font(.caption).foregroundStyle(.secondary)
                watchButton(player)
            }
        }
    }

    @ViewBuilder
    private func ownActions(_ player: FootballPlayer) -> some View {
        let price = career.quickSalePrice(playerID: player.id)
        if career.startingXI.contains(player.id) {
            Button { showSubstitution = true } label: {
                Label("Substituir este titular", systemImage: "arrow.left.arrow.right").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        if player.onLoan {
            if career.canBuyOutLoan(playerID: player.id), let option = player.purchaseOption {
                Button {
                    if career.buyOutLoan(playerID: player.id) { onAlert("\(player.name) agora é do clube.") }
                } label: {
                    Label("Comprar por \(FootballFormat.money(option))", systemImage: "cart.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            Toggle("Colocar na lista de transferência", isOn: Binding(
                get: { player.isListed },
                set: { career.setListed(playerID: player.id, listed: $0) }
            ))
            .font(.subheadline)
            Toggle("Disponível para empréstimo", isOn: Binding(
                get: { player.isLoanListed },
                set: { career.setListed(playerID: player.id, listed: $0, loan: true) }
            ))
            .font(.subheadline)
            Button { showLoanOut = true } label: {
                Label("Emprestar a um clube", systemImage: "arrow.uturn.right.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!career.isTransferWindowOpen || !career.canRelease(playerID: player.id))
            Button {
                if !career.promiseStarts(playerID: player.id) { onAlert("Não é possível prometer minutos a este atleta agora.") }
                else { onAlert("Promessa feita: ele jogará de início nos próximos jogos.") }
            } label: {
                Label("Prometer 3 jogos como titular", systemImage: "hand.thumbsup.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        Button(role: .destructive) { confirmSale = true } label: {
            Label("Vender agora por \(FootballFormat.money(price))", systemImage: "banknote").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!career.canSell(playerID: player.id))
        .accessibilityIdentifier("sell-player-\(player.id)")
        Text("Venda imediata paga \(Int(FootballCareer.quickSaleRate * 100))% do valor. Propostas costumam pagar mais.")
            .font(.caption).foregroundStyle(.secondary)
            .confirmationDialog("Vender \(player.name)?", isPresented: $confirmSale, titleVisibility: .visible) {
                Button("Vender por \(FootballFormat.money(price))", role: .destructive) {
                    if career.sellPlayer(playerID: player.id) { dismiss() } else { onAlert("Venda bloqueada: o elenco precisa continuar preenchendo a formação.") }
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("O atleta vai para o mercado de agentes livres.")
            }
    }

    private func watchButton(_ player: FootballPlayer) -> some View {
        Button { career.toggleWatch(playerID: player.id) } label: {
            Label(career.watchlist.contains(player.id) ? "Remover da lista de observação" : "Observar este atleta",
                  systemImage: career.watchlist.contains(player.id) ? "eye.slash.fill" : "eye.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }
}

// MARK: - Renovação

struct FootballRenewalSheet: View {
    @Binding var career: FootballCareer
    let playerID: Int
    @Environment(\.dismiss) private var dismiss
    @State private var wage = 0
    @State private var years = 3
    @State private var status: SquadStatus = .starter
    @State private var message: String?
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                if let player = career.player(playerID), let ask = career.contractAsk(playerID: playerID) {
                    Section("Pedido do atleta") {
                        Text("\(player.name) quer \(FootballFormat.money(ask.wage)) por \(ask.years) temporada(s) como \(ask.status.title.lowercased()).")
                            .font(.subheadline)
                        Text("Folga na folha salarial: \(FootballFormat.money(career.wageHeadroom))").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Sua oferta") {
                        Stepper("Salário: \(FootballFormat.money(wage))", value: $wage, in: 20_000...3_000_000, step: 5_000)
                        Stepper("Duração: \(years) temporada(s)", value: $years, in: 1...5)
                        Picker("Papel prometido", selection: $status) {
                            ForEach(SquadStatus.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                    }
                    if let message { Section { Text(message).font(.subheadline) } }
                    Section {
                        Button("Fazer oferta") { submit() }.accessibilityIdentifier("renewal-submit")
                    }
                    .onAppear {
                        guard !didLoad else { return }
                        didLoad = true
                        wage = ask.wage
                        years = ask.years
                        status = ask.status
                    }
                }
            }
            .navigationTitle("Renovação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
        }
        .tint(FootballTheme.accent)
    }

    private func submit() {
        switch career.offerRenewal(playerID: playerID, wage: wage, years: years, status: status) {
        case .accepted: dismiss()
        case .counter(let counter):
            wage = counter
            message = "Contraproposta: \(FootballFormat.money(counter)) por temporada. Ajustei o valor para você aceitar."
        case .refused(let text), .notAllowed(let text): message = text
        case .overWageCap: message = "A folha salarial passaria do teto definido pela diretoria."
        }
    }
}

// MARK: - Proposta por atleta de outro clube

struct FootballBidSheet: View {
    @Binding var career: FootballCareer
    let playerID: Int
    let onAlert: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var fee = 0
    @State private var wage = 0
    @State private var years = 3
    @State private var installments = 1
    @State private var goalBonus = 0
    @State private var swapID: Int?
    @State private var message: String?
    @State private var didLoad = false

    private var bid: TransferBid {
        TransferBid(playerID: playerID, fee: fee, installments: installments, swapPlayerID: swapID, goalBonus: goalBonus, wage: wage, years: years)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let player = career.player(playerID) {
                    Section("Negociação") {
                        Text("\(player.name) · \(FootballSeason.teamName(player.teamID ?? 0))").font(.subheadline.weight(.semibold))
                        Text("Pedido aproximado: \(FootballFormat.money(career.askingPrice(for: player)))").font(.caption).foregroundStyle(.secondary)
                        Text("Caixa: \(FootballFormat.money(career.transferBudget))").font(.caption).foregroundStyle(.secondary)
                        if let window = career.transferWindow {
                            Text("\(window.title): \(window.daysLeft) dia(s) restantes").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Label("Janela fechada", systemImage: "lock.fill").font(.caption).foregroundStyle(.red)
                        }
                    }
                    Section("Proposta ao clube") {
                        Stepper("Valor: \(FootballFormat.money(fee))", value: $fee, in: 0...80_000_000, step: 250_000)
                        Stepper("Parcelas: \(installments)", value: $installments, in: 1...4)
                        Stepper("Bônus por 10 gols: \(FootballFormat.money(goalBonus))", value: $goalBonus, in: 0...5_000_000, step: 250_000)
                        Picker("Troca", selection: $swapID) {
                            Text("Sem troca").tag(Int?.none)
                            ForEach(career.clubRoster.filter { !$0.isYouth && career.canRelease(playerID: $0.id) }) { own in
                                Text("\(own.name) · \(own.overall)").tag(Int?.some(own.id))
                            }
                        }
                    }
                    Section("Proposta ao atleta") {
                        Stepper("Salário: \(FootballFormat.money(wage))", value: $wage, in: 20_000...3_000_000, step: 5_000)
                        Stepper("Contrato: \(years) temporada(s)", value: $years, in: 1...5)
                    }
                    if let message { Section { Text(message).font(.subheadline) } }
                    Section {
                        Button("Enviar proposta") { submit() }.accessibilityIdentifier("bid-submit")
                    }
                    .onAppear {
                        guard !didLoad else { return }
                        didLoad = true
                        fee = career.askingPrice(for: player)
                        let ask = career.joiningAsk(for: player)
                        wage = ask.wage
                        years = ask.years
                    }
                }
            }
            .navigationTitle("Proposta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
        }
        .tint(FootballTheme.accent)
    }

    private func submit() {
        switch career.submitBid(bid) {
        case .accepted:
            onAlert("Contratação fechada!")
            dismiss()
        case .counter(let counter):
            fee = counter
            message = "Contraproposta do clube: \(FootballFormat.money(counter)). Ajustei o valor."
        case .clubRefuses(let text), .notAllowed(let text): message = text
        case .playerRefuses(let ask): message = "O atleta quer pelo menos \(FootballFormat.money(ask)) por temporada."; wage = ask
        }
    }
}

// MARK: - Empréstimo para fora

struct FootballLoanOutSheet: View {
    @Binding var career: FootballCareer
    let playerID: Int
    let onAlert: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let player = career.player(playerID) {
                    Section("Emprestar \(player.name)") {
                        ForEach(career.loanDestinations(for: player)) { team in
                            Button {
                                if career.loanOut(playerID: playerID, to: team.id) {
                                    onAlert("\(player.name) foi emprestado ao \(team.name).")
                                    dismiss()
                                } else {
                                    onAlert("Não foi possível emprestar agora.")
                                }
                            } label: {
                                HStack { ClubCrest(team: team, size: 24); Text(team.name); Spacer() }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Empréstimo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
        }
        .tint(FootballTheme.accent)
    }
}
