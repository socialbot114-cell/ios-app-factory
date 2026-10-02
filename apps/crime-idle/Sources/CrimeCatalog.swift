import Foundation

// Todo o conteúdo é ficção: cidade, famílias, negócios e golpes são inventados.

struct CrimeDistrict: Identifiable, Equatable {
    let id: Int
    let name: String
    let rival: String
    let symbol: String
    let cashCost: Double
    let respectCost: Double
    let blurb: String

    static let catalog: [CrimeDistrict] = [
        .init(id: 0, name: "Centro das Lanternas", rival: "Ninguém — é o seu berço", symbol: "lightbulb.fill",
              cashCost: 0, respectCost: 0, blurb: "Becos iluminados a gás onde tudo começou."),
        .init(id: 1, name: "Porto Velho", rival: "Os Gaivotas", symbol: "ferry.fill",
              cashCost: 5_000, respectCost: 10, blurb: "Contêineres sem dono e guindastes que não dormem."),
        .init(id: 2, name: "Rua da Neblina", rival: "Clã Veludo", symbol: "cloud.fog.fill",
              cashCost: 2_500_000, respectCost: 45, blurb: "Clubes, letreiros de neon e segredos de madrugada."),
        .init(id: 3, name: "Distrito do Cassino", rival: "Irmãos Dourado", symbol: "suit.spade.fill",
              cashCost: 5_000_000_000, respectCost: 110, blurb: "Onde a casa sempre ganha — até você chegar."),
        .init(id: 4, name: "Colinas do Norte", rival: "O Conselho", symbol: "mountain.2.fill",
              cashCost: 2_000_000_000_000, respectCost: 300, blurb: "Mansões, bancos e o trono da cidade.")
    ]

    /// Bônus de lucro por bairro dominado além do primeiro.
    static let profitBonusPerDistrict = 0.25
}

struct CrimeRacket: Identifiable, Equatable {
    let id: Int
    let name: String
    let flavor: String
    let symbol: String
    let district: Int
    let baseCost: Double
    let growth: Double
    let cycle: Double
    let revenue: Double
    /// Calor gerado por segundo quando o negócio roda com gerente. Negativo = lava a imagem.
    let heat: Double
    let managerCost: Double
    let managerName: String
    let upgradeName: String

