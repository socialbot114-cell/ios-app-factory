import SwiftUI

// MARK: - Ilustrações dedicadas (traço próprio; contagens preservadas)

// Cada view recebe fills + colorFor + onTap no mesmo padrão do canvas.
// IDs documentados por região para manter compat com sessões salvas.

private struct RB<Content: View>: View {
    let index: Int
    let total: Int
    let onTap: ((Int) -> Void)?
    let content: Content

    init(_ index: Int, total: Int, onTap: ((Int) -> Void)?, @ViewBuilder content: () -> Content) {
        self.index = index; self.total = total; self.onTap = onTap; self.content = content()
    }

    var body: some View {
        if let onTap {
            Button { onTap(index) } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel("Região \(index + 1) de \(total)")
                .accessibilityIdentifier("color-region-\(index)")
        } else {
            content.accessibilityHidden(true)
        }
    }
}

private struct Outlined<S: Shape>: View {
    var shape: S
    var fill: Color
    var line: CGFloat = 2.2

    var body: some View {
        shape.fill(fill).overlay(shape.stroke(Color.black.opacity(0.82), lineWidth: line))
    }
}

// MARK: Peixinho e bolhas — 16 regiões
// 0-3 corpo · 4 cabeça · 5 olho · 6-7 cauda · 8-9 barbatanas · 10-12 bolhas · 13-14 algas · 15 fundo do mar

