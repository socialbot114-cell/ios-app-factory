import SwiftUI

@main
struct ManagerFutebolApp: App {
    var body: some Scene { WindowGroup { FootballHome() } }
}

struct LeagueTeam: Identifiable, Hashable {
    let id: Int
    let name: String
    let city: String
    let strength: Int
}

struct LeagueFixture: Identifiable, Equatable {
    let id: Int
    let round: Int
    let home: Int
    let away: Int
    let homeGoals: Int
    let awayGoals: Int
}

struct FootballSeason {
    static let teams: [LeagueTeam] = [
        .init(id: 0, name: "Aurora FC", city: "Brasília", strength: 78),
        .init(id: 1, name: "Atlético Cerrado", city: "Goiânia", strength: 73),
        .init(id: 2, name: "Maré Alta", city: "Salvador", strength: 75),
        .init(id: 3, name: "União da Serra", city: "Belo Horizonte", strength: 77),
        .init(id: 4, name: "Estrela do Sul", city: "Porto Alegre", strength: 74),
        .init(id: 5, name: "Portuários", city: "Santos", strength: 71),
        .init(id: 6, name: "Capital Norte", city: "Manaus", strength: 69),
        .init(id: 7, name: "Vale Verde", city: "Curitiba", strength: 72)
    ]

    static func fixtures(seed: Int) -> [LeagueFixture] {
        let ids = teams.map(\.id)
        var firstLeg: [(Int, Int)] = []
        var rotating = ids
        for round in 0..<7 {
            for index in 0..<4 {
                let a = rotating[index]
                let b = rotating[7 - index]
                firstLeg.append(round.isMultiple(of: 2) ? (a, b) : (b, a))
            }
            let fixed = rotating[0]
            var rest = Array(rotating.dropFirst())
            let last = rest.removeLast()
            rest.insert(last, at: 0)
            rotating = [fixed] + rest
        }
        var output: [LeagueFixture] = []
        for round in 0..<14 {
            for match in 0..<4 {
                let pair = firstLeg[(round % 7) * 4 + match]
                let home = round < 7 ? pair.0 : pair.1
                let away = round < 7 ? pair.1 : pair.0
                let localSeed = seed &+ round &* 37 &+ match &* 101 &+ home &* 13 &+ away &* 29
                var random = UInt64(bitPattern: Int64(truncatingIfNeeded: localSeed))
                random = random &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let homeGoals = Int((random >> 32) % 5)
                random = random &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let awayGoals = Int((random >> 32) % 4)
                output.append(.init(id: round * 4 + match, round: round + 1, home: home, away: away, homeGoals: homeGoals, awayGoals: awayGoals))
            }
        }
        return output
    }

    static func standings(results: [LeagueFixture]) -> [(team: LeagueTeam, points: Int, goalDifference: Int, wins: Int)] {
        var table = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, (points: 0, gd: 0, wins: 0)) })
        for match in results {
            table[match.home]!.gd += match.homeGoals - match.awayGoals
            table[match.away]!.gd += match.awayGoals - match.homeGoals
            if match.homeGoals > match.awayGoals {
                table[match.home]!.points += 3; table[match.home]!.wins += 1
            } else if match.homeGoals < match.awayGoals {
                table[match.away]!.points += 3; table[match.away]!.wins += 1
            } else {
                table[match.home]!.points += 1; table[match.away]!.points += 1
            }
        }
        return teams.map { ($0, table[$0.id]!.points, table[$0.id]!.gd, table[$0.id]!.wins) }
            .sorted { lhs, rhs in
                if lhs.points != rhs.points { return lhs.points > rhs.points }
                if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
                if lhs.goalDifference != rhs.goalDifference { return lhs.goalDifference > rhs.goalDifference }
                return lhs.team.name < rhs.team.name
            }
    }
}