    static let catalog: [CrimeRacket] = [
        .init(id: 0, name: "Camelô de Relógios", flavor: "Rolex de verdade? Claro que não.", symbol: "clock.fill",
              district: 0, baseCost: 4, growth: 1.07, cycle: 0.8, revenue: 1, heat: 0.03,
              managerCost: 1_000, managerName: "Zé Pulseira", upgradeName: "Vitrine de veludo"),
        .init(id: 1, name: "Banca do Bicho", flavor: "Deu avestruz na cabeça.", symbol: "pawprint.fill",
              district: 0, baseCost: 60, growth: 1.15, cycle: 3, revenue: 60, heat: 0.06,
              managerCost: 15_000, managerName: "Seu Bené", upgradeName: "Talão premiado"),
        .init(id: 2, name: "Desmanche Ferrugem", flavor: "Entra carro, sai peça.", symbol: "car.fill",
              district: 1, baseCost: 720, growth: 1.14, cycle: 6, revenue: 540, heat: 0.10,
              managerCost: 100_000, managerName: "Graxa", upgradeName: "Elevador hidráulico"),
        .init(id: 3, name: "Contrabando no Cais", flavor: "Caixas que ninguém declarou.", symbol: "shippingbox.fill",
              district: 1, baseCost: 8_640, growth: 1.13, cycle: 12, revenue: 4_320, heat: 0.13,
              managerCost: 500_000, managerName: "Capitão Sal", upgradeName: "Rebocador fantasma"),
        .init(id: 4, name: "Clube Neblina", flavor: "Jazz, fumaça e conversas caras.", symbol: "music.note.house.fill",
              district: 2, baseCost: 103_680, growth: 1.12, cycle: 24, revenue: 51_840, heat: 0.08,
              managerCost: 1_200_000, managerName: "Madame Lux", upgradeName: "Palco giratório"),
        .init(id: 5, name: "Lavanderia Bolha", flavor: "Tudo sai limpinho. Inclusive o dinheiro.", symbol: "washer.fill",
              district: 2, baseCost: 1_244_160, growth: 1.11, cycle: 96, revenue: 622_080, heat: -0.15,
              managerCost: 10_000_000, managerName: "Dona Espuma", upgradeName: "Centrífuga dupla"),
        .init(id: 6, name: "Cassino Clandestino", flavor: "Fichas, dados e portas falsas.", symbol: "dice.fill",
              district: 3, baseCost: 14_929_920, growth: 1.10, cycle: 384, revenue: 7_464_960, heat: 0.20,
              managerCost: 111_111_111, managerName: "Crupiê Pérola", upgradeName: "Roleta viciada"),
        .init(id: 7, name: "Ateliê de Falsificação", flavor: "Um Monet por semana.", symbol: "paintpalette.fill",
              district: 3, baseCost: 179_159_040, growth: 1.09, cycle: 1_536, revenue: 89_579_520, heat: 0.15,
              managerCost: 555_555_555, managerName: "Pincel", upgradeName: "Verniz envelhecido"),
        .init(id: 8, name: "Banco Offshore", flavor: "Sede numa ilha que não existe.", symbol: "building.columns.fill",
              district: 4, baseCost: 2_149_908_480, growth: 1.08, cycle: 6_144, revenue: 1_074_954_240, heat: 0.10,
              managerCost: 10_000_000_000, managerName: "Dr. Cifrão", upgradeName: "Conta numerada"),
        .init(id: 9, name: "Sindicato da Neblina", flavor: "A cidade inteira paga pedágio.", symbol: "crown.fill",
              district: 4, baseCost: 25_798_901_760, growth: 1.07, cycle: 36_864, revenue: 29_668_737_024, heat: 0.25,
              managerCost: 100_000_000_000, managerName: "O Velho", upgradeName: "Selo do Conselho")
    ]

    /// Cada marco dobra a velocidade do negócio.
    static let speedMilestones = [25, 50, 100, 200, 300, 400]
    /// Cada marco multiplica o lucro do negócio.
    static let profitMilestones: [(count: Int, multiplier: Double)] = [(10, 2), (500, 3), (750, 3), (1_000, 5)]

    static func nextMilestone(after owned: Int) -> (count: Int, label: String)? {
        var all = speedMilestones.map { ($0, "velocidade ×2") }
        all += profitMilestones.map { ($0.count, "lucro ×\(Int($0.multiplier))") }
        return all.sorted { $0.0 < $1.0 }.first { $0.0 > owned }
    }
}

enum CrimeCrewPerk: Equatable {
    case profit, speed, heatShield, heistOdds, tapPower, heistLoot, offlineHours, respectGain
}

struct CrimeCrewMember: Identifiable, Equatable {
    let id: Int
    let name: String
    let role: String
    let symbol: String
    let perk: CrimeCrewPerk
    let perLevel: Double
    let recruitCost: Double
    let quote: String

    static let maxLevel = 10

    static let catalog: [CrimeCrewMember] = [
        .init(id: 0, name: "Dona Zica", role: "Contadora", symbol: "function", perk: .profit, perLevel: 0.15,
              recruitCost: 3, quote: "Número não mente. Eu minto por ele."),
        .init(id: 1, name: "Tião Volante", role: "Motorista", symbol: "steeringwheel", perk: .speed, perLevel: 0.05,
              recruitCost: 6, quote: "Semáforo é sugestão."),
        .init(id: 2, name: "Dr. Valença", role: "Advogado", symbol: "briefcase.fill", perk: .heatShield, perLevel: 0.06,
              recruitCost: 10, quote: "Meu cliente estava jantando com a avó."),
        .init(id: 3, name: "Marreta", role: "Segurança", symbol: "figure.boxing", perk: .heistOdds, perLevel: 0.03,
              recruitCost: 16, quote: "Ninguém passa. Nem eu, às vezes."),
        .init(id: 4, name: "Lola Lábia", role: "Golpista", symbol: "theatermasks.fill", perk: .tapPower, perLevel: 0.30,
              recruitCost: 24, quote: "Eu vendo areia no deserto. Com frete."),
        .init(id: 5, name: "Professor", role: "Planejador", symbol: "brain.head.profile", perk: .heistLoot, perLevel: 0.12,
              recruitCost: 40, quote: "Todo cofre tem uma história. E uma falha."),
        .init(id: 6, name: "Fantasma", role: "Arrombador", symbol: "key.fill", perk: .respectGain, perLevel: 0.10,
              recruitCost: 65, quote: "Você nunca me viu."),
        .init(id: 7, name: "Sr. Cofre", role: "Banqueiro", symbol: "lock.shield.fill", perk: .offlineHours, perLevel: 1,
              recruitCost: 100, quote: "Dinheiro parado é dinheiro triste.")
    ]