struct FishView: View {
    var fills: [Int: Int]
    var colorFor: (Int) -> Color
    var onTap: ((Int) -> Void)?

    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.08).fill(Color(red: 0.80, green: 0.92, blue: 0.98).opacity(0.5))
                // fundo do mar
                RB(15, total: 16, onTap: onTap) {
                    Outlined(shape: Ellipse(), fill: fills[15].map(colorFor) ?? .white)
                        .frame(width: s * 1.0, height: s * 0.22)
                        .offset(y: s * 0.38)
                }
                // algas
                RB(13, total: 16, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[13].map(colorFor) ?? .white)
                        .frame(width: s * 0.07, height: s * 0.42).offset(x: -s * 0.38, y: s * 0.14)
                }
                RB(14, total: 16, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[14].map(colorFor) ?? .white)
                        .frame(width: s * 0.07, height: s * 0.32).offset(x: s * 0.40, y: s * 0.18)
                }
                // cauda
                RB(6, total: 16, onTap: onTap) {
                    Outlined(shape: Triangle(), fill: fills[6].map(colorFor) ?? .white)
                        .frame(width: s * 0.20, height: s * 0.16).offset(x: s * 0.28, y: -s * 0.10)
                }
                RB(7, total: 16, onTap: onTap) {
                    Outlined(shape: Triangle(), fill: fills[7].map(colorFor) ?? .white)
                        .frame(width: s * 0.20, height: s * 0.16).offset(x: s * 0.28, y: s * 0.06).rotationEffect(.degrees(180)).offset(x: 0, y: -s * 0.02)
                }
                // corpo em 4 faixas
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in
                        RB(i, total: 16, onTap: onTap) {
                            Rectangle().fill(fills[i].map(colorFor) ?? .white)
                                .frame(width: s * 0.52, height: s * 0.085)
                        }
                    }
                }
                .clipShape(Ellipse())
                .overlay(Ellipse().stroke(Color.black.opacity(0.82), lineWidth: 2.4))
                .frame(width: s * 0.52, height: s * 0.34)
                .offset(x: -s * 0.05)
                // cabeça + olho
                RB(4, total: 16, onTap: onTap) {
                    Outlined(shape: Circle(), fill: fills[4].map(colorFor) ?? .white)
                        .frame(width: s * 0.20).offset(x: -s * 0.28, y: -s * 0.01)
                }
                RB(5, total: 16, onTap: onTap) {
                    Circle().fill(fills[5].map(colorFor) ?? Color(red: 0.20, green: 0.20, blue: 0.22))
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        .frame(width: s * 0.07).offset(x: -s * 0.30, y: -s * 0.04)
                }
                // barbatanas
                RB(8, total: 16, onTap: onTap) {
                    Outlined(shape: Triangle(), fill: fills[8].map(colorFor) ?? .white)
                        .frame(width: s * 0.12, height: s * 0.10).offset(x: -s * 0.05, y: -s * 0.22)
                }
                RB(9, total: 16, onTap: onTap) {
                    Outlined(shape: Triangle(), fill: fills[9].map(colorFor) ?? .white)
                        .frame(width: s * 0.12, height: s * 0.10).offset(x: -s * 0.05, y: s * 0.20).rotationEffect(.degrees(180))
                }
                // bolhas
                ForEach(0..<3, id: \.self) { i in
                    RB(10 + i, total: 16, onTap: onTap) {
                        Outlined(shape: Circle(), fill: fills[10 + i].map(colorFor) ?? .white, line: 2)
                            .frame(width: s * (0.09 - CGFloat(i) * 0.015))
                            .offset(x: -s * (0.05 - CGFloat(i) * 0.10), y: -s * (0.30 + CGFloat(i) * 0.05))
                    }
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: Gatinho listrado — 18 regiões
// 0 cabeça · 1-2 orelhas · 3 corpo · 4 rabo · 5 barriga · 6-9 listras · 10 focinho · 11 nariz · 12-13 patas · 14 sol · 15 nuvem · 16-17 grama

struct CatView: View {
    var fills: [Int: Int]
    var colorFor: (Int) -> Color
    var onTap: ((Int) -> Void)?

    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                RB(14, total: 18, onTap: onTap) {
                    Outlined(shape: Circle(), fill: fills[14].map(colorFor) ?? Color(red: 0.98, green: 0.78, blue: 0.35))
                        .frame(width: s * 0.18).offset(x: -s * 0.34, y: -s * 0.34)
                }
                RB(15, total: 18, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[15].map(colorFor) ?? .white)
                        .frame(width: s * 0.24, height: s * 0.10).offset(x: s * 0.30, y: -s * 0.34)
                }
                RB(16, total: 18, onTap: onTap) {
                    Outlined(shape: Ellipse(), fill: fills[16].map(colorFor) ?? .white)
                        .frame(width: s * 0.5, height: s * 0.24).offset(x: -s * 0.24, y: s * 0.36)
                }
                RB(17, total: 18, onTap: onTap) {
                    Outlined(shape: Ellipse(), fill: fills[17].map(colorFor) ?? .white)
                        .frame(width: s * 0.5, height: s * 0.24).offset(x: s * 0.24, y: s * 0.37)
                }
                // rabo
                RB(4, total: 18, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[4].map(colorFor) ?? .white)
                        .frame(width: s * 0.10, height: s * 0.34)
                        .rotationEffect(.degrees(-35)).offset(x: s * 0.30, y: s * 0.10)
                }
                // corpo + barriga
                RB(3, total: 18, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: s * 0.12, style: .continuous), fill: fills[3].map(colorFor) ?? .white)
                        .frame(width: s * 0.42, height: s * 0.40).offset(x: s * 0.10, y: s * 0.12)
                }
                RB(5, total: 18, onTap: onTap) {
                    Outlined(shape: Ellipse(), fill: fills[5].map(colorFor) ?? .white)
                        .frame(width: s * 0.24, height: s * 0.26).offset(x: s * 0.10, y: s * 0.16)
                }
                // patas
                RB(12, total: 18, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[12].map(colorFor) ?? .white)
                        .frame(width: s * 0.11, height: s * 0.16).offset(x: s * 0.02, y: s * 0.30)
                }
                RB(13, total: 18, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[13].map(colorFor) ?? .white)
                        .frame(width: s * 0.11, height: s * 0.16).offset(x: s * 0.20, y: s * 0.30)
                }
                // listras do corpo
                ForEach(0..<4, id: \.self) { i in
                    RB(6 + i, total: 18, onTap: onTap) {
                        Outlined(shape: RoundedRectangle(cornerRadius: 4, style: .continuous), fill: fills[6 + i].map(colorFor) ?? .white, line: 1.8)
                            .frame(width: s * 0.30, height: s * 0.045)
                            .offset(x: s * 0.10, y: s * (0.02 + CGFloat(i) * 0.07))
                    }
                }
                // orelhas
                RB(1, total: 18, onTap: onTap) {
                    Outlined(shape: Triangle(), fill: fills[1].map(colorFor) ?? .white)
                        .frame(width: s * 0.16, height: s * 0.16).offset(x: -s * 0.22, y: -s * 0.30).rotationEffect(.degrees(-18))
                }
                RB(2, total: 18, onTap: onTap) {
                    Outlined(shape: Triangle(), fill: fills[2].map(colorFor) ?? .white)
                        .frame(width: s * 0.16, height: s * 0.16).offset(x: -s * 0.02, y: -s * 0.30).rotationEffect(.degrees(18))
                }
                // cabeça + focinho + nariz (olhos decorativos)
                RB(0, total: 18, onTap: onTap) {
                    ZStack {
                        Outlined(shape: Circle(), fill: fills[0].map(colorFor) ?? .white)
                            .frame(width: s * 0.34)
                        HStack(spacing: s * 0.10) {
                            Circle().fill(Color.black).frame(width: s * 0.03)
                            Circle().fill(Color.black).frame(width: s * 0.03)
                        }.offset(y: -s * 0.03)
                    }.frame(width: s * 0.34, height: s * 0.34)
                        .offset(x: -s * 0.12, y: -s * 0.16)
                }
                RB(10, total: 18, onTap: onTap) {
                    Outlined(shape: Ellipse(), fill: fills[10].map(colorFor) ?? .white)
                        .frame(width: s * 0.16, height: s * 0.10).offset(x: -s * 0.12, y: -s * 0.06)
                }
                RB(11, total: 18, onTap: onTap) {
                    Outlined(shape: Triangle(), fill: fills[11].map(colorFor) ?? Color(red: 0.94, green: 0.42, blue: 0.62), line: 1.8)
                        .frame(width: s * 0.05, height: s * 0.04).offset(x: -s * 0.12, y: -s * 0.075).rotationEffect(.degrees(180))
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: Foguete espacial — 16 regiões
// 0 ponta · 1 janela · 2-3 corpo · 4-5 aletas · 6-7 chama · 8-13 estrelas · 14 planeta · 15 lua

struct RocketView: View {
    var fills: [Int: Int]
    var colorFor: (Int) -> Color
    var onTap: ((Int) -> Void)?

    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                Color(red: 0.12, green: 0.14, blue: 0.28).opacity(0.12)
                ForEach(0..<6, id: \.self) { i in
                    RB(8 + i, total: 16, onTap: onTap) {
                        Outlined(shape: Star(corners: 5), fill: fills[8 + i].map(colorFor) ?? .white, line: 1.6)
                            .frame(width: s * 0.09)
                            .offset(x: s * (i % 2 == 0 ? -0.36 : 0.36), y: s * (-0.34 + CGFloat(i) * 0.12))
                    }
                }
                RB(14, total: 16, onTap: onTap) {
                    Outlined(shape: Circle(), fill: fills[14].map(colorFor) ?? .white)
                        .frame(width: s * 0.20).offset(x: s * 0.32, y: s * 0.32)
                }
                RB(15, total: 16, onTap: onTap) {
                    Outlined(shape: Circle(), fill: fills[15].map(colorFor) ?? .white)
                        .frame(width: s * 0.14).offset(x: -s * 0.36, y: s * 0.34)
                }
                // chama
                RB(6, total: 16, onTap: onTap) {
                    Outlined(shape: Flame(), fill: fills[6].map(colorFor) ?? Color(red: 0.98, green: 0.57, blue: 0.32))
                        .frame(width: s * 0.16, height: s * 0.22).offset(y: s * 0.32)
                }
                RB(7, total: 16, onTap: onTap) {
                    Outlined(shape: Flame(), fill: fills[7].map(colorFor) ?? Color(red: 0.98, green: 0.75, blue: 0.28))
                        .frame(width: s * 0.09, height: s * 0.13).offset(y: s * 0.29)
                }
                // aletas
                RB(4, total: 16, onTap: onTap) {
                    Outlined(shape: Triangle(), fill: fills[4].map(colorFor) ?? .white)
                        .frame(width: s * 0.12, height: s * 0.20).offset(x: -s * 0.15, y: s * 0.12).rotationEffect(.degrees(180))
                }
                RB(5, total: 16, onTap: onTap) {
                    Outlined(shape: Triangle(), fill: fills[5].map(colorFor) ?? .white)
                        .frame(width: s * 0.12, height: s * 0.20).offset(x: s * 0.15, y: s * 0.12)
                }
                // corpo
                RB(2, total: 16, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: s * 0.05, style: .continuous), fill: fills[2].map(colorFor) ?? .white)
                        .frame(width: s * 0.22, height: s * 0.22).offset(y: -s * 0.02)
                }
                RB(3, total: 16, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: s * 0.05, style: .continuous), fill: fills[3].map(colorFor) ?? .white)
                        .frame(width: s * 0.22, height: s * 0.16).offset(y: s * 0.16)
                }
                RB(1, total: 16, onTap: onTap) {
                    Outlined(shape: Circle(), fill: fills[1].map(colorFor) ?? Color(red: 0.32, green: 0.62, blue: 0.94))
                        .frame(width: s * 0.11).offset(y: -s * 0.02)
                }
                RB(0, total: 16, onTap: onTap) {
                    Outlined(shape: NoseCone(), fill: fills[0].map(colorFor) ?? Color(red: 0.99, green: 0.42, blue: 0.33))
                        .frame(width: s * 0.22, height: s * 0.18).offset(y: -s * 0.22)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct Star: Shape {
    var corners: Int = 5
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<(corners * 2) {
            let rad = Double(i) * .pi / Double(corners) - .pi / 2
            let rr = i % 2 == 0 ? r : r * 0.45
            let pt = CGPoint(x: c.x + CGFloat(cos(rad)) * rr, y: c.y + CGFloat(sin(rad)) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

private struct Flame: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.2))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.midX - rect.width * 0.15, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX + rect.width * 0.15, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.2))
        p.closeSubpath()
        return p
    }
}

