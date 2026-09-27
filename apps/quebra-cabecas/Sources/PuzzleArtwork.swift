import SwiftUI

struct PuzzleIllustrationTile: View {
    let sourceIndex: Int
    let size: Int

    var body: some View {
        GeometryReader { geometry in
            let tileSide = geometry.size.width
            let imageSide = tileSide * CGFloat(size)
            PuzzleIllustration()
                .frame(width: imageSide, height: imageSide)
                .offset(
                    x: -CGFloat(sourceIndex % size) * tileSide,
                    y: -CGFloat(sourceIndex / size) * tileSide
                )
        }
        .clipped()
    }
}

struct PuzzleIllustration: View {
    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
            let rect = CGRect(origin: origin, size: CGSize(width: side, height: side))
            let point: (CGFloat, CGFloat) -> CGPoint = { x, y in
                CGPoint(x: rect.minX + x * side, y: rect.minY + y * side)
            }

            context.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.37, green: 0.68, blue: 0.84), Color(red: 0.92, green: 0.82, blue: 0.58)]),
                    startPoint: point(0.5, 0),
                    endPoint: point(0.5, 1)
                )
            )

            context.fill(Path(ellipseIn: CGRect(x: rect.minX + side * 0.68, y: rect.minY + side * 0.12, width: side * 0.17, height: side * 0.17)), with: .color(Color(red: 1.0, green: 0.82, blue: 0.38)))
            context.fill(Path(ellipseIn: CGRect(x: rect.minX + side * 0.14, y: rect.minY + side * 0.15, width: side * 0.18, height: side * 0.065)), with: .color(.white.opacity(0.78)))
            context.fill(Path(ellipseIn: CGRect(x: rect.minX + side * 0.21, y: rect.minY + side * 0.12, width: side * 0.14, height: side * 0.09)), with: .color(.white.opacity(0.78)))
            context.fill(Path(ellipseIn: CGRect(x: rect.minX + side * 0.48, y: rect.minY + side * 0.28, width: side * 0.20, height: side * 0.07)), with: .color(.white.opacity(0.62)))
            context.fill(Path(ellipseIn: CGRect(x: rect.minX + side * 0.56, y: rect.minY + side * 0.25, width: side * 0.13, height: side * 0.09)), with: .color(.white.opacity(0.62)))

            var distantMountains = Path()
            distantMountains.move(to: point(0, 0.61))
            distantMountains.addLine(to: point(0.17, 0.34))
            distantMountains.addLine(to: point(0.29, 0.48))
            distantMountains.addLine(to: point(0.47, 0.27))
            distantMountains.addLine(to: point(0.72, 0.56))
            distantMountains.addLine(to: point(0.86, 0.38))
            distantMountains.addLine(to: point(1, 0.57))
            distantMountains.addLine(to: point(1, 1))
            distantMountains.addLine(to: point(0, 1))
            distantMountains.closeSubpath()
            context.fill(distantMountains, with: .color(Color(red: 0.43, green: 0.58, blue: 0.62)))

            var farHill = Path()
            farHill.move(to: point(0, 0.62))
            farHill.addQuadCurve(to: point(1, 0.58), control: point(0.55, 0.45))
            farHill.addLine(to: point(1, 1))
            farHill.addLine(to: point(0, 1))
            farHill.closeSubpath()
            context.fill(farHill, with: .color(Color(red: 0.39, green: 0.66, blue: 0.45)))

            var nearHill = Path()
            nearHill.move(to: point(0, 0.74))
            nearHill.addQuadCurve(to: point(1, 0.69), control: point(0.43, 0.58))
            nearHill.addLine(to: point(1, 1))
            nearHill.addLine(to: point(0, 1))
            nearHill.closeSubpath()
            context.fill(nearHill, with: .color(Color(red: 0.18, green: 0.48, blue: 0.34)))

            var river = Path()
            river.move(to: point(0.48, 0.59))
            river.addQuadCurve(to: point(0.76, 1), control: point(0.44, 0.78))
            river.addLine(to: point(0.99, 1))
            river.addQuadCurve(to: point(0.65, 0.57), control: point(0.88, 0.77))
            river.closeSubpath()
            context.fill(river, with: .color(Color(red: 0.28, green: 0.67, blue: 0.78)))

            let house = CGRect(x: rect.minX + side * 0.15, y: rect.minY + side * 0.60, width: side * 0.19, height: side * 0.14)
            context.fill(Path(house), with: .color(Color(red: 0.91, green: 0.77, blue: 0.57)))
            var roof = Path()
            roof.move(to: point(0.12, 0.61))
            roof.addLine(to: point(0.245, 0.50))
            roof.addLine(to: point(0.37, 0.61))
            roof.closeSubpath()
            context.fill(roof, with: .color(Color(red: 0.49, green: 0.27, blue: 0.22)))
            context.fill(Path(CGRect(x: rect.minX + side * 0.22, y: rect.minY + side * 0.65, width: side * 0.045, height: side * 0.055)), with: .color(Color(red: 0.35, green: 0.55, blue: 0.62)))
            context.fill(Path(CGRect(x: rect.minX + side * 0.28, y: rect.minY + side * 0.65, width: side * 0.035, height: side * 0.09)), with: .color(Color(red: 0.39, green: 0.25, blue: 0.19)))

            func triangle(_ top: CGPoint, _ left: CGPoint, _ right: CGPoint) -> Path {
                var path = Path()
                path.move(to: top)
                path.addLine(to: left)
                path.addLine(to: right)
                path.closeSubpath()
                return path
            }

            let trees: [(CGFloat, CGFloat, CGFloat)] = [(0.08, 0.70, 0.105), (0.38, 0.76, 0.095), (0.91, 0.69, 0.12)]
            for tree in trees {
                let x = tree.0
                let y = tree.1
                let radius = tree.2
                context.fill(Path(CGRect(x: rect.minX + side * (x - 0.012), y: rect.minY + side * (y - 0.02), width: side * 0.024, height: side * 0.10)), with: .color(Color(red: 0.39, green: 0.28, blue: 0.18)))
                context.fill(triangle(point(x, y - radius), point(x - radius, y + radius * 0.7), point(x + radius, y + radius * 0.7)), with: .color(Color(red: 0.10, green: 0.35, blue: 0.27)))
                context.fill(triangle(point(x, y - radius * 0.35), point(x - radius * 0.75, y + radius * 1.2), point(x + radius * 0.75, y + radius * 1.2)), with: .color(Color(red: 0.13, green: 0.41, blue: 0.30)))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