    /// Custo em respeito para passar do nível atual para o próximo (nível 0 = recrutar).
    func cost(fromLevel level: Int) -> Double {
        guard level > 0 else { return recruitCost }
        return (recruitCost * Double(level + 1) * 0.6).rounded()
    }

    func effectDescription(level: Int) -> String {
        let value = perLevel * Double(max(level, 0))
        switch perk {
        case .profit: return "+\(Int((value * 100).rounded()))% lucro de tudo"
        case .speed: return "+\(Int((value * 100).rounded()))% velocidade"
        case .heatShield: return "-\(Int((value * 100).rounded()))% calor gerado"
        case .heistOdds: return "+\(Int((value * 100).rounded()))% chance nos golpes"
        case .tapPower: return "+\(Int((value * 100).rounded()))% no golpe de rua"
        case .heistLoot: return "+\(Int((value * 100).rounded()))% no saque dos golpes"
        case .offlineHours: return "+\(Int(value))h de renda offline"
        case .respectGain: return "+\(Int((value * 100).rounded()))% respeito ganho"
        }
    }
}

enum CrimeHeistPlan: String, Codable, CaseIterable, Identifiable {
    case stealth, standard, loud

    var id: String { rawValue }
    var title: String {
        switch self {
        case .stealth: return "Furtivo"
        case .standard: return "Clássico"
        case .loud: return "Barulhento"
        }
    }
    var symbol: String {
        switch self {
        case .stealth: return "moon.fill"
        case .standard: return "hat.widebrim.fill"
        case .loud: return "flame.fill"
        }
    }
    var oddsDelta: Double {
        switch self {
        case .stealth: return 0.15
        case .standard: return 0
        case .loud: return -0.15
        }
    }
    var lootMultiplier: Double {
        switch self {
        case .stealth: return 0.7
        case .standard: return 1
        case .loud: return 1.8
        }
    }
    var heatMultiplier: Double {
        switch self {
        case .stealth: return 0.5
        case .standard: return 1
        case .loud: return 1.6
        }
    }
}

struct CrimeHeist: Identifiable, Equatable {
    let id: Int
    let name: String
    let briefing: String
    let symbol: String
    let district: Int
    let duration: Double
    let baseOdds: Double
    /// Saque equivalente a N segundos da renda atual.
    let lootSeconds: Double
    let minLoot: Double
    let respect: Double
    let heat: Double

