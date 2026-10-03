import SwiftUI

struct CrimeRacketsView: View {
    let store: CrimeGameStore
    @State private var mode: CrimeBuyMode = .one

    private var state: CrimeState { store.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NoirResourceBar(state: state)
            NoirSectionTitle(eyebrow: "Seu império", title: "Negócios",
                             subtitle: "Toque no ícone para rodar um ciclo. Contrate gerentes para tudo andar sozinho.")
            buyModePicker
            ForEach(visibleRackets) { racket in
                CrimeRacketCard(store: store, racket: racket, mode: mode)
            }
            blackMarket
        }
        .noirPage()
    }

    /// Mostra os negócios abertos e só o próximo bloqueado, para dar um gostinho do que vem.
    private var visibleRackets: [CrimeRacket] {
        let unlocked = CrimeRacket.catalog.filter { state.isRacketUnlocked($0.id) }
        let nextLocked = CrimeRacket.catalog.first { !state.isRacketUnlocked($0.id) }
        return unlocked + (nextLocked.map { [$0] } ?? [])
    }

    private var buyModePicker: some View {
        HStack(spacing: 6) {
            Text("Comprar").font(.caption.weight(.heavy)).foregroundStyle(Noir.muted)
            Spacer()
            ForEach(CrimeBuyMode.allCases) { option in
                Button {
                    mode = option
                    CrimeHaptics.tap()
                } label: {
                    Text(option.title)
                        .font(.footnote.weight(.heavy))
                        .frame(minWidth: 52, minHeight: 34)
                        .foregroundStyle(mode == option ? Noir.ink : .white)
                        .background(mode == option ? Noir.gold : Color.white.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("buy-mode-\(option.title)")
                .accessibilityAddTraits(mode == option ? .isSelected : [])
            }
        }
    }

    private var blackMarket: some View {
        let available = CrimeUpgrade.catalog
            .filter { !state.upgrades.contains($0.id) }
            .filter { upgrade in
                if case let .racketProfit(index) = upgrade.effect { return state.owned[index] > 0 }
                return true
            }
            .sorted { $0.cost < $1.cost }
            .prefix(5)
        return NoirCard(tint: Noir.violet) {
            HStack {
                Label("Mercado negro", systemImage: "bag.fill").font(.headline)
                Spacer()
                Text("\(state.upgrades.count)/\(CrimeUpgrade.catalog.count)")
                    .font(.caption.weight(.bold).monospacedDigit()).foregroundStyle(Noir.muted)
            }
            Text("Melhorias permanentes até a próxima identidade.").font(.caption).foregroundStyle(Noir.muted)
            if available.isEmpty {
                Text("Nada novo no mercado por enquanto.").foregroundStyle(Noir.muted)
            }
            ForEach(Array(available)) { upgrade in
                HStack(spacing: 12) {
                    Image(systemName: upgrade.symbol)
                        .foregroundStyle(Noir.violet)
                        .frame(width: 38, height: 38)
                        .background(Noir.violet.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(upgrade.name).font(.subheadline.weight(.bold))
                        Text(upgrade.detail).font(.caption).foregroundStyle(Noir.muted)
                    }
                    Spacer(minLength: 6)
                    Button(CrimeFormat.cash(upgrade.cost)) { store.buyUpgrade(upgrade.id) }
                        .buttonStyle(NoirButtonStyle(tint: Noir.violet, compact: true))
                        .disabled(!state.canBuyUpgrade(upgrade.id))
                        .accessibilityIdentifier("upgrade-\(upgrade.id)")
                }
            }
        }
    }
}

struct CrimeRacketCard: View {
    let store: CrimeGameStore
    let racket: CrimeRacket
    let mode: CrimeBuyMode

    private var state: CrimeState { store.state }
    private var tint: Color { Noir.tint(district: racket.district) }

    var body: some View {
        if state.isRacketUnlocked(racket.id) { unlocked } else { locked }
    }

    private var locked: some View {
        NoirCard(tint: .white) {
            HStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.title2).foregroundStyle(Noir.muted)
                    .frame(width: 58, height: 58)
                    .background(Color.white.opacity(0.05), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(racket.name).font(.headline).foregroundStyle(.white.opacity(0.6))
                    Text("Domine \(CrimeDistrict.catalog[racket.district].name) no Mapa para abrir.")
                        .font(.caption).foregroundStyle(Noir.muted)
                }
            }
        }
        .opacity(0.8)
    }

    private var unlocked: some View {
        let index = racket.id
        let owned = state.owned[index]
        let managed = state.managed[index]
        let cycle = state.cycleTime(index)
        let quantity = state.quantity(for: mode, racket: index)
        let cost = state.cost(racket: index, quantity: quantity)
        let idle = owned > 0 && !managed && !state.running[index]
        let continuous = managed && cycle < 0.25

        return NoirCard(tint: tint, highlighted: idle) {
            HStack(alignment: .center, spacing: 14) {
                Button { store.run(index) } label: {
                    ZStack(alignment: .bottom) {
                        Circle()
                            .fill(RadialGradient(colors: [tint.opacity(0.45), tint.opacity(0.08)], center: .center, startRadius: 2, endRadius: 34))
                            .frame(width: 62, height: 62)
                            .overlay(Circle().strokeBorder(tint.opacity(0.6), lineWidth: 1.5))
                        Image(systemName: racket.symbol)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(tint)
                            .frame(width: 62, height: 62)
                        Text("\(owned)")
                            .font(.caption2.weight(.black).monospacedDigit())
                            .foregroundStyle(Noir.ink)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(tint, in: Capsule())
                            .offset(y: 8)
                    }
                    .phaseAnimator([false, true]) { content, phase in
                        content.scaleEffect(idle && phase ? 1.06 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rodar \(racket.name)")
                .accessibilityIdentifier("run-racket-\(index)")

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(racket.name).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        if managed {
                            Image(systemName: "person.badge.clock.fill").foregroundStyle(Noir.money).font(.caption)
                                .accessibilityLabel("Gerente contratado")
                        }
                    }
                    ZStack {
                        NoirBar(progress: continuous ? 1 : state.progress[index] / cycle, tint: tint, height: 22)
                        Text(owned == 0 ? racket.flavor : (continuous ? CrimeFormat.cash(state.incomePerSecond(index)) + "/s" : CrimeFormat.cash(state.revenuePerCycle(index))))
                            .font(.caption.weight(.heavy).monospacedDigit())
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 8)
                    }
                    HStack(spacing: 6) {
                        NoirChip(symbol: "timer", text: timerText(cycle: cycle, managed: managed, continuous: continuous))
                        if let milestone = CrimeRacket.nextMilestone(after: owned) {
                            NoirChip(symbol: "flag.checkered", text: "\(milestone.count): \(milestone.label)", tint: tint)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                if owned > 0 && !managed {
                    Button { store.hire(index) } label: {
                        VStack(spacing: 1) {
                            Text("Gerente \(racket.managerName)").lineLimit(1).minimumScaleFactor(0.7)
                            Text(CrimeFormat.cash(racket.managerCost)).font(.caption2.weight(.semibold))
                        }
                    }
                    .buttonStyle(NoirButtonStyle(tint: Noir.money, compact: true))
                    .disabled(!state.canHireManager(index))
                    .accessibilityIdentifier("hire-racket-\(index)")
                }
                Button { store.buy(index, mode: mode) } label: {
                    VStack(spacing: 1) {
                        Text(owned == 0 ? "Abrir negócio" : "Comprar ×\(quantity)")
                        Text(CrimeFormat.cash(cost)).font(.caption2.weight(.semibold)).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(NoirButtonStyle(tint: tint, compact: true))
                .disabled(!state.canBuy(racket: index, quantity: quantity))
                .accessibilityLabel("Comprar \(racket.name), quantidade \(quantity)")
                .accessibilityIdentifier("buy-racket-\(index)")
            }
        }
    }

    private func timerText(cycle: Double, managed: Bool, continuous: Bool) -> String {
        if continuous { return "contínuo" }
        if state.owned[racket.id] == 0 { return CrimeFormat.duration(racket.cycle) }
        if !managed && !state.running[racket.id] { return "toque para rodar" }
        return CrimeFormat.duration(max(cycle - state.progress[racket.id], 0))
    }
}
