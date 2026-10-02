import SwiftUI

struct CrimeMapView: View {
    let store: CrimeGameStore
    @State private var confirmPrestige = false

    private var state: CrimeState { store.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NoirResourceBar(state: state)
            NoirSectionTitle(eyebrow: "Território", title: "Mapa da Neblina",
                             subtitle: "Cada bairro dominado abre negócios e golpes novos e dá +25% de lucro em tudo.")
            CrimeTerritoryMap(owned: state.districts)
                .frame(height: 230)
            ForEach(CrimeDistrict.catalog) { district in
                districtCard(district)
            }
            legacyCard
        }
        .noirPage()
        .confirmationDialog("Assumir uma nova identidade?", isPresented: $confirmPrestige, titleVisibility: .visible) {
            Button("Sumir e recomeçar (+\(CrimeFormat.short(state.claimableLegacy)) de lenda)") { store.prestige() }
        } message: {
            Text("Dinheiro, negócios, gerentes, melhorias, bairros e calor zeram. Família, contratos e lenda ficam.")
        }
    }

    private func districtCard(_ district: CrimeDistrict) -> some View {
        let isOwned = district.id < state.districts
        let isNext = district.id == state.districts
        let tint = Noir.tint(district: district.id)
        return NoirCard(tint: tint, highlighted: isNext && state.canConquer(district.id)) {
            HStack(spacing: 14) {
                Image(systemName: district.symbol)
                    .font(.title2)
                    .foregroundStyle(isOwned ? Noir.ink : tint)
                    .frame(width: 52, height: 52)
                    .background(isOwned ? tint : tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(district.name).font(.headline)
                    Text(isOwned ? "Sob seu controle" : "Controlado por \(district.rival)")
                        .font(.caption.weight(.semibold)).foregroundStyle(isOwned ? Noir.money : Noir.muted)
                    Text(district.blurb).font(.caption).foregroundStyle(Noir.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if isOwned {
                    Image(systemName: "flag.fill").foregroundStyle(tint)
                }
            }
            if isNext {
                HStack(spacing: 6) {
                    NoirChip(symbol: "dollarsign", text: CrimeFormat.short(district.cashCost), tint: state.cash >= district.cashCost ? Noir.money : Noir.muted)
                    NoirChip(symbol: "star.fill", text: CrimeFormat.short(district.respectCost), tint: state.respect >= district.respectCost ? Noir.gold : Noir.muted)
                    Spacer(minLength: 0)
                    Button("Tomar o bairro") { store.conquer(district.id) }
                        .buttonStyle(NoirButtonStyle(tint: tint, compact: true))
                        .disabled(!state.canConquer(district.id))
                        .accessibilityIdentifier("conquer-\(district.id)")
                }
            }
        }
        .opacity(isOwned || isNext ? 1 : 0.55)
    }

    private var legacyCard: some View {
        NoirCard(tint: Noir.violet, highlighted: state.canPrestige) {
            HStack(spacing: 12) {
                Image(systemName: "theatermasks.fill")
                    .font(.title)
                    .foregroundStyle(Noir.violet)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NOVA IDENTIDADE").font(.caption2.weight(.heavy)).tracking(1.5).foregroundStyle(Noir.violet)
                    Text("Lenda: \(CrimeFormat.short(state.legacy))").font(.title3.weight(.heavy))
                        .accessibilityIdentifier("legacy-total")
                }
            }
            Text(verbatim: "Cada ponto de lenda dá +\(Int(CrimeState.legacyBonus * 100))% de lucro para sempre. Bônus atual: +\(CrimeFormat.percent(state.legacy * CrimeState.legacyBonus)).")
                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Disponível agora").font(.caption).foregroundStyle(Noir.muted)
                    Text("+\(CrimeFormat.short(state.claimableLegacy))")
                        .font(.title2.weight(.heavy).monospacedDigit()).foregroundStyle(Noir.violet)
                }
                Spacer()
                Button("Sumir do mapa") { confirmPrestige = true }
                    .buttonStyle(NoirButtonStyle(tint: Noir.violet, compact: true))
                    .disabled(!state.canPrestige)
                    .accessibilityIdentifier("prestige")
            }
            Text(state.activeHeist != nil
                 ? "Espere a equipe voltar do golpe antes de sumir."
                 : "Precisa de pelo menos \(Int(CrimeState.minimumLegacyClaim)) pontos. A lenda cresce com tudo que você já faturou.")
                .font(.caption).foregroundStyle(Noir.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Mapa estilizado: cinco bairros como ilhas de neon ligadas por ruas.
struct CrimeTerritoryMap: View {
    let owned: Int

    private static let spots: [CGPoint] = [
        CGPoint(x: 0.2, y: 0.68), CGPoint(x: 0.42, y: 0.82), CGPoint(x: 0.5, y: 0.45),
        CGPoint(x: 0.76, y: 0.65), CGPoint(x: 0.8, y: 0.22)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let points = Self.spots.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }

                // Grade de ruas ao fundo.
                var grid = Path()
                for x in stride(from: CGFloat(0), through: size.width, by: 24) {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: CGFloat(0), through: size.height, by: 24) {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.04)), lineWidth: 1)

                // Rotas entre bairros.
                for index in 1..<points.count {
                    var road = Path()
                    road.move(to: points[index - 1])
                    road.addLine(to: points[index])
                    let conquered = index < owned
                    context.stroke(road, with: .color(conquered ? Noir.gold.opacity(0.7) : .white.opacity(0.15)),
                                   style: StrokeStyle(lineWidth: conquered ? 3 : 2, dash: conquered ? [] : [5, 6]))
                }

                for (index, point) in points.enumerated() {
                    let tint = Noir.tint(district: index)
                    let isOwned = index < owned
                    let isNext = index == owned
                    let radius: CGFloat = isOwned ? 22 : 17
                    if isNext {
                        let pulse = CGFloat((sin(time * 3) + 1) / 2)
                        let ringRadius: CGFloat = radius + 6 + pulse * 8
                        let ring = CGRect(x: point.x - ringRadius, y: point.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
                        context.stroke(Path(ellipseIn: ring), with: .color(tint.opacity(Double(0.6 - pulse * 0.5))), lineWidth: 2)
                    }
                    let circle = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    var glow = context
                    glow.addFilter(.shadow(color: isOwned ? tint : .clear, radius: 12))
                    glow.fill(Path(ellipseIn: circle), with: .color(isOwned ? tint : Noir.raised))
                    context.stroke(Path(ellipseIn: circle), with: .color(tint.opacity(isOwned ? 1 : 0.5)), lineWidth: 2)
                    let symbol = context.resolveSymbol(id: index)
                    if let symbol { context.draw(symbol, at: point) }
                    let label = Text(CrimeDistrict.catalog[index].name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isOwned ? Color.white : Color.white.opacity(0.5))
                    context.draw(label, at: CGPoint(x: point.x, y: point.y + radius + 11))
                }
            } symbols: {
                ForEach(CrimeDistrict.catalog) { district in
                    Image(systemName: district.id < owned ? district.symbol : "lock.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(district.id < owned ? Noir.ink : Noir.muted)
                        .tag(district.id)
                }
            }
        }
        .background(
            RadialGradient(colors: [Noir.violet.opacity(0.2), Noir.night], center: .center, startRadius: 10, endRadius: 300),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel("Mapa da cidade: \(owned) de \(CrimeDistrict.catalog.count) bairros dominados")
    }
}