private struct NoseCone: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.35))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.35))
        p.closeSubpath()
        return p
    }
}

// MARK: Borboleta do jardim — 21 regiões
// 0-3 asa sup esq · 4-7 asa sup dir · 8-10 asa inf esq · 11-13 asa inf dir · 14 corpo · 15 cabeça · 16-17 antenas · 18-20 flores

struct ButterflyView: View {
    var fills: [Int: Int]
    var colorFor: (Int) -> Color
    var onTap: ((Int) -> Void)?

    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    RB(18 + i, total: 21, onTap: onTap) {
                        Outlined(shape: Circle(), fill: fills[18 + i].map(colorFor) ?? .white, line: 2)
                            .frame(width: s * 0.11)
                            .offset(x: s * (-0.34 + CGFloat(i) * 0.34), y: s * 0.38)
                    }
                }
                // asas superiores 2x2
                ForEach(0..<4, id: \.self) { i in
                    let row = i / 2, col = i % 2
                    RB(i, total: 21, onTap: onTap) {
                        Outlined(shape: RoundedRectangle(cornerRadius: s * 0.06, style: .continuous), fill: fills[i].map(colorFor) ?? .white)
                            .frame(width: s * 0.15, height: s * 0.17)
                            .offset(x: -s * 0.20 + CGFloat(col) * s * 0.155, y: -s * 0.20 + CGFloat(row) * s * 0.175)
                            .rotationEffect(.degrees(-18))
                    }
                    RB(4 + i, total: 21, onTap: onTap) {
                        Outlined(shape: RoundedRectangle(cornerRadius: s * 0.06, style: .continuous), fill: fills[4 + i].map(colorFor) ?? .white)
                            .frame(width: s * 0.15, height: s * 0.17)
                            .offset(x: s * 0.045 + CGFloat(col) * s * 0.155, y: -s * 0.20 + CGFloat(row) * s * 0.175)
                            .rotationEffect(.degrees(18))
                    }
                }
                // asas inferiores (fileira de 3 de cada lado)
                ForEach(0..<3, id: \.self) { i in
                    RB(8 + i, total: 21, onTap: onTap) {
                        Outlined(shape: Ellipse(), fill: fills[8 + i].map(colorFor) ?? .white)
                            .frame(width: s * 0.13, height: s * 0.12)
                            .offset(x: -s * 0.20 + CGFloat(i) * 0.02, y: s * (0.06 + CGFloat(i) * 0.10))
                            .rotationEffect(.degrees(-14))
                    }
                    RB(11 + i, total: 21, onTap: onTap) {
                        Outlined(shape: Ellipse(), fill: fills[11 + i].map(colorFor) ?? .white)
                            .frame(width: s * 0.13, height: s * 0.12)
                            .offset(x: s * 0.20 - CGFloat(i) * 0.02, y: s * (0.06 + CGFloat(i) * 0.10))
                            .rotationEffect(.degrees(14))
                    }
                }
                // antenas
                RB(16, total: 21, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[16].map(colorFor) ?? .white, line: 1.8)
                        .frame(width: s * 0.03, height: s * 0.16).rotationEffect(.degrees(-24)).offset(x: -s * 0.05, y: -s * 0.24)
                }
                RB(17, total: 21, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[17].map(colorFor) ?? .white, line: 1.8)
                        .frame(width: s * 0.03, height: s * 0.16).rotationEffect(.degrees(24)).offset(x: s * 0.05, y: -s * 0.24)
                }
                RB(15, total: 21, onTap: onTap) {
                    Outlined(shape: Circle(), fill: fills[15].map(colorFor) ?? .white)
                        .frame(width: s * 0.10).offset(y: -s * 0.15)
                }
                RB(14, total: 21, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[14].map(colorFor) ?? .white)
                        .frame(width: s * 0.09, height: s * 0.34).offset(y: s * 0.06)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: Ipê-amarelo — 41 regiões