    static let catalog: [CrimeHeist] = [
        .init(id: 0, name: "Bonde das Carteiras", briefing: "Uma volta no bonde da meia-noite com mãos leves.",
              symbol: "tram.fill", district: 0, duration: 20, baseOdds: 0.85, lootSeconds: 60, minLoot: 40, respect: 2, heat: 5),
        .init(id: 1, name: "Mesa de Pôquer Rachada", briefing: "Cartas marcadas num jogo de figurões.",
              symbol: "suit.club.fill", district: 0, duration: 90, baseOdds: 0.72, lootSeconds: 240, minLoot: 400, respect: 5, heat: 9),
        .init(id: 2, name: "Carga Desviada", briefing: "Um contêiner muda de destino no meio da noite.",
              symbol: "shippingbox.and.arrow.backward.fill", district: 1, duration: 300, baseOdds: 0.66, lootSeconds: 900, minLoot: 6_000, respect: 12, heat: 14),
        .init(id: 3, name: "Joalheria Esmeralda", briefing: "Vitrine blindada, alarme antigo, guarda sonolento.",
              symbol: "sparkles", district: 2, duration: 600, baseOdds: 0.6, lootSeconds: 1_800, minLoot: 250_000, respect: 25, heat: 20),
        .init(id: 4, name: "Trem Pagador", briefing: "Seis vagões, um deles cheio de malotes.",
              symbol: "train.side.front.car", district: 2, duration: 1_200, baseOdds: 0.55, lootSeconds: 3_600, minLoot: 2_000_000, respect: 40, heat: 26),
        .init(id: 5, name: "Cofre do Cassino Real", briefing: "A casa sempre ganha. Hoje não.",
              symbol: "lock.rectangle.stack.fill", district: 3, duration: 2_400, baseOdds: 0.5, lootSeconds: 7_200, minLoot: 5e9, respect: 70, heat: 30),
        .init(id: 6, name: "Leilão do Museu", briefing: "Trocar a tela original por uma das nossas.",
              symbol: "photo.artframe", district: 3, duration: 3_600, baseOdds: 0.46, lootSeconds: 12_000, minLoot: 2e10, respect: 100, heat: 32),
        .init(id: 7, name: "Casa da Moeda da Neblina", briefing: "O golpe que vai entrar para a lenda.",
              symbol: "banknote.fill", district: 4, duration: 7_200, baseOdds: 0.4, lootSeconds: 28_800, minLoot: 5e12, respect: 200, heat: 45)
    ]
}

enum CrimeUpgradeEffect: Equatable {
    case racketProfit(Int)
    case allProfit
    case tapPower
    case heatDecay
    case offlineHours
    case heistLoot
}

struct CrimeUpgrade: Identifiable, Equatable {
    let id: Int
    let name: String
    let detail: String
    let symbol: String
    let cost: Double
    let effect: CrimeUpgradeEffect

    static let catalog: [CrimeUpgrade] = {
        var list: [CrimeUpgrade] = [
            .init(id: 0, name: "Lábia afiada", detail: "Golpe de rua ×5", symbol: "hand.tap.fill", cost: 500, effect: .tapPower),
            .init(id: 1, name: "Rádio da polícia", detail: "Calor esfria 50% mais rápido", symbol: "antenna.radiowaves.left.and.right", cost: 25_000, effect: .heatDecay)
        ]
        for racket in CrimeRacket.catalog {
            list.append(.init(id: 2 + racket.id, name: racket.upgradeName, detail: "\(racket.name): lucro ×3",
                              symbol: racket.symbol, cost: racket.managerCost * 5, effect: .racketProfit(racket.id)))
        }
        list += [
            .init(id: 12, name: "Contador suíço", detail: "Todo o lucro ×3", symbol: "chart.line.uptrend.xyaxis", cost: 2_000_000, effect: .allProfit),
            .init(id: 13, name: "Cofre de fundo falso", detail: "+4h de renda offline", symbol: "archivebox.fill", cost: 5_000_000, effect: .offlineHours),
            .init(id: 14, name: "Conversa de vendedor", detail: "Golpe de rua ×5", symbol: "megaphone.fill", cost: 50_000_000, effect: .tapPower),
            .init(id: 15, name: "Escuta na delegacia", detail: "Calor esfria 50% mais rápido", symbol: "ear.fill", cost: 500_000_000, effect: .heatDecay),
            .init(id: 16, name: "Planta da Casa da Moeda", detail: "Saque dos golpes ×2", symbol: "map.fill", cost: 1e9, effect: .heistLoot),
            .init(id: 17, name: "Rede de laranjas", detail: "Todo o lucro ×3", symbol: "person.3.sequence.fill", cost: 1e10, effect: .allProfit),
            .init(id: 18, name: "Esconderijo nas Colinas", detail: "+4h de renda offline", symbol: "house.lodge.fill", cost: 1e12, effect: .offlineHours),
            .init(id: 19, name: "Cartel das Colinas", detail: "Todo o lucro ×3", symbol: "crown.fill", cost: 1e13, effect: .allProfit),
            .init(id: 20, name: "Cofre suíço", detail: "Saque dos golpes ×2", symbol: "lock.square.stack.fill", cost: 1e15, effect: .heistLoot),
            .init(id: 21, name: "Prefeito no bolso", detail: "Todo o lucro ×3", symbol: "building.fill", cost: 1e16, effect: .allProfit)
        ]
        return list
    }()
}