struct FootballHome: View {
    @State private var selectedTab = 0
    @AppStorage("football.seed") private var seed = 26
    @AppStorage("football.currentRound") private var currentRound = 2
    private let accent = Color(red: 0.08, green: 0.37, blue: 0.25)
    private var results: [LeagueFixture] { FootballSeason.fixtures(seed: seed).filter { $0.round <= currentRound } }
    private var capture: String? { FactoryCapture.screen }
    private var lastResult: LeagueFixture? { results.last }
    private var nextFixture: LeagueFixture? {
        guard currentRound < 14 else { return nil }
        return FootballSeason.fixtures(seed: seed).first { $0.round == min(currentRound + 1, 14) && ($0.home == 0 || $0.away == 0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if capture == "table" || selectedTab == 1 { tableView }
                else if capture == "squad" || selectedTab == 2 { squadView }
                else { dashboard }
            }
            .safeAreaInset(edge: .bottom) { navigationBar }
        }
        .tint(accent)
        .onAppear {
            if FactoryCapture.isUITesting {
                FactoryCapture.resetAppDefaults()
                seed = 26
                currentRound = 2
            }
        }
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 20) {
            FactoryHeader(eyebrow: "Liga fictícia · temporada demonstrativa", title: "Treinador, sua jornada começa aqui.", subtitle: "Uma carreira local com clubes e atletas inventados. Sem calendário ou marcas oficiais.", accent: accent)
            FactoryDemoNotice(message: "Clubes e placares fictícios · seed \(seed)")
            FactoryPanel {
                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("PRÓXIMA PARTIDA").font(.caption.bold()).tracking(1.3).foregroundStyle(.secondary)
                        Text(nextFixture.map { "\(FootballSeason.teams[$0.home].name)  ×  \(FootballSeason.teams[$0.away].name)" } ?? "Temporada concluída")
                            .font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                        Text("Rodada \(min(currentRound + 1, 14)) de 14 · Estádio Horizonte") .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "sportscourt.fill").font(.largeTitle).foregroundStyle(accent)
                }
                Button { if currentRound < 14 { currentRound += 1 } else { currentRound = 0; seed += 1 } } label: {
                    Label(currentRound < 14 ? "Simular rodada \(currentRound + 1)" : "Nova temporada", systemImage: "play.fill")
                }
                    .accessibilityIdentifier("simulate-round")
                    .buttonStyle(FactoryPrimaryButtonStyle())
                Text("A simulação usa a seed exibida; repetir a mesma seed gera os mesmos resultados.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                FactoryMetric(label: "Seu clube", value: "Aurora FC", symbol: "shield.fill", tint: accent)
                FactoryMetric(label: "Próxima rodada", value: "\(min(currentRound + 1, 14)) / 14", symbol: "calendar", tint: .orange)
            }
            FactoryPanel(title: "Último resultado", systemImage: "sportscourt") {
                if let lastResult {
                    Text("\(FootballSeason.teams[lastResult.home].name)  \(lastResult.homeGoals) — \(lastResult.awayGoals)  \(FootballSeason.teams[lastResult.away].name)").font(.headline)
                    Text("Rodada \(lastResult.round) · placar determinístico") .font(.caption).foregroundStyle(.secondary)
                }
            }
        }.factoryPage().navigationTitle("Painel do treinador").navigationBarTitleDisplayMode(.inline)
    }

    private var tableView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Liga demonstrativa", title: "Classificação", subtitle: "Pontos → vitórias → saldo de gols → nome do clube.", accent: accent)
            FactoryDemoNotice()
            FactoryPanel(title: "Resultados registrados", systemImage: "checkmark.circle") {
                ForEach(results.suffix(4)) { match in
                    Text("\(FootballSeason.teams[match.home].name)  \(match.homeGoals) — \(match.awayGoals)  \(FootballSeason.teams[match.away].name)")
                        .font(.caption).lineLimit(1).minimumScaleFactor(0.75)
                }
            }
            FactoryPanel {
                HStack { Text("#   CLUBE").font(.caption.bold()).foregroundStyle(.secondary); Spacer(); Text("P  V  SG").font(.caption.bold()).foregroundStyle(.secondary) }
                ForEach(Array(FootballSeason.standings(results: results).enumerated()), id: \.element.team.id) { index, row in
                    HStack(spacing: 10) {
                        Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit().bold()).foregroundStyle(index == 0 ? accent : .secondary).frame(width: 28, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.team.name).font(.subheadline.weight(.semibold))
                            Text(row.team.city).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        let goalDifference = row.goalDifference > 0 ? "+\(row.goalDifference)" : "\(row.goalDifference)"
                        Text("\(row.points)  \(row.wins)  \(goalDifference)")
                            .font(.caption.monospacedDigit().weight(.semibold)).frame(width: 88, alignment: .trailing)
                    }
                    if index < 7 { Divider() }
                }
            }
        }.factoryPage().navigationTitle("Classificação").navigationBarTitleDisplayMode(.inline)
    }

    private var squadView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Elenco demonstrativo", title: "Aurora FC", subtitle: "Atletas fictícios · formação 4–3–3", accent: accent)
            FactoryDemoNotice()
            FactoryPanel(title: "Titulares", systemImage: "person.3.fill") {
                ForEach(Array(["R. Nascimento · GOL", "M. Duarte · ZAG", "L. Campos · MEI", "A. Ribeiro · ATA", "J. Nunes · ATA"].enumerated()), id: \.offset) { _, player in
                    Label(player, systemImage: "person.fill")
                    if player != "J. Nunes · ATA" { Divider() }
                }
                Text("MVP demonstrativo · elenco resumido; estrutura preparada para 16 atletas fictícios por clube.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.factoryPage().navigationTitle("Elenco e tática").navigationBarTitleDisplayMode(.inline)
    }

    private var navigationBar: some View {
        HStack {
            tab("Painel", symbol: "rectangle.grid.1x2.fill", index: 0)
            tab("Tabela", symbol: "list.number", index: 1)
            tab("Elenco", symbol: "person.3.fill", index: 2)
        }.padding(8).background(.regularMaterial, in: Capsule()).padding(.horizontal, 32).padding(.bottom, 8)
    }

    private func tab(_ title: String, symbol: String, index: Int) -> some View {
        Button { selectedTab = index } label: {
            Label(title, systemImage: symbol).font(.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(selectedTab == index ? accent : .secondary)
        }.buttonStyle(.plain)
    }
}