// 0-32 copa (radial 8x4) · 33-35 tronco · 36-37 colinas · 38 sol · 39-40 nuvens

struct IpeView: View {
    var fills: [Int: Int]
    var colorFor: (Int) -> Color
    var onTap: ((Int) -> Void)?

    var canopyFills: [Int: Int] { fills.filter { $0.key < 33 } }

    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                RB(36, total: 41, onTap: onTap) {
                    Outlined(shape: Ellipse(), fill: fills[36].map(colorFor) ?? .white)
                        .frame(width: s * 0.9, height: s * 0.4).offset(x: -s * 0.2, y: s * 0.36)
                }
                RB(37, total: 41, onTap: onTap) {
                    Outlined(shape: Ellipse(), fill: fills[37].map(colorFor) ?? .white)
                        .frame(width: s * 0.9, height: s * 0.4).offset(x: s * 0.2, y: s * 0.38)
                }
                RB(38, total: 41, onTap: onTap) {
                    Outlined(shape: Circle(), fill: fills[38].map(colorFor) ?? Color(red: 0.98, green: 0.75, blue: 0.28))
                        .frame(width: s * 0.14).offset(x: -s * 0.36, y: -s * 0.36)
                }
                RB(39, total: 41, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[39].map(colorFor) ?? .white, line: 2)
                        .frame(width: s * 0.20, height: s * 0.08).offset(x: s * 0.28, y: -s * 0.38)
                }
                RB(40, total: 41, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[40].map(colorFor) ?? .white, line: 2)
                        .frame(width: s * 0.14, height: s * 0.07).offset(x: s * 0.36, y: -s * 0.30)
                }
                VStack(spacing: 3) {
                    ForEach([33, 34, 35], id: \.self) { id in
                        RB(id, total: 41, onTap: onTap) {
                            Outlined(shape: RoundedRectangle(cornerRadius: 5, style: .continuous), fill: fills[id].map(colorFor) ?? .white)
                                .frame(width: s * 0.09, height: s * 0.13)
                        }
                    }
                }.offset(y: s * 0.20)
                RadialMandalaHost(petals: 8, rings: 4, fills: canopyFills, colorFor: colorFor, onTap: onTap, total: 41)
                    .frame(width: s * 0.72, height: s * 0.72)
                    .offset(y: -s * 0.12)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: Arara do Planalto — 42 regiões