struct CrimeEventChoice: Equatable {
    let title: String
    let detail: String
    /// Custo em segundos de renda (mínimo de $1 por segundo).
    var costSeconds: Double = 0
    var cashSeconds: Double = 0
    var respect: Double = 0
    var heat: Double = 0
    var boost: Double = 1
    var boostSeconds: Double = 0
}

struct CrimeEvent: Identifiable, Equatable {
    let id: Int
    let title: String
    let story: String
    let symbol: String
    let choices: [CrimeEventChoice]

    static let catalog: [CrimeEvent] = [
        .init(id: 0, title: "Detetive na cola", story: "O detetive Bastos anda rondando seus negócios com um bloquinho na mão.", symbol: "magnifyingglass",
              choices: [.init(title: "Molhar a mão", detail: "Calor −25", costSeconds: 120, heat: -25),
                        .init(title: "Deixar quieto", detail: "Calor +12", heat: 12)]),
        .init(id: 1, title: "Festa no Clube", story: "A cidade inteira quer entrar no Clube Neblina hoje.", symbol: "party.popper.fill",
              choices: [.init(title: "Bancar a festa", detail: "Lucro ×2 por 2 min", costSeconds: 60, boost: 2, boostSeconds: 120),
                        .init(title: "Noite tranquila", detail: "Calor −5", heat: -5)]),
        .init(id: 2, title: "Informante do porto", story: "Um estivador diz saber quem anda falando demais.", symbol: "ear.fill",
              choices: [.init(title: "Pagar a dica", detail: "+8 respeito", costSeconds: 90, respect: 8),
                        .init(title: "Dispensar", detail: "Nada acontece")]),
        .init(id: 3, title: "Caiu do caminhão", story: "Cem televisores apareceram num beco. Ninguém sabe de onde.", symbol: "tv.fill",
              choices: [.init(title: "Revender rápido", detail: "+3 min de renda · calor +10", cashSeconds: 180, heat: 10),
                        .init(title: "Devolver discretamente", detail: "+3 respeito · calor −5", respect: 3, heat: -5)]),
        .init(id: 4, title: "Provocação rival", story: "Os Gaivotas pintaram o símbolo deles na sua porta.", symbol: "exclamationmark.bubble.fill",
              choices: [.init(title: "Responder à altura", detail: "+10 respeito · calor +18", respect: 10, heat: 18),
                        .init(title: "Engolir o orgulho", detail: "Calor −3", heat: -3)]),
        .init(id: 5, title: "Jornalista curioso", story: "Uma repórter do Diário da Neblina quer uma entrevista.", symbol: "newspaper.fill",
              choices: [.init(title: "Dar uma exclusiva falsa", detail: "Calor −15", costSeconds: 60, heat: -15),
                        .init(title: "Fugir das câmeras", detail: "Calor +6", heat: 6)]),
        .init(id: 6, title: "Velho amigo", story: "Seu antigo parceiro de bonde pede um empréstimo.", symbol: "person.2.fill",
              choices: [.init(title: "Emprestar", detail: "+6 respeito", costSeconds: 100, respect: 6),
                        .init(title: "Negar", detail: "Nada acontece")]),
        .init(id: 7, title: "Apagão na cidade", story: "Toda a Neblina ficou no escuro. Oportunidade?", symbol: "bolt.slash.fill",
              choices: [.init(title: "Aproveitar a escuridão", detail: "Lucro ×3 por 1 min · calor +10", heat: 10, boost: 3, boostSeconds: 60),
                        .init(title: "Ficar na moita", detail: "Calor −10", heat: -10)]),
        .init(id: 8, title: "Mala esquecida", story: "Alguém deixou uma mala de couro no seu escritório.", symbol: "suitcase.fill",
              choices: [.init(title: "Abrir", detail: "+5 min de renda", cashSeconds: 300),
                        .init(title: "Devolver ao dono", detail: "+5 respeito", respect: 5)])
    ]
}

