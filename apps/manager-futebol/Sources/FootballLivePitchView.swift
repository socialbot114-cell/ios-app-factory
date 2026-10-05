import SwiftUI

/// Ver o jogo: estádio com arquibancadas, painéis de LED e refletores, gramado, 22 atletas com uniformes de verdade,
/// árbitro, bola com física e a torcida reagindo aos gols. O movimento vem do `PitchEngine`.
struct FootballLivePitchView: View {
    let live: LiveMatchState
    let career: FootballCareer
    let running: Bool
    let speed: Int
    var height: CGFloat = 230

    @State private var engine = PitchEngine()

    private var sim: MatchSimulation { live.sim }

    private static let lineDepth: [Double] = [0.07, 0.25, 0.43, 0.62]

    /// Pressão recente de -1 (rival domina) a 1 (mandante domina).
    private var pressure: Double {
        let recent = sim.momentum.suffix(10)
        guard !recent.isEmpty else { return 0 }
        return max(-1, min(1, Double(recent.reduce(0, +)) / Double(recent.count) / 60))
    }

    private func shirtNumber(_ detail: PositionDetail, id: Int) -> Int {
        let alternate = id % 2 == 0
        switch detail {
        case .goalkeeper: return 1
        case .rightBack: return 2
        case .centreBack: return alternate ? 3 : 4
        case .leftBack: return 6
        case .defensiveMid: return 5
        case .centralMid: return alternate ? 8 : 16
        case .attackingMid: return 10
        case .winger: return alternate ? 7 : 11
        case .striker: return alternate ? 9 : 19
        }
    }