// 0 cabeça · 1-2 bico · 3 pescoço · 4-7 peito · 8-19 asa (3x4) · 20-25 cauda · 26-27 poleiro · 28-33 folhas · 34-37 flores · 38 sol · 39-40 nuvens · 41 chão

struct AraraView: View {
    var fills: [Int: Int]
    var colorFor: (Int) -> Color
    var onTap: ((Int) -> Void)?

    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                RB(38, total: 42, onTap: onTap) {
                    Outlined(shape: Circle(), fill: fills[38].map(colorFor) ?? Color(red: 0.98, green: 0.75, blue: 0.28))
                        .frame(width: s * 0.13).offset(x: -s * 0.37, y: -s * 0.37)
                }
                RB(39, total: 42, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[39].map(colorFor) ?? .white, line: 2)
                        .frame(width: s * 0.18, height: s * 0.07).offset(x: s * 0.30, y: -s * 0.38)
                }
                RB(40, total: 42, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[40].map(colorFor) ?? .white, line: 2)
                        .frame(width: s * 0.12, height: s * 0.06).offset(x: s * 0.36, y: -s * 0.30)
                }
                RB(41, total: 42, onTap: onTap) {
                    Outlined(shape: Ellipse(), fill: fills[41].map(colorFor) ?? .white)
                        .frame(width: s * 1.0, height: s * 0.18).offset(y: s * 0.40)
                }
                // folhas e flores do galho
                ForEach(0..<6, id: \.self) { i in
                    RB(28 + i, total: 42, onTap: onTap) {
                        Outlined(shape: Ellipse(), fill: fills[28 + i].map(colorFor) ?? .white, line: 1.8)
                            .frame(width: s * 0.10, height: s * 0.07)
                            .rotationEffect(.degrees(Double(i) * 30 - 60))
                            .offset(x: s * (-0.34 + CGFloat(i % 3) * 0.34), y: s * 0.16)
                    }
                }
                ForEach(0..<4, id: \.self) { i in
                    RB(34 + i, total: 42, onTap: onTap) {
                        Outlined(shape: Circle(), fill: fills[34 + i].map(colorFor) ?? .white, line: 1.8)
                            .frame(width: s * 0.06)
                            .offset(x: s * (-0.30 + CGFloat(i) * 0.20), y: s * 0.08)
                    }
                }
                // poleiro
                RB(26, total: 42, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: 5, style: .continuous), fill: fills[26].map(colorFor) ?? .white)
                        .frame(width: s * 0.80, height: s * 0.045).offset(y: s * 0.24)
                }
                RB(27, total: 42, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: 5, style: .continuous), fill: fills[27].map(colorFor) ?? .white)
                        .frame(width: s * 0.05, height: s * 0.18).offset(x: s * 0.28, y: s * 0.33)
                }
                // cauda em leque
                ForEach(0..<6, id: \.self) { i in
                    RB(20 + i, total: 42, onTap: onTap) {
                        Outlined(shape: Capsule(), fill: fills[20 + i].map(colorFor) ?? .white)
                            .frame(width: s * 0.055, height: s * 0.30)
                            .rotationEffect(.degrees(Double(i) * 12 - 30))
                            .offset(x: -s * 0.16, y: s * 0.02)
                    }
                }
                // peito em faixas
                VStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { i in
                        RB(4 + i, total: 42, onTap: onTap) {
                            Rectangle().fill(fills[4 + i].map(colorFor) ?? .white)
                                .frame(width: s * 0.20, height: s * 0.07)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: s * 0.08, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: s * 0.08, style: .continuous).stroke(Color.black.opacity(0.82), lineWidth: 2.2))
                .frame(width: s * 0.20, height: s * 0.30)
                .offset(x: -s * 0.02, y: -s * 0.06)
                // asa 3x4
                VStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { col in
                                let id = 8 + row * 3 + col
                                RB(id, total: 42, onTap: onTap) {
                                    Outlined(shape: RoundedRectangle(cornerRadius: 4, style: .continuous), fill: fills[id].map(colorFor) ?? .white, line: 1.6)
                                        .frame(width: s * 0.075, height: s * 0.06)
                                }
                            }
                        }
                    }
                }.offset(x: s * 0.16, y: -s * 0.04)
                RB(3, total: 42, onTap: onTap) {
                    Outlined(shape: Capsule(), fill: fills[3].map(colorFor) ?? .white)
                        .frame(width: s * 0.12, height: s * 0.10).offset(x: -s * 0.02, y: -s * 0.25)
                }
                // cabeça + bico
                RB(0, total: 42, onTap: onTap) {
                    ZStack {
                        Outlined(shape: Circle(), fill: fills[0].map(colorFor) ?? .white).frame(width: s * 0.17)
                        Circle().fill(Color.black).frame(width: s * 0.025).offset(x: -s * 0.02, y: -s * 0.01)
                    }.frame(width: s * 0.17, height: s * 0.17).offset(x: -s * 0.04, y: -s * 0.33)
                }
                RB(1, total: 42, onTap: onTap) {
                    Outlined(shape: NoseCone(), fill: fills[1].map(colorFor) ?? .white)
                        .frame(width: s * 0.09, height: s * 0.10).offset(x: -s * 0.15, y: -s * 0.31).rotationEffect(.degrees(-90))
                }
                RB(2, total: 42, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: 4, style: .continuous), fill: fills[2].map(colorFor) ?? .white, line: 1.8)
                        .frame(width: s * 0.07, height: s * 0.04).offset(x: -s * 0.14, y: -s * 0.24)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: Catedral em vitral — 36 regiões
