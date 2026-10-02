import SwiftUI

struct CrimeHeistsView: View {
    let store: CrimeGameStore
    @State private var plan: CrimeHeistPlan = .standard

    private var state: CrimeState { store.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NoirResourceBar(state: state)
            NoirSectionTitle(eyebrow: "Planos e disfarces", title: "Golpes",
                             subtitle: "Um golpe por vez. Saque grande, respeito e — se der errado — muito calor.")
            if let active = state.activeHeist { activeCard(active) }
            planPicker
            ForEach(CrimeHeist.catalog) { heist in
                heistCard(heist)
            }
        }
        .noirPage()
    }

    private func activeCard(_ active: CrimeActiveHeist) -> some View {
        let heist = CrimeHeist.catalog[active.heistID]
        let progress = 1 - active.remaining / heist.duration
        return NoirCard(tint: Noir.neon, highlighted: true) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Noir.neon, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Noir.neon.opacity(0.7), radius: 8)
                    Image(systemName: active.isReady ? "checkmark.seal.fill" : heist.symbol)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(active.isReady ? Noir.gold : .white)
                        .symbolEffect(.pulse, isActive: !active.isReady)
                }
                .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 5) {
                    Text("EM ANDAMENTO · \(active.plan.title.uppercased())")
                        .font(.caption2.weight(.heavy)).tracking(1.2).foregroundStyle(Noir.neon)
                    Text(heist.name).font(.title3.weight(.heavy))
                    Text(active.isReady ? "A equipe voltou. Deu certo?" : "Volta em \(CrimeFormat.duration(active.remaining))")
                        .font(.subheadline).foregroundStyle(Noir.muted).monospacedDigit()
                        .accessibilityIdentifier("heist-active")
                    HStack(spacing: 6) {
                        NoirChip(symbol: "percent", text: CrimeFormat.percent(active.odds), tint: Noir.cyan)
                        NoirChip(symbol: "dollarsign", text: CrimeFormat.short(active.loot), tint: Noir.money)
                    }
                }
            }
            if active.isReady {
                Button { store.revealHeist() } label: {
                    Label("Revelar resultado", systemImage: "envelope.open.fill")
                }
                .buttonStyle(NoirButtonStyle(tint: Noir.neon))
                .accessibilityIdentifier("reveal-heist")
            }
        }
    }

    private var planPicker: some View {
        NoirCard {
            Text("Estilo do plano").font(.headline)
            HStack(spacing: 8) {
                ForEach(CrimeHeistPlan.allCases) { option in
                    Button {
                        plan = option
                        CrimeHaptics.tap()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: option.symbol).font(.title3)
                            Text(option.title).font(.caption.weight(.heavy))
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .foregroundStyle(plan == option ? Noir.ink : .white)
                        .background(plan == option ? Noir.gold : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("plan-\(option.rawValue)")
                    .accessibilityAddTraits(plan == option ? .isSelected : [])
                }
            }
            Text(planDescription).font(.caption).foregroundStyle(Noir.muted)
        }
    }

    private var planDescription: String {
        switch plan {
        case .stealth: return "Ninguém vê nada: +15% de chance, 70% do saque, metade do calor."
        case .standard: return "O plano de sempre, sem surpresas."
        case .loud: return "Portas no chão: −15% de chance, saque ×1,8 e calor ×1,6."
        }
    }

    private func heistCard(_ heist: CrimeHeist) -> some View {
        let unlocked = state.isHeistUnlocked(heist.id)
        let tint = Noir.tint(district: heist.district)
        return NoirCard(tint: tint) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: unlocked ? heist.symbol : "lock.fill")
                    .font(.title2)
                    .foregroundStyle(unlocked ? tint : Noir.muted)
                    .frame(width: 50, height: 50)
                    .background((unlocked ? tint : Color.white).opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(heist.name).font(.headline)
                    Text(unlocked ? heist.briefing : "Domine \(CrimeDistrict.catalog[heist.district].name) para planejar.")
                        .font(.caption).foregroundStyle(Noir.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if unlocked {
                HStack(spacing: 6) {
                    NoirChip(symbol: "timer", text: CrimeFormat.duration(heist.duration))
                    NoirChip(symbol: "percent", text: CrimeFormat.percent(state.heistOdds(heist.id, plan: plan)), tint: Noir.cyan)
                    NoirChip(symbol: "dollarsign", text: CrimeFormat.short(state.heistLoot(heist.id, plan: plan)), tint: Noir.money)
                }
                HStack(spacing: 6) {
                    NoirChip(symbol: "star.fill", text: "+\(CrimeFormat.short(heist.respect * plan.lootMultiplier))", tint: Noir.gold)
                    NoirChip(symbol: "flame.fill", text: "+\(Int(heist.heat * plan.heatMultiplier))", tint: Noir.ember)
                    Spacer(minLength: 0)
                    Button("Executar") { store.startHeist(heist.id, plan: plan) }
                        .buttonStyle(NoirButtonStyle(tint: tint, compact: true))
                        .disabled(!state.canStartHeist(heist.id))
                        .accessibilityIdentifier("start-heist-\(heist.id)")
                }
            }
        }
        .opacity(unlocked ? 1 : 0.65)
    }
}

struct CrimeHeistOutcomeView: View {
    let outcome: CrimeHeistOutcome
    let dismiss: () -> Void
    @State private var revealed = false

    private var tint: Color { outcome.success ? (outcome.perfect ? Noir.gold : Noir.money) : Noir.neon }

    private var headline: String {
        if !outcome.success { return "DEU RUIM" }
        return outcome.perfect ? "GOLPE PERFEITO" : "SUCESSO"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
                .onTapGesture(perform: dismiss)
            VStack(spacing: 16) {
                Image(systemName: outcome.success ? (outcome.perfect ? "crown.fill" : "checkmark.seal.fill") : "light.beacon.max.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(tint)
                    .shadow(color: tint.opacity(0.8), radius: 20)
                    .scaleEffect(revealed ? 1 : 0.3)
                    .rotationEffect(.degrees(revealed ? 0 : -25))
                    .symbolEffect(.bounce, value: revealed)
                Text(headline)
                    .font(.system(size: 34, weight: .black, design: .serif))
                    .foregroundStyle(tint)
                    .accessibilityIdentifier("heist-outcome")
                Text(CrimeHeist.catalog[outcome.heistID].name).font(.headline).foregroundStyle(.white)
                Text(outcome.success ? "A equipe voltou com as malas cheias." : "Sirenes por toda a cidade. A equipe fugiu de mãos vazias.")
                    .font(.subheadline).foregroundStyle(Noir.muted).multilineTextAlignment(.center)
                VStack(spacing: 8) {
                    if outcome.success {
                        row("dollarsign.circle.fill", "Saque", "+" + CrimeFormat.cash(outcome.loot), Noir.money)
                        row("star.circle.fill", "Respeito", "+" + CrimeFormat.short(outcome.respect), Noir.gold)
                    }
                    row("flame.circle.fill", "Calor", "+\(Int(outcome.heat))", Noir.ember)
                }
                .padding(14)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Button("Continuar", action: dismiss)
                    .buttonStyle(NoirButtonStyle(tint: tint))
                    .accessibilityIdentifier("dismiss-outcome")
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(Noir.night, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(tint.opacity(0.6), lineWidth: 1.5))
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { revealed = true }
        }
    }

    private func row(_ symbol: String, _ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Label(label, systemImage: symbol).foregroundStyle(color)
            Spacer()
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(.white)
        }
    }
}