    private func slots() -> [PitchSlotInfo] {
        var result: [PitchSlotInfo] = []
        for isHome in [true, false] {
            let state = isHome ? sim.home : sim.away
            let athletes = state.onPitch.compactMap { career.player($0) }
            var columns: [Int: [(FootballPlayer, Int)]] = [:]
            for athlete in athletes {
                let zone = MatchSimulation.baseZone(athlete.detail)
                columns[zone.0, default: []].append((athlete, zone.1))
            }
            for (column, group) in columns {
                let ordered = group.sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.id < $1.0.id }
                for (index, entry) in ordered.enumerated() {
                    let lateral = Double(index + 1) / Double(ordered.count + 1)
                    let surname = entry.0.name.split(separator: " ").last.map(String.init) ?? entry.0.name
                    result.append(PitchSlotInfo(id: entry.0.id, home: isHome, keeper: entry.0.position == .goalkeeper,
                                                number: shirtNumber(entry.0.detail, id: entry.0.id), name: surname,
                                                depth: Self.lineDepth[min(3, max(0, column))],
                                                lateral: isHome ? lateral : 1 - lateral))
                }
            }
        }
        return result.sorted { $0.id < $1.id }
    }

    var body: some View {
        let homeTeam = FootballSeason.team(sim.home.teamID)
        let awayTeam = FootballSeason.team(sim.away.teamID)
        let homeKit = PitchKit.home(homeTeam)
        let awayKit = PitchKit.away(awayTeam, against: homeKit)
        let homeKeeperKit = PitchKit.keeper(avoiding: [homeKit.shirt, awayKit.shirt])
        let awayKeeperKit = PitchKit.keeper(avoiding: [homeKit.shirt, awayKit.shirt, homeKeeperKit.shirt])
        let input = PitchInput(slots: slots(), homeShare: sim.possessionShare, pressure: pressure, events: sim.events,
                               homeTeamID: sim.home.teamID, finished: sim.finished)
        if FactoryCapture.screen?.hasPrefix("match") == true, !engine.isWarmed, sim.minute > 0 { engine.warmUpForCapture(input: input) }
        let eventCount = sim.events.count
        let busy = engine.isBusy(eventCount: eventCount)
        let rates: [Int: Double] = [1: 1.0, 2: 1.5, 4: 2.2]
        let rate = running ? (rates[speed] ?? 1.0) : 1.0
        let crowd = min(1, max(0.35, 0.40 + Double(career.clubHype) / 160))
        let kits = Kits(home: homeKit, away: awayKit, homeKeeper: homeKeeperKit, awayKeeper: awayKeeperKit)
        let stageEngine = self.engine
        let celebrating = stageEngine.celebratingHome

        return VStack(spacing: 6) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !(running || busy))) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    stageEngine.advance(now: time, speed: rate, input: input)
                    draw(&context, size: size, engine: stageEngine, kits: kits, crowd: crowd, time: time)
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .overlay(alignment: .top) {
                if let celebrating {
                    Text("GOL! \(FootballSeason.teamName(celebrating ? sim.home.teamID : sim.away.teamID))")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Color.black.opacity(0.7), in: Capsule())
                        .padding(.top, 8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: celebrating)
            if let event = sim.events.last(where: { $0.kind != .tactic }) {
                Text("\(event.minuteLabel) \(event.text)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Jogo ao vivo, minuto \(sim.minute). \(sim.scoreLine)")
        .accessibilityIdentifier("live-pitch")
    }

    private struct Kits {
        let home: PitchKit
        let away: PitchKit
        let homeKeeper: PitchKit
        let awayKeeper: PitchKit
    }

    // MARK: - Geometria

    private struct Stage {
        let size: CGSize
        let pitch: CGRect
        let sx: CGFloat
        let sy: CGFloat

        init(size: CGSize) {
            self.size = size
            let side = size.width * 0.06
            let top = size.height * 0.19
            let bottom = size.height * 0.21
            pitch = CGRect(x: side, y: top, width: size.width - side * 2, height: size.height - top - bottom)
            sx = pitch.width / CGFloat(PitchEngine.length)
            sy = pitch.height / CGFloat(PitchEngine.width)
        }

        func point(_ meters: PitchVector) -> CGPoint {
            CGPoint(x: pitch.minX + CGFloat(meters.x) * sx, y: pitch.minY + CGFloat(meters.y) * sy)
        }

        func path(_ meters: Path) -> Path {
            meters.applying(CGAffineTransform(translationX: pitch.minX, y: pitch.minY).scaledBy(x: sx, y: sy))
        }
    }

    private func noise(_ a: Int, _ b: Int, _ salt: Int) -> Double {
        let value = sin(Double(a &* 127 &+ b &* 311 &+ salt &* 53) * 12.9898) * 43758.5453
        return abs(value - floor(value))
    }

    // MARK: - Desenho

    private func draw(_ context: inout GraphicsContext, size: CGSize, engine: PitchEngine, kits: Kits, crowd: Double, time: Double) {
        let stage = Stage(size: size)
        drawSurroundings(&context, stage: stage, kits: kits, crowd: crowd, time: time, celebrating: engine.celebratingHome)
        drawPitch(&context, stage: stage)
        drawActors(&context, stage: stage, engine: engine, kits: kits, time: time)
        drawLighting(&context, stage: stage)
    }

    private func drawSurroundings(_ context: inout GraphicsContext, stage: Stage, kits: Kits, crowd: Double, time: Double, celebrating: Bool?) {
        let size = stage.size
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Color(red: 0.03, green: 0.04, blue: 0.08), Color(red: 0.10, green: 0.11, blue: 0.16)]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        let pitch = stage.pitch
        let homeColor = kits.home.shirt
        let awayColor = kits.away.shirt
        let regions: [(rect: CGRect, salt: Int, homeShare: Double)] = [
            (CGRect(x: 0, y: 0, width: size.width, height: pitch.minY - 9), 1, 0.6),
            (CGRect(x: 0, y: pitch.maxY + 9, width: size.width, height: size.height - pitch.maxY - 9), 2, 0.35),
            (CGRect(x: 0, y: pitch.minY - 9, width: pitch.minX - 3, height: pitch.height + 18), 3, 1.0),
            (CGRect(x: pitch.maxX + 3, y: pitch.minY - 9, width: size.width - pitch.maxX - 3, height: pitch.height + 18), 4, 0.0)
        ]
        for region in regions {
            let rect = region.rect
            guard rect.width > 4, rect.height > 4 else { continue }
            context.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(white: 0.20), Color(white: 0.12)]),
                                                           startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                                           endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
            var seats = Path(), homeFans = Path(), awayFans = Path(), neutralFans = Path()
            let step: CGFloat = 5
            var column = 0
            var x = rect.minX + 1
            while x < rect.maxX - 3 {
                var row = 0
                var y = rect.minY + 1
                let aisle = column % 11 == 10
                while y < rect.maxY - 3 {
                    let cell = CGRect(x: x, y: y, width: 3.6, height: 3.6)
                    if aisle {
                        // corredor entre os setores
                    } else if noise(column, row, region.salt) < crowd {
                        let kind = noise(column, row, region.salt + 9)
                        var bounce = 0.0
                        if let celebrating, celebrating == (kind < region.homeShare) { bounce = sin(time * 10 + Double(column)) * 1.8 }
                        let fan = cell.offsetBy(dx: 0, dy: bounce)
                        if kind < region.homeShare * 0.85 { homeFans.addEllipse(in: fan) }
                        else if kind > 0.93 - (1 - region.homeShare) * 0.4 { awayFans.addEllipse(in: fan) }
                        else { neutralFans.addEllipse(in: fan) }
                    } else {
                        seats.addRoundedRect(in: cell, cornerSize: CGSize(width: 1, height: 1))
                    }
                    y += step
                    row += 1
                }
                x += step
                column += 1
            }
            context.fill(seats, with: .color(Color(red: 0.22, green: 0.27, blue: 0.40).opacity(0.9)))
            context.fill(homeFans, with: .color(homeColor.opacity(0.95)))
            context.fill(awayFans, with: .color(awayColor.opacity(0.95)))
            context.fill(neutralFans, with: .color(Color(white: 0.85).opacity(0.75)))
        }
        // Mosaico da torcida comemorando atrás do gol.
        if let celebrating {
            let end = celebrating ? regions[2].rect : regions[3].rect
            let color = celebrating ? kits.home : kits.away
            var mosaic = Path()
            let cell: CGFloat = 6
            var y = end.minY
            var row = 0
            while y < end.maxY - 2 {
                var x = end.minX
                var column = 0
                while x < end.maxX - 2 {
                    if (row + column + Int(time * 6)) % 2 == 0 { mosaic.addRect(CGRect(x: x, y: y, width: cell - 1, height: cell - 1)) }
                    x += cell
                    column += 1
                }
                y += cell
                row += 1
            }
            context.fill(mosaic, with: .color(color.trim.opacity(0.65)))
        }
        // Teto da arquibancada superior projeta sombra.
        let roof = CGRect(x: 0, y: 0, width: size.width, height: pitch.minY * 0.45)
        context.fill(Path(roof), with: .linearGradient(Gradient(colors: [Color.black.opacity(0.75), .clear]),
                                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: roof.height)))
        drawBoards(&context, stage: stage, time: time)
        drawFloodlights(&context, stage: stage, time: time)
        drawDugouts(&context, stage: stage, kits: kits)
    }

    private func drawBoards(_ context: inout GraphicsContext, stage: Stage, time: Double) {
        let pitch = stage.pitch
        let palette: [Color] = [Color(red: 0.95, green: 0.78, blue: 0.10), Color(red: 0.85, green: 0.15, blue: 0.20),
                                Color(red: 0.10, green: 0.50, blue: 0.90), Color(red: 0.95, green: 0.95, blue: 0.95)]
        let segment: CGFloat = 38
        for (y, reverse) in [(pitch.minY - 8, false), (pitch.maxY + 3, true)] {
            var x = -segment + CGFloat((time * 18).truncatingRemainder(dividingBy: Double(segment * 4))) * (reverse ? -1 : 1)
            var index = 0
            while x < stage.size.width + segment {
                let rect = CGRect(x: x, y: y, width: segment - 2, height: 5)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(palette[abs(index) % palette.count].opacity(0.9)))
                context.fill(Path(CGRect(x: rect.minX + 6, y: rect.midY - 0.8, width: segment - 14, height: 1.6)), with: .color(.black.opacity(0.35)))
                x += segment
                index += 1
            }
        }
    }

    private func drawFloodlights(_ context: inout GraphicsContext, stage: Stage, time: Double) {
        let corners = [CGPoint(x: 8, y: 6), CGPoint(x: stage.size.width - 8, y: 6),
                       CGPoint(x: 8, y: stage.size.height - 6), CGPoint(x: stage.size.width - 8, y: stage.size.height - 6)]
        for corner in corners {
            let radius: CGFloat = 46
            context.fill(Path(ellipseIn: CGRect(x: corner.x - radius, y: corner.y - radius, width: radius * 2, height: radius * 2)),
                         with: .radialGradient(Gradient(colors: [Color.white.opacity(0.55), Color(red: 1, green: 0.95, blue: 0.7).opacity(0.12), .clear]),
                                               center: corner, startRadius: 0, endRadius: radius))
            context.fill(Path(ellipseIn: CGRect(x: corner.x - 3, y: corner.y - 3, width: 6, height: 6)), with: .color(.white))
        }
    }

    private func drawDugouts(_ context: inout GraphicsContext, stage: Stage, kits: Kits) {
        let pitch = stage.pitch
        let y = pitch.maxY + 11
        for (index, kit) in [kits.home, kits.away].enumerated() {
            let centerX = pitch.midX + (index == 0 ? -pitch.width * 0.2 : pitch.width * 0.2)
            let rect = CGRect(x: centerX - 28, y: y, width: 56, height: 9)
            context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(Color(white: 0.08).opacity(0.85)))
            context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(.white.opacity(0.25)), lineWidth: 0.8)
            for seat in 0..<6 {
                let seatX = rect.minX + 6 + CGFloat(seat) * 8.6
                context.fill(Path(ellipseIn: CGRect(x: seatX, y: rect.minY + 1.5, width: 5, height: 5)), with: .color(kit.shirt.opacity(seat == 5 ? 0.6 : 0.95)))
            }
        }
    }

    private func drawPitch(_ context: inout GraphicsContext, stage: Stage) {
        let pitch = stage.pitch
        let stripes = 14
        for index in 0..<stripes {
            let width = pitch.width / CGFloat(stripes)
            let rect = CGRect(x: pitch.minX + width * CGFloat(index), y: pitch.minY, width: width + 0.6, height: pitch.height)
            context.fill(Path(rect), with: .color(index % 2 == 0 ? Color(red: 0.14, green: 0.52, blue: 0.29) : Color(red: 0.10, green: 0.43, blue: 0.24)))
        }
        // Corte em xadrez suave no gramado.
        let rows = 6
        for index in 0..<rows where index % 2 == 0 {
            let height = pitch.height / CGFloat(rows)
            context.fill(Path(CGRect(x: pitch.minX, y: pitch.minY + height * CGFloat(index), width: pitch.width, height: height)), with: .color(.white.opacity(0.025)))
        }
        let length = PitchEngine.length
        let width = PitchEngine.width
        var lines = Path()
        lines.addRect(CGRect(x: 0, y: 0, width: length, height: width))
        lines.move(to: CGPoint(x: length / 2, y: 0))
        lines.addLine(to: CGPoint(x: length / 2, y: width))
        for isLeft in [true, false] {
            let boxX = isLeft ? 0.0 : length - 16.5
            lines.addRect(CGRect(x: boxX, y: width / 2 - 20.15, width: 16.5, height: 40.3))
            let smallX = isLeft ? 0.0 : length - 5.5
            lines.addRect(CGRect(x: smallX, y: width / 2 - 9.16, width: 5.5, height: 18.32))
            let spotX = isLeft ? 11.0 : length - 11
            let center = CGPoint(x: spotX, y: width / 2)
            let start = isLeft ? -53.0 : 127.0
            appendArc(&lines, center: center, radius: 9.15, from: start, to: start + 106)
        }
        appendArc(&lines, center: CGPoint(x: length / 2, y: width / 2), radius: 9.15, from: 0, to: 360)
        let lineStyle = StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
        // As linhas são desenhadas em metros e escaladas para o palco; o campo esticado deixa os círculos levemente ovais.
        context.stroke(stage.path(lines), with: .color(.white.opacity(0.75)), style: lineStyle)
        for spot in [PitchVector(length / 2, width / 2), PitchVector(11, width / 2), PitchVector(length - 11, width / 2)] {
            let point = stage.point(spot)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 1.6, y: point.y - 1.6, width: 3.2, height: 3.2)), with: .color(.white.opacity(0.85)))
        }
        for corner in [PitchVector(0, 0), PitchVector(length, 0), PitchVector(0, width), PitchVector(length, width)] {
            let point = stage.point(corner)
            var flag = Path()
            flag.move(to: point)
            flag.addLine(to: CGPoint(x: point.x, y: point.y - 7))
            flag.addLine(to: CGPoint(x: point.x + (corner.x == 0 ? 4 : -4), y: point.y - 5.5))
            flag.addLine(to: CGPoint(x: point.x, y: point.y - 4))
            context.stroke(flag, with: .color(.yellow), lineWidth: 1)
        }
        // Gols com rede.
        for isLeft in [true, false] {
            let depth = 2.4
            let netX = isLeft ? -depth : length
            var net = Path()
            let top = width / 2 - 3.66
            net.addRect(CGRect(x: netX, y: top, width: depth, height: 7.32))
            for step in 1..<4 {
                let y = top + 7.32 * Double(step) / 4
                net.move(to: CGPoint(x: netX, y: y))
                net.addLine(to: CGPoint(x: netX + depth, y: y))
            }
            for step in 1..<3 {
                let x = netX + depth * Double(step) / 3
                net.move(to: CGPoint(x: x, y: top))
                net.addLine(to: CGPoint(x: x, y: top + 7.32))
            }
            let transformed = stage.path(net)
            context.fill(stage.path(Path(CGRect(x: netX, y: top, width: depth, height: 7.32))), with: .color(.white.opacity(0.10)))
            context.stroke(transformed, with: .color(.white.opacity(0.55)), lineWidth: 0.6)
        }
    }

    private func appendArc(_ path: inout Path, center: CGPoint, radius: Double, from: Double, to: Double) {
        let segments = 28
        for index in 0...segments {
            let angle = (from + (to - from) * Double(index) / Double(segments)) * .pi / 180
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
    }

    private func drawLighting(_ context: inout GraphicsContext, stage: Stage) {
        let pitch = stage.pitch
        context.fill(Path(pitch), with: .radialGradient(Gradient(colors: [Color.white.opacity(0.10), .clear, Color.black.opacity(0.28)]),
                                                        center: CGPoint(x: pitch.midX, y: pitch.midY), startRadius: 4,
                                                        endRadius: max(pitch.width, pitch.height) * 0.62))
    }

    // MARK: - Atores

    private func drawActors(_ context: inout GraphicsContext, stage: Stage, engine: PitchEngine, kits: Kits, time: Double) {
        let spriteHeight = max(13, min(21, stage.sx * 4.6))
        let ordered = engine.bodies.sorted { $0.pos.y < $1.pos.y }
        let skins: [Color] = [Color(red: 0.96, green: 0.80, blue: 0.66), Color(red: 0.78, green: 0.58, blue: 0.42),
                              Color(red: 0.55, green: 0.38, blue: 0.26), Color(red: 0.36, green: 0.24, blue: 0.17)]
        let hair: [Color] = [Color(red: 0.12, green: 0.09, blue: 0.07), Color(red: 0.30, green: 0.18, blue: 0.10), Color(red: 0.85, green: 0.68, blue: 0.30)]

        for trailPoint in engine.trail.enumerated() {
            let point = stage.point(trailPoint.element)
            let alpha = Double(trailPoint.offset + 1) / Double(engine.trail.count + 2) * 0.35
            context.fill(Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)), with: .color(.white.opacity(alpha)))
        }
        let refPoint = stage.point(engine.referee)
        drawSprite(&context, at: refPoint, height: spriteHeight,
                   kit: PitchKit(shirt: Color(white: 0.08), trim: Color(red: 0.95, green: 0.85, blue: 0.1), shorts: Color(white: 0.05), socks: Color(white: 0.08), pattern: .solid),
                   facing: engine.ballPos.x > engine.referee.x ? 1 : -1, stride: time * 5, dive: 0, skin: skins[1], hair: hair[0], ring: false)

        for body in ordered {
            let point = stage.point(body.pos)
            let kit = body.keeper ? (body.home ? kits.homeKeeper : kits.awayKeeper) : (body.home ? kits.home : kits.away)
            let diving = time < body.diveUntil ? body.diveSide : 0
            drawSprite(&context, at: point, height: spriteHeight, kit: kit, facing: body.facing, stride: body.stride, dive: diving,
                       skin: skins[abs(body.id) % skins.count], hair: hair[abs(body.id / 4) % hair.count], ring: engine.carrierID == body.id)
        }
        // Bola: sombra no chão e a bola levantada pela altura.
        let ground = stage.point(engine.ballPos)
        let lift = CGFloat(engine.ballZ) * stage.sy * 1.7
        context.fill(Path(ellipseIn: CGRect(x: ground.x - 3.5, y: ground.y - 1.2, width: 7, height: 3)), with: .color(.black.opacity(0.4)))
        let ball = CGRect(x: ground.x - 4, y: ground.y - lift - 8, width: 8, height: 8)
        context.fill(Path(ellipseIn: ball), with: .color(.white))
        context.stroke(Path(ellipseIn: ball), with: .color(.black.opacity(0.8)), lineWidth: 0.9)
        context.fill(Path(ellipseIn: CGRect(x: ball.midX - 1.5, y: ball.midY - 1.5, width: 3, height: 3)), with: .color(.black.opacity(0.75)))

        if let carrier = engine.carrierID.flatMap({ engine.body($0) }) {
            let point = stage.point(carrier.pos)
            let label = "\(carrier.number) \(carrier.name)"
            let anchor = CGPoint(x: min(max(point.x, 34), stage.size.width - 34), y: point.y - spriteHeight - 9)
            context.fill(Path(roundedRect: CGRect(x: anchor.x - 30, y: anchor.y - 7, width: 60, height: 13), cornerRadius: 6.5),
                         with: .color(.black.opacity(0.7)))
            context.draw(Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.white), at: anchor)
        }
        for mark in engine.cardMarks {
            let point = stage.point(mark.pos)
            let bounce = CGFloat(sin(time * 8)) * 1.5
            let rect = CGRect(x: point.x - 3.5, y: point.y - spriteHeight - 14 + bounce, width: 7, height: 10)
            context.fill(Path(roundedRect: rect, cornerRadius: 1.2), with: .color(mark.red ? .red : .yellow))
            context.stroke(Path(roundedRect: rect, cornerRadius: 1.2), with: .color(.white.opacity(0.9)), lineWidth: 0.8)
        }
    }

    private func drawSprite(_ context: inout GraphicsContext, at point: CGPoint, height sh: CGFloat, kit: PitchKit,
                            facing: Double, stride: Double, dive: Double, skin: Color, hair: Color, ring: Bool) {
        context.drawLayer { layer in
            layer.translateBy(x: point.x, y: point.y)
            if ring {
                layer.stroke(Path(ellipseIn: CGRect(x: -sh * 0.42, y: -sh * 0.10, width: sh * 0.84, height: sh * 0.30)),
                             with: .color(.yellow.opacity(0.95)), lineWidth: 1.4)
            }
            layer.fill(Path(ellipseIn: CGRect(x: -sh * 0.30, y: -sh * 0.05, width: sh * 0.60, height: sh * 0.18)), with: .color(.black.opacity(0.38)))
            if dive != 0 {
                layer.translateBy(x: 0, y: -sh * 0.45)
                layer.rotate(by: .degrees(dive * 78))
                layer.translateBy(x: 0, y: sh * 0.45)
            }
            layer.scaleBy(x: facing >= 0 ? 1 : -1, y: 1)
            let swing = CGFloat(sin(stride * 3.2)) * sh * 0.13
            // Pernas e meias.
            layer.fill(Path(CGRect(x: -sh * 0.15 + swing, y: -sh * 0.30, width: sh * 0.11, height: sh * 0.30)), with: .color(kit.socks))
            layer.fill(Path(CGRect(x: sh * 0.04 - swing, y: -sh * 0.30, width: sh * 0.11, height: sh * 0.30)), with: .color(kit.socks))
            layer.fill(Path(CGRect(x: -sh * 0.15 + swing, y: -sh * 0.06, width: sh * 0.11, height: sh * 0.06)), with: .color(.black.opacity(0.75)))
            layer.fill(Path(CGRect(x: sh * 0.04 - swing, y: -sh * 0.06, width: sh * 0.11, height: sh * 0.06)), with: .color(.black.opacity(0.75)))
            // Calção.
            layer.fill(Path(roundedRect: CGRect(x: -sh * 0.18, y: -sh * 0.44, width: sh * 0.36, height: sh * 0.17), cornerRadius: 1.2), with: .color(kit.shorts))
            // Braços.
            layer.fill(Path(CGRect(x: -sh * 0.27 - swing * 0.5, y: -sh * 0.72, width: sh * 0.08, height: sh * 0.24)), with: .color(skin))
            layer.fill(Path(CGRect(x: sh * 0.19 + swing * 0.5, y: -sh * 0.72, width: sh * 0.08, height: sh * 0.24)), with: .color(skin))
            // Camisa com o padrão do clube.
            let shirt = Path(roundedRect: CGRect(x: -sh * 0.20, y: -sh * 0.76, width: sh * 0.40, height: sh * 0.35), cornerRadius: 2)
            layer.drawLayer { inner in
                inner.clip(to: shirt)
                inner.fill(shirt, with: .color(kit.shirt))
                let box = CGRect(x: -sh * 0.20, y: -sh * 0.76, width: sh * 0.40, height: sh * 0.35)
                switch kit.pattern {
                case .solid:
                    break
                case .verticalStripes:
                    for index in 0..<3 {
                        inner.fill(Path(CGRect(x: box.minX + box.width * (0.18 + 0.28 * CGFloat(index)), y: box.minY, width: box.width * 0.14, height: box.height)), with: .color(kit.trim))
                    }
                case .hoops:
                    for index in 0..<2 {
                        inner.fill(Path(CGRect(x: box.minX, y: box.minY + box.height * (0.18 + 0.38 * CGFloat(index)), width: box.width, height: box.height * 0.18)), with: .color(kit.trim))
                    }
                case .halves:
                    inner.fill(Path(CGRect(x: box.midX, y: box.minY, width: box.width / 2, height: box.height)), with: .color(kit.trim))
                case .sash:
                    var sash = Path()
                    sash.move(to: CGPoint(x: box.minX, y: box.minY + box.height * 0.1))
                    sash.addLine(to: CGPoint(x: box.minX + box.width * 0.4, y: box.minY))
                    sash.addLine(to: CGPoint(x: box.maxX, y: box.maxY - box.height * 0.1))
                    sash.addLine(to: CGPoint(x: box.maxX - box.width * 0.4, y: box.maxY))
                    sash.closeSubpath()
                    inner.fill(sash, with: .color(kit.trim))
                }
                inner.fill(Path(CGRect(x: box.minX, y: box.minY, width: box.width, height: box.height * 0.16)), with: .color(kit.trim.opacity(0.9)))
            }
            // Cabeça e cabelo.
            layer.fill(Path(ellipseIn: CGRect(x: -sh * 0.11, y: -sh * 0.97, width: sh * 0.22, height: sh * 0.22)), with: .color(skin))
            layer.fill(Path(ellipseIn: CGRect(x: -sh * 0.115, y: -sh * 0.985, width: sh * 0.23, height: sh * 0.13)), with: .color(hair))
        }
    }
}