enum CrimeContractGoal: Equatable {
    case owned(racket: Int, count: Int)
    case totalOwned(Int)
    case managers(Int)
    case lifetime(Double)
    case districts(Int)
    case heists(Int)
    case crew(Int)
    case prestige(Int)
}

struct CrimeContract: Identifiable, Equatable {
    let id: Int
    let title: String
    let goal: CrimeContractGoal
    let respect: Double
    let cashSeconds: Double

    static let catalog: [CrimeContract] = [
        .init(id: 0, title: "Abra 5 bancas de relógio", goal: .owned(racket: 0, count: 5), respect: 1, cashSeconds: 0),
        .init(id: 1, title: "Faça seu primeiro golpe", goal: .heists(1), respect: 2, cashSeconds: 30),
        .init(id: 2, title: "Recrute alguém para a família", goal: .crew(1), respect: 2, cashSeconds: 60),
        .init(id: 3, title: "Contrate seu primeiro gerente", goal: .managers(1), respect: 3, cashSeconds: 60),
        .init(id: 4, title: "Chegue a 25 relógios", goal: .owned(racket: 0, count: 25), respect: 3, cashSeconds: 120),
        .init(id: 5, title: "Domine o Porto Velho", goal: .districts(2), respect: 5, cashSeconds: 120),
        .init(id: 6, title: "Tenha 50 negócios", goal: .totalOwned(50), respect: 5, cashSeconds: 180),
        .init(id: 7, title: "Fature $1 milhão na vida", goal: .lifetime(1e6), respect: 8, cashSeconds: 180),
        .init(id: 8, title: "Complete 10 golpes", goal: .heists(10), respect: 10, cashSeconds: 300),
        .init(id: 9, title: "Tenha 5 gerentes", goal: .managers(5), respect: 10, cashSeconds: 300),
        .init(id: 10, title: "Domine a Rua da Neblina", goal: .districts(3), respect: 12, cashSeconds: 300),
        .init(id: 11, title: "Monte uma família de 5", goal: .crew(5), respect: 12, cashSeconds: 300),
        .init(id: 12, title: "Tenha 250 negócios", goal: .totalOwned(250), respect: 20, cashSeconds: 600),
        .init(id: 13, title: "Fature $1 bilhão na vida", goal: .lifetime(1e9), respect: 25, cashSeconds: 600),
        .init(id: 14, title: "Assuma uma nova identidade", goal: .prestige(1), respect: 30, cashSeconds: 0),
        .init(id: 15, title: "Domine o Distrito do Cassino", goal: .districts(4), respect: 40, cashSeconds: 900),
        .init(id: 16, title: "Complete 50 golpes", goal: .heists(50), respect: 50, cashSeconds: 900),
        .init(id: 17, title: "Seja dono das Colinas", goal: .districts(5), respect: 80, cashSeconds: 1_800),
        .init(id: 18, title: "Fature $1 trilhão na vida", goal: .lifetime(1e12), respect: 100, cashSeconds: 1_800),
        .init(id: 19, title: "Tenha 1.000 negócios", goal: .totalOwned(1_000), respect: 150, cashSeconds: 3_600)
    ]
}

struct CrimeRank: Equatable {
    let title: String
    let threshold: Double

    static let ladder: [CrimeRank] = [
        .init(title: "Pivete", threshold: 0),
        .init(title: "Olheiro", threshold: 1_000),
        .init(title: "Soldado", threshold: 100_000),
        .init(title: "Capitão", threshold: 10_000_000),
        .init(title: "Subchefe", threshold: 1e9),
        .init(title: "Consigliere", threshold: 1e11),
        .init(title: "Chefão", threshold: 1e13),
        .init(title: "Lenda da Neblina", threshold: 1e15)
    ]
}