// 0-15 vitrais (4x4) · 16-19 arcos · 20-21 torre · 22-23 portas · 24-25 escada · 26 sol · 27-29 nuvens · 30-31 árvores · 32-33 caminho · 34 bandeira · 35 cruz

struct CatedralView: View {
    var fills: [Int: Int]
    var colorFor: (Int) -> Color
    var onTap: ((Int) -> Void)?

    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                RB(26, total: 36, onTap: onTap) {
                    Outlined(shape: Circle(), fill: fills[26].map(colorFor) ?? Color(red: 0.98, green: 0.75, blue: 0.28))
                        .frame(width: s * 0.13).offset(x: -s * 0.37, y: -s * 0.37)
                }
                ForEach(0..<3, id: \.self) { i in
                    RB(27 + i, total: 36, onTap: onTap) {
                        Outlined(shape: Capsule(), fill: fills[27 + i].map(colorFor) ?? .white, line: 1.8)
                            .frame(width: s * (0.18 - CGFloat(i) * 0.03), height: s * 0.07)
                            .offset(x: s * (0.26 + CGFloat(i) * 0.04), y: s * (-0.38 + CGFloat(i) * 0.09))
                    }
                }
                RB(30, total: 36, onTap: onTap) {
                    Outlined(shape: Circle(), fill: fills[30].map(colorFor) ?? .white)
                        .frame(width: s * 0.13).offset(x: -s * 0.38, y: s * 0.22)
                }
                RB(31, total: 36, onTap: onTap) {
                    Outlined(shape: Circle(), fill: fills[31].map(colorFor) ?? .white)
                        .frame(width: s * 0.13).offset(x: s * 0.38, y: s * 0.22)
                }
                // caminho + escada
                RB(32, total: 36, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: 4, style: .continuous), fill: fills[32].map(colorFor) ?? .white, line: 1.8)
                        .frame(width: s * 0.20, height: s * 0.16).offset(y: s * 0.36)
                }
                RB(33, total: 36, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: 4, style: .continuous), fill: fills[33].map(colorFor) ?? .white, line: 1.8)
                        .frame(width: s * 0.30, height: s * 0.05).offset(y: s * 0.27)
                }
                RB(24, total: 36, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: 4, style: .continuous), fill: fills[24].map(colorFor) ?? .white, line: 1.8)
                        .frame(width: s * 0.26, height: s * 0.045).offset(y: s * 0.225)
                }
                RB(25, total: 36, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: 4, style: .continuous), fill: fills[25].map(colorFor) ?? .white, line: 1.8)
                        .frame(width: s * 0.22, height: s * 0.045).offset(y: s * 0.18)
                }
                // corpo + vitrais 4x4
                VStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: 3) {
                            ForEach(0..<4, id: \.self) { col in
                                let id = row * 4 + col
                                RB(id, total: 36, onTap: onTap) {
                                    Outlined(shape: RoundedRectangle(cornerRadius: 3, style: .continuous), fill: fills[id].map(colorFor) ?? .white, line: 1.6)
                                        .frame(width: s * 0.10, height: s * 0.09)
                                }
                            }
                        }
                    }
                }.offset(y: -s * 0.02)
                // arcos do telhado
                ForEach(0..<4, id: \.self) { i in
                    RB(16 + i, total: 36, onTap: onTap) {
                        Outlined(shape: NoseCone(), fill: fills[16 + i].map(colorFor) ?? .white, line: 2)
                            .frame(width: s * 0.115, height: s * 0.10)
                            .offset(x: s * (-0.175 + CGFloat(i) * 0.117), y: -s * 0.28)
                    }
                }
                // torre + portas + bandeira + cruz
                RB(20, total: 36, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: 4, style: .continuous), fill: fills[20].map(colorFor) ?? .white)
                        .frame(width: s * 0.10, height: s * 0.30).offset(x: -s * 0.30, y: -s * 0.08)
                }
                RB(21, total: 36, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: 4, style: .continuous), fill: fills[21].map(colorFor) ?? .white)
                        .frame(width: s * 0.10, height: s * 0.30).offset(x: s * 0.30, y: -s * 0.08)
                }
                RB(22, total: 36, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: s * 0.03, style: .continuous), fill: fills[22].map(colorFor) ?? .white)
                        .frame(width: s * 0.09, height: s * 0.14).offset(x: -s * 0.055, y: s * 0.10)
                }
                RB(23, total: 36, onTap: onTap) {
                    Outlined(shape: RoundedRectangle(cornerRadius: s * 0.03, style: .continuous), fill: fills[23].map(colorFor) ?? .white)
                        .frame(width: s * 0.09, height: s * 0.14).offset(x: s * 0.055, y: s * 0.10)
                }
                RB(34, total: 36, onTap: onTap) {
                    Outlined(shape: Triangle(), fill: fills[34].map(colorFor) ?? Color(red: 0.99, green: 0.42, blue: 0.33), line: 1.8)
                        .frame(width: s * 0.07, height: s * 0.05).offset(x: -s * 0.26, y: -s * 0.26)
                }
                RB(35, total: 36, onTap: onTap) {
                    Outlined(shape: Cross(), fill: fills[35].map(colorFor) ?? Color(red: 0.98, green: 0.75, blue: 0.28), line: 1.8)
                        .frame(width: s * 0.06, height: s * 0.08).offset(y: -s * 0.37)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct Cross: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width * 0.3
        p.addRect(CGRect(x: rect.midX - w / 2, y: rect.minY, width: w, height: rect.height))
        p.addRect(CGRect(x: rect.minX, y: rect.minY + rect.height * 0.25, width: rect.width, height: w))
        return p
    }
}

