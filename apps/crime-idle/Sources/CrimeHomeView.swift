import SwiftUI

struct CrimeHomeView: View {
    let store: CrimeGameStore
    let openTab: (CrimeTab) -> Void
    @State private var confirmReset = false

    private var state: CrimeState { store.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            topBar
            hero
            if state.boostRemaining > 0 { boostBanner }
            if let event = state.pendingEvent { CrimeEventCard(store: store, event: CrimeEvent.catalog[event]) }
            CrimeTapButton(store: store)
            HStack(alignment: .top, spacing: 12) {
                heatCard
                rankCard
            }
            if let heist = state.activeHeist { heistMini(heist) }
            contracts
            if state.claimableLegacy >= 1 { legacyTeaser }
            FactoryDemoNotice(message: "Ficção noir · cidade, famílias e golpes inventados")
        }
        .noirPage()
        .confirmationDialog("Apagar todo o progresso?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Recomeçar do zero", role: .destructive) { store.resetEverything() }
        } message: {
            Text("Família, lenda e contratos também serão apagados.")
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("CIDADE NEBLINA").font(.caption.weight(.heavy)).tracking(2.5).foregroundStyle(Noir.gold)
                Text("A noite é sua.")
                    .font(.system(size: 26, weight: .heavy, design: .serif))
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Menu {
                Button(role: .destructive) { confirmReset = true } label: {
                    Label("Recomeçar do zero", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(Noir.muted)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Ajustes")
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            CitySkyline(lit: Double(state.totalOwned) / 600, heat: state.heat, districts: state.districts)
                .frame(height: 250)
            VStack(alignment: .leading, spacing: 4) {
                Text("COFRE")
                    .font(.caption2.weight(.heavy)).tracking(2)
                    .foregroundStyle(.white.opacity(0.7))
                Text(CrimeFormat.cash(state.cash))
                    .font(.system(size: 46, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 8)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .accessibilityIdentifier("cash-balance")
                HStack(spacing: 8) {
                    NoirChip(symbol: "arrow.up.right", text: CrimeFormat.cash(state.incomePerSecond) + "/s", tint: Noir.money)
                    NoirChip(symbol: "star.fill", text: CrimeFormat.short(state.respect) + " respeito", tint: Noir.gold)
                    if state.legacy > 0 {
                        NoirChip(symbol: "crown.fill", text: "+" + CrimeFormat.percent(state.legacy * CrimeState.legacyBonus), tint: Noir.violet)
                    }
                }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
    }

    private var boostBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill").foregroundStyle(Noir.ink)
                .frame(width: 34, height: 34)
                .background(Noir.gold, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Lucro ×\(Int(state.boostMultiplier)) na cidade").font(.subheadline.weight(.bold))
                Text("Mais \(CrimeFormat.duration(state.boostRemaining))").font(.caption).foregroundStyle(Noir.muted)
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(12)
        .background(Noir.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Noir.gold.opacity(0.5)))
    }

    private var heatCard: some View {
        NoirCard(tint: Noir.heatColor(state.heat)) {
            HStack { Spacer(); HeatGauge(heat: state.heat); Spacer() }
            Text(heatCaption)
                .font(.caption).foregroundStyle(Noir.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                store.bribe()
            } label: {
                VStack(spacing: 1) {
                    Text("Molhar a mão")
                    Text(CrimeFormat.cash(state.bribeCost)).font(.caption2.weight(.semibold))
                }
            }
            .buttonStyle(NoirButtonStyle(tint: Noir.heatColor(state.heat), compact: true))
            .frame(maxWidth: .infinity)
            .disabled(state.heat < 5 || state.cash < state.bribeCost)
            .accessibilityIdentifier("bribe")
        }
    }

    private var heatCaption: String {
        if state.heat < 40 { return "A polícia nem sabe seu nome." }
        let loss = Int(((1 - state.heatMultiplier) * 100).rounded())
        return state.heat < 65 ? "Viaturas rondando: −\(loss)% de lucro." : "Batidas por toda parte: −\(loss)% de lucro!"
    }

    private var rankCard: some View {
        let index = state.rankIndex
        let rank = CrimeRank.ladder[index]
        let next = CrimeRank.ladder.indices.contains(index + 1) ? CrimeRank.ladder[index + 1] : nil
        return NoirCard(tint: Noir.violet) {
            Image(systemName: "seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(LinearGradient(colors: [Noir.gold, Noir.ember], startPoint: .top, endPoint: .bottom))
                .overlay(Text("\(index + 1)").font(.caption.weight(.black)).foregroundStyle(Noir.ink))
            Text("PATENTE").font(.caption2.weight(.heavy)).tracking(1.5).foregroundStyle(Noir.muted)
            Text(rank.title).font(.title3.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityIdentifier("rank-title")
            if let next {
                NoirBar(progress: log10(max(state.lifetimeTotal, 1)) / log10(next.threshold), tint: Noir.violet, height: 6)
                Text("Próxima: \(next.title) em \(CrimeFormat.cash(next.threshold)) faturados")
                    .font(.caption2).foregroundStyle(Noir.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("O topo da cidade é seu.").font(.caption2).foregroundStyle(Noir.muted)
            }
        }
    }

    private func heistMini(_ heist: CrimeActiveHeist) -> some View {
        let info = CrimeHeist.catalog[heist.heistID]
        return Button { openTab(.heists) } label: {
            NoirCard(tint: Noir.neon, highlighted: heist.isReady) {
                HStack(spacing: 12) {
                    Image(systemName: info.symbol).font(.title2).foregroundStyle(Noir.neon).frame(width: 36)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(heist.isReady ? "Golpe concluído! Revele o resultado" : info.name)
                            .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        if heist.isReady {
                            Text("Toque para ver se deu certo").font(.caption).foregroundStyle(Noir.muted)
                        } else {
                            NoirBar(progress: 1 - heist.remaining / info.duration, tint: Noir.neon, height: 6)
                            Text("Termina em \(CrimeFormat.duration(heist.remaining))").font(.caption).foregroundStyle(Noir.muted)
                                .monospacedDigit()
                        }
                    }
                    Image(systemName: "chevron.right").foregroundStyle(Noir.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var contracts: some View {
        NoirCard {
            HStack {
                Label("Contratos do chefe", systemImage: "scroll.fill").font(.headline)
                Spacer()
                Text("\(state.claimedContracts.count)/\(CrimeContract.catalog.count)")
                    .font(.caption.weight(.bold).monospacedDigit()).foregroundStyle(Noir.muted)
            }
            let open = Array(state.openContracts.prefix(3))
            if open.isEmpty {
                Text("Todos os contratos cumpridos. A cidade fala de você.").foregroundStyle(Noir.muted)
            }
            ForEach(open) { contract in
                let progress = state.contractProgress(contract.id)
                let ready = state.canClaimContract(contract.id)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(contract.title).font(.subheadline.weight(.semibold))
                        NoirBar(progress: progress, tint: ready ? Noir.money : Noir.gold, height: 6)
                    }
                    Button(ready ? "Receber" : "+\(Int(contract.respect))★") { store.claimContract(contract.id) }
                        .buttonStyle(NoirButtonStyle(tint: Noir.money, compact: true))
                        .disabled(!ready)
                        .accessibilityIdentifier("claim-contract-\(contract.id)")
                }
            }
        }
    }

    private var legacyTeaser: some View {
        Button { openTab(.map) } label: {
            NoirCard(tint: Noir.violet, highlighted: state.canPrestige) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark.fill")
                        .font(.title).foregroundStyle(Noir.violet)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Nova identidade: +\(CrimeFormat.short(state.claimableLegacy)) de lenda")
                            .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        Text(state.canPrestige ? "Recomece mais forte. Veja no Mapa." : "Junte \(Int(CrimeState.minimumLegacyClaim)) para poder sumir do mapa.")
                            .font(.caption).foregroundStyle(Noir.muted)
                    }
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct CrimeTapButton: View {
    let store: CrimeGameStore
    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(store.floaters) { floater in
                CrimeFloaterView(floater: floater)
            }
            Button {
                store.tapStreet()
                pulse.toggle()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Noir.ink.opacity(0.35)).frame(width: 52, height: 52)
                        Image(systemName: "hat.widebrim.fill").font(.system(size: 26, weight: .bold))
                    }
                    .scaleEffect(pulse ? 1.12 : 1)
                    .animation(.spring(response: 0.18, dampingFraction: 0.4), value: pulse)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Golpe de rua").font(.title3.weight(.heavy))
                        Text(verbatim: "+\(CrimeFormat.cash(store.state.tapValue)) por toque · 10% de bolada")
                            .font(.caption.weight(.semibold)).opacity(0.75)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6)
            }
            .buttonStyle(CrimeTapStyle())
            .accessibilityLabel("Golpe de rua")
            .accessibilityIdentifier("tap-street")
        }
    }
}

private struct CrimeTapStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Noir.ink)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [Noir.gold, Noir.ember], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .shadow(color: Noir.gold.opacity(configuration.isPressed ? 0.15 : 0.45), radius: configuration.isPressed ? 6 : 18, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

private struct CrimeFloaterView: View {
    let floater: CrimeFloater
    @State private var rise = false

    var body: some View {
        Text(floater.text)
            .font(.system(size: floater.critical ? 26 : 18, weight: .black, design: .rounded))
            .foregroundStyle(floater.critical ? Noir.neon : Noir.money)
            .shadow(color: (floater.critical ? Noir.neon : Noir.money).opacity(0.7), radius: 8)
            .offset(x: floater.drift, y: rise ? -120 : -30)
            .opacity(rise ? 0 : 1)
            .scaleEffect(rise ? (floater.critical ? 1.4 : 1.05) : 0.8)
            .allowsHitTesting(false)
            .onAppear { withAnimation(.easeOut(duration: 1.0)) { rise = true } }
            .accessibilityHidden(true)
    }
}

struct CrimeEventCard: View {
    let store: CrimeGameStore
    let event: CrimeEvent

    var body: some View {
        NoirCard(tint: Noir.cyan, highlighted: true) {
            HStack(spacing: 10) {
                Image(systemName: event.symbol)
                    .font(.title2).foregroundStyle(Noir.cyan)
                    .frame(width: 44, height: 44)
                    .background(Noir.cyan.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("NOTÍCIA DA NOITE").font(.caption2.weight(.heavy)).tracking(1.5).foregroundStyle(Noir.cyan)
                    Text(event.title).font(.headline)
                }
            }
            Text(event.story).font(.subheadline).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                ForEach(event.choices.indices, id: \.self) { index in
                    let choice = event.choices[index]
                    let cost = store.state.eventCost(choice)
                    Button { store.choose(index) } label: {
                        VStack(spacing: 2) {
                            Text(choice.title)
                            Text(cost > 0 ? "\(choice.detail) · \(CrimeFormat.cash(cost))" : choice.detail)
                                .font(.caption2.weight(.semibold)).opacity(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NoirButtonStyle(tint: index == 0 ? Noir.cyan : Color.white.opacity(0.75), compact: true))
                    .disabled(!store.state.canChoose(index))
                    .accessibilityIdentifier("event-choice-\(index)")
                }
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
}
