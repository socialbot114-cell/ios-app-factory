import SwiftUI

// MARK: - Formas base

struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.18)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.18)
        )
        path.closeSubpath()
        return path
    }
}

struct AnnularSlice: Shape {
    var startDegrees: Double
    var endDegrees: Double
    /// Frações do raio (0...0.5 em relação ao lado, pois raio máximo = lado/2)
    var innerFraction: Double
    var outerFraction: Double

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let inner = side * innerFraction
        let outer = side * outerFraction
        var path = Path()
        path.addArc(center: center, radius: outer,
                    startAngle: .degrees(startDegrees), endAngle: .degrees(endDegrees), clockwise: false)
        path.addArc(center: center, radius: inner,
                    startAngle: .degrees(endDegrees), endAngle: .degrees(startDegrees), clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Botão de região (acessível, com identifiers estáveis p/ UI tests)

private struct RegionButton<Content: View>: View {
    let index: Int
    let total: Int
    let onTap: ((Int) -> Void)?
    let content: Content

    init(index: Int, total: Int, onTap: ((Int) -> Void)?, @ViewBuilder content: () -> Content) {
        self.index = index
        self.total = total
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        if let onTap {
            Button { onTap(index) } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel("Região \(index + 1) de \(total)")
                .accessibilityIdentifier("color-region-\(index)")
        } else {
            content
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Flor legada (9 regiões, idêntica ao MVP)

private struct Flower9View: View {
    var fills: [Int: Int]
    var colorFor: (Int) -> Color
    var onTap: ((Int) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle()
                    .fill(Color(red: 0.87, green: 0.78, blue: 0.60).opacity(0.32))
                    .frame(width: side * 0.57)
                ForEach(0..<9, id: \.self) { index in
                    let angle = Double(index) * 40 - 140
                    RegionButton(index: index, total: 9, onTap: onTap) {
                        PetalShape()
                            .fill(fills[index].map(colorFor) ?? .white)
                            .overlay(PetalShape().stroke(Color.black.opacity(0.82), lineWidth: 2.4))
                            .frame(width: side * 0.28, height: side * 0.46)
                            .offset(y: -side * 0.16)
                            .rotationEffect(.degrees(angle))
                            .contentShape(PetalShape())
                    }
                }
                Circle()
                    .fill(Color(red: 0.98, green: 0.78, blue: 0.35))
                    .overlay(Circle().stroke(Color.black, lineWidth: 2.4))
                    .frame(width: side * 0.22)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Mandala radial (centro + anéis fatiados)

private struct RadialMandalaView: View {
    var petals: Int
    var rings: Int
    var fills: [Int: Int]
    var colorFor: (Int) -> Color
    var onTap: ((Int) -> Void)?

    var total: Int { 1 + petals * rings }

    func regionId(ring: Int, petal: Int) -> Int { 1 + ring * petals + petal }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle()
                    .fill(Color(red: 0.87, green: 0.78, blue: 0.60).opacity(0.25))
                    .frame(width: side * 0.98)
                // Anéis (de fora para dentro p/ o centro ficar por cima)
                ForEach((0..<rings).reversed(), id: \.self) { ring in
                    let step = (0.48 - 0.11) / Double(rings)
                    let inner = 0.11 + Double(ring) * step
                    let outer = 0.11 + Double(ring + 1) * step
                    ForEach(0..<petals, id: \.self) { petal in
                        // desloca meio passo por anel p/ efeito trançado
                        let offset = Double(ring) * (360.0 / Double(petals) / 2.0)
                        let a0 = Double(petal) * 360.0 / Double(petals) - 90 + offset
                        let a1 = Double(petal + 1) * 360.0 / Double(petals) - 90 + offset
                        let id = regionId(ring: ring, petal: petal)
                        RegionButton(index: id, total: total, onTap: onTap) {
                            AnnularSlice(startDegrees: a0, endDegrees: a1, innerFraction: inner, outerFraction: outer)
                                .fill(fills[id].map(colorFor) ?? .white)
                                .overlay(AnnularSlice(startDegrees: a0, endDegrees: a1, innerFraction: inner, outerFraction: outer)
                                    .stroke(Color.black.opacity(0.8), lineWidth: max(1, 2.4 - Double(ring) * 0.25)))
                        }
                    }
                }
                RegionButton(index: 0, total: total, onTap: onTap) {
                    Circle()
                        .fill(fills[0].map(colorFor) ?? Color(red: 0.98, green: 0.78, blue: 0.35))
                        .overlay(Circle().stroke(Color.black, lineWidth: 2.2))
                        .frame(width: side * 0.22)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Mosaico (grade)

private struct MosaicView: View {
    var rows: Int
    var cols: Int
    var fills: [Int: Int]
    var colorFor: (Int) -> Color
    var onTap: ((Int) -> Void)?

    var total: Int { rows * cols }

    var body: some View {
        GeometryReader { geometry in
            let gap: CGFloat = 5
            let side = min(geometry.size.width, geometry.size.height)
            let cellW = (side - gap * CGFloat(cols - 1)) / CGFloat(cols)
            let cellH = (side - gap * CGFloat(rows - 1)) / CGFloat(rows)
            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<cols, id: \.self) { col in
                            let id = row * cols + col
                            RegionButton(index: id, total: total, onTap: onTap) {
                                RoundedRectangle(cornerRadius: min(cellW, cellH) * 0.24, style: .continuous)
                                    .fill(fills[id].map(colorFor) ?? .white)
                                    .overlay(RoundedRectangle(cornerRadius: min(cellW, cellH) * 0.24, style: .continuous)
                                        .stroke(Color.black.opacity(0.8), lineWidth: 2))
                                    .frame(width: cellW, height: cellH)
                            }
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Sol (centro + raios + colinas)

private struct SunburstView: View {
    var rays: Int
    var fills: [Int: Int]
    var colorFor: (Int) -> Color
    var onTap: ((Int) -> Void)?

    var total: Int { rays + 3 }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                // colinas (últimas 2 regiões)
                RegionButton(index: rays + 1, total: total, onTap: onTap) {
                    Ellipse()
                        .fill(fills[rays + 1].map(colorFor) ?? .white)
                        .overlay(Ellipse().stroke(Color.black.opacity(0.8), lineWidth: 2.2))
                        .frame(width: side * 0.9, height: side * 0.5)
                        .offset(x: -side * 0.22, y: side * 0.3)
                }
                RegionButton(index: rays + 2, total: total, onTap: onTap) {
                    Ellipse()
                        .fill(fills[rays + 2].map(colorFor) ?? .white)
                        .overlay(Ellipse().stroke(Color.black.opacity(0.8), lineWidth: 2.2))
                        .frame(width: side * 0.9, height: side * 0.5)
                        .offset(x: side * 0.22, y: side * 0.32)
                }
                ForEach(0..<rays, id: \.self) { i in
                    let angle = Double(i) * 360.0 / Double(rays)
                    RegionButton(index: 1 + i, total: total, onTap: onTap) {
                        PetalShape()
                            .fill(fills[1 + i].map(colorFor) ?? .white)
                            .overlay(PetalShape().stroke(Color.black.opacity(0.8), lineWidth: 2.2))
                            .frame(width: side * 0.16, height: side * 0.3)
                            .offset(y: -side * 0.26)
                            .rotationEffect(.degrees(angle))
                            .contentShape(PetalShape())
                    }
                }
                RegionButton(index: 0, total: total, onTap: onTap) {
                    ZStack {
                        Circle()
                            .fill(fills[0].map(colorFor) ?? Color(red: 0.98, green: 0.78, blue: 0.35))
                            .overlay(Circle().stroke(Color.black, lineWidth: 2.4))
                            .frame(width: side * 0.34)
                        HStack(spacing: side * 0.06) {
                            Circle().fill(Color.black).frame(width: side * 0.025)
                            Circle().fill(Color.black).frame(width: side * 0.025)
                        }.offset(y: -side * 0.03)
                        Path { p in
                            p.move(to: CGPoint(x: -side * 0.06, y: side * 0.04))
                            p.addQuadCurve(to: CGPoint(x: side * 0.06, y: side * 0.04), control: CGPoint(x: 0, y: side * 0.10))
                        }
                        .stroke(Color.black, lineWidth: 2.4)
                        .frame(width: side * 0.12, height: side * 0.10)
                        .offset(y: side * 0.02)
                    }.frame(width: side * 0.34, height: side * 0.34)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Canvas genérico

struct AtelierCanvas: View {
    var artwork: AtelierArtwork
    var fills: [Int: Int]
    var customs: [Color] = []
    var onTap: ((Int) -> Void)? = nil

    func colorFor(_ index: Int) -> Color {
        if customs.isEmpty {
            return AtelierPalette.color(for: index, custom: AtelierPalette.defaultCustom)
        }
        return AtelierPalette.color(for: index, customs: customs)
    }

    var body: some View {
        switch artwork.kind {
        case .flower9:
            Flower9View(fills: fills, colorFor: colorFor, onTap: onTap)
        case .sunburst8:
            SunburstView(rays: 8, fills: fills, colorFor: colorFor, onTap: onTap)
        case .mosaic44:
            FishView(fills: fills, colorFor: colorFor, onTap: onTap)
        case .mosaic36:
            CatView(fills: fills, colorFor: colorFor, onTap: onTap)
        case .mosaic28:
            RocketView(fills: fills, colorFor: colorFor, onTap: onTap)
        case .radial10x2:
            ButterflyView(fills: fills, colorFor: colorFor, onTap: onTap)
        case .radial16x3:
            RadialMandalaView(petals: 16, rings: 3, fills: fills, colorFor: colorFor, onTap: onTap)
        case .radial12x5:
            RadialMandalaView(petals: 12, rings: 5, fills: fills, colorFor: colorFor, onTap: onTap)
        case .radial8x5:
            IpeView(fills: fills, colorFor: colorFor, onTap: onTap)
        case .mosaic67:
            AraraView(fills: fills, colorFor: colorFor, onTap: onTap)
        case .mosaic66:
            CatedralView(fills: fills, colorFor: colorFor, onTap: onTap)
        case .radial13x4:
            RadialMandalaView(petals: 13, rings: 4, fills: fills, colorFor: colorFor, onTap: onTap)
        }
    }
}

// MARK: - Compat: nome antigo usado pelo MVP

struct ColoringArtwork: View {
    var fills: [Int: Int]
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        AtelierCanvas(
            artwork: AtelierLibrary.artwork(id: "jardim-tracos"),
            fills: fills,
            onTap: onTap
        )
    }
}