// MARK: Host da mandala radial com total custom (reuso p/ copa do ipê)

struct RadialMandalaHost: View {
    var petals: Int
    var rings: Int
    var fills: [Int: Int]
    var colorFor: (Int) -> Color
    var onTap: ((Int) -> Void)?
    var total: Int

    var body: some View {
        GeometryReader { _ in
            ZStack {
                ForEach((0..<rings).reversed(), id: \.self) { ring in
                    let step = (0.48 - 0.11) / Double(rings)
                    let inner = 0.11 + Double(ring) * step
                    let outer = 0.11 + Double(ring + 1) * step
                    ForEach(0..<petals, id: \.self) { petal in
                        let offset = Double(ring) * (360.0 / Double(petals) / 2.0)
                        let a0 = Double(petal) * 360.0 / Double(petals) - 90 + offset
                        let a1 = Double(petal + 1) * 360.0 / Double(petals) - 90 + offset
                        let id = 1 + ring * petals + petal
                        RB(id, total: total, onTap: onTap) {
                            AnnularSlice(startDegrees: a0, endDegrees: a1, innerFraction: inner, outerFraction: outer)
                                .fill(fills[id].map(colorFor) ?? .white)
                                .overlay(AnnularSlice(startDegrees: a0, endDegrees: a1, innerFraction: inner, outerFraction: outer)
                                    .stroke(Color.black.opacity(0.8), lineWidth: 1.6))
                        }
                    }
                }
                RB(0, total: total, onTap: onTap) {
                    Circle()
                        .fill(fills[0].map(colorFor) ?? Color(red: 0.98, green: 0.78, blue: 0.35))
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
